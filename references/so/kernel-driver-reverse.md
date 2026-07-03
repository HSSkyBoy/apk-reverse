# Kernel Driver Reverse Engineering Reference

> Covers Windows/Linux kernel driver reverse engineering, Rootkit analysis, C/C++ binary pattern recognition.

---

## Windows Driver Reverse Engineering

### Driver Types

| Type | Characteristics | Analysis Focus |
|------|------|---------|
| WDM (Windows Driver Model) | Legacy driver, manual IRP management | DriverEntry → Device Creation → Dispatch Routines |
| KMDF (Kernel Mode Driver Framework) | Modern framework, event-driven | EvtDriverDeviceAdd → Queue → I/O Callbacks |
| WDF (Windows Driver Foundation) | Umbrella term for KMDF + UMDF | Look for WdfDriverCreate calls |
| Minifilter | Filesystem filter driver | FltRegisterFilter → Pre/Post Callbacks |

### WDM Driver Analysis Flow

```text
1. Find DriverEntry (entry point)
   - IDA auto-detects, or search for IoCreateDevice / IoCreateSymbolicLink

2. Find device name and symbolic link
   - IoCreateDevice → DeviceName (e.g., \Device\MyDriver)
   - IoCreateSymbolicLink → SymLink (e.g., \DosDevices\MyDriver)

3. Find Dispatch routine
   - DriverObject->MajorFunction[IRP_MJ_DEVICE_CONTROL] = DispatchIoctl
   - This is the entry point called from user mode via DeviceIoControl

4. Analyze IOCTL handling
   - switch(IoControlCode) dispatches different functions
   - IOCTL encoding: CTL_CODE(DeviceType, Function, Method, Access)
   - Method: METHOD_BUFFERED / METHOD_IN_DIRECT / METHOD_OUT_DIRECT / METHOD_NEITHER

5. Find vulnerabilities
   - User-controlled buffer with unchecked length → overflow
   - METHOD_NEITHER directly uses user pointer → arbitrary read/write
   - Unchecked IOCTL privilege → callable by unprivileged users
```

### IOCTL Encoding Decoding

```python
# Decode IOCTL code
def decode_ioctl(code):
    device_type = (code >> 16) & 0xFFFF
    access = (code >> 14) & 0x3
    function = (code >> 2) & 0xFFF
    method = code & 0x3
    
    methods = {0: "BUFFERED", 1: "IN_DIRECT", 2: "OUT_DIRECT", 3: "NEITHER"}
    access_types = {0: "ANY", 1: "READ", 2: "WRITE", 3: "READ|WRITE"}
    
    return f"DevType=0x{device_type:X} Func=0x{function:X} Method={methods[method]} Access={access_types[access]}"

# Example
decode_ioctl(0x80002034)
# DevType=0x8000 Func=0x80D Method=BUFFERED Access=ANY
```

### IDA Plugins

| Plugin | Purpose | Link |
|------|------|------|
| **Driver Buddy Reloaded** | Auto-identify IOCTL, Dispatch, device names | https://github.com/VoidSec/DriverBuddyReloaded |
| **WinDbg + IDA** | Kernel debugging + static analysis integration | Built-in |
| **FLIRT/Lumina** | Identify WDK library functions | IDA Built-in |

### Reference Articles

