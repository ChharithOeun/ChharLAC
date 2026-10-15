-- Chharizard BLM - LAC profile (nuker, era)
local profile = {}; local sets = {}; profile.Sets = sets;
local Sub = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/subjob_features.lua');

sets.Idle = {
    Head="Nashira Turban", Neck="Uggalepih Pendant", Ear1="Loquac. Earring", Ear2="Novia Earring",
    Body="Igqira Weskit", Hands="Yigit Gages", Ring1="Ether Ring", Ring2="Star Ring",
    Back="Rainbow Cape", Waist="Sacro Cord", Legs="Nashira Seraweels", Feet="Herald's Gaiters",
    Main="Chatoyant Staff", Sub="Vivid Strap", Ammo="Clarus Stone",
};
sets.Movement = { Feet="Herald's Gaiters" };
sets.Resting = { Head="Nashira Turban", Body="Dalmatica", Ring1="Dark Ring", Waist="Austerity Belt" };
sets.TP = sets.Idle;

sets.Precast = {
    FastCast = { Ear1="Loquac. Earring", Body="Yigit Gomlek", Hands="Yigit Gages", Legs="Nashira Seraweels" },
};

-- Elemental staves table -- LAC will swap based on element
local staff = {
    Fire="Fire Staff", Ice="Ice Staff", Wind="Wind Staff", Earth="Earth Staff",
    Lightning="Thunder Staff", Water="Water Staff", Light="Light Staff", Dark="Dark Staff",
};

sets.Midcast = {
    Elemental = {
        Head="Nahtirah Hat", Neck="Uggalepih Pendant", Ear1="Loquac. Earring", Ear2="Moldavite Earring",
        Body="Igqira Weskit", Hands="Yigit Gages", Ring1="Snow Ring", Ring2="Star Ring",
        Back="Bat Cape", Waist="Sacro Cord", Legs="Igqira Lappas", Feet="Yigit Crackows",
    },
    Enfeebling = { Neck="Uggalepih Pendant", Body="Igqira Weskit", Feet="Yigit Crackows" },
    Enhancing  = { Neck="Colossus's Torque", Body="Nashira Manteel", Hands="Nashira Gages" },
    Dark       = { Head="Nashira Turban", Body="Igqira Weskit", Hands="Yigit Gages" },  -- Drain/Aspir
    Cure       = { Body="Dalmatica", Legs="Nashira Seraweels" },
    Utsusemi   = { Head="Walahra Turban" },
};

sets.WS = { Default = { Head="Nahtirah Hat", Body="Igqira Weskit" } };

sets.JA = {};
sets.JA["Manafont"]        = { Body="Sorcerer's Coat" };
sets.JA["Elemental Seal"]  = { Head="Sorcerer's Petasos" };
sets.JA["Convert"]         = {};

profile.OnLoad = function() gSettings.AllowAddSet=true; Sub.echo("[Chharizard BLM] loaded."); end
profile.OnUnload = function() Sub.echo("[Chharizard BLM] unloaded."); end
profile.HandleDefault = function()
    gFunc.EquipSet(sets.Idle);
    if (gData.GetPlayer().IsMoving) then gFunc.EquipSet(sets.Movement); end
    if (gData.GetPlayer().Status == 'Resting') then gFunc.EquipSet(sets.Resting); end
    Sub.tick(true);
end
profile.HandleEngaged = function() gFunc.EquipSet(sets.TP); Sub.tick(true); end
profile.HandleWeaponskill = function() gFunc.EquipSet(sets.WS.Default); end
profile.HandleAbility = function()
    local ja = gData.GetAction().Name; if (sets.JA[ja]) then gFunc.EquipSet(sets.JA[ja]); end
end
profile.HandlePrecast = function() gFunc.EquipSet(sets.Precast.FastCast); end
profile.HandleMidcast = function()
    local sp = gData.GetAction();
    local elem = sp.Element;
    if (sp.Skill == 'Elemental Magic') then
        gFunc.EquipSet(sets.Midcast.Elemental);
        if (elem and staff[elem]) then gFunc.Equip({ Main=staff[elem] }); end
    elseif (sp.Skill == 'Enfeebling Magic') then gFunc.EquipSet(sets.Midcast.Enfeebling);
    elseif (sp.Skill == 'Enhancing Magic') then gFunc.EquipSet(sets.Midcast.Enhancing);
    elseif (sp.Skill == 'Dark Magic') then gFunc.EquipSet(sets.Midcast.Dark);
    elseif (sp.Name:contains('Cure')) then gFunc.EquipSet(sets.Midcast.Cure);
    elseif (sp.Name:contains('Utsusemi')) then gFunc.EquipSet(sets.Midcast.Utsusemi); end
end
profile.HandleCommand = function(args)
    if (#args<1) then return; end
    if (Sub.handleCommand(args)) then return; end
    if (args[1]:lower()=='debug') then Sub.debug(); end
end
return profile;
