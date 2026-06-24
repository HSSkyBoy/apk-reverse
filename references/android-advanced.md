# Android Advanced Reverse Engineering Reference

> Covers Native SO analysis, advanced Frida usage, SSL pinning bypass, root-detection countermeasures, packed-app unpacking, and Flutter/React Native reverse engineering.

---

## Native SO Reverse Engineering

### Analysis Workflow

```text
1. Extract .so files from the APK
   unzip app.apk lib/arm64-v8a/*.so -d extracted/

2. Confirm architecture and basic information
   file libxxx.so
   rabin2 -I libxxx.so

3. Find JNI entry points
   - Search for JNI_OnLoad (dynamic registration)
   - Search for Java_com_xxx_yyy (static registration)
   - nm -D libxxx.so | grep -i java

4. Load into IDA/Ghidra for analysis
   - Import JNI headers (jni.h types)
   - Annotate JNIEnv* parameters
   - Find RegisterNatives calls (dynamically registered function table)

5. Locate key logic
   - Trace from Java-layer native method names
   - Follow cross-references from strings (keys, URLs, error messages)
   - Trace calls to crypto library functions (AES/MD5/SHA)
```

### JNI Function Registration

```c
// Static registration: function name = Java_package_class_method
JNIEXPORT jstring JNICALL Java_com_example_app_Security_getSign(
    JNIEnv *env, jobject thiz, jstring input) { ... }

// Dynamic registration: call RegisterNatives inside JNI_OnLoad
static JNINativeMethod methods[] = {
    {"getSign", "(Ljava/lang/String;)Ljava/lang/String;", (void*)native_getSign},
};

JNIEXPORT jint JNI_OnLoad(JavaVM *vm, void *reserved) {
    JNIEnv *env;
    vm->GetEnv((void**)&env, JNI_VERSION_1_6);
    jclass clazz = env->FindClass("com/example/app/Security");
    env->RegisterNatives(clazz, methods, sizeof(methods)/sizeof(methods[0]));
    return JNI_VERSION_1_6;
}
```

### JNI Analysis Tips in IDA

```text
1. Import the JNI type library
   File → Load File → Parse C Header → jni.h

2. Annotate the first parameter as JNIEnv*
   Right-click parameter → Set type → JNIEnv*
   This allows calls such as env->FindClass / env->GetMethodID to be recognized automatically

3. Find RegisterNatives
   Search for calls to JNIEnv vtable offset 0x35C (ARM64)
   → The third argument is the JNINativeMethod array
   → Extract all native function addresses from the array
```

---

## Advanced Frida Usage

### Hook Native Functions

```javascript
// Hook libc function
Interceptor.attach(Module.findExportByName("libc.so", "open"), {
    onEnter: function(args) {
        this.path = args[0].readUtf8String();
        console.log("[open] " + this.path);
    },
    onLeave: function(retval) {
        if (this.path.includes("su") || this.path.includes("magisk")) {
            console.log("[open] Blocked root check: " + this.path);
            retval.replace(-1);  // Return failure
        }
    }
});

// Hook a function inside a custom SO
var base = Module.findBaseAddress("libsecurity.so");
var targetFunc = base.add(0x1234);  // Offset address
Interceptor.attach(targetFunc, {
    onEnter: function(args) {
        console.log("arg0: " + args[0].readUtf8String());
    },
    onLeave: function(retval) {
        console.log("return: " + retval.readUtf8String());
    }
});
```

### Hook Java Methods

```javascript
Java.perform(function() {
    // Hook instance method
    var Security = Java.use("com.example.app.Security");
    Security.getSign.implementation = function(input) {
        console.log("[getSign] input: " + input);
        var result = this.getSign(input);  // Call original method
        console.log("[getSign] output: " + result);
        return result;
    };

    // Hook constructor
    Security.$init.overload('java.lang.String').implementation = function(key) {
        console.log("[Security.<init>] key: " + key);
        this.$init(key);
    };

    // Hook overloaded method
    Security.encrypt.overload('java.lang.String', 'int').implementation = function(data, mode) {
        console.log("[encrypt] data=" + data + " mode=" + mode);
        return this.encrypt(data, mode);
    };
});
```

