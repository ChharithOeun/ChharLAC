# LINT.ps1 -- static checks for ChharLAC profiles.
#
# Catches bug classes we've already been bitten by:
#   1. gFunc.Equip / ForceEquip / InterimEquip called with a {table}
#      (those APIs take two string arguments, not a table).
#      Use gFunc.EquipSet({...}) for a table of slots.
#   2. Instruments in Main slot (should be Range).
#   3. Arrows/Bullets/Bolts in Main or Range slot (should be Ammo).
#   4. Nested mode sub-tables inside sets.Idle / sets.TP
#      (must live in sibling sets.IdleStates / sets.TPModes to avoid
#      "Invalid slot specified: <ModeName>" spam).
#   5. Raw QueueCommand bypassing Core.auto() guardrail (Aurora safety).
#   6. Duplicate keys in pattern={...} tables (Lua silently drops dupes;
#      {thunder=1, fire=1, thunder=1} becomes {thunder=1, fire=1} and only
#      queues two maneuvers instead of three).
#   7. Preset-description drift between PUP.lua `presets.X.desc` and
#      ChharControl's `preset_desc[X]`.
#   8. ChharTarget ph_database entries with pops/hex_range but no `zone =`
#      field (ungated -- one same-named mob in another zone away from a
#      false "may pop <NM>" annotation).
#   9. Repo _template vs deployed character folders (drift detector).
#
# Run from repo root:   .\LINT.ps1
# Exits 0 if clean, 1 if any check fails.

param(
    [string]$LacPath = ""
)
$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot
$templateDir = Join-Path $repoRoot 'profiles\_template'

$lacCandidates = @(
    # config path FIRST -- that's where character profiles actually live.
    # The addons/ path has only LAC's own source code.
    "C:\Games\PhoenixXI\config\addons\luashitacast",
    "C:\Games\PhoenixXI\addons\luashitacast",
    "$env:LOCALAPPDATA\Phoenix\PhoenixXI\Game\config\addons\luashitacast",
    "$env:LOCALAPPDATA\PhoenixXI\Game\config\addons\luashitacast",
    "$env:LOCALAPPDATA\Phoenix-XI\Game\config\addons\luashitacast",
    "C:\PhoenixXI\addons\luashitacast",
    "C:\PhoenixXI\config\addons\luashitacast",
    "$env:APPDATA\Ashita_v4\config\addons\luashitacast",
    "C:\Ashita\config\addons\luashitacast",
    "D:\Ashita\config\addons\luashitacast"
)
if ($LacPath -and (Test-Path $LacPath)) {
    $lacDir = $LacPath
} else {
    $lacDir = $lacCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}

$fail = 0
function Problem($msg) { Write-Host "  FAIL: $msg" -ForegroundColor Red; $script:fail++ }
function OK($msg)      { Write-Host "  ok:   $msg" -ForegroundColor Green }

Write-Host ""
Write-Host "ChharLAC LINT" -ForegroundColor Cyan
Write-Host "=============" -ForegroundColor Cyan
Write-Host ""

