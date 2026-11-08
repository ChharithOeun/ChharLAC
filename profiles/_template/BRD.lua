-- Chharizard BRD -- LAC profile (Core-driven, Mote-style)
--
-- Server: Phoenix / Horizon / Aurora (automation gated by Core.automationAllowed)
-- Era cap: ToAU (75) -- gear here is Phoenix/Horizon-appropriate.
--
-- Features:
--   * Mote-style modes: /lac mode offense|defense|idle|weaponskill|casting
--   * Idle sub-states: Field / Town / DT / Refresh
--   * Instrument table (Potency/Honor/Aria/Idle/TP/FastCast) selected per song
--     type -- modeled on Mirdain Windower pattern, adapted to era instruments.
--   * Fast Cast first-class: sets.Precast.FastCast base + per-skill overlays
--     ('Singing', 'Enfeebling Magic') + per-spell overlays.
--   * SIRD overlay (sets.Midcast.SIRD) auto-swaps when hit mid-cast.
--   * Instrument swap by song type (Wind / String / Lyre) in Range slot.
--
-- Rollback: cp _pre-core-backup/BRD.lua.bak over this file to restore.

local profile = {}; local sets = {}; profile.Sets = sets;
local Sub  = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/subjob_features.lua');
local Core = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/lac_core.lua');

-- ---------------------------------------------------------------------------
-- Instrument table (era-appropriate; LAC skips missing items silently)
-- ---------------------------------------------------------------------------
-- Instrument table. Current level: BRD 8 -- using starter instruments.
local Inst = {
    Wind     = "Cornette",                          -- March / Minuet / Madrigal
    String   = "Maple Harp",                          -- Ballad / Paeon / Requiem (same til higher-tier)
    Lyre     = "Cornette",                          -- Lullaby / fallback
    -- (future upgrades, uncomment as acquired)
    -- Wind    = "Faerie Piccolo",   -- lvl 50
    -- String  = "Mary's Horn",      -- lvl ~50
    -- Lyre    = "Angel Lyre",       -- lvl ~50
};

-- Runtime-togglable idle Range. Default = Cornette (no mid-song blink).
--   /lac fwd range <item>      -- swap (e.g. "/lac fwd range Animator")
--   /lac fwd range             -- show current
--   /lac fwd verbose on|off    -- echo swaps to chat (default: off)
local idleRange = "Cornette";
local verbose   = false;

-- ---------------------------------------------------------------------------
-- IDLE sets -- base + sub-states
-- ---------------------------------------------------------------------------
sets.Idle = {
    Head="Aoidos' Calot +1", Neck="Aoidos' Matinee", Ear1="Loquac. Earring", Ear2="Musical Earring",
    Body="Aoidos' Hongreline +2", Hands="Aoidos' Manchettes +2", Ring1="Sniper's Ring", Ring2="Star Ring",
    Back="Rainbow Cape", Waist="Corsette +1", Legs="Aoidos' Rhingrave +2", Feet="Aoidos' Cothurnes +2",
    Main="Joyeuse", Sub="Genbu's Shield",
    -- Range intentionally omitted here -- resolver injects idleRange below.
    Ammo="Clarus Stone",
};
-- Sub-states layer on top of Idle (separate table -- Core resolver reads here,
-- so sets.Idle stays pure equipment keys and EquipSet(sets.Idle) iterates clean).
sets.IdleStates = {
    Field   = {},
    Town    = { Body="Councilor's Garb" },                            -- CP+ in town (if owned)
    DT      = { Head="Gnadbhod's Helm", Body="Mekira-oi" },           -- -DT emphasis
    Refresh = { Neck="Twilight Torque", Body="Aoidos' Hongreline +2" },
};

-- Movement overlay (applied by resolver when IsMoving)
sets.Movement = { Feet="Rutter Sabatons" };

-- Defense overlays (applied when DefenseMode != None)
sets.Defense = {
    PDT = { Head="Gnadbhod's Helm", Body="Mekira-oi", Hands="Dusk Gloves +1", Legs="Byakko's Haidate" },
    MDT = { Head="Walahra Turban",  Neck="Twilight Torque", Body="Mekira-oi" },
};

