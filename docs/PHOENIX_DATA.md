# Phoenix / LandSandBoat Server Data Reference

Phoenix (`https://github.com/phoenixffxi/Phoenix`, branch `beta`) is a fork of
LandSandBoat (`https://github.com/LandSandBoat/server`). The server-side game
data our addons depend on lives in that tree. **When our client-side data
disagrees with Phoenix source, Phoenix wins** — the client parses what the
server sends.

The repo layout, verified from the Phoenix root listing:
`cmake/  data/  docker/  docs/  ext/  modules/  res/  scripts/  settings/  sql/  src/  tools/`

Everything we care about is under `scripts/`, `sql/`, and `src/map/packets/`.

---

## Scripts directory map

| Path | What's there |
|------|--------------|
| `scripts/zones/<ZoneName>/mobs/<MobName>.lua` | Per-mob definitions: HP mult, drops, respawn time, mob mods, `onMobSpawn`/`onMobDeath` hooks. **Authoritative for spawn type (lottery vs timed) and PH relationships** — look for `GetMobByID`/`DisallowRespawn`/`SetRespawnTime` patterns, and `scripts/zones/<Zone>/MobIDs.lua` for the id table. |
| `scripts/zones/<ZoneName>/MobIDs.lua` | Numeric mob id table for the zone (NM id ↔ PH id mapping) |
| `scripts/zones/<ZoneName>/npcs/` | NPC scripts |
| `scripts/zones/<ZoneName>/Zone.lua` | Zone-level hooks |
| `scripts/globals/spells/<school>/<spellname>.lua` | Per-spell scripts: `onMagicCastingCheck`, `onSpellCast`. MP cost / recast / cast time come from `sql/spell_list.sql`, not these scripts. |
| `scripts/globals/magic.lua` | Magic damage / resist formulas; element indices (`xi.element.FIRE = 1` …). |
| `scripts/globals/status.lua` | **`xi.effect.*` status effect ids** — e.g. `xi.effect.POISON = 6`, `xi.effect.PARALYSIS = 4`. This is the canonical source for the icon ids our profiles pass to `GetBuffs`/`GetStatusIcon`. |
| `scripts/globals/msg.lua` | Battle message ids. Skillchain closes are 288-301 (`xi.msg.basic.SKILLCHAIN_*`) and the retail Light/Darkness Lv.4 variants 767-770 — the exact table chharburst uses. |
| `scripts/globals/mobskills/<name>.lua` | **Every mob TP move**: shape (single / aoe / cone / conal with angle), range, modifiers. Look at the `onMobSkillCheck` / `onMobWeaponSkill` / `onMobWeaponSkillPrepare` headers. |
| `scripts/globals/weaponskills/<name>.lua` | Player WS scripts; retail element and skillchain property come from `sql/weapon_skills.sql`. |
| `scripts/globals/pets/` | Pet behavior |
| `scripts/globals/jobs/pup/` | Puppetmaster: automaton frames, attachments, maneuver effects. **Burden decay and overload threshold live here** — look for `automaton.lua`, `attachments/`, and the maneuver status effect handlers. |
| `scripts/globals/jobs/bst/` | Beastmaster: jug pet, charmed pet tables |
| `scripts/globals/skillchains.lua` | **Skillchain property tables**: which WS has which skillchain property (Transfixion, Compression, …) and which chain opens which. Our chharburst `SKILLCHAIN` table should match this. |
| `scripts/globals/items/<item>.lua` | Item usage scripts (enchantments, consumables). Stat tables live in `sql/item_*.sql`. |
| `scripts/globals/common.lua`, `scripts/globals/utils/*.lua` | Shared helpers |
| `sql/mob_droplist.sql`, `sql/mob_spawn_points.sql`, `sql/mob_groups.sql`, `sql/mob_pools.sql` | Spawn, drop, group tables. **Spawn point and respawn-type data is here** (groups table has `respawntime`; a 0 or lottery-flagged entry maps to PH-only spawn). |
| `sql/spell_list.sql` | Spell id → cast time, recast, MP cost, element, skill. |
| `sql/weapon_skills.sql` | WS id → element, skillchain property, animation. |
| `sql/mob_skills.sql` | Mob skill ids (joined with `mob_family_system`). |
| `src/map/packets/action.cpp` and `src/map/packets/action.h` | **Authoritative 0x28 action-packet layout.** When our bit offsets look wrong, read this. |
| `src/map/packets/message_basic.cpp` | 0x29 message packet; skillchain-close message numbers routed here. |
| `modules/` | Phoenix-specific tweaks on top of LSB base — **check this when retail docs and in-game behavior disagree.** |

