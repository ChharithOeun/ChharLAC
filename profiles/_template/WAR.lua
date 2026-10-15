-- ============================================================================
-- Chharizard WAR - LuAshitaCast profile (era-progressive, ToAU/WoTG)
-- Weapons: Great Axe (Bravura path) primary; G. Sword/Polearm swap-capable.
-- ============================================================================

local profile = {};
local sets = {};
profile.Sets = sets;
local Sub = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/subjob_features.lua');

sets.Idle = {
    Head="Walahra Turban", Neck="Peacock Amulet", Ear1="Merman's Earring", Ear2="Ethereal Earring",
    Body="Haubergeon", Hands="Alkyoneus's Bracelets", Ring1="Sniper's Ring", Ring2="Sniper's Ring",
    Back="Amemet Mantle +1", Waist="Warwolf Belt", Legs="Homam Cosciales", Feet="Homam Gambieras",
    Main="Bravura", Sub="Pole Grip", Ammo="Fire Bomblet",
};
sets.Movement = { Feet="Rutter Sabatons" };
sets.TP = {
    Head="Walahra Turban", Neck="Chivalrous Chain", Ear1="Brutal Earring", Ear2="Suppanomimi",
    Body="Haubergeon", Hands="Dusk Gloves", Ring1="Toreador's Ring", Ring2="Rajas Ring",
    Back="Forager's Mantle", Waist="Warwolf Belt", Legs="Byakko's Haidate", Feet="Homam Gambieras",
    Main="Bravura", Sub="Pole Grip",
};
sets.PDT = {
    Head="Adaman Celata", Neck="Chivalrous Chain",
    Body="Haubergeon", Hands="Alkyoneus's Bracelets",
    Ring1="Shell Ring", Ring2="Shell Ring", Back="Shadow Mantle",
    Waist="Warwolf Belt", Legs="Byakko's Haidate", Feet="Homam Gambieras",
};

sets.WS = {};
sets.WS.Default = {
    Head="Optical Hat", Neck="Chivalrous Chain", Ear1="Brutal Earring", Ear2="Merman's Earring",
    Body="Haubergeon", Hands="Alkyoneus's Bracelets",
    Ring1="Rajas Ring", Ring2="Woodsman Ring", Back="Cerberus Mantle",
    Waist="Warwolf Belt", Legs="Byakko's Haidate", Feet="Rutter Sabatons",
};
sets.WS["Steel Cyclone"]    = sets.WS.Default;   -- Great Axe, STR/VIT
sets.WS["Raging Rush"]      = sets.WS.Default;   -- Great Axe relic, STR
sets.WS["Rampage"]          = sets.WS.Default;
sets.WS["King's Justice"]   = sets.WS.Default;
sets.WS["Metatron Torment"] = sets.WS.Default;
sets.WS["Spinning Slash"]   = sets.WS.Default;   -- Great Sword

sets.JA = {};
sets.JA["Berserk"]     = { Body="Warrior's Lorica", Feet="Warrior's Calligae" };
sets.JA["Warcry"]      = { Head="Warrior's Mask" };
sets.JA["Defender"]    = { Hands="Warrior's Mufflers" };
sets.JA["Aggressor"]   = { Head="Warrior's Mask", Body="Warrior's Lorica" };
sets.JA["Mighty Strikes"] = { Hands="Warrior's Mufflers" };
sets.JA["Provoke"]     = { Neck="Chivalrous Chain", Ring1="Wivre Ring" };

sets.Precast = { FastCast = { Ear2="Loquac. Earring", Body="Homam Corazza" } };
sets.Midcast = {
    Utsusemi = { Head="Walahra Turban", Feet="Yigit Crackows" },
    Enhancing= {},
    Cure     = {},
};

profile.OnLoad = function()
    gSettings.AllowAddSet = true;
    Sub.echo("[Chharizard WAR] Profile loaded.");
end
profile.OnUnload = function() Sub.echo("[Chharizard WAR] Profile unloaded."); end

profile.HandleDefault = function()
    gFunc.EquipSet(sets.Idle);
    if (gData.GetPlayer().IsMoving) then gFunc.EquipSet(sets.Movement); end
    Sub.tick(true);
end
profile.HandleEngaged = function()
    gFunc.EquipSet(sets.TP); Sub.tick(true);
end
profile.HandleWeaponskill = function()
    local ws = gData.GetAction().Name;
    if (sets.WS[ws]) then gFunc.EquipSet(sets.WS[ws]);
    else gFunc.EquipSet(sets.WS.Default); end
end
profile.HandleAbility = function()
    local ja = gData.GetAction().Name;
    if (sets.JA[ja]) then gFunc.EquipSet(sets.JA[ja]); end
end
profile.HandlePrecast = function() gFunc.EquipSet(sets.Precast.FastCast); end
profile.HandleMidcast = function()
    local sp = gData.GetAction();
    if (sp.Name:contains('Cure')) then gFunc.EquipSet(sets.Midcast.Cure);
    elseif (sp.Name:contains('Utsusemi')) then gFunc.EquipSet(sets.Midcast.Utsusemi); end
end

profile.HandleCommand = function(args)
    if (#args < 1) then return; end
    if (Sub.handleCommand(args)) then return; end
    local cmd = args[1]:lower();
    if (cmd == 'pdt') then gFunc.ForceEquipSet(sets.PDT); Sub.echo('[WAR] PDT'); return; end
    if (cmd == 'debug') then Sub.debug(); return; end
end

return profile;
