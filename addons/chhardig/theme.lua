--[[
    Metacast - ui/theme.lua

    Same look as MetaAH: cool slate-navy panels, one accent colour (Teal by
    default; Gold / Violet / Rose / Mint selectable), soft white borders,
    14/10/8 rounding, pill buttons. The palette and the button styles are
    lifted straight from MetaAH's lib/ui.lua so the two windows sit side by
    side as a matching set.

    build(cfg) is called once per frame (accent + opacity can change live);
    push()/pop() apply the window-wide colours and style vars.
]]

local imgui = require('imgui')

local M = {}

-- Accent choices - identical to MetaAH's M.THEMES.
M.THEMES = {
    { key = 'teal',   name = 'Teal',   c = { 0.27, 0.76, 0.80 } },
    { key = 'gold',   name = 'Gold',   c = { 0.93, 0.75, 0.36 } },
    { key = 'violet', name = 'Violet', c = { 0.63, 0.53, 0.98 } },
    { key = 'rose',   name = 'Rose',   c = { 0.96, 0.47, 0.62 } },
    { key = 'mint',   name = 'Mint',   c = { 0.45, 0.87, 0.60 } },
}

local T = {}      -- resolved colours for the current frame
M.T = T

local function rgba(c, a) return { c[1], c[2], c[3], a or 1 } end
local function mul(c, f, a) return { math.min(1, c[1] * f), math.min(1, c[2] * f), math.min(1, c[3] * f), a or 1 } end
M.rgba, M.mul = rgba, mul

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- cfg: { theme = 'teal', opacity = 0.95 }
function M.build(cfg)
    local acc = M.THEMES[1].c
    for _, t in ipairs(M.THEMES) do
        if t.key == cfg.theme then acc = t.c; break end
    end
    local op = clamp(tonumber(cfg.opacity) or 0.95, 0.3, 1.0)
    T.accent      = rgba(acc, 1)
    T.accent_hi   = mul(acc, 1.12, 1)
    T.accent_dim  = mul(acc, 0.55, 1)
    T.accent_soft = rgba(acc, 0.22)
    T.accent_mid  = rgba(acc, 0.38)
    T.win         = { 0.070, 0.078, 0.108, op }
    T.panel       = { 0.104, 0.114, 0.156, math.min(1, op + 0.03) }
    T.panel_hi    = { 0.130, 0.142, 0.190, 1 }
    T.frame       = { 0.150, 0.163, 0.218, 1 }
    T.frame_hi    = { 0.190, 0.205, 0.272, 1 }
    T.border      = { 1, 1, 1, 0.07 }
    T.text        = { 0.915, 0.935, 0.965, 1 }
    T.muted       = { 0.560, 0.600, 0.690, 1 }
    T.dark        = { 0.045, 0.052, 0.078, 1 }
    T.gold        = { 0.960, 0.790, 0.400, 1 }
    T.good        = { 0.440, 0.860, 0.580, 1 }
    T.bad         = { 0.940, 0.440, 0.470, 1 }
    T.warn        = { 0.960, 0.760, 0.360, 1 }
    T.violet      = { 0.630, 0.530, 0.980, 1 }
    T.clear       = { 0, 0, 0, 0 }
    return T
end

-- Window-wide style: same values, same order as MetaAH's draw().
local VARS = {
    { 'WindowRounding',    14 },
    { 'ChildRounding',     10 },
    { 'FrameRounding',     8 },
    { 'PopupRounding',     8 },
    { 'GrabRounding',      8 },
    { 'ScrollbarRounding', 10 },
    { 'TabRounding',       8 },
    { 'WindowPadding',     { 14, 12 } },
    { 'FramePadding',      { 10, 6 } },
    { 'ItemSpacing',       { 8, 7 } },
    { 'CellPadding',       { 8, 4 } },
    { 'WindowBorderSize',  1 },
    { 'ChildBorderSize',   1 },
    { 'ScrollbarSize',     30 },   -- finger-wide (touch screens, ROG Ally); scaled by push()
    { 'GrabMinSize',       28 },
}
M.WINDOW_PAD_Y = 12

