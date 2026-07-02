# Frida Practical Script Quick Reference

> Selected from open-source projects such as [awesome-frida](https://github.com/dweinstein/awesome-frida), [Frida-Mobile-Scripts](https://github.com/m0bilesecurity/Frida-Mobile-Scripts), and [frida-codeshare-scripts](https://github.com/zengfr/frida-codeshare-scripts).
> Categorized by scenario and ready to copy directly.

---

## Frida Gadget (Non-Root Devices)

When the target device cannot be rooted, use **frida-gadget** instead of frida-server:

1. Download `frida-gadget-<version>-android-<arch>.so` from [Frida releases](https://github.com/frida/frida/releases)
2. Embed the gadget into the APK's `lib/<arch>/` directory (e.g., `lib/arm64-v8a/libfrida-gadget.so`)
3. Add `System.loadLibrary("frida-gadget")` to the app's entry point (smali patch)
4. Optionally create `libfrida-gadget.config.so` in the same directory for script auto-loading:
   ```json
   {
     "interaction": { "type": "listen", "address": "127.0.0.1:27042" }
   }
   ```
5. Rebuild, sign, and install the APK — the gadget listens on the configured port

For automated gadget injection into an existing APK, use [objection](https://github.com/sensepost/objection) (`objection patchapk`).

> **Alternative:** [NPatch](https://github.com/7723mod/NPatch) provides a rootless LSPosed framework for Xposed-style hooking without frida. Use NPatch when you need Xposed module compatibility or prefer Java-level hooking through the LSPosed interface. See [NPatch GitHub](https://github.com/HSSkyBoy/NPatch) for details.

---

## General Hook Templates

### Hook Any Java Method

```javascript
Java.perform(function() {
    var TargetClass = Java.use("com.target.ClassName");
    
    // Hook no-argument method
    TargetClass.methodName.implementation = function() {
        console.log("[*] methodName called");
        var ret = this.methodName();
        console.log("[*] return: " + ret);
        return ret;
    };
    
    // Hook method with arguments
    TargetClass.methodName.overload('java.lang.String', 'int').implementation = function(str, num) {
        console.log("[*] methodName(" + str + ", " + num + ")");
        var ret = this.methodName(str, num);
        console.log("[*] return: " + ret);
        return ret;
    };
});
```

### Hook Constructor

```javascript
Java.perform(function() {
    var TargetClass = Java.use("com.target.ClassName");
    TargetClass.$init.overload('java.lang.String').implementation = function(arg) {
        console.log("[*] new ClassName(" + arg + ")");
        this.$init(arg);
    };
});
```

### Enumerate All Methods

```javascript
Java.perform(function() {
    var TargetClass = Java.use("com.target.ClassName");
    var methods = TargetClass.class.getDeclaredMethods();
    methods.forEach(function(method) {
        console.log(method.toString());
    });
});
```

---

## Encryption / Signing Hooks

### Hook AES Encryption and Decryption

```javascript
Java.perform(function() {
    var Cipher = Java.use("javax.crypto.Cipher");
    
    Cipher.doFinal.overload('[B').implementation = function(input) {
        var mode = this.getOpmode ? this.getOpmode() : "?";
        console.log("[Cipher.doFinal] mode=" + mode);
        console.log("  input: " + bytesToHex(input));
        var result = this.doFinal(input);
        console.log("  output: " + bytesToHex(result));
        return result;
    };
    
    // Capture key
    var SecretKeySpec = Java.use("javax.crypto.spec.SecretKeySpec");
    SecretKeySpec.$init.overload('[B', 'java.lang.String').implementation = function(key, algo) {
        console.log("[SecretKeySpec] algo=" + algo + " key=" + bytesToHex(key));
        this.$init(key, algo);
    };
    
    // Capture IV
    var IvParameterSpec = Java.use("javax.crypto.spec.IvParameterSpec");
    IvParameterSpec.$init.overload('[B').implementation = function(iv) {
        console.log("[IvParameterSpec] iv=" + bytesToHex(iv));
        this.$init(iv);
    };
});

function bytesToHex(bytes) {
    var hex = [];
    for (var i = 0; i < bytes.length; i++) {
        hex.push(('0' + (bytes[i] & 0xFF).toString(16)).slice(-2));
    }
    return hex.join('');
}
```

### Hook MD5/SHA

```javascript
Java.perform(function() {
    var MessageDigest = Java.use("java.security.MessageDigest");
    
    MessageDigest.digest.overload('[B').implementation = function(input) {
        console.log("[MessageDigest.digest] algo=" + this.getAlgorithm());
        console.log("  input: " + bytesToHex(input));
        var result = this.digest(input);
        console.log("  hash: " + bytesToHex(result));
        return result;
    };
    
    MessageDigest.digest.overload().implementation = function() {
        console.log("[MessageDigest.digest] algo=" + this.getAlgorithm());
        var result = this.digest();
        console.log("  hash: " + bytesToHex(result));
        return result;
    };
});
```

### Hook HMAC

```javascript
Java.perform(function() {
    var Mac = Java.use("javax.crypto.Mac");
    
    Mac.doFinal.overload('[B').implementation = function(input) {
        console.log("[Mac.doFinal] algo=" + this.getAlgorithm());
        console.log("  input: " + bytesToHex(input));
        var result = this.doFinal(input);
        console.log("  mac: " + bytesToHex(result));
        return result;
    };
    
    Mac.init.overload('java.security.Key').implementation = function(key) {
        var keyBytes = key.getEncoded();
        console.log("[Mac.init] key=" + bytesToHex(keyBytes));
        this.init(key);
    };
});
```

---

## Network Request Hooks

### Hook OkHttp3 Requests / Responses

```javascript
Java.perform(function() {
    var OkHttpClient = Java.use("okhttp3.OkHttpClient");
    var Interceptor = Java.use("okhttp3.Interceptor");
    
    // Hook newCall to obtain request URL
    var RealCall = Java.use("okhttp3.RealCall");
    RealCall.execute.implementation = function() {
        var request = this.request();
        console.log("[OkHttp] " + request.method() + " " + request.url().toString());
        var headers = request.headers();
        for (var i = 0; i < headers.size(); i++) {
            console.log("  " + headers.name(i) + ": " + headers.value(i));
        }
        var response = this.execute();
        console.log("[OkHttp] Response: " + response.code());
        return response;
    };
});
```

### Hook URL Connections

```javascript
Java.perform(function() {
    var URL = Java.use("java.net.URL");
    URL.openConnection.overload().implementation = function() {
        console.log("[URL] " + this.toString());
        return this.openConnection();
    };
});
```

### Hook WebView

```javascript
Java.perform(function() {
    var WebView = Java.use("android.webkit.WebView");
    WebView.loadUrl.overload('java.lang.String').implementation = function(url) {
        console.log("[WebView.loadUrl] " + url);
        this.loadUrl(url);
    };
    
    WebView.evaluateJavascript.implementation = function(script, callback) {
        console.log("[WebView.evaluateJavascript] " + script.substring(0, 200));
        this.evaluateJavascript(script, callback);
    };
});
```

---

## Bypass-Class Hooks

### General SSL Pinning Bypass

```javascript
Java.perform(function() {
    // OkHttp3 CertificatePinner
    try {
        var CertificatePinner = Java.use("okhttp3.CertificatePinner");
        CertificatePinner.check.overload('java.lang.String', 'java.util.List').implementation = function() {
            console.log("[*] SSL Pinning bypassed (OkHttp3)");
        };
    } catch(e) {}
    
    // TrustManagerImpl
    try {
        var TrustManagerImpl = Java.use("com.android.org.conscrypt.TrustManagerImpl");
        TrustManagerImpl.verifyChain.implementation = function(untrustedChain) {
            console.log("[*] SSL Pinning bypassed (TrustManagerImpl)");
            return untrustedChain;
        };
    } catch(e) {}
    
    // X509TrustManager
    try {
        var X509TrustManager = Java.use("javax.net.ssl.X509TrustManager");
        var TrustManager = Java.registerClass({
            name: "com.bypass.TrustManager",
            implements: [X509TrustManager],
            methods: {
                checkClientTrusted: function() {},
                checkServerTrusted: function() {},
                getAcceptedIssuers: function() { return []; }
            }
        });
    } catch(e) {}
    
    // Network Security Config (Android 7+)
    try {
        var NetworkSecurityConfig = Java.use("android.security.net.config.NetworkSecurityConfig");
        NetworkSecurityConfig.isCleartextTrafficPermitted.implementation = function() { return true; };
    } catch(e) {}
});
```

### General Root Detection Bypass

```javascript
Java.perform(function() {
    // File.exists bypass
    var File = Java.use("java.io.File");
    var rootPaths = ["su", "Superuser", "magisk", "busybox", "xposed", 
                     "/system/xbin/su", "/system/bin/su", "/sbin/su",
                     "/data/local/xbin/su", "/data/local/bin/su"];
    
    File.exists.implementation = function() {
        var path = this.getAbsolutePath();
        for (var i = 0; i < rootPaths.length; i++) {
            if (path.toLowerCase().indexOf(rootPaths[i].toLowerCase()) !== -1) {
                console.log("[Root] Blocked: " + path);
                return false;
            }
        }
        return this.exists();
    };
    
    // Runtime.exec bypass
    var Runtime = Java.use("java.lang.Runtime");
    Runtime.exec.overload('java.lang.String').implementation = function(cmd) {
        if (cmd.indexOf("su") !== -1 || cmd.indexOf("which") !== -1) {
            console.log("[Root] Blocked exec: " + cmd);
            throw Java.use("java.io.IOException").$new("Permission denied");
        }
        return this.exec(cmd);
    };
    
    // Build.TAGS bypass
    var Build = Java.use("android.os.Build");
    Build.TAGS.value = "release-keys";
});
```

### Anti-Debugging Bypass

```javascript
Java.perform(function() {
    // Debug.isDebuggerConnected
    var Debug = Java.use("android.os.Debug");
    Debug.isDebuggerConnected.implementation = function() {
        console.log("[AntiDebug] isDebuggerConnected → false");
        return false;
    };
    
    // TracerPid detection bypass (native layer)
    var fopen = Module.findExportByName("libc.so", "fopen");
    Interceptor.attach(fopen, {
        onEnter: function(args) {
            this.path = args[0].readUtf8String();
        },
        onLeave: function(retval) {
            if (this.path && this.path.indexOf("/proc/") !== -1 && this.path.indexOf("/status") !== -1) {
                // You can further hook fgets to modify TracerPid
            }
        }
    });
});
```

### Emulator Detection Bypass

```javascript
Java.perform(function() {
    var Build = Java.use("android.os.Build");
    Build.FINGERPRINT.value = "google/walleye/walleye:8.1.0/OPM1.171019.011/4448085:user/release-keys";
    Build.MODEL.value = "Pixel 2";
    Build.MANUFACTURER.value = "Google";
    Build.BRAND.value = "google";
    Build.DEVICE.value = "walleye";
    Build.PRODUCT.value = "walleye";
    Build.HARDWARE.value = "walleye";
    
    // TelephonyManager
    var TelephonyManager = Java.use("android.telephony.TelephonyManager");
    TelephonyManager.getDeviceId.implementation = function() { return "352099001761481"; };
    TelephonyManager.getSubscriberId.implementation = function() { return "310260000000000"; };
    TelephonyManager.getSimSerialNumber.implementation = function() { return "89014103211118510720"; };
});
```

---

## Data Storage Hooks

### Hook SharedPreferences

```javascript
Java.perform(function() {
    var SharedPreferencesImpl = Java.use("android.app.SharedPreferencesImpl");
    
    SharedPreferencesImpl.getString.implementation = function(key, defValue) {
        var value = this.getString(key, defValue);
        console.log("[SP.get] " + key + " = " + value);
        return value;
    };
    
    var Editor = Java.use("android.app.SharedPreferencesImpl$EditorImpl");
    Editor.putString.implementation = function(key, value) {
        console.log("[SP.put] " + key + " = " + value);
        return this.putString(key, value);
    };
});
```

### Hook SQLite

```javascript
Java.perform(function() {
    var SQLiteDatabase = Java.use("android.database.sqlite.SQLiteDatabase");
    
    SQLiteDatabase.rawQuery.implementation = function(sql, args) {
        console.log("[SQL] " + sql);
        if (args) console.log("  args: " + JSON.stringify(args));
        return this.rawQuery(sql, args);
    };
    
    SQLiteDatabase.execSQL.overload('java.lang.String').implementation = function(sql) {
        console.log("[SQL.exec] " + sql);
        this.execSQL(sql);
    };
});
```

---

## Unpacking Hooks

### General DEX Dump

```javascript
Java.perform(function() {
    Java.enumerateClassLoaders({
        onMatch: function(loader) {
            try {
                var pathList = Java.cast(loader, Java.use("dalvik.system.BaseDexClassLoader")).pathList.value;
                var dexElements = pathList.dexElements.value;
                for (var i = 0; i < dexElements.length; i++) {
                    var dexFile = dexElements[i].dexFile.value;
                    if (dexFile) {
                        console.log("[DEX] " + dexFile.getName());
                        // Can further dump dex contents
                    }
                }
            } catch(e) {}
        },
        onComplete: function() {}
    });
});
```

### Hook ClassLoader.loadClass

```javascript
Java.perform(function() {
    var ClassLoader = Java.use("java.lang.ClassLoader");
    ClassLoader.loadClass.overload('java.lang.String').implementation = function(name) {
        if (name.indexOf("com.target") !== -1) {
            console.log("[ClassLoader] " + name);
        }
        return this.loadClass(name);
    };
});
```

---

## Utility Functions

```javascript
// Convert byte array to hexadecimal
function bytesToHex(bytes) {
    if (!bytes) return "null";
    var hex = [];
    for (var i = 0; i < bytes.length; i++) {
        hex.push(('0' + (bytes[i] & 0xFF).toString(16)).slice(-2));
    }
    return hex.join('');
}

// Print call stack
function printStack() {
    console.log(Java.use("android.util.Log").getStackTraceString(
        Java.use("java.lang.Throwable").$new()));
}

// Print all fields of an object
function printFields(obj) {
    var fields = obj.class.getDeclaredFields();
    fields.forEach(function(field) {
        field.setAccessible(true);
        try {
            console.log("  " + field.getName() + " = " + field.get(obj));
        } catch(e) {}
    });
}

// Search for class instances in memory
function findInstances(className) {
    Java.choose(className, {
        onMatch: function(instance) {
            console.log("[Instance] " + instance);
            printFields(instance);
        },
        onComplete: function() {}
    });
}
```

---

## References

| Resource | Description | Link |
|------|------|------|
| Frida official documentation | API reference | https://frida.re/docs/ |
| Frida CodeShare | Community script sharing | https://codeshare.frida.re/ |
| awesome-frida | Resource collection | https://github.com/dweinstein/awesome-frida |
| frida-codeshare-scripts | Large script collection from across the web | https://github.com/zengfr/frida-codeshare-scripts |
| Objection | Frida wrapper | https://github.com/sensepost/objection |
| r2frida | radare2 + Frida integration | https://github.com/nowsecure/r2frida |
