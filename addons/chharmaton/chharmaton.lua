--[[
================================================================================
  ChharMaton v1.0 - visual elemental orbs for PUP maneuvers
  by Chharizard. Inspired by jonhouchens/ArcaneAutomata (MIT).

  Reads maneuver buffs 300-307 directly from Ashita's Player memory, then
  draws up to 3 colored orbs via imgui DrawList. Pure visual addon with no
  gameplay commands. ChharLAC's PUP.lua auto-loads/unloads it.
================================================================================
]]--

addon.name    = 'chharmaton';
addon.author  = 'Chharizard';
addon.version = '1.0.0';
addon.desc    = 'Visual orbs for PUP maneuvers';

require('common');

local imgui_ok, imgui = pcall(require, 'imgui');

-- Config (persisted later; defaults for now)
local cfg = {
    enabled    = true,
    x          = 400,
    y          = 350,
    orbSize    = 28,     -- bigger default
    spacing    = 72,
    alwaysShow = false,
};

local MAN_BUFF_FIRST = 300;
local MAN_BUFF_LAST  = 307;
local OVERLOAD_BUFF  = 299;

local ELEM_BY_ID = {
    [300] = 'fire',    [301] = 'ice',   [302] = 'wind',   [303] = 'earth',
    [304] = 'thunder', [305] = 'water', [306] = 'light',  [307] = 'dark',
};

local ELEM_COLOR_RGB = {
    fire    = { 1.00, 0.40, 0.20 },
    ice     = { 0.50, 0.80, 1.00 },
    wind    = { 0.60, 1.00, 0.60 },
    earth   = { 0.80, 0.65, 0.40 },
    thunder = { 1.00, 1.00, 0.40 },
    water   = { 0.40, 0.60, 1.00 },
    light   = { 1.00, 1.00, 0.90 },
    dark    = { 0.70, 0.40, 1.00 },
};

local ELEM_GLYPH = {
    fire='F', ice='I', wind='W', earth='E',
    thunder='T', water='A', light='L', dark='D',
};

-- Pack ImU32 color (ABGR order per imgui spec)
local function col32(r, g, b, a)
    a = a or 1.0;
    local R = math.floor((r or 0) * 255);
    local G = math.floor((g or 0) * 255);
    local B = math.floor((b or 0) * 255);
    local A = math.floor(a * 255);
    return A * 0x1000000 + B * 0x10000 + G * 0x100 + R;
end

-- Read active maneuvers (sorted newest-first by slot not available in Ashita;
-- we sort by element iteration order for stable display)
local function activeManeuvers()
    local out = {};
    local overloaded = false;
    local okP, player = pcall(function()
        return AshitaCore:GetMemoryManager():GetPlayer();
    end);
    if (not okP or not player) then return out, overloaded; end
    local get = player.GetBuff;
    if (not get) then return out, overloaded; end
    for i = 0, 31 do
        local ok, id = pcall(get, player, i);
        if (ok and id) then
            if (id == OVERLOAD_BUFF) then overloaded = true; end
            local elem = ELEM_BY_ID[id];
            if (elem) then table.insert(out, elem); end
        end
    end
    return out, overloaded;
end

-- Fail-open: if we can't check job, assume PUP and let the empty-maneuvers
-- check below hide the window naturally.
local function isPUPActive()
    local ok, player = pcall(function()
        return AshitaCore:GetMemoryManager():GetPlayer();
    end);
    if (not ok or not player) then return true; end
    local mok, mjob = pcall(player.GetMainJob, player);
    local sok, sjob = pcall(player.GetSubJob,  player);
    if (not mok and not sok) then return true; end  -- API missing: fail-open
    return (mok and mjob == 18) or (sok and sjob == 18);
end

