-- ============================================================================
-- smn_avatar.lua -- SMN avatar state + Blood Pact tracker + imgui HUD
--
-- Pattern mirrors pup_burden.lua / bst_pet.lua:
--   * Avatar snapshot (name/HP/MP/TP)
--   * JA recasts resolved by name (works any era: ToAU, WoTG, retail)
--   * Blood Pact recast is the headline timer (60s shared base, ToAU/era)
--   * Chat text parser for avatar KO + release
--   * imgui HUD
--   * Decision helpers for auto-tick (auto-release, auto-reward via Favor)
-- ============================================================================

local A = {};

A.visible = true;

-- Behavior toggles ------------------------------------------------------
A.autoRelease   = false;     -- release avatar at low MP to save perpetuation
A.releaseMppFloor = 15;      -- release when player MP% drops below this
A.autoSiphon    = false;     -- auto-fire Elemental Siphon when ready + at pet

-- Resolved JA recast indices (filled on hook())
local JA = {
    ['Blood Pact: Rage'] = -1,
    ['Blood Pact: Ward'] = -1,
    ['Astral Flow']      = -1,
    ['Elemental Siphon'] = -1,
    ["Avatar's Favor"]   = -1,  -- WoTG; may not exist pre-WoTG servers
    ['Astral Conduit']   = -1,  -- retail only; safe fallback
    ['Mana Cede']        = -1,  -- retail only; safe fallback
    ['Release']          = -1,
    ['Assault']          = -1,
    ['Retreat']          = -1,
};

local function resolveRecasts()
    local ok, rm = pcall(function() return AshitaCore:GetResourceManager() end);
    if (not ok or not rm) then return; end
    for name, _ in pairs(JA) do
        local ok2, ab = pcall(rm.GetAbilityByName, rm, 1, name);
        if (ok2 and ab and ab.RecastTimerId) then
            JA[name] = ab.RecastTimerId;
        end
    end
end

local function recastRemaining(name)
    local idx = JA[name];
    if (not idx or idx < 0) then return 0; end
    local ok, r = pcall(function() return AshitaCore:GetMemoryManager():GetRecast() end);
    if (not ok or not r) then return 0; end
    local ok2, t = pcall(r.GetAbilityTimer, r, idx);
    return (ok2 and t) or 0;
end

function A.recastReady(name)
    return recastRemaining(name) <= 0;
end

-- Avatar snapshot --------------------------------------------------------
function A.avatar()
    local ok, p = pcall(function() return gData.GetPet() end);
    if (not ok or not p) then return nil; end
    return {
        Name   = p.Name   or '-',
        HPP    = p.HPP    or 0,
        MPP    = p.MPP    or 0,
        TP     = p.TP     or 0,
        Status = p.Status or '?',
    };
end

function A.playerMPP()
    local ok, p = pcall(function() return gData.GetPlayer() end);
    if (not ok or not p) then return 100; end
    return p.MPP or 100;
end

-- Decision helpers ------------------------------------------------------
function A.canSiphon()
    local pet = A.avatar();
    if (not pet or pet.HPP <= 0) then return false; end
    return A.recastReady('Elemental Siphon');
end

function A.shouldRelease()
    local pet = A.avatar();
    if (not pet or pet.HPP <= 0) then return false; end  -- nothing to release
    return A.playerMPP() < A.releaseMppFloor;
end

-- Chat parser (release, pop, KO) ----------------------------------------
A.lastChat = '';
local function parseChatLine(text)
    if (not text or type(text) ~= 'string') then return; end
    local clean = text:gsub('[%z\1-\31\127]', '');
    if (clean:find("returns to the astral plane")
     or clean:find("is called forth")
     or clean:find("[Bb]lood [Pp]act")
     or clean:find("Astral Flow")) then
        A.lastChat = clean;
    end
end

-- Register / unregister ---------------------------------------------------
local registered = false;
function A.hook()
    if (registered) then return; end
    resolveRecasts();
    ashita.events.register('text_in', 'chhar_smn_avatar_txt', function(e)
        pcall(parseChatLine, e.message_modified or e.message);
    end);
    registered = true;
end

