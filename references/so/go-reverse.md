# Go Binary Reverse Engineering Guide

> Go-compiled binaries present unique challenges: static linking results in huge binary sizes, tens of thousands of functions, special string formats, and difficulty recovering symbols after stripping.
> This document covers the toolchain, recovery techniques, and practical workflows.

---

## Identifying Go Binaries

Quickly determine if a binary was compiled with Go:

```bash
# String characteristics
strings binary | grep -E "runtime\.|go\.buildid|GOROOT"

# rabin2 reconnaissance
rabin2 -z binary | grep -i "runtime"

# Abnormally large file size (statically linked runtime)
# Typical Hello World: C ~20KB, Go ~2MB
```

Common characteristics:
- Contains large number of functions prefixed with `runtime.`
- Contains `go.buildid` section
- Contains `GOROOT`, `GOPATH` path strings
- Function count 5000-50000+ (including entire runtime and standard library)

---

## Core Toolchain

### Symbol Recovery

| Tool | Purpose | Link |
|------|---------|------|
| **GoReSym** | By Mandiant, parses Go symbol information (pclntab/moduledata) | https://github.com/mandiant/GoReSym |
| **GoResolver** | By Volexity, uses CFG similarity to automatically deobfuscate Garble binaries | https://github.com/volexity/GoResolver |
| **redress** | Analyzes stripped Go binaries, recovers types/interfaces/package structure | https://github.com/goretk/redress |
| **GoStringUngarbler** | By Google, specialized in recovering Garble-obfuscated strings | https://github.com/mandiant/GoStringUngarbler |

### IDA Plugins

| Tool | Purpose | Link |
|------|---------|------|
| **go_parser** | IDA plugin, parses moduledata/pclntab/type information | https://github.com/0xjiayu/go_parser |
| **IDAGolangHelper** | IDA scripts, parses Go type information | https://github.com/sibears/IDAGolangHelper |
| **AlphaGolang** | SentinelLabs' IDAPython scripts | https://github.com/SentineLabs/AlphaGolang |
| **IDA 9.2+ Native Support** | Hex-Rays official Go decompilation improvements | https://hex-rays.com/blog/stop-guessing-and-start-going |

### Ghidra Plugins

| Tool | Purpose | Link |
|------|---------|------|
| **Ghidra + GoReSym Output** | Import symbols into Ghidra after exporting with GoReSym | Use together |
| **golang_loader_assist** | Ghidra Go loading assistant | Community script |

### Standalone Analysis Tools

| Tool | Purpose | Link |
|------|---------|------|
| **gore** | Go reverse engineering library (underlying library for redress) | https://github.com/goretk/gore |
| **garble** | Go obfuscation tool (understand it to counter it) | https://github.com/burrowers/garble |

---

## Key Structures of Go Binaries

### pclntab (PC Line Table)

The most important structure in Go binaries, contains:
- All function name and address mappings
- Source file paths
- Line number information
- Stack frame sizes

Even after stripping symbols, pclntab usually still exists (Go runtime depends on it).

```text
Locating methods:
1. Search for magic bytes: 0xFFFFFFF0 (Go 1.16+) or 0xFFFFFFFB (Go 1.18+)
2. Automatically locate with GoReSym
3. Automatically parse with go_parser IDA plugin
```

### moduledata

Contains:
- pclntab pointer
- Type information table
- itab (interface table)
- Global variable information

### String Format

Go strings are not C-style null-terminated, but use a `(pointer, length)` structure:

```text
C string:    "hello\0"
Go string:   struct { ptr *byte; len int } -> ptr points to "hello" (no \0)
```

This causes IDA/Ghidra's default string recognition to miss many Go strings.

**Solutions**:
- Use `go_parser` to auto-identify Go strings
- Use GoReSym to export string list
- Manual: find `runtime.stringtable` or locate via cross-references

---

## Practical Workflows

### Scenario 1: Unstripped Go Binary

