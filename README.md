# SSTools Mod Analyzer
credtis to toyonh and habibi mod analyzer

A PowerShell security scanner for Minecraft mods folders. Verifies every jar against
Modrinth, then performs deep static analysis on anything unverified to detect
cheat clients, auto-clickers, DLL injection, JVM agents, and external cheat tooling.

Runs entirely offline (except for Modrinth hash lookups). No dependencies.
Outputs a shareable HTML report with per-mod findings and a weighted threat score.

---

## What it does

### 1. Instance detection
Automatically finds your running Minecraft instance and its mods folder by
inspecting `javaw.exe` process arguments. Detects launcher (Modrinth, Prism,
CurseForge, MultiMC, ATLauncher, Lunar, Badlion, Vanilla) and mod loader
(Fabric, Quilt, Forge, NeoForge).

### 2. Modrinth verification
SHA1-hashes every jar in the mods folder and looks it up against Modrinth's
public `version_files` API. Verified mods are byte-identical to the published
release and cannot contain injected code.

### 3. Behavioral bytecode analysis
For every unverified jar, decompiles the constant pool and class metadata
to look for:
- Auto-attack via key-reflection + timer
- KillAura / aura loops (entity query + attack in the same class)
- Silent rotation (yaw/pitch read + write + packet send)
- Injected class payloads (mixed JDK versions in one jar)
- Reflective class loaders and packed payloads
- Clicker input simulation (SendInput / java.awt.Robot / GLFW callbacks)
- HWID fingerprinting, sandbox detection, webhook exfiltration

### 4. Obfuscation detection
Flags jars using non-ASCII identifiers, zero-width Unicode, single-char
classes, Cyrillic/Greek homoglyphs, or reserved Windows device names.

### 5. String scanning
Scans class constant pools and resource files for known cheat strings,
including fullwidth-Unicode variants that bypass naive string filters.

### 6. Native and nested payload scan
Extracts `.dll` / `.so` / `.dylib` files and greps for dangerous Windows API
imports. Detects undeclared nested jars in `META-INF/jars/`.

### 7. External cheat detection
Enumerates running processes, drivers, startup entries, prefetch history,
and named pipes for known cheat tool signatures (AutoHotkey, Cronus, XIM,
injector tools, DSE-bypass drivers).

### 8. HTML report
Writes a dark-themed report with live score bars, animated counters, per-mod
finding cards, and a weighted threat verdict. Opens in your browser.

---

## Requirements

- Windows 10 or 11
- PowerShell 5.1 (built into Windows) or PowerShell 7+
- Internet connection (only used for Modrinth hash lookup)

No .NET Framework install needed. No external modules.

---

## Running

### Option 1 — Double click
Right-click `SSTools-Mod-Analyzer.ps1` → **Run with PowerShell**

If Windows blocks execution:
