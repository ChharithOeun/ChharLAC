--[[
    Metacast - sentinel.lua

    Staff / proxy-check detection, built from:
      * atom0s' XiPackets, GP_SERV_CHAR_PC (0x00D) - the retail client's PC
        update packet. HorizonXI runs the retail client, so these are the bits
        the client itself uses to draw GM icons:
          SendFlg  @0x0A  bit 0x04 "General" -> Flags1/Flags2 are valid
          Speed    @0x1C  movement speed (normal ~40)
          Flags1   @0x20  bit 1 HideFlag (fully hidden, untargetable)
                          bit 12 AnonymousFlag, bit 29 InvisFlag (the spell)
                          bits 24-26 GmLevel (client uses >= 3; 4 = red GM icon)
          Flags2   @0x24  bit 28 GmIconFlag ("a GM hiding their icon")
      * LandSandBoat's GM commands (HorizonXI's server): !togglegm sets the
        visible GM level (real level + 3, so the icon shows), !hide makes the GM
        invisible - the server stops sending them to other clients at all, so a
        hidden GM can NOT be seen by any addon. !goto warps next to a player,
        !speed changes movement speed.
      * LandSandBoat's own source (4.35), for what a client can actually see:
          - !afkcheck: chat type 12 "GM prompt" from "_CUSTOM_MENU", a 3-choice
            sum menu; wrong / no answer in 30s sets HP to 0
          - !wallhack: HackMove (Flags1 bit 27) + GroundFlag (Flags0 bit 15)
          - HideFlag is m_isPCHidden = a normal player in a cutscene (NOT staff)
          - !speed and mounts are clamped to 80 (map.SPEED_LIMIT)
          - a hidden GM's /say and emotes still reach you within 50y, but they
            are never spawned; players spawn within 45y
          - un-hiding is broadcast to the whole zone, not just nearby players
          - !bring / !send / !jail zone their target; !jail -> zone 131
      * What fishing-bot users report staff doing: rotating or moving the
        character, /tell, /say or emotes at the player, then watching for a
        reaction.

    Two outputs:
      gm_signs(decoded 0x00D) -> reasons a PC is flagged as staff (hard stop)
      suspicion points per player, 15-minute window (proxy-checker stop at 3):
        probe visit (in and out, well inside range) ... +1
        examines you (/check) ......................... +1
        targets you ................................... +1 (once per visit)
        appears close (warp / !goto / zone-in) ........ +1
        abnormal movement speed ....................... +2 (once per visit)
]]

local M = {}

M.WINDOW   = 900      -- seconds a suspicion point counts
M.NEED     = 3        -- points that trip the proxy-checker stop
M.points   = {}       -- name -> { {t=, pts=, why=}, ... }
M.flags    = {}       -- name -> last decoded flags string (for change logging)

local function u8(d, off)  return string.byte(d, off + 1) or 0 end
local function u16(d, off) return u8(d, off) + u8(d, off + 1) * 256 end
local function u32(d, off) return u16(d, off) + u16(d, off + 2) * 65536 end
local function bit_of(v, n) return math.floor(v / 2 ^ n) % 2 == 1 end
local function bits(v, lo, n) return math.floor(v / 2 ^ lo) % (2 ^ n) end

