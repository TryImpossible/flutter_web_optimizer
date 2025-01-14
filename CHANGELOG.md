## 1.5.0

- the plugin is compatible with Flutter version 3.24 and above
- example project upgrade to flutter version 3.27.1
- fix bug，[issue](https://github.com/TryImpossible/flutter_web_optimizer/issues/34)

## 1.4.2

- example project upgrade to flutter version 3.22.1

## 1.4.1

- fix bug

## 1.4.0

- the plugin is compatible with Flutter 3.16
- support canvaskit renderer
- add `--enable-vconsole` args，support enable tencent vconsole tools

## 1.3.0

- the plugin is compatible with Flutter 3.10.5

## 1.2.0

- `flutter.js`compatible with flutter version 3.7
- `index.html`compatible with flutter version 3.7

## 1.1.12

- fix bug，[issue](https://github.com/TryImpossible/flutter_web_optimizer/issues/15)

## 1.1.11

- fix bug，[issue](https://github.com/TryImpossible/flutter_web_optimizer/issues/11)

## 1.1.10

- add `--hash-filter-regexp` args，support filtering file when hash file

## 1.1.9

- add `--enable-pwa` args enable experimental feature：PWA service worker，default to true

## 1.1.8

- insert `//@ sourceURL=main.dart.js` mark for debugging

## 1.1.7

- fix bug

## 1.1.6

- link external js and css files when using video_player、fluttertoast and other plugin，also support
  use hashed files
- support flutter_svg plugin use hashed svg resources
- `example` project introduce the supported features

## 1.1.5

- command support windows platform

## 1.1.4

- export window.hashFileManifest global variable
- use hashed resources when creating html element dynamically

## 1.1.3

- fix bug

## 1.1.2

- fix bug
- add english REMADME

## 1.1.1

- fix bug

## 1.1.0

- update `plugin` command，allow any plugin name
- update `optimize` command
    - modify web optimize steps
    - `--plugin` args support file mode and plugin mode
- update `example` project，test the usage of plugin mode

## 1.0.1

- update README
- add `example.md`

## 1.0.0

- add `plugin` command，auto generate plugin template file
- add `optimize` command，solve web page loading slow and browser cache problem
