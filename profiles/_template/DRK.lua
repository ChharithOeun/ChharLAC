-- Chharizard DRK - LAC profile (2H DPS, Souleater/Last Resort, era)
local profile = {}; local sets = {}; profile.Sets = sets;
local Sub = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/subjob_features.lua');

sets.Idle = {
    Head="Walahra Turban", Neck="Chivalrous Chain", Ear1="Merman's Earring", Ear2="Ethereal Earring",
    Body="Haubergeon", Hands="Alkyoneus's Bracelets", Ring1="Sniper's Ring", Ring2="Toreador's Ring",
    Back="Amemet Mantle +1", Waist="Warwolf Belt", Legs="Homam Cosciales", Feet="Homam Gambieras",
    Main="Ragnarok", Sub="Pole Grip", Ammo="Fire Bomblet",
};
sets.Movement = { Feet="Rutter Sabatons" };
sets.TP = {
    Head="Walahra Turban", Neck="Chivalrous Chain", Ear1="Brutal Earring", Ear2="Assault Earring",
    Body="Haubergeon", Hands="Dusk Gloves", Ring1="Rajas Ring", Ring2="Sniper's Ring",
    Back="Cerberus Mantle", Waist="Warwolf Belt", Legs="Byakko's Haidate", Feet="Homam Gambieras",
    Main="Ragnarok", Sub="Pole Grip",
};

sets.WS = {};
sets.WS.Default = {
    Head="Optical Hat", Neck="Chivalrous Chain", Ear1="Brutal Earring", Ear2="Merman's Earring",
    Body="Haubergeon", Hands="Alkyoneus's Bracelets", Ring1="Rajas Ring", Ring2="Woodsman Ring",
    Back="Cerberus Mantle", Waist="Warwolf Belt", Legs="Byakko's Haidate", Feet="Rutter Sabatons",
};
sets.WS["Guillotine"]        = sets.WS.Default;
sets.WS["Cross Reaper"]      = sets.WS.Default;
sets.WS["Spiral Hell"]       = sets.WS.Default;
sets.WS["Catastrophe"]       = sets.WS.Default;
sets.WS["Insurgency"]        = sets.WS.Default;   -- Scythe relic WS
sets.WS["Resolution"]        = sets.WS.Default;
sets.WS["Spinning Slash"]    = sets.WS.Default;

sets.JA = {};
sets.JA["Last Resort"]    = { Feet="Chaos Sollerets" };
sets.JA["Souleater"]      = { Head="Chaos Burgeonet" };
sets.JA["Diabolic Eye"]   = { Hands="Chaos Gauntlets" };
sets.JA["Blood Weapon"]   = { Body="Chaos Cuirass" };
sets.JA["Arcane Circle"]  = { Feet="Chaos Sollerets" };
sets.JA["Weapon Bash"]    = { Hands="Chaos Gauntlets" };
sets.JA["Berserk"]        = { Body="Warrior's Lorica" };  -- /WAR sub

-- Dark magic Absorbs for DRK main
sets.Midcast = {
    Absorb   = { Head="Abyss Burgeonet", Body="Abyss Cuirass", Hands="Abyss Gauntlets", Legs="Abyss Flanchard", Feet="Abyss Sollerets" },
    Drain    = { Head="Abyss Burgeonet", Body="Abyss Cuirass", Neck="Uggalepih Pendant" },
    Aspir    = { Head="Abyss Burgeonet", Neck="Uggalepih Pendant" },
    Stun     = { Head="Duelist's Chapeau", Neck="Uggalepih Pendant", Legs="Igqira Lappas" },
    Utsusemi = { Head="Walahra Turban" },
    Enhancing= {},
};
sets.Precast = { FastCast = { Ear2="Loquac. Earring" } };

profile.OnLoad = function() gSettings.AllowAddSet=true; Sub.echo("[Chharizard DRK] loaded."); end
profile.OnUnload = function() Sub.echo("[Chharizard DRK] unloaded."); end

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
    if (sp.Name:contains('Absorb')) then gFunc.EquipSet(sets.Midcast.Absorb);
    elseif (sp.Name:contains('Drain')) then gFunc.EquipSet(sets.Midcast.Drain);
    elseif (sp.Name:contains('Aspir')) then gFunc.EquipSet(sets.Midcast.Aspir);
    elseif (sp.Name == 'Stun') then gFunc.EquipSet(sets.Midcast.Stun);
    elseif (sp.Name:contains('Utsusemi')) then gFunc.EquipSet(sets.Midcast.Utsusemi); end
end
profile.HandleCommand = function(args)
    if (#args<1) then return; end
    if (Sub.handleCommand(args)) then return; end
    if (args[1]:lower()=='debug') then Sub.debug(); end
end
return profile;
