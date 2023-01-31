一个命令行工具，针对`flutter web`加载慢和缓存问题提供了一套解决方案。

## 功能

![app_web_optimizer](https://github.com/TryImpossible/flutter_web_optimizer/raw/main/20230111-172132.png)

- 通过大文件分片和资源文件cdn化方式，优化`flutter web`页面加载慢问题。
- 通过资源文件hash化，解决浏览器强缓存导致功能无法更新问题。

## 开始

在工程的`pubspec.yaml`文件中添加`flutter_web_optimizer`插件

```yaml
dev_dependencies:
  flutter_web_optimizer: ^1.1.8
```

## 用法

![app_web_optimizer](https://github.com/TryImpossible/flutter_web_optimizer/raw/main/20221124-183101.png)

在项目的根目录下执行`plugin`命令和`optimize`命令

### plugin 命令

`plugin`命令实现自动生成插件模板文件，可以在插件里面实现将资源文件上传至文件服务器上，例如腾讯的cos、阿里的oss；

```shell
flutter pub run flutter_web_optimizer plugin --path scripts/test_plugin.dart
```

- `path`参数必传，指自定义`plugin`文件的位置。

### optimize 命令

`optimize`命令针对`flutter build web`的打包产物作了大文件分片下载、资源文件hash化和资源文件cdn化三个优化。

```shell
flutter pub run flutter_web_optimizer optimize --asset-base http://192.168.101.93:9091/app/ --plugin scripts/test_plugin.dart
```

or

```shell
flutter pub run flutter_web_optimizer optimize --asset-base http://192.168.101.93:9091/app/ --plugin flutter_web_cos_upload_plugin
```

- `asset-base`参数必传，一般是文件服务器上存储对应资源文件的地址，**地址必须是/结尾**
- `web-output`参数非必传，指`flutter web build`的打包产物的文件夹位置，以当前命令行窗口为根路径，默认是`build/web`。
- `plugin`参数非必传，若需要将资源文件上传至服务器，则必传。该参数支持文件模式和插件模式两种模式，
    - 文件模式：指插件的文件位置，以当前命令行窗口为根路径。[cos_upload_plugin.dart](example/scripts/cos_upload_plugin.dart)
      文件已经实现了一套将资源文件上传至腾讯的cos的功能，可以参考。
    - 插件模式：指插件的名称，用法参考[flutter_web_cos_upload_plugin](https://pub.flutter-io.cn/packages/flutter_web_cos_upload_plugin) 插件
