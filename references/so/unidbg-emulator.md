# UniDbg Native `.so` Emulation Guide

UniDbg is an ARM32/ARM64 CPU and Linux/Android syscall emulator allowing you to run Android native `.so` files in a pure JVM environment. It is ideal for reverse engineering proprietary cryptographic algorithms (sign, token, hash) and bypassing complex native protections without physical Android hardware.

---

## 1. Core Architecture & Workflow

1. **Initialize Emulator Instance**: Choose 32-bit (`AndroidARMEmulator`) or 64-bit (`AndroidARM64Emulator`).
2. **Setup Memory & Resolver**: Configure Android API Level (23, 26, etc.).
3. **Initialize Dalvik VM**: Load APK environment and register custom JNI handler (`AbstractJni`).
4. **Load Target Library**: `vm.loadLibrary("libtarget.so", true)`.
5. **Call JNI / Exported Native Functions**: Execute methods and extract return values.

---

## 2. Standard Implementation Template

```java
import com.github.unidbg.AndroidEmulator;
import com.github.unidbg.Module;
import com.github.unidbg.arm.backend.DynarmicFactory;
import com.github.unidbg.linux.android.AndroidARM64Emulator;
import com.github.unidbg.linux.android.AndroidEmulatorBuilder;
import com.github.unidbg.linux.android.AndroidResolver;
import com.github.unidbg.linux.android.dvm.*;
import com.github.unidbg.memory.Memory;

import java.io.File;

public class NativeSignService extends AbstractJni {
    private final AndroidEmulator emulator;
    private final VM vm;
    private final Module module;
    private final DvmClass dvmClass;

    public NativeSignService(String apkPath, String soPath) {
        // 1. Build ARM64 Emulator with Fast Dynarmic Backend
        emulator = AndroidEmulatorBuilder
                .for64Bit()
                .setProcessName("com.example.targetapp")
                .addBackendFactory(new DynarmicFactory(true))
                .build();

        // 2. Resolve Android System Libraries (libc, libm, libdl)
        Memory memory = emulator.getMemory();
        memory.setLibraryResolver(new AndroidResolver(23));

        // 3. Setup Dalvik VM with this instance as JNI handler
        vm = emulator.createDALVIKVM(new File(apkPath));
        vm.setJni(this);
        vm.setVerbose(false); // Enable for debugging missing JNI calls

        // 4. Load Target .so & trigger JNI_OnLoad
        DalvikModule dm = vm.loadLibrary(new File(soPath), true);
        module = dm.getModule();
        dm.callJNI_OnLoad(emulator);

        // 5. Resolve Java native binding class
        dvmClass = vm.resolveClass("com/example/targetapp/security/NativeSecurity");
    }

    public String computeSign(String url, String postData, long timestamp) {
        DvmObject<?> ret = dvmClass.callJniMethodObject(
                emulator,
                "signRequest(Ljava/lang/String;Ljava/lang/String;J)Ljava/lang/String;",
                new StringObject(vm, url),
                new StringObject(vm, postData),
                timestamp
        );
        return (String) ret.getValue();
    }
}
```

---

## 3. Implementing Missing JNI Methods (`AbstractJni`)

Native libraries frequently invoke Android Framework methods through JNI. When UniDbg encounters an unimplemented JNI method, it throws an exception specifying the class, method name, and signature:

```java
@Override
public DvmObject<?> callObjectMethodV(BaseVM vm, DvmObject<?> dvmObject, String signature, VaList vaList) {
    switch (signature) {
        case "android/app/ActivityThread->getApplication()Landroid/app/Application;":
            return vm.resolveClass("android/app/Application").newObject(null);
            
        case "android/content/Context->getPackageManager()Landroid/content/pm/PackageManager;":
            return vm.resolveClass("android/content/pm/PackageManager").newObject(null);
            
        case "android/content/pm/PackageManager->getPackageInfo(Ljava/lang/String;I)Landroid/content/pm/PackageInfo;":
            return vm.resolveClass("android/content/pm/PackageInfo").newObject(null);
            
        case "android/content/Context->getPackageName()Ljava/lang/String;":
            return new StringObject(vm, "com.example.targetapp");
            
        case "android/content/pm/PackageInfo->signatures:[Landroid/content/pm/Signature;":
            // Provide legitimate APK signature bytes to pass anti-tamper checks
            byte[] fakeCert = new byte[] { /* cert raw bytes */ };
            DvmObject<?> sigObj = vm.resolveClass("android/content/pm/Signature").newObject(fakeCert);
            return new ArrayObject(sigObj);
    }
    return super.callObjectMethodV(vm, dvmObject, signature, vaList);
}

@Override
public boolean callBooleanMethodV(BaseVM vm, DvmObject<?> dvmObject, String signature, VaList vaList) {
    if (signature.equals("java/lang/Boolean->booleanValue()Z")) {
        return (Boolean) dvmObject.getValue();
    }
    return super.callBooleanMethodV(vm, dvmObject, signature, vaList);
}
```

---

## 4. Hooking, Tracing & Debugging

### Dobby Hooking inside UniDbg
```java
import com.github.unidbg.hook.dobby.Dobby;

Dobby dobby = Dobby.getInstance(emulator);
dobby.replace(module.base + 0x1234, new ReplaceCallback() {
    @Override
    public HookStatus onCall(Emulator<?> emulator, HookContext context, long originFunction) {
        System.out.println("Intercepted internal function at offset 0x1234");
        return HookStatus.RET(emulator, 0);
    }
});
```

### Dynamic Code & Syscall Tracing
```java
// Trace assembly execution within target range
emulator.traceCode(module.base, module.base + module.size);

// Attach debugger breakpoint
emulator.attach().addBreakPoint(module.base + 0x5678, (emu, address) -> {
    System.out.println("Hit BP! Register X0 = " + emu.getBackend().reg_read(Arm64Const.UC_ARM64_REG_X0));
    return true; // Continue execution
});
```

---

## 5. Anti-Debugging and Syscall Bypasses

1. **Virtual Filesystem Mocks**: Bypass `/proc/self/status` or `/proc/self/maps` inspection by registering a custom `FileIOResolver`.
2. **Time Checks**: Intercept `clock_gettime` / `gettimeofday` to return steady sequential intervals.
3. **Thread Creation (`pthread_create`)**: Intercept and prevent watchdog / anti-debugging detection threads from spawning.
