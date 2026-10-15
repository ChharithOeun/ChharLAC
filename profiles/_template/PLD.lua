-- ============================================================================
-- Chharizard PLD - LuAshitaCast profile for Horizon XI (era retail)
--
-- Selindril-style auto-tank features:
--   * Auto-Provoke on cooldown (30s)     -- /WAR sub tool
--   * Auto-Flash on cooldown (45s)       -- PLD signature hate
--   * Auto-Sentinel when hate slipping   -- PLD JA
--   * Auto-Cure on self/party at HP thresholds (hate maintenance via curespam)
--   * Auto-Cocoon on cooldown             -- /BLU sub, PDT self-buff
--   * Auto-Refueling on cooldown          -- /BLU sub, self-haste
--
-- Subjob support:
--   * /WAR (early game 1-30) -- Provoke, Berserk (off), Defender
--   * /BLU (mid-late game)   -- Cocoon (PDT), Refueling, Head Butt, Cannonball
--   * Auto-detects sub from AshitaCore and enables the right auto-actions
--
-- Commands (via /lac fwd ...):
--   /lac fwd auto             -- master toggle: all auto-tank features on/off
--   /lac fwd voke on|off      -- auto-Provoke
--   /lac fwd flash on|off     -- auto-Flash
--   /lac fwd cure on|off      -- auto-cure self+party at HP thresholds
--   /lac fwd cocoon on|off    -- auto-Cocoon (/BLU only)
--   /lac fwd refuel on|off    -- auto-Refueling (/BLU only)
--   /lac fwd sentinel         -- fire Sentinel now
--   /lac fwd cover <name>     -- Cover a party member
--   /lac fwd hp <n>           -- set self-cure HP threshold (default 55)
--   /lac fwd php <n>          -- set party-cure HP threshold (default 45)
--   /lac fwd config           -- print current settings
--   /lac fwd debug            -- inspect state
--
-- ⚠️  Auto-cast on cooldown may violate Horizon's rules. Verify TOS.
--     Everything defaults to OFF; toggle explicitly to enable.
-- ============================================================================

local profile = {};
local sets = {};
profile.Sets = sets;
local Sub = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/subjob_features.lua');

-- ---------------------------------------------------------------------------
-- Runtime config
-- ---------------------------------------------------------------------------
local cfg = {
    autoProvoke   = false,
    autoFlash     = false,
    autoCure      = false,
    autoCocoon    = false,
    autoRefueling = false,
    selfHpCure    = 55,      -- % self HP that triggers a Cure
    partyHpCure   = 45,      -- % party member HP that triggers Curaga/Cure
    provokeCd     = 30,      -- s
    flashCd       = 45,      -- s
    cocoonCd      = 60,      -- s
    refuelingCd   = 90,      -- s
    -- Which cure to cast at each self-HP tier (era spell availability)
    selfCureTier  = { 'Cure III', 'Cure II', 'Cure' },  -- try in order until known
    partyCureTier = { 'Cure II', 'Cure' },
};

-- ---------------------------------------------------------------------------
-- Gear sets -- era-progressive. Missing items are silently skipped by LAC,
-- so it's safe to list era-endgame pieces even if you don't have them yet.
-- ---------------------------------------------------------------------------

-- IDLE / RESTING
sets.Idle = {
    Head    = "Bronze Cap",              -- upgrade path -> Walahra Turban -> Turms Cap
    Neck    = "Chivalrous Chain",        -- +Enmity
    Ear1    = "Merman's Earring",
    Ear2    = "Merman's Earring",
    Body    = "Adaman Hauberk",          -- PDT, HP -- endgame Ochain body if you get it
    Hands   = "Adaman Mufflers",         -- HP, DEF
    Ring1   = "Shell Ring",              -- PDT
    Ring2   = "Shell Ring",              -- (or Sattva Ring for HP)
    Back    = "Cerberus Mantle",         -- PDT, STR
    Waist   = "Warwolf Belt",            -- STR, HP
    Legs    = "Adaman Cuisses",
    Feet    = "Adaman Sollerets",
    Main    = "Justice Sword",           -- upgrade path -> Divine Sword -> Excalibur (relic)
    Sub     = "Aegis",                   -- PLD relic shield; era progression: Genbu's -> Ochain -> Aegis
    Ammo    = "Fire Bomblet",            -- +Att; era ammo for tank slot
};