### Memory Search and Modification

```javascript
// Search for a string in memory
Process.enumerateModules().forEach(function(module) {
    if (module.name === "libtarget.so") {
        Memory.scan(module.base, module.size, "48 65 6C 6C 6F", {  // "Hello"
            onMatch: function(address, size) {
                console.log("Found at: " + address);
            }
        });
    }
});

// Modify memory (patch instruction)
var addr = Module.findBaseAddress("libsecurity.so").add(0x5678);
Memory.patchCode(addr, 4, function(code) {
    var writer = new Arm64Writer(code, {pc: addr});
    writer.putNop();  // Replace with NOP
    writer.flush();
});
```

---

## SSL Pinning Bypass

### General Approach (Recommended)

```javascript
// General Frida SSL Pinning bypass
// Source: https://github.com/0xCD4/SSL-bypass
Java.perform(function() {
    // 1. TrustManager bypass
    var TrustManager = Java.registerClass({
        name: 'com.custom.TrustManager',
        implements: [Java.use('javax.net.ssl.X509TrustManager')],
        methods: {
            checkClientTrusted: function(chain, authType) {},
            checkServerTrusted: function(chain, authType) {},
            getAcceptedIssuers: function() { return []; }
        }
    });

    // 2. Replace SSLContext
    var SSLContext = Java.use('javax.net.ssl.SSLContext');
    var sslContext = SSLContext.getInstance("TLS");
    sslContext.init(null, [TrustManager.$new()], null);

    // 3. OkHttp CertificatePinner bypass
    try {
        var CertificatePinner = Java.use('okhttp3.CertificatePinner');
        CertificatePinner.check.overload('java.lang.String', 'java.util.List').implementation = function() {};
    } catch(e) {}
});
```

### Framework-Specific Bypasses

| Framework | Bypass Method |
|------|---------|
| OkHttp3 | Hook `CertificatePinner.check` and return empty |
| Retrofit | Same as OkHttp because it uses OkHttp underneath |
| Volley | Hook the SSL factory used by `HurlStack` |
| Flutter | Hook `dart:io` `SecurityContext` (requires a special script) |
| React Native | Hook `OkHttpClientProvider` |
| WebView | Hook `WebViewClient.onReceivedSslError` |

### Flutter-Specific

```javascript
// Flutter SSL Pinning bypass (requires finding the ssl_verify_peer_cert function)
var flutter_lib = Module.findBaseAddress("libflutter.so");
// Search for the signature of ssl_verify_peer_cert
var pattern = "FF 03 05 D1 FD 7B 0F A9";  // ARM64 signature
Memory.scan(flutter_lib, Module.findModuleByName("libflutter.so").size, pattern, {
    onMatch: function(address) {
        Interceptor.replace(address, new NativeCallback(function() {
            return 0;  // Return success
        }, 'int', []));
    }
});
```

---

## Root Detection Bypass

### Common Detection Methods

| Detection Method | Bypass Method |
|---------|---------|
| Check `/system/app/Superuser.apk` | Hook `File.exists()` and return false |
| Check `su` command | Hook `Runtime.exec()` and intercept su calls |
| Check `/proc/self/mounts` | Hook file reads and filter Magisk-related entries |
| SafetyNet/Play Integrity | Magisk Hide / Zygisk + Shamiko |
| Check Magisk package name | Randomize Magisk package name |
| Check `/data/adb/` | Hook `opendir`/`access` |

### General Frida Root Bypass

```javascript
Java.perform(function() {
    // Hook File.exists
    var File = Java.use("java.io.File");
    File.exists.implementation = function() {
        var path = this.getAbsolutePath();
        var blacklist = ["su", "Superuser", "magisk", "busybox", "xposed"];
        for (var i = 0; i < blacklist.length; i++) {
            if (path.toLowerCase().includes(blacklist[i])) {
                return false;
            }
        }
        return this.exists();
    };

    // Hook System.getProperty
    var System = Java.use("java.lang.System");
    System.getProperty.overload('java.lang.String').implementation = function(key) {
        if (key === "ro.debuggable" || key === "ro.secure") {
            return "1";
        }
        return this.getProperty(key);
    };
});
```

