# ELF Binary Deep Analysis Reference

> Structural analysis, anti-analysis detection, and analysis techniques for reversing Linux/Android ELF files.

---

## ELF Structure Quick Reference

### File Header (ELF Header)

```text
Offset  Size  Field              Description
0x00   4     e_ident[EI_MAG]    Magic: 7f 45 4c 46 ("\x7fELF")
0x04   1     e_ident[EI_CLASS]  1=32bit, 2=64bit
0x05   1     e_ident[EI_DATA]   1=LE, 2=BE
0x10   2     e_type             2=EXEC, 3=DYN(PIE/SO), 4=CORE
0x12   2     e_machine          0x03=x86, 0x3E=x86_64, 0xB7=AArch64, 0x28=ARM
0x18   8     e_entry            Entry point virtual address
0x20   8     e_phoff            Program header table offset
0x28   8     e_shoff            Section header table offset (0 if stripped)
0x38   2     e_phnum            Number of program headers
0x3C   2     e_shnum            Number of section headers
```

### Program Header

```text
Type     Name         Description
0x01    PT_LOAD      Loadable segment (code/data)
0x02    PT_DYNAMIC   Dynamic linking information
0x03    PT_INTERP    Interpreter path (/lib/ld-linux.so)
0x04    PT_NOTE      Auxiliary information
0x06    PT_PHDR      Program header table itself
0x6474e550 PT_GNU_EH_FRAME  Exception handling
0x6474e551 PT_GNU_STACK     Stack executability flag
0x6474e552 PT_GNU_RELRO     Read-only relocations
```

### Common Sections

| Section | Description |
|---------|-------------|
| `.text` | Code section |
| `.rodata` | Read-only data (string constants) |
| `.data` | Initialized global variables |
| `.bss` | Uninitialized global variables |
| `.plt` / `.got` | Dynamic link jump table |
| `.init_array` | Constructor pointer array |
| `.fini_array` | Destructor pointer array |
| `.dynamic` | Dynamic linking information |
| `.symtab` / `.dynsym` | Symbol table |
| `.strtab` / `.dynstr` | String table |

---

## Anti-Analysis Technique Detection

### Common ELF Anti-Analysis Techniques

| Technique | Characteristic | Countermeasure |
|-----------|----------------|----------------|
| Corrupted program header | PHDR filled with garbage data (e.g., 0x0a) | Manually repair or ignore corrupted PHDR |
| No section header | `e_shoff = 0`, `e_shnum = 0` | Analyze relying only on program headers, not sections |
| Stripped symbols | No `.symtab`, all function names lost | GoReSym(Go) / signature matching / FLIRT |
| Static linking | No `.dynamic`, huge binary size | Identify library functions with FLIRT/Lumina |
| Disguised file type | Extension .sh/.txt/.jpg | Determine with `file` command / magic bytes |
| UPX packing | Contains `UPX!` marker | `upx -d` unpack |
| Custom packer | Entry point jumps to decompression code | Run dynamically to OEP then dump |
| Anti-debugging | ptrace(TRACEME) | LD_PRELOAD hook / patch |
| Anti-VM | Checks /proc/cpuinfo | Modify cpuinfo or hook reads |
| Code encryption | Runtime decryption of .text | Breakpoint after decryption then dump |

### Identifying Self-Extracting/Self-Modifying Code

```text
Characteristics:
1. mmap(PROT_READ|PROT_WRITE|PROT_EXEC) call near entry point
2. Followed by memcpy or loop copy
3. Then mprotect changes permissions
4. Finally br/jmp to the newly mapped address

Analysis Strategy:
1. Find the mmap call -> record the returned address
2. Set a breakpoint after mprotect(PROT_EXEC)
3. Dump the decompressed memory region
4. Analyze as a new binary
```

---

## ARM64 (AArch64) Reverse Engineering Quick Reference

### Registers

| Register | Purpose |
|----------|---------|
| x0-x7 | Parameters/Return values |
| x8 | Indirect result (syscall number) |
| x9-x15 | Temporary registers |
| x16-x17 | IP0/IP1 (PLT trampoline) |
| x18 | Platform register (Android: shadow call stack) |
| x19-x28 | Callee-saved |
| x29 (FP) | Frame pointer |
| x30 (LR) | Link register (return address) |
| SP | Stack pointer |
| PC | Program counter |

### Common Instruction Patterns

```text
Function prologue:
  stp x29, x30, [sp, #-N]!    # Save FP and LR
  mov x29, sp                  # Set frame pointer

Function epilogue:
  ldp x29, x30, [sp], #N      # Restore FP and LR
  ret                          # Return (br x30)

System call:
  mov x8, #NR                  # syscall number
  svc #0                       # Trigger syscall

Conditional branching:
  cmp x0, #0
  b.eq label                   # Branch if equal
  b.ne label                   # Branch if not equal
  cbz x0, label                # Branch if x0 == 0
  cbnz x0, label               # Branch if x0 != 0

Address loading:
  adrp x0, page                # Load page address upper bits
  add x0, x0, #offset          # Add lower 12-bit offset
  ldr x0, [x1, #offset]        # Load from memory
```

### Linux ARM64 Syscall Numbers

