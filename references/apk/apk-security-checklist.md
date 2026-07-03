# APK Security Testing Quick Reference

> Organized based on OWASP MASTG (Mobile Application Security Testing Guide).
> Covers six major dimensions: static analysis, dynamic analysis, network communication, data storage, authentication/authorization, and code protection.

---

## Android 14+ Changes

Android 14 and 15 introduced security restrictions relevant to reverse engineering:

- **`exported` flag mandatory** for broadcast receivers and services targeting Android 14+ (SDK 34)
- **Foreground service types** must be declared in Manifest (e.g., `dataSync`, `mediaPlayback`)
- **Partial screen sharing** — apps can no longer silently capture the full screen
- **Credential Manager** replaces BiometricPrompt in some flows
- **16KB page size support** (Android 15) — native `.so` files must be aligned for 16KB ELF pages
- **`network_security_config.xml`** — `cleartextTrafficPermitted` now defaults to `false` in Android 14+; many apps override this in their NSC config file under `res/xml/`

When analyzing modern APKs, check `minSdkVersion` — if ≥34, the above restrictions apply.

---

## Static Analysis Checklist

### Manifest Audit

```text
□ android:debuggable="true" → Debuggable (should not appear in production)
□ android:allowBackup="true" → Data can be backed up and extracted
□ Components with android:exported="true" → Exposed Activity/Service/Receiver/Provider
□ Custom permission protectionLevel → Whether it is normal (should be signature)
□ scheme in intent-filter → Whether custom deeplinks can be hijacked
□ android:usesCleartextTraffic="true" → Cleartext HTTP is allowed
□ minSdkVersion too low → May lack security features
```

### Code Audit Key Points

```text
□ Hardcoded keys/tokens (search "key", "secret", "password", "api_key")
□ Insecure random numbers (java.util.Random instead of SecureRandom)
□ Insecure cryptography (ECB mode, DES, MD5 for passwords)
□ WebView configuration (setJavaScriptEnabled + addJavascriptInterface = RCE risk)
□ SQL injection (rawQuery concatenating user input)
□ Path traversal (ContentProvider openFile does not validate paths)
□ Log leakage (Log.d/Log.i outputs sensitive information)
□ Clipboard leakage (ClipboardManager stores sensitive data)
□ Implicit Intent leakage (sendBroadcast without specifying a package name)
```

### Third-Party Library Audit

```text
□ Outdated OkHttp/Retrofit versions (known vulnerabilities)
□ Outdated WebView engine
□ SDKs with known vulnerabilities (check CVEs)
□ Data collection scope of advertising SDKs
□ Push SDK configuration (whether tokens are leaked)
```

---

## Dynamic Analysis Checklist

### Priority Frida Hook Targets

| Target | Hook Point | Purpose |
|------|---------|------|
| Login authentication | `LoginActivity.login()` | Observe credential handling |
| Signature generation | `*Sign*`, `*sign*`, `*encrypt*` | Recover signing algorithm |
| SSL Pinning | `CertificatePinner.check` | Bypass capture restrictions |
| Root detection | `*root*`, `*su*`, `*magisk*` | Bypass detection |
| Cryptographic operations | `javax.crypto.Cipher` | Extract keys/IVs |
| Token storage | `SharedPreferences.getString` | Observe token reads/writes |
| Network requests | `OkHttpClient.newCall` | Observe request construction |

### Common Frida One-Liners

```bash
# Trace all cryptographic operations
frida-trace -U -f com.target.app -j '*Cipher*!*'

# Trace all HTTP requests
frida-trace -U -f com.target.app -j '*OkHttp*!*'

# Trace SharedPreferences reads and writes
frida-trace -U -f com.target.app -j '*SharedPreferences*!*'

# Trace all native function calls
frida-trace -U -f com.target.app -i 'Java_*'
```

### Objection Quick Commands

```bash
# Connect
objection -g com.target.app explore

# Common commands
android hooking list activities
android hooking list services
android sslpinning disable
android root disable
android clipboard monitor
env                              # View application directories
sqlite connect <db_path>         # Connect to database
```

---

## Network Communication Security

### Traffic Capture Configuration

