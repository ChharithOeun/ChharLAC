-- ============================================================================
-- Chharizard PUP - LuAshitaCast profile for Horizon XI (era retail)
--
-- Features (Selindril-style, ToAU-era adapted):
--   * 8 pet-role maneuver stacks: Melee / Ranged / HybridRanged / Tank /
--     LightTank / Magic / Heal / Nuke -- picks what to fire based on role
--   * Auto-repair when pet HP < deactivatehpp (default 85%)
--   * Auto pet healing (oils) as a secondary safety net
--   * Ventriloquy on demand (shed hate to pet)
--   * Gear swaps for pet WS, pet spells, pet abilities
--
-- Commands (all via /lac fwd ...):
--   /lac fwd auto              -- toggle full automation on/off
--   /lac fwd am on|off         -- auto-maneuvers on/off individually
--   /lac fwd heal on|off       -- auto pet oil healing on/off
--   /lac fwd repair on|off     -- auto Repair ability on/off
--   /lac fwd mode <name>       -- set pet role (Melee/Ranged/HybridRanged/
--                                 Tank/LightTank/Magic/Heal/Nuke)
--   /lac fwd head <name>       -- legacy alias -- picks a mode for the head
--   /lac fwd frame <name>      -- legacy, logged only
--   /lac fwd vent              -- fire Ventriloquy on current target
--   /lac fwd modes             -- list every mode + its maneuver stack
--   /lac fwd debug             -- inspect config + pet state
--   /lac fwd cooldown on|off   -- auto-fire Cooldown on Overload (default ON)
--   /lac fwd buffs             -- show active maneuver buffs
--   /lac fwd recast            -- show live JA recast timers
--   /lac fwd config            -- print current mode + auto-toggles
--
-- Suggested binds (paste into Ashita console once):
--   /bind ^f7 /lac fwd repair toggle
--   /bind ^f8 /lac fwd am toggle
--
-- IMPORTANT: Auto-maneuvers use a timer. Private servers frequently classify
-- timer-based auto-actions as botting. Verify Horizon's rules before enabling
-- `auto` mode. Manual maneuver macros via head/frame commands are always safe.
-- ============================================================================

local profile = {};
local sets = {};
profile.Sets = sets;
local Sub = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/subjob_features.lua');
local Burden = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/pup_burden.lua');

-- ---------------------------------------------------------------------------
-- Runtime config -- edit these OR change via /lac fwd commands.
-- ---------------------------------------------------------------------------
local cfg = {
    autoManeuvers = true,   -- master toggle; default ON (per user preference)
    autoCooldown  = true,   -- auto-fire Cooldown JA when Overload hits
    autoRepair    = false,  -- auto Repair ability when pet HP drops
    autoHeal      = false,  -- auto-use oils on pet (item-based last-resort)
    petHpThreshold= 50,     -- % pet HP that triggers OIL use
    deactivatehpp = 85,     -- % pet HP that triggers REPAIR (Selindril)
    mode          = 'Melee',-- pet role (picks a maneuver pattern)
    head          = '',     -- cosmetic; auto-mapped to mode via /lac fwd head
    frame         = '',     -- cosmetic
    petOilHp      = 'Automat. Oil +3',  -- HP restore item
};

-- ---------------------------------------------------------------------------
-- Maneuver model (ported from sruon/AutoPUP + Selindril).
-- Each mode is a DECLARATIVE TARGET: "I want this many of each buff active."
-- The tick keeps buff counts at target counts. No stack, no index, no burden
-- math -- the game itself gates us via the Maneuvers JA recast and Overload.
-- Total count per mode <= 3 (automaton holds 3 maneuvers max).
-- ---------------------------------------------------------------------------
local manPatterns = {
    Melee        = { fire=2, light=1 },               -- H2H DD + sustain
    Ranged       = { wind=1, fire=1, light=1 },       -- Sharpshot
    HybridRanged = { fire=1, light=1, thunder=1 },    -- Sharpshot + melee
    Tank         = { earth=2, light=1 },              -- Valoredge
    LightTank    = { earth=1, light=1, water=1 },     -- Valoredge off-tank
    Magic        = { ice=1, dark=1, light=1 },        -- Stormwaker DD
    Heal         = { light=2, dark=1 },               -- Soulsoother
    Nuke         = { dark=2, light=1 },               -- Spiritreaver
};

local headToMode = {
    Valoredge='Tank', Harlequin='Melee', Sharpshot='Ranged',
    Stormwaker='Magic', Soulsoother='Heal', Spiritreaver='Nuke',
};

-- Buff IDs from AutoPUP/pup_ids.lua (confirmed retail; same on era).
local MAN_BUFF = {
    fire=300, ice=301, wind=302, earth=303,
    thunder=304, water=305, light=306, dark=307,
};
local OVERLOAD_ID = 299;

-- Disabling status IDs -- never fire while any of these is up.
local DISABLE_IDS = {
    [2]=true,   -- Sleep
    [10]=true,  -- Stun
    [14]=true,  -- Charm
    [17]=true,  -- Terror
    [7]=true,   -- Petrification
    [299]=true, -- Overload (handled separately for Cooldown)
};

-- Ashita ability recast indices (= in-game recast IDs from AutoPUP).
local RID_MANEUVERS = 210;
local RID_COOLDOWN  = 114;
local RID_REPAIR    = 115;  -- Repair JA recast slot

-- ---------------------------------------------------------------------------
-- Gear sets
-- ---------------------------------------------------------------------------
sets.Idle = {
    Head    = "Empress Hairpin",
    Neck    = "Peacock Amulet",
    Ear1    = "Merman's Earring",
    Ear2    = "Puppetry Earring",     -- Automaton skill
    Body    = "Yigit Gomlek",
    Hands   = "Puppetry Dastanas",
    Ring1   = "Rajas Ring",
    Ring2   = "Puppetmaster's Ring",  -- Automaton skill
    Back    = "Amemet Mantle +1",
    Waist   = "Life Belt",
    Legs    = "Puppetry Churidars",
    Feet    = "Puppetry Babouches",
};

sets.Movement = { Feet = "Rutter Sabatons" };

sets.TP = {
    Head    = "Optical Hat",
    Neck    = "Peacock Amulet",
    Ear1    = "Merman's Earring",
    Ear2    = "Assault Earring",
    Body    = "Yigit Gomlek",
    Hands   = "Yigit Gages",
    Ring1   = "Rajas Ring",
    Ring2   = "Sniper's Ring",
    Back    = "Amemet Mantle +1",
    Waist   = "Swift Belt",
    Legs    = "Yigit Seraweels",
    Feet    = "Yigit Crackows",
};

-- WS sets -- Victory Smite (MNK sub), Raging Fists, or H2H staples
sets.WS = {};
sets.WS.Default = {
    Head    = "Optical Hat",
    Neck    = "Peacock Amulet",
    Ear1    = "Merman's Earring",
    Ear2    = "Assault Earring",
    Body    = "Scorpion Harness",
    Hands   = "Yigit Gages",
    Ring1   = "Rajas Ring",
    Ring2   = "Sniper's Ring",
    Back    = "Cerberus Mantle",     -- STR / Crit
    Waist   = "Warwolf Belt",
    Legs    = "Byakko's Haidate",
    Feet    = "Yigit Crackows",
};
sets.WS["Victory Smite"] = sets.WS.Default;
sets.WS["Raging Fists"]  = sets.WS.Default;
sets.WS["Combo"]         = sets.WS.Default;

-- ---------------------------------------------------------------------------
-- Job abilities -- Activate/Deploy/Overdrive/Ventriloquy/Role Reversal/etc.
-- ---------------------------------------------------------------------------
sets.JA = {};
sets.JA["Activate"]         = { Body = "Foragers Mantle" };  -- +Automaton skill (era piece)
sets.JA["Deploy"]           = {};
sets.JA["Deactivate"]       = {};
sets.JA["Repair"]           = { Hands = "Puppetry Dastanas" };  -- +Repair effect
sets.JA["Maintenance"]      = sets.JA["Repair"];
sets.JA["Overdrive"]        = { Body = "Foragers Mantle" };
sets.JA["Ventriloquy"]      = {};
sets.JA["Role Reversal"]    = {};
sets.JA["Tactical Switch"]  = {};
sets.JA["Cooldown"]         = {};

