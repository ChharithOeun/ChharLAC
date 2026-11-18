# ChharLAC — Security & Exposure Audit

Date: 2026-10-27
Scope: addons/*, profiles/_template/*, tools/*, repo root, git state.
Branch audited: `main` @ `1c70a00`.

---

## Executive summary (TL;DR)

1. **Player ID `190378` is still permanently baked into git history** (15 occurrences across the "scrub" commit `1c70a00` and parent `91e7d5e`). The scrub reduced the live tree only; a `git clone` + `git log -p` immediately recovers `Chharizard_190378`. Public repo = effective doxx of the server-side account.
2. **`SCRUB-PLAYER-ID.ps1` is tracked at HEAD and itself contains the literal `Chharizard_190378` / `190378` strings** (lines 63-115). The scrub script undoes its own scrub.
3. **`chhardig` is a dig bot** that drives movement via `user32.dll` `keybd_event` (`pathing.lua:50`) and queues `/dig` with human-shaped but still fully automated cadence. Running it on Phoenix/Horizon is an unambiguous ToS violation and is bannable even without packet forgery. The "max paranoia" safety floor reduces, but does not eliminate, detectability.
4. **Suspicion-score detection in `chhardig` is dead code** — `on_packet` wires only the GM-flag hard stop and never increments scores for `/check`, probe visits, warp-in, or odd speed, despite `sentinel.lua` providing the API and the design doc promising it. "paranoia=max suspicion_cap=2" is a lie at runtime.
5. **Local sandbox paths exposing the real first name `Chharith`** are hard-coded in `tools/checkmate-extract/*.py`. These files are not yet tracked but are not excluded by `.gitignore`; a bulk `git add tools/` leaks them.

---

## Findings (sorted by severity)

| # | Sev | File | Issue |
|---|-----|------|-------|
| 1 | CRITICAL | git history (`1c70a00`, `91e7d5e`) | Player ID `190378` + `Chharizard_190378` recoverable from any public clone |
| 2 | CRITICAL | `SCRUB-PLAYER-ID.ps1:63,65,66,73,89,111,115` | Scrub script itself leaks the ID it was meant to erase; also at HEAD |
| 3 | HIGH | `addons/chhardig/*` (whole addon) | Chocobo-dig automation = ToS violation; shipping it under public pseudonym links identity to bot activity |
| 4 | HIGH | `addons/chhardig/chhardig.lua:261-276` | Suspicion scoring never fires; `on_packet` only triggers hard-stop on raw GM flag bits |
| 5 | HIGH | `addons/chhardig/pathing.lua:42-61` | `user32.dll keybd_event` + `MapVirtualKeyA` via LuaJIT FFI — low-level key injection, novel detection surface |
| 6 | HIGH | `tools/checkmate-extract/extract.py:16-17`, `merge_rechhar.py:13` | Hard-coded `/sessions/inspiring-amazing-thompson/mnt/Chharith/...` leaks real first name + cowork sandbox id; not ignored by `.gitignore` |
| 7 | MEDIUM | `addons/chhardig/sentinel.lua:104-111` | `gm_signs` doesn't flag Flags1 bit 12 (AnonymousFlag) or bit 29 (InvisFlag) — common staff tells on era servers |
| 8 | MEDIUM | `addons/chhardig/chhardig.lua:211` | `msg:match('^(%a+)%s*>>')` for staff /tell is server-locale fragile and matches party chat prefixes; empty staff list = no detection at all |
| 9 | MEDIUM | `addons/chhardig/chhardig.lua:222-246` | Chat-based "found/nothing" counters match any player's `/dig` text in the same zone (`digs up a Fire Crystal` from a stranger increments our daily cap). Not a leak, but could suppress exits |
| 10 | MEDIUM | `.gitignore` | Does NOT exclude `tools/checkmate-extract/`, `addons/chhardig/`, `addons/chhartarget/ph_user.lua`, or any `**/settings.lua`. Learned hex IDs + bot source are one `git add -A` away from publication |
| 11 | MEDIUM | `README.md:83-85`, `LICENSE:3`, `INIT.bat:3,24` | Public pseudonym `Chharizard` is bound to the GitHub account `ChharithOeun` across repos. Not technically a leak (the account name contains the real first name), but the audit stance should acknowledge it is a persistent de-anonymization vector |
| 12 | MEDIUM | `addons/chhardig/chhardig.lua:189-192` + `262-271` | `auto_logout = true` by default on *any* 0x00D flag — a false positive from a hidden-cutscene PC near you will instantly `/logout` mid-combat. The design acknowledges HideFlag is non-staff; the code (`gm_signs`) excludes it. Still worth flagging that **any** false positive forces logout |
| 13 | MEDIUM | `addons/chhartarget/chhartarget.lua:306,651,704`, `addons/chharcontrol/chharcontrol.lua:101` | `os.execute('mkdir ...')` with path from `AshitaCore:GetInstallPath()`. Not injectable in practice, but spawns `cmd.exe` (visible in task manager). Prefer `ashita.fs.create_directory` (already used in `pathing.lua:121`) |
| 14 | MEDIUM | `addons/chhardig/pathing.lua:122,150` | `_ensure_save_path()` writes `paths_<pid>.lua`; `M.load()` then `dofile`s it. Any local process with write access to `config/addons/chhardig/` gets RCE under the game's user. Threat model is local, but if you ever share that folder in a cloud sync, this is a hole |
| 15 | LOW | `profiles/_template/RNG.lua:5` | Comment hard-codes `C:\Users\User\...\Chharizard_RNG.lua`. "User" is Windows default, not a real username; keep as placeholder |
| 16 | LOW | All profiles (`BLM.lua`, `WAR.lua`, etc.) | `Sub.echo("[Chharizard JOB] loaded")` prints the pseudonym to console on every load — visible in screenshots |
| 17 | LOW | `addons/chhardig/chhardig.lua:36-38`, `addons/chhardig/README.md:34-35` | ToS-violation self-admission in the source. Fine for private use; damning if the repo is ever subpoenaed/screenshotted. |
| 18 | LOW | `tools/wget.exe`, `tools/wget.exe.debug` | Vendored binaries ship with build metadata (likely Mingw-w64 symbols). Low value in repo; large; invites AV false positives for cloners |
| 19 | LOW | `addons/chharburst/chharburst.lua:342-347`, `chhardig.lua:380,392` | `QueueCommand(1, '/ma ...')` / `'/dismount'` / `'/logout'` — Ashita chat injection is normal client input, not detectable, but worth noting cadence is still bot-shaped (ChharBurst fires exactly `cast_delay` after close; add jitter) |
| 20 | LOW | Everywhere | Reckless `pcall()` wrapping around every `AshitaCore:GetMemoryManager()` call hides real breakage. Not security, but when something breaks you'll never see the stack. |

---

## Per-finding details

### 1. CRITICAL — git history still contains the player ID

```
$ git log --all -p | grep -c 190378
15
$ git log --all -p | grep -oE 'Chharizard_190378' | wc -l
15
```

Both the "scrub" commit (`1c70a00`) and the initial commit (`91e7d5e`) carry the folder name verbatim in their diffs. Pushing the current `main` to a public remote exposes the ID forever, even though the live tree is clean.

**Fix.** Rewrite history before publishing (destructive):
```
pip install git-filter-repo
git filter-repo --path profiles/Chharizard_190378 --invert-paths --force
git filter-repo --replace-text <(printf 'Chharizard_190378==>CHAR_PID\n190378==>PID\n')
git push --force-with-lease origin main
```
Or keep the repo private.

### 2. CRITICAL — SCRUB-PLAYER-ID.ps1 leaks the ID at HEAD

`SCRUB-PLAYER-ID.ps1` is tracked and literally contains `Chharizard_190378` on lines 63, 65, 66, 73, 89, 111, 115 and `190378` references throughout. Even after a history rewrite, the current working tree would re-leak.

**Fix.** Delete the script (or move to a private gist); it was single-use. Replace with a generic placeholder-driven version if you need to retain the workflow:
```powershell
param([Parameter(Mandatory)][string]$Folder)
git rm -rf $Folder
```

### 3. HIGH — chhardig is a dig bot

`chhardig.lua:1-40` admits: "Running an automated digging loop is prohibited on most private servers." This is correct. The paranoia floor + log-normal cadence makes it harder for a GM to catch *during a single probe*, but server-side telemetry (interact-rate buckets, zone-dwell distributions) catches these on batch reviews. If this repo is public, your character identity is now attached to a dig bot in the public record.

**Fix.** Move `addons/chhardig/` to a private repo, and add `addons/chhardig/` to `.gitignore` here. Confirm it is not currently tracked (`git ls-files | grep chhardig` → currently empty, good) and make sure it stays that way.

### 4. HIGH — suspicion scoring is dead code

`chhardig.lua:262-276`:
```lua
local function on_packet(e)
    ...
    -- Suspicion scoring: /check, probe visits, close warps, etc.
    -- We just use sentinel's existing scoring API; detecting the specific
    -- trigger kinds requires more hooks that live in Metacast.lua -- for
    -- now we rely on the hard-stop signs above + staff name /tell.
