# Encryption/Decryption & Encoding/Decoding Tools Quick Reference

> Encrypted/encoded/hashed data is frequently encountered in reverse engineering and CTF. This document lists the most practical tools by scenario.

---

## Auto-Identify + Decrypt (when you don't know what encryption is used)

| Tool | Stars | Purpose | Link |
|------|-------|------|------|
| **Ciphey** | 18k+ | AI auto-identifies and decrypts (supports 50+ encodings/ciphers/hashes) | https://github.com/Ciphey/Ciphey |
| **CyberChef** | 29k+ | Online/offline encoding/decoding Swiss Army knife (drag-and-drop) | https://github.com/gchq/CyberChef |
| **dcode.fr** | — | 900+ online cipher/encoding/math tools | https://www.dcode.fr/ |

### Ciphey Usage

```bash
pip install ciphey
# Auto-detect and decrypt
ciphey -t "ciphertext"
# Read from file
ciphey -f encrypted.txt
```

Ciphey supports: Base64/32/16, Caesar, Vigenere, XOR, AES (weak keys), Morse, Binary, Hex, URL encoding, HTML entities, hash identification, etc.

### CyberChef Usage

```text
Online: https://gchq.github.io/CyberChef/
Offline: Download the HTML file from GitHub Releases and open directly

Common Recipes:
- From Base64 → Decode Base64
- XOR → XOR decryption (can brute-force key)
- AES Decrypt → AES decryption
- Magic → Auto-detect encoding type
```

---

## Hash Identification & Cracking

| Tool | Purpose | Link |
|------|------|------|
| **hashID** | Identify hash type (MD5/SHA/bcrypt, etc.) | https://github.com/psypanda/hashID |
| **hash-identifier** | Same as above, Python version | https://github.com/blackploit/hash-identifier |
| **haiti** | Modern hash identification tool (more accurate) | `gem install haiti` |
| **Hashcat** | GPU hash cracking | https://hashcat.net/ |
| **John the Ripper** | CPU hash cracking | https://www.openwall.com/john/ |
| **hashes.com** | Online hash lookup (rainbow tables) | https://hashes.com/ |

```bash
# Identify hash type
hashid '5f4dcc3b5aa765d61d8327deb882cf99'
# Output: [+] MD5

# haiti (more accurate)
haiti '5f4dcc3b5aa765d61d8327deb882cf99'

# Hashcat cracking
hashcat -m 0 hash.txt rockyou.txt  # MD5
hashcat -m 1000 hash.txt rockyou.txt  # NTLM
```

---

## RSA Attacks

| Tool | Purpose | Link |
|------|------|------|
| **RsaCtfTool** | RSA auto-attack (20+ attack methods) | https://github.com/Ganapati/RsaCtfTool |
| **SageMath** | Mathematical computation (large integer factorization/elliptic curves) | https://www.sagemath.org/ |
| **factordb.com** | Online large integer factorization lookup | http://factordb.com/ |
| **yafu** | Local large integer factorization | https://github.com/bbuhrow/yafu |

```bash
# RsaCtfTool auto-attack
python RsaCtfTool.py --publickey pub.pem --private
python RsaCtfTool.py --publickey pub.pem --uncipherfile cipher.txt

# Supported attacks:
# Wiener, Boneh-Durfee, Fermat, Pollard p-1, Williams p+1
# Common modulus, Small q, Hastads, Noveltyprimes, etc.
```

---

## XOR Analysis

| Tool | Purpose | Link |
|------|------|------|
| **xortool** | XOR key length guessing + known-plaintext attack | https://github.com/hellman/xortool |
| **CyberChef XOR** | Visual XOR operations | CyberChef built-in |

```bash
# Guess XOR key length
xortool encrypted_file
# Decrypt with guessed key length
xortool -l 4 -c 00 encrypted_file

# Known-plaintext attack (when part of plaintext is known)
xortool-xor -f encrypted -s "known_plaintext"
```

---

## Classical Ciphers

| Cipher Type | Tools | Description |
|---------|------|------|
| Caesar | CyberChef / dcode.fr | Brute-force 25 shifts |
| Vigenere | dcode.fr / Ciphey | Requires guessing key length |
| Substitution | quipqiup.com | Frequency analysis auto-solver |
| Enigma | dcode.fr | Online simulator |
| Rail Fence | dcode.fr / CyberChef | Rail fence cipher |
| Playfair | dcode.fr | Requires key |
| Morse | CyberChef | Dots and dashes to text |
| Bacon | dcode.fr | Binary steganography |
| ROT13/47 | CyberChef / `tr` | Simple substitution |