-- Decode the parts of a 0x00D we care about; nil if the General block isn't
-- in this packet (position-only updates don't carry the flags).
function M.decode_00D(data, size)
    if type(data) ~= 'string' then return nil end
    size = tonumber(size) or #data
    if size < 0x28 or #data < 0x28 then return nil end
    local send = u8(data, 0x0A)
    local out = { idx = u16(data, 0x08), send = send }
    if send % 8 < 4 then return out end            -- bit 0x04 not set: no flags in this one
    local f0, f1, f2 = u32(data, 0x18), u32(data, 0x20), u32(data, 0x24)
    out.general  = true
    out.speed    = u8(data, 0x1C)
    out.status   = u8(data, 0x1F)                 -- server status: 5 chocobo, 85 mount, 4 event
    out.ground   = bit_of(f0, 15)                 -- GroundFlag  (LSB: set only by !wallhack)
    out.hackmove = bit_of(f1, 27)                 -- HackMove    (LSB: set only by !wallhack)
    out.hide     = bit_of(f1, 1)
    out.anon     = bit_of(f1, 12)
    out.invis    = bit_of(f1, 29)
    out.gm       = bits(f1, 24, 3)
    out.gm_icon_hidden = bit_of(f2, 28)
    out.f0, out.f1, out.f2 = f0, f1, f2
    -- name, when the packet carries it (SendFlg bit 0x08 / full update)
    if send % 2 == 1 and #data >= 0x18 then         -- bit 0x01: position
        local function f32(o)
            local b1, b2, b3, b4 = data:byte(o + 1, o + 4)
            local sign = (b4 >= 128) and -1 or 1
            local ex = (b4 % 128) * 2 + math.floor(b3 / 128)
            local mant = (b3 % 128) * 65536 + b2 * 256 + b1
            if ex == 0 then return 0 end
            return sign * (1 + mant / 8388608) * 2 ^ (ex - 127)
        end
        out.px, out.p2, out.p3 = f32(0x0C), f32(0x10), f32(0x14)
    end
    if size >= 0x5A + 1 and #data >= 0x5A + 1 then
        local nm = data:sub(0x5A + 1, math.min(#data, 0x5A + 16)):gsub('%z.*$', '')
        if nm:match('^%a[%a]+$') then out.name = nm end
    end
    return out
end

-- Staff flags in a decoded 0x00D. Returns a list of reasons (empty = none).
-- Checked against LandSandBoat's own code (src/map/packets/char_update.cpp):
--   GmLevel   = visibleGmLevel (!togglegm: real level + 3, so 4-7)
--   HackMove + GroundFlag = wallhackEnabled (!wallhack, GM-only: walk through walls)
--   HideFlag  = m_isPCHidden - a NORMAL player hidden during a cutscene, NOT staff.
--               (4.34 and earlier stopped for it: a player watching a cutscene
--               near you looked like a GM.) Logged, not a GM sign.
--   GmIconFlag is hard-coded off on LSB; kept for retail-style servers.
function M.gm_signs(d)
    local r = {}
    if not d or not d.general then return r end
    if d.gm >= 3 then r[#r + 1] = string.format('GM icon (level %d)', d.gm) end
    if d.gm_icon_hidden then r[#r + 1] = 'GM hiding their icon' end
    if d.hackmove or d.ground then r[#r + 1] = 'walking through walls (!wallhack)' end
    return r
end

-- Movement speed in the 0x00D: 40 normal, gear / songs add some. LSB clamps
-- everything (GM !speed too) to map.SPEED_LIMIT = 80. Real HorizonXI data
-- (MetaSentry, Port Jeuno 2026-09-25, ~500 players): 17 ordinary players showed
-- 80 and 2 showed 70 (chocobos, Flee), with status 0 - so 80 can't tell a GM
-- from a chocobo rider. Only a value ABOVE the cap is impossible for a player.
M.MOUNTED = { [5] = true, [85] = true }
function M.odd_speed(d)
    if not d or not d.general then return nil end
    if (d.speed or 0) > 80 then return d.speed end
    return nil
end

-- HorizonXI's own custom NPCs that open menus with the same "GM prompt" packet
-- as a GM's !afkcheck (horizonffxi.wiki: Category:Horizon Changes/New Content):
-- outpost-warp goblins Burnstix (Port Jeuno), Sprinkstix (Upper Jeuno),
-- Twinkstix (Lower Jeuno); Shady Dealer (cosmetics); Franklin, Francine Tuft,
-- Francois (Hardcore Mode); Goblin Merrymaker (events).
M.MENU_NPCS = {
    ['burnstix'] = true, ['sprinkstix'] = true, ['twinkstix'] = true,
    ['shady dealer'] = true, ['franklin'] = true, ['francine tuft'] = true, ['francois'] = true,
    ['goblin merrymaker'] = true,
}

-- Zones only staff put you in (LSB: !jail -> 131, !gmhome -> 210).
M.GM_ZONES = { [131] = 'Mordion Gaol (GM jail)', [210] = 'GM Home' }

-- "Known staff" list typed in settings: "Name1, Name2 Name3" -> set.
function M.name_set(str)
    local set = {}
    for n in tostring(str or ''):gmatch('%a+') do set[n:lower()] = true end
    return set
end

function M.flag_string(d)
    if not d or not d.general then return nil end
    return string.format('gm=%d gmhide=%s wallhack=%s cutscene=%s anon=%s invis=%s speed=%d status=%d',
        d.gm, tostring(d.gm_icon_hidden), tostring(d.hackmove or d.ground), tostring(d.hide), tostring(d.anon),
        tostring(d.invis), d.speed or 0, d.status or 0)
end

-- Add suspicion points; returns the player's total inside the window.
function M.add(name, pts, why, now)
    now = now or os.clock()
    local list = M.points[name] or {}
    local keep, total = {}, 0
    for _, p in ipairs(list) do
        if now - p.t <= M.WINDOW then keep[#keep + 1] = p; total = total + p.pts end
    end
    keep[#keep + 1] = { t = now, pts = pts, why = why }
    total = total + pts
    M.points[name] = keep
    return total
end

function M.total(name, now)
    now = now or os.clock()
    local total = 0
    for _, p in ipairs(M.points[name] or {}) do
        if now - p.t <= M.WINDOW then total = total + p.pts end
    end
    return total
end

-- "probe x2, examined you, appeared close" for the warning line.
function M.reasons(name, now)
    now = now or os.clock()
    local count, order = {}, {}
    for _, p in ipairs(M.points[name] or {}) do
        if now - p.t <= M.WINDOW then
            if not count[p.why] then count[p.why] = 0; order[#order + 1] = p.why end
            count[p.why] = count[p.why] + 1
        end
    end
    local out = {}
    for _, w in ipairs(order) do out[#out + 1] = (count[w] > 1) and (w .. ' x' .. count[w]) or w end
    return table.concat(out, ', ')
end

function M.reset()
    M.points = {}
end

return M
