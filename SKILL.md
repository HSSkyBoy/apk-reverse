---
name: apk-reverse
description: >
  Unified reverse engineering toolkit covering Android APK decompilation,
  native .so/ELF binary analysis, and general reverse engineering techniques.
  Use for APK unpacking, Java/smali modification, Frida hooking, native binary
  reversing, CTF challenges, and anti-analysis bypass.
---

# Reverse Engineering Toolkit

## Overview

This skill is organised into three major parts. Start with the part that
matches your target, then cross-reference as needed.

| Part | When to Use | Entry Point |
|------|-------------|-------------|
| **Part 1: APK** | Android APK reversing — Java/smali, AndroidManifest, Frida hooks, rebuild | Start here for any `.apk` |
| **Part 2: SO** | Native `.so` / ELF / PE / Mach-O binary analysis — GDB, r2, Ghidra, Unicorn, anti-debug | Switch here when core logic lives in native code |
| **Part 3: General** | CTF patterns, language-specific RE (Python/WASM/.NET), platform RE (macOS/IoT), crypto tools, AI-assisted RE | Reference here for non-APK, non-native RE tasks |

### Prerequisites

| Tool | Purpose | Part |
|------|---------|------|
| `jadx` | Java decompilation | APK |
| `apktool` | APK decode/rebuild | APK |
| `frida-tools` | Dynamic instrumentation | APK / SO |
| `adb` | Android device interaction | APK |
| `radare2` / `rizin` | CLI binary analysis | SO |
| `gdb` / `pwndbg` | Dynamic debugging | SO |
| `Ghidra` | Decompilation | SO |
| `angr` | Symbolic execution | SO |
| `Unicorn` / `Qiling` | Emulation | SO |

---

## Part 1: APK Reverse Engineering

### Tools

- `jadx` — Java decompilation and reading
- `apktool` — APK decode, smali inspection, rebuild
- `frida` / `frida-ps` — Dynamic Java method hooking
- `adb` — Device connection, install, logcat, file pull
- `NPatch` — Non-root Xposed module integration
- `apksigner` / `zipalign` — Signing and alignment (manual install via Android Build-Tools)

### Bundled Scripts

All scripts have PowerShell (`.ps1`) and Bash (`.sh`) versions. Use `.ps1` on
Windows, `.sh` on Linux/macOS.

| Script | Purpose |
|--------|---------|
| `scripts/decode.ps1` / `.sh` | Run `jadx` + `apktool` in one pass, write results to disk, generate summary |
| `scripts/frida-run.ps1` / `.sh` | Device check, process listing, spawn/attach injection |
| `scripts/rebuild-sign-install.ps1` / `.sh` | Rebuild, align, sign, and optionally install APK |
| `scripts/manifest-summary.ps1` / `.sh` | Extract key Manifest components and permissions |

#### Script Output Format

All scripts output `key=value` lines to stdout. Component entries use
tab-separated fields (`name\texported\tenabled`).

**decode scripts** produce: `task_root`, `jadx_out`, `apktool_out`, `package`,
`jadx_exit_code`, `apktool_exit_code`, `java_files`, `smali_dirs`, `so_files`,
`xml_files`, `warning` (on non-zero exit)

**manifest-summary scripts** produce: `package`, `permission_count`,
`permission=...`, `activity_count`, `activity=name\texported\tenabled`,
`service_count`, `service=...`, `receiver_count`, `receiver=...`,
`provider_count`, `provider=...`, `main_activity=...`

**rebuild-sign-install scripts** produce: `unsigned_apk`, `aligned_apk`,
`signed_apk`, `keystore`, `install_device` (if `--install`)

#### Script Examples

```powershell
# Windows (PowerShell)
pwsh -File ".\scripts\decode.ps1" -ApkPath "D:\DOWNLOAD\app.apk" -Clean
pwsh -File ".\scripts\frida-run.ps1" -Usb -Spawn -Package com.example.app -ScriptPath "D:\hooks\test.js"
pwsh -File ".\scripts\rebuild-sign-install.ps1" -ProjectDir "C:\work\apktool_out" -Install
pwsh -File ".\scripts\manifest-summary.ps1" -ManifestPath "C:\work\apktool_out\AndroidManifest.xml"
```

