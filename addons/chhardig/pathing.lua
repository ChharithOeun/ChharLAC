--[[
    chhardig/pathing.lua -- waypoint storage, playback, and keyboard-emulated
    movement for Ashita v4.

    Design notes:
      * We never inject movement packets (0x015).  Server-side anti-cheat is
        most sensitive to packet forgery and the client's own movement
        validation drops/snaps-back forged positions.  Instead we drive the
        keyboard the same way the game expects a human to: Windows VK events
        via Ashita's ffi binding.
      * Keyboard events go to the FOREGROUND window.  If the user tabs out,
        movement stops.  We detect this via a position-delta watchdog and
        bail if we don't move after pressing W for 2s.
      * Waypoints are {x, y, z, name} tuples saved per zone in
        config/addons/chhardig/paths_<playerId>.lua.  The user records them
        with /chd mark <name> while standing where they want the point.
      * A "route" is an ordered list of waypoint names.  Default route is
        all waypoints from the save file in the current zone, played in
        reverse order (dig spot -> safe halfway -> zone line).

    Public API:
      path.record_wp(name)                       -- save current pos as waypoint
      path.list_wps()                            -- list for this zone
      path.remove_wp(name)
      path.walk_to(x, y, z, done_cb)             -- step toward one point
      path.walk_route(wp_names, done_cb)         -- step through many
      path.stop()                                -- cancel current walk
      path.active()                              -- true if currently walking
      path.distance(x1,y1, x2,y2)                -- euclidean
      path.self_pos()                            -- returns x, y, z
      path.current_zone()
]]--

local ffi    = require('ffi');

-- Windows VK codes for the game's default move keys.
local VK_W = 0x57;
local VK_A = 0x41;
local VK_S = 0x53;
local VK_D = 0x44;

-- Minimal Windows input API binding.  user32.dll is already in-process.
pcall(function()
    ffi.cdef[[
        typedef unsigned int  UINT;
        typedef unsigned long DWORD;
        typedef void*         HWND;
        UINT MapVirtualKeyA(UINT uCode, UINT uMapType);
        HWND GetForegroundWindow();
        void keybd_event(unsigned char bVk, unsigned char bScan, DWORD dwFlags, unsigned long dwExtraInfo);
    ]];
end);
local KEYEVENTF_KEYUP   = 0x0002;
local KEYEVENTF_SCANCODE= 0x0008;

local function send_key(vk, down)
    local scan = ffi.C.MapVirtualKeyA(vk, 0);  -- MAPVK_VK_TO_VSC
    local flags = KEYEVENTF_SCANCODE;
    if (not down) then flags = flags + KEYEVENTF_KEYUP; end
    ffi.C.keybd_event(vk, scan, flags, 0);
end

local M = {};

local state = {
    walking      = false,
    held         = {},         -- vk -> true
    goal         = nil,        -- {x,y,z}
    route        = nil,        -- list of {x,y,z,name}
    route_idx    = 1,
    last_pos     = {x=0,y=0,z=0},
    last_moved   = 0,
    stuck_since  = 0,
    on_done      = nil,
    waypoints    = {},         -- zone_id -> { name -> {x,y,z} }
    saved_at     = nil,        -- path to the save file
};

-- ---------------------------------------------------------------------------
-- Position + zone helpers
-- ---------------------------------------------------------------------------
function M.self_pos()
    local okE, ent = pcall(function()
        return AshitaCore:GetMemoryManager():GetEntity();
    end);
    local okP, party = pcall(function()
        return AshitaCore:GetMemoryManager():GetParty();
    end);
    if (not okE or not ent or not okP or not party) then return 0,0,0; end
    local idx = party:GetMemberTargetIndex(0);
    if (not idx or idx == 0) then return 0,0,0; end
    return ent:GetLocalPositionX(idx) or 0,
           ent:GetLocalPositionY(idx) or 0,
           ent:GetLocalPositionZ(idx) or 0;
end

function M.current_zone()
    local okP, party = pcall(function()
        return AshitaCore:GetMemoryManager():GetParty();
    end);
    if (not okP or not party) then return 0; end
    return party:GetMemberZone(0) or 0;
end

function M.distance(x1, y1, x2, y2)
    local dx, dy = x2-x1, y2-y1;
    return math.sqrt(dx*dx + dy*dy);
end

-- ---------------------------------------------------------------------------
-- Waypoint persistence
-- ---------------------------------------------------------------------------
local function _ensure_save_path()
    if (state.saved_at) then return state.saved_at; end
    local okP, party = pcall(function()
        return AshitaCore:GetMemoryManager():GetParty();
    end);
    local pid = (okP and party) and party:GetMemberServerId(0) or 0;
    local base = AshitaCore:GetInstallPath()
                 .. 'config/addons/chhardig/';
    local okD = pcall(ashita.fs.create_directory, base);
    state.saved_at = base .. ('paths_%d.lua'):format(pid);
    return state.saved_at;
end

function M.save()
    local path = _ensure_save_path();
    local f = io.open(path, 'w');
    if (not f) then return false, 'cannot open ' .. path; end
    f:write('-- chhardig waypoints -- do not edit by hand\n');
    f:write('return {\n');
    for zid, bucket in pairs(state.waypoints) do
        f:write(string.format('  [%d] = {\n', zid));
        for name, pos in pairs(bucket) do
            f:write(string.format("    [%q] = { x=%.3f, y=%.3f, z=%.3f },\n",
                name, pos.x, pos.y, pos.z));
        end
        f:write('  },\n');
    end
    f:write('};\n');
    f:close();
    return true;
end