sets.Movement = { Feet = "Rutter Sabatons" };

-- TP -- for tanking, focused on hate + defense while attacking
sets.TP = {
    Head    = "Walahra Turban",          -- Haste
    Neck    = "Chivalrous Chain",        -- +Enmity
    Ear1    = "Suppanomimi",             -- Dual Wield (subjob NIN) or Merman's
    Ear2    = "Ethereal Earring",        -- HP+
    Body    = "Adaman Hauberk",
    Hands   = "Adaman Mufflers",
    Ring1   = "Wivre Ring",              -- +Enmity, HP
    Ring2   = "Sattva Ring",             -- HP-drain trigger
    Back    = "Cerberus Mantle",
    Waist   = "Warwolf Belt",
    Legs    = "Adaman Cuisses",
    Feet    = "Adaman Sollerets",
    Main    = "Justice Sword",
    Sub     = "Aegis",
    Ammo    = "Fire Bomblet",
};

-- PDT (Physical Damage Taken -) -- swap in whenever taking heavy melee
sets.PDT = {
    Head    = "Adaman Celata",           -- PDT
    Neck    = "Chivalrous Chain",
    Ear1    = "Merman's Earring",
    Ear2    = "Merman's Earring",
    Body    = "Adaman Hauberk",          -- PDT
    Hands   = "Adaman Mufflers",
    Ring1   = "Shell Ring",              -- PDT
    Ring2   = "Shell Ring",
    Back    = "Cerberus Mantle",
    Waist   = "Life Belt",
    Legs    = "Adaman Cuisses",
    Feet    = "Adaman Sollerets",
    Main    = "Justice Sword",
    Sub     = "Aegis",
};

-- MDT (Magic Damage Taken -) -- swap for magic-heavy fights
sets.MDT = {
    Head    = "Optical Hat",
    Neck    = "Wivre Gorget",
    Ear1    = "Genin Earring",           -- +MDT
    Ear2    = "Genin Earring",
    Body    = "Shadow Mail",             -- MDT
    Hands   = "Aeolian Armlets",
    Ring1   = "Shell Ring",
    Ring2   = "Shell Ring",
    Back    = "Shadow Mantle",           -- MDT + Absorb Magic
    Waist   = "Resolute Belt",
    Legs    = "Shadow Breeches",
    Feet    = "Shadow Sabatons",
    Sub     = "Aegis",                   -- MDB
};

-- HYBRID -- 50/50 TP + PDT for normal tanking
sets.Hybrid = sets.TP;

-- ---------------------------------------------------------------------------
-- Weaponskills
-- ---------------------------------------------------------------------------
sets.WS = {};
sets.WS.Default = {                       -- STR-based (Vorpal Blade / Swift Blade)
    Head    = "Walahra Turban",
    Neck    = "Chivalrous Chain",
    Ear1    = "Assault Earring",
    Ear2    = "Merman's Earring",
    Body    = "Adaman Hauberk",
    Hands   = "Adaman Mufflers",
    Ring1   = "Rajas Ring",
    Ring2   = "Woodsman Ring",
    Back    = "Cerberus Mantle",
    Waist   = "Warwolf Belt",
    Legs    = "Adaman Cuisses",
    Feet    = "Adaman Sollerets",
};
sets.WS["Vorpal Blade"]     = sets.WS.Default;
sets.WS["Swift Blade"]      = sets.WS.Default;
sets.WS["Savage Blade"]     = sets.WS.Default;
sets.WS["Chant du Cygne"]   = sets.WS.Default;
sets.WS["Requiescat"]       = sets.WS.Default;  -- MND-based, adjust when you get it
sets.WS["Atonement"]        = {                  -- Enmity WS, use hate gear
    Head = "Walahra Turban", Neck = "Chivalrous Chain",
    Body = "Adaman Hauberk", Hands = "Adaman Mufflers",
    Ring1 = "Wivre Ring", Ring2 = "Wivre Ring",
    Back = "Cerberus Mantle", Waist = "Warwolf Belt",
    Legs = "Adaman Cuisses", Feet = "Adaman Sollerets",
};