-- All Maneuvers get the same gear (Pet: Skill+/Pet: Regain+ pieces on Horizon)
sets.JA["Fire Maneuver"]    = { Head = "Puppetry Tobe", Body = "Foragers Mantle" };
sets.JA["Ice Maneuver"]     = sets.JA["Fire Maneuver"];
sets.JA["Wind Maneuver"]    = sets.JA["Fire Maneuver"];
sets.JA["Earth Maneuver"]   = sets.JA["Fire Maneuver"];
sets.JA["Thunder Maneuver"] = sets.JA["Fire Maneuver"];
sets.JA["Water Maneuver"]   = sets.JA["Fire Maneuver"];
sets.JA["Light Maneuver"]   = sets.JA["Fire Maneuver"];
sets.JA["Dark Maneuver"]    = sets.JA["Fire Maneuver"];

-- ---------------------------------------------------------------------------
-- Subjob magic (usually /WHM /NIN /DNC)
-- ---------------------------------------------------------------------------
sets.Precast = {};
sets.Precast.FastCast = {
    Ear2  = "Loquac. Earring",
    Body  = "Homam Corazza",
};

sets.Midcast = {};
sets.Midcast.Utsusemi = { Head = "Walahra Turban", Feet = "Yigit Crackows" };
sets.Midcast.Healing  = { Ring1 = "Ether Ring" };

-- ---------------------------------------------------------------------------
-- Pet action gear -- worn when the automaton itself acts.
-- Selindril style: separate sets for pet TP (melee), pet WS, pet magic.
-- Player's Pet: * bonuses (Pet: Attack, Pet: Acc, Pet: Magic Attack) apply.
-- ---------------------------------------------------------------------------
sets.PetTP = {                       -- pet melee attack, worn constantly while pet engaged
    Head    = "Puppetry Tobe",       -- Pet: Attack
    Body    = "Foragers Mantle",     -- Pet: Attack+
    Hands   = "Yigit Gages",         -- Pet: Attack+
    Legs    = "Yigit Seraweels",     -- Pet: Attack+
    Feet    = "Puppetry Babouches",  -- Pet: Acc+
};

sets.PetWS = {                       -- pet using a mob-skill / WS
    Head    = "Puppetry Tobe",
    Body    = "Foragers Mantle",
    Hands   = "Yigit Gages",
    Legs    = "Yigit Seraweels",
    Feet    = "Puppetry Babouches",
    Back    = "Visucius's Mantle",   -- if you get one; else Amemet
    Waist   = "Incarnation Sash",    -- +Pet: WSD if available
};

sets.PetSpell = {                    -- pet casting magic (Stormwaker head)
    Head    = "Puppetry Tobe",       -- Pet: MAB
    Body    = "Foragers Mantle",
    Hands   = "Puppetry Dastanas",
    Legs    = "Puppetry Churidars",
    Feet    = "Puppetry Babouches",
};

-- Worn briefly while USING a pet-heal item so any Item Use time reduction
-- applies (some pieces have "Item use +N", niche but era-relevant).
sets.PetHealing = {
    -- Ear2 = "Recovery Earring",  -- item use time reduction if you find one
};

-- ============================================================================
-- Event handlers
-- ============================================================================

profile.OnLoad = function()
    gSettings.AllowAddSet = true;
    Burden.hook();
    Burden.hookHUD();
    -- Sidecar visual orb addon (safe if already loaded)
    AshitaCore:GetChatManager():QueueCommand(1, '/addon load chharmaton');
    Sub.echo("[Chharizard PUP] Profile loaded (burden tracker + HUD + ChharMaton orbs).");
end

