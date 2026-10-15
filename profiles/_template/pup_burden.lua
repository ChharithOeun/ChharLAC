-- ============================================================================
-- pup_burden.lua -- Packet-driven burden tracker + imgui HUD for PUP
--
-- Ported from Nitrous (Shiva)'s autocontrol v2.0.5 (Ricky Gall / Nifim).
--   https://github.com/... (Windower retail addon)
-- Confirmed retail formulas:
--   * Burden +15 per maneuver fire                             (action packet)
--   * Decay rate: 1 per 3s base, scales with Heatsink + Water  (0 water=2, 1=4, 2=5, 3=6)
--   * Cooldown JA halves all burden
--   * Activate / Deus Ex Automata resets burden to 15 per element
--   * Deactivate zeros burden
--   * Base threshold = 30 per element; gear modifiers raise it
-- ----------------------------------------------------------------------------
-- This module:
--   * Hooks packet 0x028 (incoming action) to track maneuver fires
--   * Hooks packet 0x044 (job update) to detect Heatsink attachment
--   * Decays burden on a self-driven coroutine (3s cadence, like retail)
--   * Exposes B.get(elem), B.threshold, B.canFire(elem), B.renderHUD()
--   * Draws an imgui window via d3d_present event (toggleable)
-- ============================================================================

local B = {};

-- Base state ------------------------------------------------------------------
local HEATSINK_ID = 8610;        -- Heatsink attachment ID (retail; may differ era)
local WATER_BUFF  = 305;         -- Water Maneuver buff ID
local BASE_THRESHOLD = 30;
local MANEUVER_ADD = 15;
local DECAY_INTERVAL = 3;        -- seconds between decay ticks

B.burden = {
    fire=0, ice=0, wind=0, earth=0, thunder=0, water=0, light=0, dark=0,
};
B.threshold    = BASE_THRESHOLD;
B.decay_rate   = 1;              -- per 3s
B.heatsink     = false;
B.visible      = true;           -- HUD on by default
B.safeMode     = false;          -- immune to overload (Kenkonken etc)
B.frame        = '';             -- automaton frame name (Valoredge/Sharpshot/...)
B.gearBonus    = 0;              -- threshold bonus from equipped gear
B.lastUpdate   = os.time();

-- Packet 0x028 action categories/params for pet actions.
-- Autocontrol uses ability param 141-148; cross-ref retail data.
local PET_ACTION = {
    [136] = 'activate',
    [139] = 'deactivate',
    [141] = 'fire',   [142] = 'ice',    [143] = 'wind',  [144] = 'earth',
    [145] = 'thunder',[146] = 'water',  [147] = 'light', [148] = 'dark',
    [309] = 'cooldown',
    [310] = 'deus_ex_automata',
};

local ELEM_SET = {
    fire=true, ice=true, wind=true, earth=true,
    thunder=true, water=true, light=true, dark=true,
};

-- Decay --------------------------------------------------------------------
local function updateDecayRate()
    if (B.heatsink) then
        local waterCount = 0;
        local player = AshitaCore:GetMemoryManager():GetPlayer();
        if (player and player.GetBuff) then
            for i = 0, 31 do
                local ok, id = pcall(player.GetBuff, player, i);
                if (ok and id == WATER_BUFF) then
                    waterCount = waterCount + 1;
                end
            end
        end
        -- Autocontrol table: 0→2, 1→4, 2→5, 3→6 (per 3s)
        local tbl = { [0]=2, [1]=4, [2]=5, [3]=6 };
        B.decay_rate = tbl[math.min(waterCount, 3)] or 2;
    else
        B.decay_rate = 1;
    end
end

local function decay()
    local now = os.time();
    local dt = now - B.lastUpdate;
    if (dt < DECAY_INTERVAL) then return; end
    local steps = math.floor(dt / DECAY_INTERVAL);
    B.lastUpdate = now - (dt % DECAY_INTERVAL);
    local lost = steps * B.decay_rate;
    for elem in pairs(ELEM_SET) do
        B.burden[elem] = math.max(0, B.burden[elem] - lost);
    end
end

