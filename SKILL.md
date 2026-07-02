---
name: apk-reverse
description: >
  Performs Android APK reverse engineering in a CLI environment. Covers APK
  unpacking, Java decompilation, smali modification, rebuilding, Frida dynamic
  hooks, and native .so analysis. Use when the user wants to "reverse an APK",
  "decompile an Android app", "analyze APK logic", "hook Android methods with
  Frida", "bypass SSL pinning", "bypass root detection", "modify smali code",
  "rebuild and sign an APK", or "inspect AndroidManifest".
---

# APK Reverse Engineering CLI Work Specification

## Scope

Prefer this skill when the task belongs to one of the following scenarios:

- Analyze the Java business logic of an APK
- Locate login, signing, risk-control, certificate validation, or root-detection logic
- Inspect and modify `AndroidManifest.xml`
- Inspect and modify smali
- Rebuild an APK
- Use Frida for Java/native dynamic hooks
- Use NPatch for non-root Xposed module integration and method hooking
- Switch to native analysis when the APK contains `.so` files

## Required CLI Tools

- `jadx` (latest release recommended)
- `apktool` (latest release recommended)
- `frida` / `frida-ps` (latest via `pip install frida-tools`)
- `adb`
- `java` (JDK 11+)

## When to Prefer Scripts

The following workflows are frequent and error-prone, so prefer the scripts bundled with this skill. All scripts have both PowerShell (`.ps1`) and Bash (`.sh`) versions — use `.ps1` on Windows and `.sh` on Linux/macOS.

- Run `jadx + apktool` in one pass, write results to disk, and generate a summary: `scripts/decode.ps1` / `scripts/decode.sh`
- Frida device check, process listing, spawn/attach injection: `scripts/frida-run.ps1` / `scripts/frida-run.sh`
- Rebuild, align, sign, and install an APK: `scripts/rebuild-sign-install.ps1` / `scripts/rebuild-sign-install.sh`
- Quickly extract key Manifest components and permissions: `scripts/manifest-summary.ps1` / `scripts/manifest-summary.sh`

Keep the following one-line commands as direct calls without wrapping them in dedicated scripts:

- `adb devices`
- `adb logcat`
- `frida-ps -U`
- `jadx --version`
- `apktool --version`

## Bundled Scripts

### `scripts/decode.ps1` / `scripts/decode.sh`

Purpose:

- Run `jadx` and `apktool` through a unified entry point
- By default, create a task output directory next to the original APK
- Output a summary containing `package`, `java_files`, `smali_dirs`, `so_files`, and related fields
- Tolerate partial `jadx` decompilation errors when useful artifacts are still produced

Examples:

```powershell
# Windows (PowerShell)
pwsh -File ".\scripts\decode.ps1" -ApkPath "D:\DOWNLOAD\app.apk" -Clean
pwsh -File ".\scripts\decode.ps1" -ApkPath "D:\DOWNLOAD\app.apk" -Name demo -SkipJadx
```

```bash
# Linux/macOS (Bash)
bash scripts/decode.sh app.apk --clean
bash scripts/decode.sh app.apk --name demo --skip-jadx
```

### `scripts/frida-run.ps1` / `scripts/frida-run.sh`

Purpose:

- Provide a unified entry point for Frida devices, processes, spawn, and attach modes
- Avoid confusing handwritten parameters such as `-f`, `-n`, and `-U`

Examples:

```powershell
# Windows (PowerShell)
pwsh -File ".\scripts\frida-run.ps1" -ListDevices
pwsh -File ".\scripts\frida-run.ps1" -Usb -ListProcesses
pwsh -File ".\scripts\frida-run.ps1" -Usb -Spawn -Package com.example.app -ScriptPath "D:\hooks\test.js"
```

```bash
# Linux/macOS (Bash)
bash scripts/frida-run.sh --list-devices
bash scripts/frida-run.sh --usb --list-processes
bash scripts/frida-run.sh --usb --spawn --package com.example.app --script hooks/test.js
```

### `scripts/rebuild-sign-install.ps1` / `scripts/rebuild-sign-install.sh`

Purpose:

- Rebuild an APK with `apktool b`
- Align it with `zipalign`
- Sign and verify it with `apksigner`
- Optionally install it directly with `adb install`

Examples:

```powershell
# Windows (PowerShell)
pwsh -File ".\scripts\rebuild-sign-install.ps1" -ProjectDir "C:\work\apktool_out" -Clean
pwsh -File ".\scripts\rebuild-sign-install.ps1" -ProjectDir "C:\work\apktool_out" -Install -Reinstall -DeviceSerial "127.0.0.1:7555"
```