```text
Method 1: System proxy + Burp/mitmproxy
- Set Wi-Fi proxy → Burp listener address
- Install the CA certificate on the device
- Android 7+ requires network_security_config or Frida bypass

Method 2: VPN mode (recommended)
- Use HttpCanary / Packet Capture
- No root and no proxy configuration required
- But it cannot decrypt SSL-pinned traffic

Method 3: Frida + r2frida
- Intercept network calls directly inside the process
- Not limited by proxy/VPN behavior
```

### Check Items

```text
□ Whether HTTPS is used (all API calls)
□ Whether SSL Pinning exists (certificate pinning)
□ Whether certificate validation is correct (self-signed certificates are not accepted)
□ Whether Certificate Transparency (CT) checks exist
□ Whether API keys are transmitted in cleartext in requests
□ Whether tokens have an expiration mechanism
□ Whether request signing prevents tampering
□ Whether replay-attack protection exists (nonce/timestamp)
□ Whether WebSocket is encrypted
□ Whether sensitive data appears in URL parameters (can be logged)
```

---

## Data Storage Security

### Check Locations

| Location | Risk | Check Command |
|------|------|---------|
| SharedPreferences | Token/password stored in cleartext | `adb shell cat /data/data/pkg/shared_prefs/*.xml` |
| SQLite database | Unencrypted sensitive data | `adb pull /data/data/pkg/databases/` |
| External storage | Readable by any app | `adb shell ls /sdcard/Android/data/pkg/` |
| Application logs | Debug information leakage | `adb logcat \| grep pkg` |
| Backup files | allowBackup=true | `adb backup -f backup.ab pkg` |
| Keyboard cache | Input history | Check whether `inputType` is `textPassword` |
| Screenshot protection | Sensitive pages can be captured | Check `FLAG_SECURE` |

### Encrypted Storage Scheme Comparison

| Scheme | Security | Notes |
|------|--------|------|
| Plain SharedPreferences | ❌ | Directly readable after root |
| EncryptedSharedPreferences | ✓ | AndroidX Security library |
| SQLCipher | ✓ | Encrypted SQLite |
| Android Keystore | ✓✓ | Hardware-backed key protection |
| Custom AES encryption | ⚠️ | Depends on key management |

---

## Authentication and Authorization

### Common Vulnerabilities

| Vulnerability | Test Method |
|------|---------|
| Weak password policy | Try 123456, password, etc. |
| No lockout mechanism | Brute-force the login API |
| Token does not expire | Replay old token after logout |
| Broken access control | Modify user_id in requests |
| SMS verification code can be brute-forced | 4/6-digit code without rate limiting |
| OAuth misconfiguration | Tamper with redirect_uri |
| Biometric authentication bypass | Hook BiometricPrompt |
| Device-binding bypass | Modify device_id |

### Test Payloads

```bash
# Broken access control test
curl -H "Authorization: Bearer USER_A_TOKEN" \
     "https://api.target.com/users/USER_B_ID/profile"

# Token replay
# 1. Log in normally and obtain token
# 2. Log out
# 3. Request with the old token → should return 401

# SMS verification code brute force
for code in $(seq 0000 9999); do
    curl -X POST "https://api.target.com/verify" \
         -d "phone=13800138000&code=$code"
done
```

---

## Code Protection Assessment

| Protection Measure | Detection Method | Bypass Difficulty |
|---------|---------|---------|
| ProGuard obfuscation | Check in jadx whether class names are a/b/c | Low (only renaming) |
| String encryption | Search for decryption functions and hook to obtain plaintext | Medium |
| Anti-debugging | Try attaching a debugger | Medium (Frida can bypass) |
| Root detection | Run on a rooted device | Medium (general scripts can bypass) |
| Emulator detection | Run on an emulator | Low-Medium |
| Integrity check | Modify APK and install | Medium (patch validation function) |
| Packer/shell | Check entry class and .so files | Medium-High (requires unpacking) |
| Native protection | Core logic in .so | High (requires IDA analysis) |
| VMP virtualization | Code executed through virtualization | Extremely high |

---

## Quick Testing Flow (30 Minutes)

```text
1. [5min] Decode + Manifest audit
   apktool d app.apk
   Check debuggable/allowBackup/exported/cleartext

2. [10min] Quick code audit
   jadx -d out app.apk
   Search: password, key, secret, token, http://

3. [5min] Network test
   Configure proxy → operate the app → check for cleartext/weak encryption

4. [5min] Storage check
   adb shell → inspect shared_prefs and databases

5. [5min] Dynamic validation
   Frida hook key functions → confirm findings
```