function A.unhook()
    if (not registered) then return; end
    pcall(ashita.events.unregister, 'text_in',     'chhar_smn_avatar_txt');
    pcall(ashita.events.unregister, 'd3d_present', 'chhar_smn_avatar_hud');
    registered = false;
end

-- imgui HUD --------------------------------------------------------------
local imgui_ok, imgui = pcall(require, 'imgui');

local HUD_ROWS = {
    { name='Blood Pact: Rage', short='BP Rage' },
    { name='Blood Pact: Ward', short='BP Ward' },
    { name='Elemental Siphon', short='Siphon'  },
    { name='Astral Flow',      short='A.Flow'  },
    { name="Avatar's Favor",   short='Favor'   },
    { name='Release',          short='Release' },
    { name='Assault',          short='Assault' },
    { name='Retreat',          short='Retreat' },
};

local function fmtSecs(s)
    if (s <= 0) then return 'READY'; end
    if (s < 60) then return string.format('%ds', s); end
    return string.format('%dm %02ds', math.floor(s/60), s % 60);
end

local function renderHUD()
    if (not A.visible or not imgui_ok or not imgui) then return; end
    local pet = A.avatar();
    if (not pet or pet.HPP <= 0) then return; end
    local ok = pcall(imgui.Begin, 'ChharSMN');
    if (ok) then
        pcall(function()
            local pet = A.avatar();
            if (pet and pet.HPP > 0) then
                imgui.Text(string.format('%s  HP %d%%  MP %d%%  TP %d  [%s]',
                    pet.Name, pet.HPP, pet.MPP, pet.TP, pet.Status));
            else
                imgui.Text('No avatar out');
            end
            imgui.Text(string.format('You: MP %d%%   Release@%d%%',
                A.playerMPP(), A.releaseMppFloor));
            imgui.Separator();
            imgui.Text(string.format('Auto: Release %s   Siphon %s',
                A.autoRelease and 'ON' or 'off',
                A.autoSiphon  and 'ON' or 'off'));
            imgui.Separator();
            for _, row in ipairs(HUD_ROWS) do
                local rem = recastRemaining(row.name);
                local line = string.format('%-8s %s', row.short, fmtSecs(rem));
                local c;
                -- "unavailable" (not resolved) rows render dimmer
                if ((JA[row.name] or -1) < 0) then
                    c = { 0.40, 0.40, 0.40, 1.0 };
                    line = string.format('%-8s --', row.short);
                elseif (rem <= 0) then c = { 0.60, 1.00, 0.60, 1.0 };
                elseif (rem < 10) then c = { 1.00, 1.00, 0.50, 1.0 };
                else c = { 0.70, 0.70, 0.70, 1.0 };
                end
                if (imgui.TextColored) then pcall(imgui.TextColored, c, line);
                else imgui.Text(line); end
            end
        end);
        pcall(imgui.End);
    end
end

function A.hookHUD()
    if (not imgui_ok) then return; end
    pcall(ashita.events.register, 'd3d_present', 'chhar_smn_avatar_hud', renderHUD);
end

function A.toggleHUD(on)
    if (on == nil) then A.visible = not A.visible;
    else A.visible = on and true or false; end
    return A.visible;
end

function A.snapshot()
    local lines = {};
    local pet = A.avatar();
    if (pet and pet.HPP > 0) then
        table.insert(lines, string.format('Avatar: %s HP %d%% MP %d%% TP %d [%s]',
            pet.Name, pet.HPP, pet.MPP, pet.TP, pet.Status));
    else
        table.insert(lines, 'Avatar: (none)');
    end
    table.insert(lines, string.format('You: MP %d%%  Release-floor %d%%',
        A.playerMPP(), A.releaseMppFloor));
    table.insert(lines, string.format('Auto -> Release=%s  Siphon=%s',
        A.autoRelease and 'ON' or 'off',
        A.autoSiphon  and 'ON' or 'off'));
    for _, row in ipairs(HUD_ROWS) do
        if ((JA[row.name] or -1) >= 0) then
            table.insert(lines, string.format('   %-18s %s',
                row.name, fmtSecs(recastRemaining(row.name))));
        end
    end
    return lines;
end

return A;