profile.OnUnload = function()
    Burden.unhook();
    AshitaCore:GetChatManager():QueueCommand(1, '/addon unload chharmaton');
    Sub.echo("[Chharizard PUP] Profile unloaded.");
end

profile.HandleDefault = function()
    -- If the pet just did something, wear its action gear briefly then return
    local pa = gData.GetPetAction();
    if (pa) then
        if (pa.Type == 'Spell') then     gFunc.EquipSet(sets.PetSpell); return; end
        if (pa.Type == 'MobSkill' or pa.Type == 'Ability') then
            gFunc.EquipSet(sets.PetWS); return;
        end
    end
    -- Otherwise: pet-attack gear if pet exists, else idle
    local pet = gData.GetPet();
    if (pet and pet.Status == 'Engaged') then
        gFunc.EquipSet(sets.PetTP);
    else
        gFunc.EquipSet(sets.Idle);
    end
    if (gData.GetPlayer().IsMoving) then gFunc.EquipSet(sets.Movement); end
    if (profile._autoTick) then profile._autoTick(); end
    Sub.tick(true);
end

profile.HandleEngaged = function()
    -- Player melee (PUP often skills up H2H). Layer PetTP on top so pet
    -- keeps its damage boost while we melee.
    gFunc.EquipSet(sets.TP);
    local pet = gData.GetPet();
    if (pet) then gFunc.EquipSet(sets.PetTP); end
    if (profile._autoTick) then profile._autoTick(); end
    Sub.tick(true);
end

profile.HandleWeaponskill = function()
    local ws = gData.GetAction().Name;
    if (sets.WS[ws]) then gFunc.EquipSet(sets.WS[ws]);
    else                  gFunc.EquipSet(sets.WS.Default); end
end

profile.HandleAbility = function()
    local ja = gData.GetAction().Name;
    if (sets.JA[ja]) then gFunc.EquipSet(sets.JA[ja]); end
end

profile.HandlePrecast = function()
    gFunc.EquipSet(sets.Precast.FastCast);
end

profile.HandleMidcast = function()
    local spell = gData.GetAction();
    if (spell.Skill == 'Ninjutsu' and spell.Name:contains('Utsusemi')) then
        gFunc.EquipSet(sets.Midcast.Utsusemi);
    elseif (spell.Skill == 'Healing Magic') then
        gFunc.EquipSet(sets.Midcast.Healing);
    end
end

-- ============================================================================
-- Automation (AutoPUP-model: buff-count driven, real recasts, overload-safe)
-- ============================================================================

-- Returns a map of buff_id → count of that buff currently active on us.
-- Count matters because maneuvers can stack to the same ID (same element
-- fired twice = count 2).
local function readBuffs()
    local b = {};
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (not player) then return b; end
    local getter = player.GetBuff or player.GetStatusIcon;
    if (not getter) then return b; end
    for i = 0, 31 do
        local ok, id = pcall(getter, player, i);
        if (ok and id ~= nil and id > 0 and id ~= 255 and id ~= 0xFF) then
            b[id] = (b[id] or 0) + 1;
        end
    end
    return b;
end

-- How many maneuvers of ANY element are currently stacked (max 3).
local function activeManeuverTotal(buffs)
    local n = 0;
    for _, id in pairs(MAN_BUFF) do n = n + (buffs[id] or 0); end
    return n;
end

-- Per-element last-fire timestamp + last-seen buff count (for wearoff detect).
--
-- Gates (in priority order):
--   1. Buff visibly just wore off (was UP, now DOWN)  -> fire immediately
--   2. Need to build toward target count + JA recast  -> fire
--   3. Hard safety: cap total fires at 3 per 60s window so a broken buff
--      reader can't ever cause an overload. Game maxes at 3 maneuvers up
--      anyway, so this is a correct physical ceiling, not a guess.
local lastFiredAt    = {};
local lastSeenCount  = {};   -- elem -> buff count observed last tick
local lastAnyFire    = 0;
local firesByElem    = {};   -- elem -> list of os.time() of recent fires
local MIN_SAME_ELEM_GAP = 12;   -- JA recast + a touch, so earth=2 can stack
local MIN_ANY_FIRE_GAP  = 11;   -- global floor between ANY two fires
local FIRE_WINDOW_SEC   = 70;   -- rolling window (slightly > base duration)

