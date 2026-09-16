#requires -Version 5.1
# SSTools Mod Analyzer v11

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null
Clear-Host

Write-Host ""
Write-Host "  SSTools Mod Analyzer beta" -ForegroundColor Cyan
Write-Host "  ========================" -ForegroundColor DarkGray
Write-Host ""

Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
$sw = [System.Diagnostics.Stopwatch]::StartNew()

$mcPid = 0; $mcCmd = $null
try {
    $procs = Get-CimInstance Win32_Process -Filter "Name='javaw.exe' OR Name='java.exe'" -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        if ($p.CommandLine -and ($p.CommandLine -match 'net\.minecraft' -or $p.CommandLine -match '--gameDir')) {
            $mcPid = [int]$p.ProcessId; $mcCmd = $p.CommandLine; break
        }
    }
} catch { }

function Get-ArgMatch { param([string]$Cmd,[string]$Name)
    if (-not $Cmd) { return $null }
    $m = [regex]::Match($Cmd, [regex]::Escape($Name) + '\s+"([^"]+)"')
    if ($m.Success) { return $m.Groups[1].Value }
    $m2 = [regex]::Match($Cmd, [regex]::Escape($Name) + '\s+([^\s"]+)')
    if ($m2.Success) { return $m2.Groups[1].Value }
    return $null
}

$gameDir   = Get-ArgMatch -Cmd $mcCmd -Name '--gameDir'
$mcVersion = Get-ArgMatch -Cmd $mcCmd -Name '--version'
$mcUser    = Get-ArgMatch -Cmd $mcCmd -Name '--username'

$jvmFlags = New-Object System.Collections.Generic.List[string]
$cheatBrands = @('Wurst','Aristois','Impact','Konas','Phobos','Salhack','ForgeHax','Mathax','Meteor','Seppuku','Huzuni','Novoline','Ares','Abyss','Tenacity','Rise','Flux','Gamesense','Intent','Vape','Ghost','Doomsday','Prestige','Dqrkis','Catlean','Asteria','Xenon','Gypsy','Novoware','HellClient','Opai','Chainlibs')
$legitAgents = @('jmxremote','yjp','jrebel','newrelic','jacoco','theseus','lombok','aspectjweaver')

if ($mcCmd) {
    foreach ($m in [regex]::Matches($mcCmd, '-javaagent:([^\s"]+)')) {
        $ap = $m.Groups[1].Value.Trim('"').Trim("'"); $an = Split-Path $ap -Leaf
        $isLegit = $false
        foreach ($la in $legitAgents) { if ($an -match $la) { $isLegit = $true; break } }
        if (-not $isLegit) { [void]$jvmFlags.Add("JavaAgent: $an") }
    }
    if ($mcCmd -match '-Xbootclasspath/p:') { [void]$jvmFlags.Add('BootClasspathPrepend') }
    if ($mcCmd -match '-Xbootclasspath/a:') { [void]$jvmFlags.Add('BootClasspathAppend') }
    if ($mcCmd -match '-agentpath:')        { [void]$jvmFlags.Add('NativeAgent') }
    if ($mcCmd -match '-agentlib:jdwp')     { [void]$jvmFlags.Add('JDWPDebugAgent') }
    foreach ($brand in $cheatBrands) { if ($mcCmd -match "(?i)\b$([regex]::Escape($brand))\b") { [void]$jvmFlags.Add("CheatClientBrand: $brand") } }
}
$mcCmd = $null

if (-not $gameDir) { $gameDir = Join-Path $env:APPDATA ".minecraft" }
$modsDir = Join-Path $gameDir "mods"
if (-not (Test-Path $modsDir)) { $modsDir = Join-Path $gameDir ".minecraft\mods" }

$uptime = "n/a"
if ($mcPid -gt 0) {
    try { $proc = Get-Process -Id $mcPid -ErrorAction Stop; $up = (Get-Date) - $proc.StartTime; $uptime = ("{0}d {1}h {2}m {3}s" -f $up.Days, $up.Hours, $up.Minutes, $up.Seconds) } catch { $uptime = "unreadable" }
}

$launcher = "Unknown"
if ($gameDir) {
    if     ($gameDir -match 'prism|Prism')          { $launcher = "Prism Launcher" }
    elseif ($gameDir -match 'curseforge|CurseForge'){ $launcher = "CurseForge" }
    elseif ($gameDir -match 'modrinth|Modrinth')    { $launcher = "Modrinth App" }
    elseif ($gameDir -match 'MultiMC')              { $launcher = "MultiMC" }
    elseif ($gameDir -match 'ATLauncher')           { $launcher = "ATLauncher" }
    elseif ($gameDir -match 'lunarclient|Lunar')    { $launcher = "Lunar Client" }
    elseif ($gameDir -match 'badlion')              { $launcher = "Badlion Client" }
    elseif ($gameDir -match '\.minecraft')          { $launcher = "Vanilla Launcher" }
}

$jars = @()
if (Test-Path $modsDir) { $jars = @(Get-ChildItem -Path $modsDir -Filter "*.jar" -File -ErrorAction SilentlyContinue) }

$loader = "Vanilla"
if ($mcVersion) {
    if     ($mcVersion -match 'fabric')   { $loader = "Fabric" }
    elseif ($mcVersion -match 'quilt')    { $loader = "Quilt" }
    elseif ($mcVersion -match 'neoforge') { $loader = "NeoForge" }
    elseif ($mcVersion -match 'forge')    { $loader = "Forge" }
}

$verDisp  = if ($mcVersion) { $mcVersion } else { "unknown" }
$userDisp = if ($mcUser)    { $mcUser }    else { "n/a" }

Write-Host "  Launcher        : $launcher"
Write-Host "  Version         : $verDisp"
Write-Host "  Loader          : $loader"
Write-Host "  Uptime          : $uptime"
Write-Host "  PID             : $mcPid"
Write-Host "  Mods folder     : $modsDir" -ForegroundColor Cyan
Write-Host "  Amount of mods  : $($jars.Count)"
Write-Host "  User            : $userDisp"
Write-Host ""

if ($jvmFlags.Count -gt 0) {
    Write-Host "  [JVM ALERT]" -ForegroundColor Red
    foreach ($f in $jvmFlags) { Write-Host "     - $f" -ForegroundColor Red }
    Write-Host ""
}
if (-not (Test-Path $modsDir) -or $jars.Count -eq 0) { Write-Host "  [ERR] no jars found" -ForegroundColor Red; exit 1 }

function Test-IsMetaMod { param([string]$JarName, $Zip)
    if ($JarName -match '(?i)-api-|(?i)\bapi\b|language-|(?i)-lib-|(?i)\blib\b|library-|-kotlin-|fabric-api|-config-') { return $true }
    if ($Zip) { $n = @($Zip.Entries | Where-Object { $_.FullName -match '^META-INF/jars/.+\.jar$' }); if ($n.Count -ge 30) { return $true } }
    return $false
}

Write-Host "[ 2 ] MODRINTH" -ForegroundColor Cyan

$headers = @{ "User-Agent" = "SSTools-Mod-Analyzer/11.0" }
$resolved = @{}

$hashes = New-Object System.Collections.Generic.List[object]
foreach ($j in $jars) {
    $h = $null
    try { $h = (Get-FileHash -Path $j.FullName -Algorithm SHA1 -ErrorAction Stop).Hash.ToLower() } catch { }
    [void]$hashes.Add([PSCustomObject]@{ Jar = $j; SHA1 = $h })
}
$pending = @($hashes | Where-Object { $_.SHA1 } | ForEach-Object { $_.SHA1 })

for ($i = 0; $i -lt $pending.Count; $i += 100) {
    $take = [Math]::Min(100, $pending.Count - $i)
    $chunk = $pending[$i..($i + $take - 1)]
    $body = @{ hashes = $chunk; algorithm = "sha1" } | ConvertTo-Json -Compress
    try {
        $resp = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/version_files" -Method Post -Body $body -ContentType "application/json" -Headers $headers -TimeoutSec 15 -ErrorAction Stop
        if ($resp) {
            $ids = New-Object System.Collections.Generic.HashSet[string]
            foreach ($prop in $resp.PSObject.Properties) { if ($prop.Value.project_id) { [void]$ids.Add([string]$prop.Value.project_id) } }
            $titles = @{}
            if ($ids.Count -gt 0) {
                try {
                    $idJson = '["' + (($ids) -join '","') + '"]'
                    $u = "https://api.modrinth.com/v2/projects?ids=" + [System.Uri]::EscapeDataString($idJson)
                    $pr = Invoke-RestMethod -Uri $u -Headers $headers -TimeoutSec 15 -ErrorAction Stop
                    foreach ($p in $pr) { if ($p.id) { $titles[[string]$p.id] = [string]$p.title } }
                } catch { }
            }
            foreach ($prop in $resp.PSObject.Properties) {
                $key = $prop.Name.ToLower(); $val = $prop.Value
                if (-not $val -or -not $val.project_id) { continue }
                $projId = [string]$val.project_id
                $t = if ($titles.ContainsKey($projId)) { $titles[$projId] } else { $projId }
                $resolved[$key] = @{ Title = $t; Version = [string]$val.version_number }
            }
        }
    } catch { Write-Host "  modrinth: $($_.Exception.Message)" -ForegroundColor DarkYellow }
}

function Get-ZoneIdentifier { param([string]$Path)
    try {
        $ads = Get-Content -Raw -Stream Zone.Identifier $Path -ErrorAction SilentlyContinue
        if ($ads -match 'HostUrl=(.+)')     { return $Matches[1].Trim() }
        if ($ads -match 'ReferrerUrl=(.+)') { return $Matches[1].Trim() }
    } catch { }
    return $null
}

$verified = New-Object System.Collections.Generic.List[object]
$unknown  = New-Object System.Collections.Generic.List[object]
foreach ($h in $hashes) {
    $zone = Get-ZoneIdentifier -Path $h.Jar.FullName
    if ($h.SHA1 -and $resolved.ContainsKey($h.SHA1)) {
        $r = $resolved[$h.SHA1]
        [void]$verified.Add([PSCustomObject]@{ Name = $h.Jar.Name; Title = $r.Title; Version = $r.Version; Path = $h.Jar.FullName; SHA1 = $h.SHA1 })
    } else {
        [void]$unknown.Add([PSCustomObject]@{ Name = $h.Jar.Name; Size = [math]::Round($h.Jar.Length / 1KB, 1); Zone = $zone; Path = $h.Jar.FullName; SHA1 = $h.SHA1 })
    }
}

Write-Host "  $($verified.Count) verified / $($unknown.Count) unknown"
if ($unknown.Count -gt 0) { foreach ($u in $unknown) { Write-Host ("     !!  {0}  [{1} KB]" -f $u.Name, $u.Size) -ForegroundColor Red } }
Write-Host ""

$whitelistCachePath = Join-Path $env:TEMP "sstools_whitelist_v1.json"
$verifiedSig = ($verified | Sort-Object SHA1 | ForEach-Object { $_.SHA1 }) -join "|"
$verifiedSigHash = ""
try { $sha = [System.Security.Cryptography.SHA1]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($verifiedSig)); $verifiedSigHash = [BitConverter]::ToString($sha).Replace("-","") } catch { }

$legitClassHashes = New-Object System.Collections.Generic.HashSet[string]
$cacheLoaded = $false
if (Test-Path $whitelistCachePath) {
    try {
        $cache = Get-Content -Raw $whitelistCachePath | ConvertFrom-Json
        if ($cache.Signature -eq $verifiedSigHash -and $cache.Hashes) {
            foreach ($h in $cache.Hashes) { [void]$legitClassHashes.Add($h) }
            $cacheLoaded = $true
            Write-Host "  whitelist loaded: $($legitClassHashes.Count) hashes"
        }
    } catch { }
}
if (-not $cacheLoaded) {
    foreach ($v in $verified) {
        try {
            $zip = [System.IO.Compression.ZipFile]::OpenRead($v.Path)
            foreach ($e in $zip.Entries) {
                if (-not $e.FullName.EndsWith(".class")) { continue }
                if ($e.Length -gt 4MB) { continue }
                try { $ms = New-Object System.IO.MemoryStream; $s = $e.Open(); $s.CopyTo($ms); $s.Close(); $sha = [System.Security.Cryptography.SHA1]::Create().ComputeHash($ms.ToArray()); [void]$legitClassHashes.Add([BitConverter]::ToString($sha).Replace("-","").ToLower()); $ms.Dispose() } catch { }
            }
            $zip.Dispose()
        } catch { }
    }
    try { @{ Signature = $verifiedSigHash; Hashes = @($legitClassHashes) } | ConvertTo-Json -Compress -Depth 3 | Set-Content -Path $whitelistCachePath -Encoding UTF8 } catch { }
    Write-Host "  whitelist built: $($legitClassHashes.Count) hashes"
}
Write-Host ""

$moduleFindings = New-Object System.Collections.Generic.List[object]
$childProcFindings = New-Object System.Collections.Generic.List[object]
$suspiciousModulePatterns = '(?i)(click|macro|pulse|autoclick|inject|hook|kbm|inputsim|trigger|esp|xray|cheat|hack|ghost|shield|aura|aim)'
$systemPathPattern = '(?i)^C:\\(Windows|Program Files|Program Files \(x86\))\\'
$legitModNativePath = '(?i)\\mods\\|\\\.minecraft\\|\\natives\\|\\jbr\\|\\jdk|\\jre|\\java|\\javaw|\\lwjgl|\\glfw|\\openal|\\stb|\\sqlite|\\netty|\\asm|\\log4j'
$legitOverlayProcs = @('EOSOverlayRenderer','NVIDIA Overlay','NVIDIA Share','NvContainer','Steam','Discord','Overwolf','OBS','obs64','obs32','RivaTuner','MSIAfterburner','Medal','GeForceExperience','nvsphelper','GameBar','XboxGameBar')

if ($mcPid -gt 0) {
    try {
        $proc = Get-Process -Id $mcPid -ErrorAction Stop
        $modules = @($proc.Modules | Where-Object { $_.FileName -and $_.FileName -notmatch $systemPathPattern -and $_.FileName -notmatch $legitModNativePath -and $_.FileName -match '\.dll$' })
        foreach ($m in $modules) {
            $fn = $m.FileName; $name = Split-Path $fn -Leaf
            $flags = New-Object System.Collections.Generic.List[string]; $score = 0
            if ($name -match $suspiciousModulePatterns) { [void]$flags.Add("suspicious filename"); $score += 8 }
            if ($fn -match '(?i)\\AppData\\Local\\Temp\\') {
                if ($fn -match '(?i)(libopus4j|libspeex4j|librnnoise4j|liblame4j|libjitsi|libwebrtc|voicechat|natives?)') { continue }
                [void]$flags.Add("loaded from temp: $fn"); $score += 10
            }
            if ($fn -match '(?i)\\Downloads\\|\\Desktop\\') { [void]$flags.Add("loaded from downloads/desktop: $fn"); $score += 12 }
            if ($score -ge 8) { [void]$moduleFindings.Add([PSCustomObject]@{ Name = $name; Path = $fn; SizeKB = [math]::Round($m.ModuleMemorySize / 1KB, 1); Score = $score; Flags = $flags }) }
        }
    } catch { }
    try {
        $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId = $mcPid" -ErrorAction SilentlyContinue)
        foreach ($c in $children) {
            $cn = $c.Name; $cl = $c.CommandLine
            $flags = New-Object System.Collections.Generic.List[string]; $score = 0
            if ($cn -match '(?i)\.exe$' -and $cn -notmatch '(?i)^(java|javaw|jcmd|jps|jstack|conhost)\.exe$') { [void]$flags.Add("non-Java child: $cn"); $score += 3 }
            if ($cn -match $suspiciousModulePatterns) { [void]$flags.Add("cheat-matching name"); $score += 10 }
            if ($cl -and $cl -match '(?i)(inject|hook|attach|manualmap|reflective)') { [void]$flags.Add("suspicious cmdline"); $score += 8 }
            if ($score -ge 5) { [void]$childProcFindings.Add([PSCustomObject]@{ Pid = $c.ProcessId; Name = $cn; CommandLine = $cl; Score = $score; Flags = $flags }) }
        }
    } catch { }
    try {
        $siblings = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $mcPid -and $_.ProcessName -match $suspiciousModulePatterns })
        foreach ($s in $siblings) {
            $isLegit = $false
            foreach ($lp in $legitOverlayProcs) { if ($s.ProcessName -match "(?i)$([regex]::Escape($lp))") { $isLegit = $true; break } }
            if ($isLegit) { continue }
            [void]$childProcFindings.Add([PSCustomObject]@{ Pid = $s.Id; Name = "$($s.ProcessName).exe"; CommandLine = "(sibling)"; Score = 8; Flags = @("running alongside Minecraft with cheat-matching name") })
        }
    } catch { }
}

if ($moduleFindings.Count -gt 0 -or $childProcFindings.Count -gt 0) {
    foreach ($m in $moduleFindings) {
        Write-Host ("  SUSPICIOUS MODULE: {0}  [{1} KB]" -f $m.Name, $m.SizeKB) -ForegroundColor Red
        foreach ($f in $m.Flags) { Write-Host ("     - {0}" -f $f) -ForegroundColor DarkRed }
    }
    foreach ($p in $childProcFindings) {
        Write-Host ("  SUSPICIOUS PROC: PID {0} {1}" -f $p.Pid, $p.Name) -ForegroundColor Red
        foreach ($f in $p.Flags) { Write-Host ("     - {0}" -f $f) -ForegroundColor DarkRed }
    }
}
Write-Host ""