-- imgui render pass -----------------------------------------------------
local function render()
    if (not cfg.enabled or not imgui_ok or not imgui) then return; end
    if (not isPUPActive()) then return; end

    local orbs, overloaded = activeManeuvers();
    if (cfg.alwaysShow and #orbs == 0) then
        orbs = { 'fire', 'ice', 'light' };   -- test triad
    end
    -- With no visible maneuvers AND no overload, there is nothing to draw.
    if (#orbs == 0 and not overloaded) then return; end

    -- Transparent, borderless, click-through window
    local flags = 0;
    pcall(function()
        -- Combine window flags; names vary across binding versions
        for _, f in ipairs({
            'WindowFlags_NoTitleBar',
            'WindowFlags_NoResize',
            'WindowFlags_NoMove',
            'WindowFlags_NoScrollbar',
            'WindowFlags_NoBackground',
            'WindowFlags_NoNav',
            'WindowFlags_NoInputs',
            'WindowFlags_NoBringToFrontOnFocus',
        }) do if (imgui[f]) then flags = flags + imgui[f]; end end
    end);

    pcall(imgui.SetNextWindowPos, { cfg.x, cfg.y });
    pcall(imgui.SetNextWindowSize, { cfg.spacing * 3 + 40, cfg.orbSize * 3 + 20 });
    -- Force transparent background + zero padding via style pushes. Some
    -- Ashita builds ignore WindowFlags_NoBackground alone.
    local pushes = 0;
    if (imgui.Col_WindowBg and imgui.PushStyleColor) then
        if (pcall(imgui.PushStyleColor, imgui.Col_WindowBg, { 0, 0, 0, 0 })) then
            pushes = pushes + 1;
        end
    end
    if (imgui.Col_Border and imgui.PushStyleColor) then
        if (pcall(imgui.PushStyleColor, imgui.Col_Border, { 0, 0, 0, 0 })) then
            pushes = pushes + 1;
        end
    end
    if (imgui.Col_TitleBg and imgui.PushStyleColor) then
        if (pcall(imgui.PushStyleColor, imgui.Col_TitleBg, { 0, 0, 0, 0 })) then
            pushes = pushes + 1;
        end
    end
    if (imgui.Col_TitleBgActive and imgui.PushStyleColor) then
        if (pcall(imgui.PushStyleColor, imgui.Col_TitleBgActive, { 0, 0, 0, 0 })) then
            pushes = pushes + 1;
        end
    end
    if (not pcall(imgui.Begin, 'chharmaton', true, flags)) then
        for i = 1, pushes do pcall(imgui.PopStyleColor); end
        return;
    end

    -- DrawList-based orbs. Use cfg.x/cfg.y directly as the anchor instead
    -- of calling GetWindowPos (which routes through sugar's math wrapper on
    -- some Ashita builds and errors on .x access).
    local okDL, dl = pcall(imgui.GetWindowDrawList);
    if (okDL and dl) then
        local baseX, baseY = cfg.x, cfg.y;
        local cy = baseY + cfg.orbSize + 6;
        local r  = cfg.orbSize;

        for i = 1, 3 do
            local elem = orbs[i];
            local cx = baseX + 20 + (i - 1) * cfg.spacing;
            local center = { cx, cy };
            if (elem) then
                local c = ELEM_COLOR_RGB[elem];
                pcall(dl.AddCircleFilled, dl, center, r + 2,
                      col32(c[1], c[2], c[3], 0.25), 32);
                pcall(dl.AddCircleFilled, dl, center, r,
                      col32(c[1], c[2], c[3], 0.95), 32);
                pcall(dl.AddCircle, dl, center, r,
                      col32(1.0, 1.0, 1.0, 0.6), 32, 1.5);
                pcall(dl.AddCircleFilled, dl,
                      { cx - r * 0.35, cy - r * 0.35 }, r * 0.25,
                      col32(1.0, 1.0, 1.0, 0.55), 16);
            else
                pcall(dl.AddCircle, dl, center, r,
                      col32(0.4, 0.4, 0.4, 0.5), 32, 1.0);
            end
            if (overloaded) then
                pcall(dl.AddCircle, dl, center, r + 4,
                      col32(1.0, 0.2, 0.2, 1.0), 32, 2.5);
            end
            -- Element glyph in center (dark text for contrast on light orbs,
            -- white text on dark orbs). Positioned ~center using heuristic
            -- offset since AddText anchors to top-left of text.
            if (elem) then
                local glyph = ELEM_GLYPH[elem] or '?';
                local c = ELEM_COLOR_RGB[elem];
                -- brightness proxy: avg of RGB
                local bright = (c[1] + c[2] + c[3]) / 3;
                local textCol = (bright > 0.65)
                    and col32(0.10, 0.08, 0.05, 1.0)
                    or  col32(1.00, 1.00, 1.00, 1.0);
                pcall(dl.AddText, dl, { cx - 4, cy - 7 }, textCol, glyph);
            end
        end
    else
        -- Fallback: colored text letters
        for i = 1, 3 do
            local e = orbs[i];
            if (e and imgui.TextColored) then
                local c = ELEM_COLOR_RGB[e];
                pcall(imgui.TextColored, { c[1], c[2], c[3], 1.0 }, '@');
            else
                pcall(imgui.Text, 'o');
            end
            if (i < 3) then pcall(imgui.SameLine); end
        end
    end

    pcall(imgui.End);
    for i = 1, pushes do pcall(imgui.PopStyleColor); end
end

-- Events ----------------------------------------------------------------
ashita.events.register('d3d_present', 'chharmaton_render', render);

ashita.events.register('load', 'chharmaton_load', function()
    print('[ChharMaton] v' .. addon.version .. ' loaded.');
end);

ashita.events.register('command', 'chharmaton_cmd', function(e)
    local parts = {};
    for w in e.command:gmatch('%S+') do parts[#parts+1] = w; end
    if (not parts[1] or parts[1]:lower() ~= '/chharmaton') then return; end
    e.blocked = true;
    local sub = (parts[2] or 'toggle'):lower();
    if (sub == 'on')     then cfg.enabled = true;
    elseif (sub == 'off') then cfg.enabled = false;
    elseif (sub == 'toggle') then cfg.enabled = not cfg.enabled;
    elseif (sub == 'pos' and parts[3] and parts[4]) then
        cfg.x = tonumber(parts[3]) or cfg.x;
        cfg.y = tonumber(parts[4]) or cfg.y;
    elseif (sub == 'size' and parts[3]) then
        cfg.orbSize = math.max(8, math.min(60, tonumber(parts[3]) or cfg.orbSize));
    elseif (sub == 'always') then
        cfg.alwaysShow = (parts[3] == 'on');
        print('[ChharMaton] alwaysShow=' .. tostring(cfg.alwaysShow));
    elseif (sub == 'test') then
        -- Fake 3 orbs so you can confirm the HUD is drawing + positioned.
        cfg.alwaysShow = true;
        print('[ChharMaton] Test mode on. "/chharmaton always off" to clear.');
    elseif (sub == 'debug') then
        local orbs, over = activeManeuvers();
        print(string.format('[ChharMaton] enabled=%s imgui=%s drawlist=%s',
            tostring(cfg.enabled), tostring(imgui_ok),
            tostring(imgui and imgui.GetWindowDrawList ~= nil)));
        print(string.format('[ChharMaton] isPUP=%s maneuvers=%d overload=%s',
            tostring(isPUPActive()), #orbs, tostring(over)));
        for i, e in ipairs(orbs) do print('  ' .. i .. ': ' .. e); end
        return;
    else
        print('[ChharMaton] on|off|toggle | pos <x> <y> | size <n> | always on|off | test | debug');
        return;
    end
    print('[ChharMaton] enabled=' .. tostring(cfg.enabled)
       .. ' pos=' .. cfg.x .. ',' .. cfg.y
       .. ' size=' .. cfg.orbSize);
end);
