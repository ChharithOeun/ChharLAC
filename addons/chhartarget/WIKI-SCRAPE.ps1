# BG-WIKI-SCRAPE.ps1
#
# Fetches BG-Wiki pages for a list of NM names, parses the "General Notes"
# and infobox for the Placeholder mob name, then appends new entries to
# ph_database.lua.  Existing entries are preserved (no overwrites).
#
# Usage:
#   # Scrape a specific list of NMs
#   .\BG-WIKI-SCRAPE.ps1 -NMs 'Argus','Mee Deggi the Punisher','Peko Peko'
#
#   # Scrape from a text file (one NM name per line)
#   .\BG-WIKI-SCRAPE.ps1 -ListFile .\my-nm-list.txt
#
#   # Scrape every NM in a BG-Wiki zone category page (one HTTP call, 50+ NMs)
#   .\BG-WIKI-SCRAPE.ps1 -ZoneCategory 'Giddeus'
#
# Appends to ph_database.lua next to this script.  Review the output before
# reloading the addon in-game.

[CmdletBinding(DefaultParameterSetName='All')]
param(
    # DEFAULT MODE: no arguments = mega-scrape (walks BG-Wiki's full NM list).
    # Just double-click MEGA-SCRAPE.bat or run `.\WIKI-SCRAPE.ps1` on its own.
    [Parameter(ParameterSetName='All')]
    [switch]$All,

    [Parameter(ParameterSetName='Names', Mandatory=$true)]
    [string[]]$NMs,

    [Parameter(ParameterSetName='File', Mandatory=$true)]
    [string]$ListFile,

    [Parameter(ParameterSetName='Zone', Mandatory=$true)]
    [string]$ZoneCategory,

    # Rate-limit delay between requests.  Bumped to 2000ms (2s) because
    # BG-Wiki throttles aggressive scrapers with HTTP 429.
    [int]$DelayMs = 2000,
    [string]$DbPath = ''
)