---

## Phoenix-specific tweaks vs retail LSB

Phoenix branches `beta` off `LandSandBoat/server:base`. Phoenix-specific
modifications land in `modules/` (loaded at server start) and `settings/`.
When in doubt about a mechanic:

1. Check `modules/` for an override of the base behavior.
2. Check `settings/default/*.lua` for tuned numbers (EXP rates, drop rates,
   level cap). Era-specific caps (level 75 / Promathia-era NMs) live here.
3. `scripts/` is the base LSB logic; Phoenix inherits unless `modules/` says
   otherwise.

---

## Addon → Phoenix data mapping

| Addon | Phoenix data path | What it would settle |
|-------|-------------------|----------------------|
| `rechhar/data/abilities.lua` | `scripts/globals/mobskills/<name>.lua` + `sql/mob_skills.sql` | Authoritative range, shape (single / AoE / cone with angle), TP cost, modifier (STR/DEX/…) for every mob TP move. Our table should mirror `onMobSkill*` headers. |
| `chhartarget/ph_database.lua` | `scripts/zones/<Zone>/MobIDs.lua` + `scripts/zones/<Zone>/mobs/<NM>.lua` + `sql/mob_groups.sql` | Authoritative NM ↔ PH id mapping, spawn type (lottery / timed / forced-pop), respawn window. The NM lua's `onMobDeath` / `SetRespawnTime` is the ground truth; checkmate's PH tables stop at what the server-side NM lua declares. |
| `chharmaton` (burden / overload) | `scripts/globals/jobs/pup/automaton.lua` and friends under `scripts/globals/jobs/pup/` | Burden decay rate, overload threshold curve, cooldown on maneuvers after overload. The maneuver recast cooldown itself is on the ability (`scripts/globals/abilities/*maneuver*.lua`), not the burden logic. |
| `chharburst` | `scripts/globals/magic.lua`, `scripts/globals/status.lua`, `scripts/globals/msg.lua`, `sql/spell_list.sql` | (1) Element indices (1=Fire … 8=Dark); (2) burst message id (238) and skillchain close ids (288-301, 767-770 — already matched); (3) each burst spell's cast time / recast / MP cost / level requirement; (4) status effect ids for debuff detection. |

## Overlap with checkmate's data/zones

`ext/checkmate/checkmate/data/zones/` (42 MB) is a scrape of Phoenix-era mob
data: level ranges, aggro, true-sight, drop ids. **For addons that only need
level / aggro / drop info, that scrape is enough** — don't re-fetch Phoenix.

Where Phoenix adds data checkmate's zones scrape does not have:

- **Scripted NM pop conditions** (keyitem gates, triggers): only in
  `scripts/zones/<Zone>/mobs/<NM>.lua`.
- **TP move list per mob family**: checkmate stores `families` → general TP
  moves, but the per-mob `onMobSkillCheck` filtering (which family-member
  can/can't use a move) is only in Phoenix.
- **Burden / overload numbers**: not in checkmate at all; Phoenix only.
- **Skillchain property for a given WS**: checkmate has nothing; Phoenix
  `sql/weapon_skills.sql` is authoritative.

---

## Fetching Phoenix data without re-downloading the whole repo

Phoenix has 45k+ commits and is large. For reference work:

- Browse via `raw.githubusercontent.com/phoenixffxi/Phoenix/beta/<path>` to
  pull single files cheaply.
- For a zone's PH data: fetch `scripts/zones/<Zone>/mobs/<NM>.lua`,
  `scripts/zones/<Zone>/MobIDs.lua`, and the matching `sql/mob_groups.sql`
  rows (`grep -i '<NM name>'`).
- For a mob TP move: fetch `scripts/globals/mobskills/<name>.lua` — one file,
  usually under 100 lines.
- For status effect ids: `scripts/globals/status.lua` once, cache locally.
- For skillchain property tables: `scripts/globals/skillchains.lua` once.

If a data table in our repo gets rebuilt from Phoenix, note the Phoenix
commit SHA next to it so staleness is visible.