- [Windows Drivers RE Methodology (VoidSec)](https://voidsec.com/windows-drivers-reverse-engineering-methodology/) — The most comprehensive WDM driver reverse engineering methodology
- [Driver Reversing 101](https://eversinc33.com/posts/driver-reversing.html) — WDM vs KMDF comparison
- [Methodology of Reversing Vulnerable Killer Drivers](https://whiteknightlabs.com/2025/10/28/methodology-of-reversing-vulnerable-killer-drivers/) — Vulnerable driver analysis

---

## Linux Kernel Module Reverse Engineering

### LKM (Loadable Kernel Module) Structure

```text
Key functions:
- init_module / module_init → Executes when module is loaded
- cleanup_module / module_exit → Executes when module is unloaded

Key structures:
- struct file_operations → Character device open/read/write/ioctl
- struct net_device_ops → Network device operations
- struct block_device_operations → Block device operations
```

### Analysis Flow

```text
1. Confirm it's a kernel module
   file module.ko → "ELF 64-bit ... relocatable" (note relocatable, not executable)

2. Find init/exit functions
   readelf -s module.ko | grep -E "init_module|cleanup_module"
   Or find module info in the .modinfo section

3. Find file_operations structure
   Search for register_chrdev / cdev_add / misc_register
   → Find the fops struct → locate ioctl/read/write handlers

4. Analyze ioctl handling
   unlocked_ioctl / compat_ioctl functions
   → switch(cmd) dispatch

5. Find Rootkit behavior
   - Modify sys_call_table → syscall hook
   - Modify /proc filesystem → hide processes/files
   - Register netfilter hook → hide network connections
   - Modify VFS layer → hide files
```

### Common Rootkit Techniques

| Technique | Characteristic | Detection Method |
|------|------|---------|
| syscall table hook | Modify `sys_call_table` entries | Compare the in-memory table with vmlinux on disk |
| VFS hook | Modify `file_operations` function pointers | Check if fops pointers point outside kernel code section |
| Netfilter hook | `nf_register_net_hook` | Traverse the netfilter hook list |
| kprobe/ftrace hook | Register kprobe or ftrace callbacks | Check ftrace registration list |
| eBPF rootkit | Load malicious BPF programs | `bpftool prog list` |
| DKOM | Directly modify kernel objects (process list) | Traverse task_struct list and compare with /proc |

### Tools

| Tool | Purpose |
|------|------|
| `crash` | Kernel dump analysis |
| `volatility3` | Memory forensics (Linux profile) |
| `dmesg` / `journalctl` | Kernel logs |
| `lsmod` / `/proc/modules` | List of loaded modules |
| `modinfo` | Module metadata |
| `strace` | System call tracing (user-mode perspective) |

---

## C/C++ Reverse Engineering Pattern Recognition

### Common C Language Patterns

| Source Pattern | Disassembly Characteristic |
|---------|-----------|
| `if-else` | `cmp` + `jcc` (conditional jump) |
| `switch-case` | Jump table (`jmp [rax*8 + table]`) or sequential `cmp` |
| `for` loop | `cmp` + `jl/jle` + loop body + `inc/add` + `jmp` back |
| `while` loop | Condition check at loop top |
| `do-while` | Condition check at loop bottom |
| Function pointer call | `call rax` or `call [reg+offset]` |
| `struct` access | `[reg+constant_offset]` (e.g., `[rdi+0x10]`) |
| `malloc` + usage | `call malloc` → return value stored in register → subsequent access via that register + offset |
| String comparison | `call strcmp` or `repe cmpsb` |

### C++ Specific Patterns

| Source Pattern | Disassembly Characteristic |
|---------|-----------|
| **Virtual function call** | `mov rax, [rcx]` (get vtable) → `call [rax+offset]` (call virtual function) |
| **Constructor** | Allocate memory → write vtable pointer → initialize members |
| **Destructor** | Clean up members → possibly call `operator delete` |
| **this pointer** | First parameter (rcx/rdi) is the object pointer |
| **Inheritance** | vtable contains parent virtual functions + child overrides |
| **Multiple inheritance** | Object contains multiple vtable pointers (different offsets) |
| **RTTI** | `type_info` pointer before the vtable |
| **Exception handling** | `__cxa_throw` / `_CxxThrowException` |
| **STL containers** | `std::vector`: three-pointer structure `{begin, end, capacity}` |
| **std::string** | Small String Optimization (SSO): short strings inline, long strings heap-allocated |

### vtable Reverse Engineering Methods

```text
1. Find vtable
   - Search for contiguous function pointer arrays (in .rodata or .rdata sections)
   - Constructor writes vtable pointer via `mov [rcx], offset vtable`

2. Determine class hierarchy
   - At offset -8 before the vtable is usually the RTTI pointer (if not stripped)
   - Multiple vtables sharing the first few entries → inheritance relationship

3. Label virtual functions
   - vtable[0] is usually the destructor (or deleting destructor)
   - Subsequent entries labeled by offset: vtable[1] = func1, vtable[2] = func2...

4. Operations in IDA
   - Create a struct at the vtable address (each field is a function pointer)
   - Add comments to `call [rax+offset]` indicating which virtual function is called
```

### Struct Recovery

```text
Method 1: Infer from access patterns
  mov eax, [rdi+0x00]  → field_0: int/ptr (4/8 bytes)
  mov ecx, [rdi+0x08]  → field_8: int/ptr
  movss xmm0, [rdi+0x10] → field_10: float

Method 2: Infer from sizeof
  call malloc(0x30) → struct size 0x30 (48 bytes)
  
Method 3: Infer from constructor
  Constructor initializes all fields → field types and offsets are clear

Method 4: Use IDA's "Create struct" feature
  Select the access pattern → Edit → Struct → Create struct from selection
```

---

## Common Compiler Characteristics

| Compiler | Identifying Features |
|--------|---------|
| MSVC | `_security_cookie` check, `__fastcall` calling convention, Rich Header |
| GCC | `__stack_chk_fail`, `-fstack-protector`, `.note.GNU-stack` |
| Clang/LLVM | Similar to GCC but different optimization patterns, `__asan_*` (if sanitizer is enabled) |
| MinGW | GCC features + Windows API calls |
| AOSP Clang | Android-specific `__android_log_print`, PGO markers |

### Optimization Level Identification

| Optimization Level | Characteristics |
|---------|------|
| -O0 | Lots of redundant mov instructions, all variables on stack, no inlining |
| -O1 | Basic optimization, some variables in registers |
| -O2 | Loop unrolling, function inlining, tail call optimization |
| -O3 / -Os | Aggressive inlining, vectorization (SIMD), harder to read |
| PGO | Hot path optimization, cold code separated into `.text.cold` |
| LTO | Cross-module inlining, global dead code elimination |

---

## Kernel Debugging Environment

### Windows

```text
Debugger: WinDbg Preview
Connection: Network debugging (recommended) or serial

Target machine setup:
bcdedit /debug on
bcdedit /dbgsettings net hostip:192.168.x.x port:50000

Debugger machine connection:
WinDbg → File → Attach to Kernel → Net → Port:50000 Key:xxx

Common commands:
!analyze -v          # Auto-analyze crash
lm                   # List loaded modules
!drvobj \Driver\xxx  # View driver object
dt nt!_DRIVER_OBJECT # Display structure
bp module!function   # Set breakpoint
```

### Linux

```text
Debugger: GDB + QEMU or kgdb

QEMU kernel debugging:
qemu-system-x86_64 -kernel bzImage -s -S ...
gdb vmlinux -ex "target remote :1234"

Common commands:
info threads         # Kernel threads
lx-symbols           # Load kernel symbols (requires scripts/gdb/)
p init_task          # View init process
lx-dmesg             # Kernel logs
```

---

## Reference Resources

| Resource | Description | Link |
|------|------|------|
| VoidSec Driver RE Methodology | Complete Windows WDM driver analysis workflow | https://voidsec.com/windows-drivers-reverse-engineering-methodology/ |
| Elastic Rootkit Series | Linux Rootkit classification + detection | https://security-labs.elastic.co/security-labs/linux-rootkits-1-hooked-on-linux |
| Driver Buddy Reloaded | IDA driver analysis plugin | https://github.com/VoidSec/DriverBuddyReloaded |
| LOLDrivers | Known vulnerable driver list | https://www.loldrivers.io/ |
| Windows Driver Samples | Microsoft official driver samples | https://github.com/microsoft/Windows-driver-samples |
| Linux Kernel Module Programming | Kernel module development guide | https://sysprog21.github.io/lkmpg/ |
| Trail of Bits - Devirtualizing C++ | vtable reverse engineering methods | https://blog.trailofbits.com/2017/02/13/devirtualizing-c-with-binary-ninja/ |