---

## Encoding Identification & Conversion

| Encoding | Identifying Features | Decoding Method |
|------|---------|---------|
| Base64 | Ends with `=` or `==`, charset A-Za-z0-9+/ | `base64 -d` / CyberChef |
| Base32 | Uppercase letters + digits 2-7, ends with `=` | CyberChef |
| Base58 | No 0/O/I/l, commonly seen in Bitcoin | CyberChef |
| Hex | Only 0-9a-f, even length | `xxd -r -p` / CyberChef |
| URL encoding | `%XX` format | `urldecode` / CyberChef |
| HTML entities | `&#XX;` or `&amp;` format | CyberChef |
| Unicode escape | `\uXXXX` format | Python `decode('unicode_escape')` |
| JWT | `xxxxx.yyyyy.zzzzz` (three Base64URL segments) | jwt.io / CyberChef |
| Brainfuck | Only eight characters: `><+-.,[]` | Online interpreter |
| Ook! | Only `Ook.` `Ook!` `Ook?` | Online interpreter |

---

## Encryption Recognition in Reverse Engineering

### Algorithm Identification via Constants

| Constant/Characteristic | Algorithm |
|-----------|------|
| `0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476` | MD5 |
| `0x6A09E667, 0xBB67AE85, 0x3C6EF372` | SHA-256 |
| `0x63, 0x7C, 0x77, 0x7B` (S-Box start) | AES |
| `0x243F6A88` (hex of π) | Blowfish |
| `0xB7E15163, 0x9E3779B9` | RC5/RC6/TEA |
| `0x61707865` ("expa") | ChaCha20/Salsa20 |
| `0xC6EF3720` | XTEA |

### Algorithm Identification via Behavior

| Behavioral Characteristic | Possible Algorithm |
|---------|-----------|
| 256-byte lookup table + swap operations | RC4 |
| 16-byte blocks + multiple permutation rounds | AES |
| Feistel structure (left/right swap) | DES/Blowfish/TEA |
| Large integer multiplication/modular exponentiation | RSA |
| Elliptic curve point operations | ECDSA/ECDH |
| Fixed 64-round loop | TEA/XTEA |
| 32 rounds + delta constant | XTEA |

---

## Automated Cryptanalysis

| Tool | Purpose | Link |
|------|------|------|
| **FeatherDuster** | Automated cryptanalysis framework | https://github.com/nccgroup/featherduster |
| **PkCrack** | ZIP known-plaintext attack | https://www.unix-ag.uni-kl.de/~conrad/krypto/pkcrack.html |
| **bkcrack** | ZIP known-plaintext attack (modern version) | https://github.com/kimci86/bkcrack |
| **z3** | SMT solver (constraint solving) | https://github.com/Z3Prover/z3 |
| **angr** | Symbolic execution (auto-solve inputs) | https://angr.io/ |

---

## Quick Decision Tree

```text
When you get unknown data:

1. Check length and character set
   - Only hex characters → could be hex encoding or a hash
   - Ends with = → Base64
   - Three dot-separated segments → JWT
   - 32/40/64 hex characters → hash (MD5/SHA1/SHA256)

2. Try Ciphey auto-detect
   ciphey -t "data"

3. If Ciphey fails → use CyberChef Magic mode

4. If it's a hash → hashID to identify type → Hashcat/John to crack

5. If it's RSA → RsaCtfTool auto-attack

6. If it's XOR → xortool to analyze key

7. If it's custom encryption → IDA/Ghidra to reverse the algorithm → write a decryption script
```

---

## Online Resources

| Resource | Link | Purpose |
|------|------|------|
| CyberChef | https://gchq.github.io/CyberChef/ | Universal encoding/decoding |
| dcode.fr | https://www.dcode.fr/ | 900+ cipher tools |
| quipqiup | https://quipqiup.com/ | Substitution cipher auto-solver |
| factordb | http://factordb.com/ | RSA large integer factorization |
| jwt.io | https://jwt.io/ | JWT decode/verify |
| hashes.com | https://hashes.com/ | Hash reverse lookup |
| crackstation | https://crackstation.net/ | Online hash cracking |