-- ---------------------------------------------------------------------------
-- TP sets -- base + OffenseMode overlays
-- ---------------------------------------------------------------------------
sets.TP = {
    Head="Walahra Turban", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Suppanomimi",
    Body="Aoidos' Hongreline +2", Hands="Dusk Gloves", Ring1="Rajas Ring", Ring2="Sniper's Ring",
    Back="Cerberus Mantle", Waist="Swift Belt", Legs="Byakko's Haidate", Feet="Homam Gambieras",
    Main="Joyeuse", Sub="Genbu's Shield",
    -- Range intentionally omitted -- keep whatever idle resolved to.
};
-- OffenseMode overlays live in a sibling table (same reason as IdleStates).
sets.TPModes = {
    Acc    = { Neck="Peacock Charm", Ring1="Toreador's Ring", Legs="Enkidu's Subligar" },
    Att    = { Ring1="Flame Ring", Ring2="Ulthalam's Ring", Waist="Warwolf Belt" },
    MaxAcc = { Head="Optical Hat", Neck="Peacock Charm", Hands="Enkidu's Mittens", Ring1="Toreador's Ring", Ring2="Woodsman Ring" },
};

-- Hybrid overlays (toggled with /lac mode hybrid)
sets.Hybrid = {
    PDT     = { Head="Gnadbhod's Helm", Body="Mekira-oi" },
    Reraise = { Head="Twilight Helm", Body="Twilight Mail" },
};

-- ---------------------------------------------------------------------------
-- PRECAST -- Fast Cast base + skill/name overlays
-- ---------------------------------------------------------------------------
sets.Precast = {
    FastCast = {
        Head="Aoidos' Calot +1", Ear1="Loquac. Earring",
        Body="Aoidos' Hongreline +2", Hands="Aoidos' Manchettes +2",
        Legs="Aoidos' Rhingrave +2",
        -- Range omitted: don't swap during precast, let midcast handle it.
    },
    -- Per-skill overlay (walks spell.Skill):
    ['Singing']           = { Legs="Fili Rhingrave" },      -- +song precast if owned
    -- Per-spell overlays (walk spell.Name):
    ['Honor March']       = { Range="Marsyas" },
    ['Sleep']             = { Head="Nahtirah Hat" },
    ['Sleep II']          = { Head="Nahtirah Hat" },
};

-- ---------------------------------------------------------------------------
-- MIDCAST -- per-skill, per-name, SIRD, CastingMode overlays
-- ---------------------------------------------------------------------------
sets.Midcast = {
    Default = { Head="Aoidos' Calot +1", Body="Aoidos' Hongreline +2" },

    -- Per-skill (spell.Skill):
    ['Singing']            = { Head="Aoidos' Calot +1", Neck="Aoidos' Matinee",
                                Ear1="Musical Earring", Body="Aoidos' Hongreline +2",
                                Hands="Aoidos' Manchettes +2", Legs="Aoidos' Rhingrave +2",
                                Feet="Aoidos' Cothurnes +2" },
    ['Enfeebling Magic']   = { Neck="Uggalepih Pendant", Head="Nahtirah Hat" },
    ['Healing Magic']      = { Body="Aoidos' Hongreline +2" },

    -- Per-spell (spell.Name):
    ['Cure']               = { Body="Aoidos' Hongreline +2" },
    ['Cure II']            = { Body="Aoidos' Hongreline +2" },
    ['Cure III']           = { Body="Aoidos' Hongreline +2" },
    ['Utsusemi: Ichi']     = { Head="Walahra Turban" },
    ['Utsusemi: Ni']       = { Head="Walahra Turban" },

    -- CastingMode overlays (/lac mode casting MB -> uses sets.Midcast.MB):
    MB   = { Head="Nahtirah Hat", Neck="Stoicheion Medal", Ring1="Strendu Ring",
             Ring2="Icesoul Ring" },

    -- Auto-applied by Core when hit while casting:
    SIRD = { Head="Nahtirah Hat", Body="Mekira-oi", Hands="Dusk Gloves +1",
             Legs="Byakko's Haidate", Ring1="Evanescence Ring" },
};

-- ---------------------------------------------------------------------------
-- Weaponskills
-- ---------------------------------------------------------------------------
sets.WS = {};
sets.WS.Default = {
    Head="Optical Hat", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Merman's Earring",
    Body="Aoidos' Hongreline +2", Hands="Dusk Gloves", Ring1="Rajas Ring", Ring2="Woodsman Ring",
    Back="Cerberus Mantle", Waist="Warwolf Belt", Legs="Byakko's Haidate", Feet="Rutter Sabatons",
    Main="Joyeuse",
};
-- Common BRD weaponskills:
sets.WS["Mercy Stroke"]  = sets.WS.Default;
sets.WS["Vorpal Blade"]  = sets.WS.Default;
sets.WS["Savage Blade"]  = sets.WS.Default;
sets.WS["Mordant Rime"]  = sets.WS.Default;   -- not in era but harmless
-- WeaponskillMode overlays:
sets.WS.Acc  = { Neck="Peacock Charm", Ring1="Toreador's Ring" };
sets.WS.Mod  = { Head="Optical Hat", Hands="Enkidu's Mittens", Ring2="Woodsman Ring" };

