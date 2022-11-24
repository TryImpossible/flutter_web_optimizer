// ignore_for_file: avoid_print
// ignore: avoid_classes_with_only_static_members

class Logger {
  Logger._internal();

  static void error(String msg) {
    print('❌  $msg');
  }

  static void success(String msg) {
    print('✅  $msg');
  }

  static void info(String msg) {
    print(msg);
  }
}
