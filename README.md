[中文文档](README.zh.md)

## Intro

A optimization tools for flutter web，solved web page loading slow and browser cache problem.

## Features

![app_web_optimizer](https://github.com/TryImpossible/flutter_web_optimizer/raw/main/20230111-172132.png)

- split large file and cdn resource file，optimize web page loading slow.
- hashed resource file，solve browser cache problem.

## Getting started

```yaml
dev_dependencies:
  flutter_web_optimizer: ^1.1.8
```

## Usage

![app_web_optimizer](https://github.com/TryImpossible/flutter_web_optimizer/raw/main/20221124-183101.png)

navigate to the root directory of the project，execute `plugin` and `optimize` command

### plugin command

the `plugin` command support auto generate plugin template files，then upload resources files to file
servers，such as such as Tencent COS and Alibaba OSS

```shell
flutter pub run flutter_web_optimizer plugin --path scripts/test_plugin.dart
```

- `path` parameter required，refers to `plugin` file path.

### optimize command

`optimize` command support split large file、hashing resource file and cdn resource file.

```shell
flutter pub run flutter_web_optimizer optimize --asset-base http://192.168.101.93:9091/app/ --plugin scripts/test_plugin.dart
```

or

```shell
flutter pub run flutter_web_optimizer optimize --asset-base http://192.168.101.93:9091/app/ --plugin flutter_web_cos_upload_plugin
```

- `asset-base` parameter required，refers to file server internet address，**it's must end with '/'**
- `web-output` parameter not required，refers to `flutter web build` generated artifact path, default
  as `build/web`.
- `plugin` parameter not required，if needs upload resource file to file server，it's must be
  required. it support file mode and plugin mode
    - file mode: it's refers to plugin file
      path. [cos_upload_plugin.dart](example/scripts/cos_upload_plugin.dart) provide a example
      upload resource file to tencent cos.
    - plugin mode: it's refers to plugin name.
      check [flutter_web_cos_upload_plugin](https://pub.flutter-io.cn/packages/flutter_web_cos_upload_plugin)
      for how to use it 