# Build scan list: repo + every ACTIVE character folder (exclude backups + stale).
$scanDirs = @($templateDir)
$charDirs = @()
if ($lacDir) {
    Write-Host "LAC install: $lacDir" -ForegroundColor Gray
    $charDirs = Get-ChildItem $lacDir -Directory `
        | Where-Object { $_.Name -match '^[A-Z][a-zA-Z]+_\d+$' -and $_.Name -notmatch 'backup' }
    foreach ($d in $charDirs) {
        Write-Host "  -> will scan $($d.Name)" -ForegroundColor Gray
        $scanDirs += $d.FullName
    }
} else {
    Write-Host "LAC install not auto-detected; scanning repo _template only." -ForegroundColor Yellow
}
Write-Host ""

# -------------------------------------------------------------------------
# [1] gFunc.Equip / ForceEquip / InterimEquip with a table argument
# -------------------------------------------------------------------------
Write-Host "[1] gFunc.{Equip,ForceEquip,InterimEquip} with a table arg" -ForegroundColor Cyan
$h = @()
foreach ($d in $scanDirs) {
    $h += Select-String -Path "$d\*.lua" -Pattern 'gFunc\.(Equip|ForceEquip|InterimEquip)\s*\(\s*\{' -ErrorAction SilentlyContinue
}
if ($h.Count -eq 0) { OK "no table-arg misuse" } else { foreach ($x in $h) { Problem "$($x.Path):$($x.LineNumber)  $($x.Line.Trim())" } }
Write-Host ""

# -------------------------------------------------------------------------
# [2] Instrument in Main= (should be Range=)
# -------------------------------------------------------------------------
Write-Host "[2] Instrument in Main= (should be Range=)" -ForegroundColor Cyan
$h = @()
foreach ($d in $scanDirs) {
    $h += Select-String -Path "$d\*.lua" -Pattern 'Main="[^"]*(Piccolo|Horn|Lyre|Harp|Drum|Fife|Harpsichord|Flute|Clarion|Bells|Pipe)"' -ErrorAction SilentlyContinue
}
if ($h.Count -eq 0) { OK "no instrument in Main" } else { foreach ($x in $h) { Problem "$($x.Path):$($x.LineNumber)  $($x.Line.Trim())" } }
Write-Host ""

# -------------------------------------------------------------------------
# [3] Arrow/Bullet/Bolt in Main= or Range= (should be Ammo=)
# -------------------------------------------------------------------------
Write-Host "[3] Arrow/Bullet/Bolt in Main= or Range= (should be Ammo=)" -ForegroundColor Cyan
$h = @()
foreach ($d in $scanDirs) {
    $h += Select-String -Path "$d\*.lua" -Pattern '(Main|Range)="[^"]*(Arrow|Bullet|Bolt)"' -ErrorAction SilentlyContinue
}
if ($h.Count -eq 0) { OK "no ammo in wrong slot" } else { foreach ($x in $h) { Problem "$($x.Path):$($x.LineNumber)  $($x.Line.Trim())" } }
Write-Host ""

# -------------------------------------------------------------------------
# [4] Nested mode sub-tables inside sets.Idle / sets.TP
# -------------------------------------------------------------------------
Write-Host "[4] sub-tables leaking into sets.Idle / sets.TP" -ForegroundColor Cyan
$h = @()
foreach ($d in $scanDirs) {
    $h += Select-String -Path "$d\*.lua" -Pattern 'sets\.(Idle|TP)\.[A-Z][a-zA-Z0-9]*\s*=\s*\{' -ErrorAction SilentlyContinue
}
if ($h.Count -eq 0) { OK "no nested mode sub-tables in Idle/TP" } else { foreach ($x in $h) { Problem "$($x.Path):$($x.LineNumber)  $($x.Line.Trim())" } }
Write-Host ""

# -------------------------------------------------------------------------
# [5] Raw QueueCommand bypassing Core.auto() guardrail (Aurora safety)
# -------------------------------------------------------------------------
Write-Host "[5] Raw QueueCommand bypasses Core.auto() (Aurora safety)" -ForegroundColor Cyan
$h = @()
foreach ($d in $scanDirs) {
    foreach ($f in Get-ChildItem "$d\*.lua" -ErrorAction SilentlyContinue) {
        if ($f.Name -eq 'subjob_features.lua') { continue }   # legacy auto layer
        if ($f.Name -eq 'lac_core.lua')        { continue }   # the gate itself
        if ($f.Name -eq 'PUP.lua')             { continue }   # addon load/unload mgmt
        # Pre-Core migration debt: these jobs use raw QueueCommand for auto-JA
        # and auto-spells. Known safe on Phoenix/Horizon. Will migrate when
        # each job gets its Core pass. Remove from this list after migration.
        if ($f.Name -eq 'BST.lua')             { continue }
        if ($f.Name -eq 'PLD.lua')             { continue }
        if ($f.Name -eq 'RNG.lua')             { continue }
        if ($f.Name -eq 'SMN.lua')             { continue }
        $h += Select-String -Path $f.FullName -Pattern 'QueueCommand' -ErrorAction SilentlyContinue
    }
}
if ($h.Count -eq 0) { OK "no raw QueueCommand in job files" } else { foreach ($x in $h) { Problem "$($x.Path):$($x.LineNumber)  $($x.Line.Trim())" } }
Write-Host ""

# -------------------------------------------------------------------------
# [6] Duplicate keys in pattern={...} tables (Lua silently drops them)
# -------------------------------------------------------------------------
Write-Host "[6] Duplicate keys in pattern={...} tables" -ForegroundColor Cyan
$dupHits = @()
foreach ($d in $scanDirs) {
    foreach ($f in Get-ChildItem "$d\*.lua" -ErrorAction SilentlyContinue) {
        $lines = Get-Content $f.FullName
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -notmatch 'pattern\s*=\s*\{([^}]*)\}') { continue }
            $inside = $matches[1]
            # Extract keys (lowercase word followed by '=')
            $keys = [regex]::Matches($inside, '([a-z]+)\s*=') | ForEach-Object { $_.Groups[1].Value }
            $dupes = $keys | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name }
            if ($dupes) {
                $dupHits += [pscustomobject]@{ Path = $f.FullName; LineNumber = $i+1; Line = $line.Trim(); Dupes = ($dupes -join ',') }
            }
        }
    }
}
if ($dupHits.Count -eq 0) { OK "no duplicate keys in pattern tables" } else {
    foreach ($x in $dupHits) { Problem "$($x.Path):$($x.LineNumber)  duplicate key(s) [$($x.Dupes)] in: $($x.Line)" }
}
Write-Host ""

# -------------------------------------------------------------------------
# [7] Preset-desc drift between PUP.lua and chharcontrol.lua
# -------------------------------------------------------------------------
Write-Host "[7] Preset desc drift (PUP.lua <-> chharcontrol.lua)" -ForegroundColor Cyan
# ChharControl isn't under LAC; try standard addon paths.
$ccCandidates = @()
if ($lacDir) {
    # Infer addon root by stripping config/addons/luashitacast off the LAC path.
    $root = $lacDir -replace '\\?config\\?addons\\?luashitacast\\?$',''
    $ccCandidates += (Join-Path $root 'addons\chharcontrol\chharcontrol.lua')
    $ccCandidates += (Join-Path $root 'config\addons\chharcontrol\chharcontrol.lua')
}
$ccPath = $ccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

function Parse-PupDescs($pupPath) {
    $out = @{}
    $text = Get-Content $pupPath -Raw
    # Each entry: `  <name> = { ... desc='...' ... },` (multi-line)
    $re = [regex]'(?s)(^|\n)\s+([a-z0-9]+)\s*=\s*\{[^}]*?desc\s*=\s*''([^'']*)'''
    foreach ($m in $re.Matches($text)) {
        $out[$m.Groups[2].Value] = $m.Groups[3].Value
    }
    return $out
}
function Parse-CcDescs($ccPath) {
    $out = @{}
    $text = Get-Content $ccPath -Raw
    # In the preset_desc block: `  <name>  = '...',`
    if ($text -match '(?s)local\s+preset_desc\s*=\s*\{(.*?)\n\}') {
        $block = $matches[1]
        foreach ($m in [regex]::Matches($block, '([a-z0-9]+)\s*=\s*''([^'']*)''')) {
            $out[$m.Groups[1].Value] = $m.Groups[2].Value
        }
    }
    return $out
}

if (-not $ccPath) {
    Write-Host "  skipped (chharcontrol.lua not found)" -ForegroundColor Yellow
} else {
    $driftFound = $false
    foreach ($cd in $charDirs + @([pscustomobject]@{ FullName = $templateDir })) {
        $pupFile = Join-Path $cd.FullName 'PUP.lua'
        if (-not (Test-Path $pupFile)) { continue }
        $pup = Parse-PupDescs $pupFile
        $cc  = Parse-CcDescs  $ccPath
        $all = ($pup.Keys + $cc.Keys) | Sort-Object -Unique
        foreach ($name in $all) {
            $p = $pup[$name]; $c = $cc[$name]
            if ($p -and $c -and ($p -ne $c)) {
                Problem "preset '$name' drift (`n           PUP: $p`n           CC : $c`n           file: $pupFile)"
                $driftFound = $true
            }
        }
    }
    if (-not $driftFound) { OK "PUP.lua descs match chharcontrol.lua preset_desc" }
}
Write-Host ""

