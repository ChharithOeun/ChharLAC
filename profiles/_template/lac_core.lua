-- lac_core.lua -- shared Mote-style engine for ChharLAC profiles.
--
-- Design goals:
--   * Mote-equivalence: state machine for Offense/Defense/Idle/WS/Hybrid/Casting/Pet
--     modes, with cycle commands and automatic set resolution.
--   * Fast Cast as a first-class concept: sets.Precast.FastCast is the base
--     for every spell; per-spell overlays via sets.Precast[spellName] win.
--   * SIRD (Spell Interruption Rate Down) auto-overlay when damaged mid-cast.
--   * Pet-ability dispatch so pet jobs (PUP/BST/SMN) can swap gear when the
--     pet uses a specific action.
--   * Server guardrail: Phoenix/Horizon run full auto; Aurora/retail silently
--     drop every /ma and /ja we would otherwise queue. One switch.
--
-- Non-goals:
--   * Replacing subjob_features.lua. This file is additive. Existing jobs that
--     use subjob_features keep working untouched. Jobs opt in to Core when the
--     user migrates them -- see MIGRATION.md.
--   * Any gear data. Core is behavior; sets live in <JOB>.lua.
--
-- Load pattern (in <JOB>.lua):
--     local Core = dofile(AshitaCore:GetInstallPath()
--         .. 'config/addons/luashitacast/_template/lac_core.lua');

local Core = {};

-- ---------------------------------------------------------------------------
-- Server config
-- ---------------------------------------------------------------------------
-- Deploy script bakes this via a sed replacement based on --Server flag.
Core.server = 'phoenix';
Core.automationAllowed = (Core.server ~= 'aurora' and Core.server ~= 'retail');

-- ---------------------------------------------------------------------------
-- State machine (Mote-style)
-- ---------------------------------------------------------------------------
Core.state = {
    OffenseMode     = 'Normal',   -- Normal / Acc / Att / MaxAcc
    DefenseMode     = 'None',     -- None / PDT / MDT
    IdleMode        = 'Field',    -- Field / Town / DT / Refresh
    WeaponskillMode = 'Normal',   -- Normal / Acc / Mod
    HybridMode      = 'Normal',   -- Normal / PDT / Reraise
    CastingMode     = 'Normal',   -- Normal / Resistant / MB
    PetMode         = 'Normal',   -- Normal / Acc / Att / MDT (pet jobs)
};

-- What each mode can cycle through. Jobs can override by assigning
-- Core.modeCycles.OffenseMode = { ... } in OnLoad.
Core.modeCycles = {
    OffenseMode     = { 'Normal','Acc','Att','MaxAcc' },
    DefenseMode     = { 'None','PDT','MDT' },
    IdleMode        = { 'Field','Town','DT','Refresh' },
    WeaponskillMode = { 'Normal','Acc','Mod' },
    HybridMode      = { 'Normal','PDT','Reraise' },
    CastingMode     = { 'Normal','Resistant','MB' },
    PetMode         = { 'Normal','Acc','Att','MDT' },
};

local function cap1(s) return s:sub(1,1):upper() .. s:sub(2):lower(); end

