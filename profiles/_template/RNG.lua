-- ============================================================================
-- Chharizard RNG - LuAshitaCast profile for Horizon XI (era retail)
--
-- Install path (LuAshitaCast v2.12 by Chharizard uses flat CharName_JOB.lua):
--   C:\Users\User\AppData\Local\Horizon\HorizonXI\Game\addons\luashitacast\Chharizard_RNG.lua
--
-- Load in-game:
--   /addon load luashitacast
--   /lac load                       -- auto-picks by character/job
--   /lac reload                     -- after edits
--
-- Custom commands (forwarded to this profile's HandleCommand):
--   /lac fwd tp                     -- switch ammo mode: TP building
--   /lac fwd acc                    -- switch ammo mode: Accuracy
--   /lac fwd sleep                  -- Sleep Arrow (bow) or Sleep Bolt (xbow)
--   /lac fwd def                    -- Fang Arrow / Acid Bolt (DEF-down proc)
--   /lac fwd blind                  -- Blind Bolt (crossbow only)
--   /lac fwd drain                  -- Bloody Bolt (crossbow only)
--   /lac fwd ws                     -- WS ammo
--   /lac fwd aoe                    -- Bomb Arrow for Barrage
--   /lac fwd ammo                   -- cycle to next mode
--   /lac fwd bow  | xbow | gun      -- swap Range weapon
--   /lac fwd debug                  -- show detected weapon + ammo table
--
-- /DRG subjob features (event-driven, not fixed timers):
--   /lac fwd jumps on|off           -- master toggle for jump automation
--   /lac fwd shed on|off            -- Super/High Jump when a mob targets you
--   /lac fwd dpsjump on|off         -- regular Jump on cooldown for DPS
--
-- Era notes (75-cap classic RNG BiS):
--   - Ranged: Yoichinoyumi (relic) > Selene's Bow > Kabura Arrow > Fire Arrow
--   - Head: Optical Hat, Bison Warbonnet (Rapid Shot), Empress Hairpin (HP)
--   - Neck: Peacock Amulet, Peacock Charm, Uggalepih Pendant (magic)
--   - Body: Scorpion Harness, Hachiryu Haramaki +1
--   - Hands: Adaman Mufflers (Slug Shot dmg), Yigit Gages (TP), Ryl.Ftm. Gloves (Barrage)
--   - Legs: Yigit Seraweels, Byakko's Haidate, Coronal Squares
--   - Feet: Yigit Crackows, Rutter Sabatons
--   - Waist: Life Belt (base), Scout's Belt (STR), Swift Belt (haste+2)
--   - Back: Amemet Mantle +1, Cerberus Mantle (STR/Crit)
--   - Rings: Rajas Ring, Toreador's Ring, Sniper's Ring +1
--   - Ears: Volley Earring (Snapshot), Drone Earring (Ranged Attack)
--
-- Server-specific: Horizon has custom items and adjusted stats — check their
-- wiki before assuming retail-era BiS on any listed piece.
-- ============================================================================

local profile = {};
local sets = {};
profile.Sets = sets;
local Sub = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/subjob_features.lua');

-- ---------------------------------------------------------------------------
-- Simple mode state -- replaces gcinclude/gcdisplay so we don't need any
-- external include. Just a Lua variable + a fixed cycle order.
-- ---------------------------------------------------------------------------
local currentMode = 'TP';
local modeCycle = { 'TP','Acc','Sleep','Def','Blind','Drain' };  -- WS/AoE excluded from cycle

-- ---------------------------------------------------------------------------
-- /DRG jump-management config -- only active when subjob is DRG.
-- All defaults OFF; toggle via /lac fwd jumps on
-- ---------------------------------------------------------------------------
local jumpCfg = {
    autoJumps    = false,   -- master toggle
    dpsJumpOnCd  = true,    -- fire regular Jump on cooldown for DPS/TP
    shedOnAggro  = true,    -- fire High/Super Jump when mob is targeting me
    checkInterval= 2,       -- seconds between jump checks
};

local function advanceMode()
    for i, m in ipairs(modeCycle) do
        if (m == currentMode) then
            currentMode = modeCycle[(i % #modeCycle) + 1];
            return;
        end
    end
    currentMode = 'TP';
end

-- ---------------------------------------------------------------------------
-- Ranged weapons -- must match the ammo type or the game rejects the shot.
-- FILL THESE IN with whatever your Chharizard actually owns. Names must
-- match your inventory exactly. If you don't have one of the types, leave
-- it as "" -- modes that need it will just no-op.
-- ---------------------------------------------------------------------------
local ranged = {
    bow  = "Longbow",              -- Or: Composite Bow, Field Bow, Selene's Bow
    xbow = "Crossbow",        -- Or: Bronze Crossbow, Mars's Crossbow
    gun  = "",                     -- Onion Gun (Lv 1), Hand Cannon (Lv 20)
};

-- ---------------------------------------------------------------------------
-- Ammo library -- centralized so you can retune once, everywhere updates.
-- LuAshitaCast has no `Ammo.Bullet.TP`-style routing table like Windower --
-- instead you just reference `ammo.TP` (etc.) in each gear set below.
-- ---------------------------------------------------------------------------
local ammo = {
    -- Arrows (bow: Yoichinoyumi, Selene's Bow, etc.)
    TP           = "Fire Arrow",       -- steady damage arrow for TP building
    WS           = "Iron Arrow",       -- STR mod, WS damage
    Acc          = "Kabura Arrow",     -- higher Acc than Fire
    Sleep        = "Sleep Arrow",      -- sleeps target on hit (great for pulls)
    Def          = "Fang Arrow",       -- DEF-down proc arrow (situational)
    AoE          = "Bomb Arrow",       -- AoE damage from Barrage
    -- Bullets (gun: Culverin, Gastraphetes -- era, if RNG uses guns at 75)
    TP_Bullet    = "Bullet",
    WS_Bullet    = "Steel Bullet",
    -- Bolts (crossbow: subjob use mostly)
    TP_Bolt      = "Crossbow Bolt",    -- basic bolt for TP building via crossbow
    Blind        = "Blind Bolt",       -- Blinds target on hit
    Bloody       = "Bloody Bolt",      -- HP drain
    Acid         = "Acid Bolt",        -- DEF down (crossbow debuff)
    SleepBolt    = "Sleep Bolt",       -- sleep via crossbow
};

-- ---------------------------------------------------------------------------
-- Idle -- resting between fights, movement, downtime
-- ---------------------------------------------------------------------------
sets.Idle = {
    Head    = "Empress Hairpin",     -- HP+; swap to Optical Hat for evasion
    Neck    = "Peacock Amulet",      -- or Peacock Charm
    Ear1    = "Drone Earring",
    Ear2    = "Volley Earring",
    Body    = "Scorpion Harness",    -- DEX/AGI/HP
    Hands   = "Yigit Gages",         -- Store TP + Ranged Acc
    Ring1   = "Rajas Ring",
    Ring2   = "Toreador's Ring",     -- Ranged Acc
    Back    = "Amemet Mantle +1",
    Waist   = "Life Belt",
    Legs    = "Yigit Seraweels",     -- Store TP
    Feet    = "Rutter Sabatons",     -- movement speed
    -- Range and Ammo left OFF idle so you keep whatever you had
};

-- Extra move-speed swap layered on top of idle when walking
sets.Movement = {
    Feet    = "Rutter Sabatons",     -- +25% movement (Prowler works too)
};

-- ---------------------------------------------------------------------------
-- Engaged TP -- meleeing (rare on RNG but happens for skill-up etc.)
-- ---------------------------------------------------------------------------
sets.TP = {
    Head    = "Optical Hat",
    Neck    = "Peacock Amulet",
    Ear1    = "Drone Earring",
    Ear2    = "Volley Earring",
    Body    = "Scorpion Harness",
    Hands   = "Yigit Gages",
    Ring1   = "Rajas Ring",
    Ring2   = "Sniper's Ring",
    Back    = "Amemet Mantle +1",
    Waist   = "Swift Belt",
    Legs    = "Byakko's Haidate",    -- Haste
    Feet    = "Yigit Crackows",
};

-- ---------------------------------------------------------------------------
-- Preshot -- Snapshot/Rapid Shot phase (aim animation shortening)
-- Ammo NOT swapped here -- it's a stored ammo type, changing it mid-aim
-- can cancel your shot on some servers. Set it in Midshot instead.
-- ---------------------------------------------------------------------------
sets.Preshot = {
    Head    = "Bison Warbonnet",     -- +Rapid Shot
    Ear1    = "Volley Earring",      -- +Rapid Shot
    Ear2    = "Volley Earring",
    Body    = "Scorpion Harness",
    Hands   = "Yigit Gages",         -- +Snapshot
    Ring1   = "Puissance Ring",      -- if available
    Ring2   = "Toreador's Ring",
    Back    = "Amemet Mantle +1",
    Waist   = "Swift Belt",          -- +2% Ranged Haste
    Legs    = "Yigit Seraweels",
    Feet    = "Yigit Crackows",
};

-- ---------------------------------------------------------------------------
-- Midshot -- Ranged Attack / Accuracy phase of the shot (AMMO SWAPS HERE)
-- ---------------------------------------------------------------------------
sets.Midshot = {
    Ammo    = ammo.TP,               -- Fire Arrow -- see ammo table at top
    Head    = "Optical Hat",         -- Accuracy
    Neck    = "Peacock Amulet",      -- Ranged Acc +10
    Ear1    = "Drone Earring",       -- Ranged Attack +5
    Ear2    = "Volley Earring",
    Body    = "Scorpion Harness",
    Hands   = "Yigit Gages",
    Ring1   = "Rajas Ring",
    Ring2   = "Toreador's Ring",
    Back    = "Amemet Mantle +1",
    Waist   = "Life Belt",           -- +10 Acc
    Legs    = "Byakko's Haidate",
    Feet    = "Rutter Sabatons",
};

-- Accuracy override -- toggle via /lac chharizard acc
sets.MidshotAcc = {
    Ammo    = ammo.Acc,              -- Kabura Arrow -- higher Acc than TP
    Head    = "Optical Hat",
    Neck    = "Peacock Amulet",
    Ear1    = "Assault Earring",     -- +Acc
    Ear2    = "Volley Earring",
    Body    = "Ryl.Ftm. Jerkin",     -- Ranger AF body
    Hands   = "Ryl.Ftm. Gloves",
    Ring1   = "Toreador's Ring",
    Ring2   = "Longshot Ring",       -- if you have it
    Back    = "Amemet Mantle +1",
    Waist   = "Life Belt",
    Legs    = "Yigit Seraweels",
    Feet    = "Yigit Crackows",
};

-- Sleep-pull mode: fire a Sleep Arrow to pull safely.
-- Activate: /lac chharizard sleep    (toggles the flag)
sets.MidshotSleep = {
    Ammo    = ammo.Sleep,            -- Sleep Arrow
    -- Sleep proc rate is not gear-boosted; keep normal ranged Acc gear.
    Head    = "Optical Hat",
    Neck    = "Peacock Amulet",
    Body    = "Scorpion Harness",
    Hands   = "Yigit Gages",
    Ring1   = "Rajas Ring",
    Ring2   = "Toreador's Ring",
    Back    = "Amemet Mantle +1",
    Waist   = "Life Belt",
    Legs    = "Byakko's Haidate",
    Feet    = "Rutter Sabatons",
};

-- Def-down mode: Fang Arrow procs DEF-down on the target (useful softening)
sets.MidshotDef = {
    Ammo    = ammo.Def,              -- Fang Arrow
    Head    = "Optical Hat",
    Neck    = "Peacock Amulet",
    Body    = "Scorpion Harness",
    Hands   = "Yigit Gages",
    Ring1   = "Rajas Ring",
    Ring2   = "Toreador's Ring",
    Back    = "Amemet Mantle +1",
    Waist   = "Life Belt",
    Legs    = "Byakko's Haidate",
    Feet    = "Rutter Sabatons",
};

-- ---------------------------------------------------------------------------
-- Crossbow / Bolt modes -- for /THF, /BRD, /NIN subs firing bolts for proc
-- effects. These get equipped when you switch to a crossbow AND select the
-- matching mode (or use the direct /lac chharizard <mode> command below).
-- Bolts don't get gear bonuses -- Acc/Rng.Att gear is what matters for the
-- proc rate itself, so these mirror Midshot with just the Ammo slot changed.
-- ---------------------------------------------------------------------------

sets.MidshotBolt = {                 -- basic bolt TP (mode: 'Bolt')
    Ammo = ammo.TP_Bolt,             -- "Bolt"
    Head = "Optical Hat", Neck = "Peacock Amulet",
    Ear1 = "Drone Earring", Ear2 = "Volley Earring",
    Body = "Scorpion Harness", Hands = "Yigit Gages",
    Ring1 = "Rajas Ring", Ring2 = "Toreador's Ring",
    Back = "Amemet Mantle +1", Waist = "Life Belt",
    Legs = "Byakko's Haidate", Feet = "Rutter Sabatons",
};

sets.MidshotBlind = {                -- blind proc (mode: 'Blind')
    Ammo = ammo.Blind,               -- "Blind Bolt"
    Head = "Optical Hat", Neck = "Peacock Amulet",
    Ear1 = "Drone Earring", Ear2 = "Volley Earring",
    Body = "Scorpion Harness", Hands = "Yigit Gages",
    Ring1 = "Rajas Ring", Ring2 = "Toreador's Ring",
    Back = "Amemet Mantle +1", Waist = "Life Belt",
    Legs = "Byakko's Haidate", Feet = "Rutter Sabatons",
};

sets.MidshotAcid = {                 -- DEF-down proc via crossbow (mode: 'Acid')
    Ammo = ammo.Acid,                -- "Acid Bolt"
    Head = "Optical Hat", Neck = "Peacock Amulet",
    Ear1 = "Drone Earring", Ear2 = "Volley Earring",
    Body = "Scorpion Harness", Hands = "Yigit Gages",
    Ring1 = "Rajas Ring", Ring2 = "Toreador's Ring",
    Back = "Amemet Mantle +1", Waist = "Life Belt",
    Legs = "Byakko's Haidate", Feet = "Rutter Sabatons",
};

sets.MidshotBloody = {               -- HP drain (mode: 'Bloody')
    Ammo = ammo.Bloody,              -- "Bloody Bolt"
    Head = "Optical Hat", Neck = "Peacock Amulet",
    Ear1 = "Drone Earring", Ear2 = "Volley Earring",
    Body = "Scorpion Harness", Hands = "Yigit Gages",
    Ring1 = "Rajas Ring", Ring2 = "Toreador's Ring",
    Back = "Amemet Mantle +1", Waist = "Life Belt",
    Legs = "Byakko's Haidate", Feet = "Rutter Sabatons",
};

sets.MidshotSleepBolt = {            -- crossbow sleep (mode: 'SleepBolt')
    Ammo = ammo.SleepBolt,           -- "Sleep Bolt"
    Head = "Optical Hat", Neck = "Peacock Amulet",
    Ear1 = "Drone Earring", Ear2 = "Volley Earring",
    Body = "Scorpion Harness", Hands = "Yigit Gages",
    Ring1 = "Rajas Ring", Ring2 = "Toreador's Ring",
    Back = "Amemet Mantle +1", Waist = "Life Belt",
    Legs = "Byakko's Haidate", Feet = "Rutter Sabatons",
};

-- ---------------------------------------------------------------------------
-- Weaponskills
-- ---------------------------------------------------------------------------
sets.WS = {};

-- Slug Shot -- STR/Ranged Attack, Adaman Mufflers give bonus damage
sets.WS["Slug Shot"] = {
    Ammo    = ammo.WS,               -- Iron Arrow (STR mod)
    Head    = "Optical Hat",
    Neck    = "Peacock Amulet",
    Ear1    = "Drone Earring",
    Ear2    = "Volley Earring",
    Body    = "Scorpion Harness",
    Hands   = "Adaman Mufflers",     -- +Slug Shot damage
    Ring1   = "Rajas Ring",
    Ring2   = "Sniper's Ring",
    Back    = "Cerberus Mantle",     -- STR / Crit
    Waist   = "Scout's Belt",        -- STR
    Legs    = "Byakko's Haidate",
    Feet    = "Yigit Crackows",
};

-- Sidewinder -- AGI-based, 40% AGI mod
sets.WS["Sidewinder"] = {
    Ammo    = ammo.WS,               -- Iron Arrow
    Head    = "Optical Hat",
    Neck    = "Peacock Amulet",
    Ear1    = "Drone Earring",
    Ear2    = "Volley Earring",
    Body    = "Scorpion Harness",
    Hands   = "Yigit Gages",
    Ring1   = "Rajas Ring",
    Ring2   = "Sniper's Ring",
    Back    = "Amemet Mantle +1",    -- AGI / Ranged Attack
    Waist   = "Scout's Belt",
    Legs    = "Yigit Seraweels",
    Feet    = "Yigit Crackows",
};

-- Detonator -- 30% AGI mod (shares Sidewinder gear)
sets.WS["Detonator"]  = sets.WS["Sidewinder"];
sets.WS["Blast Shot"] = sets.WS["Slug Shot"];

-- Default fallback for un-listed WS
sets.WS.Default = sets.WS["Sidewinder"];

-- ---------------------------------------------------------------------------
-- Job Abilities
-- ---------------------------------------------------------------------------
sets.JA = {};

sets.JA["Barrage"] = {
    Ammo    = ammo.AoE,              -- Bomb Arrow for AoE burst; swap to ammo.TP for single-target
    Hands   = "Ryl.Ftm. Gloves",     -- RNG AF hands enhance Barrage
};

sets.JA["Sharpshot"] = {
    Legs    = "Ryl.Ftm. Trousers",   -- RNG AF legs enhance Sharpshot
};

sets.JA["Bounty Shot"] = {
    -- Horizon custom TH gear if it exists; otherwise omit
    -- Waist   = "Chaac Belt",
};

sets.JA["Scavenge"] = {
    Feet    = "Orion Socks",         -- Scavenge enhance if you have relic feet
};

sets.JA["Camouflage"] = {
    Body    = "Orion Jerkin",        -- Camouflage enhance
};

-- ---------------------------------------------------------------------------
-- Magic (RNG casts nothing important, mostly Sub-job spells)
-- ---------------------------------------------------------------------------
sets.Precast = {};
sets.Precast.FastCast = {
    Ear2    = "Loquac. Earring",     -- FC+2
    Body    = "Homam Corazza",       -- FC+2 if you have it
};

sets.Midcast = {};
sets.Midcast.Utsusemi = {
    Head    = "Walahra Turban",      -- fast cast
    Feet    = "Yigit Crackows",
};

sets.Midcast.Healing = {
    Ring1   = "Ether Ring",          -- healing cure potency
};

-- ============================================================================
-- Event handlers
-- ============================================================================

profile.OnLoad = function()
    gSettings.AllowAddSet = true;
    Sub.echo("[Chharizard RNG] Profile loaded.");
end

profile.OnUnload = function()
    Sub.echo("[Chharizard RNG] Profile unloaded.");
end


-- Is subjob DRG?
local function subIsDrg()
    local pid = AshitaCore:GetMemoryManager():GetPlayer():GetSubJob();
    local name = AshitaCore:GetResourceManager():GetString('jobs.names_abbr', pid);
    if (type(name) == 'string') then name = name:trimend('\x00'); end
    return name == 'DRG';
end

-- Am I engaged with something?
local function amEngaged()
    return gData.GetPlayer().Status == 'Engaged';
end

-- Am I the current target of the mob I'm attacking? -> "I have hate."
-- Returns the mob's entity index if yes, otherwise nil.
local function mobTargetingMe()
    local myIdx = selfIndex();
    if (not myIdx or myIdx == 0) then return nil; end
    -- We're engaged; find our target locked mob via player memory
    local entMgr = AshitaCore:GetMemoryManager():GetEntity();
    local partyMgr = AshitaCore:GetMemoryManager():GetParty();
    local mySid = partyMgr:GetMemberServerId(0);
    -- Loop nearby entity indices (0..2303 is the mob range) but check only
    -- entities that are alive + within claim distance.
    for i = 0x400, 0x8FF do   -- non-player entity range in FFXI memory
        if (entMgr:GetServerId(i) ~= 0) and (entMgr:GetHPPercent(i) > 0) then
            local claim = entMgr:GetClaimStatus(i);
            local targetIdx = entMgr:GetTargetIndex(i);
            if (targetIdx == myIdx) then
                -- This mob is targeting me
                return i;
            end
        end
    end
    return nil;
end

-- Recast helpers. Returns ms remaining, 0 = ready.
local function abilityRecast(id)
    return AshitaCore:GetMemoryManager():GetRecast():GetAbilityTimer(id) or 999999;
end

-- Fire a JA. Returns true if we queued it.
local function fireJump(name)
    AshitaCore:GetChatManager():QueueCommand(1,
        string.format('/ja "%s" <me>', name));
    Sub.echo(string.format('[RNG /DRG] %s -> shed hate', name));
    return true;
end

local lastJumpAttempt = 0;
profile._jumpTick = function()
    if (gProfile ~= profile) then return; end
    if (not jumpCfg.autoJumps) then return; end
    if (not subIsDrg()) then return; end
    if (not amEngaged()) then return; end
    local now = os.time();
    if (now - lastJumpAttempt < jumpCfg.checkInterval) then return; end
    lastJumpAttempt = now;

    -- Hate-spike priority: mob is targeting me -> High/Super Jump to shed
    if (jumpCfg.shedOnAggro and mobTargetingMe()) then
        if (abilityRecast(jumpRecastId.SuperJump) == 0) then
            fireJump('Super Jump'); return;
        elseif (abilityRecast(jumpRecastId.HighJump) == 0) then
            fireJump('High Jump'); return;
        end
        -- Both on cooldown, fall through to normal jump for damage
    end

    -- Otherwise: regular Jump on cooldown for DPS/TP
    if (jumpCfg.dpsJumpOnCd and abilityRecast(jumpRecastId.Jump) == 0) then
        AshitaCore:GetChatManager():QueueCommand(1, '/ja "Jump" <t>');
        return;
    end
end

profile.HandleDefault = function()
    gFunc.EquipSet(sets.Idle);
    if (gData.GetPlayer().IsMoving) then
        gFunc.EquipSet(sets.Movement);
    end
    Sub.tick(true);  -- shared subjob automation tick (DRG/NIN/SAM/etc.)
end

profile.HandleEngaged = function()
    gFunc.EquipSet(sets.TP);
    Sub.tick(true);
end

profile.HandlePreshot = function()
    gFunc.EquipSet(sets.Preshot);
end

profile.HandleMidshot = function()
    -- Pick the midshot set by currentMode (a plain Lua var, above).
    if     (currentMode == 'Acc')       then gFunc.EquipSet(sets.MidshotAcc);
    elseif (currentMode == 'Sleep')     then gFunc.EquipSet(sets.MidshotSleep);
    elseif (currentMode == 'Def')       then gFunc.EquipSet(sets.MidshotDef);
    elseif (currentMode == 'Bolt')      then gFunc.EquipSet(sets.MidshotBolt);
    elseif (currentMode == 'Blind')     then gFunc.EquipSet(sets.MidshotBlind);
    elseif (currentMode == 'Acid')      then gFunc.EquipSet(sets.MidshotAcid);
    elseif (currentMode == 'Bloody')    then gFunc.EquipSet(sets.MidshotBloody);
    elseif (currentMode == 'SleepBolt') then gFunc.EquipSet(sets.MidshotSleepBolt);
    else                                     gFunc.EquipSet(sets.Midshot);   -- default TP
    end
end

profile.HandleWeaponskill = function()
    local ws = gData.GetAction().Name;
    if (sets.WS[ws]) then
        gFunc.EquipSet(sets.WS[ws]);
    else
        gFunc.EquipSet(sets.WS.Default);
    end
end

profile.HandleAbility = function()
    local ja = gData.GetAction().Name;
    if (sets.JA[ja]) then
        gFunc.EquipSet(sets.JA[ja]);
    end
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

-- ---------------------------------------------------------------------------
-- Ammo dispatch by weapon type. When you request a mode ("sleep", "def",
-- etc.), we look up your currently-equipped Range weapon and pick the ammo
-- that matches THAT weapon type. One command works regardless of weapon.
-- ---------------------------------------------------------------------------
local ammoMap = {
    bow = {
        TP    = ammo.TP,       -- Fire Arrow
        Acc   = ammo.Acc,      -- Kabura Arrow
        Sleep = ammo.Sleep,    -- Sleep Arrow
        Def   = ammo.Def,      -- Fang Arrow (DEF-down proc)
        WS    = ammo.WS,       -- Iron Arrow
        AoE   = ammo.AoE,      -- Bomb Arrow (Barrage)
    },
    xbow = {
        TP    = ammo.TP_Bolt,  -- Crossbow Bolt
        Acc   = ammo.TP_Bolt,  -- no dedicated Acc bolt; use standard
        Sleep = ammo.SleepBolt,-- Sleep Bolt
        Def   = ammo.Acid,     -- Acid Bolt procs DEF-down on xbow
        Blind = ammo.Blind,    -- Blind Bolt
        Drain = ammo.Bloody,   -- Bloody Bolt
        WS    = ammo.TP_Bolt,  -- Crossbow Bolt
    },
    gun = {
        TP    = ammo.TP_Bullet,-- Bullet
        Acc   = ammo.TP_Bullet,
        WS    = ammo.WS_Bullet,-- Steel Bullet
    },
};

-- Detect what type of ranged weapon is currently in the Range slot by
-- inspecting its name. Returns 'bow' / 'xbow' / 'gun' / nil.
local function detectWeaponType()
    local eq = gData.GetEquipment();
    if (not eq or not eq.Range or not eq.Range.Name) then return nil; end
    local name = eq.Range.Name:lower();
    -- Check most specific patterns first (crossbow contains "bow" too)
    if (name:find("crossbow")) then return 'xbow'; end
    if (name:find("zamburak"))  then return 'xbow'; end
    if (name:find("cannon"))    then return 'gun';  end
    if (name:find("culverin"))  then return 'gun';  end
    if (name:find("gun"))       then return 'gun';  end
    if (name:find("bow"))       then return 'bow';  end
    if (name:find("yumi"))      then return 'bow';  end  -- Yoichinoyumi etc.
    return nil;
end

-- Pick the right ammo for the current weapon + requested mode.
local function pickAmmo(mode)
    local wtype = detectWeaponType();
    if (not wtype) then return nil, nil; end
    local map = ammoMap[wtype];
    if (not map) then return nil, wtype; end
    return map[mode], wtype;
end

profile.HandleCommand = function(args)
    if (#args < 1) then return; end

    -- Shared subjob commands (jumps/utsu/hasso/etc) — try library first
    if (Sub.handleCommand(args)) then return; end

    -- Diagnostic: print what we see. Run `/lac fwd debug` to inspect.
    if (args[1] == 'debug') then
        local eq = gData.GetEquipment();
        if (not eq) then
            Sub.echo('[RNG] gData.GetEquipment() returned nil.');
            return;
        end
        if (not eq.Range) then
            Sub.echo('[RNG] No Range slot equipped.');
            return;
        end
        local name = eq.Range.Name or '<no name>';
        local lname = name:lower();
        Sub.echo(string.format('[RNG] Range slot name: "%s" (lower: "%s")', name, lname));
        Sub.echo(string.format('[RNG] Detected weapon type: %s',
            tostring(detectWeaponType())));
        for mode,item in pairs(ammoMap[detectWeaponType() or 'bow'] or {}) do
            Sub.echo(string.format('   %s -> %s', mode, item));
        end
        -- Jump state
        Sub.echo(string.format('[RNG] Sub is DRG: %s', tostring(subIsDrg())));
        Sub.echo(string.format('[RNG] Auto-jumps: %s (shed=%s, dps=%s)',
            tostring(jumpCfg.autoJumps),
            tostring(jumpCfg.shedOnAggro),
            tostring(jumpCfg.dpsJumpOnCd)));
        if (subIsDrg()) then
            Sub.echo(string.format('[RNG] Recasts: Jump %dms  High %dms  Super %dms',
                abilityRecast(jumpRecastId.Jump),
                abilityRecast(jumpRecastId.HighJump),
                abilityRecast(jumpRecastId.SuperJump)));
            local m = mobTargetingMe();
            Sub.echo(string.format('[RNG] Mob targeting me: %s', m and ('idx '..m) or 'no'));
        end
        return;
    end

    -- Optional: explicit weapon swap. /lac chharizard bow | xbow | gun.
    -- Handy for switching Range slot when you want to change ammo family.
    local weaponSwap = { bow = ranged.bow, xbow = ranged.xbow, gun = ranged.gun };
    if (weaponSwap[args[1]:lower()]) then
        local weap = weaponSwap[args[1]:lower()];
        if (weap and weap ~= "") then
            gFunc.ForceEquipSet({ Range = weap });
            Sub.echo('[RNG] Weapon: ' .. weap);
        else
            Sub.echo('[RNG] No ' .. args[1] .. ' configured in `ranged` table.');
        end
        return;
    end

    -- Cycle: TP -> Acc -> Sleep -> Def -> Blind -> Drain
    if (args[1] == 'ammo') then
        advanceMode();
        local item, wtype = pickAmmo(currentMode);
        if (item) then
            gFunc.ForceEquipSet({ Ammo = item });
            Sub.echo(string.format('[RNG] Mode %s -> %s (%s)', currentMode, item, wtype));
        else
            Sub.echo(string.format('[RNG] Mode %s: no ammo for current weapon (%s).',
                currentMode, tostring(wtype)));
        end
        return;
    end

    -- Mode shortcuts. Same mode, ammo picked by current weapon type.
    local modes = {
        tp    = 'TP',    acc   = 'Acc',   sleep = 'Sleep',
        def   = 'Def',   blind = 'Blind', drain = 'Drain',
        ws    = 'WS',    aoe   = 'AoE',
    };
    local m = modes[args[1]:lower()];
    if (m) then
        currentMode = m;
        local item, wtype = pickAmmo(m);
        if (item) then
            gFunc.ForceEquipSet({ Ammo = item });
            Sub.echo(string.format('[RNG] Mode %s -> %s (weapon: %s)', m, item, wtype));
        elseif (wtype) then
            Sub.echo(string.format('[RNG] Mode %s not available for %s weapon.', m, wtype));
        else
            Sub.echo('[RNG] No ranged weapon equipped -- can`t pick ammo.');
        end
        return;
    end
end

return profile;