```bash
# Linux/macOS (Bash)
bash scripts/decode.sh app.apk --clean
bash scripts/frida-run.sh --usb --spawn --package com.example.app --script hooks/test.js
bash scripts/rebuild-sign-install.sh apktool_out --install
bash scripts/manifest-summary.sh --manifest apktool_out/AndroidManifest.xml
```

### Recommended Workflow

#### 1. Triage

Do not rush into patching or hooking. First determine the APK structure:

```bash
jadx -d jadx_out app.apk
apktool d app.apk -o apktool_out
```

Inspect:
- `AndroidManifest.xml` — package, application, activity, service, receiver
- `lib/` — whether `.so` files are present (if yes, check Part 2)
- Key permissions (network, root, SSL)

#### 2. Java Logic Observation

Read from `jadx_out` first. Key classes to examine:
- `MainActivity`, `Application`
- Login, networking, encryption, risk-control classes
- Third-party SDK initialisation

Common keywords: `login`, `sign`, `encrypt`, `cipher`, `token`, `root`,
`certificate`, `trust`, `okhttp`, `retrofit`, `webview`

#### 3. Smali / Resource Confirmation

When `jadx` output is incomplete or a patch is needed, switch to `apktool_out`:
- Inspect `smali*/`
- Inspect `res/values/strings.xml`
- Inspect `AndroidManifest.xml`

Patch priorities:
- `android:exported`
- Debug flags
- Root-detection return values
- Certificate-validation branches

#### 4. Rebuild & Install

```bash
apktool b apktool_out -o rebuilt.apk
```

Or use the full-loop script:
```powershell
pwsh -File ".\scripts\rebuild-sign-install.ps1" -ProjectDir "apktool_out" -Install -Reinstall
```

#### 5. Dynamic Hooking (Frida)

When static analysis is insufficient:
- Hook login functions
- Hook OkHttp / Retrofit / WebView
- Hook `javax.crypto` and `MessageDigest`
- Hook root-detection and SSL pinning

Recommendations:
- Hook Java first, then evaluate native hooks
- Print parameters and return values first, then modify if needed
- Prefer `scripts/frida-run.ps1` for stable injection

#### 6. Native .so Routing

If the APK contains important `.so` files, switch to **Part 2** when:
- The Java layer is only a JNI wrapper
- Core signing or crypto logic is not in Java
- Logic disappears after `System.loadLibrary()`
- Certificate validation or risk-control logic is inside `.so`

### Reference Files

- `references/apk/android-advanced.md` — Native SO/JNI, packers, Flutter/RN
- `references/apk/apk-security-checklist.md` — OWASP-aligned test checklist
- `references/apk/frida-bypass-kit.md` — FridaBypassKit integration guide
- `references/apk/frida-cookbook.md` — Reusable Frida hook scripts by category

---

## Part 2: Native Binary / .SO Analysis

Covers ELF, PE, Mach-O, and any native binary analysis. Use this when you are
working with `.so` files from an APK, standalone ELF binaries, or any compiled
native target.

### Tools

| Tool | Purpose | Common Commands |
|------|---------|-----------------|
| `radare2` / `rizin` | CLI disassembly, analysis, patching | `r2 ./binary`, `aaa`, `afl`, `pdf @ main` |
| `gdb` / `pwndbg` / `GEF` | Dynamic debugging | `gdb ./binary`, `start`, `b *main+0xca` |
| `Ghidra` | Headless decompilation | `analyzeHeadless project/ tmp -import binary -postScript script.py` |
| `Unicorn` | CPU emulation for code snippets | Python API, see reference notes |
| `Qiling` | Cross-platform emulation with OS support | `ql.run()` |
| `Frida` | Native function hooking, memory scanning | `frida binary`, `Interceptor.attach()` |
| `angr` | Symbolic execution, CFG recovery | `proj = angr.Project('./binary')` |

### Quick Wins (Try First)

```bash
# Plaintext extraction
strings binary | grep -iE "flag|secret|password"
rabin2 -z binary | grep -i "flag"

# Dynamic triage — often reveals behaviour without full reversing
ltrace ./binary
strace -f -s 500 ./binary

# Run with test inputs
./binary AAAA
echo "test" | ./binary
```