-- Cycle to next value: /lac mode offense
-- Explicit set:        /lac mode offense Acc
function Core.cycleMode(modeName, explicit)
    modeName = cap1(modeName) .. 'Mode';
    if (Core.state[modeName] == nil) then
        Core.echo('unknown mode: '..modeName); return;
    end
    if (explicit) then
        -- validate against cycle list (case-insensitive)
        local ok = nil;
        for _,v in ipairs(Core.modeCycles[modeName]) do
            if (v:lower() == explicit:lower()) then ok = v; break; end
        end
        if (not ok) then
            Core.echo('bad value for '..modeName..': '..explicit); return;
        end
        Core.state[modeName] = ok;
    else
        local cycle = Core.modeCycles[modeName];
        local cur = Core.state[modeName];
        local nextIdx = 1;
        for i,v in ipairs(cycle) do
            if (v == cur) then nextIdx = (i % #cycle) + 1; break; end
        end
        Core.state[modeName] = cycle[nextIdx];
    end
    Core.echo(modeName..' -> '..Core.state[modeName]);
end

function Core.printModes()
    Core.echo('---- current modes ----');
    for k,v in pairs(Core.state) do Core.echo('  '..k..' = '..v); end
end

-- ---------------------------------------------------------------------------
-- Set helpers
-- ---------------------------------------------------------------------------
-- Shallow merge: `over` keys win. Returns a NEW table.
function Core.mergeSets(base, over)
    local out = {};
    if (base) then for k,v in pairs(base) do out[k] = v; end end
    if (over) then for k,v in pairs(over) do out[k] = v; end end
    return out;
end

-- Fold several sets left-to-right (later wins). Nil entries skipped.
function Core.layer(...)
    local out = {};
    for _,s in ipairs({...}) do
        if (type(s) == 'table') then
            for k,v in pairs(s) do out[k] = v; end
        end
    end
    return out;
end

-- ---------------------------------------------------------------------------
-- Fast Cast / Precast resolver
-- ---------------------------------------------------------------------------
-- sets.Precast.FastCast is the base. Per-spell overlays via
-- sets.Precast[spell.Name] win on top. Jobs can also define
-- sets.Precast[spell.Skill] for skill-wide overlays (e.g., 'Enfeebling Magic').
function Core.resolvePrecast(sets, spell)
    if (not sets.Precast) then return {}; end
    local layers = { sets.Precast.FastCast };
    if (spell and spell.Skill and sets.Precast[spell.Skill]) then
        table.insert(layers, sets.Precast[spell.Skill]);
    end
    if (spell and spell.Name and sets.Precast[spell.Name]) then
        table.insert(layers, sets.Precast[spell.Name]);
    end
    return Core.layer(table.unpack(layers));
end

-- Midcast resolver with SIRD and CastingMode overlays.
-- sets.Midcast base, then sets.Midcast[spell.Skill], then sets.Midcast[spell.Name],
-- then CastingMode overlay (e.g., sets.Midcast.MB when CastingMode='MB').
function Core.resolveMidcast(sets, spell)
    if (not sets.Midcast) then return {}; end
    local layers = {};
    if (sets.Midcast.Default)                     then table.insert(layers, sets.Midcast.Default); end
    if (spell and sets.Midcast[spell.Skill])      then table.insert(layers, sets.Midcast[spell.Skill]); end
    if (spell and sets.Midcast[spell.Name])       then table.insert(layers, sets.Midcast[spell.Name]); end
    if (Core.state.CastingMode ~= 'Normal'
        and sets.Midcast[Core.state.CastingMode]) then table.insert(layers, sets.Midcast[Core.state.CastingMode]); end
    return Core.layer(table.unpack(layers));
end

-- ---------------------------------------------------------------------------
-- Idle resolver
-- ---------------------------------------------------------------------------
-- Layers:
--   sets.Idle (base, pure equipment keys only)
--   sets.IdleStates[IdleMode]  -- e.g., sets.IdleStates.Field / .Town / .DT
--   sets.Defense[DefenseMode]  -- when DefenseMode != None
--   sets.Movement              -- when player is moving
function Core.resolveIdle(sets)
    local layers = { sets.Idle };
    if (sets.IdleStates and sets.IdleStates[Core.state.IdleMode]) then
        table.insert(layers, sets.IdleStates[Core.state.IdleMode]);
    end
    if (Core.state.DefenseMode ~= 'None'
        and sets.Defense and sets.Defense[Core.state.DefenseMode]) then
        table.insert(layers, sets.Defense[Core.state.DefenseMode]);
    end
    local set = Core.layer(table.unpack(layers));
    local okP, ply = pcall(function() return gData.GetPlayer(); end);
    if (okP and ply and ply.IsMoving and sets.Movement) then
        set = Core.layer(set, sets.Movement);
    end
    return set;
end

-- TP resolver with OffenseMode + DefenseMode + HybridMode overlays.
-- OffenseMode overlays live in sets.TPModes (NOT nested in sets.TP, same
-- reason as IdleStates -- would leak as fake slot keys to Equip).
function Core.resolveTP(sets)
    local layers = { sets.TP };
    if (sets.TPModes and sets.TPModes[Core.state.OffenseMode]) then
        table.insert(layers, sets.TPModes[Core.state.OffenseMode]);
    end
    if (Core.state.HybridMode ~= 'Normal'
        and sets.Hybrid and sets.Hybrid[Core.state.HybridMode]) then
        table.insert(layers, sets.Hybrid[Core.state.HybridMode]);
    end
    if (Core.state.DefenseMode ~= 'None'
        and sets.Defense and sets.Defense[Core.state.DefenseMode]) then
        table.insert(layers, sets.Defense[Core.state.DefenseMode]);
    end
    return Core.layer(table.unpack(layers));
end

-- Weaponskill resolver. sets.WS.Default + sets.WS[wsName] + mode overlay.
function Core.resolveWS(sets, wsName)
    local layers = { sets.WS and sets.WS.Default };
    if (wsName and sets.WS and sets.WS[wsName]) then
        table.insert(layers, sets.WS[wsName]);
    end
    if (Core.state.WeaponskillMode ~= 'Normal'
        and sets.WS and sets.WS[Core.state.WeaponskillMode]) then
        table.insert(layers, sets.WS[Core.state.WeaponskillMode]);
    end
    return Core.layer(table.unpack(layers));
end

-- ---------------------------------------------------------------------------
-- SIRD hook (damage-while-casting -> swap to sets.Midcast.SIRD)
-- ---------------------------------------------------------------------------
-- Casting status is tracked by HandlePrecast/HandleMidcast callers:
--     Core.beginCast() in HandlePrecast
--     Core.endCast()   on cast completion/interrupt (hooked in packet 0x28)
-- Damage detection: when player receives melee/physical/magical damage packet
-- while Core.isCasting is true, we overlay sets.Midcast.SIRD on the active set.
Core.isCasting = false;
Core._castSets  = nil;   -- sets reference stored by beginCast

function Core.beginCast(sets)
    Core.isCasting = true;
    Core._castSets = sets;
end
function Core.endCast()
    Core.isCasting = false;
    Core._castSets = nil;
end

-- Called from packet listener in profile OnLoad (see MIGRATION.md).
function Core.onDamageTaken()
    if (not Core.isCasting) then return; end
    if (not Core._castSets) then return; end
    if (Core._castSets.Midcast and Core._castSets.Midcast.SIRD) then
        gFunc.EquipSet(Core._castSets.Midcast.SIRD);
    end
end

-- ---------------------------------------------------------------------------
-- Pet-ability dispatch
-- ---------------------------------------------------------------------------
-- Hooks packet 0x28 (action) where actor is the player's pet. Fires:
--     profile.HandlePetAbility(abilityName, abilityId)
-- Set up by Core.registerPetHandler(profile) in OnLoad.
local activePetHandler = nil;
function Core.registerPetHandler(profile)
    activePetHandler = profile;
end
function Core.unregisterPetHandler()
    activePetHandler = nil;
end

-- Called from the packet listener (see MIGRATION.md). The listener itself
-- is installed once, in a profile's OnLoad, via a shared util.
function Core.dispatchPetAbility(abilityName, abilityId)
    if (not activePetHandler) then return; end
    if (type(activePetHandler.HandlePetAbility) ~= 'function') then return; end
    activePetHandler.HandlePetAbility(abilityName, abilityId);
end

-- ---------------------------------------------------------------------------
-- Server guardrail: automation gate
-- ---------------------------------------------------------------------------
-- Jobs call Core.auto('/ma "Cure IV" <me>') instead of raw QueueCommand.
-- On Aurora/retail builds, this is a no-op; display-only features still work.
function Core.auto(cmd)
    if (not Core.automationAllowed) then return; end
    AshitaCore:GetChatManager():QueueCommand(1, cmd);
end

-- ---------------------------------------------------------------------------
-- Logging
-- ---------------------------------------------------------------------------
function Core.echo(fmt, ...)
    local msg = (select('#', ...) > 0) and string.format(fmt, ...) or fmt;
    print(string.char(0x1F, 220) .. '[LAC] ' .. msg);
end

-- ---------------------------------------------------------------------------
-- Command handler. Jobs route /lac ... commands into Core.handleCommand first.
-- Returns true if consumed.
-- ---------------------------------------------------------------------------
-- Supported:
--   /lac mode              -- print current modes
--   /lac mode <name>       -- cycle (name = offense/defense/idle/weaponskill/hybrid/casting/pet)
--   /lac mode <name> <val> -- set explicit value
--   /lac server            -- print current server + automation state
function Core.handleCommand(args)
    if (#args < 1) then return false; end
    local cmd = args[1]:lower();

    if (cmd == 'mode' or cmd == 'modes') then
        if (not args[2]) then Core.printModes(); return true; end
        Core.cycleMode(args[2], args[3]);
        return true;
    end
    if (cmd == 'server') then
        Core.echo('server = %s (automation %s)',
            Core.server, Core.automationAllowed and 'ALLOWED' or 'DISABLED');
        return true;
    end
    return false;
end

return Core;
