import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

String? appId, secretId, secretKey, bucketName, region;

/// 解析 flutter_web_cos_upload_plugin.yaml 文件
void main() {
  T getValue<T>(dynamic value) {
    if (value is! T) {
      throw Exception(
          'flutter_web_cos_upload_plugin.yaml incorrect [value] type error !!!');
    }
    return value;
  }

  final File file = File('${path.current}/flutter_web_cos_upload_plugin.yaml');
  if (!file.existsSync()) {
    throw Exception('flutter_web_cos_upload_plugin.yaml non-existent !!!');
  }
  final String contents = file.readAsStringSync();
  final dynamic doc = loadYaml(contents);
  if (doc is! Map) {
    throw Exception('flutter_web_cos_upload_plugin.yaml incorrect format !!!');
  }
  if (doc['cos'] is! Map) {
    throw Exception('flutter_web_cos_upload_plugin.yaml incorrect format !!!');
  }
  if (doc['cos']['config'] is! Map<dynamic, dynamic>) {
    throw Exception('flutter_web_cos_upload_plugin.yaml incorrect format !!!');
  }

  appId = getValue<String>(doc['cos']['config']['appId']);
  secretId = getValue<String>(doc['cos']['config']['secretId']);
  secretKey = getValue<String>(doc['cos']['config']['secretKey']);
  bucketName = getValue<String>(doc['cos']['bucketName']);
  region = getValue<String>(doc['cos']['region']);

  print('$appId, $secretId, $secretId, $bucketName, $region');
}