Write-Host "[ 3 ] OBFUSCATION" -ForegroundColor Cyan
$obfResults = New-Object System.Collections.Generic.List[object]
$devNames = @("CON","PRN","AUX","NUL","COM1","COM2","COM3","COM4","COM5","COM6","COM7","COM8","COM9","LPT1","LPT2","LPT3","LPT4","LPT5","LPT6","LPT7","LPT8","LPT9")
foreach ($jar in $jars) {
    $flags = New-Object System.Collections.Generic.List[string]
    $score = 0
    $singleCharRoot = 0; $nonAscii = 0; $zeroWidth = 0; $fullwidth = 0
    $hiragana = 0; $katakana = 0; $hangul = 0; $cjk = 0; $cyrillic = 0; $greek = 0
    $reservedHits = 0; $totalClasses = 0; $oneLetterNames = 0; $twoLetterNames = 0
    $numericNames = 0; $noVowelNames = 0; $gibberishNames = 0; $confusionNames = 0
    $singleCharPkgSegs = 0; $vanillaSpoof = 0
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($jar.FullName)
        foreach ($entry in $zip.Entries) {
            $n = $entry.FullName.Replace('\','/'); $nl = $n.ToLowerInvariant()
            if ($nl.EndsWith(".exe") -or $nl.EndsWith(".bat") -or $nl.EndsWith(".cmd") -or $nl.EndsWith(".ps1") -or $nl.EndsWith(".vbs") -or $nl.EndsWith(".scr")) { $flags.Add("Executable payload: $n") | Out-Null; $score += 20 }
            foreach ($d in $devNames) { if ($n -match "(^|/)$d\.") { $reservedHits++; break } }
            if ($n -match '^net/minecraft/' -and $n.EndsWith('.class')) { $vanillaSpoof++ }
            if ($nl.EndsWith(".class")) {
                $totalClasses++
                $bn = [System.IO.Path]::GetFileNameWithoutExtension($n)
                $parent = if ($n.Contains("/")) { $n.Substring(0, $n.LastIndexOf('/')) } else { "" }
                if ($bn.Length -eq 1 -and $parent -eq "") { $singleCharRoot++ }
                if ($bn.Length -eq 1) { $oneLetterNames++ } elseif ($bn.Length -eq 2) { $twoLetterNames++ }
                if ($bn -match '^\d+$') { $numericNames++ }
                if ($bn -match '^[Il1O0_]+$') { $confusionNames++ }
                if ($bn.Length -ge 3 -and $bn -match '^[a-zA-Z]+$') {
                    $vowels = 0
                    foreach ($ch in $bn.ToCharArray()) { if ($ch -match '[aeiouAEIOU]') { $vowels++ } }
                    if ($vowels -eq 0) { $noVowelNames++ }
                    elseif ($bn -match '[bcdfghjklmnpqrstvwxyzBCDFGHJKLMNPQRSTVWXYZ]{3,}' -and ($vowels / $bn.Length) -lt 0.3) { $gibberishNames++ }
                }
                if ($n.Contains("/")) { $segs = ($n -replace '\.class$','') -split '/'; for ($si = 0; $si -lt $segs.Count - 1; $si++) { if ($segs[$si].Length -eq 1) { $singleCharPkgSegs++ } } }
                $hasNonAscii = $false
                foreach ($ch in $bn.ToCharArray()) {
                    $cp = [int]$ch
                    if     ($cp -ge 0x3040 -and $cp -le 0x309F) { $hiragana++ }
                    elseif (($cp -ge 0x30A0 -and $cp -le 0x30FF) -or ($cp -ge 0x31F0 -and $cp -le 0x31FF)) { $katakana++ }
                    elseif (($cp -ge 0xAC00 -and $cp -le 0xD7AF) -or ($cp -ge 0x1100 -and $cp -le 0x11FF) -or ($cp -ge 0x3130 -and $cp -le 0x318F)) { $hangul++ }
                    elseif (($cp -ge 0x4E00 -and $cp -le 0x9FFF) -or ($cp -ge 0x3400 -and $cp -le 0x4DBF)) { $cjk++ }
                    elseif (($cp -ge 0x0400 -and $cp -le 0x04FF) -or ($cp -ge 0x0500 -and $cp -le 0x052F)) { $cyrillic++ }
                    elseif ($cp -ge 0x0370 -and $cp -le 0x03FF) { $greek++ }
                    elseif (($cp -ge 0xFF01 -and $cp -le 0xFF5E) -or ($cp -ge 0xFFE0 -and $cp -le 0xFFE6)) { $fullwidth++ }
                    elseif (($cp -ge 0x200B -and $cp -le 0x200F) -or $cp -eq 0xFEFF -or $cp -eq 0x2060 -or $cp -eq 0x180E) { $zeroWidth++ }
                    if ($cp -gt 127) { $hasNonAscii = $true }
                }
                if ($hasNonAscii) { $nonAscii++ }
            }
        }
        $zip.Dispose()
        $p1 = if ($totalClasses -ge 5) { [math]::Round(($oneLetterNames / $totalClasses) * 100) } else { 0 }
        $p2 = if ($totalClasses -ge 5) { [math]::Round(($twoLetterNames / $totalClasses) * 100) } else { 0 }
        $pn = if ($totalClasses -ge 5) { [math]::Round(($numericNames / $totalClasses) * 100) } else { 0 }
        $pu = if ($totalClasses -ge 5) { [math]::Round(($nonAscii / $totalClasses) * 100) } else { 0 }
        $pv = if ($totalClasses -ge 5) { [math]::Round(($noVowelNames / $totalClasses) * 100) } else { 0 }
        $pg = if ($totalClasses -ge 100) { [math]::Round(($gibberishNames / $totalClasses) * 100) } else { 0 }
        $pc = if ($totalClasses -ge 5) { [math]::Round(($confusionNames / $totalClasses) * 100) } else { 0 }
        if ($singleCharRoot -ge 5) { $flags.Add("Single-char root classes ($singleCharRoot)") | Out-Null; $score += 15 }
        if ($p1 -ge 15) { $flags.Add("One-letter class names ($p1%)") | Out-Null; $score += 12 }
        if ($p2 -ge 20) { $flags.Add("Two-letter class names ($p2%)") | Out-Null; $score += 10 }
        if ($pn -ge 20) { $flags.Add("Numeric class names ($pn%)") | Out-Null; $score += 12 }
        if ($pu -ge 10) { $flags.Add("Unicode class names ($pu%)") | Out-Null; $score += 12 }
        if ($pv -ge 8)  { $flags.Add("No-vowel class names ($pv%)") | Out-Null; $score += 10 }
        if ($pg -ge 15) { $flags.Add("Gibberish class names ($pg%)") | Out-Null; $score += 15 }
        if ($pc -ge 3)  { $flags.Add("Confusion-char names ($pc%)") | Out-Null; $score += 10 }
        if ($singleCharPkgSegs -ge 50 -and $totalClasses -ge 10) { $flags.Add("Single-char package segments ($singleCharPkgSegs)") | Out-Null; $score += 15 }
        if ($hiragana -ge 1) { $flags.Add("Hiragana obfuscator") | Out-Null; $score += 15 }
        if ($katakana -ge 1) { $flags.Add("Katakana obfuscator") | Out-Null; $score += 15 }
        if ($hangul   -ge 1) { $flags.Add("Hangul obfuscator") | Out-Null; $score += 15 }
        if ($cjk      -ge 1) { $flags.Add("CJK obfuscator") | Out-Null; $score += 15 }
        if ($cyrillic -ge 1) { $flags.Add("Cyrillic homoglyph obfuscator") | Out-Null; $score += 15 }
        if ($greek    -ge 1) { $flags.Add("Greek homoglyph obfuscator") | Out-Null; $score += 15 }
        if ($fullwidth -ge 3) { $flags.Add("Fullwidth unicode identifiers") | Out-Null; $score += 20 }
        if ($zeroWidth -ge 1) { $flags.Add("Zero-width unicode ($zeroWidth)") | Out-Null; $score += 30 }
        if ($nonAscii -ge 3 -and $hiragana -lt 1 -and $katakana -lt 1 -and $hangul -lt 1 -and $cyrillic -lt 1 -and $greek -lt 1) { $flags.Add("Non-ASCII identifier scrambling") | Out-Null; $score += 15 }
        if ($reservedHits -ge 1) { $flags.Add("Reserved Windows device names ($reservedHits)") | Out-Null; $score += 15 }
        if ($vanillaSpoof -ge 1) { $flags.Add("Vanilla namespace spoofing ($vanillaSpoof)") | Out-Null; $score += 25 }
    } catch { }
    if ($score -ge 15) { [void]$obfResults.Add([PSCustomObject]@{ Name = $jar.Name; Flags = $flags; Score = $score }) }
}

if ($obfResults.Count -eq 0) { Write-Host "  no obfuscation anomalies" -ForegroundColor DarkGreen }
else {
    foreach ($r in ($obfResults | Sort-Object Score -Descending)) {
        $col = if ($r.Score -ge 30) { "Red" } elseif ($r.Score -ge 15) { "Yellow" } else { "DarkYellow" }
        Write-Host ("  * {0}  [score {1}]" -f $r.Name, $r.Score) -ForegroundColor $col
        foreach ($f in $r.Flags) { Write-Host "      - $f" -ForegroundColor DarkGray }
    }
}
Write-Host ""

$attackNames  = @("attackEntity","doAttack","attack","swingHand","swing","hitEntity","tryAttack","doHit","leftClick","onAttack","attackTarget")
$trigNames    = @("atan2","sin","cos","tan","asin","acos","toRadians","toDegrees")
$randomNames  = @("nextInt","nextDouble","nextFloat","nextLong","nextGaussian","currentTimeMillis","nanoTime","random","Random","Math.random")
$schedNames   = @("scheduleAtFixedRate","scheduleWithFixedDelay","schedule","submit","execute","invokeLater","invokeAndWait","setInterval","setTimeout","submitAsync")
$sleepNames   = @("sleep","yield","parkNanos","parkUntil","park")
$packetNames  = @("sendPacket","writePacket","fireChannelRead","channelRead","sendImmediately","onSend","dispatch")
$tickNames    = @("register","registerTick","onTick","tick","endTick","startTick","onEndTick","onStartTick","registerListener","addListener","subscribe","addCallback")
$keyNames     = @("isPressed","wasPressed","isKeyPressed","isKeyDown","isMouseButtonPressed")
$reflectNames = @("invoke","setAccessible","getDeclaredMethod","getDeclaredField","getDeclaredConstructor","getMethod","getField","getConstructor","getDeclaredFields","newInstance")
$cdNames      = @("getAttackCooldownProgress","getAttackCooldownProgressPerTick","attackCooldown","getCooldownProgress")
$itemUseNames = @("useItem","interactItem","swapHandItems","interactBlock","interactEntity","dropSelectedItem","pickBlock")
$moveNames    = @("setVelocity","addVelocity","setPos","setPosition","move","jump","setOnGround","setNoGravity","setFlying","setSprinting","setNoClip","setFallDistance")
$visNames     = @("shouldRender","isVisible","canSee","canBeRendered","getBlockState","renderLabel","isInsideFrustum","isCulled")
$sensConstants = @(0.6, 8.0, 0.15, 0.3, 0.006, 0.0075)
$rotationFields = @("yaw","pitch","prevyaw","prevpitch","lastyaw","lastpitch","headyaw","bodyyaw","renderyaw","renderpitch","field_5965","field_5964","f_19858_","f_19857_")
$yarnReflectNames = @("class_310","class_1657","class_1297","class_1309","class_2338","class_2248","method_1551","method_1434","method_23481","method_1881","method_1499","method_23317","method_23321","field_1690","field_1886","field_1705","field_1729","field_5965","field_5964")
$timerConstants = @(50L,100L,150L,175L,200L,250L,500L)
$sensitiveMixinTargets = @("doAttack","isPressed","wasPressed","isKeyPressed","attackEntity","interactBlock","interactEntity","sendPacket")
$freeHostDomains = @('onrender.com','vercel.app','netlify.app','herokuapp.com','firebaseio.com','glitch.me','repl.co','ngrok.io','ngrok-free.app','trycloudflare.com','loca.lt','workers.dev','pages.dev','surge.sh')
$webhookRegex = [regex]::new('https?://(?:discord(?:app)?\.com/api/webhooks/\d+/[\w-]+|hooks\.slack\.com/services/[\w/]+|api\.telegram\.org/bot\d+:[\w-]+)', 'IgnoreCase')
$hwidNames = @("getProcessorID","getVolumeSerialNumber","getComputerName","getMACAddress","getDiskSerial","getBaseboardSerial","getMachineId")
$sandboxStrings = @("sandbox","VirtualBox","VMware","QEMU","cuckoo","wireshark","procmon","x64dbg","ollydbg","ida64","WinDbg")
$knownClientFamilies = @("meteordevelopment","net/wurstclient","WurstClient","net/ccbluex/liquidbounce","LiquidBounce","com/darkmagician6/eventapi","net/impactclient","me/zeroeightsix/kami","RusherHack","FutureClient","today/opai/client","doomsdayclient","novoware","hellclient","skidfuscator.dev","dev/virel","catlean","org/chainlibs")
$nativeInputNames = @("SendInput","mouse_event","SetCursorPos","keybd_event","GetAsyncKeyState","SetWindowsHookEx","GetForegroundWindow","SetForegroundWindow","FindWindow")
$glfwInputNames = @("glfwSetMouseButtonCallback","glfwSetCursorPosCallback","glfwSetKeyCallback")
$robotClassNames = @("java/awt/Robot","Robot.mousePress","Robot.mouseRelease","Robot.mouseMove","Robot.keyPress")
$mouseReflectionNames = @("method_1601","method_1611","field_1799","field_1800","field_1801","field_1802","onMouseButton","activeButton","leftButton","rightButton","middleButton","cursorLocked")
$keyBindingReflectionNames = @("method_1434","method_23481","isPressed","setPressed","timesPressed")
$entityListNames = @('getOtherEntities','getEntities','getEntitiesByClass','getPlayers','getNearbyEntities')

$CAT = @{
    "AUTO_CLICK_KEY_REFLECTION" = @{ W = 10; L = "AUTO-ATTACK VIA KEY-REFLECTION + TIMER"; E = "Reads KeyBinding via Yarn reflection and toggles isPressed/setPressed on a timer. This is the autoclicker pattern." }
    "INJECTED_CLASS_PAYLOAD"    = @{ W = 8;  L = "INJECTED CLASS PAYLOAD (JDK SPLIT)"; E = "Small set of classes compiled on a newer JDK than the majority. Someone dropped extra classes into the jar." }
    "NOVEL_CLASS_RATIO"         = @{ W = 6;  L = "NOVEL CLASSES (not on Modrinth)"; E = "None of these classes exist in any Modrinth-published mod. Custom code with no public source." }
    "PACKED_LOADER"             = @{ W = 10; L = "PACKED REFLECTIVE CLASSLOADER"; E = "defineClass + readFully + embedded map. Runtime class decryption." }
    "REFLECTIVE_LOADER"         = @{ W = 9;  L = "REFLECTIVE CLASSLOADER ENTRYPOINT"; E = "defineClass + readFully + reflection. Loads classes from bytes." }
    "EMBEDDED_PAYLOAD"          = @{ W = 8;  L = "EMBEDDED ENCRYPTED PAYLOAD"; E = "defineClass + getResourceAsStream. Loads hidden class from resource." }
    "CUSTOM_CLASSLOADER"        = @{ W = 8;  L = "CUSTOM CLASSLOADER SUBCLASS"; E = "ClassLoader subclass + defineClass + reflection." }
    "KEY_TOGGLE_AUTOMATION"     = @{ W = 7;  L = "AUTOMATED KEY-STATE TOGGLING"; E = "isPressed + setPressed + randomness. Autoclicker." }
    "TIMER_KEY_COMBO"           = @{ W = 7;  L = "TIMER + KEY-STATE COMBO"; E = "isPressed + setPressed + timer constant." }
    "XOR_STRING_DECRYPTION"     = @{ W = 6;  L = "XOR STRING DECRYPTION"; E = "XOR + new String in same method. Hidden strings." }
    "STATIC_MUTABLE_STATE"      = @{ W = 3;  L = "STATIC MUTABLE STATE MACHINE"; E = "Multiple static mutable primitives + reflection + timer." }
    "OVERWRITE_SENSITIVE"       = @{ W = 6;  L = "OVERWRITE ON SENSITIVE METHOD"; E = "@Overwrite on doAttack / isPressed / sendPacket." }
    "SENSITIVE_MIXIN_TARGET"    = @{ W = 4;  L = "MIXIN INTO SENSITIVE METHOD"; E = "Mixin targeting doAttack / isPressed / sendPacket." }
    "THREAD_SLEEP_IN_TICK"      = @{ W = 5;  L = "THREAD.SLEEP IN TICK HANDLER"; E = "Blocking sleep on render thread." }
    "URLCLASSLOADER"            = @{ W = 7;  L = "RUNTIME CLASSPATH LOADING"; E = "URLClassLoader + reflection." }
    "IMGUI_MENU"                = @{ W = 8;  L = "IMGUI / CLICKGUI MENU"; E = "Bundles ImGui. Almost exclusively used by cheat ClickGUIs." }
    "NATIVE_METHOD"             = @{ W = 4;  L = "NATIVE METHOD DECLARED"; E = "Native method + reflection or packet." }
    "ANTI_DEBUG"                = @{ W = 6;  L = "ANTI-DEBUG / ANTI-VM CHECKS"; E = "Debugger/sandbox detection strings." }
    "ACCESS_TOKEN_REF"          = @{ W = 10; L = "SESSION TOKEN REFERENCE"; E = "Reads launcher_accounts / accessToken. Session harvesting." }
    "SOCKET_C2"                 = @{ W = 8;  L = "RAW SOCKET C2"; E = "Raw socket + backdoor port." }
    "BACKDOOR_PORT"             = @{ W = 7;  L = "HARDCODED BACKDOOR PORT"; E = "1337 / 4444 / 31337 constants." }
    "WEBHOOK_EXFIL"             = @{ W = 10; L = "DISCORD/SLACK/TELEGRAM WEBHOOK"; E = "Discord/Slack/Telegram webhook URL in constant pool." }
    "FREE_HOST_C2"              = @{ W = 7;  L = "FREE HOST C2 ENDPOINT"; E = "Vercel/onrender/ngrok. Cheap C2." }
    "SELF_AWARE_ANTI_SCAN"      = @{ W = 8;  L = "SELF-AWARE ANTI-SCAN STRINGS"; E = "HWID / AuthCheck / AntiScan strings." }
    "HWID_FINGERPRINT"          = @{ W = 10; L = "HWID FINGERPRINTING"; E = "Reads hardware ID. License binding." }
    "SANDBOX_DETECTION"         = @{ W = 10; L = "SANDBOX / DEBUGGER DETECTION"; E = "Refuses to run under analysis." }
    "KNOWN_CLIENT_FAMILY"       = @{ W = 10; L = "KNOWN CHEAT CLIENT FAMILY"; E = "Wurst / LiquidBounce / Meteor / Impact signature." }
    "KILLAURA_LOOP"             = @{ W = 10; L = "KILLAURA LOOP (ENTITY QUERY + ATTACK)"; E = "Queries nearby entities AND attacks in same class." }
    "SILENT_ROTATION_CORRELATION" = @{ W = 10; L = "SILENT ROTATION (YAW READ+WRITE + PACKET)"; E = "Reads + writes yaw/pitch + sends packet in same class." }
    "NATIVE_INPUT_INJECTION"    = @{ W = 10; L = "NATIVE OS INPUT INJECTION"; E = "SendInput / mouse_event / SetCursorPos via JNI." }
    "ROBOT_CLASS_USAGE"         = @{ W = 9;  L = "JAVA ROBOT INPUT SIMULATION"; E = "java.awt.Robot presses the mouse." }
    "CLICKER_INPUT_SIMULATION"  = @{ W = 10; L = "SIMULATED CLICK INPUT"; E = "Simulates mouse via OS or GLFW." }
    "MOUSE_STATE_REFLECTION"    = @{ W = 8;  L = "MOUSE STATE REFLECTION"; E = "Reflects Mouse.onMouseButton / activeButton." }
    "CLICKER_DLL_BUNDLED"       = @{ W = 10; L = "BUNDLED CLICKER DLL"; E = "Ships a clicker-library DLL." }
    "ATTACK_TICK_EVENT"         = @{ W = 7;  L = "ATTACK VIA TICK EVENT"; E = "Attack + tick + key poll." }
    "ATTACK_KEY_POLL"           = @{ W = 7;  L = "ATTACK VIA KEY POLLING"; E = "Attack + key poll + randomness." }
    "ATTACK_COOLDOWN_GATED"     = @{ W = 6;  L = "COOLDOWN-GATED ATTACK"; E = "Attack + cooldown check + tick." }
    "ATTACK_REFLECTION"         = @{ W = 6;  L = "REFLECTION-DRIVEN ATTACK"; E = "Attack + reflection." }
    "AUTO_ATTACK_THREADED"      = @{ W = 6;  L = "ATTACK FROM THREAD BODY"; E = "Attack inside Thread/Runnable." }
    "AUTO_ATTACK_SCHEDULED"     = @{ W = 6;  L = "SCHEDULED ATTACK DISPATCH"; E = "Attack + scheduler." }
    "AUTO_ATTACK_SLEEP_LOOP"    = @{ W = 5;  L = "SLEEP-DRIVEN ATTACK LOOP"; E = "Attack + sleep." }
    "AUTO_ATTACK_RANDOMIZED"    = @{ W = 5;  L = "RANDOMIZED ATTACK TIMING"; E = "Attack + randomness." }
    "SILENT_AIM_TRIG"           = @{ W = 6;  L = "TRIG-GATED ROTATION WRITE"; E = "Rotation field write + trig math." }
    "AIM_INTERPOLATION"         = @{ W = 5;  L = "SENSITIVITY-GATED AIM WRITE"; E = "Rotation write + GCD sensitivity constants." }
    "ROTATION_INJECTION"        = @{ W = 4;  L = "ROTATION INJECTION"; E = "Rotation write + attack/packet." }
    "PACKET_AUTOMATION"         = @{ W = 5;  L = "SCHEDULED PACKET AUTOMATION"; E = "Scheduler + packet + item use." }
    "ITEM_USE_AUTOMATION"       = @{ W = 4;  L = "AUTOMATED ITEM-USE"; E = "Item use + key + tick." }
    "MOVEMENT_INJECTION"        = @{ W = 4;  L = "MOVEMENT INJECTION"; E = "Velocity/setPos + key + tick." }
    "RENDER_VISIBILITY_HOOK"    = @{ W = 2;  L = "RENDER VISIBILITY FILTER"; E = "Mixin on render visibility. Xray/ESP risk." }
    "MIXIN_COMBAT_HOOK"         = @{ W = 3;  L = "MIXIN COMBAT/TICK HOOK"; E = "Mixin targeting combat/tick." }
    "TICK_RATE_MANIPULATION"    = @{ W = 3;  L = "TICK RATE MANIPULATION"; E = "Writes tick delta/rate." }
    "UNSAFE_MEMORY"             = @{ W = 3;  L = "UNSAFE MEMORY ACCESS"; E = "Unsafe + reflection + timer." }
    "ASM_BYTECODE_MANIPULATION" = @{ W = 9;  L = "RUNTIME BYTECODE MANIPULATION (ASM)"; E = "Uses ASM to rewrite bytecode. Legit mods use Mixin." }
    "NETWORK_INTERFACE_ENUM"    = @{ W = 9;  L = "NETWORK INTERFACE ENUMERATION"; E = "Enumerates NICs. License binding." }
    "SYNTHETIC_FIELD_EXPLOSION" = @{ W = 7;  L = "SYNTHETIC FIELD EXPLOSION"; E = "20+ synthetic fields. Obfuscator signature." }
}

