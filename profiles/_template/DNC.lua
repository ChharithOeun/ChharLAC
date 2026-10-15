-- Chharizard DNC - LAC profile (dancer, waltz/samba/step, era WoTG)
local profile = {}; local sets = {}; profile.Sets = sets;
local Sub = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/subjob_features.lua');

sets.Idle = {
    Head="Walahra Turban", Neck="Peacock Amulet", Ear1="Suppanomimi", Ear2="Brutal Earring",
    Body="Etoile Casaque", Hands="Etoile Bangles", Ring1="Sniper's Ring", Ring2="Sniper's Ring",
    Back="Amemet Mantle +1", Waist="Warwolf Belt", Legs="Byakko's Haidate", Feet="Etoile Toe Shoes",
    Main="Terpsichore", Sub="Kila", Ammo="Fire Bomblet",
};
sets.Movement = { Feet="Rutter Sabatons" };
sets.TP = {
    Head="Walahra Turban", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Suppanomimi",
    Body="Etoile Casaque", Hands="Dusk Gloves", Ring1="Rajas Ring", Ring2="Sniper's Ring",
    Back="Cerberus Mantle", Waist="Swift Belt", Legs="Byakko's Haidate", Feet="Homam Gambieras",
    Main="Terpsichore", Sub="Kila",
};

sets.WS = {};
sets.WS.Default = {
    Head="Optical Hat", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Assault Earring",
    Body="Etoile Casaque", Hands="Homam Manopolas", Ring1="Rajas Ring", Ring2="Woodsman Ring",
    Back="Cerberus Mantle", Waist="Warwolf Belt", Legs="Byakko's Haidate", Feet="Rutter Sabatons",
};
sets.WS["Evisceration"]    = sets.WS.Default;
sets.WS["Pyrrhic Kleos"]   = sets.WS.Default;
sets.WS["Exenterator"]     = sets.WS.Default;
sets.WS["Rudra's Storm"]   = sets.WS.Default;

sets.JA = {};
-- Waltzes -- boost cure amount
sets.JA["Curing Waltz"]       = { Head="Etoile Tiara", Body="Etoile Casaque", Hands="Etoile Bangles", Legs="Etoile Tights" };
sets.JA["Curing Waltz II"]    = sets.JA["Curing Waltz"];
sets.JA["Curing Waltz III"]   = sets.JA["Curing Waltz"];
sets.JA["Divine Waltz"]       = sets.JA["Curing Waltz"];
sets.JA["Healing Waltz"]      = { Hands="Etoile Bangles" };
-- Sambas
sets.JA["Haste Samba"]        = { Feet="Etoile Toe Shoes" };
sets.JA["Drain Samba"]        = { Feet="Etoile Toe Shoes" };
sets.JA["Aspir Samba"]        = { Feet="Etoile Toe Shoes" };
-- Steps
sets.JA["Quickstep"]          = { Legs="Etoile Tights" };
sets.JA["Box Step"]           = { Legs="Etoile Tights" };
sets.JA["Stutter Step"]       = { Legs="Etoile Tights" };
sets.JA["Feather Step"]       = { Legs="Etoile Tights" };
-- Others
sets.JA["Fan Dance"]          = { Body="Etoile Casaque" };
sets.JA["No Foot Rise"]       = { Body="Etoile Casaque" };
sets.JA["Trance"]             = { Head="Etoile Tiara" };
sets.JA["Chocobo Jig"]        = { Feet="Etoile Toe Shoes" };
sets.JA["Chocobo Jig II"]     = { Feet="Etoile Toe Shoes" };

sets.Precast = { FastCast = { Ear2="Loquac. Earring" } };
sets.Midcast = { Utsusemi = { Head="Walahra Turban" } };

profile.OnLoad = function()
    gSettings.AllowAddSet = true;
    if (not Sub.jobLive('DNC')) then
        print("[Chharizard DNC] WARNING: DNC not yet unlocked on server '"..Sub.server..
              "' (WoTG content). Profile loaded but you can't play the job here.");
    end
    Sub.echo("[Chharizard DNC] loaded.");
end
profile.OnUnload = function() Sub.echo("[Chharizard DNC] unloaded."); end

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
