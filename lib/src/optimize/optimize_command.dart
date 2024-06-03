import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_web_optimizer/src/optimize/flutter_service_worker.js.dart';
import 'package:flutter_web_optimizer/src/optimize/flutter_web_optimizer.js.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as path;
import 'package:standard_message_codec/standard_message_codec.dart';

import '../common/logger.dart';
import '../common/model.dart';
import 'flutter.js.dart';

class OptimizeCommand extends Command<void> {
  OptimizeCommand() {
    argParser
      ..addOption(
        'asset-base',
        help: 'asset base url，end with /，eq：http://127.0.0.1:8080/',
        mandatory: true,
      )
      ..addOption(
        'web-output',
        help: 'web artifacts output dir，'
            'only support relative path，root path is [path.context.current]，'
            'eq：build/web',
      )
      ..addOption(
        'plugin',
        help: 'plugin file path，'
            'only support relative path，root path is [path.context.current]，'
            'eq：flutter_web_optimize_plugin.dart',
      )
      ..addFlag(
        'enable-pwa',
        help: 'enable PWA service worker',
        defaultsTo: true,
      )
      ..addOption(
        'hash-filter-regexp',
        help: 'hash file filter',
      )
      ..addFlag(
        'enable-vconsole',
        help: 'enable vconsole tools',
        defaultsTo: false,
      );
  }

  @override
  String get description =>
      'solve web page loading slow and browser cache problem';

  @override
  String get name => 'optimize';

  /// 资源路径，一般是cdn地址
  late String _assetBase;

  /// Web构建产物路径
  late String _webOutput;

  /// plugin 文件路径，支持处理资源上传cdn等操作
  late String _plugin;

  /// 是否支持pwa
  late bool _enablePWA;

  /// 哈希文件筛选器
  late String _hashFilterRegexp;

  /// 是否启用vconsole
  late bool _enableVConsole;

  /// isolate通信，发送信息
  SendPort? _sendPort;

  /// isolate通信，接收信息
  ReceivePort? _receivePort;

  /// isolate消息
  Stream<IsolateMessageProtocol>? _message;

  // 需要hash的文件
  final Map<String, String> _hashFiles = <String, String>{};

  // 哈希化后的文件清单
  final Map<String, String> _hashFileManifest = <String, String>{};

  @override
  FutureOr<void> run() async {
    Logger.info('start web optimize');

    await _parseArgs();

    await _initIsolate();

    final Directory outputDir = Directory(_webOutput);
    if (!outputDir.existsSync()) {
      // 构建产物目录不存在，直接退出
      Logger.error('web artifacts output dir is not exist');
      exit(2);
    }

    await _splitMainDartJS(outputDir);

    _replaceFlutterJS();

    _hashAssets();

    _importFlutterWebOptimizerJS();

    _updateSourceMapsMark();

    if (_enablePWA) {
      _updateFlutterServiceWorkerJS();
    }

    _injectToHtml();

    await _cdnAssets();

    _disposeIsolate();

    Logger.info('end web optimize');
  }

  /// 解析命令行参数
  // void _parseShellArgs(List<String> arguments) {
  //   final ArgParser argParser = ArgParser()
  //     ..addOption(
  //       'asset-base',
  //       help: 'asset base url，end with /，eq：http://127.0.0.1:8080/',
  //       mandatory: true,
  //     )
  //     ..addOption(
  //       'web-output',
  //       help: 'web artifacts output dir，'
  //           'only support relative path，root path is [path.context.current]，'
  //           'eq：build/web',
  //     )
  //     ..addOption(
  //       'plugin',
  //       help: 'plugin file path，'
  //           'only support relative path，root path is [path.context.current]，'
  //           'eq：flutter_web_optimize_plugin.dart',
  //     );
  //   final ArgResults argResults =
  //       completion.tryArgsCompletion(arguments, argParser);
  //   _assetBase = argResults['asset-base'];
  //   final String? webOutput = argResults['web-output'];
  //   if (webOutput?.isNotEmpty ?? false) {
  //     _webOutput = path.join(path.context.current, webOutput!);
  //   }
  //   final String? pluginFile = argResults['plugin'];
  //   if (pluginFile?.isNotEmpty ?? false) {
  //     _plugin = path.join(path.context.current, pluginFile!);
  //   }
  // }

