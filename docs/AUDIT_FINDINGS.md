# Chharizard API-Call Audit

Audit of Ashita API calls in our addons against `ASHITA_API.md`.

**Legend**
- OK — call appears in sampled known-good addons (chains, chharmaton,
  checkmate, equipmon, craftbook) with the same signature.
- WRONG — the method doesn't exist or has the wrong name; replacement given.
- UNVERIFIED — plausible but not seen in any known-good source. Needs a
  runtime check or a reference against `docs.ashitaxi.com`.

---

## `addons/chharburst/chharburst.lua`

| Line | Call | Status | Notes |
|------|------|--------|-------|
| 132 | `AshitaCore:GetMemoryManager():GetPlayer()` | OK | |
| 134-135 | `player:GetMainJob()` / `:GetSubJob()` | OK | returns job id (0..23) |
| 136 | `AshitaCore:GetResourceManager()` | OK | |
| 137-138 | `res:GetJobByIndex(mainIdx)` | **WRONG / UNVERIFIED** | Not seen in any sampled addon. Replace with `AshitaCore:GetResourceManager():GetString('jobs.names_abbr', mainIdx)` to get the 3-letter abbreviation, matching `chains:388` and `profiles/subjob_features:412`. |
| 139-140 | `m.NameAbbr3` / `m.Name3` | **WRONG** | These field names are not real. If `GetJobByIndex` returned a struct it would be `.Name[1]` for English (resource DAT convention). Fix by switching to `GetString('jobs.names_abbr', id)` which returns a trimmed string directly. |
| 172 | `res:GetSpellByName(spellName, 0)` | OK | `chains:549` |
| 177 | `player:HasSpellData()` | OK | `checkmate player:419` |
| 178 | `player:HasSpell(sp.Index)` | OK | `checkmate player:420`, `chains:551` |
| 182 | `player:GetMainJobLevel()` | OK | |
| 184 | `player:GetSubJobLevel()` | OK | |
| 185-186 | `sp.LevelRequired[mainIdx]` | OK (with caveat) | `.LevelRequired` is indexed by **job id**; subIdx can be 0 ("no subjob") — current code's `reqS and reqS > 0 and ... >= reqS` handles it. |
| 209 | `player:GetMP()` | OK | `chains:505` |
| 215 | `party:GetMemberServerId(0)` | OK | |
| 222 | `AshitaCore:GetMemoryManager():GetEntity()` | OK | |
| 225 | `ent:GetServerId(i)` | OK | |
| 236 | `me:GetMemberTargetIndex(0)` | OK | |
| 238-239 | `ent:GetLocalPositionX/Y(idx)` | OK | |
| 253-255 | iterate `party:GetMemberServerId(i)` for i=0..17 | OK | correct alliance slot range |
| 261 | `ent:GetClaimStatus(idx)` | OK | returns claim server-id, 0 = unclaimed |
| 330, 335, 341 | `AshitaCore:GetChatManager():QueueCommand(1, cmd)` | OK | |
| 338, 347 | **`ashita.tasks.once(delay, fn)`** | **WRONG** | Correct name is `ashita.tasks.oncef`. See `equipmon:587`, `craftbook/window.lua:83`. The current `ashita.tasks.once` call will likely nil-deref — the `ashita.tasks and ashita.tasks.once` guard at line 346 silently skips the delay and casts immediately. Fix: `ashita.tasks.oncef(delay, fn)`. |

**Blocker fixes for chharburst** (ship-stopping bugs):

1. Replace `res:GetJobByIndex(idx)` + `.NameAbbr3`/`.Name3` with:
   ```lua
   local mn = (AshitaCore:GetResourceManager():GetString('jobs.names_abbr', mainIdx) or ''):gsub('%s+$', '');
   local sn = (AshitaCore:GetResourceManager():GetString('jobs.names_abbr', subIdx)  or ''):gsub('%s+$', '');
   ```
   (The `gsub` trims DAT padding spaces; `profiles/subjob_features:398-413` uses the same trim helper.)

