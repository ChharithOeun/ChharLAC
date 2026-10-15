-- Chharizard NIN - LAC profile (dual wield / ninjutsu, era)
local profile = {}; local sets = {}; profile.Sets = sets;
local Sub = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/subjob_features.lua');

sets.Idle = {
    Head="Walahra Turban", Neck="Peacock Amulet", Ear1="Suppanomimi", Ear2="Ethereal Earring",
    Body="Hachiya Chainmail +1", Hands="Iga Tekko +1", Ring1="Sniper's Ring", Ring2="Sniper's Ring",
    Back="Amemet Mantle +1", Waist="Warwolf Belt", Legs="Byakko's Haidate", Feet="Iga Kyahan +1",
    Main="Kagenui", Sub="Bloody Bolts", Ammo="Fire Bomblet",
};
sets.Movement = { Feet="Rutter Sabatons" };
sets.TP = {
    Head="Walahra Turban", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Suppanomimi",
    Body="Hachiya Chainmail +1", Hands="Dusk Gloves", Ring1="Rajas Ring", Ring2="Sniper's Ring",
    Back="Cerberus Mantle", Waist="Swift Belt", Legs="Byakko's Haidate", Feet="Homam Gambieras",
    Main="Kagenui", Sub="Kanjizai",
};

sets.WS = {};
sets.WS.Default = {
    Head="Optical Hat", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Merman's Earring",
    Body="Hachiya Chainmail +1", Hands="Dusk Gloves", Ring1="Rajas Ring", Ring2="Woodsman Ring",
    Back="Cerberus Mantle", Waist="Warwolf Belt", Legs="Byakko's Haidate", Feet="Rutter Sabatons",
};
sets.WS["Blade: Jin"]   = sets.WS.Default;
sets.WS["Blade: Ten"]   = sets.WS.Default;
sets.WS["Blade: Ku"]    = sets.WS.Default;
sets.WS["Blade: Metsu"] = sets.WS.Default;
sets.WS["Blade: Shun"]  = sets.WS.Default;
sets.WS["Blade: Hi"]    = sets.WS.Default;

sets.JA = {};
sets.JA["Mijin Gakure"]  = { Feet="Ninja Kyahan" };
sets.JA["Futae"]         = { Hands="Iga Tekko +1" };
sets.JA["Sange"]         = { Legs="Iga Hakama +1" };
sets.JA["Yonin"]         = { Body="Hachiya Chainmail +1" };
sets.JA["Innin"]         = { Head="Iga Zukin +1" };

sets.Precast = {
    FastCast = { Head="Walahra Turban", Ear2="Loquac. Earring", Body="Hachiya Chainmail +1", Hands="Iga Tekko +1", Legs="Iga Hakama +1" },
    Utsusemi = { Head="Walahra Turban", Neck="Magoraga Beads", Ear2="Loquac. Earring", Feet="Iga Kyahan +1" },
};
sets.Midcast = {
    Ninjutsu       = { Head="Iga Zukin +1", Neck="Uggalepih Pendant", Body="Hachiya Chainmail +1", Hands="Hachiya Tekko +1", Feet="Iga Kyahan +1" },
    NinjutsuDmg    = { Neck="Uggalepih Pendant", Hands="Hachiya Tekko +1" },
    NinjutsuEnfeeb = { Hands="Hachiya Tekko +1", Feet="Iga Kyahan +1" },
    Utsusemi       = { Neck="Magoraga Beads", Ear2="Loquac. Earring", Feet="Iga Kyahan +1" },
    Cure           = {},
};

profile.OnLoad = function() gSettings.AllowAddSet=true; Sub.echo("[Chharizard NIN] loaded."); end
profile.OnUnload = function() Sub.echo("[Chharizard NIN] unloaded."); end

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
profile.HandlePrecast = function()
    local sp = gData.GetAction();
    if (sp.Name and sp.Name:contains('Utsusemi')) then
        gFunc.EquipSet(sets.Precast.Utsusemi);
    else
        gFunc.EquipSet(sets.Precast.FastCast);
    end
end
profile.HandleMidcast = function()
    local sp = gData.GetAction();
    if (sp.Name:contains('Utsusemi')) then gFunc.EquipSet(sets.Midcast.Utsusemi);
    elseif (sp.Skill == 'Ninjutsu') then
        -- differentiate damage nins vs enfeeb nins
        if (sp.Name:contains(': Ni') or sp.Name:contains(': Ichi') or sp.Name:contains(': San')) then
            gFunc.EquipSet(sets.Midcast.NinjutsuDmg);
        else
            gFunc.EquipSet(sets.Midcast.NinjutsuEnfeeb);
        end
    elseif (sp.Name:contains('Cure')) then gFunc.EquipSet(sets.Midcast.Cure); end
end
profile.HandleCommand = function(args)
    if (#args<1) then return; end
    if (Sub.handleCommand(args)) then return; end
    if (args[1]:lower()=='debug') then Sub.debug(); end
end
return profile;