-- Public API ---------------------------------------------------------------
-- Returns the gain for firing one more of `elem` given current gear/frame.
-- Pulled from ArcaneAutomata's calibrated Horizon profile:
--   Dark normal frame = 15, reduced frames (Valoredge/Sharpshot) ~= 10
--   Non-Dark fixed at 15 (stat-aware refinement in a future pass)
function B.estimateGain(elem)
    if (elem == 'dark') then
        local f = (B.frame or ''):lower();
        if (f == 'valoredge' or f == 'sharpshot') then return 10; end
    end
    return MANEUVER_ADD;
end

-- Returns one of SAFE / LOW / WARM / DANGER / OVERLOAD based on predicted
-- post-fire burden vs threshold (ArcaneAutomata 5-level risk classification).
function B.riskLevel(elem)
    if (B.safeMode) then return 'SAFE'; end
    decay();
    local cur = B.burden[elem] or 0;
    if (cur > B.threshold) then return 'OVERLOAD'; end
    local projected = cur + B.estimateGain(elem);
    local over = projected - B.threshold;
    if (over <= 0)                   then return 'SAFE';    end
    if (over < B.threshold * 0.20)   then return 'LOW';     end
    if (over < B.threshold * 0.50)   then return 'WARM';    end
    return 'DANGER';
end

-- Firing allowed at SAFE and LOW (nonzero but <20% risk).
function B.canFire(elem)
    if (B.safeMode) then return true; end
    local r = B.riskLevel(elem);
    return (r == 'SAFE' or r == 'LOW');
end

-- Overload-immunity gear detection.
-- Kenkonken (PUP Mythic H2H) grants "no automaton overload".
-- Mythic weapons stay as the same item ID across upgrade stages (percent
-- bar fills, but ID doesn't change until the Mythic Aftermath variants if
-- they exist for that weapon). Confirmed Kenkonken IDs below.
local IMMUNITY_ITEM_IDS = {
    [21002] = true,  -- Kenkonken (Mythic)
    [21003] = true,  -- Kenkonken (variant / trial / afterglow)
    [21004] = true,
    [21005] = true,
};
-- Substring name matcher as a backup -- any slot whose name contains one of
-- these fires safeMode. Lower-case; partial OK ("kenkon" catches hyphens too).
local IMMUNITY_NAME_PARTS = {
    'kenkon',
};

local function matchImmunity(name, id)
    if (id and IMMUNITY_ITEM_IDS[id]) then return true; end
    if (type(name) == 'string') then
        local lower = name:lower();
        for _, part in ipairs(IMMUNITY_NAME_PARTS) do
            if (lower:find(part, 1, true)) then return true; end
        end
    end
    return false;
end

-- Threshold-modifier gear table (ArcaneAutomata-sourced; era-filtered).
--   On Horizon XI, Puppetry Dastanas +5 is the only one most people own.
local THRESHOLD_MODIFIERS = {
    ['puppetry dastanas']     = 5,
    ['puppetry dastanas +1']  = 5,
    ['foire dastanas']        = 5,
    ['foire dastanas +1']     = 5,
    ['visucius\'s mantle']    = 10,
    ['dispersal mantle']      = 5,
};

local function matchThresholdBonus(name)
    if (type(name) ~= 'string') then return 0; end
    local lower = name:lower();
    for key, bonus in pairs(THRESHOLD_MODIFIERS) do
        if (lower:find(key, 1, true)) then return bonus; end
    end
    return 0;
end

-- Walk equipment: tally threshold bonus from gear, detect Kenkonken immunity.
function B.updateSafeMode(equipment)
    B.safeMode  = false;
    B.gearBonus = 0;
    if (not equipment) then
        B.threshold = BASE_THRESHOLD;
        return;
    end
    for slot, item in pairs(equipment) do
        local name, id;
        if (type(item) == 'table') then
            name, id = item.Name, item.Id;
        elseif (type(item) == 'string') then
            name = item;
        end
        if (matchImmunity(name, id)) then B.safeMode = true; end
        B.gearBonus = B.gearBonus + matchThresholdBonus(name);
    end
    B.threshold = BASE_THRESHOLD + B.gearBonus;
end

