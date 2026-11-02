# Migrating a job to lac_core.lua

`lac_core.lua` is the Mote-style engine for ChharLAC. This doc shows
how to migrate an existing job (that uses `subjob_features.lua`)
to also use Core. Both can coexist on the same profile.

## 1. Add the require

At the top of `<JOB>.lua`, alongside the existing Sub require:

```lua
local Sub  = dofile(AshitaCore:GetInstallPath()
    .. 'config/addons/luashitacast/_template/subjob_features.lua');
local Core = dofile(AshitaCore:GetInstallPath()
    .. 'config/addons/luashitacast/_template/lac_core.lua');
```

## 2. Rename sets for state-aware resolution

The resolver expects a specific shape. Rename as you touch each set.

| Old (flat) | New (state-aware) | Notes |
|---|---|---|
| `sets.Idle = { ... }` | `sets.Idle = { ... }` + optional `sets.Idle.Field`, `sets.Idle.Town`, `sets.Idle.DT` | Base keys apply always; sub-key wins when IdleMode matches |
| `sets.TP = { ... }` | `sets.TP = { ... }` + optional `sets.TP.Acc`, `sets.TP.Att`, `sets.TP.MaxAcc` | Overlays stacked on OffenseMode |
| `sets.WS[name] = { ... }` | unchanged, plus optional `sets.WS.Acc`, `sets.WS.Mod` | Overlays on WeaponskillMode |
| `sets.Precast.FastCast` | unchanged | Base for ALL spells |
| (none) | `sets.Precast['Impact']`, `sets.Precast['Cure']` | Per-spell precast overlays |
| (none) | `sets.Precast['Enfeebling Magic']` | Per-skill precast overlays |
| `sets.Midcast.Cure`, etc. | unchanged | Resolver already walks skill-then-name |
| (none) | `sets.Midcast.MB` | CastingMode='MB' overlay |
| (none) | `sets.Midcast.SIRD` | Auto-overlay when hit mid-cast |
| (none) | `sets.Defense.PDT`, `sets.Defense.MDT` | DefenseMode overlays |
| (none) | `sets.Hybrid.PDT`, `sets.Hybrid.Reraise` | HybridMode TP overlays |
| (none) | `sets.Pet[ability]` | Pet-ability swap sets |

## 3. Replace handlers with Core resolvers

```lua
-- OLD
profile.HandleDefault = function()
    gFunc.EquipSet(sets.Idle);
    if (gData.GetPlayer().IsMoving) then gFunc.EquipSet(sets.Movement); end
    Sub.tick(true);
end
profile.HandleEngaged = function() gFunc.EquipSet(sets.TP); Sub.tick(true); end
profile.HandlePrecast = function() gFunc.EquipSet(sets.Precast.FastCast); end
profile.HandleMidcast = function()
    local sp = gData.GetAction();
    if (sp.Name:contains('Cure')) then gFunc.EquipSet(sets.Midcast.Cure);
    -- (etc.)
    end
end
profile.HandleWeaponskill = function()
    local ws = gData.GetAction().Name;
    if (sets.WS[ws]) then gFunc.EquipSet(sets.WS[ws]);
    else gFunc.EquipSet(sets.WS.Default); end
end
```

```lua
-- NEW (Core-driven)
profile.HandleDefault = function()
    gFunc.EquipSet(Core.resolveIdle(sets));
    Sub.tick(true);
end
profile.HandleEngaged = function()
    gFunc.EquipSet(Core.resolveTP(sets));
    Sub.tick(true);
end
profile.HandlePrecast = function()
    local sp = gData.GetAction();
    gFunc.EquipSet(Core.resolvePrecast(sets, sp));
    Core.beginCast(sets);
end
profile.HandleMidcast = function()
    local sp = gData.GetAction();
    gFunc.EquipSet(Core.resolveMidcast(sets, sp));
end
profile.HandleWeaponskill = function()
    local ws = gData.GetAction().Name;
    gFunc.EquipSet(Core.resolveWS(sets, ws));
end
```

## 4. Pet-ability swaps (pet jobs only)

```lua
-- Register during OnLoad; unregister in OnUnload.
profile.OnLoad = function()
    gSettings.AllowAddSet = true;
    Core.registerPetHandler(profile);
    Sub.echo('[Chharizard PUP] loaded.');
end
profile.OnUnload = function()
    Core.unregisterPetHandler();
    Sub.echo('[Chharizard PUP] unloaded.');
end

-- Called when your pet uses any action.
profile.HandlePetAbility = function(abilityName, abilityId)
    local s = sets.Pet and sets.Pet[abilityName];
    if (s) then gFunc.EquipSet(s); end
end
```

## 5. Route /lac commands to Core first

```lua
profile.HandleCommand = function(args)
    if (#args < 1) then return; end
    if (Core.handleCommand(args)) then return; end  -- NEW: Core first
    if (Sub.handleCommand(args)) then return; end
    if (args[1]:lower() == 'debug') then Sub.debug(); end
end
```

Now you can run in-game:
```
/lac mode               print current modes
/lac mode offense       cycle OffenseMode
/lac mode offense Acc   set OffenseMode explicitly
/lac mode defense PDT   turn on PDT overlay
/lac mode idle Town     switch to Town idle
/lac server             check which server/automation state
```

## 6. Automation safety (Phoenix/Horizon only)

Replace raw QueueCommand calls with `Core.auto(cmd)`:

```lua
-- OLD (always runs -- bannable on Aurora)
AshitaCore:GetChatManager():QueueCommand(1, '/ma "Cure IV" <stpc>');

-- NEW (gated by Core.automationAllowed)
Core.auto('/ma "Cure IV" <stpc>');
```

LINT will catch raw QueueCommand calls that bypass the gate.

## 7. Fast Cast patterns

Fast Cast is first-class. Three layers:

```lua
sets.Precast = {
    FastCast = {               -- 1. BASE: applied to every spell precast
        Ear1="Loquacious Earring",
        Body="Agwu's Robe",
        -- (all FC gear)
    },
    ['Enfeebling Magic'] = {   -- 2. SKILL overlay (per Spell.Skill)
        Legs="Lethargy Fuseau",
    },
    ['Impact'] = {             -- 3. NAME overlay (per Spell.Name)
        Head="Twilight Cloak",
    },
};
```

Resolver walks: FastCast -> Skill overlay -> Name overlay. Later wins.

## 8. SIRD -- Spell Interruption Rate Down

Define `sets.Midcast.SIRD` and the resolver auto-overlays it when the
engine detects damage while casting. No per-job wiring needed beyond the
set itself:

```lua
sets.Midcast = {
    SIRD = {                   -- Resolver auto-swaps mid-cast if hit.
        Head="Nahtirah Hat",
        Ring1="Evanescence Ring",
        -- (SIRD-focused pieces, often with Enmity- too)
    },
    -- ... normal Cure/Enhancing/etc. sets
};
```

**Note:** the SIRD damage listener itself needs a one-time packet hook
registration. That lives in the next phase (Phase 2) when we build the
first job on top of Core. For now, defining the SIRD set is harmless and
future-ready.
