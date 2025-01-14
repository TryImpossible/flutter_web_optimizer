const String flutterWebOptimizerSourceCode = r'''
    // The code below is injected by flutter web optimizer, do not edit!!!!!!

    // window.assetBase
    var assetBase = null;
    
    // window.mainjsManifest
    var mainjsManifest = null;
    
    // window.hashFileManifest
    var hashFileManifest = null;

    // window.deferredLibraryParts
    var deferredLibraryParts = {};

    // window.deferredPartUris
    var deferredPartUris = [];
    
    // hook dynamic create element `src` `href` property
    (function(){
      var _defineProperty = function (element, property) {
        var value;
        Object.defineProperty(element, property, {
          get: function () {
            return element.getAttribute(property);
          },
          set: function (v) {
            value = v;
            if (typeof v === 'string') {
              if (v.startsWith(assetBase)) {
                v = v.replace(assetBase, '');
              }
              if (v.startsWith('./')) {
                v = v.replace('./', '');
              }
              if (hashFileManifest[v]) {
                value = assetBase + hashFileManifest[v];
              }
            }
            element.setAttribute(property, value);
          }
        })
    
        var _setAttribute = element.setAttribute;
        element.setAttribute = function () {
          var args = Array.prototype.slice.call(arguments);
          // if (args[0] === 'src') {
          //   //do something here
          //   console.log('setAttribute', args[1])
          // }
          _setAttribute.apply(element, args);
        }
      }
    
      var _createElement = document.createElement;
      var _hookProperties = {'link': 'href', 'script': 'src', 'audio': 'src', 'video': 'src', 'map': 'src', 'img': 'src'};
      document.createElement = function (tagName) {
        var element = _createElement.call(document, tagName);
        var property = _hookProperties[tagName.toLowerCase()];
        if (property) {
          _defineProperty(element, property);
        }
        return element;
      }
    })();

    // preload main.dart.js_xxx.part js when page initialize
    (function(){
      var path;
      if (window.location.hash) {
        var hash = window.location.hash.substring(2);
        path = hash.split('?')[0];
      } else {
        var pathname = window.location.pathname;
        path = pathname.substring(pathname.lastIndexOf('/') + 1)
      }
      if (deferredLibraryParts[path]) {
        for (var index in deferredLibraryParts[path]) {
          // console.info('load main.dart.js_xxx.part: ' + deferredPartUris[index] + 'Date.now: ' + Date.now());
          dartDeferredLibraryLoader(deferredPartUris[index], null, null, path, null)
        }
      }
    })();
    
    // load main.dart.js_xxx.part js
    function dartDeferredLibraryLoader(uri, successCallback, errorCallback, loadId, loadPriority) {
      console.info('uri: ' + uri + ', loadId: '+ loadId + ', loadPriority: '+ loadPriority);
    
      var key = uri.toString().replace(/(.*)(main\.dart\.(.+)\.js)/g, '$2');
      var src = assetBase + mainjsManifest[key];
    
      var script = document.createElement("script");
      script.type = "text/javascript";
      script.src = src;
      script.addEventListener("load", successCallback, false);
      script.addEventListener("error", errorCallback, false);
      document.body.appendChild(script);
    }

    function dartDeferredLibraryMultiLoader(uris, successCallback, errorCallback, loadId, loadPriority) {
      // console.info('load main.dart.js_xxx.part: ' + uris + 'Date.now: ' + Date.now());
      console.info('uris: ' + uris + ', loadId: '+ loadId + ', loadPriority: '+ loadPriority);
      if (Object.prototype.toString.call(uris) === '[object Array]') {
        for (var index in uris) {
          dartDeferredLibraryLoader(uris[index], successCallback, errorCallback, loadId, loadPriority);
        }
      }
    }
    ''';