$cheatStrings = @(
    "Aim Assist","Aimassist","Anchor macro","Anti Phase","Anti Web","Attack Delay","Attack Players","Aura",
    "Auto Armor","Auto Base Place","Auto Buff","Auto crystal","Auto Double Hand","Auto D-Tap","Auto Eat",
    "Auto Hit Crystal","Auto Inventory Totem","Auto Jump Reset","Auto loot","Auto Mace","Auto Mend","Auto Mine",
    "Auto Nether Potion","Auto Pot","Auto Pot Refill","Auto Potion","Auto shield breaker","Auto Switch","Auto Web",
    "Auto WTap","AutoAnchor","Autoarmor","Autoclicker","Autodoublehand","AutoHitCrystal","AutoInventoryTotem",
    "Autoretotem","Autototem","Axe Delay","Boat Fly","Bow Aimbot","Break ESP","Click Aimassist","Click Simulation",
    "ClickAimassist","ClickCrystal","Crystal Aim Assist","Crystal optimizer","CrystalAura","Cw Crystal","Disable Shields",
    "Double Glowstone","Elytra Target","Equip Delay","Fake cps","Fake Lag","fast place","Freecam","Generic autoanchor",
    "Generic Crystal Optimizer","Generic Selfdestruct","GUI Move","Height Expansion","High Jump","hit delay","Hole Anchor",
    "Horizontal Speed","Hover Totem","Illegal Modifications","Item ESP","Legit Totem","Mace Elytra Target","Mace Swap",
    "Macro anchor","Netherite Finder","No Miss Delay","Nuker","Off Hand","Only Crit Axe","Only Crit Sword","Pearl Chaser",
    "Ping spoof","Pop Chams","Projectile Predict","Quiver","Scaffold","Shield Disabler","Slot selection","Spawner Miner",
    "Speed Delay","Speed Mine","Speed Multiplier","Sticky Aim","Stop on Kill","String Cleaner","Surround","Switch Back",
    "Switch Delay","Sword Delay","throw delay","Tracers","Trajectories","Trigger Bot","TriggerBot","Vertical Speed",
    "Void ESP","WalksyOptimizer","Width Expansion","Wind Hop","X-Ray","KillAura","AimAssist","AutoCrystal","AutoTotem",
    "AntiKnockback","AntiKB","NoFall","XRay","ChestESP","PlayerESP","EntityESP","MobESP","NameESP","BoxESP","SkeletonESP",
    "FastBreak","ChestStealer","InvMove","Criticals","ClickAura","MultiAura","BowAimbot","AutoClicker","AntiBot",
    "NoSlowdown","NoSlow","Blink","FastPlace","AutoPot","FlyHack","SpeedHack","AutoAnchor","AnchorAura","CrystalAura",
    "BedAura","ReachHack","HitboxExpand","SilentAim","AimLock","HeadSnap","ForceField","LegitAura","PingSpoof",
    "SelfDestruct","ShieldBreaker","meteordevelopment","cc/novoline","com/alan/clients","wtf/moonlight","me/zeroeightsix/kami",
    "net/ccbluex","today/opai","vape.gg","liquidbounce","fdp-client","rusherhack","wurst","doomsdayclient","prestigeclient",
    "198macros","dqrkis","catlean","asteria","xenon","gypsy","novoware","hellclient","chaosclient","opai","chainlibs",
    "skidfuscator","isObsidianOrBedrock","isValidCrystalPosition","processAnchorPvP","findKnockbackSword",
    "modifyDecrementAmount","preventSwordFromBlockAttack","shouldBlockBlockHit","setBlockBreakingCooldown",
    "getBlockBreakingCooldown","setItemUseCooldown","invokeDoAttack","invokeDoItemUse","setSelectedSlot",
    "swapBackToOriginalSlot","invokeOnMouseButton","getHandSwingDuration","predictCrystals","noOffhandTotem",
    "getNearByCrystals","slotExplode","findTotemSlot","activateOnRightClick","crystalPlaceClock","isDeadBodyNearby",
    "CrystalTwiceClock","POT_CHEATS","DontPlaceCrystal","DontBreakCrystal","CanPlaceCrystalServer",
    "Skidfuscator","Paramorphism","RadonObfuscator","Caesium","Bozar","Branchlock","Binscure","SuperBlaubeere27",
    "Qprotect","ZKMFLOW","ZelixKlassMaster","StringerJavaObfuscator","JNIC","ScutiObf","SmokeObf","AllatoriObfuscator",
    "ProGuard","imgui.gl3","imgui.glfw","imgui-java","ImGuiImpl","isDebuggerPresent","ptrace","TracerPid",
    "accessToken","launcher_profiles","launcher_accounts","refreshToken"
)
$escaped = $cheatStrings | ForEach-Object { [regex]::Escape($_) }
$cheatRegex = New-Object System.Text.RegularExpressions.Regex(($escaped -join '|'), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

function Convert-FullwidthToAscii { param([string]$Text)
    if (-not $Text) { return "" }
    $sb = New-Object System.Text.StringBuilder $Text.Length
    foreach ($ch in $Text.ToCharArray()) {
        $cp = [int]$ch
        if ($cp -ge 0xFF01 -and $cp -le 0xFF5E) { [void]$sb.Append([char]($cp - 0xFEE0)) }
        elseif ($cp -eq 0x3000) { [void]$sb.Append(' ') }
        else { [void]$sb.Append($ch) }
    }
    return $sb.ToString()
}

function Get-ClassUtf8 { param([byte[]]$bytes)
    $out = New-Object System.Collections.Generic.List[string]
    if (-not $bytes -or $bytes.Length -lt 10) { return ,$out }
    if (-not ($bytes[0] -eq 0xCA -and $bytes[1] -eq 0xFE -and $bytes[2] -eq 0xBA -and $bytes[3] -eq 0xBE)) { return ,$out }
    try {
        $p = 8; $cpCount = ($bytes[$p] -shl 8) -bor $bytes[$p+1]; $p += 2
        for ($i = 1; $i -lt $cpCount; $i++) {
            if ($p -ge $bytes.Length) { break }
            $tag = [int]$bytes[$p]; $p++
            switch ($tag) {
                1 { $len = ($bytes[$p] -shl 8) -bor $bytes[$p+1]; $p += 2
                    if ($p + $len -gt $bytes.Length) { break }
                    if ($len -ge 3) { [void]$out.Add([System.Text.Encoding]::UTF8.GetString($bytes, $p, $len)) }
                    $p += $len }
                3 { $p += 4 } 4 { $p += 4 } 5 { $p += 8; $i++ } 6 { $p += 8; $i++ }
                7 { $p += 2 } 8 { $p += 2 } 9 { $p += 4 } 10 { $p += 4 }
                11 { $p += 4 } 12 { $p += 4 } 15 { $p += 3 } 16 { $p += 2 }
                17 { $p += 4 } 18 { $p += 4 } 19 { $p += 2 } 20 { $p += 2 }
                default { break }
            }
        }
    } catch { }
    return ,$out
}

function Get-ClassInfo { param([byte[]]$bytes)
    $info = [ordered]@{
        ThisClass="";SuperClass="";Interfaces=@();IsMixin=$false;InvokedMethods=@();FieldWrites=@();FieldReads=@()
        FloatConstants=@();LongConstants=@();Utf8Strings=@();Error=$null;ClassVersion=0
        HasXor=$false;HasNewString=$false;HasXorDecrypt=$false;MixinOverwrite=$false;MixinTargetsSensitive=$false
        HasThreadSleep=$false;HasURLClassLoader=$false;HasUnsafe=$false;HasImgui=$false;HasNativeMethod=$false
        HasAntiDebug=$false;HasTickRate=$false;HasAccessToken=$false;HasSocketC2=$false;HasBackdoorPort=$false
        HasSelfAware=0;HasWebhook=$false;HasFreeHost=$false;StaticMutablePrimitives=0;WebhookUrls=@();FreeHostUrls=@()
        HasAsm=$false;HasNetworkEnum=$false;HasHwid=$false;HasSandbox=$false;HasKnownFamily=$false
        HasPacketCombat=$false;HasLocalAttack=$false;HasYawRead=$false;HasYawWrite=$false
        HasEntityListQuery=$false;HasAttackCall=$false;SyntheticFieldCount=0
        HasRobotClass=$false;RobotHitCount=0;HasNativeInput=$false;NativeInputHitCount=0
        HasGlfwInput=$false;HasMouseReflection=$false;MouseReflectHitCount=0
        HasKeyBindingReflection=$false;KeyBindingReflectHitCount=0;MethodInvokes=@{}
    }
    if (-not $bytes -or $bytes.Length -lt 10) { $info.Error = "empty"; return $info }
    if (-not ($bytes[0] -eq 0xCA -and $bytes[1] -eq 0xFE -and $bytes[2] -eq 0xBA -and $bytes[3] -eq 0xBE)) { $info.Error = "not class"; return $info }
    try {
        $p = 8; $cpCount = ($bytes[$p] -shl 8) -bor $bytes[$p+1]; $p += 2
        $cpTag = New-Object 'int[]' $cpCount; $cpA = New-Object 'int[]' $cpCount; $cpB = New-Object 'int[]' $cpCount
        $cpStr = New-Object 'string[]' $cpCount; $cpDbl = New-Object 'double[]' $cpCount; $cpLng = New-Object 'long[]' $cpCount
        for ($i = 1; $i -lt $cpCount; $i++) {
            if ($p -ge $bytes.Length) { throw "cp trunc" }
            $tag = [int]$bytes[$p]; $p++; $cpTag[$i] = $tag
            switch ($tag) {
                1 { $len = ($bytes[$p] -shl 8) -bor $bytes[$p+1]; $p += 2
                    if ($p + $len -gt $bytes.Length) { throw "overrun" }
                    $cpStr[$i] = [System.Text.Encoding]::UTF8.GetString($bytes, $p, $len); $p += $len }
                3 { $cpA[$i] = ($bytes[$p] -shl 24) -bor ($bytes[$p+1] -shl 16) -bor ($bytes[$p+2] -shl 8) -bor $bytes[$p+3]; $cpDbl[$i] = [double]$cpA[$i]; $p += 4 }
                4 { $t = New-Object 'byte[]' 4; [Array]::Copy($bytes,$p,$t,0,4); if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($t) }; $cpDbl[$i] = [double][BitConverter]::ToSingle($t,0); $p += 4 }
                5 { $t = New-Object 'byte[]' 8; [Array]::Copy($bytes,$p,$t,0,8); if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($t) }; $cpLng[$i] = [BitConverter]::ToInt64($t,0); $cpDbl[$i] = [double]$cpLng[$i]; $p += 8; $i++ }
                6 { $t = New-Object 'byte[]' 8; [Array]::Copy($bytes,$p,$t,0,8); if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($t) }; $cpDbl[$i] = [BitConverter]::ToDouble($t,0); $p += 8; $i++ }
                7 { $cpA[$i] = ($bytes[$p] -shl 8) -bor $bytes[$p+1]; $p += 2 }
                8 { $cpA[$i] = ($bytes[$p] -shl 8) -bor $bytes[$p+1]; $p += 2 }
                9 { $cpA[$i] = ($bytes[$p] -shl 8) -bor $bytes[$p+1]; $cpB[$i] = ($bytes[$p+2] -shl 8) -bor $bytes[$p+3]; $p += 4 }
                10 { $cpA[$i] = ($bytes[$p] -shl 8) -bor $bytes[$p+1]; $cpB[$i] = ($bytes[$p+2] -shl 8) -bor $bytes[$p+3]; $p += 4 }
                11 { $cpA[$i] = ($bytes[$p] -shl 8) -bor $bytes[$p+1]; $cpB[$i] = ($bytes[$p+2] -shl 8) -bor $bytes[$p+3]; $p += 4 }
                12 { $cpA[$i] = ($bytes[$p] -shl 8) -bor $bytes[$p+1]; $cpB[$i] = ($bytes[$p+2] -shl 8) -bor $bytes[$p+3]; $p += 4 }
                15 { $p += 3 } 16 { $p += 2 } 17 { $p += 4 } 18 { $p += 4 } 19 { $p += 2 } 20 { $p += 2 }
                default { throw "tag $tag" }
            }
        }
        $className = New-Object 'string[]' $cpCount
        $methodName = New-Object 'string[]' $cpCount
        $fieldNameArr = New-Object 'string[]' $cpCount
        $natName = New-Object 'string[]' $cpCount
        for ($i = 1; $i -lt $cpCount; $i++) {
            if ($cpTag[$i] -eq 7) { $u = $cpA[$i]; if ($u -gt 0 -and $u -lt $cpCount -and $cpStr[$u]) { $className[$i] = $cpStr[$u] } }
            elseif ($cpTag[$i] -eq 12) { $n = $cpA[$i]; if ($n -gt 0 -and $n -lt $cpCount -and $cpStr[$n]) { $natName[$i] = $cpStr[$n] } }
        }
        for ($i = 1; $i -lt $cpCount; $i++) {
            $tag = $cpTag[$i]
            if ($tag -eq 10 -or $tag -eq 11) { $n = $cpB[$i]; if ($n -gt 0 -and $natName[$n]) { $methodName[$i] = $natName[$n] } }
            elseif ($tag -eq 9) { $n = $cpB[$i]; if ($n -gt 0 -and $natName[$n]) { $fieldNameArr[$i] = $natName[$n] } }
        }
        $info.ClassVersion = ($bytes[6] -shl 8) -bor $bytes[7]
        $p += 2
        $thisIdx = ($bytes[$p] -shl 8) -bor $bytes[$p+1]; $p += 2
        $superIdx = ($bytes[$p] -shl 8) -bor $bytes[$p+1]; $p += 2
        if ($thisIdx -gt 0 -and $thisIdx -lt $cpCount) { $info.ThisClass = $className[$thisIdx] }
        if ($superIdx -gt 0 -and $superIdx -lt $cpCount) { $info.SuperClass = $className[$superIdx] }

        $webhookHits = New-Object System.Collections.Generic.List[string]
        $freeHostHits = New-Object System.Collections.Generic.List[string]
        foreach ($s in $cpStr) {
            if (-not $s) { continue }
            if ($s.StartsWith("Lorg/spongepowered/asm/mixin/")) { $info.IsMixin = $true }
            if ($s -match 'Overwrite;') { $info.MixinOverwrite = $true }
            if ($s -match '(?i)imgui\.gl3|imgui\.glfw|imgui-java|ImGuiImpl') { $info.HasImgui = $true }
            if ($s -match 'accessToken|launcher_profiles|launcher_accounts|session\.json|refreshToken') { $info.HasAccessToken = $true }
            if ($s -match '(?i)isDebuggerPresent|CheckRemoteDebuggerPresent|ptrace|TracerPid') { $info.HasAntiDebug = $true }
            if ($s -match 'setTickRate|tickDelta|tickRateManager|tickRate') { $info.HasTickRate = $true }
            if ($s -match '\b(1337|4444|5555|31337|8080|8888|9999)\b') { $info.HasBackdoorPort = $true }
            if ($s -match 'URLClassLoader|defineClass') { $info.HasURLClassLoader = $true }
            if ($s -match 'sun/misc/Unsafe|jdk/internal/misc/Unsafe') { $info.HasUnsafe = $true }
            if ($s -match 'getOutputStream|getInputStream') { $info.HasSocketC2 = $true }
            if ($s -match '(?i)\bAntiScan\b|\bAntiFlag\b|\bAntiDetect\b|\bHWID\b|\bHWIDCheck\b|\bLicenseAuth\b|\bAuthCheck\b') { $info.HasSelfAware++ }
            foreach ($m in $webhookRegex.Matches($s)) { [void]$webhookHits.Add($m.Value); $info.HasWebhook = $true }
            foreach ($fh in $freeHostDomains) { if ($s -match [regex]::Escape($fh)) { [void]$freeHostHits.Add($s); $info.HasFreeHost = $true; break } }
            if ($s -match 'org/objectweb/asm') { $info.HasAsm = $true }
            if ($s -eq 'getNetworkInterfaces' -or $s -eq 'getHardwareAddress') { $info.HasNetworkEnum = $true }
            foreach ($h in $hwidNames) { if ($s -eq $h) { $info.HasHwid = $true; break } }
            foreach ($sb in $sandboxStrings) { if ($s -match "(?i)\b$([regex]::Escape($sb))\b") { $info.HasSandbox = $true; break } }
            foreach ($fam in $knownClientFamilies) { if ($s -match [regex]::Escape($fam)) { $info.HasKnownFamily = $true; break } }
            foreach ($pk in @("PlayerInteractEntityC2SPacket","PlayerActionC2SPacket","PlayerMoveC2SPacket","UpdateSelectedSlotC2SPacket")) { if ($s -match [regex]::Escape($pk)) { $info.HasPacketCombat = $true; break } }
            foreach ($r in $robotClassNames) { if ($s -match [regex]::Escape($r)) { $info.RobotHitCount++; $info.HasRobotClass = $true; break } }
            foreach ($n in $nativeInputNames) { if ($s -eq $n) { $info.NativeInputHitCount++; $info.HasNativeInput = $true; break } }
            foreach ($g in $glfwInputNames) { if ($s -eq $g) { $info.HasGlfwInput = $true; break } }
            foreach ($mr in $mouseReflectionNames) { if ($s -eq $mr) { $info.MouseReflectHitCount++; $info.HasMouseReflection = $true; break } }
            foreach ($kb in $keyBindingReflectionNames) { if ($s -eq $kb) { $info.KeyBindingReflectHitCount++; $info.HasKeyBindingReflection = $true; break } }
        }
        $info.WebhookUrls = @($webhookHits); $info.FreeHostUrls = @($freeHostHits)
        foreach ($mn in $sensitiveMixinTargets) { foreach ($s in $cpStr) { if ($s -eq $mn) { $info.MixinTargetsSensitive = $true; break } }; if ($info.MixinTargetsSensitive) { break } }

        $ifaceCount = ($bytes[$p] -shl 8) -bor $bytes[$p+1]; $p += 2
        $ifaces = New-Object System.Collections.Generic.List[string]
        for ($i = 0; $i -lt $ifaceCount; $i++) { $ii = ($bytes[$p] -shl 8) -bor $bytes[$p+1]; $p += 2; if ($ii -gt 0 -and $ii -lt $cpCount -and $className[$ii]) { $ifaces.Add($className[$ii]) | Out-Null } }
        $info.Interfaces = @($ifaces)

        $fc = ($bytes[$p] -shl 8) -bor $bytes[$p+1]; $p += 2
        for ($i = 0; $i -lt $fc; $i++) {
            $fieldAcc = ($bytes[$p] -shl 8) -bor $bytes[$p+1]
            $nameIdx = ($bytes[$p+2] -shl 8) -bor $bytes[$p+3]
            $descIdx = ($bytes[$p+4] -shl 8) -bor $bytes[$p+5]
            $fname = if ($nameIdx -gt 0 -and $nameIdx -lt $cpCount) { $cpStr[$nameIdx] } else { "" }
            $desc = if ($descIdx -gt 0 -and $descIdx -lt $cpCount) { $cpStr[$descIdx] } else { "" }
            $isStatic = ($fieldAcc -band 0x0008) -ne 0
            $isFinal = ($fieldAcc -band 0x0010) -ne 0
            if ($isStatic -and -not $isFinal -and $desc.Length -eq 1 -and $desc -match '[ZBCSIJFD]') { $info.StaticMutablePrimitives++ }
            if ($fname -match '^(access\$\d+|\$SwitchMap\$|this\$|\$VALUES)' -or $fname -match '^val\$' -or $fname -match '^arg\$') { $info.SyntheticFieldCount++ }
            $p += 6
            $ac = ($bytes[$p] -shl 8) -bor $bytes[$p+1]; $p += 2
            for ($j = 0; $j -lt $ac; $j++) {
                $p += 2
                $alen = ($bytes[$p] -shl 24) -bor ($bytes[$p+1] -shl 16) -bor ($bytes[$p+2] -shl 8) -bor $bytes[$p+3]
                $p += 4 + $alen
            }
        }
        $codeNameIdx = -1
        for ($i = 1; $i -lt $cpCount; $i++) { if ($cpStr[$i] -eq "Code") { $codeNameIdx = $i; break } }
        $invokedSet = New-Object System.Collections.Generic.HashSet[string]
        $fieldWriteSet = New-Object System.Collections.Generic.HashSet[string]
        $fieldReadSet = New-Object System.Collections.Generic.HashSet[string]
        $constSet = New-Object System.Collections.Generic.HashSet[double]
        $longSet = New-Object System.Collections.Generic.HashSet[long]
        $stringSet = New-Object System.Collections.Generic.HashSet[string]
        for ($i = 1; $i -lt $cpCount; $i++) {
            if ($cpTag[$i] -eq 1 -and $cpStr[$i] -and $cpStr[$i].Length -ge 3) { [void]$stringSet.Add($cpStr[$i]) }
            if ($cpTag[$i] -eq 5 -and $cpLng[$i] -ne 0) { [void]$longSet.Add($cpLng[$i]) }
        }
        $mc = ($bytes[$p] -shl 8) -bor $bytes[$p+1]; $p += 2
        for ($i = 0; $i -lt $mc; $i++) {
            $methodAcc = ($bytes[$p] -shl 8) -bor $bytes[$p+1]
            if (($methodAcc -band 0x0100) -ne 0) { $info.HasNativeMethod = $true }
            $p += 6
            $ac = ($bytes[$p] -shl 8) -bor $bytes[$p+1]; $p += 2
            for ($j = 0; $j -lt $ac; $j++) {
                $ani = ($bytes[$p] -shl 8) -bor $bytes[$p+1]; $p += 2
                $alen = ($bytes[$p] -shl 24) -bor ($bytes[$p+1] -shl 16) -bor ($bytes[$p+2] -shl 8) -bor $bytes[$p+3]
                $p += 4; $aEnd = $p + $alen
                if ($ani -eq $codeNameIdx) {
                    $p += 4
                    $clen = ($bytes[$p] -shl 24) -bor ($bytes[$p+1] -shl 16) -bor ($bytes[$p+2] -shl 8) -bor $bytes[$p+3]
                    $p += 4; $cStart = $p; $cEnd = $p + $clen
                    $mXor = $false; $mNewStr = $false
                    for ($k = $cStart; $k -le $cEnd - 3; $k++) {
                        $op = [int]$bytes[$k]
                        if ($op -ge 0xB6 -and $op -le 0xB9) {
                            $ref = ($bytes[$k+1] -shl 8) -bor $bytes[$k+2]
                            if ($ref -gt 0 -and $ref -lt $cpCount -and $methodName[$ref]) {
                                $mName = $methodName[$ref]
                                [void]$invokedSet.Add($mName)
                                if ($mName -eq 'sleep') { $info.HasThreadSleep = $true }
                                if (-not $info.MethodInvokes.ContainsKey($mName)) { $info.MethodInvokes[$mName] = 0 }
                                $info.MethodInvokes[$mName]++
                            }
                        } elseif ($op -eq 0xB3 -or $op -eq 0xB5) { $ref = ($bytes[$k+1] -shl 8) -bor $bytes[$k+2]; if ($ref -gt 0 -and $ref -lt $cpCount -and $fieldNameArr[$ref]) { [void]$fieldWriteSet.Add($fieldNameArr[$ref]) } }
                        elseif ($op -eq 0xB2 -or $op -eq 0xB4) { $ref = ($bytes[$k+1] -shl 8) -bor $bytes[$k+2]; if ($ref -gt 0 -and $ref -lt $cpCount -and $fieldNameArr[$ref]) { [void]$fieldReadSet.Add($fieldNameArr[$ref]) } }
                        elseif ($op -eq 0x12) { $idx = [int]$bytes[$k+1]; if ($idx -gt 0 -and $idx -lt $cpCount -and $cpDbl[$idx] -ne 0) { [void]$constSet.Add($cpDbl[$idx]) }; $k++ }
                        elseif ($op -eq 0x13 -or $op -eq 0x14) { $idx = ($bytes[$k+1] -shl 8) -bor $bytes[$k+2]; if ($idx -gt 0 -and $idx -lt $cpCount -and $cpDbl[$idx] -ne 0) { [void]$constSet.Add($cpDbl[$idx]) }; $k += 2 }
                        elseif ($op -eq 0x82) { $mXor = $true }
                        elseif ($op -eq 0xBB) { $ref = ($bytes[$k+1] -shl 8) -bor $bytes[$k+2]; if ($ref -gt 0 -and $ref -lt $cpCount -and $className[$ref] -eq "java/lang/String") { $mNewStr = $true } }
                    }
                    if ($mXor) { $info.HasXor = $true }
                    if ($mNewStr) { $info.HasNewString = $true }
                    if ($mXor -and $mNewStr) { $info.HasXorDecrypt = $true }
                    $p = $cEnd
                }
                $p = $aEnd
            }
        }
        $info.InvokedMethods = @($invokedSet)
        $info.FieldWrites = @($fieldWriteSet)
        $info.FieldReads = @($fieldReadSet)
        $info.FloatConstants = @($constSet)
        $info.LongConstants = @($longSet)
        $info.Utf8Strings = @($stringSet)
        foreach ($fr in $fieldReadSet) { $frl = $fr.ToLowerInvariant(); if ($frl -match '^(yaw|pitch|prevyaw|prevpitch|lastyaw|lastpitch|field_5965|field_5964|f_19858_|f_19857_)$') { $info.HasYawRead = $true; break } }
        foreach ($fw in $fieldWriteSet) { $fwl = $fw.ToLowerInvariant(); if ($fwl -match '^(yaw|pitch|prevyaw|prevpitch|lastyaw|lastpitch|field_5965|field_5964|f_19858_|f_19857_)$') { $info.HasYawWrite = $true; break } }
        foreach ($m in $invokedSet) {
            if ($entityListNames -contains $m) { $info.HasEntityListQuery = $true }
            if (@('attackEntity','doAttack','attack','tryAttack','hitEntity','doHit') -contains $m) { $info.HasAttackCall = $true }
            if ($m -eq 'attackEntity' -or $m -eq 'doAttack') { $info.HasLocalAttack = $true }
        }
    } catch { $info.Error = $_.Exception.Message }
    return $info
}