```bash
# Linux/macOS (Bash)
bash scripts/rebuild-sign-install.sh apktool_out --clean
bash scripts/rebuild-sign-install.sh apktool_out --install --reinstall --device "127.0.0.1:7555"
```

Notes:

- A debug keystore is generated and reused by default
- The default output is placed next to `ProjectDir`, making it easy to keep the original package, decoded directory, and rebuilt package together

### `scripts/manifest-summary.ps1` / `scripts/manifest-summary.sh`

Purpose:

- Extract the package name
- List permissions
- List activities, services, receivers, and providers
- Mark the main launcher activity

Example:

```powershell
# Windows (PowerShell)
pwsh -File ".\scripts\manifest-summary.ps1" -ManifestPath "C:\work\apktool_out\AndroidManifest.xml"
```

```bash
# Linux/macOS (Bash)
bash scripts/manifest-summary.sh --manifest work/apktool_out/AndroidManifest.xml
```

#### Output Format

All scripts output `key=value` lines to stdout. Component entries use tab-separated fields (`name\texported\tenabled`).

**decode scripts** produce: `task_root`, `jadx_out`, `apktool_out`, `package`, `jadx_exit_code`, `apktool_exit_code`, `java_files`, `smali_dirs`, `so_files`, `xml_files`, `warning` (on non-zero exit)

**manifest-summary scripts** produce: `package`, `permission_count`, `permission=...`, `activity_count`, `activity=name\texported\tenabled`, `service_count`, `service=...`, `receiver_count`, `receiver=...`, `provider_count`, `provider=...`, `main_activity=...`

**rebuild-sign-install scripts** produce: `unsigned_apk`, `aligned_apk`, `signed_apk`, `keystore`, `install_device` (if --install)

For `.so`, `lib/arm64-v8a/*.so`, or `lib/armeabi-v7a/*.so` analysis, combine this with:

- `ida-reverse`
- `radare2`

## Tool Responsibilities

### `jadx`

Used for:

- Java decompilation and reading
- Searching package names, class names, and method names
- Understanding high-level APK logic first

Common commands:

```bash
jadx -d jadx_out app.apk
jadx --single-class com.example.LoginActivity -d jadx_out app.apk
jadx --deobf -d jadx_out app.apk
```

### `apktool`

Used for:

- Decoding APKs
- Inspecting and modifying `AndroidManifest.xml`
- Inspecting and modifying smali
- Rebuilding APKs

Common commands:

```bash
apktool d app.apk -o apktool_out
apktool b apktool_out -o rebuilt.apk
```

### `frida`

Used for:

- Dynamically observing Java method calls
- Hooking native exported functions
- Bypassing root detection, certificate validation, and anti-debug checks

Common commands:

```bash
frida-ps -U
frida -U -f com.example.app -l hook.js
frida-trace -U -f com.example.app -j '*!*certificate*'
```

### `adb`

Used for:

- Device connection
- APK installation
- Log inspection
- File extraction

Common commands:

```bash
adb devices
adb install -r app.apk
adb shell pm list packages
adb logcat
adb pull /data/local/tmp/file .
```

### `NPatch`

Used for:

- Non-root Xposed module integration (rootless LSPosed framework)
- Method hooking without root access by injecting dex and so files into the target APK
- Patching APKs via CLI (`java -jar npatch.jar`) or Android manager app

Common commands:

```bash
# CLI patching (requires Java)
java -jar npatch.jar --input app.apk --output patched.apk
```

