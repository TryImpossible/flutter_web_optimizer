/// isolate信息行为
class IsolateMessageAction {
  IsolateMessageAction.internal();

  /// 资源cdn化
  static String get cdnAssets => 'cdnAssets';
}

/// isolate通讯协议
class IsolateMessageProtocol {
  IsolateMessageProtocol.request(this.action, [this.data])
      : type = _requestProtocol;

  IsolateMessageProtocol.response(this.action, [this.data])
      : type = _responseProtocol;

  IsolateMessageProtocol._internal(this.type, this.action, [this.data]);

  static final String _requestProtocol = 'request';
  static final String _responseProtocol = 'response';

  String type;
  String action;
  Object? data;

  bool get isRequest => type == _requestProtocol;

  bool get isResponse => type == _responseProtocol;

  Map<String, Object> toMap() {
    return <String, Object>{
      'type': type,
      'action': action,
      if (data != null) 'data': data!,
    };
  }

  factory IsolateMessageProtocol.fromMap(Map<String, Object> map) {
    return IsolateMessageProtocol._internal(
      map['type'] as String,
      map['action'] as String,
      map['data'],
    );
  }
}
