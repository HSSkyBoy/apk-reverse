# apk-reverse

Claude Code skill for reverse engineering. Covers **Android APK decompilation**,
**native .so/ELF binary analysis**, and **general reverse engineering techniques**
(CTF patterns, language-specific RE, crypto tools, AI-assisted RE).

## Quick Start

```powershell
# Windows (PowerShell) — decode an APK
pwsh -File ".\scripts\decode.ps1" -ApkPath "C:\path\to\app.apk" -Clean

# Windows — rebuild, sign, and install
pwsh -File ".\scripts\rebuild-sign-install.ps1" -ProjectDir ".\apktool_out" -Install

# Windows — extract Manifest info
pwsh -File ".\scripts\manifest-summary.ps1" -ManifestPath ".\apktool_out\AndroidManifest.xml"

# Windows — Frida device listing and injection
pwsh -File ".\scripts\frida-run.ps1" -Usb -ListProcesses
pwsh -File ".\scripts\frida-run.ps1" -Usb -Spawn -Package com.example.app -ScriptPath ".\hooks\test.js"
```

```bash
# Linux/macOS (Bash) — decode an APK
bash scripts/decode.sh app.apk --clean

# Linux/macOS — rebuild, sign, and install
bash scripts/rebuild-sign-install.sh apktool_out --install

# Linux/macOS — extract Manifest info
bash scripts/manifest-summary.sh --manifest apktool_out/AndroidManifest.xml

# Linux/macOS — Frida device listing and injection
bash scripts/frida-run.sh --usb --list-processes
bash scripts/frida-run.sh --usb --spawn --package com.example.app --script hooks/test.js
```

## Prerequisites

| Tool | Purpose | Required By |
|------|---------|-------------|
| [jadx](https://github.com/skylot/jadx) | Java decompilation | APK |
| [apktool](https://apktool.org/) | APK decode/rebuild | APK |
| [frida-tools](https://frida.re/) | Dynamic instrumentation | APK + SO |
| [adb](https://developer.android.com/tools/adb) | Device interaction | APK |
| Java (JDK 11+) | Required by apktool and keytool | APK |
| [radare2](https://rada.re/r/) | Binary analysis | SO |
| [Ghidra](https://ghidra-sre.org/) | Decompilation | SO |

## Scripts

| Script | Windows (.ps1) | Linux/macOS (.sh) |
|--------|---------------|-------------------|
| Decode (jadx + apktool) | `scripts/decode.ps1` | `scripts/decode.sh` |
| Frida injection | `scripts/frida-run.ps1` | `scripts/frida-run.sh` |
| Rebuild, sign, install | `scripts/rebuild-sign-install.ps1` | `scripts/rebuild-sign-install.sh` |
| Manifest summary | `scripts/manifest-summary.ps1` | `scripts/manifest-summary.sh` |

## Non-Root APK Solutions

| Tool | Description |
|------|-------------|
| [frida-gadget](https://frida.re/docs/gadget/) | Embed Frida into the APK for non-root dynamic analysis |
| [NPatch](https://github.com/7723mod/NPatch) | Rootless LSPosed framework — insert dex/so for Xposed hooks without root |

All scripts output `key=value` lines to stdout. See [SKILL.md](SKILL.md) for
detailed output format documentation.

## References

### APK (Android)

| File | Content |
|------|---------|
| `references/apk/frida-cookbook.md` | Reusable Frida hook scripts by category |
| `references/apk/android-advanced.md` | Native SO, JNI, packers, Flutter/RN reversing |
| `references/apk/apk-security-checklist.md` | OWASP-aligned security testing checklist |
| `references/apk/frida-bypass-kit.md` | FridaBypassKit integration guide |

### SO (Native Binary Analysis)

| File | Content |
|------|---------|
| `references/so/elf-analysis.md` | ELF structure, headers, sections, dynamic linking |
| `references/so/go-reverse.md` | Go binary reversing (GoReSym, goroutines) |
| `references/so/kernel-driver-reverse.md` | Kernel driver reversing (Windows/Linux) |
| `references/so/tools.md` | GDB, radare2, Ghidra, Unicorn, .NET, packers |
| `references/so/tools-dynamic.md` | Frida, angr, lldb, Qiling, Triton |
| `references/so/tools-advanced.md` | VMProtect, BinDiff, deobfuscation, LLVM lifting |
| `references/so/anti-analysis.md` | Anti-debug, anti-VM, anti-DBI, integrity checks |
| `references/so/platforms-hardware.md` | ARM64/AArch64, RISC-V, MIPS |
| `references/so/languages-compiled.md` | Rust, Swift, Kotlin/Native, Haskell, C++ |

### General (Cross-Cutting)

| File | Content |
|------|---------|
| `references/general/patterns.md` | Custom VM, XOR, S-Box, LLVM obfuscation |
| `references/general/patterns-ctf.md` | CTF competition patterns (Part 1) |
| `references/general/patterns-ctf-2.md` | CTF competition patterns (Part 2) |
| `references/general/patterns-ctf-3.md` | CTF competition patterns (Part 3) |
| `references/general/languages.md` | Python bytecode, WASM, HarmonyOS, Brainfuck |
| `references/general/languages-platforms.md` | Android JNI, Electron, Node.js, Verilog |
| `references/general/platforms.md` | macOS/iOS, embedded/IoT, CAN bus |
| `references/general/crypto-decode-tools.md` | Ciphey, CyberChef, encoding/encryption tools |
| `references/general/field-notes.md` | Quick reference: binary types, anti-debug, patterns |
| `references/general/ai-assisted-re.md` | LLM4Decompile, Decaf, multi-agent decompilation |
| `references/general/awesome-re-resources.md` | Curated RE tool and tutorial lists |

## License

MIT — see [LICENSE](LICENSE).
