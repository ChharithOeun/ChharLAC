# Ashita v4 API Reference (for Chharizard addons)

Canonical API cheat-sheet. **Look here before guessing.** All signatures were
verified against addons known to work on this server:

- `PhoenixXI/addons/chains/chains.lua` (2003 lines; packet 0x28 parsing, resource lookups)
- `PhoenixXI/addons/chharmaton/chharmaton.lua` (ArcaneAutomata fork; recast API)
- `PhoenixXI/addons/equipmon/equipmon.lua`, `craftbook/*`, `cor-tracker/*`
- `ext/checkmate/checkmate/core/player.lua`, `.../packets.lua`

If a method is not in this file, treat it as **unverified** until you see it
work in one of the sources above or at `https://docs.ashitaxi.com/`.

---

## `AshitaCore` — top-level singleton

| Call | Returns |
|------|---------|
| `AshitaCore:GetMemoryManager()` | IMemoryManager |
| `AshitaCore:GetResourceManager()` | IResourceManager |
| `AshitaCore:GetChatManager()` | IChatManager |
| `AshitaCore:GetPointerManager()` | IPointerManager (rarely needed) |
| `AshitaCore:GetInstallPath()` | string, trailing `\` (e.g. `C:\Ashita4\`) |

Standard addon path idiom (used by craftbook, chhartarget, chharcontrol):

```lua
local dir = ('%sconfig\\addons\\%s\\'):fmt(AshitaCore:GetInstallPath(), addon.name);
```

Addon source directory is `<install>\addons\<name>\`.

---

## IMemoryManager — `AshitaCore:GetMemoryManager()`

| Call | Returns |
|------|---------|
| `:GetPlayer()` | IPlayer |
| `:GetParty()` | IParty |
| `:GetEntity()` | IEntity |
| `:GetTarget()` | ITarget |
| `:GetRecast()` | IRecast |
| `:GetInventory()` | IInventory |
| `:GetAutoFollow()` | IAutoFollow (chharmaton:427) |

### IPlayer — `GetMemoryManager():GetPlayer()`

Confirmed getters (checkmate/core/player.lua, chharmaton, chains):

- `:GetMainJob()` / `:GetMainJobLevel()` → job id (0..23), level
- `:GetSubJob()`  / `:GetSubJobLevel()`
- `:GetMP()` → current MP (**chains:505, chharburst uses this**)
- `:GetHPMax()` → base HP max (player struct)
- `:GetStat(index)` / `:GetStatModifier(index)` → base/modifier stat values
- `:GetCombatSkill(skill_id)` → returns a struct with `:GetSkill()`
- `:GetBuffs()` → `uint16[]` of status effect ids, 32 slots (`chains:314`, `checkmate player:175`). Terminator / empty slots are `0` or `0xFF`.
- `:GetStatusIcon(i)` → used in `profiles/subjob_features.lua:440` to walk buff icons (0..31). **Alternative to GetBuffs.** Unverified whether both exist on all Ashita builds; `GetBuffs` is safer — chains and checkmate both use it.
- `:HasSpell(spellIndex)` → bool (`checkmate player:420`, `chains:551`)
- `:HasSpellData()` → bool — must return true before `HasSpell` is meaningful
- `:HasAbility(abilityId)` → **unverified** — not seen in any sampled addon. Prefer looking the ability up in resources + checking recast.

**DOES NOT EXIST on IPlayer:**
- `:GetTP()` — TP is **not** on IPlayer. Use `IParty:GetMemberTP(0)` (see below).
- `:GetMainJobTP()` — not a real method. Previously hallucinated.
- `:GetHP()` / `:GetHPP()` — not on IPlayer; use IParty.
- `:HasBuff(id)` — not real. Walk `GetBuffs()` yourself, or walk `GetStatusIcon(0..31)`.

### IParty — `GetMemoryManager():GetParty()`

The party struct holds **your own live HP / MP / TP** (slot 0) **and** every
visible party/alliance member (slots 1..17).

| Call | Returns |
|------|---------|
| `:GetMemberServerId(slot)` | server/account id (0 if empty) |
| `:GetMemberTargetIndex(slot)` | entity-table index (used with IEntity) |
| `:GetMemberName(slot)` | string |
| `:GetMemberHP(slot)` / `:GetMemberHPPercent(slot)` | current HP / 0..100 |
| `:GetMemberMP(slot)` / `:GetMemberMPPercent(slot)` | current MP / 0..100 |
| `:GetMemberTP(slot)` | current TP (0..3000). **This is where self-TP lives.** |
| `:GetMemberZone(slot)` | zone id |

Slot layout: 0 is you, 1-5 are your party, 6-11 alliance 1, 12-17 alliance 2.

### IEntity — `GetMemoryManager():GetEntity()`

Indexed by entity index (0..0x8FF). Slot 0 is you (same as
`GetParty():GetMemberTargetIndex(0)`).

| Call | Returns |
|------|---------|
| `:GetName(idx)` | string |
| `:GetServerId(idx)` | uint32 (0 if slot empty) |
| `:GetTargetIndex(idx)` | the entity's own index (useful for party look-up) |
| `:GetHPPercent(idx)` | 0..100 |
| `:GetClaimStatus(idx)` | server-id of the player/party that has claim (0 = unclaimed) |
| `:GetLocalPositionX(idx)` / `:GetLocalPositionY(idx)` / `:GetLocalPositionZ(idx)` | floats |
| `:GetLocalHeading(idx)` | radians |

### ITarget — `GetMemoryManager():GetTarget()`

| Call | Returns |
|------|---------|
| `:GetTargetIndex(0)` | main target entity index (0 = none) |
| `:GetTargetIndex(1)` | sub target entity index |
| `:GetIsSubTargetActive()` | 1 if sub-target cursor is up |
| `:GetServerId(0)` | main target server id (`chains:1774`) |

### IRecast — `GetMemoryManager():GetRecast()`

**Critical gotcha:** the ability-timer API is indexed by **slot (0..31), not by
ability id**. The slot holds a `RecastTimerId` that you match against
`resource.RecastTimerId`.

| Call | Returns |
|------|---------|
| `:GetAbilityTimer(slot)` | ticks remaining (60 per second) |
| `:GetAbilityTimerId(slot)` | the recast timer id currently in that slot (0 = empty) |
| `:GetSpellTimer(spellId)` | ticks remaining for spell (spell recast is id-indexed, not slot-indexed) |

Correct ability recast lookup (from chharmaton:494-511):

```lua
local resource = AshitaCore:GetResourceManager():GetAbilityById(abilityId);
if (resource == nil) then return 0; end
local recasts = AshitaCore:GetMemoryManager():GetRecast();
for slot = 0, 31 do
    if (recasts:GetAbilityTimerId(slot) == resource.RecastTimerId) then
        return math.max(0, recasts:GetAbilityTimer(slot) / 60);  -- seconds
    end
