-- Chharizard BLM - LAC profile (nuker, era)
local profile = {}; local sets = {}; profile.Sets = sets;
local Sub  = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/Chharizard_3679/subjob_features.lua');
local Core = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/lac_core.lua');

sets.Idle = {
    Head="Nashira Turban", Neck="Uggalepih Pendant", Ear1="Loquac. Earring", Ear2="Moldavite Earring",
    Body="Igqira Weskit", Hands="Summoner's Bracers", Ring1="Ether Ring", Ring2="Star Ring",
    Back="Rainbow Cape", Waist="Sacro Cord", Legs="Nashira Seraweels", Feet="Herald's Gaiters",
    Main="Chatoyant Staff", Sub="Caster's Cesti",
};
sets.Movement = { Feet="Herald's Gaiters" };
sets.Resting = { Head="Nashira Turban", Body="Dalmatica", Ring1="Dark Ring", Waist="Penitent's Rope" };
sets.TP = sets.Idle;

sets.Precast = {
    FastCast = { Ear1="Loquac. Earring", Body="Summoner's Doublet", Hands="Summoner's Bracers", Legs="Nashira Seraweels" },
};

-- Elemental staves table -- LAC will swap based on element
local staff = {
    Fire="Fire Staff", Ice="Ice Staff", Wind="Wind Staff", Earth="Earth Staff",
    Lightning="Thunder Staff", Water="Water Staff", Light="Light Staff", Dark="Dark Staff",
};

sets.Midcast = {
    Elemental = {
        Head="Walahra Turban", Neck="Uggalepih Pendant", Ear1="Loquac. Earring", Ear2="Moldavite Earring",
        Body="Igqira Weskit", Hands="Summoner's Bracers", Ring1="Snow Ring", Ring2="Star Ring",
        Back="Bat Cape", Waist="Sacro Cord", Legs="Igqira Lappas", Feet="Summoner's Pigaches",
    },
    Enfeebling = { Neck="Uggalepih Pendant", Body="Igqira Weskit", Feet="Summoner's Pigaches" },
    Enhancing  = { Neck="Colossus's Torque", Body="Nashira Manteel", Hands="Nashira Gages" },
    Dark       = { Head="Nashira Turban", Body="Igqira Weskit", Hands="Summoner's Bracers" },  -- Drain/Aspir
    Cure       = { Body="Dalmatica", Legs="Nashira Seraweels" },
    Utsusemi   = { Head="Walahra Turban" },
};

sets.WS = { Default = { Head="Walahra Turban", Body="Igqira Weskit" } };

sets.JA = {};
sets.JA["Manafont"]        = { Body="Sorcerer's Coat" };
sets.JA["Elemental Seal"]  = { Head="Sorcerer's Petasos" };
sets.JA["Convert"]         = {};

-- Hidden trainer: cycles single-target nukes (Elemental) + Drain (Dark). All
-- self-cast to burn MP for skillup. `/lac fwd train on`. Hidden from help.
local trainSpells = { 'Stone', 'Water', 'Aero', 'Fire', 'Blizzard', 'Thunder', 'Drain' };
local trainIdx    = 1;
local function blmTrainer(ply, party)
    if (Core.handleRestCycle(ply, party)) then return; end
    local sp = trainSpells[trainIdx];
    trainIdx = (trainIdx % #trainSpells) + 1;
    Core.auto(string.format('/ma "%s" <me>', sp));   -- self-nuke tiny dmg; skillup
end

profile.OnLoad = function()
    gSettings.AllowAddSet=true;
    Core.registerTrainer(blmTrainer);
    Sub.echo("[Chharizard BLM] loaded.");
end
profile.OnUnload = function()
    Core.unregisterTrainer(); Core.training = false;
    Sub.echo("[Chharizard BLM] unloaded.");
end
profile.HandleDefault = function()
    gFunc.EquipSet(sets.Idle);
    if (gData.GetPlayer().IsMoving) then gFunc.EquipSet(sets.Movement); end
    if (gData.GetPlayer().Status == 'Resting') then gFunc.EquipSet(sets.Resting); end
    Sub.tick(true);
    Core.trainTick();
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
        if (elem and staff[elem]) then gFunc.EquipSet({ Main=staff[elem] }); end
    elseif (sp.Skill == 'Enfeebling Magic') then gFunc.EquipSet(sets.Midcast.Enfeebling);
    elseif (sp.Skill == 'Enhancing Magic') then gFunc.EquipSet(sets.Midcast.Enhancing);
    elseif (sp.Skill == 'Dark Magic') then gFunc.EquipSet(sets.Midcast.Dark);
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
