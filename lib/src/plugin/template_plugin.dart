const String templatePluginSourceCode = r'''
import 'dart:isolate';

import 'package:flutter_web_optimizer/flutter_web_optimizer.dart';

/// [arguments] shell args from flutter pub run flutter_web_optimizer optimize
/// eq: flutter pub run flutter_web_optimizer optimize --asset-base http://192.168.101.93:9091/app/ --plugin scripts/cos_upload_plugin.dart
///
/// The template code is generate by flutter web optimizer 
Future<void> main(List<String> arguments, SendPort sendPort) async {
  // create a new [ReceivePort] instance
  ReceivePort receivePort = ReceivePort();
  // send [receivePort.sendPort] to server for exchnage message
  sendPort.send(receivePort.sendPort);
  // [receivePort] listen for message 
  receivePort.listen((dynamic message) {
    print('client isolate get message: $message');
    if (message is Map<String, Object>) {
      final IsolateMessageProtocol protocol = IsolateMessageProtocol.fromMap(message);
      // you can write you business code here
      // just an example
      // if (protocol.action == IsolateMessageAction.cdnAssets) {
      //   final String assetBase = arguments[1]; // asset-base from command args
      //   final IsolateMessageProtocol response =
      //       IsolateMessageProtocol.response(IsolateMessageAction.cdnAssets);
      //   sendPort.send(response.toMap());
      // }
    }
  });
}
''';