### Initial Analysis

```bash
file binary              # Type, architecture
checksec --file=binary   # Security features
rabin2 -I binary         # Binary info
strings binary           # Extract strings
```

### Analysis Workflow

1. **Strings extraction** — many easy targets have readable flags
2. **Dynamic triage** — `ltrace`/`strace` often reveals behaviour
3. **Frida hooking** — hook `strcmp`/`memcmp` to capture expected values
4. **Symbolic execution** — `angr` solves many flag-checkers automatically
5. **Emulation** — `Qiling`/`Unicorn` for foreign arch or anti-debug bypass
6. **Map control flow** — before modifying execution
7. **Automate** — via r2pipe, Frida, angr, Python scripting

### Key Topics & Reference Files

| Topic | File |
|-------|------|
| ELF structure, headers, sections, dynamic linking | `references/so/elf-analysis.md` |
| GDB, r2, Ghidra, Unicorn, Python bytecode, WASM, .NET, packers | `references/so/tools.md` |
| Frida, angr, lldb, x64dbg, Qiling, Triton, Intel Pin | `references/so/tools-dynamic.md` |
| VMProtect, Themida, BinDiff, deobfuscation, RetDec, LLVM lifting | `references/so/tools-advanced.md` |
| Linux/Windows anti-debug, anti-VM, anti-DBI, integrity checks | `references/so/anti-analysis.md` |
| Go binary reversing (GoReSym, memory layout, goroutines) | `references/so/go-reverse.md` |
| Kernel driver reversing (WDM, KMDF, minifilter, Linux .ko) | `references/so/kernel-driver-reverse.md` |
| Compiled languages (Rust, Swift, Kotlin/Native, Haskell, C++) | `references/so/languages-compiled.md` |
| ARM64/AArch64, RISC-V, MIPS, MBR/bootloader | `references/so/platforms-hardware.md` |

### Common Encryption Patterns

- XOR with single byte — try all 256 values
- XOR with known plaintext (`flag{`, `CTF{`)
- RC4 with hardcoded key
- Custom permutation + XOR
- XOR with position index (`^ i` or `^ (i & 0xff)`)

For more CTF-specific patterns, see `references/general/patterns*.md`.

### PIE Binary Debugging

```bash
gdb ./binary
start                    # Forces PIE base resolution
b *main+0xca            # Relative to main
run
```

### Memory Dumping Strategy

Let the program compute the answer, then dump it. Break at the final comparison
(`b *main+OFFSET`), enter any input of correct length, then `x/s $rsi` to dump
the computed value.

---

## Part 3: General Reverse Engineering

Cross-cutting reference material for CTF challenges, non-native RE targets,
and specialised techniques. Part 3 does not duplicate Part 2's tool guides;
it adds challenge patterns, language specifics, platform knowledge, and
meta-resources.

### CTF Challenge Patterns

| File | Content |
|------|---------|
| `references/general/patterns.md` | Custom VMs, XOR ciphers, S-Box, self-modifying code, LLVM obfuscation, anti-debug patterns |
| `references/general/patterns-ctf.md` | Emulator opcodes, LD_PRELOAD key extraction, RC4+VM loaders, kernel module mazes |
| `references/general/patterns-ctf-2.md` | Multi-layer decrypt, stack string deobfuscation, lattice/circuit patterns, ROP obfuscation |
| `references/general/patterns-ctf-3.md` | Z3 circuits, keyboard LED Morse, GLSL shader VM, BPF JIT, DNN inversion |

### Language-Specific Techniques

| File | Target Languages |
|------|-----------------|
| `references/general/languages.md` | Python bytecode, WASM, HarmonyOS HAP/ABC, Brainfuck/esolangs, UEFI, DOS, FRACTRAN |
| `references/general/languages-platforms.md` | Android JNI obfuscation, Electron, Node.js, Verilog, Ruby/Perl, Rust serde_json, Intel SGX |

### Platform-Specific Reversing

| File | Platforms |
|------|-----------|
| `references/general/platforms.md` | macOS/iOS (Mach-O, dyld, Swift), embedded/IoT (firmware, UART, RTOS), automotive CAN bus |

### Crypto & Encoding Tools