  Future<void> _parseArgs() async {
    Future<void> parsePluginArgs() async {
      /// plugin 文件路径，支持处理资源上传cdn等操作
      final String? plugin = argResults!['plugin'];
      if (plugin?.isEmpty ?? true) {
        _plugin = '';
        return;
      }
      if (path.extension(plugin!).isNotEmpty) {
        /// Uri
        _plugin = path.join(path.context.current, plugin);
      } else {
        /// Not Uri
        final PackageConfig? packageConfig =
            await findPackageConfig(Directory.current);
        if (packageConfig == null) {
          _plugin = '';
          return;
        }
        try {
          final Package package = packageConfig.packages
              .singleWhere((Package element) => element.name == plugin);
          _plugin = path.join(package.packageUriRoot.toFilePath(), plugin);
          _plugin = path.setExtension(_plugin, '.dart');
        } catch (_) {
          _plugin = '';
        }
      }
      if (!File(_plugin).existsSync()) {
        throw Exception('plugin args is invalid!!!');
      }
    }

    /// 资源路径，一般是cdn地址
    _assetBase = argResults!['asset-base'] ?? '';

    /// Web构建产物路径
    final String? webOutput = argResults!['web-output'];
    if (webOutput?.isNotEmpty ?? false) {
      _webOutput = path.join(path.context.current, webOutput!);
    } else {
      _webOutput = path.join(path.context.current, 'build', 'web');
    }

    /// plugin 文件路径，支持处理资源上传cdn等操作
    await parsePluginArgs();

    /// 是否支持pwa
    _enablePWA = argResults!['enable-pwa'];

    /// 哈希文件筛选器
    _hashFilterRegexp = argResults!['hash-filter-regexp'] ?? '';

    /// 是否启用vconsole
    _enableVConsole = argResults!['enable-vconsole'];
  }

  /// 初始化isolate通信
  Future<void> _initIsolate() {
    if (_plugin.isEmpty) {
      return Future<void>.value();
    }

    final Completer<void> completer = Completer<void>();
    final StreamController<IsolateMessageProtocol> controller =
        StreamController<IsolateMessageProtocol>.broadcast();
    _message = controller.stream;

    _receivePort ??= ReceivePort();
    _receivePort!.listen((dynamic message) {
      if (message is SendPort) {
        _sendPort = message;
        completer.complete();
      }

      if (message is Map<String, Object>) {
        Logger.info('server isolate get message: $message');
        controller.add(IsolateMessageProtocol.fromMap(message));
      }
    });

    Isolate.spawnUri(
      Uri.file(_plugin),
      argResults!.arguments,
      _receivePort!.sendPort,
    );
    return completer.future;
  }

  /// 释放isolate通信
  void _disposeIsolate() {
    _receivePort?.close();
    _receivePort = null;
    _sendPort = null;
    _message = null;
  }

  /// 拆分 main.dart.js
  Future<void> _splitMainDartJS(Directory outputDir) async {
    // 写入单个文件
    Future<bool> writeSingleFile({
      required File file,
      required String filename,
      required int startIndex,
      required endIndex,
    }) {
      final Completer<bool> completer = Completer();
      final File f = File(path.join(file.parent.path, filename));
      if (f.existsSync()) {
        f.deleteSync();
      }
      final RandomAccessFile raf = f.openSync(mode: FileMode.write);
      late final StreamSubscription<List<int>> subscription;
      subscription = file.openRead(startIndex, endIndex).listen(
        (List<int> data) {
          raf.writeFromSync(data);
        },
        onDone: () {
          raf.flushSync();
          raf.closeSync();
          completer.complete(true);
          subscription.cancel();
        },
        onError: (dynamic data) {
          raf.flushSync();
          raf.closeSync();
          completer.complete(false);
          subscription.cancel();
        },
      );
      return completer.future;
    }

    final File file = outputDir.listSync().whereType<File>().singleWhere(
        (File entity) => path.basename(entity.path) == 'main.dart.js');

    /// 针对xhr加载动态js文件，插入『@ sourceURL』标记，方便调试
    file.openSync(mode: FileMode.append)
      ..writeStringSync('\n\n//@ sourceURL=main.dart.js\n')
      ..closeSync();
    const int totalChunk = 6;
    final Uint8List bytes = file.readAsBytesSync();
    final int chunkSize = (bytes.length / totalChunk).ceil();
    final List<Future<bool>> futures = List<Future<bool>>.generate(
      totalChunk,
      (int index) {
        return writeSingleFile(
          file: file,
          filename: 'main.dart_$index.js',
          startIndex: index * chunkSize,
          endIndex: (index + 1) * chunkSize,
        );
      },
    );

    await Future.wait(futures);
  }