---

## Packer/Shell Detection and Unpacking

### Common App Packers

| Packer | Identification Features | Unpacking Method |
|------|---------|---------|
| 360 Jiagu | `libjiagu.so`, `com.stub.StubApp` | FART / Frida dump dex |
| Tencent Legu | `libshell*.so`, `com.tencent.StubShell` | FART / BlackDex |
| Bangcle | `libDexHelper.so`, `com.secneo.apkwrapper` | FART |
| Ijiami | `libexec.so`, `s.h.e.l.l` | Frida dump |
| NetEase Yidun | `libnesec.so` | Frida dump |
| Naga | `libnaga.so` | Frida dump |

### General Unpacking Methods

```text
Method 1: FART (ART runtime unpacking)
- Flash a FART ROM or use the Frida version of FART
- Automatically dump all dex files loaded by ClassLoaders

Method 2: Frida DEX Dump
- frida -U -f com.target.app -l dex_dump.js
- Hook DexFile::OpenMemory and dump in-memory dex files

Method 3: BlackDex
- Rootless unpacking tool
- Install the BlackDex APK directly and select the target application to unpack

Method 4: Manual dump
- Use Frida to enumerate all ClassLoaders
- Locate the application's ClassLoader → obtain DexFile objects
- Read dex memory regions and save them
```

### Frida DEX Dump Script

```javascript
Java.perform(function() {
    Java.enumerateClassLoaders({
        onMatch: function(loader) {
            try {
                var dexFiles = loader.getDexFileList();
                console.log("ClassLoader: " + loader);
                console.log("  DEX files: " + dexFiles);
            } catch(e) {}
        },
        onComplete: function() {}
    });
});
```

---

## React Native / Flutter Reverse Engineering

### React Native

```text
1. Unpack the APK → assets/index.android.bundle (JS code)
2. Format the JS → search for API endpoints, keys, and signing logic
3. If Hermes bytecode exists (.hbc file) → decompile with hermes-dec
4. Hook: use Frida to hook the Java-layer ReactBridge
```

### Flutter

```text
1. Flutter code is compiled into libapp.so (Dart AOT)
2. It cannot be directly decompiled back to Dart source code
3. Analysis methods:
   - reFlutter tool: patch libflutter.so to obtain snapshot
   - Doldrums: parse Dart snapshot and recover class/function information
   - Frida hook key functions inside libflutter.so
4. Network analysis: Flutter does not use the system proxy and requires special SSL handling
```

---

## Tool Quick Reference

| Tool | Purpose | Installation |
|------|------|------|
| jadx | Java decompilation | Already in bootstrap |
| apktool | Decode/rebuild APK | Already in bootstrap |
| Frida | Dynamic hooks | `pip install frida-tools` |
| Objection | Frida wrapper for easier use | `pip install objection` |
| MobSF | Automated mobile security analysis | Docker deployment |
| BlackDex | Rootless unpacking | APK installation |
| FART | ART unpacking | Flash ROM or use Frida version |
| hermes-dec | Hermes bytecode decompilation | npm installation |
| reFlutter | Flutter reverse-engineering helper | pip installation |
| Magisk + Shamiko | Root hiding | Flash module |

---

## References

| Resource | Description | Link |
|------|------|------|
| OWASP MASTG | Mobile Application Security Testing Guide | https://mas.owasp.org/ |
| FridaBypassKit | General bypass framework | https://github.com/okankurtuluss/FridaBypassKit |
| SSL-bypass | General non-custom SSL bypass | https://github.com/0xCD4/SSL-bypass |
| awesome-frida | Frida resource collection | https://github.com/dweinstein/awesome-frida |
| Android Security Awesome | Android security resources | https://github.com/ashishb/android-security-awesome |