`references/general/crypto-decode-tools.md` — Ciphey, CyberChef, dcode.fr,
Base64/32/16, Caesar, Vigenère, XOR, AES weak keys, Morse, hash identification.
Written in Chinese (中文).

### AI-Assisted Reverse Engineering

`references/general/ai-assisted-re.md` — LLM4Decompile, Decaf (compiler-feedback
verification), constraint-guided multi-agent decompilation, REMEND equation
extraction. Written in Chinese (中文).

### Quick Reference

`references/general/field-notes.md` — Binary type identification (pyc, WASM,
APK, Flutter, .NET, UPX, Tauri), anti-debugging bypass, S-Box/keystream
patterns, custom VM analysis, signal-based binary exploration, x86-64 gotchas,
iterative solver patterns, Unicorn emulation notes.

### Resources

`references/general/awesome-re-resources.md` — Curated lists of RE tools,
tutorials, and communities (awesome-reversing, awesome-reverse-engineering,
malware-analysis resources, ARM exploitation guides).

---

## Bootstrap

This skill's scripts can optionally install missing tools. When a required tool
is not found, the bootstrap script asks before attempting automatic installation.

### Automation Boundaries

| Tool | Auto-install | Method | Notes |
|------|-------------|--------|-------|
| jadx | ✓ | apt / brew / manual | Windows: manual download from GitHub |
| apktool | ✓ | apt / brew / manual | Windows: manual download from apktool.org |
| frida-tools | ✓ | pip | Requires Python |
| adb | ✓ | apt / brew / winget | |
| zipalign | ✗ | Manual Android Build-Tools | `sdkmanager "build-tools;<version>"` |
| apksigner | ✗ | Manual Android Build-Tools | Same as above |
| radare2 | ✓ | apt / brew / winget | |
| gdb | ✓ | apt / brew | Windows: manual or WSL |
| Ghidra | ✗ | Manual download | Requires JDK 17+ |

### Bootstrap Trigger Points

- `scripts/decode.ps1` / `.sh` — prompts when jadx or apktool is missing
- `scripts/rebuild-sign-install.ps1` / `.sh` — prompts when adb or apktool is missing
- `scripts/frida-run.ps1` / `.sh` — prompts when frida is missing

### When Bootstrap Fails

If automatic installation fails or the user declines, the script throws a clear
error with manual installation links. Common reasons: network unavailable,
package manager not available, Java or Python not installed.

---

## Re-routing Logic

| You encounter… | Start here | Then route to… |
|----------------|------------|----------------|
| `.apk` file | **Part 1 (APK)** | Part 2 if `.so` contains core logic |
| `.so` / ELF / PE / Mach-O | **Part 2 (SO)** | Part 3 for CTF patterns or anti-debug |
| APK with `.so` files | **Part 1 (APK)** triage, then Part 2 for `.so` analysis | Part 3 for anti-analysis patterns |
| CTF reversing challenge | **Part 2 (SO)** triage | Part 3 for patterns / language specifics |
| Python bytecode, WASM, .NET | **Part 3 (General)** → `languages.md` | Part 2 if native tools needed |
| Anti-debug / anti-VM bypass | **Part 2 (SO)** → `anti-analysis.md` | |
| Symbolic execution / emulation | **Part 2 (SO)** → `tools-dynamic.md` | |
| Flutter / React Native APK | **Part 1 (APK)** → `android-advanced.md` | |

---

## Output Requirements

The final response must at least explain:

- **APK analysis:** entry components, key classes, whether key logic is in Java,
  smali, or `.so`, sensitive points (login, signing, root, SSL, WebView, JNI),
  what was patched or hooked
- **Native analysis:** binary type, architecture, notable functions/strings,
  anti-debug techniques encountered, bypass used, what was hooked or patched
- **General analysis:** challenge type, relevant patterns, toolchain used,
  solved approach

---

## Prohibited Practices

- Do not blindly modify smali at the start
- Do not write hooks before checking the Manifest and main entry point
- Do not treat incomplete Java decompilation as proof the logic cannot be analysed
- Do not keep forcing Java-layer analysis when `.so` clearly carries core logic
- Do not jump to full reverse engineering before trying strings and dynamic triage
- Do not use `angr` before understanding the binary's structure
