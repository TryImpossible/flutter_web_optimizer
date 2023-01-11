import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_web_optimizer/src/optimize/flutter_web_optimizer.js.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as path;

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

    final File mainDartJsFile = outputDir
        .listSync()
        .whereType<File>()
        .singleWhere(
            (File entity) => path.basename(entity.path) == 'main.dart.js');
    await _splitMainDartJS(mainDartJsFile);

    _replaceFlutterJS();

    _hashAssets();

    _importFlutterWebOptimizerJS();

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
  Future<void> _splitMainDartJS(File file) async {
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
      final Stream<List<int>> inputStream = file.openRead(startIndex, endIndex);
      inputStream.listen(
        (List<int> data) {
          raf.writeFromSync(data);
        },
        onDone: () {
          raf.flushSync();
          raf.closeSync();
          completer.complete(true);
        },
        onError: (dynamic data) {
          raf.flushSync();
          raf.closeSync();
          completer.complete(false);
        },
      );
      return completer.future;
    }

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

    /// 分片完成后删除 main.dart.js
    file.deleteSync();
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
    final String basename = path.basenameWithoutExtension(file.path);
    final String extension = path.extension(file.path);
    final String filename = '$basename.$md5Hash$extension';
    Logger.info('hashed file name: $filename');
    return filename;
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
      // 文件名使用hash值
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

    // 需要修正源码中关联的文件引用
    final Map<String, File> amendSourceCodeRelatedFiles = <String, File>{};

    // 读取资源清单文件
    final File assetManifest =
        File(path.join(_webOutput, 'assets', 'AssetManifest.json'));
    String assetManifestContents = assetManifest.readAsStringSync();
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
      assetManifestContents = assetManifestContents.replaceFirstMapped(
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
        amendSourceCodeRelatedFiles[key] = file;
      }
    });

    // 写入修改后的资源、字体清单文件
    assetManifest.writeAsStringSync(assetManifestContents);
    fontManifest.writeAsStringSync(fontManifestContents);

    // 将AssetManifest.json文件进行md5
    String assetManifestFileName = 'AssetManifest.json';
    final File assetManifestFile =
        File(path.join(_webOutput, 'assets', assetManifestFileName));
    amendSourceCodeRelatedFiles[assetManifestFileName] = assetManifestFile;

    // 将FontManifest.json进行md5
    String fontManifestFileName = 'FontManifest.json';
    final File fontManifestFile =
        File(path.join(_webOutput, 'assets', fontManifestFileName));
    amendSourceCodeRelatedFiles[fontManifestFileName] = fontManifestFile;

    // 需要修正源码中关联的字符串引用
    final Map<String, String> amendSourceCodeRelatedStrings =
        <String, String>{};
    amendSourceCodeRelatedFiles.forEach((String key, File value) {
      String newKey = key.replaceFirstMapped(
        RegExp('(.*)($key)(.*)'),
        (Match match) => replace(match, value, key, _hashFiles),
      );
      if (newKey.startsWith('./')) {
        newKey = newKey.substring(1);
      }
      amendSourceCodeRelatedStrings[key] = newKey;
    });

    Directory(_webOutput).listSync().whereType<File>() // 文件类型
        .where((File file) {
      final String filename = path.basename(file.path);
      return RegExp(
              r'(main\.dart(.*)\.js)|(favicon.png)|(flutter.js)|(manifest.json)')
          .hasMatch(filename);
    }).forEach((File file) {
      final String basename = path.basename(file.path);
      if (RegExp(r'^main\.dart(.*)\.js$').hasMatch(basename)) {
        // 查找 main.dart_xxx.js 和 main.dart.xxx.part.js 文件
        // 修正修正源码中关联的字符串引用
        String contents = file.readAsStringSync();
        amendSourceCodeRelatedStrings.forEach((String key, String value) {
          contents = contents.replaceAll(RegExp(key), value);
        });
        file.writeAsStringSync(contents);
      }
      final String filename = _md5File(file);
      _hashFiles[file.path] = path.join(path.dirname(file.path), filename);
    });

    // 重命名文件
    _hashFiles.forEach((String key, String value) {
      File(key).renameSync(value);
    });
  }

  /// 导入flutter_web_optimizer.js
  void _importFlutterWebOptimizerJS() {
    // 哈希化后的main.dart.js && main.dart.xxx.part文件
    final Map<String, String> jsManifest = <String, String>{};

    // 排序后生成 _hashFileManifest 和 jsManifest
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

  /// 修改 index.html
  void _injectToHtml() {
    /// 读取index.html
    final File file = File('$_webOutput/index.html');
    String contents = file.readAsStringSync();

    /// 解析 index.html 为 Document
    final Document document = parse(contents);

    final Element? headElement = document.head;
    if (headElement != null) {
      /// 注入 assetBase meta 标签
      void injectAssetBaseMeta(Element element) {
        final Element meta = Element.tag('meta');
        meta.attributes['name'] = 'assetBase';
        meta.attributes['content'] = _assetBase;

        element.append(Text('\n'));
        element.append(Comment('content值必须以 / 结尾'));
        element.append(Text('\n'));
        element.append(meta);
        element.append(Text('\n'));
      }

      final List<Element> metas = document.getElementsByTagName('meta');
      if (metas.isNotEmpty) {
        injectAssetBaseMeta(metas.last);
      } else {
        injectAssetBaseMeta(headElement);
      }
    }

    if (headElement != null) {
      /// 注入 flutter_web_optimizer.js script
      final Element script = Element.tag('script');
      script.attributes['src'] = 'flutter_web_optimizer.js';
      script.attributes['defer'] = '';

      final List<Element> scripts = document.getElementsByTagName('script');
      if (scripts.length > 1) {
        final Element firstScript = scripts.first;
        headElement.insertBefore(script, firstScript);
        headElement.insertBefore(Text('\n'), firstScript);
      } else {
        headElement.append(script);
        headElement.append(Text('\n'));
      }
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

    // 查找所有元素
    final List<Element> elements = document.querySelectorAll('*');
    for (final Element element in elements) {
      if (element.attributes.containsKey('href')) {
        String href = element.attributes['href']!;
        final bool isAbsolute = !<String>['manifest.json'].contains(href);
        href = replace(href, isAbsolute: isAbsolute);
        element.attributes['href'] = href;
      }
      if (element.attributes.containsKey('src')) {
        String src = element.attributes['src']!;
        src = replace(src);
        element.attributes['src'] = src;
      }
    }

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