# -------------------------------------------------------------------------
# [8] ChharTarget ph_database.lua -- entries with pops/hex_range but no zone
# -------------------------------------------------------------------------
# Any PH entry that has pops or hex_range but is missing a `zone =` field
# is UNGATED: if a mob with the same name exists in a different zone, we'll
# falsely annotate it with "may pop <NM>". The ChharTarget zone-gate code
# can only filter when the entry has a zone set.
Write-Host "[8] ChharTarget ph_database entries missing zone=" -ForegroundColor Cyan
$phDbCandidates = @()
if ($lacDir) {
    $root = $lacDir -replace '\\?config\\?addons\\?luashitacast\\?$',''
    $phDbCandidates += (Join-Path $root 'addons\chhartarget\ph_database.lua')
    $phDbCandidates += (Join-Path $root 'config\addons\chhartarget\ph_database.lua')
}
$phDbPath = $phDbCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $phDbPath) {
    Write-Host "  skipped (ph_database.lua not found)" -ForegroundColor Yellow
} else {
    $lines = Get-Content $phDbPath
    $ungated = @()
    $inEntry = $false
    $entryName = ""
    $entryStartLine = 0
    $entryHasZone = $false
    $entryHasPopsOrRange = $false
    $depth = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        # Entry start: PH['name'] = {  or  PH["name"] = {
        if (-not $inEntry -and $line -match 'PH\s*\[\s*[''"](.+?)[''"]\s*\]\s*=\s*\{') {
            $inEntry = $true
            $entryName = $matches[1]
            $entryStartLine = $i + 1
            $entryHasZone = $false
            $entryHasPopsOrRange = $false
            $depth = 1
            continue
        }
        if ($inEntry) {
            # Rough brace tracking (works for well-formed entries, which these are).
            $opens  = ([regex]::Matches($line, '\{')).Count
            $closes = ([regex]::Matches($line, '\}')).Count
            $depth += $opens - $closes
            if ($line -match '\bzone\s*=')                           { $entryHasZone = $true }
            if ($line -match '\b(pops|hex_range|ph_hex_ids)\s*=\s*\{') { $entryHasPopsOrRange = $true }
            if ($depth -le 0) {
                if ($entryHasPopsOrRange -and -not $entryHasZone) {
                    $ungated += [pscustomobject]@{ Name = $entryName; Line = $entryStartLine }
                }
                $inEntry = $false
            }
        }
    }
    if ($ungated.Count -eq 0) {
        OK "all PH entries with pops/hex_range have zone="
    } else {
        foreach ($u in $ungated) {
            Problem ("ph_database.lua:{0}  entry '{1}' has pops/hex_range but no zone=" -f $u.Line, $u.Name)
        }
    }
}
Write-Host ""

