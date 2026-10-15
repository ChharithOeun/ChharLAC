-- Chharizard DRG - LAC profile (polearm, jumps, era)
local profile = {}; local sets = {}; profile.Sets = sets;
local Sub = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/subjob_features.lua');

sets.Idle = {
    Head="Wyvern Helm", Neck="Peacock Amulet", Ear1="Merman's Earring", Ear2="Ethereal Earring",
    Body="Drachen Mail", Hands="Drachen Finger Gauntlets", Ring1="Sniper's Ring", Ring2="Sniper's Ring",
    Back="Amemet Mantle +1", Waist="Warwolf Belt", Legs="Homam Cosciales", Feet="Homam Gambieras",
    Main="Gungnir", Sub="Pole Grip", Ammo="Fire Bomblet",
};
sets.Movement = { Feet="Rutter Sabatons" };
sets.TP = {
    Head="Walahra Turban", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Assault Earring",
    Body="Haubergeon", Hands="Dusk Gloves", Ring1="Rajas Ring", Ring2="Sniper's Ring",
    Back="Amemet Mantle +1", Waist="Warwolf Belt", Legs="Byakko's Haidate", Feet="Homam Gambieras",
    Main="Gungnir", Sub="Pole Grip",
};

sets.WS = {};
sets.WS.Default = {
    Head="Optical Hat", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Merman's Earring",
    Body="Haubergeon", Hands="Drachen Finger Gauntlets", Ring1="Rajas Ring", Ring2="Woodsman Ring",
    Back="Cerberus Mantle", Waist="Warwolf Belt", Legs="Byakko's Haidate", Feet="Rutter Sabatons",
};
sets.WS["Penta Thrust"]     = sets.WS.Default;
sets.WS["Impulse Drive"]    = sets.WS.Default;
sets.WS["Wheeling Thrust"]  = sets.WS.Default;
sets.WS["Drakesbane"]       = sets.WS.Default;
sets.WS["Stardiver"]        = sets.WS.Default;

sets.JA = {};
sets.JA["Jump"]           = { Hands="Drachen Finger Gauntlets", Legs="Wyrm Brais", Feet="Wyrm Greaves" };
sets.JA["High Jump"]      = { Head="Wyrm Armet", Legs="Wyrm Brais", Feet="Wyrm Greaves" };
sets.JA["Super Jump"]     = { Feet="Wyrm Greaves" };
sets.JA["Spirit Link"]    = { Head="Drachen Helm", Hands="Drachen Finger Gauntlets" };
sets.JA["Ancient Circle"] = { Legs="Wyrm Brais" };
sets.JA["Call Wyvern"]    = { Body="Drachen Mail" };

sets.Precast = { FastCast = { Ear2="Loquac. Earring" } };
sets.Midcast = { Utsusemi = { Head="Walahra Turban" } };

profile.OnLoad = function() gSettings.AllowAddSet=true; Sub.echo("[Chharizard DRG] loaded."); end
profile.OnUnload = function() Sub.echo("[Chharizard DRG] unloaded."); end

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
    if (sp.Name:contains('Utsusemi')) then gFunc.EquipSet(sets.Midcast.Utsusemi); end
end
profile.HandleCommand = function(args)
    if (#args<1) then return; end
    if (Sub.handleCommand(args)) then return; end
    if (args[1]:lower()=='debug') then Sub.debug(); end
end
return profile;
