-- Chharizard RDM - LAC profile (enfeeble/enhance/melee hybrid, era)
local profile = {}; local sets = {}; profile.Sets = sets;
local Sub = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/subjob_features.lua');

sets.Idle = {
    Head="Walahra Turban", Neck="Uggalepih Pendant", Ear1="Loquac. Earring", Ear2="Snow Ear",
    Body="Duelist's Tabard", Hands="Duelist's Gloves", Ring1="Ether Ring", Ring2="Diamond Ring",
    Back="Errant Cape", Waist="Sacro Cord", Legs="Duelist's Tights", Feet="Herald's Gaiters",
    Main="Joyeuse", Sub="Genbu's Shield", Ammo="Phtgn. Bomblet",
};
sets.Movement = { Feet="Herald's Gaiters" };
sets.Resting = { Head="Duelist's Chapeau", Waist="Austerity Belt" };
sets.TP = {
    Head="Walahra Turban", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Suppanomimi",
    Body="Duelist's Tabard", Hands="Dusk Gloves", Ring1="Rajas Ring", Ring2="Sniper's Ring",
    Back="Cerberus Mantle", Waist="Swift Belt", Legs="Homam Cosciales", Feet="Homam Gambieras",
    Main="Joyeuse", Sub="Genbu's Shield",
};

sets.Precast = { FastCast = { Head="Duelist's Chapeau", Ear1="Loquac. Earring", Body="Duelist's Tabard", Hands="Duelist's Gloves", Legs="Duelist's Tights" } };
sets.Midcast = {
    Cure       = { Body="Dalmatica", Legs="Duelist's Tights", Feet="Herald's Gaiters" },
    Enhancing  = { Head="Duelist's Chapeau", Neck="Colossus's Torque", Body="Duelist's Tabard", Hands="Duelist's Gloves" },
    Enfeebling = { Head="Duelist's Chapeau", Neck="Uggalepih Pendant", Body="Duelist's Tabard", Hands="Duelist's Gloves", Ring1="Snow Ring", Feet="Duelist's Boots" },
    Elemental  = { Neck="Uggalepih Pendant", Body="Igqira Weskit", Legs="Igqira Lappas" },
    Dark       = { Head="Duelist's Chapeau", Body="Duelist's Tabard" },
    Utsusemi   = { Head="Walahra Turban" },
};

sets.WS = {};
sets.WS.Default = {
    Head="Optical Hat", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Merman's Earring",
    Body="Duelist's Tabard", Hands="Dusk Gloves", Ring1="Rajas Ring", Ring2="Woodsman Ring",
    Back="Cerberus Mantle", Waist="Warwolf Belt", Legs="Byakko's Haidate", Feet="Rutter Sabatons",
};
sets.WS["Vorpal Blade"]   = sets.WS.Default;
sets.WS["Swift Blade"]    = sets.WS.Default;
sets.WS["Savage Blade"]   = sets.WS.Default;
sets.WS["Chant du Cygne"] = sets.WS.Default;
sets.WS["Death Blossom"]  = sets.WS.Default;   -- Rapier

sets.JA = {};
sets.JA["Chainspell"] = { Body="Warlock's Tabard" };
sets.JA["Convert"]    = { Body="Duelist's Tabard" };
sets.JA["Composure"]  = { Head="Duelist's Chapeau" };
sets.JA["Saboteur"]   = { Hands="Duelist's Gloves" };

profile.OnLoad = function() gSettings.AllowAddSet=true; Sub.echo("[Chharizard RDM] loaded."); end
profile.OnUnload = function() Sub.echo("[Chharizard RDM] unloaded."); end
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
    if (sp.Name:contains('Cure')) then gFunc.EquipSet(sets.Midcast.Cure);
    elseif (sp.Skill == 'Enhancing Magic') then gFunc.EquipSet(sets.Midcast.Enhancing);
    elseif (sp.Skill == 'Enfeebling Magic') then gFunc.EquipSet(sets.Midcast.Enfeebling);
    elseif (sp.Skill == 'Elemental Magic') then gFunc.EquipSet(sets.Midcast.Elemental);
    elseif (sp.Skill == 'Dark Magic') then gFunc.EquipSet(sets.Midcast.Dark);
    elseif (sp.Name:contains('Utsusemi')) then gFunc.EquipSet(sets.Midcast.Utsusemi); end
end
profile.HandleCommand = function(args)
    if (#args<1) then return; end
    if (Sub.handleCommand(args)) then return; end
    if (args[1]:lower()=='debug') then Sub.debug(); end
end
return profile;