Write-Host "[ 4 ] BEHAVIORAL BYTECODE" -ForegroundColor Cyan
$behaviorResults = New-Object System.Collections.Generic.List[object]
$bi = 0
foreach ($jar in $jars) {
    $bi++
    $isMetaMod = Test-IsMetaMod -JarName $jar.Name
    $findings = New-Object System.Collections.Generic.List[object]
    $classCount = 0; $classVersions = @{}; $novelClassCount = 0
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($jar.FullName)
        if (-not $isMetaMod) { $nested = @($zip.Entries | Where-Object { $_.FullName -match '^META-INF/jars/.+\.jar$' }); if ($nested.Count -ge 30) { $isMetaMod = $true } }
        foreach ($entry in $zip.Entries) {
            if (-not $entry.FullName.EndsWith(".class")) { continue }
            if ($entry.Length -gt 4MB) { continue }
            $classCount++
            $bytes = $null
            try { $ms = New-Object System.IO.MemoryStream; $s = $entry.Open(); $s.CopyTo($ms); $s.Close(); $bytes = $ms.ToArray(); $ms.Dispose() } catch { continue }
            try {
                $sha = [System.Security.Cryptography.SHA1]::Create().ComputeHash($bytes)
                $shaStr = [BitConverter]::ToString($sha).Replace("-","").ToLower()
                if (-not $legitClassHashes.Contains($shaStr)) { $novelClassCount++ }
            } catch { }
            if ($isMetaMod) { continue }
            $info = Get-ClassInfo -bytes $bytes
            if ($info.Error) { continue }
            if ($info.ClassVersion -gt 0) { if (-not $classVersions.ContainsKey($info.ClassVersion)) { $classVersions[$info.ClassVersion] = 0 }; $classVersions[$info.ClassVersion]++ }

            $isRunnable = $info.Interfaces -contains "java/lang/Runnable"
            $isThread = $info.SuperClass -eq "java/lang/Thread"
            $isLoader = $info.SuperClass -eq "java/lang/ClassLoader" -or $info.SuperClass -eq "java/security/SecureClassLoader"

            $hasAttack=$false;$hasTrig=$false;$hasRandom=$false;$hasSched=$false;$hasSleep=$false
            $hasPacket=$false;$hasTick=$false;$hasKey=$false;$hasReflect=$false;$hasCD=$false
            $hasItemUse=$false;$hasMove=$false;$hasVis=$false
            $hasDefine=$false;$hasReadFully=$false;$hasEmbeddedMap=$false;$hasKeyToggle=$false

            foreach ($m in $info.InvokedMethods) {
                if (-not $hasAttack -and $attackNames -contains $m) { $hasAttack = $true }
                if (-not $hasTrig -and $trigNames -contains $m) { $hasTrig = $true }
                if (-not $hasRandom -and $randomNames -contains $m) { $hasRandom = $true }
                if (-not $hasSched -and $schedNames -contains $m) { $hasSched = $true }
                if (-not $hasSleep -and $sleepNames -contains $m) { $hasSleep = $true }
                if (-not $hasPacket -and $packetNames -contains $m) { $hasPacket = $true }
                if (-not $hasTick -and $tickNames -contains $m) { $hasTick = $true }
                if (-not $hasKey -and $keyNames -contains $m) { $hasKey = $true }
                if (-not $hasReflect -and $reflectNames -contains $m) { $hasReflect = $true }
                if (-not $hasCD -and $cdNames -contains $m) { $hasCD = $true }
                if (-not $hasItemUse -and $itemUseNames -contains $m) { $hasItemUse = $true }
                if (-not $hasMove -and $moveNames -contains $m) { $hasMove = $true }
                if (-not $hasVis -and $visNames -contains $m) { $hasVis = $true }
                if ($m -eq 'defineClass') { $hasDefine = $true }
                if ($m -eq 'readFully' -or $m -eq 'readUTF' -or $m -eq 'readInt') { $hasReadFully = $true }
                if ($m -eq 'getResourceAsStream' -or $m -eq 'ByteArrayInputStream' -or $m -eq 'DataInputStream') { $hasEmbeddedMap = $true }
            }

            $yarnHits = 0; $yarnHitNames = New-Object System.Collections.Generic.List[string]
            foreach ($s in $info.Utf8Strings) {
                if (-not $s) { continue }
                foreach ($yn in $yarnReflectNames) { if ($s -eq $yn) { $yarnHits++; [void]$yarnHitNames.Add($yn); break } }
            }

            $hasIsPressed = $false; $hasSetPressed = $false
            foreach ($m in $info.InvokedMethods) { if ($m -eq 'isPressed' -or $m -eq 'method_1434') { $hasIsPressed = $true }; if ($m -eq 'setPressed' -or $m -eq 'method_23481') { $hasSetPressed = $true } }
            if ($hasIsPressed -and $hasSetPressed -and $hasRandom) { $hasKeyToggle = $true }
            $hasTimerConst = $false
            foreach ($lc in $info.LongConstants) { if ($timerConstants -contains $lc) { $hasTimerConst = $true; break } }
            $hasRotWrite = $false
            foreach ($f in $info.FieldWrites) { if ($rotationFields -contains $f.ToLowerInvariant()) { $hasRotWrite = $true; break } }
            $hasSens = $false
            foreach ($c in $info.FloatConstants) { foreach ($sc in $sensConstants) { if ([Math]::Abs($c - $sc) -lt 0.0005) { $hasSens = $true; break } }; if ($hasSens) { break } }

            $assignedCat = $null
            if     ($info.HasEntityListQuery -and $info.HasAttackCall -and $hasTick) { $assignedCat = "KILLAURA_LOOP" }
            elseif ($info.HasYawRead -and $info.HasYawWrite -and $hasPacket) { $assignedCat = "SILENT_ROTATION_CORRELATION" }
            elseif ($info.HasKnownFamily) { $assignedCat = "KNOWN_CLIENT_FAMILY" }
            elseif ($info.HasNativeInput -and $info.NativeInputHitCount -ge 3) { $assignedCat = "NATIVE_INPUT_INJECTION" }
            elseif ($info.HasRobotClass) { $assignedCat = "ROBOT_CLASS_USAGE" }
            elseif ($info.HasMouseReflection -and $info.MouseReflectHitCount -ge 2 -and $hasReflect) { $assignedCat = "MOUSE_STATE_REFLECTION" }
            elseif ($info.HasGlfwInput -and $hasReflect -and $hasTick) { $assignedCat = "CLICKER_INPUT_SIMULATION" }
            elseif ($info.HasKeyBindingReflection -and $info.KeyBindingReflectHitCount -ge 3 -and $hasTimerConst) { $assignedCat = "CLICKER_INPUT_SIMULATION" }
            elseif ($info.HasWebhook) { $assignedCat = "WEBHOOK_EXFIL" }
            elseif ($info.HasHwid) { $assignedCat = "HWID_FINGERPRINT" }
            elseif ($info.HasSandbox -and ($hasReflect -or $info.HasAntiDebug)) { $assignedCat = "SANDBOX_DETECTION" }
            elseif ($info.HasAccessToken) { $assignedCat = "ACCESS_TOKEN_REF" }
            elseif ($hasReflect -and $yarnHits -ge 3 -and ($hasTick -or $hasKey -or $hasRandom -or $hasKeyToggle)) { $assignedCat = "AUTO_CLICK_KEY_REFLECTION" }
            elseif ($hasKeyToggle -and ($hasTick -or $hasRandom)) { $assignedCat = "KEY_TOGGLE_AUTOMATION" }
            elseif ($hasIsPressed -and $hasSetPressed -and $hasTimerConst) { $assignedCat = "TIMER_KEY_COMBO" }
            elseif ($info.HasXorDecrypt) { $assignedCat = "XOR_STRING_DECRYPTION" }
            elseif ($info.HasImgui) { $assignedCat = "IMGUI_MENU" }
            elseif ($info.MixinOverwrite -and $info.MixinTargetsSensitive) { $assignedCat = "OVERWRITE_SENSITIVE" }
            elseif ($info.IsMixin -and $info.MixinTargetsSensitive) { $assignedCat = "SENSITIVE_MIXIN_TARGET" }
            elseif ($info.HasThreadSleep -and ($hasTick -or $info.IsMixin)) { $assignedCat = "THREAD_SLEEP_IN_TICK" }
            elseif ($info.HasURLClassLoader -and $hasReflect) { $assignedCat = "URLCLASSLOADER" }
            elseif ($info.HasAsm -and $hasReflect) { $assignedCat = "ASM_BYTECODE_MANIPULATION" }
            elseif ($info.HasNetworkEnum) { $assignedCat = "NETWORK_INTERFACE_ENUM" }
            elseif ($info.StaticMutablePrimitives -ge 3 -and $hasReflect -and $hasTimerConst) { $assignedCat = "STATIC_MUTABLE_STATE" }
            elseif ($info.HasUnsafe -and $hasReflect -and $hasTimerConst) { $assignedCat = "UNSAFE_MEMORY" }
            elseif ($info.SyntheticFieldCount -ge 20) { $assignedCat = "SYNTHETIC_FIELD_EXPLOSION" }
            elseif ($isLoader -and $hasDefine -and $hasReflect) { $assignedCat = "CUSTOM_CLASSLOADER" }
            elseif ($hasDefine -and $hasReflect -and $hasReadFully -and $hasEmbeddedMap) { $assignedCat = "PACKED_LOADER" }
            elseif ($hasDefine -and $hasReflect -and $hasReadFully) { $assignedCat = "REFLECTIVE_LOADER" }
            elseif ($hasDefine -and $hasEmbeddedMap) { $assignedCat = "EMBEDDED_PAYLOAD" }
            elseif ($info.HasFreeHost -and ($hasReflect -or $hasPacket)) { $assignedCat = "FREE_HOST_C2" }
            elseif ($info.HasBackdoorPort -and $hasPacket -and $hasReflect) { $assignedCat = "BACKDOOR_PORT" }
            elseif ($info.HasSocketC2 -and $info.HasBackdoorPort) { $assignedCat = "SOCKET_C2" }
            elseif ($info.HasTickRate -and ($hasKey -or $hasItemUse) -and $hasReflect) { $assignedCat = "TICK_RATE_MANIPULATION" }
            elseif ($hasAttack -and $hasTick -and ($hasKey -or $hasRandom -or $hasCD)) { $assignedCat = "ATTACK_TICK_EVENT" }
            elseif ($hasAttack -and $hasKey -and ($hasRandom -or $hasCD -or $hasSched)) { $assignedCat = "ATTACK_KEY_POLL" }
            elseif ($hasAttack -and $hasCD -and ($hasRandom -or $hasTick -or $hasKey)) { $assignedCat = "ATTACK_COOLDOWN_GATED" }
            elseif ($hasAttack -and $hasReflect) { $assignedCat = "ATTACK_REFLECTION" }
            elseif ($hasAttack -and ($isRunnable -or $isThread)) { $assignedCat = "AUTO_ATTACK_THREADED" }
            elseif ($hasAttack -and $hasSched) { $assignedCat = "AUTO_ATTACK_SCHEDULED" }
            elseif ($hasAttack -and $hasSleep) { $assignedCat = "AUTO_ATTACK_SLEEP_LOOP" }
            elseif ($hasAttack -and $hasRandom) { $assignedCat = "AUTO_ATTACK_RANDOMIZED" }
            elseif ($hasRotWrite -and $hasTrig -and ($hasAttack -or $hasPacket -or $hasKey)) { $assignedCat = "SILENT_AIM_TRIG" }
            elseif ($hasRotWrite -and $hasSens -and ($hasAttack -or $hasPacket -or $hasKey -or $hasTick)) { $assignedCat = "AIM_INTERPOLATION" }
            elseif ($hasRotWrite -and ($hasAttack -or $hasPacket)) { $assignedCat = "ROTATION_INJECTION" }
            elseif ($hasSched -and $hasPacket -and $hasItemUse) { $assignedCat = "PACKET_AUTOMATION" }
            elseif ($hasItemUse -and $hasKey -and ($hasRandom -or $hasTick -or $hasSched)) { $assignedCat = "ITEM_USE_AUTOMATION" }
            elseif ($hasMove -and $hasKey -and ($hasTick -or $hasSched)) { $assignedCat = "MOVEMENT_INJECTION" }
            elseif ($hasVis -and $info.IsMixin) { $assignedCat = "RENDER_VISIBILITY_HOOK" }
            elseif ($info.IsMixin -and $hasAttack) { $assignedCat = "MIXIN_COMBAT_HOOK" }

            if ($assignedCat) {
                $ev = ""
                if ($yarnHits -gt 0) { $ev = "yarn: " + (($yarnHitNames | Select-Object -First 6) -join ",") }
                elseif ($info.LongConstants.Count -gt 0) { $hit = $info.LongConstants | Where-Object { $timerConstants -contains $_ } | Select-Object -First 3; if ($hit) { $ev = "timers: " + ($hit -join "ms,") + "ms" } }
                if ($info.WebhookUrls.Count -gt 0) { $wh = $info.WebhookUrls[0]; if ($wh.Length -gt 60) { $wh = $wh.Substring(0,57) + "..." }; $ev = "webhook: $wh" }
                if ($info.ClassVersion -gt 0) { $ev += "  ver=$($info.ClassVersion)" }
                if ($info.StaticMutablePrimitives -gt 0) { $ev += "  staticMut=$($info.StaticMutablePrimitives)" }
                [void]$findings.Add([PSCustomObject]@{ Category = $assignedCat; Class = $info.ThisClass; Evidence = $ev.Trim() })
            }
        }
        $zip.Dispose()
        if (-not $isMetaMod) {
            try {
                $z2 = [System.IO.Compression.ZipFile]::OpenRead($jar.FullName)
                foreach ($e in $z2.Entries) {
                    if ($e.FullName -match '\.(dll|so|dylib)$') {
                        $dllName = [System.IO.Path]::GetFileName($e.FullName)
                        if ($dllName -match '(?i)(click|macro|pulse|autoclick|auto_click|inputsim|triggerlib|pulseclick|kbm)') {
                            [void]$findings.Add([PSCustomObject]@{ Category = "CLICKER_DLL_BUNDLED"; Class = $e.FullName; Evidence = "bundled: $dllName ($([math]::Round($e.Length/1KB,1)) KB)" })
                        }
                    }
                }
                $z2.Dispose()
            } catch { }
        }
        if (-not $isMetaMod -and $classVersions.Keys.Count -gt 1) {
            $sorted = $classVersions.GetEnumerator() | Sort-Object -Property Key -Descending
            $newestVer = $sorted[0].Key; $newestCount = $sorted[0].Value
            if ($newestCount -le 5 -and $sorted.Count -ge 2) {
                $older = $sorted | Where-Object { $_.Key -lt $newestVer } | Sort-Object -Property Value -Descending | Select-Object -First 1
                if ($older -and $older.Value -ge ($newestCount * 4)) {
                    $vstr = ($sorted | ForEach-Object { "v$($_.Key)($($_.Value))" }) -join " "
                    [void]$findings.Add([PSCustomObject]@{ Category = "INJECTED_CLASS_PAYLOAD"; Class = "(jar-wide)"; Evidence = "newest v$newestVer has $newestCount classes vs v$($older.Key)($($older.Value)) | $vstr" })
                }
            }
        }
        $isVerifiedJar = ($verified | Where-Object { $_.Name -eq $jar.Name }).Count -gt 0
        if (-not $isMetaMod -and -not $isVerifiedJar -and $classCount -gt 0) {
            $novelPct = [math]::Round(($novelClassCount / $classCount) * 100)
            if ($novelPct -ge 90 -and $classCount -ge 5) {
                [void]$findings.Add([PSCustomObject]@{ Category = "NOVEL_CLASS_RATIO"; Class = "(jar-wide)"; Evidence = "$novelPct% novel ($novelClassCount / $classCount)" })
            }
        }
    } catch { }
    if ($findings.Count -gt 0) { [void]$behaviorResults.Add([PSCustomObject]@{ Name = $jar.Name; Findings = $findings; Classes = $classCount }) }
}
Write-Host "  behavioral scan complete: $($behaviorResults.Count) flagged"
Write-Host ""