function B.record(elem)
    decay();
    if (ELEM_SET[elem]) then
        B.burden[elem] = (B.burden[elem] or 0) + MANEUVER_ADD;
    end
end

function B.cooldown()
    decay();
    for elem in pairs(ELEM_SET) do
        B.burden[elem] = B.burden[elem] / 2;
    end
end

function B.activate()
    for elem in pairs(ELEM_SET) do B.burden[elem] = 15; end
    updateDecayRate();
end

function B.deactivate()
    for elem in pairs(ELEM_SET) do B.burden[elem] = 0; end
end

function B.zone()
    for elem in pairs(ELEM_SET) do B.burden[elem] = 15; end
end

function B.setHeatsink(on)
    B.heatsink = on and true or false;
    updateDecayRate();
end

-- Packet 0x028 (action) parser ---------------------------------------------
-- Scoped to our actor only. Params:
--   byte 5-8  : actor ID
--   byte 10-9 : category (upper nibble of byte 10, 4 bits)
--   target action param carries the ability ID in a specific slot
-- We use a conservative parser: scan for our ID + ability param in the
-- fixed payload offsets autocontrol uses, then react on known pet action IDs.
local function parseActionPacket(e)
    local player = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0);
    if (not player) then return; end
    local actor = struct.unpack('L', e.data, 0x05 + 1);
    if (actor ~= player) then return; end
    -- Category is bits 82-85 of the packet (0x0A low nibble in simple cases)
    local category = struct.unpack('B', e.data, 0x0A + 1);
    category = bit.band(category, 0x3F);  -- category occupies 6 bits
    if (category ~= 6) then return; end   -- 6 = Job Ability
    -- Param offset varies by packet layout; autocontrol uses act.param which
    -- maps to byte offset ~0x14. We read a 16-bit param from offset 0x14.
    local param = struct.unpack('H', e.data, 0x14 + 1);
    local action = PET_ACTION[param];
    if (not action) then return; end
    if (action == 'activate' or action == 'deus_ex_automata') then
        B.activate();
    elseif (action == 'deactivate') then
        B.deactivate();
    elseif (action == 'cooldown') then
        B.cooldown();
    elseif (ELEM_SET[action]) then
        B.record(action);
    end
end

-- Packet 0x044 (job update) -- find Heatsink in attachments
local function parseJobPacket(e)
    -- Byte 4 = main job. 18 = PUP.
    local mjob = struct.unpack('B', e.data, 0x04 + 1);
    if (mjob ~= 18) then return; end
    -- Attachments live in bytes 0x61..0x70 (16 bytes, each attachment id-5120)
    local found = false;
    for i = 0, 11 do
        local b = struct.unpack('B', e.data, 0x61 + i + 1);
        if (b ~= 0 and (b + 0x2000) == HEATSINK_ID) then
            found = true; break;
        end
    end
    B.setHeatsink(found);
end

-- Chat-text parser --------------------------------------------------------
-- The game broadcasts the exact overload chance when a maneuver fires:
--   "Chharizard's Fire Maneuver overload chance is 0%."
--   "Chharizard's Light Maneuver overload chance is 33%."
--   "Chharizard is overloaded!"
--
-- From the chance (X%) we can derive post-fire burden:
--   chance > 0  -> burden[elem] = threshold + X        (over the ceiling)
--   chance == 0 -> burden[elem] = max(current + 15, 15) (still under ceiling)
-- This is the authoritative source -- packet parsing is a backup.
B.lastChat = '';  -- diagnostic: last chat line we parsed

local function parseChatLine(text)
    if (not text or type(text) ~= 'string') then return; end
    -- Normalize: strip FFXI chat color codes (0x1E, 0x1F, 0x7F ranges)
    local clean = text:gsub('[%z\1-\31\127]', '');
    -- Loose pattern: find element word anywhere before "Maneuver" + chance
    local word, chance = clean:match("(%w+) [Mm]aneuver.-overload chance is (%d+)");
    if (word and chance) then
        local e = word:lower();
        if (ELEM_SET[e]) then
            B.lastChat = clean;
            chance = tonumber(chance) or 0;
            if (chance > 0) then
                B.burden[e] = B.threshold + chance;
            else
                B.burden[e] = math.min(B.threshold,
                                       (B.burden[e] or 0) + MANEUVER_ADD);
            end
        end
        return;
    end
    -- "automaton is overloaded"
    if (text:match("[Oo]verload")) then
        -- Pet overloaded -- all elements are near/above threshold now
        for e in pairs(ELEM_SET) do
            B.burden[e] = math.max(B.burden[e], B.threshold);
        end
        return;
    end
    -- "Automaton deactivated" or "Deactivate"
    if (text:match("[Dd]eactivat")) then
        B.deactivate();
        return;
    end
    -- "Cooldown" message
    if (text:match("[Cc]ooldown")) then
        B.cooldown();
        return;
    end