end
```

`sentinel.add` / `sentinel.total` are never called from `chhardig.lua`. `settings.suspicion_cap` is read nowhere outside the paranoia preset block. The UI claim of "max=2" is cosmetic.

**Fix.** Either wire the hooks (0x00E `/check` message, 0x00D proximity delta, 0x00D speed > cap) or remove the dial from the UI so the user doesn't believe they have protection they don't.

### 5. HIGH — low-level keyboard injection

`pathing.lua:42-61`:
```lua
ffi.cdef[[
    void keybd_event(unsigned char bVk, unsigned char bScan, DWORD dwFlags, unsigned long dwExtraInfo);
]]
...
ffi.C.keybd_event(vk, scan, flags, 0);
```

`keybd_event` is a legacy input API that writes directly to the global keyboard state. It bypasses Ashita's own input stack and is visible to any process using `SetWindowsHookEx(WH_KEYBOARD_LL)` — anti-cheat vendors routinely do this. Current FFXI private-server anti-cheat is not that sophisticated, but the attack surface is wide.

**Fix.** If you must drive movement without packets, use `SendInput` with `INPUT_KEYBOARD` and `KEYEVENTF_SCANCODE` *addressed to the game window* via `PostMessage(WM_KEYDOWN)` instead — stays per-window, less visible to global hooks. Better still: don't automate movement, and have the user walk the exit path manually.

### 6. HIGH — real first name in tool scripts

```
tools/checkmate-extract/extract.py:16: --checkmate /sessions/inspiring-amazing-thompson/ext/checkmate/checkmate
tools/checkmate-extract/extract.py:17: --out       /sessions/inspiring-amazing-thompson/mnt/Chharith/ChharLAC/tools/checkmate-extract/out
tools/checkmate-extract/merge_rechhar.py:13: TARGET = Path('/sessions/inspiring-amazing-thompson/mnt/Chharith/reChhar/addons/rechhar/data/abilities.lua')
```

`Chharith` is the user's real first name per their email (`chharith@gmail.com`). These files are untracked but `.gitignore` does not exclude `tools/checkmate-extract/`.

**Fix.** Replace absolute paths with `pathlib.Path(__file__).parent` relative lookups, and add to `.gitignore`:
```
tools/checkmate-extract/
```

### 7. MEDIUM — sentinel.gm_signs misses AnonymousFlag/InvisFlag

`sentinel.lua:104-111` only reports `gm >= 3`, `gm_icon_hidden`, `hackmove|ground`. It computes `d.anon` and `d.invis` into the decoded struct (lines 72-73) but never surfaces them. Metacast's doc comments at the top of the file list these as proxy-check signals.

**Fix.** Add to `gm_signs`:
```lua
if d.anon  then r[#r+1] = 'anonymous flag' end
if d.invis then r[#r+1] = 'invisible flag (spell)' end
```
Note `anon` on another player is NOT staff — a player with an anonymity gear/trait flips it too — so treat it as a +1 suspicion point, not a hard stop.

### 8. MEDIUM — staff /tell regex is fragile

`chhardig.lua:211`:
```lua
local sender = msg:match('^(%a+)%s*>>');
```
Incoming /tell on Ashita renders as `<Sender>>>You:` or similar; the actual chat_mode is 3 (tell). Pattern-matching the rendered text is locale-fragile and misses tells sent through alternate chat modes. Also matches *any* word followed by `>>` at line start, which can happen in system messages.

**Fix.** Switch to `e.mode == 3` detection (`text_in` events carry a `mode` on Ashita v4) and parse the sender from the structured field, not the display string. Also require a non-empty `settings.staff_names` before the whole handler runs; log a warning on `load` if empty.

### 9. MEDIUM — chat counters match other players' dig results

`chhardig.lua:222`:
```lua
local found_name = msg:match('digs up an? (.+)%.') ...
```

Another player in the same zone digging up a crystal increments `state.daily_finds`, which can trip `settings.daily_cap` and send *you* into exit sequence despite doing nothing.

**Fix.** Require the message mode to be your own action (chat mode 121 "You dig up ...") or prefix-check `msg:find('^You')`.

### 10. MEDIUM — .gitignore gaps

Current `.gitignore` protects `profiles/*_[0-9]*/` and `settings.xml`, but **not**:
- `tools/checkmate-extract/` — has real-name paths
- `addons/chhardig/` — bot source
- `addons/chhartarget/ph_user.lua` — learned hex IDs tie to specific char kills
- `addons/*/settings.lua` — persisted per-addon state
- `addons/chhartarget/era-nm-seed.txt`
- `**/paths_*.lua` — waypoint files pathing.lua writes (contain play locations)

**Fix.** Append:
```
# bot source (private; never publish)
addons/chhardig/

# per-run data that identifies play behaviour
addons/*/settings.lua
addons/chhartarget/ph_user.lua
**/paths_*.lua

# internal tooling (contains absolute sandbox paths)
tools/checkmate-extract/
```

### 11. MEDIUM — pseudonym binds to real GitHub

`README.md`, `LICENSE`, `INIT.bat` all cross-link `ChharithOeun` ↔ `Chharizard`. The GitHub login `ChharithOeun` carries the real first name. This is a pre-existing exposure (public GitHub), but worth noting that **every** addon echoing `[Chharizard JOB] loaded` imprints the pseudonym into chat screenshots the user might post.

**Fix (optional).** Rename echoes to `[LAC JOB]` or `[CHAR JOB]`. Change `addon.author` strings to a generic handle.

### 12. MEDIUM — auto_logout = true on any 0x00D flag

If `gm_signs` ever misfires (new server adds a flag bit, or `data_raw` is truncated), `auto_logout` triggers mid-combat. Not a security hole, but a self-inflicted DoS vector.

**Fix.** Require two independent signs within N seconds, or move auto-logout off by default and let the user opt in once they trust the detector.

### 13. MEDIUM — os.execute for mkdir

Four call sites (`chhartarget.lua:306,651,704`, `chharcontrol.lua:101`) run `cmd.exe /c mkdir`. Not injectable, but every call pops a cmd window briefly and is noisy. `pathing.lua:121` already uses `ashita.fs.create_directory`.

**Fix.** Replace all four `os.execute('mkdir ...')` with `ashita.fs.create_directory(dir)`.

### 14. MEDIUM — dofile on persisted settings

`pathing.lua:150`, `chharcontrol.lua:109`, every profile `_TEMPLATE.lua:28`. The config dir is user-writable only, so RCE requires a local foothold already. Still a bad default. Prefer parsing with a sandboxed `load()` env.

### 15-20. LOW findings

Addressed in the table. None are urgent; several (16, 17) are design choices.

---

## Good patterns found (keep doing these)

- `chharburst/chharburst.lua:439` — `packet_in` handler is read-only (parses 0x28, never injects 0x28). No forged action packets.
- `pathing.lua:1-10` — Explicit design note: "We never inject movement packets (0x015)." Server-side movement validation is correctly identified as the trip wire.
- `realism.lua` — Log-normal cadences, fatigue drift, distraction injection, soft bounds. This is the right shape for human timing.
- `sentinel.lua:62-93` — Clean, defensive 0x00D decoder with explicit size checks.
- `.gitignore` — Correct exclusion of `profiles/*_[0-9]*/` (the Name_PID folder pattern) with a `_template` whitelist.
- All addons wrap `AshitaCore:GetMemoryManager()` calls in `pcall` — survives API shape changes between Ashita builds. (Note: see finding #20 — don't lose the error entirely.)
- `chhardig.lua:36-38` — Honest ToS note at the top of the bot addon. Reader is warned.
- No `loadstring()` / `load()` on untrusted input anywhere.
- No HTTP exfiltration anywhere — nothing imports `socket`, `luasocket`, `WinHTTP`, or shells curl/wget.
- No `/login` command injection anywhere.
- No stored passwords, API keys, Discord webhooks, or OAuth tokens.
- `SETUP.ps1` requires the user to type their own ID and keeps it strictly local (never commits it, since the output folder matches the `.gitignore` glob).

---

## Appendix: grep commands used

```sh
# Player ID + character names
git -C . grep -nE '\b(190378|3679|3858)\b'
git -C . grep -n 'Chharizard'
git -C . grep -n 'Chharith'

# Windows user paths
git -C . grep -nE 'C:\\Users\\|/Users/[^/]+/|/home/[^/]+/|/mnt/Chharith'

# Dangerous Lua
git -C . grep -nE '(loadstring|os\.execute|io\.popen|dofile\s*\(|packet_out|InjectPacket|QueueCommand\(1,\s*./login)'

# Packet / input injection
git -C . grep -nE '(ashita\.packets|packet_in|packet_out|ashita\.vks|SendString|keybd_event|SetKeyboardState|user32|InjectPacket)'

# Secrets
git -C . grep -niE '(discord|webhook|http://|https://|api[_ -]?key|token|password|secret|bearer)'

# Network / disk-exfil
git -C . grep -nE '(socket|LuaSocket|require..socket|http\.request|io\.open.*log|io\.open.*tells|chatlog)'

# Git history recovery check (CRITICAL)
git log --all -p | grep -c 190378                       # expect 0, currently 15
git log --all -p | grep -oE 'Chharizard_190378' | wc -l # expect 0, currently 15
git log --all --name-only | grep -E 'Chharizard_|_[0-9]{3,}'
```

Re-run after each remediation to confirm the counts fall to 0.