# -------------------------------------------------------------------------
# [9] Repo _template vs deployed character folders (drift)
# -------------------------------------------------------------------------
Write-Host "[9] Repo _template vs deployed character folders (drift)" -ForegroundColor Cyan
if ($lacDir) {
    $driftAny = $false
    foreach ($cd in $charDirs) {
        foreach ($repoFile in Get-ChildItem $templateDir -Filter *.lua) {
            $deployed = Join-Path $cd.FullName $repoFile.Name
            if (-not (Test-Path $deployed)) { continue }
            $rh = (Get-FileHash $repoFile.FullName -Algorithm MD5).Hash
            $dh = (Get-FileHash $deployed         -Algorithm MD5).Hash
            if ($rh -ne $dh) {
                Problem "$($cd.Name)/$($repoFile.Name) differs from repo _template"
                $driftAny = $true
            }
        }
    }
    if (-not $driftAny) { OK "all deployed files match repo" }
} else {
    Write-Host "  skipped (no LAC install detected)" -ForegroundColor Yellow
}
Write-Host ""

# -------------------------------------------------------------------------
Write-Host "==== Summary ====" -ForegroundColor Cyan
if ($fail -eq 0) {
    Write-Host "All checks passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "$fail issue(s) found." -ForegroundColor Red
    exit 1
}