-- ---------------------------------------------------------------------------
-- Job abilities
-- ---------------------------------------------------------------------------
sets.JA = {};
sets.JA["Provoke"]          = { Neck = "Chivalrous Chain", Ring1 = "Wivre Ring" };
sets.JA["Sentinel"]         = { Feet = "Cheval Boots" };       -- +Enmity/Sentinel duration
sets.JA["Cover"]            = { Head = "Ochain Helm" };        -- +Cover; era: any Pld JSE
sets.JA["Rampart"]          = { Head = "Ochain Helm" };
sets.JA["Divine Emblem"]    = { Feet = "Chevalier's Sabatons +1" }; -- +Flash after
sets.JA["Divine Seal"]      = {};
sets.JA["Invincible"]       = { Legs = "Cab. Breeches" };      -- +Invincible duration
sets.JA["Shield Bash"]      = { Hands = "Cab. Gauntlets" };
sets.JA["Holy Circle"]      = {};
sets.JA["Fealty"]           = {};
sets.JA["Chivalry"]         = {};
-- WAR sub
sets.JA["Berserk"]          = {};
sets.JA["Defender"]         = {};
sets.JA["Warcry"]           = {};
sets.JA["Aggressor"]        = {};

-- ---------------------------------------------------------------------------
-- Precast (Fast Cast) -- Lv-appropriate era progression
-- ---------------------------------------------------------------------------
sets.Precast = {};
sets.Precast.FastCast = {
    Head    = "Walahra Turban",
    Ear2    = "Loquac. Earring",         -- FC+2 (Lv 40 quest)
    Body    = "Homam Corazza",           -- FC+2 -- endgame Salvage
    Hands   = "Rostrum Pumps",           -- no wait, Rostrum are feet
    Feet    = "Rostrum Pumps",           -- FC+5% on subjob magic
    Ring1   = "Prolix Ring",             -- FC+2
    Legs    = "Homam Cosciales",
};

-- ---------------------------------------------------------------------------
-- Midcast
-- ---------------------------------------------------------------------------
sets.Midcast = {};

-- Cures -- Cure Potency + Enmity (spam heals build hate)
sets.Midcast.Cure = {
    Head    = "Walahra Turban",
    Neck    = "Chivalrous Chain",        -- +Enmity so heals build hate too
    Body    = "Adaman Hauberk",
    Hands   = "Devout Bracers",          -- Cure Potency %
    Ring1   = "Ether Ring",              -- Healing Skill
    Back    = "Cerberus Mantle",
    Legs    = "Rostrum Pumps",           -- feet, but placeholder
    Feet    = "Rostrum Pumps",
    Waist   = "Blessed Briault",         -- if you have it
};

sets.Midcast.Enhancing = {               -- Protect/Shell/Enlight
    Head    = "Walahra Turban",
    Neck    = "Enhancing Torque",
    Body    = "Adaman Hauberk",
    Hands   = "Weather. Mittens +1",     -- Enhancing Magic Skill
};

sets.Midcast.Flash = {                   -- max Enmity for the biggest hate spike
    Neck    = "Chivalrous Chain",
    Body    = "Adaman Hauberk",
    Ring1   = "Wivre Ring",
    Ring2   = "Wivre Ring",
    Back    = "Cerberus Mantle",
    Waist   = "Warwolf Belt",
};

-- /BLU sub spells
sets.Midcast.Cocoon         = { Body = "Adaman Hauberk" };     -- self-buff
sets.Midcast.Refueling      = { Body = "Adaman Hauberk" };
sets.Midcast["Metallic Body"] = { Body = "Adaman Hauberk" };   -- Stoneskin-like
sets.Midcast["Head Butt"]   = { Neck = "Chivalrous Chain" };   -- hate proc + stun
sets.Midcast.Cannonball     = { Neck = "Chivalrous Chain" };   -- hate spike WS-like
sets.Midcast["Actinic Burst"] = sets.Midcast.Flash;            -- AoE Flash-like

-- Utsusemi (if /NIN)
sets.Midcast.Utsusemi = { Head = "Walahra Turban", Feet = "Yigit Crackows" };

-- ============================================================================
-- Event handlers
-- ============================================================================

profile.OnLoad = function()
    gSettings.AllowAddSet = true;
    Sub.echo("[Chharizard PLD] Profile loaded.");
end

profile.OnUnload = function()
    Sub.echo("[Chharizard PLD] Profile unloaded.");
end