-- ---------------------------------------------------------------------------
-- Job abilities
-- ---------------------------------------------------------------------------
sets.JA = {
    ["Nightingale"]  = { Feet="Aoidos' Cothurnes +2" },
    ["Troubadour"]   = { Body="Aoidos' Hongreline +2" },
    ["Soul Voice"]   = { Body="Aoidos' Hongreline +2" },
    ["Pianissimo"]   = {},
};

-- ---------------------------------------------------------------------------
-- Per-song-type instrument swap (overlays Range mid-cast)
-- ---------------------------------------------------------------------------
local function instrumentForSong(name)
    if (name:contains('March') or name:contains('Minuet') or name:contains('Madrigal')
        or name:contains('Mambo') or name:contains('Prelude') or name:contains('Scherzo')) then
        return Inst.Wind;
    elseif (name:contains('Ballad') or name:contains('Paeon') or name:contains('Requiem')
            or name:contains('Threnody') or name:contains('Elegy') or name:contains('Dirge')) then
        return Inst.String;
    else
        return Inst.Lyre;
    end
end

-- ---------------------------------------------------------------------------
-- Load / Unload
-- ---------------------------------------------------------------------------
profile.OnLoad = function()
    gSettings.AllowAddSet = true;
    Core.echo('[Chharizard BRD] loaded (server=%s, auto=%s).',
        Core.server, tostring(Core.automationAllowed));
end
profile.OnUnload = function()
    Core.echo('[Chharizard BRD] unloaded.');
end

-- ---------------------------------------------------------------------------
-- Handlers -- all delegate to Core resolvers
-- ---------------------------------------------------------------------------
profile.HandleDefault = function()
    gFunc.EquipSet(Core.resolveIdle(sets));
    gFunc.EquipSet({ Range = idleRange });   -- user-togglable Range
    Sub.tick(true);
end

profile.HandleEngaged = function()
    gFunc.EquipSet(Core.resolveTP(sets));
    gFunc.EquipSet({ Range = idleRange });   -- carry user-togglable Range into TP too
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
    -- Instrument swap for songs (Range slot, not Main).
    if (sp.Skill == 'Singing') then
        gFunc.EquipSet({ Range = instrumentForSong(sp.Name) });
    end
end

profile.HandleAbility = function()
    local ja = gData.GetAction().Name;
    if (sets.JA[ja]) then gFunc.EquipSet(sets.JA[ja]); end
end

profile.HandleWeaponskill = function()
    local ws = gData.GetAction().Name;
    gFunc.EquipSet(Core.resolveWS(sets, ws));
end

-- ---------------------------------------------------------------------------
-- Command handler: Core first (modes), then Sub (sub-job auto), then local.
-- ---------------------------------------------------------------------------
profile.HandleCommand = function(args)
    if (#args < 1) then return; end
    if (Core.handleCommand(args)) then return; end
    if (Sub.handleCommand(args))  then return; end
    local cmd = args[1]:lower();
    -- /lac fwd range <item>  (or no arg = show current)
    if (cmd == 'range') then
        if (args[2]) then
            idleRange = args[2];
            -- Allow multi-word item names: "/lac fwd range Faerie Piccolo"
            for i = 3, #args do idleRange = idleRange .. ' ' .. args[i]; end
            if (verbose) then Core.echo('idle Range -> %s', idleRange); end
        else
            Core.echo('idle Range = %s', idleRange);   -- query always prints
        end
        return;
    end
    -- /lac fwd verbose on|off  (default off; silences range-swap echoes)
    if (cmd == 'verbose') then
        if     (args[2] and args[2]:lower() == 'on')  then verbose = true;
        elseif (args[2] and args[2]:lower() == 'off') then verbose = false;
        else   verbose = not verbose; end
        Core.echo('verbose = %s', verbose and 'ON' or 'OFF');
        return;
    end
    if (cmd == 'debug') then Sub.debug(); end
end

return profile;