$cheatClientListRaw = @(
"06dWare","198Macros","22qq","3arthh4ck","4E","5C","Achilles","Agalar","AimWhere","AllahWare",
"Ananta","Apollo","Ares","Argon","Arsenic","Artemis","Aspirah","Astera","Asteria","Astralis",
"AstraWare","Atlas","Atomic","Aurora","Backdoored","Balenciaga","Bape","BBCWare","BeefSense",
"BladeCore","BleachHack","Blessed","BloomWare","Boze","Bubby","Cake","Calamity","Calcium",
"Calypso","Candy","CarrotHack","CatLean","Catmi","CatsWare","ChucKHack","Claudius","ClickCrystals",
"Coffee","Cookie","Cosmos","CousinWare","Cr33pyWare","Cranberry","CrossSince","Crystal","Cue",
"CurryMod","Cursa","Curse","Cute","CW Hack","CwHack","CX","Cymer","Dent","DestroySquad","Devu",
"Doki","Doomsday","DotGod.cc","Swift","Dqrkis","DrugHack","Echo","Elysian","Epitaph","Epsilon",
"Europa","Evangelion","Evo","ExosWare","FabricHax","FamilyFunPack","FDP","Glass","LiquidBounce",
"LiquidCat","SkidBounce","FencingF+2","Ferox","Fira","FireWork","FiveGuys","Flawless","Floppa",
"Fog","Forever","ForgeHax","Francium","Freemanatee","FrostBurn","FutureX","Galactie","GameSense",
"Gardenia","Garuff","Gate","GeraldHack","GhostBleach","GishCode","Gladiator","Glow","Grandline",
"GrassWare.win","Grim","GumTune","Gypsyy","Hanabi","HayBale","HemHacks","Realth","HitlerHax",
"HockeyWare","Huzuni","HydraWare+","Hydrogen","Hypnotic","Ikea","IlyVoo","Incoming","Infinity2",
"InfinityLoop","InvincibilityHack","Jackey","Jex","JigokuSense","Jobless","JorgitoHack","Juice",
"KAMI","Zispanos","Kami++","Kami5","Kamiblue","Kana","Kappa","Karma","KettleHack","Kevin","Kiwi",
"Koks","Konas","Korppu","KrLoader","Krypton","Kura","Lambda","Lantern","Lattia","LavaHack","LBounce",
"Leave","Legacy","LeuxBackdoor","LiquidShadow","LiquidX","ListedHack","LiveSense","LmaoBox","Lover",
"Lucky","LumaHack","Lumina","Luminex","Lynx","MacHack","MackMod","Magic","Marlow","McDonald",
"MedusaWare","Medved","MelodySky","Melon","MelonHack+","Mera Private","Meteor","Meteor+","MetteroV2",
"Minced","Mint","Mirai","Misericordia","Mist","Moloch.su","Momentum","Monke","Moonlight","Mousse",
"Myau","Nami","NanoSense","NClient","Neko+","Neptunium","New Virgin","Nexus","Nicotine","NightX",
"NineHack","Noat Wurst+2","Wurst+2","NobleSix","NoobHack","Norules","Notorious","Nova","Novoware",
"NovowareAPI","NoWeakAttack","Noxx","NullPoint","NutGod.CC","Nyrex","Oak","Old Virgin","OmegaHack",
"OyVey Rewrite","Silence","Uop.cc","Zori","Raven B++","OnePop","Onigiri","Onyx","Orchard","Orion",
"Osiris","Osmium","Outrage","OyVey+","Ozark","Past","PastiqueV2","PepsiMod","Phantom","Pika",
"Piston","Platinium","Platinum","Plutora","Pocket","PollosHook","Postman++","Prestige","PubDLC",
"Pugware","Pulse","Quantrum","Quantum","Qubit","Radium","Raion","RavenWeave","Razmorozka",
"Rebirth Alpha","Rebirth Nextgen","reDACTED","Reflection","Remnant","RenoSense","RenoSenseTwo",
"RerHack.club","Resilience","Reznya","Rich","Rocan","RoseGold","Ruby","Ruhama","SafePoint.club",
"SafePoint+2","Satellite","Scrim","Scrims","Selene","Seppuku","SerenityCE","SexHack","ShafferHack",
"ShellSock","SHGR","Shoreline","ShrimpHack","Silk","Skidd.ed","Skilled","Skligga","Skliggahack",
"Slack","Smok","SMPHack","Sn0w","Sol","Sorus","Splash","ST TriggerBot","Stay","Sudo","Sumo",
"Sunshine","Surge","Wing","Sushi","Sydney","Syracuse","System","Tarasande","TeddyWare","Temple",
"Tensor","THSense","ThunderHack","ThunderHack Recode","TipTap","Tokyo","Tomato","Toxic.club",
"TransWare","TriggerLib","Trinity","TrollGod.cc","Trollhack","TurcoHack.cc","Turok","Urmomia",
"UZI","Vape","Vapid","Velaris","Vengeance","Vertex","ConfigLib","VeteranHack","Virgin","Volt","Vox",
"vril","Vrpos","VydraHack","W1seHack","Walksy","Water","Wazo Skid","WingClient","Winter","Wiz",
"Wurst","Wurst+1","Wurst+3","Xdolf","Xenon","Xenophyre","Xiu","Xulu","Xyla","Zelith","Zenith",
"Zeon","ZeroHack","ZeroTwo","Zinc","Zodiac","Zoomies","ZSpaceHack","Zyklon"
)
$cheatClientFull = New-Object System.Collections.Generic.HashSet[string]
$cheatClientBase = New-Object System.Collections.Generic.HashSet[string]
$cheatClientPkg = New-Object System.Collections.Generic.HashSet[string]
$baseNameExclusions = @("fire","ice","echo","sol","system","past","leave","cookie","magic","reflection","water","sumo","stay","shoreline","crystal","piston","bloomware")
foreach ($name in $cheatClientListRaw) {
    $n = $name.Trim()
    if ($n.Length -lt 3) { continue }
    [void]$cheatClientFull.Add("$n Client")
    $lower = $n.ToLowerInvariant()
    if ($baseNameExclusions -notcontains $lower) {
        [void]$cheatClientBase.Add($n)
        $safePkg = $n -replace '[^a-zA-Z0-9]',''
        if ($safePkg.Length -ge 3) { [void]$cheatClientPkg.Add($safePkg.ToLowerInvariant()) }
    }
}
$cheatClientFullRegex = New-Object System.Text.RegularExpressions.Regex((($cheatClientFull | ForEach-Object { [regex]::Escape($_) }) -join '|'), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

function Find-CheatClientNames { param([string]$JarPath, [ref]$FullHits, [ref]$PkgHits, [ref]$ClassHits)
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($JarPath)
        $classPaths = @()
        foreach ($entry in $zip.Entries) {
            if (-not $entry.FullName.EndsWith(".class")) { continue }
            $classPaths += $entry.FullName
            if ($entry.Length -gt 4MB) { continue }
            $bytes = $null
            try { $ms = New-Object System.IO.MemoryStream; $s = $entry.Open(); $s.CopyTo($ms); $s.Close(); $bytes = $ms.ToArray(); $ms.Dispose() } catch { continue }
            foreach ($st in (Get-ClassUtf8 -bytes $bytes)) {
                if (-not $st -or $st.Length -lt 4) { continue }
                if ($cheatClientFullRegex.IsMatch($st)) { foreach ($m in $cheatClientFullRegex.Matches($st)) { [void]$FullHits.Value.Add($m.Value) } }
            }
        }
        $zip.Dispose()
        foreach ($path in $classPaths) {
            $norm = $path -replace '\.class$',''
            $parts = $norm -split '/'
            if ($parts.Count -lt 1) { continue }
            $rootPkg = $parts[0].ToLowerInvariant()
            $className = $parts[-1]
            if ($cheatClientPkg.Contains($rootPkg)) { [void]$PkgHits.Value.Add("$($parts[0])/... (root)"); continue }
            if ($parts.Count -ge 2 -and $cheatClientPkg.Contains($parts[1].ToLowerInvariant()) -and $parts[0] -in @('com','net','org','io','me','dev')) { [void]$PkgHits.Value.Add("$($parts[0])/$($parts[1])/... (pkg)"); continue }
            if ($parts.Count -eq 1 -and $cheatClientBase.Contains($className)) { [void]$ClassHits.Value.Add($className) }
        }
    } catch { }
}

Write-Host "[ 5 ] STRING SCANNER (verified skipped)" -ForegroundColor Cyan
$verifiedNames = @{}
foreach ($v in $verified) { $verifiedNames[$v.Name] = $true }
$skippedVerified = 0
$stringHits = New-Object System.Collections.Generic.List[object]
$textExts = @('.json','.txt','.lang','.properties','.yml','.yaml','.toml','.xml','.mcmeta','.cfg','.conf','.mf')

function Add-Hits { param([string]$Text, [hashtable]$JarHits, [string]$Location)
    if (-not $Text -or $Text.Length -lt 3) { return }
    $matches = $cheatRegex.Matches($Text)
    $fw = Convert-FullwidthToAscii $Text
    if ($fw -ne $Text) { $matches += $cheatRegex.Matches($fw) }
    foreach ($mm in $matches) {
        $k = $mm.Value.ToLower()
        if (-not $JarHits.ContainsKey($k)) { $JarHits[$k] = [PSCustomObject]@{ Term = $mm.Value; Locations = New-Object System.Collections.Generic.List[string] } }
        if ($JarHits[$k].Locations.Count -lt 3) { [void]$JarHits[$k].Locations.Add($Location) }
    }
}

foreach ($jar in $jars) {
    if ($verifiedNames.ContainsKey($jar.Name)) { $skippedVerified++; continue }
    $jarHits = @{}
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($jar.FullName)
        foreach ($entry in $zip.Entries) {
            if ($entry.Length -gt 4MB) { continue }
            $n = $entry.FullName; $nl = $n.ToLowerInvariant()
            if ($nl.EndsWith(".class")) {
                try { $ms = New-Object System.IO.MemoryStream; $s = $entry.Open(); $s.CopyTo($ms); $s.Close(); $bytes = $ms.ToArray(); $ms.Dispose(); foreach ($st in (Get-ClassUtf8 -bytes $bytes)) { Add-Hits -Text $st -JarHits $jarHits -Location $n } } catch { }
                continue
            }
            $text = $null
            foreach ($ext in $textExts) {
                if ($nl.EndsWith($ext)) { try { $s = $entry.Open(); $sr = New-Object System.IO.StreamReader($s, [System.Text.Encoding]::UTF8); $text = $sr.ReadToEnd(); $sr.Close(); $s.Close() } catch { $text = $null }; break }
            }
            if ($text) { Add-Hits -Text $text -JarHits $jarHits -Location $n }
        }
        $zip.Dispose()
    } catch { }
    $ccFull = New-Object System.Collections.Generic.HashSet[string]
    $ccPkg = New-Object System.Collections.Generic.HashSet[string]
    $ccCls = New-Object System.Collections.Generic.HashSet[string]
    Find-CheatClientNames -JarPath $jar.FullName -FullHits ([ref]$ccFull) -PkgHits ([ref]$ccPkg) -ClassHits ([ref]$ccCls)
    if ($ccFull.Count -gt 0 -or $ccPkg.Count -gt 0 -or $ccCls.Count -gt 0) {
        $jarHits["__cheat_client__"] = [PSCustomObject]@{ Term = "KNOWN CHEAT CLIENT"; Locations = New-Object System.Collections.Generic.List[string] }
        foreach ($f in $ccFull) { [void]$jarHits["__cheat_client__"].Locations.Add("full: $f") }
        foreach ($p in $ccPkg) { [void]$jarHits["__cheat_client__"].Locations.Add("pkg:  $p") }
        foreach ($c in $ccCls) { [void]$jarHits["__cheat_client__"].Locations.Add("cls:  $c") }
    }
    if ($jarHits.Count -gt 0) { [void]$stringHits.Add([PSCustomObject]@{ Name = $jar.Name; Hits = $jarHits }) }
}
Write-Host "  $($stringHits.Count) string hits / $skippedVerified verified skipped"
Write-Host ""