-- Small utility: get subjob name (e.g. 'WAR', 'BLU', 'NIN', 'WHM')
local function subJob()
    local p = AshitaCore:GetMemoryManager():GetPlayer();
    local id = p:GetSubJob();
    local name = AshitaCore:GetResourceManager():GetString('jobs.names_abbr', id);
    if (type(name) == 'string') then name = name:trimend('\x00'); end
    return name or '';
end

profile.HandleDefault = function()
    -- Default to PDT idle (tank stance) unless we've got HP room
    gFunc.EquipSet(sets.Idle);
    if (gData.GetPlayer().IsMoving) then gFunc.EquipSet(sets.Movement); end
    if (profile._autoTick) then profile._autoTick(); end
    Sub.tick(true);
end

profile.HandleEngaged = function()
    gFunc.EquipSet(sets.TP);
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
    if     (spell.Name:contains('Cure'))    then gFunc.EquipSet(sets.Midcast.Cure);
    elseif (spell.Name:contains('Curaga'))  then gFunc.EquipSet(sets.Midcast.Cure);
    elseif (spell.Name == 'Flash')          then gFunc.EquipSet(sets.Midcast.Flash);
    elseif (sets.Midcast[spell.Name])       then gFunc.EquipSet(sets.Midcast[spell.Name]);
    elseif (spell.Skill == 'Enhancing Magic') then gFunc.EquipSet(sets.Midcast.Enhancing);
    elseif (spell.Skill == 'Ninjutsu' and spell.Name:contains('Utsusemi')) then
        gFunc.EquipSet(sets.Midcast.Utsusemi);
    end
end

-- ============================================================================
-- Automation
-- ============================================================================

