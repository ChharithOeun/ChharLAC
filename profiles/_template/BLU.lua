-- Chharizard BLU - LAC profile (blue mage, sword, era)
local profile = {}; local sets = {}; profile.Sets = sets;
local Sub = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/subjob_features.lua');

sets.Idle = {
    Head="Walahra Turban", Neck="Uggalepih Pendant", Ear1="Loquac. Earring", Ear2="Snow Ear",
    Body="Magus Jubbah", Hands="Magus Bazubands", Ring1="Sniper's Ring", Ring2="Sniper's Ring",
    Back="Rainbow Cape", Waist="Warwolf Belt", Legs="Homam Cosciales", Feet="Homam Gambieras",
    Main="Joyeuse", Sub="Genbu's Shield", Ammo="Fire Bomblet",
};
sets.Movement = { Feet="Rutter Sabatons" };
sets.TP = {
    Head="Walahra Turban", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Suppanomimi",
    Body="Homam Corazza", Hands="Dusk Gloves", Ring1="Rajas Ring", Ring2="Sniper's Ring",
    Back="Cerberus Mantle", Waist="Swift Belt", Legs="Homam Cosciales", Feet="Homam Gambieras",
    Main="Joyeuse", Sub="Genbu's Shield",
};

sets.WS = {};
sets.WS.Default = {
    Head="Optical Hat", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Merman's Earring",
    Body="Homam Corazza", Hands="Dusk Gloves", Ring1="Rajas Ring", Ring2="Woodsman Ring",
    Back="Cerberus Mantle", Waist="Warwolf Belt", Legs="Byakko's Haidate", Feet="Rutter Sabatons",
};
sets.WS["Chant du Cygne"] = sets.WS.Default;
sets.WS["Vorpal Blade"]   = sets.WS.Default;
sets.WS["Savage Blade"]   = sets.WS.Default;
sets.WS["Requiescat"]     = sets.WS.Default;

sets.Precast = { FastCast = { Head="Magus Keffiyeh", Ear1="Loquac. Earring", Body="Magus Jubbah", Hands="Magus Bazubands" } };
sets.Midcast = {
    BlueMagic     = { Head="Magus Keffiyeh", Neck="Uggalepih Pendant", Body="Magus Jubbah", Hands="Magus Bazubands", Legs="Magus Shalwar", Feet="Magus Charuqs" },
    BlueMagicPhys = { Neck="Chivalrous Chain", Body="Homam Corazza", Hands="Dusk Gloves", Ring1="Rajas Ring", Ring2="Woodsman Ring", Back="Cerberus Mantle", Waist="Warwolf Belt", Legs="Byakko's Haidate" },
    BlueMagicMag  = { Neck="Uggalepih Pendant", Body="Igqira Weskit", Hands="Yigit Gages", Feet="Yigit Crackows" },
    BlueMagicHeal = { Neck="Colossus's Torque", Body="Magus Jubbah", Hands="Magus Bazubands" },
    Cure          = { Body="Dalmatica" },
    Utsusemi      = { Head="Walahra Turban" },
};

sets.JA = {};
sets.JA["Burst Affinity"]  = { Feet="Magus Charuqs" };
sets.JA["Chain Affinity"]  = { Head="Magus Keffiyeh", Feet="Assimilator's Charuqs" };
sets.JA["Efflux"]          = { Legs="Magus Shalwar" };
sets.JA["Azure Lore"]      = { Hands="Magus Bazubands" };

profile.OnLoad = function() gSettings.AllowAddSet=true; Sub.echo("[Chharizard BLU] loaded."); end
profile.OnUnload = function() Sub.echo("[Chharizard BLU] unloaded."); end

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
    local ja = gData.GetAction().Name; if (sets.JA[ja]) then gFunc.EquipSet(sets.JA[ja]); end
end
profile.HandlePrecast = function() gFunc.EquipSet(sets.Precast.FastCast); end
profile.HandleMidcast = function()
    local sp = gData.GetAction();
    if (sp.Skill == 'Blue Magic') then
        gFunc.EquipSet(sets.Midcast.BlueMagic);
    elseif (sp.Name:contains('Cure')) then gFunc.EquipSet(sets.Midcast.Cure);
    elseif (sp.Name:contains('Utsusemi')) then gFunc.EquipSet(sets.Midcast.Utsusemi); end
end
profile.HandleCommand = function(args)
    if (#args<1) then return; end
    if (Sub.handleCommand(args)) then return; end
    if (args[1]:lower()=='debug') then Sub.debug(); end
end
return profile;
