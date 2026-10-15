-- Chharizard BRD - LAC profile (singer, era)
local profile = {}; local sets = {}; profile.Sets = sets;
local Sub = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/subjob_features.lua');

sets.Idle = {
    Head="Aoidos' Calot +1", Neck="Aoidos' Matinee", Ear1="Loquac. Earring", Ear2="Musical Earring",
    Body="Aoidos' Hongreline +2", Hands="Aoidos' Manchettes +2", Ring1="Sniper's Ring", Ring2="Star Ring",
    Back="Rainbow Cape", Waist="Corsette +1", Legs="Aoidos' Rhingrave +2", Feet="Aoidos' Cothurnes +2",
    Main="Angel Lyre", Sub="Genbu's Shield", Ammo="Clarus Stone",
};
sets.Movement = { Feet="Rutter Sabatons" };
sets.TP = {
    Head="Walahra Turban", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Suppanomimi",
    Body="Aoidos' Hongreline +2", Hands="Dusk Gloves", Ring1="Rajas Ring", Ring2="Sniper's Ring",
    Back="Cerberus Mantle", Waist="Swift Belt", Legs="Byakko's Haidate", Feet="Homam Gambieras",
    Main="Joyeuse", Sub="Genbu's Shield",
};

sets.Precast = {
    FastCast = { Head="Aoidos' Calot +1", Ear1="Loquac. Earring", Body="Aoidos' Hongreline +2", Hands="Aoidos' Manchettes +2", Legs="Aoidos' Rhingrave +2" },
};
sets.Midcast = {
    Song       = { Head="Aoidos' Calot +1", Neck="Aoidos' Matinee", Ear1="Musical Earring", Body="Aoidos' Hongreline +2", Hands="Aoidos' Manchettes +2", Legs="Aoidos' Rhingrave +2", Feet="Aoidos' Cothurnes +2" },
    SongInst   = {},  -- instrument swap happens in HandleMidcast
    Cure       = { Body="Aoidos' Hongreline +2" },
    Enfeebling = { Neck="Uggalepih Pendant" },
    Utsusemi   = { Head="Walahra Turban" },
};

sets.WS = {};
sets.WS.Default = {
    Head="Optical Hat", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Merman's Earring",
    Body="Aoidos' Hongreline +2", Hands="Dusk Gloves", Ring1="Rajas Ring", Ring2="Woodsman Ring",
    Back="Cerberus Mantle", Waist="Warwolf Belt", Legs="Byakko's Haidate", Feet="Rutter Sabatons",
};
sets.WS["Mercy Stroke"] = sets.WS.Default;
sets.WS["Vorpal Blade"] = sets.WS.Default;
sets.WS["Savage Blade"] = sets.WS.Default;

sets.JA = {};
sets.JA["Nightingale"]  = { Feet="Aoidos' Cothurnes +2" };
sets.JA["Troubadour"]   = { Body="Aoidos' Hongreline +2" };
sets.JA["Soul Voice"]   = { Body="Aoidos' Hongreline +2" };
sets.JA["Pianissimo"]   = {};

profile.OnLoad = function() gSettings.AllowAddSet=true; Sub.echo("[Chharizard BRD] loaded."); end
profile.OnUnload = function() Sub.echo("[Chharizard BRD] unloaded."); end

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
    if (sp.Skill == 'Singing') then
        gFunc.EquipSet(sets.Midcast.Song);
        -- Instrument swap by song type
        if (sp.Name:contains('March') or sp.Name:contains('Minuet') or sp.Name:contains('Madrigal')) then
            gFunc.Equip({ Main="Faerie Piccolo" });
        elseif (sp.Name:contains('Ballad') or sp.Name:contains('Paeon') or sp.Name:contains('Requiem')) then
            gFunc.Equip({ Main="Mary's Horn" });
        else
            gFunc.Equip({ Main="Angel Lyre" });
        end
    elseif (sp.Name:contains('Cure')) then gFunc.EquipSet(sets.Midcast.Cure);
    elseif (sp.Skill == 'Enfeebling Magic') then gFunc.EquipSet(sets.Midcast.Enfeebling);
    elseif (sp.Name:contains('Utsusemi')) then gFunc.EquipSet(sets.Midcast.Utsusemi); end
end
profile.HandleCommand = function(args)
    if (#args<1) then return; end
    if (Sub.handleCommand(args)) then return; end
    if (args[1]:lower()=='debug') then Sub.debug(); end
end
return profile;