  /// 替换 flutter.js
  void _replaceFlutterJS() {
    final File file = File('$_webOutput/flutter.js');
    if (!file.existsSync()) {
      file.createSync();
    }
    file.writeAsStringSync(flutterJSSourceCode);
  }

  /// md5文件
  String _md5File(File file) {
    Logger.info('hashing file: ${file.path}');
    final Uint8List bytes = file.readAsBytesSync();
    // 截取8位即可
    final String md5Hash = crypto.md5.convert(bytes).toString().substring(0, 8);

    // 文件名使用hash值
    String filename = path.basename(file.path);
    final index = filename.indexOf('.');
    String basename = filename.substring(0, index);
    String extension = filename.substring(index);
    filename = '$basename.$md5Hash$extension';
    Logger.info('hashed file name: $filename');

    return filename;
  }

  /// 过滤文件是否进行哈希操作
  /// [path] 文件路径
  bool _filteringHashFile(String path) {
    if (_hashFilterRegexp.isEmpty) {
      return false;
    }
    return RegExp(_hashFilterRegexp).hasMatch(path);
  }

  /// 资源hash化
  void _hashAssets() {
    /// 替换
    String replace(
      Match match,
      File file,
      String key,
      Map<String, String> hashFiles,
    ) {
      if (_filteringHashFile(file.path)) {
        return match[0] ?? '';
      }
      // 文件名使用hash值
      // AssetManifest.6acec4df.json
      final String filename = _md5File(file);
      // 此时key已经是 posix 平台的分隔符 /
      // 统一将路径分隔符修改成 / ，assetManifest 和 fontManifest 使用的是 posix 平台的分隔符 /
      final String dirname = path.posix.dirname(key);
      final String newKey = path.posix.join(dirname, filename);

      // hash文件路径
      final String newPath = path.join(path.dirname(file.path), filename);
      hashFiles[file.path] = newPath;

      return '${match[1]}$newKey${match[3]}';
    }

    /// hash化canvaskit
    void hashCanvaskitDir() {
      // 遍历构建产物icons目录
      final Directory canvaskitDir =
          Directory(path.join(_webOutput, 'canvaskit'));
      canvaskitDir
          .listSync(recursive: true)
          .whereType<File>() // 文件类型
          .where((File file) => !path.basename(file.path).startsWith('.'))
          .forEach((File file) {
        // final String filename = _md5File(file);
        // _hashFiles[file.path] = path.join(path.dirname(file.path), filename);
        _hashFiles[file.path] = file.path;
      });
    }

    /// hash化icons目录
    void hashIconsDir() {
      // 读取 manifest.json 清单文件
      final File manifest = File(path.join(_webOutput, 'manifest.json'));
      String manifestContents = manifest.readAsStringSync();
      // 遍历构建产物icons目录
      final Directory iconsDir = Directory(path.join(_webOutput, 'icons'));
      iconsDir
          .listSync()
          .whereType<File>() // 文件类型
          .where((File file) => !path.basename(file.path).startsWith('.'))
          .forEach((File file) {
        // 使用 posix 平台的分隔符 /
        String key = path.relative(file.path, from: _webOutput);
        key = path.toUri(key).toString();
        // 替换 manifest.json 清单文件
        manifestContents = manifestContents.replaceFirstMapped(
          RegExp('(.*)($key)(.*)'),
          (Match match) => replace(match, file, key, _hashFiles),
        );
      });
      // 写入修改后的 manifest.json 清单文件
      manifest.writeAsStringSync(manifestContents);
    }

    /// hash化assets目录
    void hashAssetsDir(Map<String, File> files) {
      // 读取资源清单文件
      final File assetManifestJson =
          File(path.join(_webOutput, 'assets', 'AssetManifest.json'));
      String assetManifestJsonContents = assetManifestJson.readAsStringSync();
      // flutter 3.10.5 版本后 AssetManifest.json 变更为 AssetManifest.bin
      // 文件编码使用StandardMessageCodec
      final File assetManifestBin =
          File(path.join(_webOutput, 'assets', 'AssetManifest.bin'));
      ByteData assetManifestByteData =
          assetManifestBin.readAsBytesSync().buffer.asByteData();
      String assetManifestBinContents = jsonEncode(
          const StandardMessageCodec().decodeMessage(assetManifestByteData));
      // flutter 3.16 版本后 AssetManifest.bin 变更为 AssetManifest.bin.json
      final File assetManifestBinJson =
          File(path.join(_webOutput, 'assets', 'AssetManifest.bin.json'));

      // 读取字体清单文件
      final File fontManifest =
          File(path.join(_webOutput, 'assets', 'FontManifest.json'));
      String fontManifestContents = fontManifest.readAsStringSync();

      // 遍历构建产物assets目录，对资源文件md5后获取哈希值，并修改资源、字体清单文件
      final Directory assetsDir = Directory(path.join(_webOutput, 'assets'));
      assetsDir
          .listSync(recursive: true)
          .whereType<File>() // 文件类型
          .where((File file) => !path.basename(file.path).startsWith('.'))
          .forEach((File file) {
        // 使用 posix 平台的分隔符 /
        String key = path.relative(file.path, from: assetsDir.path);
        key = path.toUri(key).toString();
        // 替换资源清单文件
        assetManifestJsonContents =
            assetManifestJsonContents.replaceFirstMapped(
          RegExp('(.*)($key)(.*)'),
          (Match match) => replace(match, file, key, _hashFiles),
        );
        assetManifestBinContents = assetManifestBinContents.replaceFirstMapped(
          RegExp('(.*)($key)(.*)'),
          (Match match) => replace(match, file, key, _hashFiles),
        );
        // 替换字体清单文件
        fontManifestContents = fontManifestContents.replaceAllMapped(
          RegExp('(.*)($key)(.*)'),
          (Match match) => replace(match, file, key, _hashFiles),
        );

        if (<String>['.svg'].contains(path.extension(file.path))) {
          // 针对flutter_svg插件使用svg文件的特殊处理
          files[key] = file;
        }
      });

      // 写入修改后的资源、字体清单文件
      assetManifestJson.writeAsStringSync(assetManifestJsonContents);
      // 文件编码为StandardMessageCodec的写入方式
      assetManifestByteData = const StandardMessageCodec()
          .encodeMessage(jsonDecode(assetManifestBinContents))!;
      final Uint8List assetManifestByte = assetManifestByteData.buffer
          .asUint8List(0, assetManifestByteData.lengthInBytes);
      assetManifestBin.writeAsBytesSync(assetManifestByte);
      // AssetManifest.bin 变更为 AssetManifest.bin.json
      final String assetManifestBinJsonContents =
          json.encode(base64.encode(assetManifestByte));
      assetManifestBinJson.writeAsStringSync(assetManifestBinJsonContents);

      fontManifest.writeAsStringSync(fontManifestContents);
    }

    /// 修正源码引用
    void amendSourceCode(Map<String, File> files) {
      // 将AssetManifest.bin.json文件进行md5
      String assetManifestBinJsonFileName = 'AssetManifest.bin.json';
      final File assetManifestBinJsonFile =
          File(path.join(_webOutput, 'assets', assetManifestBinJsonFileName));
      files[assetManifestBinJsonFileName] = assetManifestBinJsonFile;

      // 将AssetManifest.bin文件进行md5
      String assetManifestBinFileName = 'AssetManifest.bin';
      final File assetManifestBinFile =
          File(path.join(_webOutput, 'assets', assetManifestBinFileName));
      files[assetManifestBinFileName] = assetManifestBinFile;

      // 将AssetManifest.json文件进行md5
      String assetManifestFileName = 'AssetManifest.json';
      final File assetManifestFile =
          File(path.join(_webOutput, 'assets', assetManifestFileName));
      files[assetManifestFileName] = assetManifestFile;

      // 将FontManifest.json进行md5
      String fontManifestFileName = 'FontManifest.json';
      final File fontManifestFile =
          File(path.join(_webOutput, 'assets', fontManifestFileName));
      files[fontManifestFileName] = fontManifestFile;

      // 需要修正源码中关联的字符串引用
      final Map<String, String> amendSourceCodeRelatedStrings =
          <String, String>{};
      files.forEach((String key, File value) {
        String newKey = key.replaceFirstMapped(
          RegExp('(.*)($key)(.*)'),
          (Match match) => replace(match, value, key, _hashFiles),
        );
        if (newKey.startsWith('./')) {
          newKey = newKey.substring(2);
        }
        amendSourceCodeRelatedStrings[key] = newKey;
      });
      Logger.info('msg: $amendSourceCodeRelatedStrings');

      Directory(_webOutput)
          .listSync()
          .whereType<File>() // 文件类型
          .where((File file) {
        final RegExp regExp = RegExp(r'^main\.dart(.*)\.js$');
        final String filename = path.basename(file.path);
        return regExp.hasMatch(filename);
      }).forEach((File file) {
        // 查找 main.dart_xxx.js 和 main.dart.xxx.part.js 文件
        // 修正修正源码中关联的字符串引用
        String contents = file.readAsStringSync();
        amendSourceCodeRelatedStrings.forEach((String key, String value) {
          contents = contents.replaceAll(RegExp(key), value);
        });
        file.writeAsStringSync(contents);
      });
    }

    /// hash化web根目录
    void hashWebOutputDir() {
      Directory(_webOutput)
          .listSync()
          .whereType<File>() // 文件类型
          .where((File file) {
        final RegExp regExp = RegExp(
            r'(main\.dart(.*)\.js)|(favicon.png)|(flutter.js)|(manifest.json)');
        final String filename = path.basename(file.path);
        return regExp.hasMatch(filename);
      }).forEach((File file) {
        final String filename = _md5File(file);
        _hashFiles[file.path] = path.join(path.dirname(file.path), filename);
      });
    }

    // 需要修正源码中关联的文件引用
    final Map<String, File> amendSourceCodeRelatedFiles = <String, File>{};

    hashCanvaskitDir();
    hashIconsDir();
    hashAssetsDir(amendSourceCodeRelatedFiles);
    amendSourceCode(amendSourceCodeRelatedFiles);
    hashWebOutputDir();

    // 重命名文件
    _hashFiles.forEach((String key, String value) {
      File(key).renameSync(value);
    });
  }

