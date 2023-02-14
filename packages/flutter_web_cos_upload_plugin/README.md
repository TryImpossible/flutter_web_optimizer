## Intro
A sub plug-in of flutter_web_optimizer，used to upload resources to cos

## Features

upload flutter web build artifact to tencent cos，such as image，javascript file and etc

## Getting started

```yaml
dev_dependencies:
  flutter_web_cos_upload_plugin: ^1.0.0
```

## Usage

flutter_web_cos_upload_plugin.yaml

```yaml
cos:
  config:
    appId: 'xxx'
    secretId: 'xxx'
    secretKey: 'xxx'
  bucketName: 'xxx'
  region: 'xxx'
```

1. copy `flutter_web_cos_upload_plugin.yaml` to your project root directory
2. fill in the correct appId，secretId，secretKey，bucketName and region
3. execute `flutter pub run flutter_web_optimizer optimize --asset-base xxx --plugin flutter_web_cos_upload_plugin` command
4. then the resources will be uploaded to tencent cos
