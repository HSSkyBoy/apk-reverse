# AI-Assisted Reverse Engineering

> LLM-driven decompilation / Multi-Agent verification / Neural semantic recovery
> 2025-2026 Biggest paradigm shift

## Core Tools and Models

### LLM4Decompile
- First open-source framework using LLM for binary-to-source decompilation
- Supports x86/ARM/MIPS multi-architecture
- Input: assembly code → Output: C source code
- Training data: millions of source-assembly pairs

### Decaf (2026)
- **Compiler feedback verification**: Compile LLM-generated source code and compare against the original binary
- Result: decompilation rate 26% → 83.9% (ExeBench Real -O2)
- Key insight: feedback loops are more effective than larger models

### Constraint-Guided Multi-Agent (2026)
- Three-level verification pipeline:
  1. Syntax correctness (parsing)
  2. Compilability (GCC)
  3. Behavioral equivalence (LLM-generated test cases)
- 84-97% re-executable rate, only $0.03-0.05 each

### REMEND (2026)
- Specialized: extracting mathematical equations from binaries
- 89.8-92.4% accuracy (across 3 ISAs x 3 optimization levels x 2 languages)
- Speed: 0.132s/function, only 12M parameters

### Glaurung
- Open-source Ghidra alternative, Rust kernel + Python bindings
- **AI-native architecture**: LLM Agent embedded in every analysis layer
- Evidence artifacts: plain/rich/JSON/JSONL multi-format output for LLM consumption
- Supports: ELF/PE/Mach-O, x86/ARM/RISC-V, IOC detection, entropy analysis

## Workflow: AI-Enhanced Binary Analysis

### 1. LLM-Assisted Rapid Reconnaissance

```text
□ strings extraction → LLM semantic classification (URLs/keys/paths/protocols)
□ Import table analysis → LLM infers functionality (crypto=OpenSSL? networking=libcurl?)
□ Disassembly snippets → LLM identifies patterns (crypto algorithms, anti-debugging, VM detection)
□ Error messages → LLM infers context ("Invalid license" → authorization logic location)
```

### 2. Neural Decompilation

```bash
# LLM4Decompile
python llm4decompile.py --binary target.so --arch arm64 --output target.c

# Verify results (recompile + compare)
gcc -O2 -o target_recompiled target.c -fPIC -shared
# → Validate output behavioral equivalence
```

### 3. Multi-Agent Verification

```text
Agent 1 (Syntax): Check whether the generated C code can be parsed
  ↓ Failure → Feed error info back to LLM for retry
Agent 2 (Compile): GCC compilation → Check warnings/errors
  ↓ Failure → Feed compilation errors to LLM
Agent 3 (Behavior): LLM generates inputs → Run original and recompiled versions → Compare outputs
  ↓ Mismatch → Feed differences to LLM → Iterative correction
```

### 4. LLM-Assisted Static Analysis

```text
□ Function renaming: Input decompiled pseudocode → LLM suggests semantic names
□ Type recovery: Analyze context → LLM infers struct/class definitions
□ Algorithm identification: Assembly snippets → LLM recognizes crypto algorithms (AES/TEA/RC4/custom)
□ Protocol reversing: Network packet sequences → LLM infers protocol format
□ Comment generation: Decompiled code → LLM generates comments
```

### 5. macOS/iOS Private Framework Reversing (MOTIF)

```text
Problem: macOS private frameworks have no documentation, missing type information
Solution: LLM analyzes usage patterns → infers method signatures and parameter types
Result: ObjC signature recovery 15% → 86% (vs static analysis)
```

## LLM Prompt Templates

### Function Semantic Analysis

```
You are a reverse engineering expert. Analyze this decompiled function:

[pseudocode]

1. What does this function do? (one sentence)
2. Suggest a meaningful function name.
3. What are the input parameters and their likely types?
4. What is the return value?
5. What external APIs/functions does it depend on?
6. Any security-relevant operations (crypto, auth, network, file I/O)?
```

### Algorithm Identification

```
Analyze this assembly/disassembly for cryptographic operations:

[assembly code]

1. Is this a known cryptographic algorithm? (AES/DES/RC4/TEA/ChaCha20/custom?)
2. Identify the key schedule and round structure.
3. What is the key size?
4. Are there any hardcoded constants that identify the algorithm?
```

### Protocol Format Inference

```
Given this network packet sequence, infer the protocol structure:

[hex dump]

1. Identify magic bytes and length fields.
2. Propose a struct definition for the packet header.
3. What field(s) appear to be checksums/CRCs?
4. Is this a known protocol or custom?
```

## Tool Selection

| Scenario | Recommended Tool | Cost |
|----------|-----------------|------|
| Fast decompilation | LLM4Decompile | Free (local GPU) |
| High-precision decompilation | Constraint-Guided Multi-Agent | ~$0.05/binary |
| Math function extraction | REMEND | Free |
| Cross-platform RE | Glaurung (Rust) | Free and open source |
| LLM interaction | Claude API / GPT-4 / DeepSeek | ~$0.01-0.10/call |

## Limitations

- **Complex control flow**: Virtualized/obfuscated code is still difficult (control flow flattening, VMProtect)
- **Indirect calls**: Virtual function tables, function pointers are hard to recover
- **Inlined functions**: Blurred boundaries after compiler inlining
- **Floating-point operations**: Semantic recovery of vectorized instructions needs improvement
- **Context window**: Large functions (>1000 lines) exceed LLM context limits

Source: Decaf (2026), REMEND (2026), Constraint-Guided Multi-Agent Decompilation (2026), LLM4Decompile, Glaurung