  /// 导入flutter_web_optimizer.js
  void _importFlutterWebOptimizerJS() {
    /// 排序后生成 _hashFileManifest 和 jsManifest
    void getManifestValue(Map<String, String> jsManifest) {
      _hashFiles.keys.toList()
        ..sort()
        ..forEach((String key) {
          String filepath =
              path.toUri(path.relative(key, from: _webOutput)).toString();
          String hashedFilePath = path
              .toUri(path.relative(_hashFiles[key]!, from: _webOutput))
              .toString();
          _hashFileManifest[filepath] = hashedFilePath;
          final String filename = path.basename(key);
          if (RegExp(r'^main\.dart(.*)\.js$').hasMatch(filename)) {
            jsManifest[filename] = path.basename(_hashFiles[key]!);
          }
        });
    }

    /// 修正flutter_web_optimizer.js源码
    File amendSourceCode(Map<String, String> jsManifest) {
      // 更新 assetBase、mainjsManifest 和 hashFileManifest
      const JsonEncoder jsonEncoder = JsonEncoder.withIndent('  ');
      final String flutterWebOptimizer = flutterWebOptimizerSourceCode
          .replaceAll(
            RegExp('var assetBase = null;'),
            'var assetBase = "$_assetBase";',
          )
          .replaceAll(
            RegExp('var mainjsManifest = null;'),
            'var mainjsManifest = ${jsonEncoder.convert(jsManifest)};',
          )
          .replaceAll(
            RegExp('var hashFileManifest = null;'),
            'var hashFileManifest = ${jsonEncoder.convert(_hashFileManifest)};',
          );
      final File file = File('$_webOutput/flutter_web_optimizer.js')
        ..createSync()
        ..writeAsStringSync(flutterWebOptimizer);
      return file;
    }

    // 哈希化后的main.dart.js && main.dart.xxx.part文件
    final Map<String, String> jsManifest = <String, String>{};
    getManifestValue(jsManifest);
    final File file = amendSourceCode(jsManifest);

    // 哈希flutter_web_optimizer.js文件
    final String fileName = _md5File(file);
    String filepath = file.path;
    String hashedFilePath = path.join(path.dirname(file.path), fileName);
    _hashFiles[filepath] = hashedFilePath;
    // 重命名文件
    file.renameSync(hashedFilePath);
    // 更新 _hashFileManifest
    filepath = path.toUri(path.relative(filepath, from: _webOutput)).toString();
    hashedFilePath =
        path.toUri(path.relative(hashedFilePath, from: _webOutput)).toString();
    _hashFileManifest[filepath] = hashedFilePath;
  }

