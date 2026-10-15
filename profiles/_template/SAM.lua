-- Chharizard SAM - LAC profile (great katana, hasso/seigan, era)
local profile = {}; local sets = {}; profile.Sets = sets;
local Sub = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/subjob_features.lua');

sets.Idle = {
    Head="Walahra Turban", Neck="Peacock Amulet", Ear1="Merman's Earring", Ear2="Ethereal Earring",
    Body="Haubergeon", Hands="Kirin's Osode", Ring1="Sniper's Ring", Ring2="Sniper's Ring",
    Back="Amemet Mantle +1", Waist="Warwolf Belt", Legs="Byakko's Haidate", Feet="Homam Gambieras",
    Main="Kikoku", Sub="Pole Grip", Ammo="Fire Bomblet",
};
sets.Movement = { Feet="Rutter Sabatons" };
sets.TP = {
    Head="Walahra Turban", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Assault Earring",
    Body="Haubergeon", Hands="Dusk Gloves", Ring1="Rajas Ring", Ring2="Sniper's Ring",
    Back="Cerberus Mantle", Waist="Warwolf Belt", Legs="Byakko's Haidate", Feet="Homam Gambieras",
    Main="Kikoku", Sub="Pole Grip",
};

sets.WS = {};
sets.WS.Default = {
    Head="Optical Hat", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Merman's Earring",
    Body="Haubergeon", Hands="Dusk Gloves", Ring1="Rajas Ring", Ring2="Woodsman Ring",
    Back="Cerberus Mantle", Waist="Warwolf Belt", Legs="Byakko's Haidate", Feet="Rutter Sabatons",
};
sets.WS["Tachi: Kasha"]    = sets.WS.Default;
sets.WS["Tachi: Gekko"]    = sets.WS.Default;
sets.WS["Tachi: Yukikaze"] = sets.WS.Default;
sets.WS["Tachi: Rana"]     = sets.WS.Default;
sets.WS["Tachi: Ageha"]    = sets.WS.Default;
sets.WS["Tachi: Fudo"]     = sets.WS.Default;

sets.JA = {};
sets.JA["Meditate"]           = { Head="Saotome Kabuto" };
sets.JA["Hasso"]              = { Hands="Saotome Kote" };
sets.JA["Seigan"]             = { Head="Myochin Kabuto" };
sets.JA["Third Eye"]          = { Legs="Saotome Haidate" };
sets.JA["Warding Circle"]     = { Head="Saotome Kabuto" };
sets.JA["Meikyo Shisui"]      = { Feet="Saotome Sune-Ate" };

sets.Precast = { FastCast = { Ear2="Loquac. Earring" } };
sets.Midcast = { Utsusemi = { Head="Walahra Turban" } };

profile.OnLoad = function() gSettings.AllowAddSet=true; Sub.echo("[Chharizard SAM] loaded."); end
profile.OnUnload = function() Sub.echo("[Chharizard SAM] unloaded."); end

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