# Force TLS 1.2+ (default PowerShell 5.1 uses SSL3/TLS1.0 which modern sites
# reject with "Could not create SSL/TLS secure channel").  Enable every
# modern protocol the current .NET build knows about.
try {
    $proto = [Net.SecurityProtocolType]::SystemDefault
    foreach ($name in @('Tls13','Tls12','Tls11')) {
        try { $proto = $proto -bor ([Net.SecurityProtocolType]::$name) } catch {}
    }
    [Net.ServicePointManager]::SecurityProtocol = $proto
    # Also disable certificate validation issues from BG-Wiki's cert chain
    # on older Windows installs (expired-root issue happens on fresh Win10).
    [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
} catch {
    Write-Host "WARNING: could not set TLS 1.2+ -- scraping may fail." -ForegroundColor Yellow
}
$script:UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
             '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 ChharTarget/1.0'

# Preferred: read from local wiki mirrors (T:\WikiMirrors) if they exist.
# This bypasses rate limits + TLS issues + "site is down today" entirely.
# Falls back to live fetch only when the mirror doesn't have the page.
$script:MirrorRoots = @(
    'T:\WikiMirrors',
    'C:\WikiMirrors',
    (Join-Path $env:USERPROFILE 'WikiMirrors')
)
function Resolve-Mirror {
    param([string]$Url)
    # Map a wiki URL to a candidate local file path.  Example:
    #   https://www.bg-wiki.com/ffxi/Rock_Lizard
    #     -> <mirror>\BGWiki\www.bg-wiki.com\ffxi\Rock_Lizard.html (or /index.html)
    try {
        $uri   = [Uri]$Url
        $host2 = $uri.Host
        $path  = $uri.AbsolutePath.TrimStart('/')
        if (-not $path) { $path = 'index' }
        # Try several file-naming schemes wget might have used
        $cands = @()
        foreach ($root in $script:MirrorRoots) {
            foreach ($folder in @('BGWiki','FFXIclopedia','PhoenixXI','HorizonXI',
                                  'CatsEyeXI','NocturnalSouls','EdenXI',
                                  'FFXIAH','ClassicFFXIc')) {
                $base = Join-Path (Join-Path $root $folder) $host2
                $cands += (Join-Path $base ($path + '.html'))
                $cands += (Join-Path $base ($path -replace '/','\') + '.html')
                $cands += (Join-Path $base (Join-Path $path 'index.html'))
                $cands += (Join-Path $base $path)
            }
        }
        foreach ($c in $cands) {
            if (Test-Path -LiteralPath $c -PathType Leaf) { return $c }
        }
    } catch {}
    return $null
}

function Get-WebContent {
    param([string]$Url, [int]$MaxAttempts = 4)
    # 1) Try local mirror first
    $mirror = Resolve-Mirror $Url
    if ($mirror) {
        try { return Get-Content -LiteralPath $mirror -Raw -ErrorAction Stop } catch {}
    }
    # Retry on HTTP 429 (too many requests) with exponential back-off.
    # Each attempt doubles the delay: 5s, 10s, 20s, 40s.
    $backoffSec = 5
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            return (Invoke-WebRequest -Uri $Url -UseBasicParsing `
                                      -UserAgent $script:UA -ErrorAction Stop).Content
        } catch {
            $msg = $_.Exception.Message
            if ($msg -match '429' -or $msg -match 'Too Many Requests') {
                if ($attempt -lt $MaxAttempts) {
                    Write-Host "    [429] rate-limited; waiting ${backoffSec}s before retry $($attempt+1)/$MaxAttempts..." -ForegroundColor Yellow
                    Start-Sleep -Seconds $backoffSec
                    $backoffSec *= 2
                    continue
                }
            }
            # Non-429 or exhausted retries -- try WebClient as last resort
            try {
                $wc = New-Object System.Net.WebClient
                $wc.Headers.Add('User-Agent', $script:UA)
                return $wc.DownloadString($Url)
            } catch {
                throw "Fetch failed for $Url -- $($_.Exception.Message)"
            }
        }
    }
}

# Resolve script directory even when $PSScriptRoot is empty (older PS, some
# invocation contexts).  Fall back to the current working directory.
if (-not $DbPath -or $DbPath -eq '') {
    $scriptDir = $PSScriptRoot
    if (-not $scriptDir -or $scriptDir -eq '') {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path -ErrorAction SilentlyContinue
    }
    if (-not $scriptDir -or $scriptDir -eq '') { $scriptDir = (Get-Location).Path }
    $DbPath = Join-Path $scriptDir 'ph_database.lua'
}

$ErrorActionPreference = 'Continue'
# Verbose at start so you see activity immediately
Write-Host "WIKI-SCRAPE starting (ParameterSet: $($PSCmdlet.ParameterSetName))" -ForegroundColor Cyan

# ----------------------------------------------------------------------------
# Resolve the input list
# ----------------------------------------------------------------------------
switch ($PSCmdlet.ParameterSetName) {
    'Names' {
        $nmList = $NMs
    }
    'File' {
        if (-not (Test-Path $ListFile)) { throw "List file not found: $ListFile" }
        $nmList = Get-Content $ListFile | Where-Object { $_ -and $_ -notmatch '^\s*#' }
    }
    'Zone' {
        Write-Host "Fetching zone-category page for $ZoneCategory ..." -ForegroundColor Cyan
        $zoneUrl = 'https://www.bg-wiki.com/ffxi/Category:' + ($ZoneCategory -replace ' ', '_')
        try {
            $zoneHtml = @{ Content = (Get-WebContent $zoneUrl) }
        } catch {
            Write-Host "  Failed: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
        $nmList = @()
        $linkMatches = [regex]::Matches($zoneHtml.Content, '/ffxi/([A-Za-z0-9_%\-\.''!]+?)"[^>]*title="([^"]+)"')
        foreach ($m in $linkMatches) {
            $title = $m.Groups[2].Value
            if ($title -and $title -notmatch '^(Category|File|Template|Help):') {
                $nmList += $title
            }
        }
        $nmList = $nmList | Select-Object -Unique
        Write-Host "  Found $($nmList.Count) candidate pages." -ForegroundColor DarkGray
    }
    'All' {
        Write-Host 'MEGA-SCRAPE: walking BG-Wiki Category:Notorious_Monsters...' -ForegroundColor Cyan
        Write-Host '  Fetching first page -- give it 10-30 seconds...' -ForegroundColor DarkGray
        $nmList = @()
        $pageUrl = 'https://www.bg-wiki.com/ffxi/Category:Notorious_Monsters'
        $pagesSeen = 0
        while ($pageUrl) {
            $pagesSeen++
            Write-Host ("  page $pagesSeen -> $pageUrl") -ForegroundColor DarkGray
            try {
                $catHtml = Get-WebContent $pageUrl
            } catch {
                Write-Host "  Failed to fetch $pageUrl -- $($_.Exception.Message)" -ForegroundColor Red
                break
            }
            Write-Host ("    fetched $($catHtml.Length) bytes, parsing links...") -ForegroundColor DarkGray
            $linkMatches = [regex]::Matches($catHtml,
                '/ffxi/([^"]+?)"[^>]*title="([^"]+)"')
            Write-Host ("    found $($linkMatches.Count) raw links on this page") -ForegroundColor DarkGray
            $kept = 0
            foreach ($m in $linkMatches) {
                $title = [System.Net.WebUtility]::HtmlDecode($m.Groups[2].Value)
                if ($title -and $title -notmatch '^(Category|File|Template|Help|Special|User|Talk):' `
                             -and $title -notmatch '^Notorious Monster' `
                             -and $title -notmatch '^(Crafting|Dynamis|Guides|JSE|Monthly|Odyssey|Omen|Reforged|Ultimate|Unity|Vagary|Visit the main page)' ) {
                    $nmList += $title
                    $kept++
                }
            }
            Write-Host ("    kept $kept  (running total: $($nmList.Count))") -ForegroundColor DarkGray

            # Follow pagination.  BG-Wiki uses MediaWiki's "next page" link,
            # which looks like: <a href="/index.php?title=Category:Notorious_Monsters&amp;pagefrom=X">next page</a>
            # If the href is relative (/index.php?...), prepend the host.
            # Decode &amp; and HTML entities.  Retry 403 with a browser UA.
            $nextMatch = [regex]::Match($catHtml, 'href="([^"]+)"[^>]*>\s*next page\s*</a>')
            if ($nextMatch.Success) {
                $next = [System.Net.WebUtility]::HtmlDecode($nextMatch.Groups[1].Value)
                if ($next -notmatch '^http') { $next = 'https://www.bg-wiki.com' + $next }
                $pageUrl = $next
            } else {
                $pageUrl = $null
                Write-Host '    no next-page link; category walk complete.' -ForegroundColor DarkGray
            }
            Start-Sleep -Milliseconds $DelayMs
        }
        $nmList = $nmList | Select-Object -Unique | Sort-Object
        Write-Host "  Found $($nmList.Count) unique NM pages across $pagesSeen category pages." -ForegroundColor Green
    }
}

if (-not $nmList -or $nmList.Count -eq 0) {
    Write-Host "No NMs to scrape." -ForegroundColor Yellow
    exit 0
}

# ----------------------------------------------------------------------------
# Load existing DB to detect dupes
# ----------------------------------------------------------------------------
$existingKeys = @{}
if (Test-Path $DbPath) {
    $dbText = Get-Content $DbPath -Raw
    foreach ($m in [regex]::Matches($dbText, "PH\['([^']+)'\]")) {
        $existingKeys[$m.Groups[1].Value.ToLower()] = $true
    }
    Write-Host "Loaded $($existingKeys.Count) existing PH entries." -ForegroundColor DarkGray
}

# ----------------------------------------------------------------------------
# Fetch + parse each NM
# ----------------------------------------------------------------------------
$additions = @()
$skipped   = 0
$notFound  = @()

foreach ($nm in $nmList) {
    $nm = $nm.Trim()
    if (-not $nm) { continue }
    # HTML-decode (`&#039;` -> `'`, `&amp;` -> `&`, etc.) before URL-encoding.
    # BG-Wiki category pages contain HTML-escaped titles.
    $nm = [System.Net.WebUtility]::HtmlDecode($nm)
    # Build URL-safe path: spaces -> underscores; keep apostrophes/dashes
    # (BG-Wiki URLs use them literally); URL-encode anything else exotic.
    $urlName = ($nm -replace ' ', '_')

    # Fetch all configured wikis in parallel.  Cross-reference boosts confidence.
    # Add more sources by extending $pages below -- e.g. for Horizon-specific
    # NM data if HorizonXI publishes a wiki, add:
    #   'horizon' = "https://horizonxi.com/wiki/$urlName"
    # Entries that disagree between sources are flagged as MEDIUM confidence
    # so the user knows to verify in-game.
    $sources = @{}
    $pages   = @{
        'bg'  = "https://www.bg-wiki.com/ffxi/$urlName"
        'ffx' = "https://ffxiclopedia.fandom.com/wiki/$urlName"
    }
    foreach ($src in $pages.Keys) {
        try {
            $sources[$src] = Get-WebContent $pages[$src]
        } catch {}
    }
    if ($sources.Count -eq 0) {
        Write-Host "[404]  $nm (not on BG-Wiki or FFXIclopedia)" -ForegroundColor DarkYellow
        $notFound += $nm
        continue
    }
    $html = ($sources.Values -join "`n`n") # combined blob for pattern search

    # PH name patterns -- cover BG-Wiki + FFXIclopedia phrasing variants
    $phMatches = @()
    $patterns = @(
        # "Lottery spawn off of X"  / "Lottery Spawn off of X"  / "lottery spawn off of X"
        '[Ll]ottery\s+[Ss]pawn\s+off\s+of\s+<[^>]+>?\s*([A-Z][A-Za-z0-9 \-'']+?)\s*<',
        '[Ll]ottery\s+[Ss]pawn\s+off\s+of\s+([A-Z][A-Za-z0-9 \-'']+?)\s+(?:at|around|near|from)',
        # "Lottery Spawn from X"
        '[Ll]ottery\s+[Ss]pawn\s+from\s+(?:the\s+)?<[^>]+>?\s*([A-Z][A-Za-z0-9 \-'']+?)\s*<',
        '[Ll]ottery\s+[Ss]pawn\s+from\s+(?:the\s+)?([A-Z][A-Za-z0-9 \-'']+?)(?:\s+at|\s+around|\s+near|[\.\,])',
        # "Lottery: From X at Y"
        'Lottery[:\s]+From\s+([A-Z][A-Za-z0-9 \-'']+?)\s+at',
        # "Spawns from X" / "Spawned from X" / "Spawns off X"
        '[Ss]pawn(?:ed|s)?\s+(?:from|off\s+of|off)\s+(?:the\s+)?<[^>]+>?\s*([A-Z][A-Za-z0-9 \-'']+?)\s*<',
        '[Ss]pawn(?:ed|s)?\s+(?:from|off\s+of|off)\s+(?:the\s+)?([A-Z][A-Za-z0-9 \-'']+?)(?:\s+at|\s+around|[\.\,])',
        # "Place Holder: X"  "Placeholder: X"  "PH: X"  (also "Place Holder's ID is...")
        '(?:[Pp]lace\s*[Hh]older|PH)[s'']?\s*[:=]\s*<[^>]+>\s*([A-Z][A-Za-z0-9 \-'']+?)\s*<',
        '(?:[Pp]lace\s*[Hh]older|PH)[s'']?\s*[:=]\s*([A-Z][A-Za-z0-9 \-'']+?)(?:\s+at|[\.\,<])',
        # "X is the placeholder"
        '([A-Z][A-Za-z0-9 \-'']+?)\s+is\s+(?:the|a)\s+[Pp]laceholder',
        # "Pop from X" / "Pops from X"
        '[Pp]op(?:s|ped)?\s+from\s+(?:the\s+)?([A-Z][A-Za-z0-9 \-'']+?)(?:\s+at|[\.\,])'
    )
    foreach ($pat in $patterns) {
        foreach ($m in [regex]::Matches($html, $pat)) {
            $ph = $m.Groups[1].Value.Trim()
            if ($ph -and $ph.Length -lt 40 -and
                $ph -notmatch '^(The|An|A|At|And|In|On|Of|For|By|From|To)$') {
                $phMatches += $ph
            }
        }
    }
    $phMatches = $phMatches | Select-Object -Unique

    # Hex ID patterns -- BG-Wiki writes these a few different ways:
    #   "Placeholder ID is 17B."
    #   "Placeholder's ID is 126."
    #   "PH ID: 14A"
    #   "Placeholder IDs are 17B, 17C, 190."
    $hexIds = @()
    $hexPatterns = @(
        "Placeholder(?:'s)? ID is\s+<[^>]+>?\s*([0-9A-Fa-f, ]+)",
        "Placeholder(?:'s)? ID is\s+([0-9A-Fa-f, ]+)",
        "Placeholder(?:'s)? IDs are\s+([0-9A-Fa-f, ]+)",
        'PH ID[s]?:\s*([0-9A-Fa-f, ]+)'
    )
    foreach ($pat in $hexPatterns) {
        foreach ($m in [regex]::Matches($html, $pat)) {
            # Split comma/space-separated hex nums, filter obvious junk
            foreach ($tok in ($m.Groups[1].Value -split '[, ]+')) {
                $t = $tok.Trim().TrimEnd('.')
                if ($t -match '^[0-9A-Fa-f]{2,4}$') { $hexIds += $t.ToUpper() }
            }
        }
    }
    $hexIds = $hexIds | Select-Object -Unique

    # Location (first chunk after "Lottery spawn off of X at (Y)")
    $location = $null
    if ($html -match 'Lottery spawn off of[^.(]+at\s*\(([A-Z0-9\-/ ]+)\)') {
        $location = $Matches[1].Trim()
    }

    # Respawn / window (prose varies -- common forms)
    $respawnMin = $null
    if ($html -match '[Rr]espawn.{0,80}?(\d{1,3})(?:\s*to\s*\d{1,3})?\s*minute') {
        $respawnMin = [int]$Matches[1]
    } elseif ($html -match '[Rr]espawn.{0,80}?(\d{1,3})\s*hour') {
        $respawnMin = [int]$Matches[1] * 60
    }

    # Widescan description -- the GOLD data for era servers (hex-independent).
    # "bottom lizard of first group of five"
    # "3rd Forest Hare in bottom group of 3"
    # "last Damselfly in group of 4 between Snippers and Thread Leeches"
    $widescan = $null
    $wsPatterns = @(
        'Wide ?[Ss]can[,:]?\s*([^<\n\.]{10,200}[\.<])',
        'In widescan[,:]?\s*([^<\n\.]{10,200}[\.<])',
        '[Ii]n Wide Scan[,:]?\s*([^<\n\.]{10,200}[\.<])',
        '(bottom[^<\n\.]{5,120}placeholder)',
        '(top[^<\n\.]{5,120}placeholder)',
        '(\d(?:st|nd|rd|th)[^<\n\.]{5,120}placeholder)',
        '(first group of \w+[^<\n\.]{5,120})'
    )
    foreach ($pat in $wsPatterns) {
        if ($html -match $pat) {
            $widescan = $Matches[1] -replace '<[^>]+>', '' -replace '\s+', ' '
            $widescan = $widescan.Trim().TrimEnd('.<')
            if ($widescan.Length -gt 180) { $widescan = $widescan.Substring(0, 180) + '...' }
            break
        }
    }

    # Confidence: PH name appearing in BOTH wikis = HIGH; one = MEDIUM
    $confidence = 'MEDIUM'
    if ($sources.Count -ge 2 -and $phMatches.Count -gt 0) {
        $hits = 0
        foreach ($src in $sources.Values) {
            if ($src -match [regex]::Escape($phMatches[0])) { $hits++ }
        }
        if ($hits -ge 2) { $confidence = 'HIGH (BG+FFXIc)' }
    }

    if ($phMatches.Count -eq 0) {
        Write-Host "[none] $nm  (no PH pattern matched -- may be world-spawn)" -ForegroundColor DarkGray
        continue
    }

    foreach ($ph in $phMatches) {
        $key = $ph.ToLower()
        if ($existingKeys.ContainsKey($key)) {
            $skipped++
            continue
        }
        $additions += [PSCustomObject]@{
            PH         = $ph
            NM         = $nm
            HexIds     = $hexIds
            Location   = $location
            RespawnSec = if ($respawnMin) { $respawnMin * 60 } else { $null }
            Widescan   = $widescan
            Confidence = $confidence
        }
        $existingKeys[$key] = $true
        $hexStr = if ($hexIds.Count -gt 0) { "  hex=$($hexIds -join ',')" } else { '' }
        $wsStr  = if ($widescan) { "  ws=`"$widescan`"" } else { '' }
        $color  = if ($confidence -like 'HIGH*') { 'Green' } else { 'Yellow' }
        Write-Host "[$confidence] $nm  <-  $ph$hexStr$wsStr" -ForegroundColor $color
    }
    Start-Sleep -Milliseconds $DelayMs
}

# ----------------------------------------------------------------------------
# Append new entries to the Lua DB
# ----------------------------------------------------------------------------
if ($additions.Count -gt 0) {
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $block = "`n`n-- ============================================================================`n"
    $block += "-- Scraped from BG-Wiki on $stamp`n"
    $block += "-- ============================================================================`n"
    foreach ($row in $additions) {
        $phLua = $row.PH -replace "'", "\\'"
        $nmLua = $row.NM -replace "'", "\\'"
        $parts = @("pops = { '$nmLua' }")
        if ($row.HexIds -and $row.HexIds.Count -gt 0) {
            $hexLua = ($row.HexIds | ForEach-Object { "0x$_" }) -join ', '
            # Note: retail hexes are kept as a REFERENCE under a separate field
            # (not ph_hex_ids) because they won't match era-server hexes.
            # The user calibrates with /ct learn or /ct range in-game.
            $parts += "ph_hex_ids_retail = { $hexLua }"
        }
        if ($row.Location) {
            $locLua = $row.Location -replace "'", "\\'"
            $parts += "location = '$locLua'"
        }
        if ($row.RespawnSec) {
            $parts += "respawn_sec = $($row.RespawnSec)"
        }
        if ($row.Widescan) {
            $wsLua = $row.Widescan -replace "'", "\\'"
            $parts += "widescan = '$wsLua'"
        }
        if ($row.Confidence) {
            $parts += "confidence = '$($row.Confidence)'"
        }
        $body = $parts -join ', '
        $block += "PH['$($phLua.ToLower())'] = { $body };`n"
    }

    # Insert before the final `return M;` line
    $db = Get-Content $DbPath -Raw
    if ($db -match '(?s)^(.*?)(return M;?\s*)$') {
        $new = $Matches[1] + $block + $Matches[2]
    } else {
        $new = $db + $block
    }
    Set-Content -Path $DbPath -Value $new -NoNewline -Encoding UTF8
}

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Scanned:     $($nmList.Count) NMs"
Write-Host "Added:       $($additions.Count) new PH entries"
Write-Host "Skipped:     $skipped (already in DB)"
Write-Host "Not found:   $($notFound.Count) (404 on BG-Wiki)"
if ($notFound.Count -gt 0) {
    Write-Host "  $($notFound -join ', ')" -ForegroundColor DarkGray
}
Write-Host ""
Write-Host "Reload the addon in-game to pick up the new entries:" -ForegroundColor Yellow
Write-Host "  /addon reload chhartarget" -ForegroundColor White
