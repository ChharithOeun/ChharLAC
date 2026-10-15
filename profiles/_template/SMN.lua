-- Chharizard SMN - LAC profile (avatars, era)
local profile = {}; local sets = {}; profile.Sets = sets;
local Sub = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/subjob_features.lua');
local Avatar = dofile(AshitaCore:GetInstallPath() .. 'config/addons/luashitacast/_template/smn_avatar.lua');

sets.Idle = {
    Head="Nashira Turban", Neck="Uggalepih Pendant", Ear1="Loquac. Earring", Ear2="Novia Earring",
    Body="Yigit Gomlek", Hands="Yigit Gages", Ring1="Ether Ring", Ring2="Star Ring",
    Back="Summoner's Doublet", Waist="Sacro Cord", Legs="Nashira Seraweels", Feet="Herald's Gaiters",
    Main="Chatoyant Staff", Sub="Vivid Strap", Ammo="Clarus Stone",
};
sets.Movement = { Feet="Herald's Gaiters" };
sets.Resting = { Head="Nashira Turban", Body="Dalmatica", Waist="Austerity Belt" };
sets.TP = sets.Idle;

-- Pet perpetuation reduction
sets.Perp = {
    Head="Summoner's Horn", Body="Summoner's Doublet", Hands="Summoner's Bracers", Legs="Summoner's Spats", Feet="Summoner's Pigaches",
    Ring1="Sattva Ring", Waist="Sagacity Belt",
};

sets.Precast = { FastCast = { Ear1="Loquac. Earring", Body="Yigit Gomlek" } };
sets.Midcast = {
    BloodPactRage = { Head="Summoner's Horn", Neck="Astral Aria", Body="Summoner's Doublet",
                      Hands="Summoner's Bracers", Legs="Summoner's Spats", Feet="Summoner's Pigaches" },
    BloodPactWard = { Head="Summoner's Horn", Body="Summoner's Doublet", Hands="Summoner's Bracers" },
    Cure          = { Body="Dalmatica" },
    Enhancing     = { Neck="Colossus's Torque" },
    Utsusemi      = { Head="Walahra Turban" },
};

sets.WS = { Default = { Head="Nashira Turban", Body="Yigit Gomlek" } };

sets.JA = {};
sets.JA["Astral Flow"] = { Feet="Summoner's Pigaches" };
sets.JA["Elemental Siphon"] = { Head="Summoner's Horn" };

profile.OnLoad = function()
    gSettings.AllowAddSet=true;
    Avatar.hook(); Avatar.hookHUD();
    Sub.echo("[Chharizard SMN] loaded (avatar HUD + BP tracker active).");
end
profile.OnUnload = function()
    Avatar.unhook();
    Sub.echo("[Chharizard SMN] unloaded.");
end

local lastAutoFire = 0;
local function autoTick()
    local now = os.time();
    if ((now - lastAutoFire) < 2) then return; end
    -- Auto-Release at low MP floor
    if (Avatar.autoRelease and Avatar.shouldRelease()
        and Avatar.recastReady('Release')) then
        AshitaCore:GetChatManager():QueueCommand(1, '/ja "Release" <me>');
        Sub.echo(string.format('[SMN] Auto-Release (MP %d%% < %d%%)',
            Avatar.playerMPP(), Avatar.releaseMppFloor));
        lastAutoFire = now;
        return;
    end
    -- Auto-Siphon (free MP) when ready and we have an avatar out
    if (Avatar.autoSiphon and Avatar.canSiphon()) then
        AshitaCore:GetChatManager():QueueCommand(1, '/ja "Elemental Siphon" <me>');
        Sub.echo('[SMN] Auto-Siphon');
        lastAutoFire = now;
    end
end
profile._autoTick = autoTick;

profile.HandleDefault = function()
    local pet = gData.GetPet();
    if (pet) then gFunc.EquipSet(sets.Perp);
    else gFunc.EquipSet(sets.Idle); end
    if (gData.GetPlayer().IsMoving) then gFunc.EquipSet(sets.Movement); end
    if (gData.GetPlayer().Status == 'Resting') then gFunc.EquipSet(sets.Resting); end
    autoTick();
    Sub.tick(true);
end
profile.HandleEngaged = function()
    gFunc.EquipSet(sets.TP);
    autoTick();
    Sub.tick(true);
end
profile.HandleWeaponskill = function() gFunc.EquipSet(sets.WS.Default); end
profile.HandleAbility = function()
    local ja = gData.GetAction().Name; if (sets.JA[ja]) then gFunc.EquipSet(sets.JA[ja]); end
end
profile.HandlePrecast = function() gFunc.EquipSet(sets.Precast.FastCast); end
profile.HandleMidcast = function()
    local sp = gData.GetAction();
    if (sp.Skill == 'BloodPactRage') then gFunc.EquipSet(sets.Midcast.BloodPactRage);
    elseif (sp.Skill == 'BloodPactWard') then gFunc.EquipSet(sets.Midcast.BloodPactWard);
    elseif (sp.Name:contains('Cure')) then gFunc.EquipSet(sets.Midcast.Cure);
    elseif (sp.Skill == 'Enhancing Magic') then gFunc.EquipSet(sets.Midcast.Enhancing);
    elseif (sp.Name:contains('Utsusemi')) then gFunc.EquipSet(sets.Midcast.Utsusemi); end
end
profile.HandleCommand = function(args)
    if (#args<1) then return; end
    if (Sub.handleCommand(args)) then return; end
    local sub = args[1]:lower();
    local function tri(f, w)
        if (w=='on') then return true; end
        if (w=='off') then return false; end
        return not f;
    end
    local w2 = args[2] and args[2]:lower() or nil;

    if (sub=='auto') then
        Avatar.autoRelease = not Avatar.autoRelease;
        Avatar.autoSiphon  = Avatar.autoRelease;
        Sub.echo('[SMN] Auto (Release + Siphon): '
              .. (Avatar.autoRelease and 'ON' or 'OFF'));
        return;
    end
    if (sub=='release') then
        Avatar.autoRelease = tri(Avatar.autoRelease, w2);
        Sub.echo('[SMN] Auto-Release: ' .. (Avatar.autoRelease and 'ON' or 'OFF')
              .. ' (fires below ' .. Avatar.releaseMppFloor .. '% MP)');
        return;
    end
    if (sub=='siphon') then
        Avatar.autoSiphon = tri(Avatar.autoSiphon, w2);
        Sub.echo('[SMN] Auto-Siphon: ' .. (Avatar.autoSiphon and 'ON' or 'OFF'));
        return;
    end
    if (sub=='floor' and args[2]) then
        local n = tonumber(args[2]);
        if (n and n>0 and n<=100) then
            Avatar.releaseMppFloor = n;
            Sub.echo('[SMN] Release floor set to ' .. n .. '% MP');
        end
        return;
    end
    if (sub=='hud') then
        local on = Avatar.toggleHUD(w2=='on' and true or w2=='off' and false or nil);
        Sub.echo('[SMN] Avatar HUD: ' .. (on and 'ON' or 'OFF'));
        return;
    end
    if (sub=='avatar' or sub=='config') then
        for _, line in ipairs(Avatar.snapshot()) do Sub.echo('[SMN] ' .. line); end
        return;
    end
    if (sub=='debug') then Sub.debug(); return; end

    Sub.echo('[SMN] Unknown: ' .. sub
          .. '  (auto|release|siphon|floor|hud|avatar|debug)');
end
return profile;
