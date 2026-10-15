-- Chharizard COR - LAC profile (corsair, quickdraw + rolls, era)
local profile = {}; local sets = {}; profile.Sets = sets;
local Sub = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/subjob_features.lua');

sets.Idle = {
    Head="Walahra Turban", Neck="Peacock Amulet", Ear1="Merman's Earring", Ear2="Ethereal Earring",
    Body="Commodore Frac", Hands="Commodore Gants", Ring1="Sniper's Ring", Ring2="Sniper's Ring",
    Back="Amemet Mantle +1", Waist="Warwolf Belt", Legs="Corsair's Trews", Feet="Corsair's Bottes",
    Main="Nirvana", Sub="Pole Grip", Ammo="Bullet", Range="Culverin",
};
sets.Movement = { Feet="Rutter Sabatons" };
sets.TP = {
    Head="Optical Hat", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Assault Earring",
    Body="Homam Corazza", Hands="Dusk Gloves", Ring1="Rajas Ring", Ring2="Sniper's Ring",
    Back="Amemet Mantle +1", Waist="Swift Belt", Legs="Homam Cosciales", Feet="Homam Gambieras",
};

sets.Preshot = { Head="Walahra Turban", Legs="Nashira Seraweels" };
sets.Midshot = {
    Head="Optical Hat", Neck="Peacock Amulet", Ear1="Volley Earring", Ear2="Assault Earring",
    Body="Commodore Frac", Hands="Commodore Gants", Ring1="Rajas Ring", Ring2="Woodsman Ring",
    Back="Amemet Mantle +1", Waist="Elanid Belt", Legs="Nashira Seraweels", Feet="Corsair's Bottes",
};

sets.WS = {};
sets.WS.Default = {                           -- ranged WS (Slug Shot, Detonator)
    Head="Optical Hat", Neck="Peacock Amulet", Ear1="Assault Earring", Ear2="Merman's Earring",
    Body="Commodore Frac", Hands="Corsair's Gants", Ring1="Rajas Ring", Ring2="Woodsman Ring",
    Back="Cerberus Mantle", Waist="Elanid Belt", Legs="Corsair's Trews", Feet="Corsair's Bottes",
};
sets.WS["Slug Shot"]     = sets.WS.Default;
sets.WS["Detonator"]     = sets.WS.Default;
sets.WS["Leaden Salute"] = sets.WS.Default;
sets.WS["Wildfire"]      = sets.WS.Default;
sets.WS["Last Stand"]    = sets.WS.Default;

sets.JA = {};
sets.JA["Phantom Roll"]   = { Head="Commodore Tricorne", Hands="Commodore Gants" };
sets.JA["Wild Card"]      = { Feet="Corsair's Bottes" };
sets.JA["Random Deal"]    = { Body="Corsair's Frac" };
sets.JA["Snake Eye"]      = { Legs="Corsair's Trews" };
sets.JA["Double-Up"]      = { Ring1="Barataria Ring" };
sets.JA["Fold"]           = { Hands="Commodore Gants" };
sets.JA["Bust"]           = {};

-- Quickdraw shots (elemental)
sets.Precast = { FastCast = { Ear2="Loquac. Earring" } };
sets.Midcast = {
    QuickDraw = { Head="Commodore Tricorne", Neck="Uggalepih Pendant", Hands="Commodore Gants",
                  Ring1="Snow Ring", Legs="Corsair's Trews" },
    Utsusemi  = { Head="Walahra Turban" },
    Cure      = {},
};

profile.OnLoad = function() gSettings.AllowAddSet=true; Sub.echo("[Chharizard COR] loaded."); end
profile.OnUnload = function() Sub.echo("[Chharizard COR] unloaded."); end

profile.HandleDefault = function()
    gFunc.EquipSet(sets.Idle);
    if (gData.GetPlayer().IsMoving) then gFunc.EquipSet(sets.Movement); end
    Sub.tick(true);
end
profile.HandleEngaged = function() gFunc.EquipSet(sets.TP); Sub.tick(true); end
profile.HandlePreshot = function() gFunc.EquipSet(sets.Preshot); end
profile.HandleMidshot = function() gFunc.EquipSet(sets.Midshot); end
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
    if (sp.Name:contains('Shot')) then gFunc.EquipSet(sets.Midcast.QuickDraw);
    elseif (sp.Name:contains('Cure')) then gFunc.EquipSet(sets.Midcast.Cure);
    elseif (sp.Name:contains('Utsusemi')) then gFunc.EquipSet(sets.Midcast.Utsusemi); end
end
profile.HandleCommand = function(args)
    if (#args<1) then return; end
    if (Sub.handleCommand(args)) then return; end
    if (args[1]:lower()=='debug') then Sub.debug(); end
end
return profile;