-- Party HP inspection. Returns array of { name, hpp, index } for each member.
local function partyHpList()
    local out = {};
    local party = AshitaCore:GetMemoryManager():GetParty();
    for i = 0, 5 do
        if (party:GetMemberIsActive(i) == 1) then
            local hpp = party:GetMemberHPPercent(i);
            local name = party:GetMemberName(i);
            if (name and name ~= '') then
                out[#out+1] = { name = name, hpp = hpp, index = i };
            end
        end
    end
    return out;
end

-- Player's own HP%
local function selfHpp()
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    local pt = AshitaCore:GetMemoryManager():GetParty();
    return pt:GetMemberHPPercent(0);
end

-- Any active mob targeting me? Rough proxy: I'm engaged.
local function iAmEngaged()
    return gData.GetPlayer().Status == 'Engaged';
end

-- Timers
local lastVoke = 0;
local lastFlash = 0;
local lastCocoon = 0;
local lastRefueling = 0;
local lastCure = 0;

profile._autoTick = function()
    if (gProfile ~= profile) then return; end
    local now = os.time();
    local sub = subJob();

    -- Auto Provoke (WAR sub)
    if (cfg.autoProvoke and sub == 'WAR' and iAmEngaged()
        and (now - lastVoke >= cfg.provokeCd)) then
        AshitaCore:GetChatManager():QueueCommand(1, '/ja "Provoke" <t>');
        lastVoke = now;
    end

    -- Auto Flash (main job, any sub)
    if (cfg.autoFlash and iAmEngaged()
        and (now - lastFlash >= cfg.flashCd)) then
        AshitaCore:GetChatManager():QueueCommand(1, '/ma "Flash" <t>');
        lastFlash = now;
    end

    -- Auto Cocoon (BLU sub, PDT self-buff)
    if (cfg.autoCocoon and sub == 'BLU'
        and (now - lastCocoon >= cfg.cocoonCd)) then
        AshitaCore:GetChatManager():QueueCommand(1, '/ma "Cocoon" <me>');
        lastCocoon = now;
    end

    -- Auto Refueling (BLU sub, self-haste)
    if (cfg.autoRefueling and sub == 'BLU'
        and (now - lastRefueling >= cfg.refuelingCd)) then
        AshitaCore:GetChatManager():QueueCommand(1, '/ma "Refueling" <me>');
        lastRefueling = now;
    end

    -- Auto Cure (self + party) -- 3s cooldown between attempts
    if (cfg.autoCure and (now - lastCure >= 3)) then
        local self_hp = selfHpp();
        -- Emergency self-heal
        if (self_hp > 0 and self_hp < cfg.selfHpCure) then
            for _, sp in ipairs(cfg.selfCureTier) do
                AshitaCore:GetChatManager():QueueCommand(1,
                    string.format('/ma "%s" <me>', sp));
                lastCure = now;
                break;
            end
        else
            -- Party heal for hate maintenance
            for _, m in ipairs(partyHpList()) do
                if (m.index > 0 and m.hpp > 0 and m.hpp < cfg.partyHpCure) then
                    for _, sp in ipairs(cfg.partyCureTier) do
                        AshitaCore:GetChatManager():QueueCommand(1,
                            string.format('/ma "%s" %s', sp, m.name));
                        lastCure = now;
                        break;
                    end
                    break;
                end
            end
        end
    end
end

-- ============================================================================
-- Commands
-- ============================================================================

profile.HandleCommand = function(args)
    if (#args < 1) then return; end
    if (Sub.handleCommand(args)) then return; end
    local sub = args[1]:lower();

    if (sub == 'auto') then
        local on = not cfg.autoProvoke;
        cfg.autoProvoke = on;
        cfg.autoFlash   = on;
        cfg.autoCure    = on;
        cfg.autoCocoon  = on;
        cfg.autoRefueling = on;
        Sub.echo('[PLD] All auto-tank features: ' .. (on and 'ON' or 'OFF'));
        return;
    end

    local toggleMap = {
        voke   = 'autoProvoke',
        flash  = 'autoFlash',
        cure   = 'autoCure',
        cocoon = 'autoCocoon',
        refuel = 'autoRefueling',
    };
    if (toggleMap[sub]) then
        cfg[toggleMap[sub]] = (args[2] and args[2]:lower() == 'on');
        Sub.echo('[PLD] ' .. sub .. ': '
              .. (cfg[toggleMap[sub]] and 'ON' or 'OFF'));
        return;
    end

    if (sub == 'sentinel') then
        AshitaCore:GetChatManager():QueueCommand(1, '/ja "Sentinel" <me>');
        return;
    end

    if (sub == 'cover' and args[2]) then
        AshitaCore:GetChatManager():QueueCommand(1,
            string.format('/ja "Cover" %s', args[2]));
        return;
    end

    if (sub == 'hp' and args[2]) then
        cfg.selfHpCure = tonumber(args[2]) or cfg.selfHpCure;
        Sub.echo('[PLD] Self-cure threshold: ' .. cfg.selfHpCure .. '%');
        return;
    end
    if (sub == 'php' and args[2]) then
        cfg.partyHpCure = tonumber(args[2]) or cfg.partyHpCure;
        Sub.echo('[PLD] Party-cure threshold: ' .. cfg.partyHpCure .. '%');
        return;
    end

    if (sub == 'config') then
        Sub.echo('[PLD] Sub: ' .. subJob());
        Sub.echo('[PLD] Auto Provoke: '   .. (cfg.autoProvoke and 'ON' or 'OFF'));
        Sub.echo('[PLD] Auto Flash: '     .. (cfg.autoFlash and 'ON' or 'OFF'));
        Sub.echo('[PLD] Auto Cure: '      .. (cfg.autoCure and 'ON' or 'OFF'));
        Sub.echo('[PLD] Auto Cocoon: '    .. (cfg.autoCocoon and 'ON' or 'OFF'));
        Sub.echo('[PLD] Auto Refueling: ' .. (cfg.autoRefueling and 'ON' or 'OFF'));
        Sub.echo('[PLD] Self HP cure: '   .. cfg.selfHpCure .. '%');
        Sub.echo('[PLD] Party HP cure: '  .. cfg.partyHpCure .. '%');
        return;
    end

    if (sub == 'debug') then
        Sub.echo('[PLD DEBUG] Sub: '     .. subJob());
        Sub.echo('[PLD DEBUG] Self HP: ' .. selfHpp() .. '%');
        Sub.echo('[PLD DEBUG] Engaged: ' .. tostring(iAmEngaged()));
        for _, m in ipairs(partyHpList()) do
            if (m.hpp > 0) then
                Sub.echo(string.format('   party[%d] %s: %d%%', m.index, m.name, m.hpp));
            end
        end
        return;
    end

    Sub.echo('[PLD] Unknown command: ' .. sub
          .. '  (auto|voke|flash|cure|cocoon|refuel|sentinel|cover|hp|php|config|debug)');
end

return profile;