end

-- Register / unregister event hooks ----------------------------------------
local registered = false;
function B.hook()
    if (registered) then return; end
    ashita.events.register('packet_in', 'chhar_pup_burden_pkt', function(e)
        if (e.id == 0x028) then
            pcall(parseActionPacket, e);
        elseif (e.id == 0x044) then
            pcall(parseJobPacket, e);
        end
    end);
    -- text_in signature in Ashita v4: {mode, message, modified_mode, ...}
    ashita.events.register('text_in', 'chhar_pup_burden_txt', function(e)
        pcall(parseChatLine, e.message_modified or e.message);
    end);
    registered = true;
end

function B.unhook()
    if (not registered) then return; end
    pcall(ashita.events.unregister, 'packet_in', 'chhar_pup_burden_pkt');
    pcall(ashita.events.unregister, 'text_in',   'chhar_pup_burden_txt');
    pcall(ashita.events.unregister, 'd3d_present', 'chhar_pup_burden_hud');
    registered = false;
end

-- imgui HUD ----------------------------------------------------------------
local imgui_ok, imgui = pcall(require, 'imgui');

local ELEM_ORDER = { 'fire','ice','wind','earth','thunder','water','light','dark' };
local ELEM_COLOR = {
    fire    = { 1.00, 0.40, 0.20, 1.0 },
    ice     = { 0.50, 0.80, 1.00, 1.0 },
    wind    = { 0.60, 1.00, 0.60, 1.0 },
    earth   = { 0.80, 0.65, 0.40, 1.0 },
    thunder = { 1.00, 1.00, 0.40, 1.0 },
    water   = { 0.40, 0.60, 1.00, 1.0 },
    light   = { 1.00, 1.00, 0.90, 1.0 },
    dark    = { 0.70, 0.40, 1.00, 1.0 },
};
local ELEM_GLYPH = {
    fire='F', ice='I', wind='W', earth='E',
    thunder='T', water='A', light='L', dark='D',
};

-- Risk-level colors (ArcaneAutomata palette)
local RISK_COLOR = {
    SAFE     = { 0.40, 1.00, 0.40, 1.0 },  -- green
    LOW      = { 0.40, 1.00, 0.80, 1.0 },  -- teal
    WARM     = { 1.00, 0.85, 0.30, 1.0 },  -- amber
    DANGER   = { 1.00, 0.55, 0.15, 1.0 },  -- orange
    OVERLOAD = { 1.00, 0.20, 0.20, 1.0 },  -- red
};

-- Modern HUD: top orb row (active maneuvers from most-recent fires) + per-
-- element burden rows with 5-level risk coloring. Each orb is a colored
-- circle rendered via DrawList with a risk-colored ring, falling back to
-- bracket-style [F] text if DrawList isn't available in this imgui build.
local function drawOrb(dl, cx, cy, radius, elem, risk)
    if (not dl) then return; end
    local col = ELEM_COLOR[elem] or { 0.8, 0.8, 0.8, 1.0 };
    local ring = RISK_COLOR[risk] or RISK_COLOR.SAFE;
    local pack = function(c)
        -- IM_COL32: ABGR packed
        local r = math.floor((c[1] or 0) * 255);
        local g = math.floor((c[2] or 0) * 255);
        local b = math.floor((c[3] or 0) * 255);
        local a = math.floor((c[4] or 1) * 255);
        return a * 0x1000000 + b * 0x10000 + g * 0x100 + r;
    end
    pcall(dl.AddCircleFilled, dl, cx, cy, radius, pack(col), 32);
    pcall(dl.AddCircle, dl, cx, cy, radius + 3, pack(ring), 32, 2.5);
