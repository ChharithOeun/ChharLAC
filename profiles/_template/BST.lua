-- Chharizard BST - LAC profile (pet management, era)
local profile = {}; local sets = {}; profile.Sets = sets;
local Sub = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/subjob_features.lua');
local Pet = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/bst_pet.lua');

sets.Idle = {
    Head="Walahra Turban", Neck="Peacock Amulet", Ear1="Merman's Earring", Ear2="Ethereal Earring",
    Body="Beast Jackcoat +1", Hands="Beast Gloves", Ring1="Sniper's Ring", Ring2="Sniper's Ring",
    Back="Amemet Mantle +1", Waist="Warwolf Belt", Legs="Beast Trousers", Feet="Beast Gaiters",
    Main="Guttler", Sub="Pole Grip", Ammo="Pet Food Theta",
};
sets.Movement = { Feet="Rutter Sabatons" };
sets.TP = {
    Head="Optical Hat", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Suppanomimi",
    Body="Beast Jackcoat +1", Hands="Beast Gloves", Ring1="Rajas Ring", Ring2="Sniper's Ring",
    Back="Amemet Mantle +1", Waist="Warwolf Belt", Legs="Byakko's Haidate", Feet="Beast Gaiters",
    Main="Guttler",
};

sets.PetTP = {                   -- charmed/jugged pet is engaged
    Head="Beast Helm", Neck="Beastmaster's Collar", Ear1="Rimeice Earring", Ear2="Flameice Earring",
    Body="Beast Jackcoat +1", Hands="Beast Gloves", Ring1="Ferine Ring", Ring2="Ferine Ring",
    Back="Beast Mantle", Waist="Sagacity Belt", Legs="Beast Trousers", Feet="Beast Gaiters",
};

sets.WS = {};
sets.WS.Default = {
    Head="Optical Hat", Neck="Peacock Amulet", Ear1="Brutal Earring", Ear2="Assault Earring",
    Body="Scorpion Harness", Hands="Beast Gloves", Ring1="Rajas Ring", Ring2="Woodsman Ring",
    Back="Cerberus Mantle", Waist="Warwolf Belt", Legs="Byakko's Haidate", Feet="Rutter Sabatons",
};
sets.WS["Onslaught"]    = sets.WS.Default;   -- Axe
sets.WS["Ruinator"]     = sets.WS.Default;
sets.WS["Decimation"]   = sets.WS.Default;
sets.WS["Primal Rend"]  = sets.WS.Default;

sets.JA = {};
sets.JA["Call Beast"]   = { Body="Beast Jackcoat +1" };
sets.JA["Reward"]       = { Head="Beast Helm", Body="Beast Jackcoat +1", Hands="Beast Gloves", Legs="Beast Trousers" };
sets.JA["Charm"]        = { Head="Beast Helm", Hands="Beast Gloves", Waist="Sagacity Belt" };
sets.JA["Sic"]          = { Feet="Beast Gaiters" };
sets.JA["Fight"]        = {};
sets.JA["Familiar"]     = { Body="Beast Jackcoat +1" };
sets.JA["Feral Howl"]   = { Head="Beast Helm" };
sets.JA["Killer Instinct"] = { Body="Beast Jackcoat +1" };

sets.Precast = { FastCast = { Ear2="Loquac. Earring" } };
sets.Midcast = { Utsusemi = { Head="Walahra Turban" } };

profile.OnLoad = function()
    gSettings.AllowAddSet=true;
    Pet.hook(); Pet.hookHUD();
    Sub.echo("[Chharizard BST] loaded (pet HUD + JA tracker active).");
end
profile.OnUnload = function()
    Pet.unhook();
    Sub.echo("[Chharizard BST] unloaded.");
end

-- Auto-decision tick (called from HandleDefault/HandleEngaged)
local lastAutoFire = 0;
local function autoTick()
    local now = os.time();
    if ((now - lastAutoFire) < 2) then return; end  -- 2s floor between fires

    -- Auto-Reward when pet dips below HPP threshold
    if (Pet.autoReward and Pet.canReward()) then
        local pet = Pet.pet();
        if (pet and pet.HPP < Pet.rewardHppThreshold) then
            AshitaCore:GetChatManager():QueueCommand(1, '/ja "Reward" <t>');
            Sub.echo(string.format('[BST] Auto-Reward (pet %d%% < %d%%)',
                pet.HPP, Pet.rewardHppThreshold));
            lastAutoFire = now;
            return;
        end
    end

    -- Auto-Call Beast when pet is dead/gone AND recast is up
    if (Pet.autoCall and Pet.canCall()) then
        AshitaCore:GetChatManager():QueueCommand(1, '/ja "Call Beast" <me>');
        Sub.echo('[BST] Auto-Call Beast');
        lastAutoFire = now;
        return;
    end
end
profile._autoTick = autoTick;

profile.HandleDefault = function()
    local pet = gData.GetPet();
    if (pet and pet.Status == 'Engaged') then
        gFunc.EquipSet(sets.PetTP);
    else
        gFunc.EquipSet(sets.Idle);
    end
    if (gData.GetPlayer().IsMoving) then gFunc.EquipSet(sets.Movement); end
    autoTick();
    Sub.tick(true);
end
profile.HandleEngaged = function()
    gFunc.EquipSet(sets.TP);
    autoTick();
    Sub.tick(true);
end
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
    local sub = args[1]:lower();

    local function tri(flag, w)
        if (w=='on') then return true; end
        if (w=='off') then return false; end
        return not flag;
    end
    local w2 = args[2] and args[2]:lower() or nil;

    if (sub=='auto') then
        Pet.autoReward = not Pet.autoReward;
        Pet.autoCall   = Pet.autoReward;
        Sub.echo('[BST] Auto (Reward + Call): ' .. (Pet.autoReward and 'ON' or 'OFF'));
        return;
    end
    if (sub=='reward') then
        Pet.autoReward = tri(Pet.autoReward, w2);
        Sub.echo('[BST] Auto-Reward: ' .. (Pet.autoReward and 'ON' or 'OFF')
              .. ' (fires below ' .. Pet.rewardHppThreshold .. '%)');
        return;
    end
    if (sub=='call') then
        Pet.autoCall = tri(Pet.autoCall, w2);
        Sub.echo('[BST] Auto-Call Beast: ' .. (Pet.autoCall and 'ON' or 'OFF'));
        return;
    end
    if (sub=='threshold' and args[2]) then
        local n = tonumber(args[2]);
        if (n and n>0 and n<=100) then
            Pet.rewardHppThreshold = n;
            Sub.echo('[BST] Reward threshold set to ' .. n .. '%');
        end
        return;
    end
    if (sub=='hud') then
        local on = Pet.toggleHUD(w2=='on' and true or w2=='off' and false or nil);
        Sub.echo('[BST] Pet HUD: ' .. (on and 'ON' or 'OFF'));
        return;
    end
    if (sub=='pet' or sub=='config') then
        for _, line in ipairs(Pet.snapshot()) do Sub.echo('[BST] ' .. line); end
        return;
    end
    if (sub=='debug') then Sub.debug(); return; end

    Sub.echo('[BST] Unknown: ' .. sub
          .. '  (auto|reward|call|threshold|hud|pet|debug)');
end
return profile;