2. Rename every `ashita.tasks.once` to `ashita.tasks.oncef`.

---

## `addons/chhartarget/chhartarget.lua`

| Line | Call | Status |
|------|------|--------|
| 69 | `AshitaCore:GetMemoryManager()` | OK |
| 71-76 | `mm:GetTarget():GetTargetIndex(0/1)` with method-existence guards | OK |
| 84, 93 | `entity:GetHPPercent(index)` | OK (`checkmate` and chains both use the per-entity HPP) |
| 148-150 | `mm:GetTarget()` / `tgt:GetTargetIndex(0)` | OK |
| 215 | `AshitaCore:GetMemoryManager():GetParty()` | OK |
| 387-391 | `player.GetMainJob` / `player.GetSubJob` via pcall | OK |

No wrong calls spotted. Defensive `pcall + method-presence` pattern is overkill
but harmless.

---

## `addons/rechhar/rechhar.lua`

| Line | Call | Status |
|------|------|--------|
| 67-68 | `GetParty()` / `GetEntity()` | OK |
| 154-156 | `entMgr`, `GetMemberTargetIndex(0)` | OK |
| 158 | `entMgr:GetLocalHeading(idx)` | **UNVERIFIED** | Plausible — IEntity exposes `GetLocalPositionX/Y/Z`, so a parallel `GetLocalHeading` is consistent with the API shape, but it's not in any of the four sampled addons. Confirm against `docs.ashitaxi.com` or a quick in-game test before relying on the value for anything beyond debug output. |

---

## `profiles/_template/subjob_features.lua`

| Line | Call | Status |
|------|------|--------|
| 411-412 | `player:GetMainJob()` + `GetString('jobs.names_abbr', pid)` | OK — this is the pattern chharburst should copy |
| 417 | `party:GetMemberTargetIndex(0)` | OK |
| 420-429 | `party:GetMemberTP(0)` (self-TP via IParty) | OK — correct replacement for the earlier hallucinated `GetMainJobTP` |
| 431-432 | `party:GetMemberHPPercent(0)` / `GetMemberMPPercent(0)` | OK |
| 437-442 | iterate `player:GetStatusIcon(i)` for i=0..31 | **UNVERIFIED** | Chains and checkmate both walk `player:GetBuffs()` (returns the buff array directly) instead. `GetStatusIcon(i)` may well exist on Ashita's IPlayer, but we have no sampled addon that uses it. **Safer rewrite** mirrors chains:314 / checkmate player:175: `for _, id in pairs(player:GetBuffs()) do if (id == target) then return true; end end`. |
| 433-435 | `gData.GetPlayer().Status` / `.IsMoving` | OK (LuAshitacast API) — not Ashita API, lives in the LAC addon context. |

---

## `addons/chharcontrol/chharcontrol.lua`

| Line | Call | Status |
|------|------|--------|
| 168-170 | `GetPlayer():GetMainJob() == 18` (PUP) | OK |
| 176-186 | `mm`, `mm:GetPlayer()`, `GetResourceManager():GetItemById(id)` | OK |

No wrong calls.

---

## `addons/chharmaton/chharmaton.lua` (ChharLAC copy)

Confirmed-identical API surface to the PhoenixXI/chharmaton reference. All
sampled calls (lines 72-96, including the `pcall` wrappers around
`player:GetMainJob` / `GetSubJob`) are OK.

---

## Summary — fixes required before next ship

1. **chharburst** — `GetJobByIndex` / `.NameAbbr3` doesn't exist. Replace
   with `GetString('jobs.names_abbr', id)` plus trim.
2. **chharburst** — `ashita.tasks.once` → `ashita.tasks.oncef`. Without this,
   the cast delay silently collapses to 0.
3. **subjob_features.hasBuff** — switch from unverified `GetStatusIcon` loop
   to the sampled `GetBuffs()` loop so we match the known-good pattern.
4. **rechhar heading usage** — confirm `GetLocalHeading` exists on this
   Ashita build before relying on it in logic (currently informational only,
   so low priority).

Everything else audited is consistent with `ASHITA_API.md`.
