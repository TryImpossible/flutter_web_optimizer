export http_proxy=127.0.0.1:1087;
export https_proxy=$http_proxy;

# set http_proxy=http://127.0.0.1:1087
# set https_proxy=https://127.0.0.1:1087

flutter pub publish --dry-run -v --server=https://pub.dartlang.org
flutter pub publish --server=https://pub.dartlang.org
# flutter packages pub publish --server=https://pub.dartlang.org