# Deploy Chharizard-LAC profiles to Phoenix XI.
#
# What this does:
#   1. Finds your Phoenix install (asks if auto-detect fails)
#   2. Prompts for your Phoenix character name + player ID
#      (can be different from your Horizon character)
#   3. Copies the profile folder from the repo
#   4. Rewrites all dofile paths to the new folder name
#   5. Bakes M.server = "phoenix" into subjob_features.lua
#   6. Guards against overwriting an existing LAC folder you've been using

param(
    [string]$CharacterName = "",
    [string]$PlayerId = "",
    [string]$PhoenixPath = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$repoRoot    = $PSScriptRoot
$sourceDir   = Join-Path $repoRoot "profiles\CHAR_PID"

if (-not (Test-Path $sourceDir)) {
    Write-Host "ERROR: Source profile folder not found at $sourceDir" -ForegroundColor Red
    Write-Host "Run SETUP.ps1 first, or restore the CHAR_PID folder." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "===========================================" -ForegroundColor Magenta
Write-Host "  Chharizard-LAC -> Phoenix XI deployment"  -ForegroundColor Magenta
Write-Host "===========================================" -ForegroundColor Magenta
Write-Host ""

# ---------------------------------------------------------------------------
# 1. Find Phoenix install
# ---------------------------------------------------------------------------
if (-not $PhoenixPath) {
    $candidates = @(
        "C:\Games\PhoenixXI\addons\luashitacast",                                            # User-stated location
        "C:\Games\PhoenixXI\config\addons\luashitacast",
        "$env:LOCALAPPDATA\Phoenix\PhoenixXI\Game\config\addons\luashitacast",               # Hidden Horizon-style
        "$env:LOCALAPPDATA\PhoenixXI\Game\config\addons\luashitacast",
        "$env:LOCALAPPDATA\Phoenix-XI\Game\config\addons\luashitacast",
        "C:\PhoenixXI\addons\luashitacast",
        "C:\PhoenixXI\config\addons\luashitacast"
    )
    Write-Host "Scanning for Phoenix install..." -ForegroundColor Cyan
    $hits = @()
    foreach ($c in $candidates) {
        if (Test-Path $c) {
            # Count any existing <Name>_<ID> folders so we can prefer a path
            # that already holds characters -- Ashita's standard layout is
            # ...\config\addons\luashitacast, which is where LAC auto-creates
            # the per-char folder; some installs ALSO have an empty
            # ...\addons\luashitacast decoy that gets found first.
            $charCount = (Get-ChildItem $c -Directory -ErrorAction SilentlyContinue |
                          Where-Object { $_.Name -match '^[A-Za-z]+_\d+$' }).Count
            $hits += [pscustomobject]@{ Path = $c; Chars = $charCount }
            Write-Host ("  FOUND: {0}   ({1} character folder(s))" -f $c, $charCount) -ForegroundColor Green
        }
    }
    # Prefer the path with the most character folders (ties → first match).
    if ($hits.Count -gt 0) {
        $best = $hits | Sort-Object -Property Chars -Descending | Select-Object -First 1
        $PhoenixPath = $best.Path
    }
    if (-not $PhoenixPath) {
        Write-Host ""
        Write-Host "Could not find Phoenix LuAshitaCast folder automatically." -ForegroundColor Yellow
        Write-Host "Please enter the full path to Phoenix's luashitacast folder."
        Write-Host "Examples:"
        Write-Host "  C:\Games\PhoenixXI\addons\luashitacast"
        Write-Host "  C:\Users\User\AppData\Local\Phoenix\PhoenixXI\Game\config\addons\luashitacast"
        $PhoenixPath = Read-Host "LuAshitaCast path"
    }
}

if (-not (Test-Path $PhoenixPath)) {
    Write-Host "ERROR: Phoenix LuAshitaCast folder does not exist: $PhoenixPath" -ForegroundColor Red
    Write-Host "Launch Phoenix at least once (and LuAshitaCast as an addon) so the folder is created." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Deploying to: $PhoenixPath" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 2. Phoenix character details
# ---------------------------------------------------------------------------
# LuAshitaCast creates a <CharName>_<PlayerID> folder the first time you log
# in on a character. We scan for those folders and show a pick-list -- you
# don't need to know your player ID.
Write-Host ""
Write-Host "Scanning for Phoenix characters..." -ForegroundColor Cyan
$existing = Get-ChildItem $PhoenixPath -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^([A-Za-z]+)_(\d+)$' } |
            Sort-Object Name

if ($existing.Count -eq 0) {
    Write-Host ""
    Write-Host "No existing character folders found in $PhoenixPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To find your player ID:" -ForegroundColor Cyan
    Write-Host "  1. Launch Phoenix XI and log into the character you want to set up"
    Write-Host "  2. Load LuAshitaCast with:  /addon load luashitacast"
    Write-Host "  3. Log out and come back here -- LAC will have created the folder"
    Write-Host "  4. Re-run this deployment script"
    Write-Host ""
    Write-Host "OR enter the details manually below if you already know the ID." -ForegroundColor Gray
    Write-Host ""
    if (-not $CharacterName) { $CharacterName = Read-Host "Phoenix character name" }
    if (-not $PlayerId)      { $PlayerId      = Read-Host "Phoenix player ID (digits only, length varies by server)" }
} else {
    Write-Host "Found $($existing.Count) character folder(s):" -ForegroundColor Green
    Write-Host ""
    # Sort by most-recently-modified first so the live character shows up on top
    $existing = $existing | Sort-Object -Property LastWriteTime -Descending
    for ($i = 0; $i -lt $existing.Count; $i++) {
        $m    = [regex]::Match($existing[$i].Name, '^([A-Za-z]+)_(\d+)$')
        $when = $existing[$i].LastWriteTime.ToString("yyyy-MM-dd HH:mm")
        $luas = (Get-ChildItem $existing[$i].FullName -Filter "*.lua" -ErrorAction SilentlyContinue).Count
        $tag  = if ($i -eq 0) { "  <-- most recent" } else { "" }
        Write-Host ("  [{0}] {1}  (ID {2})  modified {3}  [{4} .lua files]{5}" -f ($i+1), $m.Groups[1].Value, $m.Groups[2].Value, $when, $luas, $tag)
    }
    Write-Host "  [M] Enter manually (if your character isn't listed)"
    Write-Host ""
    $pick = Read-Host "Choice"
    if ($pick -match '^\d+$') {
        $idx = [int]$pick - 1
        if ($idx -lt 0 -or $idx -ge $existing.Count) {
            Write-Host "ERROR: Invalid choice." -ForegroundColor Red; exit 1
        }
        $m = [regex]::Match($existing[$idx].Name, '^([A-Za-z]+)_(\d+)$')
        $CharacterName = $m.Groups[1].Value
        $PlayerId      = $m.Groups[2].Value
        Write-Host "Selected: $CharacterName (ID $PlayerId)" -ForegroundColor Green
    } elseif ($pick -eq 'm' -or $pick -eq 'M') {
        $CharacterName = Read-Host "Phoenix character name"
        $PlayerId      = Read-Host "Phoenix player ID (digits only, length varies by server)"
    } else {
        Write-Host "ERROR: Invalid choice." -ForegroundColor Red; exit 1
    }
}

if ($CharacterName -notmatch '^[A-Za-z]+$') { Write-Host "ERROR: Character name must be letters only." -ForegroundColor Red; exit 1 }
if ($PlayerId -notmatch '^\d+$')             { Write-Host "ERROR: Player ID must be numeric." -ForegroundColor Red; exit 1 }

$destFolderName = "${CharacterName}_${PlayerId}"
$destPath       = Join-Path $PhoenixPath $destFolderName

# ---------------------------------------------------------------------------
# 3. Overwrite guard
# ---------------------------------------------------------------------------
if (Test-Path $destPath) {
    Write-Host ""
    Write-Host "WARNING: $destPath already exists." -ForegroundColor Yellow
    if (-not $Force) {
        $existingLuas = (Get-ChildItem $destPath -Filter "*.lua" -ErrorAction SilentlyContinue).Count
        Write-Host "  It contains $existingLuas .lua file(s)."
        $confirm = Read-Host "Overwrite? Existing settings.xml will be preserved. [y/N]"
        if ($confirm -ne 'y' -and $confirm -ne 'Y') {
            Write-Host "Aborted." -ForegroundColor Yellow
            exit 0
        }
    }
    # Preserve settings.xml if present (per-toon LAC state)
    $existingSettings = Join-Path $destPath "settings.xml"
    if (Test-Path $existingSettings) {
        $tmpSettings = Join-Path $env:TEMP ("lac_settings_" + [guid]::NewGuid().ToString() + ".xml")
        Copy-Item $existingSettings $tmpSettings
        Write-Host "  settings.xml preserved to $tmpSettings" -ForegroundColor Green
    }
    # Also preserve any user-edited job files by backing up the whole folder
    $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $backup = "${destPath}_backup_$stamp"
    Rename-Item $destPath $backup
    Write-Host "  Previous folder backed up as $backup" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 4. Copy
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Copying profile files..." -ForegroundColor Cyan
Copy-Item -Path $sourceDir -Destination $destPath -Recurse
$copied = (Get-ChildItem $destPath -Filter "*.lua").Count
Write-Host "  $copied .lua files copied."

# Restore settings.xml from temp if we saved one
if ($tmpSettings -and (Test-Path $tmpSettings)) {
    Copy-Item $tmpSettings (Join-Path $destPath "settings.xml") -Force
    Remove-Item $tmpSettings -Force
    Write-Host "  settings.xml restored." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 5. Rewrite paths + server flag
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Rewriting paths + server flag..." -ForegroundColor Cyan
$luaFiles = Get-ChildItem -Path $destPath -Filter "*.lua" -Recurse
$patched = 0
foreach ($f in $luaFiles) {
    $content = Get-Content $f.FullName -Raw
    $updated = $content -replace 'CHAR_PID', $destFolderName
    $updated = $updated -replace 'M\.server = "horizon";', 'M.server = "phoenix";'
    if ($content -ne $updated) {
        [System.IO.File]::WriteAllText($f.FullName, $updated)
        $patched++
    }
}
Write-Host "  $patched files patched." -ForegroundColor Green

Write-Host ""
Write-Host "===========================================" -ForegroundColor Magenta
Write-Host "  Deployment complete!"                      -ForegroundColor Magenta
Write-Host "===========================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "Installed to:   $destPath"
Write-Host "Server profile: phoenix"
Write-Host "Character:      $CharacterName (ID $PlayerId)"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Launch Phoenix XI"
Write-Host "  2. In-game: /addon load luashitacast"
Write-Host "  3. In-game: /lac load <JOB>   (e.g. /lac load WAR)"
Write-Host "  4. Verify server flag:  /lac fwd subdebug"
Write-Host ""
Write-Host "Note: SCH and DNC profiles will warn-on-load (WoTG not yet on Phoenix)." -ForegroundColor Yellow
Write-Host ""
