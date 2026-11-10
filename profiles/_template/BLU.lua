-- Chharizard BLU - LAC profile (blue mage, sword, era)
local profile = {}; local sets = {}; profile.Sets = sets;
local Sub  = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/Chharizard_3679/subjob_features.lua');
local Core = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/lac_core.lua');

-- Hidden trainer: self-cast Blue Magic for Blue skillup. Cocoon (lvl 5,
-- Defense Up) + Pollen (lvl 12, self-heal) + Metallic Body (lvl 24,
-- Stoneskin) if learned. `/lac fwd train on`. Hidden from help.
local trainSpells = { 'Cocoon', 'Pollen', 'Metallic Body' };
local trainIdx    = 1;
local function bluTrainer(ply, party)
    if (Core.handleRestCycle(ply, party)) then return; end
    local sp = trainSpells[trainIdx];
    trainIdx = (trainIdx % #trainSpells) + 1;
    Core.auto(string.format('/ma "%s" <me>', sp));
end

sets.Idle = {
    Head="Walahra Turban", Neck="Uggalepih Pendant", Ear1="Loquac. Earring", Ear2="Snow Ear",
    Body="Scout's Jerkin", Hands="Scout's Bracers", Ring1="Sniper's Ring", Ring2="Sniper's Ring",
    Back="Rainbow Cape", Waist="Warwolf Belt", Legs="Homam Cosciales", Feet="Homam Gambieras",
    Main="Joyeuse", Sub="Genbu's Shield", Ammo="Fire Bomblet",
};
sets.Movement = { Feet="Rutter Sabatons" };
sets.TP = {
    Head="Walahra Turban", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Suppanomimi",
    Body="Homam Corazza", Hands="Dusk Gloves", Ring1="Rajas Ring", Ring2="Sniper's Ring",
    Back="Cerberus Mantle", Waist="Swift Belt", Legs="Homam Cosciales", Feet="Homam Gambieras",
    Main="Joyeuse", Sub="Genbu's Shield",
};

sets.WS = {};
sets.WS.Default = {
    Head="Optical Hat", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Merman's Earring",
    Body="Homam Corazza", Hands="Dusk Gloves", Ring1="Rajas Ring", Ring2="Woodsman Ring",
    Back="Cerberus Mantle", Waist="Warwolf Belt", Legs="Byakko's Haidate", Feet="Rutter Sabatons",
};
sets.WS["Chant du Cygne"] = sets.WS.Default;
sets.WS["Vorpal Blade"]   = sets.WS.Default;
sets.WS["Savage Blade"]   = sets.WS.Default;
sets.WS["Requiescat"]     = sets.WS.Default;

sets.Precast = { FastCast = { Head="Scout's Beret", Ear1="Loquac. Earring", Body="Scout's Jerkin", Hands="Scout's Bracers" } };
sets.Midcast = {
    BlueMagic     = { Head="Scout's Beret", Neck="Uggalepih Pendant", Body="Scout's Jerkin", Hands="Scout's Bracers", Legs="Scout's Braccae", Feet="Scout's Socks" },
    BlueMagicPhys = { Neck="Chivalrous Chain", Body="Homam Corazza", Hands="Dusk Gloves", Ring1="Rajas Ring", Ring2="Woodsman Ring", Back="Cerberus Mantle", Waist="Warwolf Belt", Legs="Byakko's Haidate" },
    BlueMagicMag  = { Neck="Uggalepih Pendant", Body="Igqira Weskit", Hands="Summoner's Bracers", Feet="Summoner's Pigaches" },
    BlueMagicHeal = { Neck="Colossus's Torque", Body="Scout's Jerkin", Hands="Scout's Bracers" },
    Cure          = { Body="Dalmatica" },
    Utsusemi      = { Head="Walahra Turban" },
};

sets.JA = {};
sets.JA["Burst Affinity"]  = { Feet="Scout's Socks" };
sets.JA["Chain Affinity"]  = { Head="Scout's Beret", Feet="Mirage Charuqs" };
sets.JA["Efflux"]          = { Legs="Scout's Braccae" };
sets.JA["Azure Lore"]      = { Hands="Scout's Bracers" };

profile.OnLoad = function()
    gSettings.AllowAddSet=true;
    Core.registerTrainer(bluTrainer);
    Sub.echo("[Chharizard BLU] loaded.");
end
profile.OnUnload = function()
    Core.unregisterTrainer(); Core.training = false;
    Sub.echo("[Chharizard BLU] unloaded.");
end

profile.HandleDefault = function()
    gFunc.EquipSet(sets.Idle);
    if (gData.GetPlayer().IsMoving) then gFunc.EquipSet(sets.Movement); end
    Sub.tick(true);
    Core.trainTick();
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
    if (sp.Skill == 'Blue Magic') then
        gFunc.EquipSet(sets.Midcast.BlueMagic);
    elseif (sp.Name:contains('Cure')) then gFunc.EquipSet(sets.Midcast.Cure);
    elseif (sp.Name:contains('Utsusemi')) then gFunc.EquipSet(sets.Midcast.Utsusemi); end
end
profile.HandleCommand = function(args)
    if (#args<1) then return; end
    if (Core.handleCommand(args)) then return; end   -- modes + hidden train
    if (Sub.handleCommand(args)) then return; end
    if (args[1]:lower()=='debug') then Sub.debug(); end
end
return profile;