end
return 0;
```

### IInventory — `GetMemoryManager():GetInventory()`

| Call | Returns |
|------|---------|
| `:GetEquippedItem(slot)` | `{ Index = containerAndSlot }` where high byte = container, low byte = slot |
| `:GetContainerItem(container, slot)` | item instance `{ Id, Count, ... }` |

Pattern (checkmate player:114-120):

```lua
local eq  = inv:GetEquippedItem(slot);
local item = inv:GetContainerItem(bit.rshift(eq.Index, 8), bit.band(eq.Index, 0xFF));
```

---

## IResourceManager — `AshitaCore:GetResourceManager()`

Resource DAT lookups.

| Call | Returns |
|------|---------|
| `:GetSpellByName(name, lang)` | ISpell (lang: 0 = EN) |
| `:GetSpellById(id)` | ISpell |
| `:GetAbilityByName(name, lang)` | IAbility |
| `:GetAbilityById(id)` | IAbility |
| `:GetItemByName(name, lang)` | IItem |
| `:GetItemById(id)` | IItem |
| `:GetString(table, index)` | string from a DAT string table |

Known string tables: `'buffs.names'`, `'jobs.names'`, `'jobs.names_abbr'`
(chains:318, 388). Use the `GetString('jobs.names_abbr', id)` pattern to get
the three-letter job name — **not** a nonexistent `GetJobByIndex`.

### Resource struct fields (ISpell / IAbility / IItem)

Verified from chains, chharmaton, equipmon, craftbook:

- `.Index` — resource index (same number you pass to `HasSpell`)
- `.Id` — spell / ability / item id (`chains:1203+`)
- `.Name` — `string[]`, indexed by language slot (`.Name[1]` is EN) (equipmon:211+, craftbook/db.lua:474)
- `.LevelRequired` — `int[]`, indexed by **job id**; `-1` or `0` for jobs that can't learn it. Used in chharburst:185-186.
- `.RecastTimerId` — for abilities; the slot id used by IRecast (chharmaton:506)
- `.ManaCost`, `.CastTime`, `.RecastTime`, `.Skill`, `.Element` — present on ISpell; not all verified by name in sampled sources, treat exact names as **unverified** unless you see them used.

---

## IChatManager — `AshitaCore:GetChatManager()`

| Call | Effect |
|------|--------|
| `:QueueCommand(mode, command)` | queue a game command (mode `1` = default, send to game as if typed) |
| `:Write(mode, flag, msg)` | print to chat log (unverified exact signature on all builds) |

Addons normally use `print(chat.header(addon.name):append(...))` for addon
output; `QueueCommand` is reserved for *issuing* commands (`/ma`, `/console`,
etc.).

---

## Ashita library — `ashita.*`

### `ashita.events.register(event, callback_id, fn)`

Confirmed events (chains, chharmaton):

| Event | `e` shape |
|-------|-----------|
| `'load'` | no args |
| `'unload'` | no args |
| `'command'` | `e.command` (full string), `e.injected` (bool), `e.blocked` (settable) |
| `'packet_in'` | `e.id`, `e.size`, `e.data` (string), `e.data_raw` (FFI ptr), `e.data_modified`, `e.data_modified_raw`, `e.chunk_size`, `e.chunk_data`, `e.chunk_data_raw`, `e.injected`, `e.blocked` (settable) |
| `'packet_out'` | same shape as packet_in |
| `'text_in'` / `'text_out'` | `e.message`, `e.mode`, `e.blocked` |
| `'d3d_present'` | no args; called every frame (use for ImGui + polling) |
| `'key'` / `'mouse'` | input events (shape unverified in sampled sources) |

### `ashita.bits`

- `ashita.bits.unpack_be(raw, byte_offset, bit_offset, length)` — big-endian bitfield from `e.data_raw` (chains:1307, 1426; checkmate packets:159).
- `ashita.bits.unpack_le(...)` — little-endian equivalent (not used by sampled addons but documented in Ashita API).

Common 0x28 (action) bit offsets, verified in checkmate `packets.lua`:

| Field | Bit offset | Width |
|-------|-----------|-------|
| actor id | 40 | 32 |
| target count | 72 | 6 |
| category (action type 1..15) | 82 | 4 |
| action id | 86 | 32 |
| first target block | 150 | 36 bits header, variable result rows (85 + 1 + optional 37 + 1 + optional 34) |

### `ashita.tasks` — **gotcha**

The confirmed function name is **`ashita.tasks.oncef(delay, fn)`** — note
the `f` suffix. equipmon:587, craftbook/window.lua:83 use it.

`ashita.tasks.once(...)` as written in chharburst is **unverified / probably
wrong**. Fix to `oncef`.

Other scheduling functions (`.repeating`, `.schedule`) exist in some Ashita
builds but were not seen in sampled addons — **unverified**.

### `ashita.settings`

Used for JSON-schema settings persistence. See chains settings module. Not
re-documented here — read `chains.lua` lines 1-100 and 1375-1385 for the
canonical pattern.

### `ashita.memory`

- `ashita.memory.read_uint32(ptr)` — chains:487

### ImGui bindings

Available as `imgui.*`. Full binding list is documented at
`https://docs.ashitaxi.com/`. Chars and chharmaton both call e.g.
`imgui.Begin`, `imgui.Text`, `imgui.SliderFloat`, `imgui.End`. Treat anything
not seen in a sampled addon as unverified until confirmed from the docs.

---

## Common pitfalls

1. **TP lives on IParty, not IPlayer.** `GetMemberTP(0)` for self.
2. **Ability recast is indexed by slot (0..31), not ability id.** Walk the
   slots and match `GetAbilityTimerId(slot) == resource.RecastTimerId`.
3. **Spell recast IS indexed by spell id.** `GetSpellTimer(spellId)`.
4. **`GetBuffs()` returns a buffer with sentinel 0 / 0xFF.** Don't assume
   32 valid entries.
5. **`ashita.tasks.oncef`**, not `once`.
6. **Resource `.Name` is an array keyed by language slot.** `.Name[1]` is
   English. Don't index with `0`.
7. **`.LevelRequired` is keyed by job id**, and may be `-1` or `0` for jobs
   that can't learn the spell — check `> 0` before comparing.
8. **Addon paths use backslashes** on Windows: `AshitaCore:GetInstallPath()`
   returns a trailing-backslash string, so `..` concat works but `/` won't
   survive on Windows file APIs.
