# Smali Modification & APK Patching Guide

This guide covers practical Dalvik bytecode (Smali) modification, common bypass patches (signature verification, VIP/license checks, root/debug flags, SSL pinning), log injection, and repackaging.

---

## 1. Smali Syntax & Register Basics

### Registers & Types
- `v0`, `v1`, ... : Local registers
- `p0`, `p1`, ... : Parameter registers (`p0` is `this` in non-static methods; `p0` is first argument in static methods)
- Primitive Types: `Z` (boolean), `I` (int), `J` (long, 2 registers), `F` (float), `D` (double, 2 registers), `V` (void)
- Object Types: `Ljava/lang/String;`, `Landroid/content/Context;`
- Array Types: `[B` (byte[]), `[Ljava/lang/String;`

### Common Instructions Cheatsheet
| Operation | Smali Instruction | Meaning |
|---|---|---|
| **Return Boolean True** | `const/4 v0, 0x1`<br>`return v0` | Returns `true` |
| **Return Boolean False** | `const/4 v0, 0x0`<br>`return v0` | Returns `false` |
| **Return Null Object** | `const/4 v0, 0x0`<br>`return-object v0` | Returns `null` |
| **Return Constant String** | `const-string v0, "mock_value"`<br>`return-object v0` | Returns `"mock_value"` |
| **Return Void** | `return-void` | Exits method immediately |
| **NOP Out Instruction** | `nop` | No operation (replaces checks) |
| **Unconditional Jump** | `goto :cond_target` | Force branch execution |
| **Conditional Branch Inversion** | `if-eqz v0, :cond_0` -> `if-nez v0, :cond_0` | Invert if condition |

---

## 2. Standard Patch Recipes

### Pattern 1: Bypass Boolean Checks (VIP / Root / Debug / License)
```smali
# Original method:
.method public isVip()Z
    .registers 2
    # ... lots of verification logic ...
    return v0
.end method

# Patched method (Force True):
.method public isVip()Z
    .registers 1
    const/4 v0, 0x1
    return v0
.end method
```

### Pattern 2: Bypass APK Signature Verification
When the app compares its current signature hash against a hardcoded hash:
```smali
# Method that checks APK signature:
.method public static verifyAppSignature(Landroid/content/Context;)Z
    .registers 2
    const/4 v0, 0x1
    return v0
.end method
```
Or when obtaining signature byte array or string, replace with original valid certificate string:
```smali
.method public static getSignatureString(Landroid/content/Context;)Ljava/lang/String;
    .registers 2
    const-string v0, "ORIGINAL_SHA256_OR_HEX_SIGNATURE"
    return-object v0
.end method
```

### Pattern 3: Bypass Dialog / Forced Upgrade / Kill Switch
Locate the method showing the blocking dialog or calling `System.exit(0)` / `finish()`:
```smali
.method public checkForceUpgrade()V
    .registers 1
    # Replace entire body with instant return
    return-void
.end method
```

### Pattern 4: Injecting Logcat Debug Statements
To print variable values or execution flow during runtime:
```smali
# 1. Ensure .locals or .registers has enough space (e.g. increase .locals count)
.locals 3

# 2. Add logging snippet:
const-string v0, "APK_DEBUG"
# Log variable v1 (assuming v1 is a String):
invoke-static {v0, v1}, Landroid/util/Log;->d(Ljava/lang/String;Ljava/lang/String;)I

# Or log non-string object via String.valueOf:
invoke-static {v1}, Ljava/lang/String;->valueOf(Ljava/lang/Object;)Ljava/lang/String;
move-result-object v1
invoke-static {v0, v1}, Landroid/util/Log;->d(Ljava/lang/String;Ljava/lang/String;)I
```

---

## 3. `AndroidManifest.xml` Modifications

### Enable Debugging & Backup
```xml
<application
    android:debuggable="true"
    android:allowBackup="true"
    android:networkSecurityConfig="@xml/network_security_config" ... >
```

### Allow User Certificates (Bypass SSL Pinning globally in Android 7+)
Create `res/xml/network_security_config.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="true">
        <trust-anchors>
            <certificates src="system" />
            <certificates src="user" />
        </trust-anchors>
    </base-config>
</network-security-config>
```

---

## 4. Rebuild, Align & Sign Workflow

```bash
# 1. Rebuild with apktool
apktool b apktool_out -o unsigned.apk

# 2. Zipalign (4-byte alignment required by Android OS)
zipalign -p -f -v 4 unsigned.apk aligned.apk

# 3. Sign using apksigner with custom debug keystore (v1 + v2 + v3 schemes)
apksigner sign --ks debug.keystore --ks-pass pass:android --ks-key-alias androiddebugkey --out signed.apk aligned.apk

# 4. Verify signature
apksigner verify -v signed.apk
```
