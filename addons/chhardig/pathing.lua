--[[
    chhardig/pathing.lua -- waypoint storage only.

    H3 fix (audit 2026-11-17):
      The previous version drove the character via keybd_event +
      KEYEVENTF_SCANCODE, whose events carry LLKHF_INJECTED -- the single
      most obvious synthetic-input fingerprint any client AC can see.
      That routine fired right when staff was already looking (the exit
      sequence runs AFTER a suspicion trigger), making it the addon's
      biggest detection surface.

      This module no longer injects any input.  Waypoints remain so the
      user can mark dig spots for reference and see them on the Data /
      Waypoints tab in the UI, but nothing scripted drives movement.

    Public API (reduced):
      path.record_wp(name)        -- save current pos as a waypoint
      path.list_wps()             -- list waypoints in current zone
      path.remove_wp(name)
      path.wp(name)
      path.distance(x1,y1,x2,y2)  -- 2D euclidean
      path.self_pos()             -- returns x, y, z
      path.current_zone()
      path.load(), path.save()

    The former walk_to / walk_route / tick / panic_release entry points
    are intentionally gone.  If anything calls them you'll see a loud
    error instead of silent synthetic input.
]]--

local M = {};

local state = {
    waypoints = {},         -- zone_id -> { name -> {x,y,z} }
    saved_at  = nil,        -- path to the save file
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
    pcall(ashita.fs.create_directory, base);
    state.saved_at = base .. ('paths_%d.lua'):format(pid);
    return state.saved_at;
end

function M.save()
    local p = _ensure_save_path();
    local f = io.open(p, 'w');
    if (not f) then return false, 'cannot open ' .. p; end
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
    local p = _ensure_save_path();
    local f = io.open(p, 'r');
    if (not f) then return; end
    f:close();
    local ok, data = pcall(dofile, p);
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

-- H3: deliberately no walk_to / walk_route / tick / panic_release.
-- These used to inject VK_W.  They do not come back without a detection-
-- surface review.
return M;