  /// 修正//# sourceMappingURL，插入//@ sourceURL
  void _updateSourceMapsMark() {
    String replace(Match m) => '${m[1]}$_assetBase${_hashFileManifest[m[2]]}';
    Directory(_webOutput)
        .listSync()
        .whereType<File>() // 文件类型
        .where((File file) {
      final RegExp regExp = RegExp(r'^main\.dart(.*)\.js$');
      final String filename = path.basename(file.path);
      return regExp.hasMatch(filename);
    }).forEach((File file) {
      String contents = file.readAsStringSync();
      contents = contents
          .replaceFirstMapped(RegExp(r'(//# sourceMappingURL=)(.*)\n'), replace)
          .replaceFirstMapped(RegExp(r'(//@ sourceURL=)(.*)\n'), replace);
      file.writeAsStringSync(contents);
    });
  }

  /// 更新flutter_service_worker.js
  void _updateFlutterServiceWorkerJS() {
    final File file = File(path.join(_webOutput, 'flutter_service_worker.js'));
    if (!file.existsSync()) {
      return;
    }
    String contents = file.readAsStringSync();
    if (contents.isEmpty) {
      return;
    }
    String? resourcesValues = RegExp(r'const RESOURCES = {\n([\s\S]*)\n};')
        .firstMatch(contents)
        ?.group(1);
    if (resourcesValues?.isEmpty ?? true) {
      return;
    }
    String? coreValues = RegExp(r'const CORE = \[\n([\s\S]*?)\];')
        .firstMatch(contents)
        ?.group(1);
    if (coreValues?.isEmpty ?? true) {
      return;
    }

    final List<String> insertedJSList = <String>[];
    _hashFileManifest.keys.where((String key) => key != 'main.dart.js').toList()
      ..sort()
      ..forEach((String key) {
        final String value = _hashFileManifest[key]!;
        resourcesValues =
            resourcesValues?.replaceAll(RegExp('"$key"'), '"$value"');
        coreValues = coreValues?.replaceAll(RegExp('"$key"'), '"$value"');

        final String filename = path.basename(key);
        if (RegExp(r'^(main\.dart(.*)\.js|flutter_web_optimizer\.js)$')
            .hasMatch(filename)) {
          // 收集main.dart.*js和flutter_web_optimizer.js文件
          insertedJSList.add(value);
        }
      });
    resourcesValues = resourcesValues?.replaceAll(
        RegExp(r'"main\.dart\.js": (.+),'),
        insertedJSList
            .where((String key) => RegExp(
                    r'^main\.dart_\d(.*)\.js|flutter_web_optimizer\.(.*)\.js$')
                .hasMatch(key))
            .map((String js) {
              final String md5String = crypto.md5
                  .convert(File(path.join(_webOutput, js)).readAsBytesSync())
                  .toString();
              return '"$js": "$md5String",';
            })
            .toList()
            .join('\n'));
    coreValues = coreValues?.replaceAll(
      RegExp(r'"main\.dart\.js",'),
      insertedJSList
          .where((String key) =>
              !RegExp(r'^flutter_web_optimizer\.(.*)\.js$').hasMatch(key))
          .map((String js) => '"$js",')
          .toList()
          .join('\n'),
    );
    contents = flutterServiceWorkerSourceCode
        .replaceFirstMapped(
          RegExp(r'(const RESOURCES = {)(};)'),
          (m) => '${m[1]}\n$resourcesValues\n${m[2]}',
        )
        .replaceAll(
          RegExp(RegExp.escape('const CORE = [];'), caseSensitive: true),
          'const CORE = [\n$coreValues\n];',
        )
        .replaceAll(
          RegExp(r'const assetBase = null;'),
          'var assetBase = "$_assetBase";',
        );
    file.writeAsStringSync(contents);
  }

