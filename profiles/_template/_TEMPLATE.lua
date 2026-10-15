-- ============================================================================
-- Chharizard <JOB> - LuAshitaCast profile template (Horizon XI)
--
-- Every new job profile starts from this shell so all Chharizard jobs share
-- the same subjob automation (DRG jumps, NIN utsu, SAM Hasso/Meditate/3E).
--
-- To use:
--   1. Copy this file to <JOB>.lua (e.g. WAR.lua, MNK.lua)
--   2. Fill in job-specific gear sets
--   3. Uncomment/adjust job-specific handlers (WS, JA, Precast, Midcast)
-- ============================================================================

local profile = {};
local sets = {};
profile.Sets = sets;
local Sub = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/subjob_features.lua');

-- ---------------------------------------------------------------------------
-- Gear sets -- fill in with era-appropriate items for this job.
-- Missing items are silently skipped by LAC so aspirational sets are fine.
-- ---------------------------------------------------------------------------
sets.Idle = {
    -- Head =, Neck =, Ear1 =, Ear2 =, Body =, Hands =, Ring1 =, Ring2 =,
    -- Back =, Waist =, Legs =, Feet =, Main =, Sub =, Ammo =
};

sets.Movement = { Feet = "Rutter Sabatons" };
sets.TP = {};
sets.WS = {};
sets.WS.Default = {};
sets.JA = {};
sets.Precast = { FastCast = {} };
sets.Midcast = {
    Cure     = {},
    Enhancing= {},
    Utsusemi = { Head = "Walahra Turban" },
    Healing  = {},
};

-- ============================================================================
-- Event handlers
-- ============================================================================

profile.OnLoad = function()
    gSettings.AllowAddSet = true;
    Sub.echo("[Chharizard <JOB>] Profile loaded.");
end

profile.OnUnload = function()
    Sub.echo("[Chharizard <JOB>] Profile unloaded.");
end

-- Note: shared subjob automation is driven from HandleDefault/HandleEngaged
-- because LAC profiles don't have access to ashita.timer. LAC calls these
-- handlers continuously while the profile is active, so Sub.tick() gets a
-- ~1/sec effective cadence (throttled internally per feature).

profile.HandleDefault = function()
    gFunc.EquipSet(sets.Idle);
    if (gData.GetPlayer().IsMoving) then gFunc.EquipSet(sets.Movement); end
    Sub.tick(true);
end

profile.HandleEngaged = function()
    gFunc.EquipSet(sets.TP);
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
    if (spell.Name:contains('Cure')) then gFunc.EquipSet(sets.Midcast.Cure);
    elseif (spell.Skill == 'Enhancing Magic') then gFunc.EquipSet(sets.Midcast.Enhancing);
    elseif (spell.Skill == 'Ninjutsu' and spell.Name:contains('Utsusemi')) then
        gFunc.EquipSet(sets.Midcast.Utsusemi);
    end
end

-- ============================================================================
-- Commands (via /lac fwd ...)
-- ============================================================================
profile.HandleCommand = function(args)
    if (#args < 1) then return; end
    -- Shared subjob commands always tried first
    if (Sub.handleCommand(args)) then return; end

    -- Job-specific commands go here
    local cmd = args[1]:lower();
    if (cmd == 'debug') then
        Sub.debug();
        return;
    end
end

return profile;
