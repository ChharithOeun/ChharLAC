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
    preset        = 'harle',-- NAMED preset -- harle/blm/whm/rdm/tank/turtle/meva/rng/rngtank/lvl60
    mode          = 'Melee',-- (legacy fallback -- only used if preset is empty and head/frame unset)
    head          = '',     -- (legacy manual override)
    frame         = '',     -- (legacy manual override)
    overdrive     = false,  -- toggle: Overdrive mindset (Wind-heavy for Sharpshot bursts)
    forceWS       = false,  -- toggle: WS-window override (fires forcing element 70-99% TP)
    chharControl  = true,   -- toggle: auto-load/unload ChharControl sidecart with PUP.lua
    petOilHp      = 'Automat. Oil +3',  -- HP restore item
};

-- ---------------------------------------------------------------------------
-- Maneuver model (per Poof's Puppetmaster Guide + sruon/AutoPUP).
--
-- Each entry is a DECLARATIVE TARGET: "I want this many of each buff active"
-- plus an optional `wsForce` element that gets prioritized when the pet is
-- in the WS-TP window (70-99%). This forces the preferred WS:
--   * Valoredge frame + Dark maneuver -> Cannibal Blade
--   * Sharpshot frame + Thunder maneuver -> Daze
--   * Harlequin/Stormwaker frames share Knockout -- no forcing needed
--
-- Lookup priority:
--   1. headFrameToPattern['<Head>/<Frame>']  (exact pair)
--   2. headToPattern['<Head>']               (head only -- generic frame)
--   3. manPatterns[cfg.mode]                 (back-compat role mode)
--
-- Guide note on Sharpshot: "ideal circumstances, Wind, Fire, Thunder, will
-- suffice" and "be sure not to have 2 Fire maneuvers up prior to WS or you'll
-- force Arcuballista regardless." Our pattern of {wind=1, fire=1, thunder=1}
-- hits that exactly, and the WS-force elem is thunder so Daze is picked.
--
-- Guide note on Valoredge: "Dark Maneuver also helps trigger Cannibal Blade
-- if I have other maneuvers up ... avoid 2 thunder or 2 fire or you'll
-- trigger one of the other two weaponskills even if Dark Maneuver up."
-- ---------------------------------------------------------------------------
local manPatterns = {
    Melee        = { fire=2, light=1 },
    Ranged       = { wind=1, fire=1, light=1 },
    HybridRanged = { fire=1, light=1, thunder=1 },
    Tank         = { earth=2, light=1 },
    LightTank    = { earth=1, light=1, water=1 },
    Magic        = { ice=1, dark=1, light=1 },
    Heal         = { light=2, dark=1 },
    Nuke         = { dark=2, light=1 },
};

-- Head-only fallback (used when preset is '' and no exact head/frame match).
local headToPattern = {
    Valoredge   = { earth=2, light=1,                wsForce='dark'    },
    Harlequin   = { fire=1,  light=1, earth=1                          },
    Sharpshot   = { wind=1,  fire=1, thunder=1,      wsForce='thunder' },
    Stormwaker  = { ice=1,   dark=1, light=1                           },
    Soulsoother = { light=2, dark=1                                    },
    Spiritreaver= { dark=2,  light=1                                   },
};

-- =============================================================================
-- NAMED PRESETS -- the primary setup system (per user's workflow).
-- `/lac fwd setup <preset>` locks the maneuver pattern AND tells ChharControl
-- (sidecart addon) to echo/apply the matching attachment set.
--
-- `pattern` is the base maneuver target per element (sums <= 3).
-- `wsForce` is the element to prioritize when pet TP is in WS window.
-- `strobeFire` means: on turtle preset, fire-maneuver is only put up when the
--   automaton Strobe JA (30s recast) is ready, so fire boost actually triggers
--   the provoke proc instead of being wasted on cooldown.
-- =============================================================================
local presets = {
    harle = {
        head='Harlequin', frame='Harlequin',
        pattern={ light=1, fire=1, thunder=1 },
        desc='Harlequin + Harlequin -- light/fire/thunder (general DD)',
    },
    blm = {
        head='Spiritreaver', frame='Stormwaker',
        pattern={ ice=2, dark=1 },
        desc='Spiritreaver + Stormwaker -- ice/ice/dark (nuke/burst)',
    },
    whm = {
        head='Soulsoother', frame='Stormwaker',
        pattern={ water=1, light=1, dark=1 },
        desc='Soulsoother + Stormwaker -- water/light/dark (healer)',
    },
    rdm = {
        head='Stormwaker', frame='Stormwaker',
        pattern={ dark=1, water=1, ice=1 },
        desc='Stormwaker + Stormwaker -- dark/water/ice (DD caster)',
    },
    tank = {
        head='Valoredge', frame='Valoredge',
        pattern={ earth=1, fire=1, light=1 }, wsForce='dark',
        desc='Valoredge + Valoredge -- earth/fire/light + Dark @ WS (Cannibal Blade force)',
    },
    turtle = {
        head='Soulsoother', frame='Valoredge',
        pattern={ light=1, water=1, earth=1 }, strobeFire=true,
        desc='Soulsoother + Valoredge -- light/water/earth + Fire when Strobe ready',
    },
    meva = {
        head='Soulsoother', frame='Harlequin',
        pattern={ light=1, water=1, dark=1 },
        desc='Soulsoother + Harlequin -- light/water/dark (magic-eva tank)',
    },
    rng = {
        head='Sharpshot', frame='Sharpshot',
        pattern={ wind=2, fire=1 }, wsForce='thunder',
        desc='Sharpshot + Sharpshot -- wind/wind/fire + Thunder @ WS (Daze force)',
    },
    rngtank = {
        head='Valoredge', frame='Sharpshot',
        pattern={ light=1, fire=1, wind=1 }, wsForce='thunder',
        desc='Valoredge + Sharpshot -- light/fire/wind + Thunder @ WS (Daze force)',
    },
    lvl60 = {
        head='Valoredge', frame='Valoredge',
        pattern={ light=1, water=1, thunder=1 }, wsForce='dark',
        desc='Valoredge + Valoredge -- light/water/thunder + Dark @ WS (BCNM level cap)',
    },
};

-- Overdrive patterns: when cfg.overdrive==true, these override normal lookup.
-- Overdrive JA is a damage/accuracy burst, best paired with Wind for attack
-- speed. Still respects the frame's wsForce for sub-WS behavior.
local overdrivePatterns = {
    Valoredge = { wind=1, earth=1, light=1, wsForce='dark'    },
    Sharpshot = { wind=2, thunder=1,        wsForce='thunder' },
    Harlequin = { wind=2, fire=1                              },
    Stormwaker= { wind=1, ice=1,   light=1                    },
};

-- Strobe-ready tracking (for turtle preset).  Strobe is an automaton
-- Provoke-equivalent with a 30s native cooldown.  We mark it "last fired"
-- when we see "Chharmaton uses Strobe" in chat; the strobeReady() helper
-- returns true when 30s has passed and fire-maneuver may be put up to
-- boost its land chance.
local STROBE_CD    = 30;    -- seconds
local lastStrobeAt = 0;

local function strobeReady()
    return (os.time() - lastStrobeAt) >= STROBE_CD;
end

-- Pet TP window where we prioritize the WS-forcing maneuver.
-- 70 is just below the point Attuner can transpose; 99 is just before fire.
local WS_TP_WINDOW_LO = 700;    -- pet.TP is 0..3000 scale in Ashita memory
local WS_TP_WINDOW_HI = 2990;   -- fire tends to land at 100% exact

-- Legacy mapping -- kept so `/lac fwd head Sharpshot` still works alone.
local headToMode = {
    Valoredge='Tank', Harlequin='Melee', Sharpshot='Ranged',
    Stormwaker='Magic', Soulsoother='Heal', Spiritreaver='Nuke',
};

-- Resolve the active maneuver pattern.  Returns (pattern_table, source).
-- Priority:
--   1. Overdrive override (frame-keyed) if cfg.overdrive
--   2. Named preset (cfg.preset) -- the primary setup system
--   3. Head+Frame-derived pattern via headToPattern (legacy manual)
--   4. Legacy role mode (back-compat)
local function getActivePattern()
    -- Overdrive override: picks frame-based from preset if preset set, else cfg.frame
    if (cfg.overdrive) then
        local fr = (cfg.preset ~= '' and presets[cfg.preset] and presets[cfg.preset].frame)
                or cfg.frame;
        local p = overdrivePatterns[fr];
        if (p) then return p, 'overdrive/'..fr; end
    end
    -- Named preset
    if (cfg.preset and cfg.preset ~= '' and presets[cfg.preset]) then
        local pr = presets[cfg.preset];
        -- Build a flat pattern table with wsForce/strobeFire tacked on.
        local p = {};
        for k, v in pairs(pr.pattern) do p[k] = v; end
        p.wsForce    = pr.wsForce;
        p.strobeFire = pr.strobeFire;
        return p, 'preset:'..cfg.preset;
    end
    -- Head-only legacy fallback
    if (cfg.head ~= '') then
        local p = headToPattern[cfg.head];
        if (p) then return p, cfg.head; end
    end
    -- Legacy role mode
    return manPatterns[cfg.mode] or manPatterns.Melee, 'mode:'..cfg.mode;
end

-- Buff IDs from AutoPUP/pup_ids.lua (confirmed retail; same on era).
local MAN_BUFF = {
    fire=300, ice=301, wind=302, earth=303,
    thunder=304, water=305, light=306, dark=307,
};
local OVERLOAD_ID = 299;
-- Overdrive status ID (PUP JA grants this buff on player for ~60s).
-- If your server uses a different ID, the text_in hook below is the backup
-- trigger -- "<player> uses Overdrive" flips cfg.overdrive on regardless.
local OVERDRIVE_ID = 253;

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

-- Session-level flag: PUP.lua's OnLoad fires on EVERY zone change, but we
-- only want to load the sidecar addons ONCE.  Flag survives inside the
-- Lua state until the addon chain is manually unloaded.
_G.__chharPupSidecarsLoaded = _G.__chharPupSidecarsLoaded or false;

profile.OnLoad = function()
    gSettings.AllowAddSet = true;
    Burden.hook();
    Burden.hookHUD();
    -- Only load sidecars on the FIRST OnLoad of this session.  Subsequent
    -- zone-triggered OnLoads skip the load commands -- no chat spam.
    if (not _G.__chharPupSidecarsLoaded) then
        AshitaCore:GetChatManager():QueueCommand(1, '/addon load chharmaton');
        if (cfg.chharControl) then
            AshitaCore:GetChatManager():QueueCommand(1, '/addon load chharcontrol');
            if (cfg.preset and cfg.preset ~= '') then
                AshitaCore:GetChatManager():QueueCommand(1,
                    '/cc preset ' .. cfg.preset);
            end
        end
        _G.__chharPupSidecarsLoaded = true;
        Sub.echo("[Chharizard PUP] Profile loaded + sidecars initialized.");
    else
        Sub.echo("[Chharizard PUP] Profile reloaded (sidecars already running).");
    end
end

profile.OnUnload = function()
    Burden.unhook();
    -- OnUnload fires on BOTH zone change AND real job change.  To tell them
    -- apart, check the player's current main job.  PUP == 18.
    --   Main job still PUP  -> zone change, keep sidecars running
    --   Main job != PUP     -> real job change, drop the sidecars so they're
    --                          not sitting there consuming resources on WAR
    local okP, player = pcall(gData.GetPlayer);
    local mainJob = okP and player and (player.MainJob or player.MainJobId);
    local isPupStill = (mainJob == 18 or mainJob == 'PUP');
    if (not isPupStill) then
        AshitaCore:GetChatManager():QueueCommand(1, '/addon unload chharmaton');
        if (cfg.chharControl) then
            AshitaCore:GetChatManager():QueueCommand(1, '/addon unload chharcontrol');
        end
        _G.__chharPupSidecarsLoaded = false;   -- so next PUP load re-fires
        Sub.echo("[Chharizard PUP] Job change away from PUP -- sidecars unloaded.");
    else
        Sub.echo("[Chharizard PUP] Zone change -- sidecars left running.");
    end
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

-- In-flight tracking.  When we QueueCommand a maneuver, the game takes 1-3s
-- to actually land the buff + show it in memory.  During that window
-- readBuffs() returns the OLD count, so without this tracker we'll happily
-- fire a 2nd maneuver thinking we're still at 2/3 -- and overload.
--
-- Each entry: inflightUntil[elem] = os.time() + INFLIGHT_WINDOW
-- Any entry whose timestamp is in the future counts as "present" for cap math.
-- (Declared HERE, before the helper functions that reference it, so Lua binds
--  them to this local rather than silently falling through to a nil global.)
local inflightUntil    = {};
local INFLIGHT_WINDOW  = 4;

-- Fire log: every maneuver fire's timestamp (ours OR manually macroed, caught
-- via text_in).  Capped at the full maneuver duration so the hard cap below
-- works even if the server uses non-standard buff IDs we can't read.
local fireLog          = {};
local MANEUVER_LIFE    = 65;    -- seconds; base duration 60s + a few of slack

-- How many in-flight (just-fired, not yet registered) maneuvers exist.
local function inflightTotal()
    local n = 0;
    local now = os.time();
    for _, t in pairs(inflightUntil) do
        if (t > now) then n = n + 1; end
    end
    return n;
end

-- Count of a specific element in-flight (0 or 1 under normal use).
local function inflightOf(elem)
    local t = inflightUntil[elem];
    return (t and t > os.time()) and 1 or 0;
end

-- Count every fire within the maneuver-duration window.  This is the HARD
-- overload cap and does not depend on reading buffs correctly from memory.
local function recentFiresTotal()
    local now = os.time();
    -- Prune expired entries in place
    while (#fireLog > 0 and (now - fireLog[1]) > MANEUVER_LIFE) do
        table.remove(fireLog, 1);
    end
    return #fireLog;
end

-- Record a fire into both inflight (short window) and fireLog (full life).
local function recordFire(elem)
    local now = os.time();
    inflightUntil[elem] = now + INFLIGHT_WINDOW;
    fireLog[#fireLog + 1] = now;
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
-- (inflightUntil + INFLIGHT_WINDOW are declared higher up, before the
--  inflightTotal/inflightOf helpers that reference them.)
local firesByElem    = {};   -- elem -> list of os.time() of recent fires
-- Only re-fire the SAME element when it's near expiry (base buff = 60s).
-- Firing earlier causes stacked long-remaining buffs that overload Burden.
-- This is the Selindrles / AutoPUP model: trust buff count, don't age-refresh.
local MIN_SAME_ELEM_GAP = 55;   -- was 12 (overload bug); near-expiry refresh only
local MIN_ANY_FIRE_GAP  = 20;   -- was 12; stretch pacing so 3 fires span 60s
-- Debounce flaky buff reads: require 2 consecutive ticks of (have < want)
-- before trusting a wearoff.  Blocks single-tick packet jitter from firing.
local WEAROFF_CONFIRM_TICKS = 2;
local wearoffTicks = {};        -- [elem] = consecutive-low-read count
local everReached  = {};        -- [elem] = true once current >= want seen (priming done)
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

local function nextManeuverNeeded(buffs, pet)
    local pattern = getActivePattern();
    local now = os.time();

    -- WS-TP-window: if forcing is enabled and pet TP is in the pre-WS window
    -- and the pattern specifies a wsForce element that isn't already up,
    -- fire that FIRST (ahead of any other element).  This is how we force
    -- Cannibal Blade (Valoredge/dark) and Daze (Sharpshot/thunder).
    if (cfg.forceWS and pattern.wsForce and pet) then
        local tp = pet.TP or 0;
        if (tp >= WS_TP_WINDOW_LO and tp <= WS_TP_WINDOW_HI) then
            local f    = pattern.wsForce;
            local have = (buffs[MAN_BUFF[f]] or 0) + inflightOf(f);
            if (have < 1 and Burden.canFire(f)) then
                lastSeenCount[f] = buffs[MAN_BUFF[f]] or 0;
                return f;
            end
        end
    end

    -- Turtle preset: fire-maneuver gated on Strobe-ready. Add fire=1 to the
    -- pattern dynamically only when Strobe (30s recast) has recycled, so the
    -- fire boost actually procs Strobe instead of being wasted during CD.
    local effPattern = pattern;
    if (pattern.strobeFire and strobeReady()) then
        effPattern = {};
        for k, v in pairs(pattern) do effPattern[k] = v; end
        effPattern.fire = (effPattern.fire or 0) + 1;
    end

    local worn, aged = nil, nil;
    for _, elem in ipairs({'fire','ice','wind','earth','thunder','water','light','dark'}) do
        local want = effPattern[elem];
        if (want) then
            -- Count visible buffs + any just-fired for this element so we
            -- don't queue a 2nd fire during the ~2s packet-latency window.
            local have       = (buffs[MAN_BUFF[elem]] or 0) + inflightOf(elem);
            local wasHad     = (lastSeenCount[elem] or 0) >= want;
            local sinceFire  = now - (lastFiredAt[elem] or 0);
            local burdenOK   = Burden.canFire(elem);

            -- Debounce flaky buff reads: only count a wearoff if we've seen
            -- (have < want) for WEAROFF_CONFIRM_TICKS consecutive ticks AND
            -- enough time has passed since OUR last fire that the buff would
            -- plausibly actually have worn off (prevents re-firing while
            -- buffs still have 20+s left on the clock).
            if (have < want) then
                wearoffTicks[elem] = (wearoffTicks[elem] or 0) + 1;
            else
                wearoffTicks[elem] = 0;
            end
            local confirmed  = (wearoffTicks[elem] or 0) >= WEAROFF_CONFIRM_TICKS;
            local plausible  = sinceFire >= MIN_SAME_ELEM_GAP;  -- 50s floor

            if (have < want and wasHad and confirmed and plausible
                and not worn and burdenOK) then
                worn = elem;
            end
            -- (Removed the age-based auto-refire branch; it fired every 12s
            --  on any sub-want read and was the overload engine.  Now a
            --  re-fire requires a confirmed wearoff past the 50s plausibility
            --  floor -- i.e. the buff really dropped near the end of its life.)
            local cur = buffs[MAN_BUFF[elem]] or 0;
            lastSeenCount[elem] = cur;
            if (cur >= want) then everReached[elem] = true; end
        end
    end
    -- Priming case: the stack hasn't reached `want` yet (lastSeenCount keeps
    -- the HIGH-WATER mark across ticks, so once we've seen 2 for an element,
    -- a drop to 1 is a wearoff and goes through the confirmed branch above).
    -- Here we fire when the stack has never reached `want` and the global
    -- fire gap allows another queue -- lets BLM (ice=2) prime to 2 without
    -- needing a wearoff event.
    if (not worn) then
        for _, elem in ipairs({'fire','ice','wind','earth','thunder','water','light','dark'}) do
            local want = effPattern[elem];
            if (want) then
                local have    = (buffs[MAN_BUFF[elem]] or 0) + inflightOf(elem);
                local sinceEl = now - (lastFiredAt[elem] or 0);
                local priming = not everReached[elem];
                -- Keep per-element gap >= JA recast (12s) so we don't
                -- hammer the same element on consecutive ticks.
                if (have < want and priming and sinceEl >= 12
                    and Burden.canFire(elem)) then
                    worn = elem; break;
                end
            end
        end
    end

    return worn;
end

-- Hook text_in to catch:
--   1. Strobe usage by the automaton (for turtle preset)
--   2. Maneuver fires FROM THE PLAYER -- including macro-driven ones outside
--      our tick -- so we can mark that element in-flight and never queue a
--      second fire during the game's 2-3s packet-processing window.
ashita.events.register('text_in', 'pup_text_track', function(e)
    if (not e or not e.message) then return; end
    if (gProfile ~= profile) then return; end
    local msg = e.message;

    if (msg:find('uses Strobe')) then
        lastStrobeAt = os.time();
    end

    -- Overdrive trigger backup -- if the OVERDRIVE_ID buff detection misses
    -- on this server, this chat trigger still flips us into overdrive mode.
    -- The 60s wearoff is still handled by the buff check in autoTick (if the
    -- buff IS detectable); otherwise we leave it on until manually toggled.
    if (msg:match('uses [Oo]verdrive')) then
        if (not cfg.overdrive) then
            cfg.overdrive = true;
            local pat, src = getActivePattern();
            Sub.echo('[PUP] Overdrive JA fired -> ' .. src
                  .. '  (' .. fmtPattern(pat) .. ')');
        end
    end

    -- "<Name> uses Fire Maneuver." / Ice / Wind / Earth / Thunder / Water / Light / Dark
    -- Set inflight on the element so the in-tick count math treats it as
    -- already present (prevents overload from manually-queued maneuvers too).
    -- Confirmed maneuver fire -- "<name> uses X Maneuver".  THIS is where
    -- burden and the fire log get updated.  A queue-time call would wrongly
    -- credit failed attempts (resting, status, OOR) -- the chat line only
    -- appears for fires the server actually accepted.
    local elem = msg:match('uses (%a+) Maneuver');
    if (elem) then
        elem = elem:lower();
        if (MAN_BUFF[elem]) then
            recordFire(elem);                 -- bump inflight + fireLog
            Burden.record(elem);              -- bump local burden counter
            lastAnyFire = os.time();
        end
    end
end);

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
            wearoffTicks = {}; everReached = {};
            firesByElem = {}; inflightUntil = {}; fireLog = {};
        end
        return;
    end

    local buffs = readBuffs();

    -- Auto-sync Overdrive mode: track the player buff.  When it appears,
    -- switch to the overdrive pattern; when it drops, switch back.  This
    -- means the user never has to remember to toggle it manually.
    local odNow = buffs[OVERDRIVE_ID] ~= nil;
    if (odNow ~= cfg.overdrive) then
        cfg.overdrive = odNow;
        local pat, src = getActivePattern();
        Sub.echo(string.format('[PUP] Overdrive %s -> %s (%s)',
            odNow and 'DETECTED' or 'ended', src, fmtPattern(pat)));
    end

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
        -- Overload guard A: count visible buffs + in-flight fires.
        if ((activeManeuverTotal(buffs) + inflightTotal()) >= 3) then return; end
        -- Overload guard B (nuclear backup): count our OWN fire log over the
        -- maneuver-duration window.  This works even if the server uses
        -- unusual buff IDs and readBuffs() returns 0 across the board --
        -- we cap at 3 fires per MANEUVER_DURATION so a buff-read bug can
        -- never produce a 4th fire.
        if (recentFiresTotal() >= 3) then return; end
        local elem = nextManeuverNeeded(buffs, pet);
        if (elem) then
            local name = elem:sub(1,1):upper() .. elem:sub(2) .. ' Maneuver';
            AshitaCore:GetChatManager():QueueCommand(1,
                string.format('/ja "%s" <me>', name));
            lastFiredAt[elem]    = now2;
            lastAnyFire          = now2;
            wearoffTicks[elem]   = 0;   -- reset debounce on fire
            -- Populate the global fire log at QUEUE time (not just text_in)
            -- so the "3 fires per 60s" hard cap works even on servers whose
            -- chat line format doesn't match our text_in regex.  If the queue
            -- fails (resting, status, etc) the extra entry decays out in 60s
            -- anyway -- strictly safer to over-count than under-count.
            fireLog[#fireLog + 1] = now2;
            firesByElem[elem] = firesByElem[elem] or {};
            firesByElem[elem][#firesByElem[elem] + 1] = now2;
            -- Seed Burden at queue time with a conservative estimate.  If
            -- text_in later confirms, we'll have double-counted this fire
            -- for ~60s before decay evens it out -- which is the SAFE
            -- direction (over-count burden = fewer fires = no overload).
            -- If text_in misses, this is the only burden update we'll get.
            pcall(Burden.record, elem);
            -- SHORT inflight window to prevent re-firing the same tick before
            -- chat confirms.  The full fireLog + Burden.record happen ONLY when
            -- the game actually posts "uses X Maneuver" -- so a failed fire
            -- (resting / status / out of range) never pollutes burden state.
            inflightUntil[elem]  = now2 + 3;
            -- NOTE: do NOT call Burden.record() here.  Burden gets bumped only
            -- when the game actually posts "<name> uses X Maneuver" in chat
            -- (handled by the text_in hook below).  Firing at queue time
            -- would wrongly inflate burden on failed queues -- resting,
            -- status disables, out-of-range, etc.
            -- Tag echo with WS-force if we fired because pet is in WS window.
            local _, src = getActivePattern();
            local tag = (cfg.forceWS and pet and pet.TP and pet.TP >= WS_TP_WINDOW_LO
                        and pet.TP <= WS_TP_WINDOW_HI) and ' [WS!]' or '';
            Sub.echo(string.format('[PUP:%s]%s -> %s', src, tag, name));
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

    -- Normalize head/frame name capitalization.
    local function norm(s) return s:sub(1,1):upper() .. s:sub(2):lower(); end

    if (sub == 'head' and args[2]) then
        local h = norm(args[2]);
        if (not headToPattern[h]) then
            Sub.echo('[PUP] Unknown head: ' .. h
                  .. ' (Valoredge/Harlequin/Sharpshot/Stormwaker/Soulsoother/Spiritreaver)');
            return;
        end
        cfg.head = h;
        local mapped = headToMode[h];
        if (mapped) then cfg.mode = mapped; end
        local pat, src = getActivePattern();
        Sub.echo('[PUP] Head=' .. h .. ' -> ' .. src .. ' -- ' .. fmtPattern(pat)
              .. (pat.wsForce and ('  [WS->' .. pat.wsForce:upper() .. ']') or ''));
        return;
    end

    if (sub == 'frame' and args[2]) then
        local f = norm(args[2]);
        if (not headToPattern[f]) then
            Sub.echo('[PUP] Unknown frame: ' .. f
                  .. ' (Valoredge/Harlequin/Sharpshot/Stormwaker/Soulsoother/Spiritreaver)');
            return;
        end
        cfg.frame = f;
        local pat, src = getActivePattern();
        Sub.echo('[PUP] Frame=' .. f .. ' -> ' .. src .. ' -- ' .. fmtPattern(pat)
              .. (pat.wsForce and ('  [WS->' .. pat.wsForce:upper() .. ']') or ''));
        return;
    end

    -- Primary one-shot setup: `/lac fwd setup tank`  (or blm/whm/rdm/turtle/
    -- meva/rng/rngtank/lvl60).  Two-arg legacy form `/lac fwd setup <head> <frame>`
    -- still works as a manual override.
    if (sub == 'setup' and args[2] and not args[3]) then
        local name = args[2]:lower();
        local pr = presets[name];
        if (not pr) then
            local names = {};
            for k in pairs(presets) do names[#names+1] = k; end
            table.sort(names);
            Sub.echo('[PUP] Unknown preset: ' .. name
                  .. '  (' .. table.concat(names, '|') .. ')');
            return;
        end
        cfg.preset = name;
        cfg.head   = pr.head;    -- keep legacy fields in sync for debug/display
        cfg.frame  = pr.frame;
        local pat, src = getActivePattern();
        Sub.echo(string.format('[PUP] Preset: %s -- %s', name, pr.desc));
        Sub.echo('[PUP]   Maneuvers: ' .. fmtPattern(pat));
        if (pat.wsForce) then
            Sub.echo(string.format('[PUP]   WS-force: %s maneuver at pet TP %d-%d',
                pat.wsForce:upper(), WS_TP_WINDOW_LO, WS_TP_WINDOW_HI));
        end
        if (pat.strobeFire) then
            Sub.echo('[PUP]   Fire maneuver gated on Strobe-ready (30s)');
        end
        -- Notify ChharControl so it can equip/echo the matching attachment set.
        if (cfg.chharControl) then
            AshitaCore:GetChatManager():QueueCommand(1, '/cc preset ' .. name);
        end
        return;
    end
    if (sub == 'setup' and args[2] and args[3]) then
        local h, f = norm(args[2]), norm(args[3]);
        if (not headToPattern[h] or not headToPattern[f]) then
            Sub.echo('[PUP] setup <head> <frame> -- unknown head/frame.');
            return;
        end
        cfg.preset = '';        -- clear preset: manual mode
        cfg.head   = h;
        cfg.frame  = f;
        local pat, src = getActivePattern();
        Sub.echo(string.format('[PUP] Manual setup: %s head / %s frame -> %s', h, f, src));
        Sub.echo('[PUP]   Maneuvers: ' .. fmtPattern(pat));
        return;
    end

    -- Alias: `/lac fwd preset <name>`  (same as `/lac fwd setup <name>`)
    if (sub == 'preset') then
        if (not args[2]) then
            Sub.echo('[PUP] Current preset: ' .. (cfg.preset ~= '' and cfg.preset or '(none)'));
            local names = {};
            for k in pairs(presets) do names[#names+1] = k; end
            table.sort(names);
            Sub.echo('[PUP] Available: ' .. table.concat(names, ', '));
            for _, n in ipairs(names) do
                Sub.echo(string.format('   %-8s -- %s', n, presets[n].desc));
            end
            return;
        end
        -- Chain into the setup handler by rewriting args
        args[1] = 'setup';
        return profile.HandleCommand(args);
    end

    if (sub == 'overdrive' or sub == 'od') then
        cfg.overdrive = tri(cfg.overdrive, args[2] and args[2]:lower());
        local pat, src = getActivePattern();
        Sub.echo('[PUP] Overdrive mode: ' .. (cfg.overdrive and 'ON' or 'OFF')
              .. ' -> ' .. src .. ' -- ' .. fmtPattern(pat));
        return;
    end

    if (sub == 'forcews' or sub == 'wsforce') then
        cfg.forceWS = tri(cfg.forceWS, args[2] and args[2]:lower());
        Sub.echo('[PUP] WS-force (pre-WS priority maneuver at pet TP '
              .. WS_TP_WINDOW_LO .. '-' .. WS_TP_WINDOW_HI .. '): '
              .. (cfg.forceWS and 'ON' or 'OFF'));
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
        local pat, src = getActivePattern();
        Sub.echo('[PUP] Head/Frame:    ' .. (cfg.head ~= '' and cfg.head or '(unset)')
              .. ' / ' .. (cfg.frame ~= '' and cfg.frame or '(unset)'));
        Sub.echo('[PUP] Active pattern: ' .. src .. ' -- ' .. fmtPattern(pat));
        if (pat.wsForce) then
            Sub.echo(string.format('[PUP] WS-force:      %s maneuver at pet TP %d-%d  (%s)',
                pat.wsForce:upper(), WS_TP_WINDOW_LO, WS_TP_WINDOW_HI,
                cfg.forceWS and 'ENABLED' or 'disabled'));
        end
        Sub.echo('[PUP] Overdrive:     ' .. (cfg.overdrive and 'ON' or 'OFF'));
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
        local pat, src = getActivePattern();
        Sub.echo('[PUP DEBUG] Pattern src=' .. src
              .. '  pattern=' .. fmtPattern(pat)
              .. (pat.wsForce and ('  wsForce=' .. pat.wsForce) or ''));
        Sub.echo('[PUP DEBUG] Head=' .. cfg.head .. '  Frame=' .. cfg.frame
              .. '  Overdrive=' .. tostring(cfg.overdrive)
              .. '  ForceWS=' .. tostring(cfg.forceWS));
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
        Sub.echo('[PUP DEBUG] Maneuvers up: ' .. activeManeuverTotal(buffs)
              .. ' + ' .. inflightTotal() .. ' in-flight = '
              .. (activeManeuverTotal(buffs) + inflightTotal()) .. '/3');
        Sub.echo('[PUP DEBUG] Hard-cap fireLog: ' .. recentFiresTotal()
              .. '/3 fires in last ' .. MANEUVER_LIFE .. 's');
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
          .. '  (setup <preset> | preset [name] | overdrive | forcews | auto | am | heal | repair | cooldown | mode | head | frame | threshold | buffs | burden | hud | recast | vent | config | debug)');
end

return profile;
