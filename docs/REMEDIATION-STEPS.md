# Remediation steps -- do these in order

Covers the fixes landed on 2026-10-27 in response to `SECURITY_AUDIT.md`.

## Local-only (sandbox) changes already made

- `.gitignore` extended to cover `addons/chhardig/`, `tools/checkmate-extract/`,
  `**/ph_user.lua`, `**/paths_*.lua`, `**/settings.lua`, `*.exe` under tools,
  backup folders, and a defense-in-depth wildcard that matches any file
  whose name contains a 6-digit sequence (likely a player id).
- `/sessions/inspiring-amazing-thompson/mnt/Chharith/ChharDig-private/`
  staged with chhardig moved out of ChharLAC entirely + its own `.gitignore`
  + a `README.md` explaining why it stays private.
- Suspicion scoring wired for real in `ChharDig-private/addons/chhardig/
  chhardig.lua` -- `on_packet` now scores "appeared close", "abnormal speed",
  "probe visit"; `on_text` scores "examined you" (/check); hard-stops when
  the per-player total exceeds `settings.suspicion_cap`.
- `pathing.lua` prologue now documents the FFI-keyboard detection surface
  honestly (what a client-side monitor would see) and lists what we tried
  and what we explicitly did not try.

## What YOU need to run on your Windows box

### 1. Remove chhardig from the ChharLAC working tree

From a ChharLAC repo shell:

```powershell
git rm -r addons/chhardig
git commit -m "move chhardig out of the public repo (see ChharDig-private)"
```

The folder is now gitignored, so if a stray copy ever reappears locally
`git status` will not list it.

### 2. Delete the self-leaking scrub script (and run its replacement)

```powershell
pip install git-filter-repo
.\SCRUB-HISTORY.ps1
```

The script:
- Verifies git-filter-repo is installed.
- Shows how many hits of `190378` / `Chharizard_190378` exist in history.
- Requires you to type `rewrite my history` to proceed.
- Creates a `.git/pre-scrub-<timestamp>.bundle` backup.
- Removes `SCRUB-PLAYER-ID.ps1` from every commit.
- Removes `profiles/Chharizard_190378/` from every commit (if ever added).
- Replaces the string in every remaining file.
- Verifies 0 hits remain.
- Tells you the force-push command.

After it finishes you review:

```powershell
git log --oneline -20
git show HEAD
```

Then force-push:

```powershell
git push --force-with-lease origin main
```

### 3. Stand up ChharDig-private as its own repo

```powershell
cd "C:\Users\<you>\Documents\Chharith\ChharDig-private"
git init
git add .
git commit -m "ChharDig v1.0 initial import (private)"
gh repo create ChharDig --private --source . --push
```

Or without the gh CLI:

```powershell
git remote add origin git@github.com:ChharithOeun/ChharDig.git
git push -u origin main
```

Keep it **private** on GitHub. Do not add the public ChharLAC README to
point at it.

### 4. Regenerate tools/checkmate-extract outputs locally

Those extractor scripts hardcode my sandbox paths. On your box:

```powershell
cd tools\checkmate-extract
# Edit extract.py / merge_rechhar.py and replace
#   /sessions/inspiring-amazing-thompson/mnt/Chharith/...
# with your real local paths.
python extract.py --checkmate <path-to-checkmate-clone> --out out
```

Since `tools/checkmate-extract/` is now gitignored, these edits never
leak back to the repo.

### 5. Verify

```powershell
# Nothing in the live tree
Select-String -Path . -Pattern '190378' -Recurse
Select-String -Path . -Pattern 'Chharizard_190378' -Recurse

# Nothing in history
git log --all -p | Select-String '190378'
```

All three should return zero hits.

## What remains unfixed (by design)

- **Keyboard-FFI detection surface in chhardig.** Documented in
  `pathing.lua`. We could lower it with SendMessage WM_KEYDOWN to the
  game HWND, but that's also detectable by anyone who looks, and lacks
  cross-key timing fidelity. The honest answer is "running any dig bot
  is a risk, this one is as careful as a dig bot can be."
- **ToS risk of chhardig itself.** Addressed by making the repo private
  and documenting the risk in both READMEs.
- **Tools/wget.exe binary.** Not currently committed; now gitignored.
  If you want to keep using it, keep it local.
