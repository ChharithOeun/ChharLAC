# ============================================================================
# INSTALL-CHHARMATON.ps1
# Clones ArcaneAutomata (jonhouchens, MIT) and rebrands to ChharMaton.
# Installs into the chosen Ashita install's addons folder.
# Keeps the original LICENSE + THIRD_PARTY_NOTICES, adds a FORK_NOTICE.
# ============================================================================

param(
    [string[]]$AshitaRoot = $null,  # one or more Ashita install roots; auto-detect if blank
    [string]  $Repo       = 'https://github.com/jonhouchens/ArcaneAutomata.git'
)

$ErrorActionPreference = 'Stop'

function Find-AshitaRoots {
    $found = @()
    $guesses = @(
        'C:\Games\PhoenixXI',
        'C:\Games\HorizonXI\Game',
        'C:\Games\HorizonXI',
        'C:\Program Files (x86)\Ashita-v4',
        "$env:USERPROFILE\Ashita-v4"
    )
    foreach ($g in $guesses) {
        if (Test-Path (Join-Path $g 'addons')) { $found += $g }
    }
    return $found
}

if (-not $AshitaRoot -or $AshitaRoot.Count -eq 0) {
    $AshitaRoot = Find-AshitaRoots
    if (-not $AshitaRoot -or $AshitaRoot.Count -eq 0) {
        Write-Host "No Ashita installs auto-detected. Re-run with:" -ForegroundColor Yellow
        Write-Host "  .\INSTALL-CHHARMATON.ps1 -AshitaRoot 'C:\path\to\Ashita'" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "Target Ashita installs:" -ForegroundColor Cyan
foreach ($r in $AshitaRoot) { Write-Host "  $r" -ForegroundColor Cyan }

$tempDir = Join-Path $env:TEMP ("chharmaton-stage-" + [guid]::NewGuid().ToString('n').Substring(0,8))

# 1. Clone source ONCE
Write-Host "`nCloning $Repo ..." -ForegroundColor Cyan
git clone --depth 1 $Repo $tempDir
if ($LASTEXITCODE -ne 0) { throw "git clone failed" }

# 3. Rebrand helpers --------------------------------------------------------
function Rebrand-File {
    param([string]$Path)
    $txt = Get-Content $Path -Raw -Encoding UTF8

    # addon.name = 'arcaneautomata'   -> 'chharmaton'
    $txt = $txt -replace "addon\.name\s*=\s*'arcaneautomata'",       "addon.name    = 'chharmaton'"
    $txt = $txt -replace 'addon\.name\s*=\s*"arcaneautomata"',       'addon.name    = "chharmaton"'

    # addon.author
    $txt = $txt -replace "addon\.author\s*=\s*'[^']*'",              "addon.author  = 'Chharizard (fork of jonhouchens/ArcaneAutomata, MIT)'"

    # Primary command: /aa and legacy /po /puporbit /invokation /inv
    $txt = $txt -replace "'/aa'",                                     "'/chharmaton'"
    $txt = $txt -replace '"/aa"',                                     '"/chharmaton"'
    $txt = $txt -replace "'/po'",                                     "'/chm'"
    $txt = $txt -replace "'/puporbit'",                               "'/chmorbit'"
    $txt = $txt -replace "'/invokation'",                             "'/chminv'"
    $txt = $txt -replace "'/inv'",                                    "'/chminv2'"

    # Chat prefix "[ArcaneAutomata]" or "ArcaneAutomata:" in print strings
    $txt = $txt -replace '\[ArcaneAutomata\]',                        '[ChharMaton]'
    $txt = $txt -replace 'ArcaneAutomata:',                           'ChharMaton:'
    $txt = $txt -replace '"ArcaneAutomata"',                          '"ChharMaton"'
    $txt = $txt -replace "'ArcaneAutomata'",                          "'ChharMaton'"

    Set-Content $Path -Value $txt -Encoding UTF8 -NoNewline
}

function Rebrand-Manifest {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    $xml = Get-Content $Path -Raw -Encoding UTF8
    $xml = $xml -replace '<name>arcaneautomata</name>',              '<name>chharmaton</name>'
    $xml = $xml -replace '<name>ArcaneAutomata</name>',              '<name>ChharMaton</name>'
    $xml = $xml -replace '<author>[^<]*</author>',                   '<author>Chharizard (fork of ArcaneAutomata)</author>'
    $xml = $xml -replace '/aa</name>',                               '/chharmaton</name>'
    Set-Content $Path -Value $xml -Encoding UTF8 -NoNewline
}

# 2. Loop over every target install ---------------------------------------
$forkNotice = @"
ChharMaton is a rebranded fork of ArcaneAutomata by jonhouchens,
released under the MIT License. See ArcaneAutomata-LICENSE for the
original license, which continues to apply to all code in this folder.

This fork changes only identifiers (addon name, command names, chat
prefixes) so it can run alongside / in place of the original. All
rendering, burden-model, and packet-parsing logic is unchanged.

Original repo:  https://github.com/jonhouchens/ArcaneAutomata
Fork brand:     Chharizard
"@

foreach ($root in $AshitaRoot) {
    Write-Host ""
    Write-Host "==> Installing to $root" -ForegroundColor Cyan

    $addonsDir = Join-Path $root 'addons'
    $libsDir   = Join-Path $addonsDir 'libs'
    $targetDir = Join-Path $addonsDir 'chharmaton'

    if (Test-Path $targetDir) {
        Write-Host "    Removing existing $targetDir ..."
        Remove-Item $targetDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $targetDir | Out-Null
    New-Item -ItemType Directory -Path $libsDir  -Force | Out-Null

    # Copy + rebrand addon files
    $addonFiles = @('arcaneautomata.lua', 'actionpacket.lua', 'maneuverview.lua')
    foreach ($f in $addonFiles) {
        $src = Join-Path $tempDir $f
        if (-not (Test-Path $src)) { continue }
        $destName = $f -replace 'arcaneautomata', 'chharmaton'
        $dest = Join-Path $targetDir $destName
        Copy-Item $src $dest -Force
        Rebrand-File $dest
        Write-Host "    installed addons/chharmaton/$destName"
    }

    # Copy shared libs (burdenmodel / burdenforecast / pupstats)
    $libFiles = Get-ChildItem (Join-Path $tempDir 'libs') -Filter '*.lua' -ErrorAction SilentlyContinue
    foreach ($lib in $libFiles) {
        if ($lib.Name -like 'test_*') { continue }
        $dest = Join-Path $libsDir $lib.Name
        Copy-Item $lib.FullName $dest -Force
        Write-Host "    installed addons/libs/$($lib.Name)"
    }

    # Attribution files
    foreach ($f in @('LICENSE', 'THIRD_PARTY_NOTICES.md', 'README.md')) {
        $src = Join-Path $tempDir $f
        if (Test-Path $src) {
            Copy-Item $src (Join-Path $targetDir "ArcaneAutomata-$f") -Force
        }
    }
    Set-Content (Join-Path $targetDir 'FORK_NOTICE.md') -Value $forkNotice -Encoding UTF8
}

# 3. Cleanup --------------------------------------------------------------
Remove-Item $tempDir -Recurse -Force
Write-Host ""
Write-Host "Done. Load with: /addon load chharmaton" -ForegroundColor Green
Write-Host "Primary command:  /chharmaton help" -ForegroundColor Green
