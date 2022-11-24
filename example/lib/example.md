### plugin
```shell
flutter pub run flutter_web_optimizer plugin --path scripts/test_plugin.dart
or
flutter_web_optimizer plugin --path scripts/test_plugin.dart
```

### optimize
```shell
flutter pub run flutter_web_optimizer optimize --asset-base http://192.168.101.93:9091/app/ --plugin scripts/test_plugin.dart
or
flutter_web_optimizer optimize --asset-base http://192.168.101.93:9091/app/ --plugin scripts/test_plugin.dart
```