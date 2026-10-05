# Chharizard-LAC setup script
# Renames the profile folder + rewrites all dofile paths to your character.

param(
    [string]$CharacterName = "",
    [string]$PlayerId = "",
    [ValidateSet("horizon","phoenix","retail","")]
    [string]$Server = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  Chharizard-LAC setup" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

$repoRoot   = $PSScriptRoot
$profileDir = Join-Path $repoRoot "profiles"
$default    = Join-Path $profileDir "CHAR_PID"

if (-not (Test-Path $default)) {
    Write-Host "ERROR: Cannot find $default." -ForegroundColor Red
    Write-Host "Did you already run this script? If so, use -Force to reset first." -ForegroundColor Yellow
    exit 1
}

# Prompt if not passed on cmdline
if (-not $CharacterName) {
    $CharacterName = Read-Host "Your character name (e.g. Chharizard)"
}
if (-not $PlayerId) {
    Write-Host "Your player ID is the number LuAshitaCast uses in its folder name."
    Write-Host "Look in <Ashita>\config\addons\luashitacast\ for a folder like <YourName>_XXXXXX."
    $PlayerId = Read-Host "Your player ID (6 digits)"
}

if ($CharacterName -notmatch '^[A-Za-z]+$') {
    Write-Host "ERROR: Character name must be letters only." -ForegroundColor Red
    exit 1
}
if ($PlayerId -notmatch '^\d+$') {
    Write-Host "ERROR: Player ID must be numeric." -ForegroundColor Red
    exit 1
}

if (-not $Server) {
    Write-Host ""
    Write-Host "Which server are you on?"
    Write-Host "  [1] Horizon XI (ToAU cap)"
    Write-Host "  [2] Phoenix XI (ToAU cap, WoTG pending -- SCH/DNC not yet playable)"
    Write-Host "  [3] Retail / other"
    $s = Read-Host "Choice [1-3]"
    switch ($s) {
        "1" { $Server = "horizon" }
        "2" { $Server = "phoenix" }
        "3" { $Server = "retail"  }
        default {
            Write-Host "ERROR: Invalid choice." -ForegroundColor Red
            exit 1
        }
    }
}
Write-Host "  Server profile: $Server" -ForegroundColor Green

$newFolder = "${CharacterName}_${PlayerId}"
$newPath   = Join-Path $profileDir $newFolder

Write-Host ""
Write-Host "Renaming CHAR_PID -> $newFolder..." -ForegroundColor Cyan

if (Test-Path $newPath) {
    if (-not $Force) {
        Write-Host "ERROR: $newPath already exists. Use -Force to overwrite." -ForegroundColor Red
        exit 1
    }
    Remove-Item $newPath -Recurse -Force
}

Rename-Item -Path $default -NewName $newFolder

# Rewrite every dofile path AND the server default in every .lua under the new folder
Write-Host "Rewriting dofile paths and server profile in .lua files..." -ForegroundColor Cyan
$luaFiles = Get-ChildItem -Path $newPath -Filter "*.lua" -Recurse
foreach ($f in $luaFiles) {
    $content = Get-Content $f.FullName -Raw
    $updated = $content -replace 'CHAR_PID', $newFolder
    # Bake in the chosen server as the default (only affects subjob_features.lua)
    $updated = $updated -replace 'M\.server = "horizon";', ("M.server = `"$Server`";")
    if ($content -ne $updated) {
        [System.IO.File]::WriteAllText($f.FullName, $updated)
        Write-Host "  patched: $($f.Name)"
    }
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Copy $newPath"
Write-Host "     to <Ashita>\config\addons\luashitacast\"
Write-Host "  2. In-game: /addon load luashitacast"
Write-Host "  3. In-game: /lac load <JOB>   (e.g. /lac load RNG)"
Write-Host "  4. In-game: /lac fwd subdebug   (verify subjob library loaded)"
Write-Host ""
