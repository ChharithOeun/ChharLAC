-- ============================================================================
-- Chharizard MNK - LuAshitaCast profile (era-progressive)
-- Weapons: H2H. Focus: TP acceleration, WS burst, Chakra self-heal.
-- ============================================================================
local profile = {};
local sets = {};
profile.Sets = sets;
local Sub = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/subjob_features.lua');

sets.Idle = {
    Head="Empress Hairpin", Neck="Peacock Amulet", Ear1="Merman's Earring", Ear2="Merman's Earring",
    Body="Melee Cyclas", Hands="Dusk Gloves", Ring1="Sniper's Ring", Ring2="Toreador's Ring",
    Back="Amemet Mantle +1", Waist="Warwolf Belt", Legs="Byakko's Haidate", Feet="Melee Gaiters",
    Main="Destroyers", Sub="", Ammo="Fire Bomblet",
};
sets.Movement = { Feet="Rutter Sabatons" };
sets.TP = {
    Head="Optical Hat", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Suppanomimi",
    Body="Scorpion Harness", Hands="Melee Gloves", Ring1="Rajas Ring", Ring2="Sniper's Ring",
    Back="Forager's Mantle", Waist="Swift Belt", Legs="Byakko's Haidate", Feet="Dune Boots",
    Main="Destroyers",
};

sets.WS = {};
sets.WS.Default = {
    Head="Optical Hat", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Merman's Earring",
    Body="Scorpion Harness", Hands="Melee Gloves", Ring1="Rajas Ring", Ring2="Woodsman Ring",
    Back="Cerberus Mantle", Waist="Warwolf Belt", Legs="Byakko's Haidate", Feet="Rutter Sabatons",
};
sets.WS["Raging Fists"]     = sets.WS.Default;
sets.WS["Asuran Fists"]     = sets.WS.Default;
sets.WS["Victory Smite"]    = sets.WS.Default;
sets.WS["Ascetic's Fury"]   = sets.WS.Default;
sets.WS["Combo"]            = sets.WS.Default;
sets.WS["Howling Fist"]     = sets.WS.Default;
sets.WS["Dragon Kick"]      = sets.WS.Default;

sets.JA = {};
sets.JA["Boost"]          = { Hands="Temple Gloves" };
sets.JA["Focus"]          = { Head="Temple Crown" };
sets.JA["Dodge"]          = { Feet="Temple Gaiters" };
sets.JA["Counterstance"]  = { Feet="Melee Gaiters" };
sets.JA["Chakra"]         = { Hands="Temple Gloves", Body="Temple Cyclas" };
sets.JA["Chi Blast"]      = { Head="Optical Hat", Hands="Temple Gloves" };
sets.JA["Hundred Fists"]  = { Legs="Temple Hose" };

sets.Precast = { FastCast = { Ear2="Loquac. Earring" } };
sets.Midcast = {
    Utsusemi = { Head="Walahra Turban" },
    Cure     = { Neck="Justice Badge" },
};

profile.OnLoad = function()
    gSettings.AllowAddSet = true;
    Sub.echo("[Chharizard MNK] Profile loaded.");
end
profile.OnUnload = function() Sub.echo("[Chharizard MNK] Profile unloaded."); end

profile.HandleDefault = function()
    gFunc.EquipSet(sets.Idle);
    if (gData.GetPlayer().IsMoving) then gFunc.EquipSet(sets.Movement); end
    Sub.tick(true);
end
profile.HandleEngaged = function() gFunc.EquipSet(sets.TP); Sub.tick(true); end
profile.HandleWeaponskill = function()
    local ws = gData.GetAction().Name;
    if (sets.WS[ws]) then gFunc.EquipSet(sets.WS[ws]);
    else gFunc.EquipSet(sets.WS.Default); end
end
profile.HandleAbility = function()
    local ja = gData.GetAction().Name;
    if (sets.JA[ja]) then gFunc.EquipSet(sets.JA[ja]); end
end
profile.HandlePrecast = function() gFunc.EquipSet(sets.Precast.FastCast); end
profile.HandleMidcast = function()
    local sp = gData.GetAction();
    if (sp.Name:contains('Cure')) then gFunc.EquipSet(sets.Midcast.Cure);
    elseif (sp.Name:contains('Utsusemi')) then gFunc.EquipSet(sets.Midcast.Utsusemi); end
end

profile.HandleCommand = function(args)
    if (#args < 1) then return; end
    if (Sub.handleCommand(args)) then return; end
    if (args[1]:lower() == 'debug') then Sub.debug(); end
end

return profile;
