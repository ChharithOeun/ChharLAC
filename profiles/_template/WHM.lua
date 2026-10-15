-- Chharizard WHM - LAC profile (healer, era)
local profile = {}; local sets = {}; profile.Sets = sets;
local Sub = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/subjob_features.lua');

sets.Idle = {
    Head="Nashira Turban", Neck="Uggalepih Pendant", Ear1="Loquac. Earring", Ear2="Novia Earring",
    Body="Nashira Manteel", Hands="Yigit Gages", Ring1="Ether Ring", Ring2="Star Ring",
    Back="Rainbow Cape", Waist="Sacro Cord", Legs="Nashira Seraweels", Feet="Herald's Gaiters",
    Main="Chatoyant Staff", Sub="Vivid Strap", Ammo="Clarus Stone",
};
sets.Movement = { Feet="Herald's Gaiters" };
sets.Resting = { Head="Nashira Turban", Body="Dalmatica", Waist="Austerity Belt" };
sets.TP = sets.Idle;

sets.Precast = {
    FastCast = { Ear1="Loquac. Earring", Body="Dalmatica", Legs="Nashira Seraweels" },
};
sets.Midcast = {
    Cure       = { Head="Nahtirah Hat", Neck="Phalaina Locket", Ear1="Loquac. Earring", Ear2="Novia Earring",
                   Body="Alb Cornette", Hands="Yigit Gages", Ring1="Ether Ring", Ring2="Star Ring",
                   Back="Pahtli Cape", Waist="Cleric's Belt", Legs="Cleric's Pantaloons", Feet="Herald's Gaiters" },
    CureII     = nil,  -- fallback to Cure
    Enhancing  = { Head="Nashira Turban", Neck="Colossus's Torque", Body="Nashira Manteel", Hands="Nashira Gages" },
    Enfeebling = { Head="Nashira Turban", Neck="Uggalepih Pendant", Body="Nashira Manteel", Hands="Nashira Gages", Feet="Yigit Crackows" },
    Elemental  = { Head="Nahtirah Hat", Neck="Uggalepih Pendant", Body="Igqira Weskit", Hands="Yigit Gages", Ring1="Star Ring", Feet="Yigit Crackows" },
    Divine     = { Head="Nashira Turban", Neck="Uggalepih Pendant", Body="Nashira Manteel" },
    Utsusemi   = { Head="Walahra Turban" },
    Healing    = { Ring1="Ether Ring" },
};

sets.WS = { Default = { Head="Nahtirah Hat", Body="Nashira Manteel", Hands="Yigit Gages" } };

sets.JA = {};
sets.JA["Benediction"]  = { Body="Piety Bliaut" };
sets.JA["Divine Seal"]  = { Head="Piety Coif" };
sets.JA["Devotion"]     = { Head="Piety Coif" };
sets.JA["Afflatus Solace"] = { Body="Orison Bliaut" };
sets.JA["Afflatus Misery"] = { Body="Orison Bliaut" };

profile.OnLoad = function() gSettings.AllowAddSet = true; Sub.echo("[Chharizard WHM] loaded."); end
profile.OnUnload = function() Sub.echo("[Chharizard WHM] unloaded."); end
profile.HandleDefault = function()
    gFunc.EquipSet(sets.Idle);
    if (gData.GetPlayer().IsMoving) then gFunc.EquipSet(sets.Movement); end
    if (gData.GetPlayer().Status == 'Resting') then gFunc.EquipSet(sets.Resting); end
    Sub.tick(true);
end
profile.HandleEngaged = function() gFunc.EquipSet(sets.TP); Sub.tick(true); end
profile.HandleWeaponskill = function() gFunc.EquipSet(sets.WS.Default); end
profile.HandleAbility = function()
    local ja = gData.GetAction().Name;
    if (sets.JA[ja]) then gFunc.EquipSet(sets.JA[ja]); end
end
profile.HandlePrecast = function() gFunc.EquipSet(sets.Precast.FastCast); end
profile.HandleMidcast = function()
    local sp = gData.GetAction();
    if (sp.Name:contains('Cure') or sp.Name:contains('Cura')) then gFunc.EquipSet(sets.Midcast.Cure);
    elseif (sp.Skill == 'Enhancing Magic') then gFunc.EquipSet(sets.Midcast.Enhancing);
    elseif (sp.Skill == 'Enfeebling Magic') then gFunc.EquipSet(sets.Midcast.Enfeebling);
    elseif (sp.Skill == 'Elemental Magic') then gFunc.EquipSet(sets.Midcast.Elemental);
    elseif (sp.Skill == 'Divine Magic') then gFunc.EquipSet(sets.Midcast.Divine);
    elseif (sp.Name:contains('Utsusemi')) then gFunc.EquipSet(sets.Midcast.Utsusemi); end
end
profile.HandleCommand = function(args)
    if (#args<1) then return; end
    if (Sub.handleCommand(args)) then return; end
    if (args[1]:lower()=='debug') then Sub.debug(); end
end
return profile;