  /// 修改 index.html
  void _injectToHtml() {
    /// 注入 assetBase meta 标签
    // void injectAssetBaseMeta({
    //   required Document document,
    //   required Element headElement,
    // }) {
    //   final DocumentFragment metaFragment = document.createDocumentFragment();
    //   metaFragment.append(Text('\n'));
    //   metaFragment.append(Comment('content值必须以 / 结尾'));
    //   metaFragment.append(Text('\n'));
    //   final Element meta = Element.tag('meta')
    //     ..attributes['name'] = 'assetBase'
    //     ..attributes['content'] = _assetBase;
    //   metaFragment.append(meta);
    //   metaFragment.append(Text('\n'));
    //
    //   final List<Element> metas = headElement.getElementsByTagName('meta');
    //   if (metas.isNotEmpty) {
    //     headElement.insertBefore(metaFragment, metas.last.nextElementSibling);
    //   } else {
    //     headElement.append(metaFragment);
    //   }
    // }

    /// 注入 flutter_web_optimizer.js script
    void injectFlutterWebOptimizerScript({
      required Element headElement,
    }) {
      final Element script = Element.tag('script');
      script.attributes['src'] = 'flutter_web_optimizer.js';
      script.attributes['defer'] = '';

      final List<Element> scripts = headElement.getElementsByTagName('script');
      if (scripts.length > 1) {
        final Element firstScript = scripts.first;
        headElement.insertBefore(script, firstScript);
        headElement.insertBefore(Text('\n'), firstScript);
      } else {
        headElement.append(script);
        headElement.append(Text('\n'));
      }
    }

    /// 插入vconsole
    void injectVConsoleScript({
      required Element headElement,
    }) {
      final Element script = Element.tag('script');
      script.attributes['src'] =
          'https://cdn.jsdelivr.net/npm/vconsole@latest/dist/vconsole.min.js';

      headElement.append(script);
      headElement.append(Text('\n'));
      // headElement.append(Text(r'''
      // <script>
      //   // VConsole will be exported to `window.VConsole` by default.
      //   var vConsole = new window.VConsole();
      // </script>
      // '''));
      // headElement.append(Text('\n'));

      final Element initScript = Element.tag('script');
      initScript.text = r'''
        // VConsole will be exported to `window.VConsole` by default.
        var vConsole = new window.VConsole();
        ''';
      headElement.append(initScript);
      headElement.append(Text('\n'));
    }

    /// 替换哈希后的文件
    String replace(String key, {bool isAbsolute = true}) {
      if (key.isEmpty || !_hashFileManifest.containsKey(key)) {
        return key;
      }
      if (isAbsolute) {
        return '$_assetBase${_hashFileManifest[key]}';
      } else {
        return _hashFileManifest[key]!;
      }
    }

    /// 修正元素值
    void amendElements({required Document document}) {
      // 查找所有元素
      final List<Element> elements = document.querySelectorAll('*');
      for (final Element element in elements) {
        if (element.attributes.containsKey('href')) {
          String href = element.attributes['href']!;
          final bool isAbsolute = !<String>[
            'icons/Icon-192.png',
            'favicon.png',
            'manifest.json',
          ].contains(href);
          href = replace(href, isAbsolute: isAbsolute);
          element.attributes['href'] = href;
        }
        if (element.attributes.containsKey('src')) {
          String src = element.attributes['src']!;
          src = replace(src);
          element.attributes['src'] = src;
        }
      }
    }

    /// 读取index.html
    final File file = File('$_webOutput/index.html');
    String contents = file.readAsStringSync();

    /// 解析 index.html 为 Document
    final Document document = parse(contents);
    final Element? headElement = document.head;
    if (headElement == null) {
      Logger.error('the document head cannot be null');
      exit(2);
    }
    // injectAssetBaseMeta(document: document, headElement: headElement);
    injectFlutterWebOptimizerScript(headElement: headElement);
    if (_enableVConsole) {
      injectVConsoleScript(headElement: headElement);
    }
    amendElements(document: document);

    // 写入文件
    file.writeAsStringSync(document.outerHtml);
  }

  /// 资源cdn化
  Future<void> _cdnAssets() async {
    if (_plugin.isEmpty) {
      return Future<void>.value();
    }
    final Completer<void> completer = Completer<void>();
    StreamSubscription<IsolateMessageProtocol>? subscription;
    subscription = _message?.listen((IsolateMessageProtocol protocol) {
      if (protocol.isResponse &&
          protocol.action == IsolateMessageAction.cdnAssets) {
        subscription?.cancel();
        completer.complete();
      }
    });
    // 需要上传的文件
    final List<String> toUploadFiles = _hashFiles.values.toList();
    _sendPort?.send(IsolateMessageProtocol.request(
      IsolateMessageAction.cdnAssets,
      toUploadFiles,
    ).toMap());
    return completer.future;
  }
}