```text
1. GoReSym -t -d -p binary > symbols.json
   -> Export all function names, types, source file paths
2. Load into IDA/Ghidra
3. Import GoReSym's symbol information
4. Filter out runtime.* and standard library functions, focus on user code
5. Start analysis from main.main
```

### Scenario 2: Stripped Go Binary

```text
1. GoReSym -t -d -p binary > symbols.json
   -> Even if stripped, pclntab is usually still there
2. If GoReSym fails -> use redress
   redress -src binary    # Recover source file paths
   redress -pkg binary    # Recover package structure
   redress -type binary   # Recover type information
3. Load into IDA + go_parser plugin
4. Run go_parser auto-recovery
5. Start from the recovered main.main
```

### Scenario 3: Garble-obfuscated Go Binary

```text
Garble will:
- Randomize function names (main.main -> main.a3f2b1c)
- Encrypt strings
- Remove file path information
- Obfuscate package names

Countermeasures:
1. GoResolver (CFG signature matching)
   -> Recover standard library function names via CFG similarity
2. GoStringUngarbler (string decryption)
   -> Automatically identify and decrypt Garble's string encryption patterns
3. Dynamic analysis (Frida/dlv)
   -> Hook runtime functions to observe actual behavior
4. Comparative analysis
   -> Compile Hello World with same Go version, use binary-diff to compare runtime portions
```

### Scenario 4: CGo Mixed Compilation

```text
1. Identify CGo boundaries (_cgo_* functions)
2. Recover Go part with go_parser
3. Analyze C part with conventional IDA
4. Focus on bridge functions like _cgo_topofstack, crosscall2
```

---

## Common Command Quick Reference

```bash
# GoReSym: export symbols
GoReSym -t -d -p binary > symbols.json
GoReSym -t -d -p binary -o ida_script.py  # Generate IDA script

# redress: analyze stripped binary
redress -src binary          # Source file paths
redress -pkg binary          # Package structure
redress -type binary         # Type information
redress -interface binary    # Interface information
redress -filepath binary     # Full file path

# GoResolver: deobfuscate Garble
GoResolver -binary binary -output resolved.json

# GoStringUngarbler: decrypt Garble strings
GoStringUngarbler -i binary -o deobfuscated_binary

# Quick Go version detection
strings binary | grep "go1\."
GoReSym -p binary | grep "Version"
```

---

## Go Analysis Workflow in IDA

```text
1. Load the binary (select correct architecture)
2. Wait for automatic analysis to complete
3. Run go_parser plugin:
   - File -> Script File -> go_parser.py
   - or Edit -> Plugins -> Go Parser
4. The plugin will automatically:
   - Parse pclntab
   - Recover function names
   - Mark Go strings
   - Parse type information
5. Filter view:
   - Hide runtime.* functions
   - Focus on main.* and third-party packages
6. Start reversing from main.main
```

---

## Common Pitfalls

| Pitfall | Description | Solution |
|---------|-------------|----------|
| Too many functions to review | Go static linking results in 5000-50000 functions | Filter by package name, only look at main.* and business packages |
| Incomplete string recognition | Go strings are not null-terminated | Recover with go_parser or GoReSym |
| Decompilation results hard to read | Go's defer/goroutine/interface make pseudo-code complex | IDA 9.2+ has improvements, or supplement with dynamic analysis |
| Garble obfuscation | Function names/strings fully randomized | GoResolver + GoStringUngarbler |
| Version differences | pclntab format differs across Go versions | GoReSym supports Go 1.2-1.23+ |
| CGo boundary | Go and C code mixed | Identify _cgo_* functions as the boundary |

---

## Integration with Other Skills

| Need | Tool |
|------|------|
| In-depth Go binary analysis in IDA | `ida-reverse/` + go_parser plugin |
| Ghidra analysis (free) | Ghidra + GoReSym symbol import |
| Quick reconnaissance | `radare2/` -- `rabin2 -z` to view strings |
| Dynamic hooking | Frida (hook runtime functions) or dlv (Go native debugger) |
| Cross-version comparison | `binary-diff/` -- migrate symbols from old version to new version |
| Garble deobfuscation | GoResolver + GoStringUngarbler |
