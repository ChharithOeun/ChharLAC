-- Chharizard SCH - LAC profile (scholar, stratagems, WoTG)
local profile = {}; local sets = {}; profile.Sets = sets;
local Sub = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/Chharizard_3679/subjob_features.lua');

sets.Idle = {
    Head="Nashira Turban", Neck="Uggalepih Pendant", Ear1="Loquac. Earring", Ear2="Moldavite Earring",
    Body="Scholar's Gown", Hands="Scholar's Bracers", Ring1="Ether Ring", Ring2="Star Ring",
    Back="Rainbow Cape", Waist="Sacro Cord", Legs="Nashira Seraweels", Feet="Herald's Gaiters",
    Main="Chatoyant Staff", Sub="Caster's Cesti",
};
sets.Movement = { Feet="Herald's Gaiters" };
sets.Resting = { Head="Nashira Turban", Body="Dalmatica", Waist="Penitent's Rope" };
sets.TP = sets.Idle;

sets.Precast = {
    FastCast = { Ear1="Loquac. Earring", Body="Scholar's Gown", Legs="Nashira Seraweels" },
};
sets.Midcast = {
    Cure       = { Head="Scholar's Mortarboard", Neck="Phalaina Locket", Body="Scholar's Gown",
                   Hands="Scholar's Bracers", Legs="Scholar's Pants", Feet="Scholar's Loafers" },
    Enhancing  = { Head="Scholar's Mortarboard", Neck="Colossus's Torque", Body="Scholar's Gown" },
    Enfeebling = { Head="Scholar's Mortarboard", Neck="Uggalepih Pendant", Body="Scholar's Gown" },
    Elemental  = { Head="Scholar's Mortarboard", Neck="Uggalepih Pendant", Body="Scholar's Gown",
                   Hands="Scholar's Bracers", Ring1="Snow Ring", Legs="Scholar's Pants" },
    Dark       = { Head="Scholar's Mortarboard", Body="Scholar's Gown" },
    Divine     = { Neck="Uggalepih Pendant" },
    Helix      = { Head="Scholar's Mortarboard", Body="Scholar's Gown", Hands="Scholar's Bracers" },
    Utsusemi   = { Head="Walahra Turban" },
};

sets.WS = { Default = { Head="Scholar's Mortarboard", Body="Scholar's Gown" } };

sets.JA = {};
sets.JA["Light Arts"]     = { Body="Scholar's Gown" };
sets.JA["Dark Arts"]      = { Body="Scholar's Gown" };
sets.JA["Sublimation"]    = { Head="Scholar's Mortarboard" };
sets.JA["Tabula Rasa"]    = { Legs="Scholar's Pants" };
sets.JA["Enlightenment"]  = { Body="Scholar's Gown" };
-- Stratagems (free arts; gear doesn't matter but keep hook)
sets.JA["Penury"]      = { Legs="Scholar's Pants" };
sets.JA["Parsimony"]   = { Legs="Scholar's Pants" };
sets.JA["Celerity"]    = { Feet="Scholar's Loafers" };
sets.JA["Alacrity"]    = { Feet="Scholar's Loafers" };
sets.JA["Rapture"]     = { Head="Scholar's Mortarboard" };
sets.JA["Ebullience"]  = { Head="Scholar's Mortarboard" };

profile.OnLoad = function()
    gSettings.AllowAddSet = true;
    if (not Sub.jobLive('SCH')) then
        print("[Chharizard SCH] WARNING: SCH not yet unlocked on server '"..Sub.server..
              "' (WoTG content). Profile loaded but you can't play the job here.");
    end
    Sub.echo("[Chharizard SCH] loaded.");
end
profile.OnUnload = function() Sub.echo("[Chharizard SCH] unloaded."); end

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
    if (sp.Name:contains('Cure') or sp.Name:contains('Cura')) then gFunc.EquipSet(sets.Midcast.Cure);
    elseif (sp.Name:contains('Helix')) then gFunc.EquipSet(sets.Midcast.Helix);
    elseif (sp.Skill == 'Enhancing Magic') then gFunc.EquipSet(sets.Midcast.Enhancing);
    elseif (sp.Skill == 'Enfeebling Magic') then gFunc.EquipSet(sets.Midcast.Enfeebling);
    elseif (sp.Skill == 'Elemental Magic') then gFunc.EquipSet(sets.Midcast.Elemental);
    elseif (sp.Skill == 'Dark Magic') then gFunc.EquipSet(sets.Midcast.Dark);
    elseif (sp.Skill == 'Divine Magic') then gFunc.EquipSet(sets.Midcast.Divine);
    elseif (sp.Name:contains('Utsusemi')) then gFunc.EquipSet(sets.Midcast.Utsusemi); end
end
profile.HandleCommand = function(args)
    if (#args<1) then return; end
    if (Sub.handleCommand(args)) then return; end
    if (args[1]:lower()=='debug') then Sub.debug(); end
end
return profile;