local function colours()
    return {
        { 'WindowBg',             T.win },
        { 'ChildBg',              T.panel },
        { 'PopupBg',              T.panel_hi },
        { 'Border',               T.border },
        { 'BorderShadow',         T.clear },
        { 'Text',                 T.text },
        { 'TextDisabled',         T.muted },
        { 'FrameBg',              T.frame },
        { 'FrameBgHovered',       T.frame_hi },
        { 'FrameBgActive',        T.frame_hi },
        { 'Button',               T.frame },
        { 'ButtonHovered',        T.frame_hi },
        { 'ButtonActive',         T.accent_dim },
        { 'Header',               T.accent_mid },
        { 'HeaderHovered',        T.accent_soft },
        { 'HeaderActive',         T.accent_mid },
        { 'CheckMark',            T.accent },
        { 'SliderGrab',           T.accent },
        { 'SliderGrabActive',     T.accent_hi },
        { 'Separator',            T.border },
        { 'ScrollbarBg',          { 1, 1, 1, 0.04 } },
        { 'ScrollbarGrab',        T.accent_dim },
        { 'ScrollbarGrabHovered', T.accent_dim },
        { 'ScrollbarGrabActive',  T.accent },
        { 'PlotHistogram',        T.accent },
        { 'TableHeaderBg',        T.panel_hi },
        { 'TableBorderStrong',    T.border },
        { 'TableBorderLight',     T.border },
        { 'TableRowBg',           T.clear },
        { 'TableRowBgAlt',        { 1, 1, 1, 0.025 } },
        { 'TextSelectedBg',       T.accent_mid },
        { 'ResizeGrip',           T.clear },
        { 'ResizeGripHovered',    T.accent_soft },
        { 'ResizeGripActive',     T.accent_mid },
    }
end

-- Push everything; returns (ncolours, nvars) for pop(). Ids missing on this
-- ImGui build are skipped.
function M.push(scale)
    scale = tonumber(scale) or 1.0
    local nc, nv = 0, 0
    for _, e in ipairs(VARS) do
        local id = _G['ImGuiStyleVar_' .. e[1]]
        if type(id) == 'number' then
            local v = e[2]
            if (e[1] == 'ScrollbarSize' or e[1] == 'GrabMinSize') and type(v) == 'number' then v = v * scale end
            imgui.PushStyleVar(id, v); nv = nv + 1
        end
    end
    local seen = {}
    for _, e in ipairs(colours()) do
        local id = _G['ImGuiCol_' .. e[1]]
        if type(id) == 'number' and not seen[id] then
            seen[id] = true
            imgui.PushStyleColor(id, e[2]); nc = nc + 1
        end
    end
    return nc, nv
end

function M.pop(nc, nv)
    if nc and nc > 0 then imgui.PopStyleColor(nc) end
    if nv and nv > 0 then imgui.PopStyleVar(nv) end
end

-- MetaAH button styles:
--   'normal' | 'primary' | 'danger' | 'ghost' | 'tab' | 'tab_on' | 'warn'
function M.button(lbl, style, w, h)
    local base, hov, act, txt
    if style == 'primary' then
        base, hov, act, txt = T.accent, T.accent_hi, mul(T.accent, 0.85), T.dark
    elseif style == 'danger' then
        base, hov, act, txt = { 0.55, 0.22, 0.27, 1 }, { 0.72, 0.28, 0.34, 1 }, { 0.48, 0.18, 0.23, 1 }, T.text
    elseif style == 'go' then        -- green START
        base, hov, act, txt = { 0.20, 0.62, 0.36, 1 }, { 0.26, 0.74, 0.44, 1 }, { 0.16, 0.52, 0.30, 1 }, { 1, 1, 1, 1 }
    elseif style == 'warn' then
        base, hov, act, txt = mul(T.warn, 0.85), T.warn, mul(T.warn, 0.7), T.dark
    elseif style == 'ghost' then
        base, hov, act, txt = T.clear, T.frame_hi, T.frame, T.muted
    elseif style == 'tab' then
        base, hov, act, txt = T.clear, T.frame, T.frame_hi, T.muted
    elseif style == 'tab_on' then
        base, hov, act, txt = T.accent_mid, T.accent_mid, T.accent_mid, T.accent_hi
    else
        base, hov, act, txt = T.frame, T.frame_hi, T.accent_dim, T.text
    end
    imgui.PushStyleColor(ImGuiCol_Button, base)
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, hov)
    imgui.PushStyleColor(ImGuiCol_ButtonActive, act)
    imgui.PushStyleColor(ImGuiCol_Text, txt)
    local clicked = imgui.Button(lbl, { w or 0, h or 0 })
    imgui.PopStyleColor(4)
    return clicked
end

M.build({ theme = 'teal', opacity = 0.95 })   -- sane values before the first frame
return M