NPatch is an alternative to frida-gadget for users who prefer Xposed-style hooks without root. See [NPatch GitHub](https://github.com/7723mod/NPatch) for the full framework source and documentation. The patch output follows the same `rebuild-sign-install` workflow as apktool-modified APKs.

## Recommended Workflow

### 1. Triage

First determine the approximate structure of the APK. Do not rush into patching or hooking.

Recommended actions:

1. Export Java code with `jadx -d jadx_out app.apk`
2. Export smali and resources with `apktool d app.apk -o apktool_out`
3. Inspect:
   - `AndroidManifest.xml`
   - Main `package`
   - `application`, `activity`, `service`, and `receiver`
   - Whether the `lib/` directory contains `.so` files

### 2. Java Logic Observation

Prefer reading from `jadx_out` first:

- `MainActivity`
- `Application`
- Login, networking, encryption, and risk-control related classes
- Third-party SDK initialization classes

Common keywords:

- `login`
- `sign`
- `encrypt`
- `cipher`
- `token`
- `root`
- `certificate`
- `trust`
- `okhttp`
- `retrofit`
- `webview`

If the Java code is readable, locate the business logic there first.

### 3. Smali and Resource-Layer Confirmation

When `jadx` output is incomplete, heavily obfuscated, or an actual patch is required, switch to `apktool_out`:

- Inspect `smali*/`
- Inspect `res/values/strings.xml`
- Inspect `AndroidManifest.xml`

Patch priorities:

- `android:exported`
- Debug flags
- Root-detection return values
- Login validation logic
- Certificate-validation branches

### 4. Rebuild and Install

After modification:

```bash
apktool b apktool_out -o rebuilt.apk
```

Or use the script for the full loop:

```powershell
pwsh -File "<skill-root>\apk-reverse\scripts\rebuild-sign-install.ps1" -ProjectDir "apktool_out" -Install -Reinstall -DeviceSerial "127.0.0.1:7555"
```

Notes:

- This skill only guarantees the `apktool` rebuild path
- If the next step requires installing to a real device, a signing process is usually also required
- If the task enters signing/alignment, add `apksigner` / `zipalign`

### 5. Dynamic Hooking

When static analysis is insufficient, use Frida:

- Hook login functions
- Hook key points in `OkHttp` / `Retrofit` / `WebView`
- Hook `javax.crypto` and `MessageDigest`
- Hook root-detection functions
- Hook SSL pinning logic

Principles:

- Hook Java first, then evaluate whether native hooks are needed
- Print parameters and return values first, then decide whether to actively modify return values

Recommendations:

- Use simple one-off commands directly with `frida-*`
- Prefer `scripts/frida-run.ps1` for stable and reusable injection workflows

### 6. Native `.so` Routing

If the APK contains important `.so` files:

- Use `apktool` or `jadx` to locate `lib/**/*.so`
- Use `radare2` for exported symbols, strings, and quick triage
- Use `ida-reverse` for long-running deeper analysis, decompilation, renaming, and type recovery

Switch to native analysis as soon as possible when you see these signals:

- The Java layer is only a JNI wrapper
- The core signing logic is not in Java
- Key logic disappears after `System.loadLibrary()`
- Certificate validation or risk-control logic is inside `.so`

## Output Requirements

The final response must at least explain:

- Entry components and key classes
- Whether the key logic is in Java, smali, or `.so`
- Confirmed sensitive points: login, signing, root, SSL, WebView, JNI
- If a patch was made, what was changed
- If a hook was made, which class/method/exported function was hooked

## Prohibited Practices

- Do not blindly modify smali at the start
- Do not write hooks before checking the Manifest and main entry point
- Do not treat incomplete Java decompilation as proof that the logic cannot be analyzed
- Do not keep forcing Java-layer analysis when `.so` clearly carries the core logic

## Quick Command Notes

```bash
# Java decompilation
jadx -d jadx_out app.apk

# APK decoding
apktool d app.apk -o apktool_out

# APK rebuild
apktool b apktool_out -o rebuilt.apk

# Devices and processes
adb devices
frida-ps -U

# Start and inject
frida -U -f com.example.app -l hook.js
```

---

## Routing Context

This skill covers Java-layer APK analysis and Frida dynamic hooks. Route to other skills when:

- Core logic lives in `.so` files — use a native binary analysis skill (IDA, Ghidra, radare2)
- Dynamic hooking or validation is the primary task — use a dedicated Frida skill
- General reverse-engineering methodology guidance is needed — consult a broader reverse-engineering skill

---

## On-Demand Bootstrap

This skill's entry scripts can optionally install missing tools. When a required tool is not found, the bootstrap script asks the user before attempting automatic installation.

### Automation Boundaries

| Tool | Auto-install supported | Installation method | Notes |
|------|------------------------|---------------------|-------|
| jadx | ✓ | apt / brew / manual download | Windows: manual download from GitHub; Linux: `apt install jadx` |
| apktool | ✓ | apt / brew / manual download | Windows: manual download from apktool.org |
| frida / frida-ps | ✓ | pip install frida-tools | Requires Python to be installed |
| adb | ✓ | apt / brew / winget | Windows: winget; Linux: `apt install adb` |
| zipalign | ✗ | Manual Android Build-Tools installation required | `sdkmanager "build-tools;<version>"` |
| apksigner | ✗ | Manual Android Build-Tools installation required | Same as above |

### Bootstrap Trigger Points

- `scripts/decode.ps1` / `scripts/decode.sh`: prompts for install when jadx or apktool is missing
- `scripts/rebuild-sign-install.ps1` / `scripts/rebuild-sign-install.sh`: prompts when adb or apktool is missing
- `scripts/frida-run.ps1` / `scripts/frida-run.sh`: prompts when frida is missing

### When Bootstrap Fails

If automatic installation fails or the user declines, the script throws a clear error and includes manual installation links. Common reasons:

- Network unavailable (GitHub API / PyPI inaccessible)
- Package manager not available (winget on older Windows, no apt on non-Debian Linux)
- Java not installed (apktool depends on JDK)