function M.load()
    local path = _ensure_save_path();
    local f = io.open(path, 'r');
    if (not f) then return; end
    f:close();
    local ok, data = pcall(dofile, path);
    if (ok and type(data) == 'table') then state.waypoints = data; end
end

function M.record_wp(name)
    if (not name or name == '') then return false, 'need a name'; end
    local zid = M.current_zone();
    if (zid == 0) then return false, 'zone unknown'; end
    local x, y, z = M.self_pos();
    state.waypoints[zid] = state.waypoints[zid] or {};
    state.waypoints[zid][name] = { x=x, y=y, z=z };
    return M.save();
end

function M.remove_wp(name)
    local zid = M.current_zone();
    if (state.waypoints[zid]) then
        state.waypoints[zid][name] = nil;
        M.save();
    end
end

function M.list_wps()
    local zid = M.current_zone();
    local bucket = state.waypoints[zid] or {};
    local out = {};
    for name, pos in pairs(bucket) do
        out[#out+1] = { name=name, x=pos.x, y=pos.y, z=pos.z };
    end
    table.sort(out, function(a,b) return a.name < b.name; end);
    return out;
end

function M.wp(name)
    local zid = M.current_zone();
    return state.waypoints[zid] and state.waypoints[zid][name] or nil;
end

-- ---------------------------------------------------------------------------
-- Movement primitives
-- ---------------------------------------------------------------------------
local function hold(vk)
    if (not state.held[vk]) then
        send_key(vk, true);
        state.held[vk] = true;
    end
end
local function release(vk)
    if (state.held[vk]) then
        send_key(vk, false);
        state.held[vk] = nil;
    end
end
local function release_all()
    for vk in pairs(state.held) do release(vk); end
end

-- Pick the keys to press so the character moves toward (gx, gy).
-- The game uses WASD relative to CAMERA heading, which we can't read without
-- more plumbing.  Simpler heuristic: always use W (forward) and turn the
-- character to face the target by tapping /facetarget-style via chat.
-- For now we send W only and tap /lockon or /face if we have one, else just W.
local function face_and_step(gx, gy)
    local sx, sy = M.self_pos();
    -- Face target: the simplest primitive that works without reading the
    -- camera is to use the client's own "face" via /lookat ... which only
    -- works if we have the target id.  Lacking that, we tap A/D nudges to
    -- line up.  Really simple first pass: just hold W.  User's responsible
    -- for pointing the camera at the goal before enabling auto-exit, OR
    -- recording waypoints along a path the character can walk forward
    -- through without turning.
    hold(VK_W);
    -- Record the move for the watchdog
    state.last_pos = { x=sx, y=sy };
end

function M.walk_to(x, y, z, done_cb)
    state.goal = { x=x, y=y, z=z };
    state.route = nil;
    state.walking = true;
    state.on_done = done_cb;
    state.last_moved = os.clock();
    state.last_pos = { x=select(1, M.self_pos()), y=select(2, M.self_pos()) };
end

function M.walk_route(wp_names, done_cb)
    local pts = {};
    for _, name in ipairs(wp_names) do
        local wp = M.wp(name);
        if (wp) then pts[#pts+1] = { x=wp.x, y=wp.y, z=wp.z, name=name }; end
    end
    if (#pts == 0) then
        if (done_cb) then done_cb(false, 'no waypoints resolved'); end
        return;
    end
    state.route = pts;
    state.route_idx = 1;
    state.goal = pts[1];
    state.walking = true;
    state.on_done = done_cb;
    state.last_moved = os.clock();
    state.last_pos = { x=select(1, M.self_pos()), y=select(2, M.self_pos()) };
end

function M.stop()
    release_all();
    state.walking = false;
    state.goal    = nil;
    state.route   = nil;
    if (state.on_done) then
        local cb = state.on_done; state.on_done = nil;
        cb(false, 'stopped');
    end
end

function M.active() return state.walking; end

-- Tick: call every frame.  Checks if we've arrived at `state.goal` or if
-- we're stuck (no position change in 2s while holding W).
local ARRIVE_RADIUS = 2.5;    -- yalms
local STUCK_SEC     = 2.0;
function M.tick()
    if (not state.walking or not state.goal) then return; end
    local sx, sy = M.self_pos();
    local gx, gy = state.goal.x, state.goal.y;
    local d = M.distance(sx, sy, gx, gy);

    -- Arrived at current goal?
    if (d <= ARRIVE_RADIUS) then
        release_all();
        if (state.route) then
            state.route_idx = state.route_idx + 1;
            if (state.route_idx <= #state.route) then
                state.goal = state.route[state.route_idx];
                state.last_moved = os.clock();
                face_and_step(state.goal.x, state.goal.y);
                return;
            end
        end
        -- Done
        state.walking = false;
        state.goal = nil;
        if (state.on_done) then
            local cb = state.on_done; state.on_done = nil;
            cb(true, 'arrived');
        end
        return;
    end

    -- Stuck watchdog: moved?
    local moved_dist = M.distance(sx, sy, state.last_pos.x, state.last_pos.y);
    if (moved_dist > 0.5) then
        state.last_moved = os.clock();
        state.last_pos = { x=sx, y=sy };
    elseif ((os.clock() - state.last_moved) > STUCK_SEC) then
        release_all();
        state.walking = false;
        if (state.on_done) then
            local cb = state.on_done; state.on_done = nil;
            cb(false, 'stuck (foreground? turned away? bump into geometry?)');
        end
        return;
    end

    -- Keep moving
    face_and_step(gx, gy);
end

-- Emergency stop: release every key we might hold.
function M.panic_release()
    release_all();
    state.walking = false;
end

return M;
