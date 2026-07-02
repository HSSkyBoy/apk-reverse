# apk-reverse

Claude Code skill for Android APK reverse engineering. Provides automation scripts and reference documentation for common reverse engineering workflows.

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

| Tool | Purpose |
|------|---------|
| [jadx](https://github.com/skylot/jadx) | Java decompilation |
| [apktool](https://apktool.org/) | APK decode/rebuild |
| [frida-tools](https://frida.re/) | Dynamic instrumentation |
| [adb](https://developer.android.com/tools/adb) | Device interaction |
| Java (JDK 11+) | Required by apktool and keytool |

## Scripts

| Script | Windows (.ps1) | Linux/macOS (.sh) |
|--------|---------------|-------------------|
| Decode (jadx + apktool) | `scripts/decode.ps1` | `scripts/decode.sh` |
| Frida injection | `scripts/frida-run.ps1` | `scripts/frida-run.sh` |
| Rebuild, sign, install | `scripts/rebuild-sign-install.ps1` | `scripts/rebuild-sign-install.sh` |
| Manifest summary | `scripts/manifest-summary.ps1` | `scripts/manifest-summary.sh` |

All scripts output `key=value` lines to stdout. See [SKILL.md](SKILL.md) for detailed output format documentation.

## References

| File | Content |
|------|---------|
| `references/frida-cookbook.md` | Reusable Frida hook scripts by category |
| `references/android-advanced.md` | Native SO, JNI, packers, Flutter/RN reversing |
| `references/apk-security-checklist.md` | OWASP-aligned security testing checklist |
| `references/frida-bypass-kit.md` | FridaBypassKit integration guide |

## License

MIT — see [LICENSE](LICENSE).
