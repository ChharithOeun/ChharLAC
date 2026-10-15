-- ============================================================================
-- bst_pet.lua -- BST pet state + JA tracker + imgui HUD
--
-- Mirrors the pup_burden.lua pattern:
--   * Reads pet HP/TP/Status every tick
--   * Looks up BST JA recasts via Ashita's resource manager (so IDs stay
--     correct across era/retail without hardcoding)
--   * Parses chat text for pet events (jug used, pet KO, Reward applied)
--   * imgui HUD: pet status, Reward/Sic/Ready/Call Beast with countdowns
--   * canReward(), canCall(), canSic() helpers for the auto-decision tick
-- ============================================================================

local B = {};

B.visible = true;

-- Settings consumers can tweak from BST.lua -----------------------------
B.rewardHppThreshold = 70;      -- auto-Reward when pet HPP < this
B.autoReward = false;
B.autoCall   = false;           -- auto-recall jug pet if dead/dismissed

-- Resolved JA recast indices (filled at hook() time via name lookup).
-- Falling back to -1 if the ability doesn't exist (sub BST limited pool).
local JA = {
    ['Call Beast']  = -1,
    ['Reward']      = -1,
    ['Sic']         = -1,
    ['Ready']       = -1,     -- Ready is the jug-pet variant of Sic
    ['Familiar']    = -1,
    ['Charm']       = -1,
    ['Tame']        = -1,
    ['Feral Howl']  = -1,
    ['Killer Instinct'] = -1,
};

local function resolveRecasts()
    local rm = pcall(function() return AshitaCore:GetResourceManager() end)
          and AshitaCore:GetResourceManager() or nil;
    if (not rm) then return; end
    for name, _ in pairs(JA) do
        local ok, ab = pcall(rm.GetAbilityByName, rm, 1, name);
        if (ok and ab and ab.RecastTimerId) then
            JA[name] = ab.RecastTimerId;
        end
    end
end

-- Returns seconds remaining on a JA by name, or 0 if ready / unknown.
local function recastRemaining(name)
    local idx = JA[name];
    if (not idx or idx < 0) then return 0; end
    local ok, r = pcall(function() return AshitaCore:GetMemoryManager():GetRecast() end);
    if (not ok or not r) then return 0; end
    local ok2, t = pcall(r.GetAbilityTimer, r, idx);
    return (ok2 and t) or 0;
end

function B.recastReady(name)
    return recastRemaining(name) <= 0;
end

-- Pet info snapshot ------------------------------------------------------
function B.pet()
    local ok, p = pcall(function() return gData.GetPet() end);
    if (not ok or not p) then return nil; end
    return {
        Name   = p.Name   or '-',
        HPP    = p.HPP    or 0,
        TP     = p.TP     or 0,
        Status = p.Status or '?',
    };
end

-- Decision helpers for auto-ticks ---------------------------------------
function B.canReward()
    local pet = B.pet();
    if (not pet or pet.HPP <= 0) then return false; end
    if (pet.HPP >= 100) then return false; end         -- Reward refuses at full HP
    if (not B.recastReady('Reward')) then return false; end
    return true;
end

function B.canCall()
    if (not B.recastReady('Call Beast')) then return false; end
    local pet = B.pet();
    return (not pet) or pet.HPP <= 0;                    -- only call if no pet
end

function B.canReady()
    local pet = B.pet();
    if (not pet or pet.HPP <= 0) then return false; end
    return B.recastReady('Ready');
end

-- Chat-text parser -------------------------------------------------------
-- Useful signals:
--   "<Pet> gains the effect of Reward."    -> keep Reward on cooldown anyway
--   "<Pet> is slain."                       -> pet dead flag (for auto-call)
--   "You call forth an automaton" (jug)     -> brand-new pet
-- Mostly informational; the JA recast + pet struct already give us truth.
B.lastChat = '';
local function parseChatLine(text)
    if (not text or type(text) ~= 'string') then return; end
    local clean = text:gsub('[%z\1-\31\127]', '');
    if (clean:find("is slain") or clean:find("falls to the ground")) then
        B.lastChat = clean;
    elseif (clean:find("call forth") or clean:find("Reward")) then
        B.lastChat = clean;
    end
