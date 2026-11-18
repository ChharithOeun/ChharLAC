# SCRUB-HISTORY.ps1 -- rewrite ChharLAC git history to purge the player ID
#                       and remove the self-leaking scrub script.
#
# DESTRUCTIVE: this rewrites every commit SHA on your branch.  Any existing
# clone/fork of this repo becomes incompatible.  Only run this BEFORE you
# publish, OR if you accept that collaborators will have to re-clone.
#
# What it does:
#   1. Verifies git-filter-repo is installed (pip install git-filter-repo).
#   2. Shows you what strings will be replaced BEFORE the rewrite runs.
#   3. Requires you to type a confirmation phrase (so you can't double-click
#      your way into a destructive rewrite by mistake).
#   4. Runs git-filter-repo with:
#        - path-delete:  SCRUB-PLAYER-ID.ps1   (the self-leaker)
#        - path-delete:  profiles/Chharizard_190378/   (if the folder was
#          ever committed in any ancestor commit; filter-repo removes it
#          from every revision)
#        - replace-text: 190378          -> PID
#        - replace-text: Chharizard_190378 -> CHAR_PID
#   5. Shows you a diff summary and asks you to force-push explicitly.
#
# After it runs, the SCRUB-PLAYER-ID.ps1 script will be gone from HEAD and
# from every reachable ancestor commit; the player id becomes unrecoverable
# via git log -p.
#
# ---
# SAFETY: this script does NOT push by itself.  You run `git push --force`
# manually after reviewing the diff.  If anything looks wrong you can `git
# reflog` to find the pre-rewrite commit and reset back.

$ErrorActionPreference = 'Stop'

Write-Host '===========================================' -ForegroundColor Red
Write-Host '  ChharLAC history scrub (DESTRUCTIVE)'       -ForegroundColor Red
Write-Host '===========================================' -ForegroundColor Red
Write-Host ''

# 1. Prereq -- git-filter-repo (via python -m, not git subcommand)
$ok = $false
try {
    python -m git_filter_repo --help *>$null
    $ok = ($LASTEXITCODE -eq 0)
} catch { $ok = $false }
if (-not $ok) {
    Write-Host 'ERROR: git-filter-repo is not installed.' -ForegroundColor Red
    Write-Host 'Install it with:  pip install git-filter-repo' -ForegroundColor Yellow
    Write-Host 'Docs: https://github.com/newren/git-filter-repo' -ForegroundColor Yellow
    exit 1
}
function Invoke-FilterRepo { python -m git_filter_repo @args }

# 2. Preview the leak
Write-Host 'Scanning git history for the leaked strings...' -ForegroundColor Cyan
$hits = git log --all -p | Select-String -Pattern '(190378|Chharizard_190378)' | Measure-Object
Write-Host ("  found {0} hits across all commits" -f $hits.Count) -ForegroundColor Yellow
if ($hits.Count -eq 0) {
    Write-Host 'Nothing to scrub.  History is already clean.' -ForegroundColor Green
    exit 0
}

# 3. Confirmation phrase
Write-Host ''
Write-Host 'This will REWRITE EVERY COMMIT in your repo history.' -ForegroundColor Red
Write-Host 'Anyone with an existing clone will have to re-clone.'  -ForegroundColor Red
Write-Host 'The commit SHAs you see in `git log` will all change.' -ForegroundColor Red
Write-Host ''
$phrase = 'rewrite my history'
$typed = Read-Host "To proceed, type: $phrase"
if ($typed -ne $phrase) {
    Write-Host 'Phrase did not match.  Aborting.' -ForegroundColor Yellow
    exit 1
}

# 4. Backup bundle
$bak = ".git/pre-scrub-$([int][double]::Parse((Get-Date -UFormat %s))).bundle"
Write-Host "Creating backup bundle at $bak ..." -ForegroundColor Cyan
git bundle create $bak --all
Write-Host '  backup created.' -ForegroundColor Green

# 5. Build the replacements file.  Format: `old==>new` per line.
$replFile = '.git/scrub-replacements.txt'
@(
    'Chharizard_190378==>CHAR_PID',
    '190378==>PID'
) | Set-Content -Encoding ASCII $replFile
Write-Host "Replacements file: $replFile" -ForegroundColor Gray

# 6. Delete the self-leaking scrub script from every revision.
Write-Host ''
Write-Host 'Removing SCRUB-PLAYER-ID.ps1 from every commit...' -ForegroundColor Cyan
Invoke-FilterRepo --path SCRUB-PLAYER-ID.ps1 --invert-paths --force

# 7. Delete any committed Chharizard_190378 folder from every revision.
Write-Host ''
Write-Host 'Removing profiles/Chharizard_190378/ (if ever committed)...' -ForegroundColor Cyan
Invoke-FilterRepo --path profiles/Chharizard_190378 --invert-paths --force

# 8. Replace the leaked strings everywhere.
Write-Host ''
Write-Host 'Replacing leaked strings in all remaining files...' -ForegroundColor Cyan
Invoke-FilterRepo --replace-text $replFile --force

# 9. Verify
Write-Host ''
Write-Host 'Re-scanning...' -ForegroundColor Cyan
$after = git log --all -p | Select-String -Pattern '(190378|Chharizard_190378)' | Measure-Object
if ($after.Count -eq 0) {
    Write-Host '  CLEAN -- no hits remain.' -ForegroundColor Green
} else {
    Write-Host ("  WARNING: {0} hits still remain." -f $after.Count) -ForegroundColor Red
    Write-Host '  Something else is leaking.  Inspect:' -ForegroundColor Yellow
    Write-Host "    git log --all -p | Select-String '190378'" -ForegroundColor Yellow
}

# 10. Next steps
Write-Host ''
Write-Host '===========================================' -ForegroundColor Green
Write-Host 'DONE.  Review before pushing:'               -ForegroundColor Green
Write-Host '===========================================' -ForegroundColor Green
Write-Host '  git log --oneline -20'
Write-Host '  git show HEAD'
Write-Host ''
Write-Host 'When satisfied, FORCE-PUSH:'
Write-Host '  git push --force-with-lease origin main' -ForegroundColor Yellow
Write-Host ''
Write-Host 'If something looks wrong, restore from backup:'
Write-Host ("  git bundle verify $bak") -ForegroundColor Gray
Write-Host ("  git clone $bak restored-repo")           -ForegroundColor Gray
Write-Host ''