| Num | Name | Description |
|-----|------|-------------|
| 56 | openat | Open file |
| 63 | read | Read |
| 64 | write | Write |
| 57 | close | Close |
| 222 | mmap | Memory map |
| 226 | mprotect | Change memory protection |
| 117 | ptrace | Process trace |
| 220 | clone | Create process/thread |
| 221 | execve | Execute program |
| 93 | exit | Exit |
| 94 | exit_group | Exit process group |

---

## Common Compression/Packing Algorithm Identification

| Algorithm | Identification | Decompression |
|-----------|----------------|---------------|
| **LZSS** | Bitstream + literal/match tokens | Custom decompressor (like this report) |
| **ZLIB/Deflate** | Magic: `78 01`/`78 9C`/`78 DA` | `zlib.decompress()` |
| **GZIP** | Magic: `1F 8B` | `gzip -d` / `gunzip` |
| **LZ4** | Magic: `04 22 4D 18` | `lz4 -d` |
| **LZMA/XZ** | Magic: `FD 37 7A 58 5A 00` (XZ) | `xz -d` / `lzma -d` |
| **Brotli** | No fixed magic, check context | `brotli -d` |
| **Zstandard** | Magic: `28 B5 2F FD` | `zstd -d` |
| **UPX** | String `UPX!` | `upx -d` |
| **Custom** | Decompression loop at entry point | Reverse engineer algorithm then write decompressor |

### Clues for Identifying Custom Compression

```text
1. Loop + bitwise ops (shift, AND, OR) near entry point
2. "Sliding window" back-copy (reading backwards from output buffer) -> LZ family
3. Frequency table/Huffman tree construction -> Deflate/Huffman
4. Fixed-size block processing -> Block compression (LZ4/Snappy)
5. Arithmetic coding characteristics (range narrowing) -> LZMA/ANS
```

---

## Linux Process Injection Techniques

### mmap + Code Injection

```text
Process:
1. mmap(NULL, size, PROT_READ|PROT_WRITE, MAP_ANON|MAP_PRIVATE, -1, 0)
2. Write shellcode/payload to the mapped region
3. mprotect(addr, size, PROT_READ|PROT_EXEC)  # Change to executable
4. Jump to the mapped address and execute

Characteristics:
- mmap return value is saved
- Followed by memcpy or loop write
- Then mprotect changes permissions
- Finally br/blr to that address
```

### ptrace Injection

```text
Process:
1. ptrace(PTRACE_ATTACH, target_pid)
2. waitpid(target_pid)
3. ptrace(PTRACE_GETREGS, target_pid, &regs)
4. Modify regs.pc to point to injected code
5. ptrace(PTRACE_SETREGS, target_pid, &regs)
6. ptrace(PTRACE_CONT, target_pid)

Characteristics:
- Open /proc/<pid>/mem or use ptrace
- Read/modify target process registers
- Write shellcode to target process space
```

### /proc/self/mem Self-Modification

```text
Process:
1. open("/proc/self/mem", O_RDWR)
2. lseek(fd, target_addr, SEEK_SET)
3. write(fd, new_code, size)

Use cases:
- Bypass W^X protection (mmap pages cannot be simultaneously W+X)
- Modify own code section (.text is usually read-only)
- Runtime patch instructions
```

---

## Strategies for Analyzing Large ELF Binaries

For large binaries 5MB+:

```text
1. Quick reconnaissance (5 minutes)
   - file / rabin2 -I -> Architecture, type, protections
   - strings | grep -i "error\|fail\|http\|/proc\|/dev" -> Key strings
   - rabin2 -i -> Imported functions (if any)
   - rabin2 -E -> Exported functions

2. Structural analysis (10 minutes)
   - readelf -l -> Program headers (LOAD segment layout)
   - Code near entry point -> check for decryption/decompression
   - Find .init_array -> Constructors (may contain anti-debugging)

3. Locating key logic
   - Start with string cross-references
   - Start with system calls (mmap/ptrace/open)
   - Start with network functions (connect/send/recv)

4. Divide and conquer
   - If self-extracting -> decompress first, analyze payload
   - If multi-module -> analyze by function blocks
   - Use binary-diff to compare different versions
```

---

## Tool Command Quick Reference

```bash
# Basic info
file binary
readelf -h binary          # ELF header
readelf -l binary          # Program headers
readelf -S binary          # Section headers (if present)
rabin2 -I binary           # Comprehensive info

# Strings
strings -a binary | less
rabin2 -z binary           # Data section strings
rabin2 -zz binary          # All file strings

# Disassembly
r2 -A binary               # radare2 analysis
objdump -d binary          # GNU disassembly
aarch64-linux-gnu-objdump -d binary  # ARM64 cross-disassembly

# Dynamic analysis
strace -f ./binary         # System call trace
ltrace -f ./binary         # Library function trace
qemu-aarch64 -strace ./binary  # ARM64 emulated execution

# Memory dump
gdb -p <pid> -ex "dump memory out.bin 0xADDR 0xADDR+SIZE" -ex quit

# Repair corrupted ELF
# Manually modify e_phnum or patch corrupted PHDR
python -c "
import struct
with open('binary', 'r+b') as f:
    f.seek(0x38)  # e_phnum offset (64-bit)
    f.write(struct.pack('<H', 2))  # Modify to correct PHDR count
"
```