end

-- Register / unregister event hooks --------------------------------------
local registered = false;
function B.hook()
    if (registered) then return; end
    resolveRecasts();
    ashita.events.register('text_in', 'chhar_bst_pet_txt', function(e)
        pcall(parseChatLine, e.message_modified or e.message);
    end);
    registered = true;
end

function B.unhook()
    if (not registered) then return; end
    pcall(ashita.events.unregister, 'text_in',     'chhar_bst_pet_txt');
    pcall(ashita.events.unregister, 'd3d_present', 'chhar_bst_pet_hud');
    registered = false;
end

-- imgui HUD --------------------------------------------------------------
local imgui_ok, imgui = pcall(require, 'imgui');

local HUD_ROWS = {
    { name='Call Beast',  short='Call'   },
    { name='Reward',      short='Reward' },
    { name='Ready',       short='Ready'  },
    { name='Sic',         short='Sic'    },
    { name='Familiar',    short='Famil.' },
    { name='Charm',       short='Charm'  },
};

local function fmtSecs(s)
    if (s <= 0) then return 'READY'; end
    if (s < 60) then return string.format('%ds', s); end
    return string.format('%dm %02ds', math.floor(s/60), s % 60);
end

local function renderHUD()
    if (not B.visible or not imgui_ok or not imgui) then return; end
    local pet = B.pet();
    if (not pet or pet.HPP <= 0) then return; end
    local ok = pcall(imgui.Begin, 'ChharBST');
    if (ok) then
        pcall(function()
            local pet = B.pet();
            if (pet and pet.HPP > 0) then
                imgui.Text(string.format('%s  HP %d%%  TP %d  [%s]',
                    pet.Name, pet.HPP, pet.TP, pet.Status));
            else
                imgui.Text('No pet');
            end
            imgui.Separator();
            -- Auto-state line
            imgui.Text(string.format('Auto: Reward %s   Call %s',
                B.autoReward and 'ON' or 'off',
                B.autoCall   and 'ON' or 'off'));
            imgui.Separator();
            for _, row in ipairs(HUD_ROWS) do
                local rem = recastRemaining(row.name);
                local line = string.format('%-8s %s', row.short, fmtSecs(rem));
                local c;
                if (rem <= 0) then
                    c = { 0.60, 1.00, 0.60, 1.0 };  -- green: ready
                elseif (rem < 10) then
                    c = { 1.00, 1.00, 0.50, 1.0 };  -- yellow: about to be ready
                else
                    c = { 0.70, 0.70, 0.70, 1.0 };  -- gray: cooling
                end
                if (imgui.TextColored) then
                    pcall(imgui.TextColored, c, line);
                else
                    imgui.Text(line);
                end
            end
        end);
        pcall(imgui.End);
    end
end

function B.hookHUD()
    if (not imgui_ok) then return; end
    pcall(ashita.events.register, 'd3d_present', 'chhar_bst_pet_hud', renderHUD);
end

function B.toggleHUD(on)
    if (on == nil) then B.visible = not B.visible;
    else B.visible = on and true or false; end
    return B.visible;
end

-- Snapshot for /lac fwd pet command
function B.snapshot()
    local lines = {};
    local pet = B.pet();
    if (pet and pet.HPP > 0) then
        table.insert(lines, string.format('Pet: %s  HP %d%%  TP %d  [%s]',
            pet.Name, pet.HPP, pet.TP, pet.Status));
    else
        table.insert(lines, 'Pet: (none)');
    end
    table.insert(lines, string.format('Auto -> Reward=%s  Call=%s  (Reward threshold %d%%)',
        B.autoReward and 'ON' or 'off',
        B.autoCall   and 'ON' or 'off',
        B.rewardHppThreshold));
    for _, row in ipairs(HUD_ROWS) do
        table.insert(lines, string.format('   %-14s %s',
            row.name, fmtSecs(recastRemaining(row.name))));
    end
    return lines;
end

return B;