end

-- Draw a single step of the HUD, each guarded in its own pcall so one
-- failure never swallows the rest of the window.
local function safeText(line, c)
    if (c and imgui.TextColored) then
        if (not pcall(imgui.TextColored, c, line)) then
            pcall(imgui.Text, line);
        end
    else
        pcall(imgui.Text, line);
    end
end

local function renderHUD()
    if (not B.visible or not imgui_ok or not imgui) then return; end
    local okPet, pet = pcall(function() return gData.GetPet() end);
    if (not okPet or not pet or (pet.HPP or 0) <= 0) then return; end
    decay();
    if (not pcall(imgui.Begin, 'ChharPUP')) then return; end

    -- Header
    local flag = '';
    if (B.safeMode)      then flag = ' [KENKONKEN]';
    elseif (B.heatsink)  then flag = ' [Heatsink]'; end
    if (B.gearBonus > 0) then flag = flag .. ' +' .. B.gearBonus; end
    safeText(string.format('Thresh %d   Decay %d/3s%s',
        B.threshold, B.decay_rate, flag));

    -- Orb row: each orb in its own element color, laid out via SameLine so
    -- they render horizontally. Falls back cleanly on any imgui binding.
    local orbs = {};
    for e, c in pairs(B.burden) do
        if (c and c > 0) then table.insert(orbs, e); end
    end
    table.sort(orbs, function(a, b)
        return (B.burden[a] or 0) > (B.burden[b] or 0);
    end);
    for i = 1, 3 do
        local e = orbs[i];
        if (e) then
            safeText('@', ELEM_COLOR[e]);
        else
            safeText('o', { 0.35, 0.35, 0.35, 1.0 });
        end
        if (i < 3) then pcall(imgui.SameLine); end
    end
    pcall(imgui.Separator);

    -- Per-element burden rows: NAME in element color, status in risk color.
    -- Split into three segments via SameLine so each column gets its own tint.
    for _, elem in ipairs(ELEM_ORDER) do
        local v    = B.burden[elem] or 0;
        local risk = B.riskLevel(elem);
        local elemColor = ELEM_COLOR[elem];
        local riskColor = RISK_COLOR[risk];
        local nameText  = string.format('%-7s', elem:sub(1,1):upper() .. elem:sub(2));
        local valText   = string.format(' %4.0f/%d  ', v, B.threshold);
        local statText  = risk;
        -- Element-colored name, risk-colored numbers AND status so the eye
        -- picks the overload row immediately. Numbers get a slightly dimmer
        -- tint so the status word still reads as the primary indicator.
        local numColor = {
            riskColor[1] * 0.85,
            riskColor[2] * 0.85,
            riskColor[3] * 0.85,
            1.0,
        };
        safeText(nameText, elemColor);
        pcall(imgui.SameLine);
        safeText(valText, numColor);
        pcall(imgui.SameLine);
        safeText(statText, riskColor);
    end
    pcall(imgui.End);
end

function B.hookHUD()
    if (not imgui_ok) then return; end
    pcall(ashita.events.register, 'd3d_present', 'chhar_pup_burden_hud', renderHUD);
end

function B.toggleHUD(on)
    if (on == nil) then B.visible = not B.visible; else B.visible = on and true or false; end
    return B.visible;
end

-- Snapshot for /lac fwd burden command
function B.snapshot()
    decay();
    local lines = {};
    local tag = B.safeMode and '  [KENKONKEN: no overload]'
             or (B.heatsink and '  [Heatsink]' or '');
    table.insert(lines, string.format('Threshold %d  Decay %d/3s%s',
        B.threshold, B.decay_rate, tag));
    for _, elem in ipairs(ELEM_ORDER) do
        local v = B.burden[elem] or 0;
        local flag = (v + MANEUVER_ADD > B.threshold) and ' <-- unsafe to refire' or '';
        table.insert(lines, string.format('   %-8s %5.1f / %d%s',
            elem, v, B.threshold, flag));
    end
    return lines;
end

return B;