Write-Host "[ 6 ] NATIVE / NESTED" -ForegroundColor Cyan
$nativeFindings = New-Object System.Collections.Generic.List[object]
$nestedFindings = New-Object System.Collections.Generic.List[object]
$dangerousImports = @('CreateRemoteThread','VirtualAlloc','VirtualProtect','WriteProcessMemory','ReadProcessMemory','OpenProcess','SetWindowsHookEx','GetAsyncKeyState','URLDownloadToFile','InternetOpen','WinHttpOpen','IsDebuggerPresent','CheckRemoteDebuggerPresent','NtQueryInformationProcess','CryptUnprotectData')
$tempRoot = Join-Path $env:TEMP ("sstools_" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

foreach ($jar in $jars) {
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($jar.FullName)
        $isMetaMod = Test-IsMetaMod -JarName $jar.Name -Zip $zip
        $jarNatives = New-Object System.Collections.Generic.List[object]
        foreach ($entry in $zip.Entries) {
            if ($entry.FullName -match '\.(dll|so|dylib|exe|sys)$') {
                $name = [System.IO.Path]::GetFileName($entry.FullName)
                if ($entry.FullName -match '/natives?/') { continue }
                $tmp = Join-Path $tempRoot ("n_" + [Guid]::NewGuid().ToString('N') + "_" + $name)
                try {
                    $entry.ExtractToFile($tmp, $true)
                    $bytes = [System.IO.File]::ReadAllBytes($tmp)
                    $text = [System.Text.Encoding]::ASCII.GetString($bytes)
                    $imports = @()
                    foreach ($imp in $dangerousImports) { if ($text -match [regex]::Escape($imp)) { $imports += $imp } }
                    [void]$jarNatives.Add([PSCustomObject]@{ Name = $name; Path = $entry.FullName; Size = $entry.Length; Imports = $imports })
                } catch { }
                finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
            }
        }
        if ($jarNatives.Count -gt 0) { [void]$nativeFindings.Add([PSCustomObject]@{ Name = $jar.Name; Payloads = $jarNatives }) }
        if (-not $isMetaMod) {
            $declaredNested = @()
            try {
                $fmj = $zip.GetEntry("fabric.mod.json")
                if ($fmj) { $sr = New-Object System.IO.StreamReader($fmj.Open(), [System.Text.Encoding]::UTF8); $txt = $sr.ReadToEnd(); $sr.Close(); $declaredNested = @([regex]::Matches($txt, '"file"\s*:\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }) }
            } catch { }
            $jarNested = New-Object System.Collections.Generic.List[object]
            $undeclared = New-Object System.Collections.Generic.List[object]
            foreach ($entry in $zip.Entries) {
                if ($entry.FullName -match '\.jar$' -and $entry.FullName -match '^META-INF/jars/') {
                    [void]$jarNested.Add([PSCustomObject]@{ Path = $entry.FullName; Size = $entry.Length })
                    $fn = [System.IO.Path]::GetFileName($entry.FullName)
                    if ($declaredNested.Count -gt 0 -and ($declaredNested -notcontains $entry.FullName) -and ($declaredNested -notcontains $fn)) { [void]$undeclared.Add([PSCustomObject]@{ Path = $entry.FullName; Size = $entry.Length }) }
                }
            }
            $outerClasses = @($zip.Entries | Where-Object { $_.FullName -match '\.class$' -and $_.FullName -notmatch '^META-INF/' })
            if ($undeclared.Count -gt 0) { [void]$nestedFindings.Add([PSCustomObject]@{ Name = $jar.Name; Kind = "Undeclared"; Nested = $undeclared }) }
            elseif ($jarNested.Count -ge 1 -and $outerClasses.Count -lt 5) { [void]$nestedFindings.Add([PSCustomObject]@{ Name = $jar.Name; Kind = "HollowShell"; Nested = $jarNested }) }
        }
        $zip.Dispose()
    } catch { }
}
Write-Host "  $($nativeFindings.Count) native / $($nestedFindings.Count) nested"
Write-Host ""
Remove-Item $tempRoot -Force -Recurse -ErrorAction SilentlyContinue

Write-Host "[ 7 ] EXTERNAL CHEAT DETECTION" -ForegroundColor Cyan
$externalHits = New-Object System.Collections.Generic.List[object]
$legitProcWhitelist = @('EOSOverlayRenderer','NVIDIA Overlay','NVIDIA Share','NvContainer','NVIDIA Web Helper','nvsphelper','Steam','Steamwebhelper','Discord','Overwolf','OBS','obs64','obs32','RivaTuner','MSIAfterburner','Medal','GeForceExperience','GameBar','XboxGameBar','EpicGamesLauncher','EADesktop','Origin','UbisoftConnect','Battle.net','BEService','EasyAntiCheat','EasyAntiCheat_EOS','vgc','vgk','vgtray')
$cheatProcNames = @('autoclicker','clicker','macroman','gsauto','mouseclicker','xmouse','murgee','auto-clicker','autosofted','fastclicker','triggerbot','aimbot','wallhack','cronus','rewasd','antimicro','inputmapper','xpadder','joy2key','kbm2xinput','xoutput','ds4windows','hidhide','interception','autohotkey','ahk','titan','xim','ghostclient','externalcheat','injector','manualmapper','kdmapper','cheatengine','cheatengine-x86_64','cheatengine-i386','ceserver','fateinjector','horioninjector','extremeinjector')
$cheatProcRegex = '(?i)^(' + (($cheatProcNames | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')'

try {
    Get-Process -ErrorAction SilentlyContinue | ForEach-Object {
        $pname = $_.ProcessName
        $isWhitelisted = $false
        foreach ($lw in $legitProcWhitelist) { if ($pname -match "(?i)^$([regex]::Escape($lw))") { $isWhitelisted = $true; break } }
        if ($isWhitelisted) { return }
        if ($pname -match $cheatProcRegex -or $pname -match '(?i)auto.*click|click.*auto|macro.*click|click.*macro') {
            [void]$externalHits.Add([PSCustomObject]@{ Category = "CHEAT_PROCESS_RUNNING"; Target = "$pname.exe (PID $($_.Id))"; Detail = "known external cheat/macro tool running"; Weight = 10 })
        }
    }
} catch { }

try {
    Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle } | ForEach-Object {
        $title = $_.MainWindowTitle
        $isWhitelisted = $false
        foreach ($lw in $legitProcWhitelist) { if ($_.ProcessName -match "(?i)^$([regex]::Escape($lw))") { $isWhitelisted = $true; break } }
        if ($isWhitelisted) { return }
        if ($title -match '(?i)\b(esp|wallhack|aimbot|triggerbot|ghost|injector|cheat|hack|aura)\b') {
            [void]$externalHits.Add([PSCustomObject]@{ Category = "SUSPICIOUS_WINDOW_TITLE"; Target = "$($_.ProcessName) - '$title'"; Detail = "window title matches overlay/cheat pattern"; Weight = 8 })
        }
    }
} catch { }

$inputSoftware = @('LogiOptions','LogiOptionsMgr','LGHUB','lghub_agent','Razer Synapse','RazerCentralService','iCUE','Corsair.Service','SteelSeriesGG','ROCCAT_Swarm','AutoHotkey','AutoHotkeyU64','AutoHotkeyU32','AHK')
try {
    Get-Process -ErrorAction SilentlyContinue | ForEach-Object {
        $pn = $_.ProcessName
        foreach ($sw in $inputSoftware) { if ($pn -match "(?i)^$([regex]::Escape($sw))$") { [void]$externalHits.Add([PSCustomObject]@{ Category = "INPUT_SOFTWARE_RUNNING"; Target = "$pn.exe (PID $($_.Id))"; Detail = "input/macro software running"; Weight = 4 }); break } }
    }
} catch { }

try {
    $startupDirs = @((Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'), (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Startup'))
    foreach ($sd in $startupDirs) {
        if (-not (Test-Path $sd)) { continue }
        Get-ChildItem -Path $sd -File -ErrorAction SilentlyContinue | ForEach-Object {
            $n = $_.Name; $tgt = $null
            if ($n -match '\.lnk$') { try { $sh = New-Object -ComObject WScript.Shell; $tgt = $sh.CreateShortcut($_.FullName).TargetPath; [void][Runtime.InteropServices.Marshal]::ReleaseComObject($sh) } catch { } }
            if ($n -match '(?i)(click|macro|ahk|inject|cheat|hack|ghost|trigger)' -or ($tgt -and $tgt -match '(?i)(click|macro|ahk|inject|cheat|ghost|trigger)' -and $tgt -notmatch '(?i)\\(Windows|Program Files)\\)')) {
                [void]$externalHits.Add([PSCustomObject]@{ Category = "STARTUP_PERSISTENCE"; Target = $_.FullName; Detail = if ($tgt) { "shortcut -> $tgt" } else { "suspicious startup entry" }; Weight = 9 })
            }
        }
    }
} catch { }

try {
    $runKeys = @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run')
    foreach ($rk in $runKeys) {
        if (-not (Test-Path $rk)) { continue }
        $props = Get-ItemProperty -Path $rk -ErrorAction SilentlyContinue
        $props.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
            $v = [string]$_.Value
            if ($v -match '(?i)(click|macro|ahk|auto.*click|inject|cheat|hack|ghost|trigger|aimbot)') { [void]$externalHits.Add([PSCustomObject]@{ Category = "REGISTRY_PERSISTENCE"; Target = "$rk\$($_.Name)"; Detail = $v; Weight = 9 }) }
        }
    }
} catch { }

$legitDriverWhitelist = @('EhStorTcgDrv','storahci','stornvme','storport','disk','partmgr','volmgr','volsnap','pci','acpi','ntfs','fastfat','cng','ksecdd','kspp','clipsp','msrpc','netio','tcpip','ndis','wfplwfs','fltmgr','fileinfo','wdf01000','wdfldr','wudfrd','usbccgp','usbhub','hidusb','hidclass','mouclass','kbdclass','mouhid','kbdhid','dxgkrnl','dxgmms1','dxgmms2','monitor','win32k','win32kbase','win32kfull','ndiswan','rassstp','raspptp','http','afd','npfs','msfs','fs_rec')
$cheatDriverNames = @('kdmapper','dsefix','capcom','iqvw64e','gdrv','rtcore64','updsobj','winio','winring0','winring0x64','inpout','inpoutx64','hwinterface','mhyprot','mhyprot2','zext','shielden','yaboi')
try {
    $drvOut = & driverquery /v /fo csv 2>$null
    if ($drvOut) {
        $drvOut = $drvOut | ConvertFrom-Csv
        foreach ($d in $drvOut) {
            $dn = [string]$d.'Module Name'; $dp = [string]$d.'Display Name'
            $isWhitelisted = $false
            foreach ($lw in $legitDriverWhitelist) { if ($dn -match "(?i)^$([regex]::Escape($lw))$") { $isWhitelisted = $true; break } }
            if ($isWhitelisted) { continue }
            foreach ($bad in $cheatDriverNames) { if ($dn -match "(?i)$([regex]::Escape($bad))" -or $dp -match "(?i)$([regex]::Escape($bad))") { [void]$externalHits.Add([PSCustomObject]@{ Category = "SUSPICIOUS_DRIVER"; Target = $dn; Detail = "driver matching DSE-bypass ($dp)"; Weight = 10 }); break } }
        }
    }
} catch { }

$cheatInstallNames = @('injector','ghostclient','externalcheat','cheatengine','kdmapper','manualmapper','autoclicker','autoclick','triggerbot','aimbot','wallhack','aimware','cronus','xim')
$scanRoots = @($env:APPDATA, $env:LOCALAPPDATA, (Join-Path $env:USERPROFILE 'Downloads'), (Join-Path $env:USERPROFILE 'Documents'))
try {
    foreach ($root in $scanRoots) {
        if (-not (Test-Path $root)) { continue }
        Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $dn = $_.Name
            foreach ($bad in $cheatInstallNames) { if ($dn -match "(?i)^$([regex]::Escape($bad))$") { [void]$externalHits.Add([PSCustomObject]@{ Category = "CHEAT_INSTALL_FOLDER"; Target = $_.FullName; Detail = "folder name matches known cheat tool"; Weight = 9 }); break } }
        }
    }
} catch { }

try {
    $pfDir = Join-Path $env:SystemRoot 'Prefetch'
    if (Test-Path $pfDir) {
        Get-ChildItem -Path $pfDir -Filter '*.pf' -File -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.BaseName -match '(?i)(INJECTOR|AIMBOT|TRIGGERBOT|AUTOCLICK|MACROMAN|KDMAPPER|MANUALMAP|WALLHACK|GHOSTCLIENT|XIM|CRONUS|FATEINJECTOR|HORIONINJECTOR|EXTREME INJECTOR)') {
                [void]$externalHits.Add([PSCustomObject]@{ Category = "PREFETCH_HISTORY"; Target = $_.Name; Detail = ("last run: {0}" -f $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm')); Weight = 7 })
            }
        }
    }
} catch { }

try {
    $pipes = @(Get-ChildItem -Path '\\.\pipe\' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
    foreach ($pipe in $pipes) {
        if ($pipe -match '(?i)(cheat|inject|ghost|aimbot|trigger|macro|kdmapper)') { [void]$externalHits.Add([PSCustomObject]@{ Category = "SUSPICIOUS_NAMED_PIPE"; Target = "\\.\pipe\$pipe"; Detail = "named pipe matches cheat pattern"; Weight = 7 }) }
    }
} catch { }

try {
    $taskOut = & schtasks /query /fo csv /v 2>$null
    if ($taskOut) {
        $taskOut = $taskOut | ConvertFrom-Csv
        foreach ($t in $taskOut) {
            $taskName = [string]$t.'TaskName'; $taskRun = [string]$t.'Task To Run'
            $combined = "$taskName $taskRun"
            if ($combined -match '(?i)(ahk|autohotkey|clicker|macro|inject|cheat|ghost|triggerbot|aimbot)' -and $taskRun -notmatch '(?i)\\(Windows|Program Files|Program Files \(x86\))\\' -and $taskRun -notmatch '(?i)Microsoft') {
                [void]$externalHits.Add([PSCustomObject]@{ Category = "SCHEDULED_TASK_PERSISTENCE"; Target = $taskName; Detail = $taskRun; Weight = 8 })
            }
        }
    }
} catch { }

try {
    Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | ForEach-Object {
        $svcName = $_.Name; $svcPath = $_.PathName
        $isWhitelisted = $false
        foreach ($lw in $legitProcWhitelist) { if ($svcName -match "(?i)$([regex]::Escape($lw))") { $isWhitelisted = $true; break } }
        if ($isWhitelisted) { return }
        $isSuspicious = $false; $reason = ""
        if ($svcPath) { if ($svcPath -match '(?i)\\AppData\\|\\Temp\\|\\Users\\Public\\') { $isSuspicious = $true; $reason = "service binary in user-writable path" } }
        if ($svcName -match '(?i)^(cheat|ghost|inject|trigger|aimbot|macro)') { $isSuspicious = $true; $reason = "service name matches cheat pattern" }
        if ($isSuspicious) { [void]$externalHits.Add([PSCustomObject]@{ Category = "SUSPICIOUS_SERVICE"; Target = $svcName; Detail = $reason; Weight = 8 }) }
    }
} catch { }

if ($mcPid -gt 0) {
    try {
        $inputRunning = @($externalHits | Where-Object { $_.Category -eq 'INPUT_SOFTWARE_RUNNING' })
        if ($inputRunning.Count -ge 2) { [void]$externalHits.Add([PSCustomObject]@{ Category = "CORRELATION_INPUT_MACRO"; Target = "Minecraft + multiple input tools"; Detail = "Minecraft active with $($inputRunning.Count) input/macro tools running"; Weight = 8 }) }
    } catch { }
}

Write-Host "  $($externalHits.Count) external hits"
Write-Host ""

$reportCards = New-Object System.Collections.Generic.List[object]
foreach ($jar in $jars) {
    $score = 0
    $findings = New-Object System.Collections.Generic.List[object]
    $bh = $behaviorResults | Where-Object { $_.Name -eq $jar.Name }
    if ($bh) {
        foreach ($f in $bh.Findings) {
            $entry = $null
            if ($CAT.ContainsKey($f.Category)) { $entry = $CAT[$f.Category] }
            $w = if ($entry) { $entry.W } else { 3 }
            $score += $w
            $lbl = if ($entry) { $entry.L } else { $f.Category }
            [void]$findings.Add([PSCustomObject]@{ Rule = $f.Category; Label = $lbl; Weight = $w; Evidence = $f.Evidence })
        }
    }
    $sh = $stringHits | Where-Object { $_.Name -eq $jar.Name }
    if ($sh -and $sh.Hits.ContainsKey("__cheat_client__")) {
        $score += 9
        foreach ($loc in $sh.Hits["__cheat_client__"].Locations) {
            [void]$findings.Add([PSCustomObject]@{ Rule = "CHEAT_CLIENT_NAME"; Label = "KNOWN CHEAT CLIENT NAME MATCH"; Weight = 9; Evidence = $loc })
        }
    }
    $obf = $obfResults | Where-Object { $_.Name -eq $jar.Name }
    if ($obf) { $score += [math]::Min(10, $obf.Score) }
    $band = "Clean"; $bandColor = "Green"
    if ($score -ge 26) { $band = "Confirmed Cheat Pattern"; $bandColor = "Red" }
    elseif ($score -ge 15) { $band = "High Risk"; $bandColor = "Red" }
    elseif ($score -ge 6) { $band = "Review Recommended"; $bandColor = "Yellow" }
    elseif ($score -ge 1) { $band = "Low Signal"; $bandColor = "DarkYellow" }
    [void]$reportCards.Add([PSCustomObject]@{ File = $jar.Name; Score = $score; Band = $band; BandColor = $bandColor; Findings = $findings })
}

$modScore = ($reportCards | Measure-Object -Property Score -Sum).Sum
$externalScore = 0
foreach ($h in $externalHits) { $externalScore += $h.Weight }
$threatScore = $modScore + $externalScore

$verdict = "Clean"
if     ($threatScore -ge 26 -or $jvmFlags.Count -gt 0 -or $moduleFindings.Count -gt 0 -or $childProcFindings.Count -gt 0 -or $externalScore -ge 15) { $verdict = "CONFIRMED CHEAT PATTERN" }
elseif ($threatScore -ge 15) { $verdict = "HIGH RISK" }
elseif ($threatScore -ge 6)  { $verdict = "REVIEW RECOMMENDED" }
elseif ($threatScore -ge 1)  { $verdict = "LOW SIGNAL" }

$flaggedCards = @($reportCards | Where-Object { $_.Score -gt 0 } | Sort-Object Score -Descending)

Write-Host ("=" * 78) -ForegroundColor DarkGray
Write-Host "FINAL SUMMARY" -ForegroundColor White
Write-Host ("=" * 78) -ForegroundColor DarkGray
Write-Host ("  launcher                : " + $launcher)
Write-Host ("  loader                  : " + $loader)
Write-Host ("  version                 : " + $verDisp)
Write-Host ("  pid / uptime            : " + $(if ($mcPid) { "$mcPid / $uptime" } else { "not running" }))
Write-Host ("  mods folder             : " + $modsDir) -ForegroundColor Cyan
Write-Host ("  archives scanned        : " + $jars.Count)
Write-Host ("  modrinth verified       : " + $verified.Count) -ForegroundColor Green
Write-Host ("  modrinth unknown        : " + $unknown.Count) -ForegroundColor $(if ($unknown.Count -gt 0) { "Red" } else { "Green" })
Write-Host ("  obfuscation flagged     : " + $obfResults.Count)
Write-Host ("  behavioral flagged      : " + $behaviorResults.Count)
Write-Host ("  mod threat score        : " + $modScore)
Write-Host ("  string-scan flagged     : " + $stringHits.Count)
Write-Host ("  native payloads         : " + $nativeFindings.Count)
Write-Host ("  jvm injection flags     : " + $jvmFlags.Count)
Write-Host ("  injected modules        : " + $moduleFindings.Count)
Write-Host ("  suspicious child procs  : " + $childProcFindings.Count)
Write-Host ("  external cheat hits     : " + $externalHits.Count)
Write-Host ("  external threat score   : " + $externalScore)
Write-Host ("  total threat score      : " + $threatScore)
Write-Host ("  elapsed                 : " + [math]::Round($sw.Elapsed.TotalSeconds, 2) + "s") -ForegroundColor DarkGray
Write-Host ("=" * 78) -ForegroundColor DarkGray
Write-Host ""
Write-Host ("  VERDICT: {0}" -f $verdict) -ForegroundColor $(if ($verdict -eq "CONFIRMED CHEAT PATTERN" -or $verdict -eq "HIGH RISK") { "Red" } elseif ($verdict -eq "REVIEW RECOMMENDED" -or $verdict -eq "LOW SIGNAL") { "Yellow" } else { "Green" })
Write-Host ""

function HtmlEnc { param([string]$s)
    if (-not $s) { return "" }
    return $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;')
}

function New-HtmlReport {
    param([string]$OutputPath, [switch]$Open)
    $vc = "clean"; $vIcon = "check"
    if     ($verdict -eq "CONFIRMED CHEAT PATTERN") { $vc = "critical"; $vIcon = "skull" }
    elseif ($verdict -eq "HIGH RISK")               { $vc = "critical"; $vIcon = "alert" }
    elseif ($verdict -eq "REVIEW RECOMMENDED")      { $vc = "warning";  $vIcon = "alert" }
    elseif ($verdict -eq "LOW SIGNAL")              { $vc = "warning";  $vIcon = "info" }
    $maxScore = 60
    $modPct = [math]::Min(100, [math]::Round(($modScore / $maxScore) * 100))
    $extPct = [math]::Min(100, [math]::Round(($externalScore / $maxScore) * 100))
    $totPct = [math]::Min(100, [math]::Round(($threatScore / $maxScore) * 100))
    $totalArchives = $verified.Count + $unknown.Count
    $elapsed = [math]::Round($sw.Elapsed.TotalSeconds, 2)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<!DOCTYPE html><html lang="en" data-theme="dark"><head><meta charset="UTF-8">')
    [void]$sb.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1">')
    [void]$sb.AppendLine('<title>SSTools Mod Analyzer</title>')
    [void]$sb.AppendLine('<style>')
    [void]$sb.AppendLine(@'
:root {
  --emerald: #10b981; --emerald-bright: #34d399; --emerald-glow: rgba(16,185,129,0.35);
  --gold: #f59e0b; --gold-bright: #fbbf24; --gold-glow: rgba(245,158,11,0.35);
  --red: #ef4444; --red-bright: #f87171; --red-glow: rgba(239,68,68,0.35);
  --bg-1: #060a08;
  --glass-bg: rgba(255,255,255,0.04);
  --glass-bg-hover: rgba(255,255,255,0.07);
  --glass-border: rgba(255,255,255,0.09);
  --glass-border-strong: rgba(255,255,255,0.16);
  --text: #e8f0ec; --text-dim: #8fa89b; --text-mute: #5a6b62;
  --shadow: rgba(0,0,0,0.5);
}
[data-theme="light"] {
  --bg-1: #ecfdf5;
  --glass-bg: rgba(255,255,255,0.55);
  --glass-bg-hover: rgba(255,255,255,0.75);
  --glass-border: rgba(16,185,129,0.15);
  --glass-border-strong: rgba(16,185,129,0.3);
  --text: #064e3b; --text-dim: #047857; --text-mute: #6b7280;
  --shadow: rgba(16,185,129,0.08);
}
* { box-sizing: border-box; margin: 0; padding: 0; }
html { scroll-behavior: smooth; }
body {
  font-family: "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif;
  background: var(--bg-1); color: var(--text); line-height: 1.55;
  min-height: 100vh; padding: 32px 20px; overflow-x: hidden;
  -webkit-font-smoothing: antialiased;
  transition: background 0.4s ease, color 0.4s ease;
}
code, .mono { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
.bg-orbs { position: fixed; inset: 0; z-index: -1; overflow: hidden; pointer-events: none; }
.orb { position: absolute; border-radius: 50%; filter: blur(80px); opacity: 0.5; animation: float 20s ease-in-out infinite; }
.orb-1 { width: 500px; height: 500px; background: radial-gradient(circle, var(--emerald) 0%, transparent 70%); top: -200px; left: -150px; }
.orb-2 { width: 400px; height: 400px; background: radial-gradient(circle, var(--gold) 0%, transparent 70%); top: 30%; right: -150px; animation-delay: -5s; }
.orb-3 { width: 350px; height: 350px; background: radial-gradient(circle, #06b6d4 0%, transparent 70%); bottom: -100px; left: 30%; animation-delay: -10s; }
.orb-4 { width: 300px; height: 300px; background: radial-gradient(circle, var(--emerald-bright) 0%, transparent 70%); top: 60%; left: -100px; animation-delay: -15s; }
@keyframes float {
  0%, 100% { transform: translate(0,0) scale(1); }
  33% { transform: translate(60px,-40px) scale(1.1); }
  66% { transform: translate(-40px,60px) scale(0.95); }
}
.container { max-width: 1180px; margin: 0 auto; }
.topbar { display: flex; justify-content: space-between; align-items: center; gap: 16px; margin-bottom: 28px; flex-wrap: wrap; }
.brand { display: flex; align-items: center; gap: 14px; }
.brand-logo {
  width: 48px; height: 48px; border-radius: 14px;
  background: linear-gradient(135deg, var(--emerald) 0%, var(--gold) 100%);
  display: flex; align-items: center; justify-content: center;
  font-weight: 800; color: white; font-size: 18px;
  box-shadow: 0 8px 24px var(--emerald-glow); position: relative;
}
.brand-logo::after {
  content: ""; position: absolute; inset: -4px; border-radius: 18px;
  background: linear-gradient(135deg, var(--emerald), var(--gold));
  opacity: 0.3; filter: blur(12px); z-index: -1;
}
.brand-text h1 {
  font-size: 20px; font-weight: 800; letter-spacing: -0.02em;
  background: linear-gradient(135deg, var(--emerald-bright) 0%, var(--gold-bright) 100%);
  -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text;
}
.brand-text .sub { font-size: 12px; color: var(--text-dim); margin-top: 2px; }
.theme-toggle {
  width: 44px; height: 44px; border-radius: 12px;
  background: var(--glass-bg); border: 1px solid var(--glass-border);
  backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px);
  color: var(--text); cursor: pointer; font-size: 18px;
  display: flex; align-items: center; justify-content: center;
  transition: all 0.2s ease;
}
.theme-toggle:hover { background: var(--glass-bg-hover); border-color: var(--glass-border-strong); transform: scale(1.05); }
.glass {
  background: var(--glass-bg); border: 1px solid var(--glass-border);
  backdrop-filter: blur(24px) saturate(140%); -webkit-backdrop-filter: blur(24px) saturate(140%);
  border-radius: 20px;
  box-shadow: 0 8px 32px var(--shadow), inset 0 1px 0 rgba(255,255,255,0.06);
  position: relative; overflow: hidden;
}
.glass::before {
  content: ""; position: absolute; top: 0; left: 0; right: 0; height: 1px;
  background: linear-gradient(90deg, transparent, rgba(255,255,255,0.3), transparent);
  pointer-events: none;
}
.verdict {
  padding: 32px 36px; margin-bottom: 24px; border-radius: 24px;
  display: flex; align-items: center; gap: 24px; flex-wrap: wrap;
  transition: transform 0.3s ease; transform-style: preserve-3d;
}
.verdict-critical { border-color: rgba(239,68,68,0.4); box-shadow: 0 8px 40px rgba(239,68,68,0.15); }
.verdict-warning  { border-color: rgba(245,158,11,0.4); box-shadow: 0 8px 40px rgba(245,158,11,0.15); }
.verdict-clean    { border-color: rgba(16,185,129,0.4); box-shadow: 0 8px 40px rgba(16,185,129,0.15); }
.verdict-icon {
  width: 80px; height: 80px; border-radius: 20px; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
  font-size: 40px; position: relative;
}
.verdict-critical .verdict-icon { background: linear-gradient(135deg, rgba(239,68,68,0.2), rgba(239,68,68,0.05)); color: var(--red-bright); box-shadow: 0 8px 32px var(--red-glow); }
.verdict-warning  .verdict-icon { background: linear-gradient(135deg, rgba(245,158,11,0.2), rgba(245,158,11,0.05)); color: var(--gold-bright); box-shadow: 0 8px 32px var(--gold-glow); }
.verdict-clean    .verdict-icon { background: linear-gradient(135deg, rgba(16,185,129,0.2), rgba(16,185,129,0.05)); color: var(--emerald-bright); box-shadow: 0 8px 32px var(--emerald-glow); }
.verdict-text { flex: 1; min-width: 240px; }
.verdict-label { font-size: 11px; font-weight: 700; letter-spacing: 0.16em; text-transform: uppercase; color: var(--text-dim); margin-bottom: 8px; }
.verdict-title { font-size: 32px; font-weight: 800; letter-spacing: -0.025em; margin-bottom: 8px; line-height: 1.1; }
.verdict-critical .verdict-title { background: linear-gradient(135deg, #fca5a5, var(--red)); -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text; }
.verdict-warning  .verdict-title { background: linear-gradient(135deg, var(--gold-bright), var(--gold)); -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text; }
.verdict-clean    .verdict-title { background: linear-gradient(135deg, var(--emerald-bright), var(--emerald)); -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text; }
.verdict-desc { font-size: 14px; color: var(--text-dim); }
.scan-meta-pills { display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 24px; }
.meta-pill {
  background: var(--glass-bg); border: 1px solid var(--glass-border);
  backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px);
  padding: 8px 14px; border-radius: 100px; font-size: 12px; color: var(--text-dim);
  display: flex; align-items: center; gap: 6px;
}
.meta-pill b { color: var(--text); font-weight: 600; }
.meta-pill-dot { width: 6px; height: 6px; border-radius: 50%; background: var(--emerald); box-shadow: 0 0 8px var(--emerald-glow); }
.score-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; margin-bottom: 24px; }
@media (max-width: 700px) { .score-grid { grid-template-columns: 1fr; } }
.score-card { padding: 22px 24px; transition: transform 0.3s cubic-bezier(0.34, 1.56, 0.64, 1); transform-style: preserve-3d; }
.score-card:hover { transform: translateY(-4px); }
.score-head { display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 14px; }
.score-label { font-size: 11px; font-weight: 700; letter-spacing: 0.1em; text-transform: uppercase; color: var(--text-dim); }
.score-num { font-size: 32px; font-weight: 800; letter-spacing: -0.03em; font-variant-numeric: tabular-nums; }
.score-num.green  { background: linear-gradient(135deg, var(--emerald-bright), var(--emerald)); -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text; }
.score-num.yellow { background: linear-gradient(135deg, var(--gold-bright), var(--gold)); -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text; }
.score-num.red    { background: linear-gradient(135deg, #fca5a5, var(--red)); -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text; }
.score-bar { height: 8px; background: rgba(0,0,0,0.3); border-radius: 4px; overflow: hidden; position: relative; }
[data-theme="light"] .score-bar { background: rgba(16,185,129,0.1); }
.score-fill { height: 100%; border-radius: 4px; position: relative; transition: width 1.2s cubic-bezier(0.4, 0, 0.2, 1); }
.score-fill::after { content: ""; position: absolute; inset: 0; background: linear-gradient(90deg, transparent 0%, rgba(255,255,255,0.4) 50%, transparent 100%); animation: shimmer 2.5s infinite; }
@keyframes shimmer { 0% { transform: translateX(-100%); } 100% { transform: translateX(100%); } }
.fill-green  { background: linear-gradient(90deg, var(--emerald), var(--emerald-bright)); box-shadow: 0 0 12px var(--emerald-glow); }
.fill-yellow { background: linear-gradient(90deg, var(--gold), var(--gold-bright)); box-shadow: 0 0 12px var(--gold-glow); }
.fill-red    { background: linear-gradient(90deg, var(--red), var(--red-bright)); box-shadow: 0 0 12px var(--red-glow); }
.tiles { display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 14px; margin-bottom: 32px; }
.tile { padding: 18px 20px; text-align: left; transition: transform 0.3s cubic-bezier(0.34, 1.56, 0.64, 1), border-color 0.3s ease; transform-style: preserve-3d; cursor: default; }
.tile:hover { transform: translateY(-3px) scale(1.02); border-color: var(--glass-border-strong); }
.tile-icon {
  width: 36px; height: 36px; border-radius: 10px; margin-bottom: 12px;
  display: flex; align-items: center; justify-content: center;
  font-size: 16px; font-weight: 700;
  background: var(--glass-bg); border: 1px solid var(--glass-border);
}
.tile.green .tile-icon { background: linear-gradient(135deg, rgba(16,185,129,0.2), rgba(16,185,129,0.05)); color: var(--emerald-bright); border-color: rgba(16,185,129,0.3); }
.tile.yellow .tile-icon { background: linear-gradient(135deg, rgba(245,158,11,0.2), rgba(245,158,11,0.05)); color: var(--gold-bright); border-color: rgba(245,158,11,0.3); }
.tile.red .tile-icon { background: linear-gradient(135deg, rgba(239,68,68,0.2), rgba(239,68,68,0.05)); color: var(--red-bright); border-color: rgba(239,68,68,0.3); }
.tile-num { font-size: 28px; font-weight: 800; letter-spacing: -0.03em; font-variant-numeric: tabular-nums; line-height: 1.1; }
.tile.green .tile-num  { color: var(--emerald-bright); }
.tile.yellow .tile-num { color: var(--gold-bright); }
.tile.red .tile-num    { color: var(--red-bright); }
.tile-label { font-size: 11px; color: var(--text-dim); text-transform: uppercase; letter-spacing: 0.08em; margin-top: 4px; font-weight: 600; }
.section-title { font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.16em; color: var(--text-dim); margin: 32px 0 16px 0; display: flex; align-items: center; gap: 12px; }
.section-title::before { content: ""; width: 3px; height: 16px; border-radius: 2px; background: linear-gradient(180deg, var(--emerald), var(--gold)); box-shadow: 0 0 8px var(--emerald-glow); }
.section-title::after { content: ""; flex: 1; height: 1px; background: linear-gradient(90deg, var(--glass-border) 0%, transparent 100%); }
table { width: 100%; border-collapse: collapse; font-size: 13px; }
th, td { padding: 14px 20px; text-align: left; border-bottom: 1px solid var(--glass-border); }
th { color: var(--text-dim); font-weight: 700; font-size: 11px; text-transform: uppercase; letter-spacing: 0.08em; background: rgba(0,0,0,0.15); }
tbody tr:last-child td { border-bottom: none; }
tbody tr { transition: background 0.15s ease; }
tbody tr:hover { background: var(--glass-bg-hover); }
.row-flagged { background: rgba(245,158,11,0.05); }
.row-flagged:hover { background: rgba(245,158,11,0.1); }
.row-flagged td:first-child { position: relative; }
.row-flagged td:first-child::before { content: ""; position: absolute; left: 0; top: 0; bottom: 0; width: 3px; background: linear-gradient(180deg, var(--gold), var(--gold-bright)); box-shadow: 0 0 8px var(--gold-glow); }
.status-pill { display: inline-flex; align-items: center; gap: 5px; padding: 4px 10px; border-radius: 100px; font-size: 10px; font-weight: 700; letter-spacing: 0.08em; text-transform: uppercase; border: 1px solid; }
.status-pill::before { content: ""; width: 5px; height: 5px; border-radius: 50%; }
.status-verified { background: rgba(16,185,129,0.12); color: var(--emerald-bright); border-color: rgba(16,185,129,0.3); }
.status-verified::before { background: var(--emerald); box-shadow: 0 0 6px var(--emerald-glow); }
.status-unknown  { background: rgba(239,68,68,0.12); color: var(--red-bright); border-color: rgba(239,68,68,0.3); }
.status-unknown::before { background: var(--red); box-shadow: 0 0 6px var(--red-glow); }
.status-flagged  { background: rgba(245,158,11,0.12); color: var(--gold-bright); border-color: rgba(245,158,11,0.3); }
.status-flagged::before { background: var(--gold); box-shadow: 0 0 6px var(--gold-glow); }
.score-cell { font-family: ui-monospace, monospace; font-weight: 700; }
details.mod-card { margin-bottom: 12px; border-radius: 20px; overflow: hidden; }
details.mod-card summary { cursor: pointer; padding: 20px 24px; display: flex; align-items: center; gap: 16px; user-select: none; list-style: none; transition: background 0.15s ease; }
details.mod-card summary::-webkit-details-marker { display: none; }
details.mod-card summary:hover { background: var(--glass-bg-hover); }
details.mod-card[open] summary { border-bottom: 1px solid var(--glass-border); }
.sev-dot { width: 12px; height: 12px; border-radius: 50%; flex-shrink: 0; position: relative; }
.sev-dot.red    { background: var(--red); box-shadow: 0 0 0 4px rgba(239,68,68,0.15), 0 0 12px var(--red-glow); }
.sev-dot.yellow { background: var(--gold); box-shadow: 0 0 0 4px rgba(245,158,11,0.15), 0 0 12px var(--gold-glow); }
.sev-dot.green  { background: var(--emerald); box-shadow: 0 0 0 4px rgba(16,185,129,0.15), 0 0 12px var(--emerald-glow); }
.sev-dot::after { content: ""; position: absolute; inset: -4px; border-radius: 50%; background: inherit; opacity: 0.5; animation: pulse 2s ease-in-out infinite; }
@keyframes pulse { 0%, 100% { transform: scale(1); opacity: 0.5; } 50% { transform: scale(1.4); opacity: 0; } }
.mod-info { flex: 1; min-width: 0; }
.mod-name { font-weight: 700; font-size: 14px; word-break: break-all; }
.mod-band { font-size: 12px; color: var(--text-dim); margin-top: 3px; }
.mod-score-badge { font-family: ui-monospace, monospace; font-weight: 700; font-size: 14px; padding: 8px 14px; border-radius: 10px; background: var(--glass-bg); border: 1px solid var(--glass-border); flex-shrink: 0; }
.mod-score-badge.red    { color: var(--red-bright); border-color: rgba(239,68,68,0.3); }
.mod-score-badge.yellow { color: var(--gold-bright); border-color: rgba(245,158,11,0.3); }
.mod-score-badge.green  { color: var(--emerald-bright); border-color: rgba(16,185,129,0.3); }
.mod-body { padding: 8px 24px 20px 24px; }
.finding { padding: 18px 0; border-bottom: 1px solid var(--glass-border); }
.finding:last-child { border-bottom: none; }
.finding-head { display: flex; align-items: center; gap: 10px; margin-bottom: 10px; flex-wrap: wrap; }
.finding-rule { font-weight: 700; font-size: 14px; color: var(--text); }
.finding-weight { font-family: ui-monospace, monospace; font-size: 11px; font-weight: 700; padding: 3px 9px; border-radius: 6px; border: 1px solid; }
.finding-weight.high   { color: var(--red-bright);  background: rgba(239,68,68,0.1);  border-color: rgba(239,68,68,0.3); }
.finding-weight.medium { color: var(--gold-bright); background: rgba(245,158,11,0.1); border-color: rgba(245,158,11,0.3); }
.finding-weight.low    { color: var(--text-dim);    background: var(--glass-bg);      border-color: var(--glass-border); }
.finding-explain { font-size: 13px; color: var(--text-dim); margin-bottom: 12px; padding: 10px 14px; border-radius: 10px; background: rgba(0,0,0,0.2); border-left: 2px solid var(--emerald); }
.finding-evidence { background: rgba(0,0,0,0.35); border: 1px solid var(--glass-border); padding: 12px 16px; border-radius: 10px; font-family: ui-monospace, monospace; font-size: 12px; color: #7dd3fc; word-break: break-all; line-height: 1.55; }
.ext-item { padding: 16px 24px; border-bottom: 1px solid var(--glass-border); display: flex; gap: 16px; align-items: flex-start; transition: background 0.15s ease; }
.ext-item:last-child { border-bottom: none; }
.ext-item:hover { background: var(--glass-bg-hover); }
.ext-body { flex: 1; min-width: 0; }
.ext-cat { font-size: 11px; font-weight: 700; letter-spacing: 0.1em; text-transform: uppercase; color: var(--red-bright); }
.ext-cat.warn { color: var(--gold-bright); }
.ext-target { font-family: ui-monospace, monospace; font-size: 13px; color: var(--text); margin-top: 4px; word-break: break-all; }
.ext-detail { font-size: 12px; color: var(--text-dim); margin-top: 5px; word-break: break-all; }
.ext-weight { font-family: ui-monospace, monospace; font-size: 11px; font-weight: 700; padding: 4px 10px; border-radius: 8px; flex-shrink: 0; border: 1px solid; color: var(--text-dim); background: var(--glass-bg); border-color: var(--glass-border); }
.ext-weight.high { color: var(--red-bright);  background: rgba(239,68,68,0.1);  border-color: rgba(239,68,68,0.3); }
.ext-weight.med  { color: var(--gold-bright); background: rgba(245,158,11,0.1); border-color: rgba(245,158,11,0.3); }
.footer { text-align: center; color: var(--text-mute); font-size: 12px; margin-top: 56px; padding-top: 28px; border-top: 1px solid var(--glass-border); line-height: 1.8; }
.footer b { color: var(--text-dim); font-weight: 600; }
@media (max-width: 640px) {
  body { padding: 20px 12px; }
  .verdict { padding: 22px; }
  .verdict-title { font-size: 24px; }
  .verdict-icon { width: 60px; height: 60px; font-size: 30px; }
  .score-num { font-size: 26px; }
  th, td { padding: 10px 14px; }
}
'@)
    [void]$sb.AppendLine('</style></head><body>')
    [void]$sb.AppendLine('<div class="bg-orbs"><div class="orb orb-1"></div><div class="orb orb-2"></div><div class="orb orb-3"></div><div class="orb orb-4"></div></div>')
    [void]$sb.AppendLine('<div class="container">')
    [void]$sb.AppendLine('<div class="topbar">')
    [void]$sb.AppendLine('<div class="brand"><div class="brand-logo">SS</div><div class="brand-text"><h1>SSTools Mod Analyzer</h1><div class="sub">Scan report</div></div></div>')
    [void]$sb.AppendLine('<button class="theme-toggle" onclick="toggleTheme()" title="Toggle theme"><span id="theme-icon">&#9789;</span></button>')
    [void]$sb.AppendLine('</div>')
    [void]$sb.AppendLine('<div class="scan-meta-pills">')
    [void]$sb.AppendLine(('<div class="meta-pill"><span class="meta-pill-dot"></span><b>{0}</b></div>' -f (HtmlEnc $launcher)))
    [void]$sb.AppendLine(('<div class="meta-pill">MC <b>{0}</b> &middot; <b>{1}</b></div>' -f (HtmlEnc $verDisp), (HtmlEnc $loader)))
    [void]$sb.AppendLine(('<div class="meta-pill">PID <b>{0}</b></div>' -f $mcPid))
    [void]$sb.AppendLine(('<div class="meta-pill">Uptime <b>{0}</b></div>' -f (HtmlEnc $uptime)))
    [void]$sb.AppendLine(('<div class="meta-pill">Scanned <b>{0}</b></div>' -f (HtmlEnc (Get-Date -Format "HH:mm:ss"))))
    [void]$sb.AppendLine('</div>')
    $vIconChar = if ($vIcon -eq "skull") { "&#9760;" } elseif ($vIcon -eq "alert") { "&#9888;" } elseif ($vIcon -eq "check") { "&#10003;" } else { "&#8505;" }
    [void]$sb.AppendLine(('<div class="glass verdict verdict-{0}" data-tilt><div class="verdict-icon">{1}</div>' -f $vc, $vIconChar))
    [void]$sb.AppendLine('<div class="verdict-text">')
    [void]$sb.AppendLine('<div class="verdict-label">Analysis verdict</div>')
    [void]$sb.AppendLine(('<div class="verdict-title">{0}</div>' -f (HtmlEnc $verdict)))
    $vDesc = switch ($vc) {
        "critical" { "Multiple high-confidence indicators of cheat activity were found. Review findings below." }
        "warning"  { "Low-signal indicators found. Likely benign but worth reviewing." }
        default    { "No significant threat indicators detected in this instance." }
    }
    [void]$sb.AppendLine(('<div class="verdict-desc">{0}</div>' -f $vDesc))
    [void]$sb.AppendLine('</div></div>')
    $modFill = if ($modScore -ge 15) { "fill-red" } elseif ($modScore -ge 6) { "fill-yellow" } else { "fill-green" }
    $extFill = if ($externalScore -ge 15) { "fill-red" } elseif ($externalScore -ge 6) { "fill-yellow" } else { "fill-green" }
    $totFill = if ($threatScore -ge 26) { "fill-red" } elseif ($threatScore -ge 6) { "fill-yellow" } else { "fill-green" }
    $modNumClass = if ($modScore -ge 15) { "red" } elseif ($modScore -ge 6) { "yellow" } else { "green" }
    $extNumClass = if ($externalScore -ge 15) { "red" } elseif ($externalScore -ge 6) { "yellow" } else { "green" }
    $totNumClass = if ($threatScore -ge 26) { "red" } elseif ($threatScore -ge 6) { "yellow" } else { "green" }
    [void]$sb.AppendLine('<div class="score-grid">')
    [void]$sb.AppendLine(('<div class="glass score-card" data-tilt><div class="score-head"><span class="score-label">Mod threat</span><span class="score-num {0}" data-count="{1}">0</span></div><div class="score-bar"><div class="score-fill {2}" style="width:0%" data-width="{3}"></div></div></div>' -f $modNumClass, $modScore, $modFill, $modPct))
    [void]$sb.AppendLine(('<div class="glass score-card" data-tilt><div class="score-head"><span class="score-label">External threat</span><span class="score-num {0}" data-count="{1}">0</span></div><div class="score-bar"><div class="score-fill {2}" style="width:0%" data-width="{3}"></div></div></div>' -f $extNumClass, $externalScore, $extFill, $extPct))
    [void]$sb.AppendLine(('<div class="glass score-card" data-tilt><div class="score-head"><span class="score-label">Total threat</span><span class="score-num {0}" data-count="{1}">0</span></div><div class="score-bar"><div class="score-fill {2}" style="width:0%" data-width="{3}"></div></div></div>' -f $totNumClass, $threatScore, $totFill, $totPct))
    [void]$sb.AppendLine('</div>')
    $uFlagClass = if ($unknown.Count -gt 0) { "red" } else { "green" }
    $mFlagClass = if ($modScore -ge 15) { "red" } elseif ($modScore -ge 6) { "yellow" } else { "green" }
    $eFlagClass = if ($externalScore -ge 15) { "red" } elseif ($externalScore -ge 6) { "yellow" } else { "green" }
    $jFlagClass = if ($jvmFlags.Count -gt 0) { "red" } else { "green" }
    $dFlagClass = if ($moduleFindings.Count -gt 0) { "red" } else { "green" }
    [void]$sb.AppendLine('<div class="tiles">')
    [void]$sb.AppendLine(('<div class="glass tile green" data-tilt><div class="tile-icon">&#10003;</div><div class="tile-num" data-count="{0}">0</div><div class="tile-label">Verified</div></div>' -f $verified.Count))
    [void]$sb.AppendLine(('<div class="glass tile {0}" data-tilt><div class="tile-icon">?</div><div class="tile-num" data-count="{1}">0</div><div class="tile-label">Unknown</div></div>' -f $uFlagClass, $unknown.Count))
    [void]$sb.AppendLine(('<div class="glass tile {0}" data-tilt><div class="tile-icon">&#9760;</div><div class="tile-num" data-count="{1}">0</div><div class="tile-label">Mod threats</div></div>' -f $mFlagClass, $modScore))
    [void]$sb.AppendLine(('<div class="glass tile {0}" data-tilt><div class="tile-icon">&#9888;</div><div class="tile-num" data-count="{1}">0</div><div class="tile-label">External hits</div></div>' -f $eFlagClass, $externalHits.Count))
    [void]$sb.AppendLine(('<div class="glass tile {0}" data-tilt><div class="tile-icon">JVM</div><div class="tile-num" data-count="{1}">0</div><div class="tile-label">JVM flags</div></div>' -f $jFlagClass, $jvmFlags.Count))
    [void]$sb.AppendLine(('<div class="glass tile {0}" data-tilt><div class="tile-icon">DLL</div><div class="tile-num" data-count="{1}">0</div><div class="tile-label">Injected modules</div></div>' -f $dFlagClass, $moduleFindings.Count))
    [void]$sb.AppendLine('</div>')
    [void]$sb.AppendLine('<h2 class="section-title">Mods scanned</h2>')
    [void]$sb.AppendLine('<div class="glass" style="overflow:hidden"><table><thead><tr><th>Status</th><th>File</th><th>Name</th><th>Version</th><th style="text-align:right">Score</th></tr></thead><tbody>')
    $allModRows = @()
    foreach ($v in $verified) {
        $rc = $reportCards | Where-Object { $_.File -eq $v.Name }
        $isFlagged = $rc -and $rc.Score -gt 0
        $allModRows += [PSCustomObject]@{ Status = $(if ($isFlagged) { "FLAGGED" } else { "VERIFIED" }); File = $v.Name; Name = $v.Title; Version = $v.Version; Score = $(if ($rc) { $rc.Score } else { 0 }); Flagged = $isFlagged }
    }
    foreach ($u in $unknown) {
        $rc = $reportCards | Where-Object { $_.File -eq $u.Name }
        $allModRows += [PSCustomObject]@{ Status = "UNKNOWN"; File = $u.Name; Name = "(not on Modrinth)"; Version = ""; Score = $(if ($rc) { $rc.Score } else { 0 }); Flagged = $true }
    }
    foreach ($r in ($allModRows | Sort-Object -Property @{Expression={$_.Flagged};Descending=$true}, File)) {
        $rowClass = if ($r.Flagged) { "row-flagged" } else { "" }
        $statusClass = switch ($r.Status) { "VERIFIED" { "status-verified" } "UNKNOWN" { "status-unknown" } "FLAGGED" { "status-flagged" } default { "" } }
        [void]$sb.AppendLine(('<tr class="{0}"><td><span class="status-pill {1}">{2}</span></td><td class="mono">{3}</td><td>{4}</td><td class="mono">{5}</td><td class="score-cell" style="text-align:right">{6}</td></tr>' -f $rowClass, $statusClass, $r.Status, (HtmlEnc $r.File), (HtmlEnc $r.Name), (HtmlEnc $r.Version), $r.Score))
    }
    [void]$sb.AppendLine('</tbody></table></div>')
    if ($flaggedCards.Count -gt 0) {
        [void]$sb.AppendLine('<h2 class="section-title">Threats detected in mods</h2>')
        foreach ($rc in $flaggedCards) {
            $sev = if ($rc.Score -ge 15) { "red" } elseif ($rc.Score -ge 6) { "yellow" } else { "green" }
            [void]$sb.AppendLine('<details class="glass mod-card" open>')
            [void]$sb.AppendLine(('<summary><div class="sev-dot {0}"></div><div class="mod-info"><div class="mod-name">{1}</div><div class="mod-band">{2}</div></div><div class="mod-score-badge {0}">{3}</div></summary>' -f $sev, (HtmlEnc $rc.File), (HtmlEnc $rc.Band), $rc.Score))
            [void]$sb.AppendLine('<div class="mod-body">')
            foreach ($f in $rc.Findings) {
                $explain = ""
                if ($CAT.ContainsKey($f.Rule)) { $explain = $CAT[$f.Rule].E }
                $wClass = if ($f.Weight -ge 8) { "high" } elseif ($f.Weight -ge 5) { "medium" } else { "low" }
                [void]$sb.AppendLine('<div class="finding">')
                [void]$sb.AppendLine(('<div class="finding-head"><span class="finding-rule">{0}</span><span class="finding-weight {1}">weight {2}</span></div>' -f (HtmlEnc $f.Label), $wClass, $f.Weight))
                if ($explain) { [void]$sb.AppendLine(('<div class="finding-explain">{0}</div>' -f (HtmlEnc $explain))) }
                if ($f.Evidence) { [void]$sb.AppendLine(('<div class="finding-evidence">{0}</div>' -f (HtmlEnc $f.Evidence))) }
                [void]$sb.AppendLine('</div>')
            }
            [void]$sb.AppendLine('</div></details>')
        }
    }
    if ($externalHits.Count -gt 0) {
        [void]$sb.AppendLine('<h2 class="section-title">External cheat detection</h2>')
        [void]$sb.AppendLine('<div class="glass" style="overflow:hidden">')
        foreach ($h in $externalHits) {
            $wClass = if ($h.Weight -ge 8) { "high" } elseif ($h.Weight -ge 5) { "med" } else { "" }
            $dotClass = if ($h.Weight -ge 8) { "red" } elseif ($h.Weight -ge 5) { "yellow" } else { "green" }
            [void]$sb.AppendLine('<div class="ext-item">')
            [void]$sb.AppendLine(('<div class="sev-dot {0}"></div>' -f $dotClass))
            [void]$sb.AppendLine('<div class="ext-body">')
            [void]$sb.AppendLine(('<div class="ext-cat">{0}</div>' -f (HtmlEnc $h.Category)))
            [void]$sb.AppendLine(('<div class="ext-target">{0}</div>' -f (HtmlEnc $h.Target)))
            if ($h.Detail) { [void]$sb.AppendLine(('<div class="ext-detail">{0}</div>' -f (HtmlEnc $h.Detail))) }
            [void]$sb.AppendLine('</div>')
            [void]$sb.AppendLine(('<div class="ext-weight {0}">w={1}</div>' -f $wClass, $h.Weight))
            [void]$sb.AppendLine('</div>')
        }
        [void]$sb.AppendLine('</div>')
    }
    if ($jvmFlags.Count -gt 0) {
        [void]$sb.AppendLine('<h2 class="section-title">JVM injection flags</h2>')
        [void]$sb.AppendLine('<div class="glass" style="overflow:hidden">')
        foreach ($f in $jvmFlags) { [void]$sb.AppendLine('<div class="ext-item"><div class="sev-dot red"></div><div class="ext-body"><div class="ext-target">' + (HtmlEnc $f) + '</div></div></div>') }
        [void]$sb.AppendLine('</div>')
    }
    if ($moduleFindings.Count -gt 0) {
        [void]$sb.AppendLine('<h2 class="section-title">Injected modules</h2>')
        [void]$sb.AppendLine('<div class="glass" style="overflow:hidden">')
        foreach ($m in $moduleFindings) {
            [void]$sb.AppendLine('<div class="ext-item">')
            [void]$sb.AppendLine('<div class="sev-dot red"></div>')
            [void]$sb.AppendLine('<div class="ext-body">')
            [void]$sb.AppendLine(('<div class="ext-target">{0}</div>' -f (HtmlEnc $m.Name)))
            [void]$sb.AppendLine(('<div class="ext-detail">{0}</div>' -f (HtmlEnc $m.Path)))
            foreach ($fl in $m.Flags) { [void]$sb.AppendLine(('<div class="ext-detail">&rarr; {0}</div>' -f (HtmlEnc $fl))) }
            [void]$sb.AppendLine('</div>')
            [void]$sb.AppendLine(('<div class="ext-weight high">{0} KB</div>' -f $m.SizeKB))
            [void]$sb.AppendLine('</div>')
        }
        [void]$sb.AppendLine('</div>')
    }
    if ($childProcFindings.Count -gt 0) {
        [void]$sb.AppendLine('<h2 class="section-title">Suspicious processes</h2>')
        [void]$sb.AppendLine('<div class="glass" style="overflow:hidden">')
        foreach ($p in $childProcFindings) {
            [void]$sb.AppendLine('<div class="ext-item">')
            [void]$sb.AppendLine('<div class="sev-dot red"></div>')
            [void]$sb.AppendLine('<div class="ext-body">')
            [void]$sb.AppendLine(('<div class="ext-target">PID {0} &mdash; {1}</div>' -f $p.Pid, (HtmlEnc $p.Name)))
            if ($p.CommandLine) { [void]$sb.AppendLine(('<div class="ext-detail mono">{0}</div>' -f (HtmlEnc $p.CommandLine))) }
            foreach ($fl in $p.Flags) { [void]$sb.AppendLine(('<div class="ext-detail">&rarr; {0}</div>' -f (HtmlEnc $fl))) }
            [void]$sb.AppendLine('</div></div>')
        }
        [void]$sb.AppendLine('</div>')
    }
    if ($nativeFindings.Count -gt 0) {
        [void]$sb.AppendLine('<h2 class="section-title">Native payloads</h2>')
        foreach ($r in $nativeFindings) {
            [void]$sb.AppendLine('<div class="glass" style="margin-bottom:12px;overflow:hidden">')
            [void]$sb.AppendLine(('<div style="padding:16px 24px;border-bottom:1px solid var(--glass-border);font-weight:600">{0}</div>' -f (HtmlEnc $r.Name)))
            foreach ($p in $r.Payloads) {
                [void]$sb.AppendLine('<div class="ext-item">')
                [void]$sb.AppendLine('<div class="sev-dot red"></div>')
                [void]$sb.AppendLine('<div class="ext-body">')
                [void]$sb.AppendLine(('<div class="ext-target">{0}</div>' -f (HtmlEnc $p.Path)))
                if ($p.Imports.Count -gt 0) { [void]$sb.AppendLine(('<div class="ext-detail" style="color:var(--red-bright)">Dangerous imports: {0}</div>' -f (HtmlEnc ($p.Imports -join ', ')))) }
                [void]$sb.AppendLine('</div>')
                [void]$sb.AppendLine(('<div class="ext-weight high">{0} KB</div>' -f [math]::Round($p.Size / 1KB, 1)))
                [void]$sb.AppendLine('</div>')
            }
            [void]$sb.AppendLine('</div>')
        }
    }
    [void]$sb.AppendLine('<div class="footer">')
    [void]$sb.AppendLine(('Generated by <b>SSTools Mod Analyzer</b> &middot; <b>{0}</b> archives scanned in <b>{1}s</b><br>' -f $totalArchives, $elapsed))
    [void]$sb.AppendLine(('<span class="mono" style="font-size:11px">Report: {0}</span>' -f (HtmlEnc $OutputPath)))
    [void]$sb.AppendLine('</div>')
    [void]$sb.AppendLine('</div>')
    [void]$sb.AppendLine('<script>')
    [void]$sb.AppendLine(@'
function toggleTheme() {
  var html = document.documentElement;
  var current = html.getAttribute('data-theme');
  var next = current === 'dark' ? 'light' : 'dark';
  html.setAttribute('data-theme', next);
  document.getElementById('theme-icon').innerHTML = next === 'dark' ? '&#9789;' : '&#9788;';
}
document.addEventListener('DOMContentLoaded', function() {
  var counters = document.querySelectorAll('[data-count]');
  var observed = new WeakSet();
  var io = new IntersectionObserver(function(entries) {
    entries.forEach(function(entry) {
      if (entry.isIntersecting && !observed.has(entry.target)) {
        observed.add(entry.target);
        animateCount(entry.target);
      }
    });
  }, { threshold: 0.3 });
  counters.forEach(function(el) { io.observe(el); });
  var fills = document.querySelectorAll('[data-width]');
  var fio = new IntersectionObserver(function(entries) {
    entries.forEach(function(entry) {
      if (entry.isIntersecting && !observed.has(entry.target)) {
        observed.add(entry.target);
        var w = entry.target.getAttribute('data-width');
        setTimeout(function() { entry.target.style.width = w + '%'; }, 100);
      }
    });
  }, { threshold: 0.3 });
  fills.forEach(function(el) { fio.observe(el); });
  function animateCount(el) {
    var target = parseInt(el.getAttribute('data-count'), 10) || 0;
    if (target === 0) { el.textContent = '0'; return; }
    var start = performance.now();
    var duration = 900;
    function tick(now) {
      var p = Math.min(1, (now - start) / duration);
      var eased = 1 - Math.pow(1 - p, 3);
      el.textContent = Math.round(target * eased);
      if (p < 1) requestAnimationFrame(tick);
      else el.textContent = target;
    }
    requestAnimationFrame(tick);
  }
  if (window.matchMedia('(hover: hover)').matches) {
    document.querySelectorAll('[data-tilt]').forEach(function(card) {
      card.addEventListener('mousemove', function(e) {
        var rect = card.getBoundingClientRect();
        var cx = rect.left + rect.width / 2;
        var cy = rect.top + rect.height / 2;
        var dx = (e.clientX - cx) / rect.width;
        var dy = (e.clientY - cy) / rect.height;
        card.style.transform = 'perspective(800px) rotateY(' + (dx * 4) + 'deg) rotateX(' + (-dy * 4) + 'deg) translateY(-2px)';
      });
      card.addEventListener('mouseleave', function() { card.style.transform = ''; });
    });
  }
});
'@)
    [void]$sb.AppendLine('</script>')
    [void]$sb.AppendLine('</body></html>')
    $sb.ToString() | Set-Content -Path $OutputPath -Encoding UTF8
    if ($Open) { try { Start-Process $OutputPath } catch { Write-Host "could not auto-open: $($_.Exception.Message)" -ForegroundColor DarkYellow } }
}

$reportDir = if ($env:USERPROFILE) { Join-Path $env:USERPROFILE 'Desktop' } else { $env:TEMP }
if (-not (Test-Path $reportDir)) { $reportDir = $env:TEMP }
$htmlPath = Join-Path $reportDir ("SSTools-report-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".html")
New-HtmlReport -OutputPath $htmlPath -Open
Write-Host ("  report exported to: {0}" -f $htmlPath) -ForegroundColor Cyan
Write-Host ""
