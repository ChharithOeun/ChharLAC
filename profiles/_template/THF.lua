-- Chharizard THF - LAC profile (DA/crit, SA+TA, era)
local profile = {}; local sets = {}; profile.Sets = sets;
local Sub = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/subjob_features.lua');

sets.Idle = {
    Head="Empress Hairpin", Neck="Peacock Amulet", Ear1="Merman's Earring", Ear2="Ethereal Earring",
    Body="Assassin's Vest", Hands="Assassin's Armlets +1", Ring1="Sniper's Ring", Ring2="Sniper's Ring",
    Back="Amemet Mantle +1", Waist="Warwolf Belt", Legs="Homam Cosciales", Feet="Homam Gambieras",
    Main="Mandau", Sub="Kila", Ammo="Fire Bomblet",
};
sets.Movement = { Feet="Rutter Sabatons" };
sets.TP = {
    Head="Walahra Turban", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Suppanomimi",
    Body="Scorpion Harness", Hands="Homam Manopolas", Ring1="Rajas Ring", Ring2="Sniper's Ring",
    Back="Cerberus Mantle", Waist="Swift Belt", Legs="Homam Cosciales", Feet="Homam Gambieras",
};
sets.TH = { Hands="Assassin's Armlets +1", Waist="Chaac Belt", Feet="Raider's Poulaines" };

sets.WS = {};
sets.WS.Default = {
    Head="Optical Hat", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Assault Earring",
    Body="Scorpion Harness", Hands="Homam Manopolas", Ring1="Rajas Ring", Ring2="Woodsman Ring",
    Back="Cerberus Mantle", Waist="Warwolf Belt", Legs="Byakko's Haidate", Feet="Homam Gambieras",
};
sets.WS["Dancing Edge"]    = sets.WS.Default;
sets.WS["Evisceration"]    = sets.WS.Default;
sets.WS["Rudra's Storm"]   = sets.WS.Default;
sets.WS["Shark Bite"]      = sets.WS.Default;
sets.WS["Mercy Stroke"]    = sets.WS.Default;
sets.WS["Mandalic Stab"]   = sets.WS.Default;

sets.JA = {};
sets.JA["Sneak Attack"]   = { Head="Assassin's Bonnet +1", Body="Assassin's Vest", Legs="Assassin's Culottes +1", Ring1="Rajas Ring" };
sets.JA["Trick Attack"]   = { Hands="Assassin's Armlets +1", Legs="Raider's Trousers", Feet="Raider's Poulaines" };
sets.JA["Hide"]           = { Body="Assassin's Vest" };
sets.JA["Flee"]           = { Feet="Rogue's Poulaines" };
sets.JA["Perfect Dodge"]  = { Hands="Assassin's Armlets +1" };
sets.JA["Steal"]          = { Head="Assassin's Bonnet +1", Hands="Rogue's Armlets", Feet="Rogue's Poulaines" };
sets.JA["Mug"]            = { Head="Assassin's Bonnet +1" };

sets.Precast = { FastCast = { Ear2="Loquac. Earring" } };
sets.Midcast = { Utsusemi = { Head="Walahra Turban" } };

profile.OnLoad = function() gSettings.AllowAddSet=true; Sub.echo("[Chharizard THF] loaded."); end
profile.OnUnload = function() Sub.echo("[Chharizard THF] unloaded."); end

profile.HandleDefault = function()
    gFunc.EquipSet(sets.Idle);
    if (gData.GetPlayer().IsMoving) then gFunc.EquipSet(sets.Movement); end
    Sub.tick(true);
end
profile.HandleEngaged = function()
    gFunc.EquipSet(sets.TP);
    -- Layer TH on top (TH gear is a superset of TP gear anyway for THF)
    gFunc.EquipSet(sets.TH);
    Sub.tick(true);
end
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
    if (sp.Name:contains('Utsusemi')) then gFunc.EquipSet(sets.Midcast.Utsusemi); end
end
profile.HandleCommand = function(args)
    if (#args<1) then return; end
    if (Sub.handleCommand(args)) then return; end
    if (args[1]:lower()=='debug') then Sub.debug(); end
end
return profile;
