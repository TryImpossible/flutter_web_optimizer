const String dartDeferredLibraryLoaderSourceCode = r'''
    // The code below is injected by flutter web optimizer, do not edit!!!!!!
    var assetBase = null;
    var jsManifest = null;
    function dartDeferredLibraryLoader(uri, successCallback, errorCallback, loadId) {
      console.log(`uri: ${uri}, loadId: ${loadId}`);
      let src;
      try {
        const url = new URL(uri);
        const key = url.pathname.replaceAll(/(.*)(main\.dart\.(.+)\.js)/g, '$2');
        src = `${assetBase}${jsManifest[key]}`;
      } catch (e) {
        const key = uri.replaceAll(/(.*)(main\.dart\.(.+)\.js)/g, '$2');
        src = `${assetBase}${jsManifest[key]}`;
      }
      
      script = document.createElement("script");
      script.type = "text/javascript";
      script.src = src;
      script.addEventListener("load", successCallback, false);
      script.addEventListener("error", errorCallback, false);
      document.body.appendChild(script);
    }
    ''';