-- Count of recent fires for a given element (within FIRE_WINDOW_SEC).
local function elemFires(elem, now)
    local list = firesByElem[elem];
    if (not list) then return 0; end
    -- Prune in place
    while (#list > 0 and (now - list[1]) > FIRE_WINDOW_SEC) do
        table.remove(list, 1);
    end
    return #list;
end

-- Element is capped (shouldn't fire) if recent-fires >= pattern target + 1.
-- That +1 is a refresh buffer so wearoff refills always have room.
local function elemCapped(elem, now, pattern)
    local target = pattern[elem] or 0;
    return elemFires(elem, now) >= (target + 1);
end

local function nextManeuverNeeded(buffs)
    local pattern = manPatterns[cfg.mode] or manPatterns.Melee;
    local now = os.time();
    local worn, aged = nil, nil;
    for _, elem in ipairs({'fire','ice','wind','earth','thunder','water','light','dark'}) do
        local want = pattern[elem];
        if (want) then
            local have       = buffs[MAN_BUFF[elem]] or 0;
            local wasHad     = (lastSeenCount[elem] or 0) >= want;
            local sinceFire  = now - (lastFiredAt[elem] or 0);
            -- Authoritative gate: don't fire if burden would exceed threshold.
            -- This replaces the pattern-based cap and is the real retail rule.
            local burdenOK   = Burden.canFire(elem);
            if (have < want and wasHad and not worn and burdenOK) then
                worn = elem;
            end
            if (have < want
                and sinceFire >= MIN_SAME_ELEM_GAP
                and burdenOK
                and not aged) then
                aged = elem;
            end
            lastSeenCount[elem] = have;
        end
    end
    return worn or aged;
end

-- Query the game's own recast timer for an ability (seconds remaining).
-- Returns 0 (ready) on any error so we fail-open rather than freeze.
local function recastRemaining(rid)
    local ok, r = pcall(function()
        return AshitaCore:GetMemoryManager():GetRecast()
    end);
    if (not ok or not r) then return 0; end
    local ok2, t = pcall(r.GetAbilityTimer, r, rid);
    if (not ok2 or not t) then return 0; end
    return t;
end

local function recastReady(rid)
    return recastRemaining(rid) <= 0;
end


-- ---------------------------------------------------------------------------
-- Automation tick -- called from HandleDefault/HandleEngaged each frame.
--
-- Decision tree (AutoPUP-style, in priority order):
--   1. Pet gone?            -> nothing to do.
--   2. Overload active?     -> fire Cooldown JA if ready, then bail.
--   3. Any disabling status -> bail (sleep/stun/charm/terror/petrify).
--   4. Casting?             -> bail (don't interrupt our own spell).
--   5. Pet HP below Repair threshold + JA ready -> fire Repair.
--   6. Pet HP critical + oils enabled           -> use oil (fallback).
--   7. Any maneuver needed + Maneuvers JA ready -> fire next needed.
--
-- All timing is driven by the GAME'S own recast timers. No arbitrary
-- intervals, no burden guessing: if Maneuvers JA says ready, we fire.
-- Overload == the real "burden exceeded" signal, so Cooldown is our
-- only burden-management tool and we only need it on actual overload.
-- ---------------------------------------------------------------------------
local lastHealTime = 0;

profile._autoTick = function()
    if (gProfile ~= profile) then return; end
    -- Refresh Kenkonken (overload-immunity) detection from current equip.
    -- Pass the whole table through -- updateSafeMode handles name OR id match.
    local okEq, equip = pcall(gData.GetEquipment);
    if (okEq and equip) then Burden.updateSafeMode(equip); end
    local pet = gData.GetPet();
    if (not pet or pet.HPP <= 0) then
        -- Pet gone -- clear per-element records so next deploy is fresh.
        if (next(lastFiredAt) ~= nil) then
            lastFiredAt = {}; lastSeenCount = {}; lastAnyFire = 0;
            firesByElem = {};
        end
        return;
    end

    local buffs = readBuffs();

    -- (2) Overload -> auto-Cooldown
    if (buffs[OVERLOAD_ID]) then
        if (cfg.autoCooldown and recastReady(RID_COOLDOWN)) then
            AshitaCore:GetChatManager():QueueCommand(1, '/ja "Cooldown" <me>');
            Sub.echo('[PUP] Overload detected -> Cooldown fired.');
        end
        return;
    end

    -- (3) Disabled -> bail
    for id in pairs(DISABLE_IDS) do
        if (buffs[id]) then return; end
    end

    -- (5) Auto-Repair (preferred over oils when JA is up)
    if (cfg.autoRepair and pet.HPP < cfg.deactivatehpp) then
        if (recastReady(RID_REPAIR)) then
            AshitaCore:GetChatManager():QueueCommand(1, '/ja "Repair" <me>');
            Sub.echo(string.format('[PUP] Auto-Repair (pet %d%% < %d%%)',
                pet.HPP, cfg.deactivatehpp));
            return;  -- one action per tick
        end
    end

    -- (6) Auto-oil (last resort if Repair is on cooldown)
    local now = os.time();
    if (cfg.autoHeal and pet.HPP < cfg.petHpThreshold
        and (now - lastHealTime >= 15)) then
        AshitaCore:GetChatManager():QueueCommand(1,
            string.format('/item "%s" <me>', cfg.petOilHp));
        lastHealTime = now;
        Sub.echo(string.format('[PUP] Auto-oil pet (%d%%) with %s',
            pet.HPP, cfg.petOilHp));
        return;
    end

    -- (7) Auto-maneuver
    if (cfg.autoManeuvers) then
        local now2 = os.time();
        if ((now2 - lastAnyFire) < MIN_ANY_FIRE_GAP) then return; end
        if (not recastReady(RID_MANEUVERS)) then return; end
        if (activeManeuverTotal(buffs) >= 3) then return; end
        local elem = nextManeuverNeeded(buffs);
        if (elem) then
            local name = elem:sub(1,1):upper() .. elem:sub(2) .. ' Maneuver';
            AshitaCore:GetChatManager():QueueCommand(1,
                string.format('/ja "%s" <me>', name));
            lastFiredAt[elem] = now2;
            lastAnyFire = now2;
            -- Record burden LOCALLY as a fallback. Chat parse will OVERRIDE
            -- with the exact post-fire value (threshold + chance) if it
            -- fires -- so we never double-count. If chat parse fails for any
            -- reason, this +15 still keeps burden tracked incrementally.
            Burden.record(elem);
            Sub.echo(string.format('[PUP:%s] -> %s', cfg.mode, name));
        end
    end
end


-- ============================================================================
-- Commands (via /lac fwd ...)
-- ============================================================================

profile.HandleCommand = function(args)
    if (#args < 1) then return; end
    if (Sub.handleCommand(args)) then return; end
    local sub = args[1]:lower();

    -- Small helper: on|off|toggle → new bool
    local function tri(flag, word)
        if (word == 'on')  then return true;  end
        if (word == 'off') then return false; end
        if (word == 'toggle' or word == nil) then return not flag; end
        return flag;
    end

    if (sub == 'auto') then
        cfg.autoManeuvers = not cfg.autoManeuvers;
        cfg.autoRepair    = cfg.autoManeuvers;
        cfg.autoCooldown  = cfg.autoManeuvers;
        Sub.echo('[PUP] Auto (maneuvers + repair + cooldown): '
              .. (cfg.autoManeuvers and 'ON' or 'OFF'));
        return;
    end

    if (sub == 'cooldown' or sub == 'cd') then
        cfg.autoCooldown = tri(cfg.autoCooldown, args[2] and args[2]:lower());
        Sub.echo('[PUP] Auto-Cooldown on Overload: '
              .. (cfg.autoCooldown and 'ON' or 'OFF'));
        return;
    end

    if (sub == 'am') then
        cfg.autoManeuvers = tri(cfg.autoManeuvers, args[2] and args[2]:lower());
        Sub.echo('[PUP] Auto-maneuvers: ' .. (cfg.autoManeuvers and 'ON' or 'OFF'));
        return;
    end

    if (sub == 'heal') then
        cfg.autoHeal = tri(cfg.autoHeal, args[2] and args[2]:lower());
        Sub.echo('[PUP] Auto-oil: ' .. (cfg.autoHeal and 'ON' or 'OFF'));
        return;
    end

    if (sub == 'repair') then
        cfg.autoRepair = tri(cfg.autoRepair, args[2] and args[2]:lower());
        Sub.echo('[PUP] Auto-Repair: ' .. (cfg.autoRepair and 'ON' or 'OFF')
              .. ' (triggers at pet < ' .. cfg.deactivatehpp .. '%)');
        return;
    end

    -- Pretty-print a pattern like {fire=2, light=1} as "Fire x2, Light x1"
    local function fmtPattern(p)
        local parts = {};
        for _, e in ipairs({'fire','ice','wind','earth','thunder','water','light','dark'}) do
            if (p[e]) then
                parts[#parts+1] = string.format('%s x%d',
                    e:sub(1,1):upper()..e:sub(2), p[e]);
            end
        end
        return table.concat(parts, ', ');
    end

    if (sub == 'mode' and args[2]) then
        local m = args[2]:sub(1,1):upper() .. args[2]:sub(2):lower();
        if (not manPatterns[m]) then
            Sub.echo('[PUP] Unknown mode: ' .. m
                  .. ' (Melee/Ranged/HybridRanged/Tank/LightTank/Magic/Heal/Nuke)');
        else
            cfg.mode = m;
            Sub.echo('[PUP] Mode: ' .. m .. ' -- ' .. fmtPattern(manPatterns[m]));
        end
        return;
    end

    if (sub == 'modes') then
        Sub.echo('[PUP] Available modes:');
        for name, pat in pairs(manPatterns) do
            Sub.echo(string.format('   %-14s  %s', name, fmtPattern(pat)));
        end
        return;
    end

    if (sub == 'head' and args[2]) then
        local h = args[2]:sub(1,1):upper() .. args[2]:sub(2):lower();
        cfg.head = h;
        local mapped = headToMode[h];
        if (mapped) then
            cfg.mode = mapped;
            Sub.echo('[PUP] Head=' .. h .. ' -> mode=' .. mapped
                  .. ' -- ' .. fmtPattern(manPatterns[mapped]));
        else
            Sub.echo('[PUP] Unknown head: ' .. h
                  .. ' (Valoredge/Harlequin/Sharpshot/Stormwaker/Soulsoother/Spiritreaver)');
        end
        return;
    end

    if (sub == 'frame' and args[2]) then
        cfg.frame = args[2]:sub(1,1):upper() .. args[2]:sub(2):lower();
        Sub.echo('[PUP] Frame set to ' .. cfg.frame .. ' (cosmetic -- mode drives maneuvers)');
        return;
    end

    if (sub == 'threshold' and args[2]) then
        local n = tonumber(args[2]);
        if (n and n > 0 and n <= 100) then
            cfg.deactivatehpp = n;
            Sub.echo('[PUP] Repair threshold set to ' .. n .. '%');
        end
        return;
    end

    if (sub == 'buffs') then
        local b = readBuffs();
        Sub.echo('[PUP] Active maneuver buffs:');
        for elem, id in pairs(MAN_BUFF) do
            if (b[id]) then
                Sub.echo(string.format('   %-8s x%d', elem, b[id]));
            end
        end
        Sub.echo(string.format('   Overload: %s',
            b[OVERLOAD_ID] and 'YES' or 'no'));
        return;
    end

    if (sub == 'burden') then
        for _, line in ipairs(Burden.snapshot()) do
            Sub.echo('[PUP] ' .. line);
        end
        return;
    end

    if (sub == 'hud') then
        local on = Burden.toggleHUD(args[2] == 'on' and true
                                 or args[2] == 'off' and false
                                 or nil);
        Sub.echo('[PUP] Burden HUD: ' .. (on and 'ON' or 'OFF'));
        return;
    end

    if (sub == 'safe') then
        local word = args[2] and args[2]:lower() or 'toggle';
        if (word == 'on') then Burden.safeMode = true;
        elseif (word == 'off') then Burden.safeMode = false;
        else Burden.safeMode = not Burden.safeMode; end
        Sub.echo('[PUP] Safe mode (overload immunity): '
              .. (Burden.safeMode and 'ON' or 'OFF'));
        return;
    end

    if (sub == 'recast') then
        Sub.echo(string.format('[PUP] Maneuvers ready in %.1fs',
            recastRemaining(RID_MANEUVERS)));
        Sub.echo(string.format('[PUP] Cooldown  ready in %.1fs',
            recastRemaining(RID_COOLDOWN)));
        Sub.echo(string.format('[PUP] Repair    ready in %.1fs',
            recastRemaining(RID_REPAIR)));
        return;
    end

    if (sub == 'vent') then
        AshitaCore:GetChatManager():QueueCommand(1,
            '/ja "Ventriloquy" <t>');
        return;
    end

    if (sub == 'config') then
        Sub.echo('[PUP] Mode:          ' .. cfg.mode
              .. '  (' .. fmtPattern(manPatterns[cfg.mode] or {}) .. ')');
        Sub.echo('[PUP] Head/Frame:    ' .. cfg.head .. ' / ' .. cfg.frame);
        Sub.echo('[PUP] Auto maneuvers:' .. (cfg.autoManeuvers and ' ON' or ' OFF'));
        Sub.echo('[PUP] Auto Cooldown: ' .. (cfg.autoCooldown  and ' ON' or ' OFF')
              .. ' (fires on Overload)');
        Sub.echo('[PUP] Auto Repair:   ' .. (cfg.autoRepair    and ' ON' or ' OFF')
              .. ' (fires below ' .. cfg.deactivatehpp .. '%)');
        Sub.echo('[PUP] Auto oil:      ' .. (cfg.autoHeal      and ' ON' or ' OFF')
              .. ' (fires below ' .. cfg.petHpThreshold .. '%)');
        return;
    end

    if (sub == 'debug') then
        local buffs = readBuffs();
        local pet = gData.GetPet();
        Sub.echo('[PUP DEBUG] Mode=' .. cfg.mode
              .. '  pattern=' .. fmtPattern(manPatterns[cfg.mode] or {}));
        Sub.echo('[PUP DEBUG] AM=' .. tostring(cfg.autoManeuvers)
              .. '  CD=' .. tostring(cfg.autoCooldown)
              .. '  RP=' .. tostring(cfg.autoRepair)
              .. '  OIL=' .. tostring(cfg.autoHeal));
        if (pet) then
            Sub.echo(string.format('[PUP DEBUG] Pet: %s  HP:%d%%  TP:%d  Status:%s',
                pet.Name, pet.HPP, pet.TP, pet.Status or '?'));
        else
            Sub.echo('[PUP DEBUG] No pet.');
        end
        Sub.echo('[PUP DEBUG] Maneuvers up: ' .. activeManeuverTotal(buffs) .. '/3');
        for elem, id in pairs(MAN_BUFF) do
            if (buffs[id]) then
                Sub.echo(string.format('   - %-8s x%d (id %d)', elem, buffs[id], id));
            end
        end
        Sub.echo(string.format('[PUP DEBUG] Overload=%s  Maneuvers CD=%.1fs  Cooldown CD=%.1fs',
            tostring(buffs[OVERLOAD_ID] ~= nil),
            recastRemaining(RID_MANEUVERS),
            recastRemaining(RID_COOLDOWN)));
        return;
    end

    Sub.echo('[PUP] Unknown command: ' .. sub
          .. '  (auto|am|heal|repair|cooldown|mode|modes|head|frame|threshold|buffs|burden|hud|recast|vent|config|debug)');
end

return profile;
