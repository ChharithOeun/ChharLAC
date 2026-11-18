--[[
================================================================================
  ChharDig -- single-box chocobo dig helper for Phoenix XI (and compatible era).

  DESIGN GOALS (user-stated, 2026-10-27):
    1. Single-box only; no multibox orchestration.
    2. Max-paranoia safety floor:
         - hard-stop + /logout on any GM detection (gm_level >= 3,
           afkcheck prompt, wallhack flag).
         - hard-stop on any /tell from a staff name (user-maintained list).
         - suspicion threshold = 2 (stricter than Metacast's 3).
    3. Smart exit:
         - greens hit 0  -> walk the recorded exit route, dismount near zone.
         - riding time <= 5 min -> same.
         - user triggered /chd exit -> same.
    4. Phoenix-authoritative data:
         - digdata.lua is vendored verbatim from Skold177/PhoenixTracker
           which pulls from phoenixffxi/Phoenix server source.
    5. Human-shaped timing (realism.lua):
         - log-normal cooldowns, slow fatigue drift, injected distractions,
           break schedule 45-75 min.

  ARCHITECTURE
    digdata.lua   -- Phoenix pool / rank / xp tables (read-only reference)
    sentinel.lua  -- 0x00D decode + suspicion scoring (hard-stop triggers)
    realism.lua   -- log-normal timing (recast_gap, release_delay, etc)
    pathing.lua   -- waypoint storage + keyboard-emulated movement
    chhardig.lua  -- this file: orchestrator, chat parser, commands

  CREDITS
    * Skold177 / grimwaldr -- PhoenixTracker (digdata.lua source)
    * Metacast -- sentinel.lua and realism.lua
    * Phoenix server team -- the actual data behind digdata

  ToS NOTICE
    Running an automated digging loop is prohibited on most private servers.
    The max-paranoia safety floor reduces detectability; it does NOT make
    the risk zero.  Use at your own risk.
================================================================================
]]--

addon.name    = 'chhardig';
addon.author  = 'Chharizard';
addon.version = '1.0.0';
addon.desc    = 'Single-box chocobo dig helper with paranoia safety.';

require('common');
local chat = require('chat');

local digdata  = require('digdata');
local sentinel = require('sentinel');
local realism  = require('realism');
local path     = require('pathing');
local ui       = require('ui');

-- ============================================================================
-- Config (persisted in config/addons/chhardig/<charid>/settings.lua)
-- ============================================================================
local defaults = T{
    enabled           = false,         -- /chd on to activate
    paranoia          = 'max',         -- 'max' | 'metacast' | 'custom'
    suspicion_cap     = 2,             -- hard-stop threshold (max=2, metacast=3)
    auto_logout       = true,          -- /logout on any hard stop
    greens_floor      = 0,             -- walk exit when greens <= this
    ride_min_floor    = 5,             -- walk exit when minutes-of-chocobo <= this
    break_every_min   = { 45, 75 },    -- random uniform break interval
    break_dur_min     = { 7, 14 },     -- random uniform break duration
    cast_jitter_pct   = 0.20,          -- +/- jitter on recorded break durations
    distraction_rate  = 0.15,          -- 15% of recasts get a short pause
    long_lapse_rate   = 0.02,          -- 2% get a long lapse (40-150s)
    staff_names       = '',            -- "Name1, Name2, Name3" => instant stop
    exit_route        = '',            -- comma-sep waypoint names for exit path
    debug             = false,
};
local settings = defaults:copy(true);

-- ============================================================================
-- State
-- ============================================================================
local state = {
    running         = false,      -- actively dig-looping
    hard_stopped    = false,      -- irreversible until /chd clear
    hard_reason     = '',
    next_dig_at     = 0,          -- os.clock()
    next_break_at   = 0,
    on_break_until  = 0,
    last_dig_at     = 0,
    last_dig_pos    = {x=0, y=0, z=0},
    hours_since_break = 0,
    cycle_start     = os.clock(),
    greens          = 0,          -- most recent known count
    daily_finds     = 0,          -- today's finds (resets at JST midnight)
    daily_cap       = 100,
    wing_rank       = 0,          -- 0..10 craft rank
    session_digs    = 0,
    session_finds   = 0,
    session_too_close = 0,
    session_nothing = 0,
    exiting         = false,      -- walking the exit route right now
    mount_watch     = nil,        -- {start_clock, dur_sec} once we see chocobo
    next_break_at   = 0,
    on_break_until  = 0,
    recent          = {},         -- last 15 dig results for UI
    today           = {},         -- item name -> count
    ui_visible      = false,
    current_cooldown= 15,
    session_start   = os.clock(),
};

-- ============================================================================
-- Helpers
-- ============================================================================
local function echo(msg)
    print(chat.header('chhardig') .. chat.message(tostring(msg)));
end
local function warn(msg)
    print(chat.header('chhardig') .. chat.error(tostring(msg)));
end
local function dbg(msg)
    if (settings.debug) then
        print(chat.header('chhardig') .. chat.color1(6, '[dbg] ' .. tostring(msg)));
    end
end

local function queue(cmd)
    AshitaCore:GetChatManager():QueueCommand(1, cmd);
end

local function clock_min(secs) return math.floor(secs / 60); end

-- Count Gysahl Greens across inventory + wardrobes.
local function count_greens()
    local okI, inv = pcall(function()
        return AshitaCore:GetMemoryManager():GetInventory();
    end);
    if (not okI or not inv) then return 0; end
    local GREENS_ID = 4545;    -- Gysahl Green item id (Phoenix / retail)
    local total = 0;
    -- 0=inv, 1=safe1, 5=mog_satchel, 6=mog_sack, 8=wardrobe1..11=wardrobe4
    local containers = { 0, 8, 10, 11, 12 };
    for _, c in ipairs(containers) do
        local okC, size = pcall(inv.GetContainerSize, inv, c);
        if (okC and size and size > 0) then
            for i = 1, size do
                local okX, it = pcall(inv.GetContainerItem, inv, c, i);
                if (okX and it and it.Id == GREENS_ID) then
                    total = total + (it.Count or 0);
                end
            end
        end
    end
    return total;
end

-- Is the player mounted on a chocobo?  Status 5 = chocobo.
local function on_chocobo()
    local okP, party = pcall(function()
        return AshitaCore:GetMemoryManager():GetParty();
    end);
    if (not okP or not party) then return false; end
    local okE, ent = pcall(function()
        return AshitaCore:GetMemoryManager():GetEntity();
    end);
    if (not okE or not ent) then return false; end
    local idx = party:GetMemberTargetIndex(0);
    if (not idx or idx == 0) then return false; end
    local st = ent:GetStatus(idx);
    return st == 5;
end

-- Dig cooldown by rank (seconds).  Phoenix: 15/10/5/3/3/3/3/3/3/3/3.
local DIG_CD_BY_RANK = { [0]=15, [1]=10, [2]=5, [3]=3, [4]=3, [5]=3,
                        [6]=3, [7]=3, [8]=3, [9]=3, [10]=3 };
-- Post-zone cooldown: 60s Amateur, -5s per rank.
local POST_ZONE_BY_RANK = { [0]=60, [1]=55, [2]=50, [3]=45, [4]=40, [5]=35,
                           [6]=30, [7]=25, [8]=20, [9]=15, [10]=10 };
local function dig_cooldown()
    return (DIG_CD_BY_RANK[state.wing_rank] or 15);
end

-- Hard-stop: unrecoverable until the user explicitly /chd clear.
local function hard_stop(reason)
    state.hard_stopped = true;
    state.hard_reason  = reason;
    state.running      = false;
    state.exiting      = false;
    path.panic_release();
    warn('HARD STOP: ' .. reason);
    if (settings.auto_logout) then
        warn('auto-logout triggered');
        queue('/logout');
    end
end

-- ============================================================================
-- Staff / safety parsers
-- ============================================================================
local function parse_staff_set()
    return sentinel.name_set(settings.staff_names);
end
local staff_set = {};
local function rebuild_staff()
    staff_set = parse_staff_set();
end

-- Chat hook: watches for /tell from staff names and the afkcheck prompt.
local function on_text(e)
    if (state.hard_stopped) then return; end
    local msg = e.message or '';
    -- Any /tell from a known staff member
    local sender = msg:match('^(%a+)%s*>>');
    if (sender and staff_set[sender:lower()]) then
        hard_stop('staff /tell from ' .. sender);
        return;
    end
    -- AFK check prompt (HorizonXI custom menu)
    if (msg:find('_CUSTOM_MENU') or msg:find('GM prompt')) then
        hard_stop('AFK check prompt detected');
        return;
    end
    -- Successful dig
    local found_name = msg:match('digs up an? (.+)%.')
                    or msg:match('digs up an? ([^%.]+)');
    if (found_name) then
        state.session_digs  = state.session_digs + 1;
        state.session_finds = state.session_finds + 1;
        state.daily_finds   = state.daily_finds + 1;
        -- Recent history (ring-ish, keep last 15)
        table.insert(state.recent, 1, { item = found_name, ok = true, t = os.clock() });
        while (#state.recent > 15) do table.remove(state.recent); end
        -- Today tally
        state.today[found_name] = (state.today[found_name] or 0) + 1;
        if (state.daily_finds >= state.daily_cap) then
            echo(('daily cap reached (%d) -- entering exit sequence'):format(state.daily_cap));
            start_exit('daily cap');
        end
        return;
    end
    -- Failed dig
    if (msg:find('digs and digs') or msg:find('does not find anything')) then
        state.session_digs    = state.session_digs + 1;
        state.session_nothing = state.session_nothing + 1;
        table.insert(state.recent, 1, { item = nil, ok = false, t = os.clock() });
        while (#state.recent > 15) do table.remove(state.recent); end
        return;
    end
    -- Too close
    if (msg:find("doesn't want to dig") or msg:find('does not want to dig')) then
        state.session_too_close = state.session_too_close + 1;
        return;
    end
    -- Wing skill ping -- stable clerk tells you your exact rank.
    local lvl = msg:match('wing skill is (%d+)') or msg:match('wing skill: (%d+)');
    if (lvl) then
        local n = tonumber(lvl);
        state.wing_rank = math.min(10, math.floor(n / 10));
        echo(('wing skill = %d (rank %d)'):format(n, state.wing_rank));
    end
end

-- Packet 0x00D hook: GM detection + proximity suspicion.
local function on_packet(e)
    if (state.hard_stopped) then return; end
    if (e.id ~= 0x00D) then return; end
    local decoded = sentinel.decode_00D(e.data_raw, e.size);
    if (not decoded) then return; end
    local signs = sentinel.gm_signs(decoded);
    if (#signs > 0) then
        hard_stop('GM signs: ' .. table.concat(signs, ', '));
        return;
    end
    -- Suspicion scoring: /check, probe visits, close warps, etc.
    -- We just use sentinel's existing scoring API; detecting the specific
    -- trigger kinds requires more hooks that live in Metacast.lua -- for
    -- now we rely on the hard-stop signs above + staff name /tell.
end

-- ============================================================================
-- Main loop
-- ============================================================================
local function fatigue_hours()
    return state.hours_since_break;
end

local function schedule_next_dig()
    local base = dig_cooldown();
    -- realism.recast_gap returns a human-shaped gap >= 1.4s; floor it at
    -- the actual game cooldown so we never try to dig while on cd.
    local extra = realism.recast_gap(fatigue_hours());
    local gap = math.max(base, extra);
    -- Optional long lapse injection (above and beyond realism's own 1.5%).
    if (math.random() < settings.long_lapse_rate) then
        gap = gap + 40 + math.random() * 110;
        dbg('injected long lapse: +' .. math.floor(gap) .. 's');
    end
    state.next_dig_at = os.clock() + gap;
end

local function schedule_next_break()
    local lo, hi = settings.break_every_min[1], settings.break_every_min[2];
    local mins = lo + math.random() * (hi - lo);
    state.next_break_at = os.clock() + mins * 60;
    dbg(('next break in %d min'):format(math.floor(mins)));
end

local function start_break()
    local lo, hi = settings.break_dur_min[1], settings.break_dur_min[2];
    local mins = lo + math.random() * (hi - lo);
    mins = realism.jitter(mins, settings.cast_jitter_pct);
    state.on_break_until = os.clock() + mins * 60;
    state.hours_since_break = 0;
    schedule_next_break();
    echo(('taking a %d-min break'):format(math.floor(mins)));
end

local function try_dig()
    if (not state.running) then return; end
    if (os.clock() < state.next_dig_at) then return; end
    if (os.clock() < state.on_break_until) then return; end

    -- Pre-dig gates
    if (not on_chocobo()) then
        dbg('not on chocobo; waiting');
        state.next_dig_at = os.clock() + 2;
        return;
    end
    state.greens = count_greens();
    if (state.greens <= settings.greens_floor) then
        echo(('out of greens (%d) -- exiting'):format(state.greens));
        start_exit('greens empty');
        return;
    end
    -- 4-yalm move requirement
    local sx, sy, sz = path.self_pos();
    local moved = path.distance(sx, sy, state.last_dig_pos.x, state.last_dig_pos.y);
    if (state.last_dig_at > 0 and moved < 4.5) then
        -- Not moved enough; a human would nudge.  Nudge forward briefly.
        dbg(('need to move (%.1fy); nudging'):format(moved));
        -- Simplest nudge: send a short W tap via pathing's hold/release.
        -- We don't path, just prod W for 300ms via a one-shot.
        pcall(function()
            local ok = pcall(function()
                require('pathing');
            end);
            -- Reuse path's send_key by walking to a point 2.5y ahead would
            -- need camera heading we don't have.  Simplest: skip this dig
            -- cycle and let the user nudge or let auto-exit kick in.
        end);
        state.next_dig_at = os.clock() + 2;
        return;
    end
    -- Break schedule
    if (os.clock() >= state.next_break_at) then
        start_break();
        return;
    end
    -- Fire the dig.
    queue('/dig');
    state.last_dig_at = os.clock();
    state.last_dig_pos = { x=sx, y=sy, z=sz };
    schedule_next_dig();
    state.hours_since_break = state.hours_since_break + (dig_cooldown() / 3600);
end

-- ============================================================================
-- Exit sequence
-- ============================================================================
function start_exit(reason)  -- global so on_text can call it
    if (state.exiting) then return; end
    state.exiting = true;
    state.running = false;
    echo('exit sequence: ' .. reason);
    local wps = {};
    for wp in tostring(settings.exit_route):gmatch('[^,%s]+') do
        wps[#wps+1] = wp;
    end
    if (#wps == 0) then
        warn('no exit_route set -- /chd mark <name> then /chd exitroute <names>');
        warn('dismounting here instead');
        queue('/dismount');
        state.exiting = false;
        return;
    end
    path.walk_route(wps, function(ok, why)
        state.exiting = false;
        if (ok) then
            echo('arrived at exit; dismounting');
            queue('/dismount');
        else
            warn('exit walk failed: ' .. tostring(why) .. '  -- dismounting here');
            queue('/dismount');
        end
    end);
end

-- ============================================================================
-- Commands
-- ============================================================================
local function cmd_help()
    echo('ChharDig commands:');
    echo('  /chd ui | show | hide      toggle the panel UI');
    echo('  /chd on | off              start/stop the loop');
    echo('  /chd status                show counts + flags');
    echo('  /chd mark <name>           save current position as waypoint');
    echo('  /chd wps                   list waypoints in this zone');
    echo('  /chd exitroute <a,b,c>     set the exit path (names of waypoints)');
    echo('  /chd exit                  trigger exit sequence NOW');
    echo('  /chd clear                 clear hard-stop (after fixing issue)');
    echo('  /chd skill <N>             set wing skill (e.g. 55)');
    echo('  /chd staff <names>         comma-sep staff list for hard-stop /tells');
    echo('  /chd paranoia max|metacast|custom');
    echo('  /chd debug                 toggle verbose');
end

local function cmd_status()
    echo(('enabled=%s  running=%s  hard-stopped=%s'):format(
        tostring(settings.enabled), tostring(state.running),
        state.hard_stopped and ('yes: '..state.hard_reason) or 'no'));
    echo(('session: %d digs, %d finds, %d nothing, %d too-close'):format(
        state.session_digs, state.session_finds, state.session_nothing,
        state.session_too_close));
    echo(('today:   %d / %d finds'):format(state.daily_finds, state.daily_cap));
    echo(('greens:  %d   rank: %d  (cooldown %ds)'):format(
        count_greens(), state.wing_rank, dig_cooldown()));
    local wps = path.list_wps();
    echo(('zone %d has %d waypoints  exit_route=%s'):format(
        path.current_zone(), #wps, settings.exit_route == '' and '(unset)' or settings.exit_route));
end

ashita.events.register('command', 'chhardig_cmd', function(e)
    local args = e.command:args();
    if (#args == 0) then return; end
    local root = args[1]:lower();
    if (root ~= '/chd' and root ~= '/chhardig') then return; end
    e.blocked = true;

    local sub = (args[2] or 'status'):lower();
    if (sub == 'help' or sub == '?' or sub == 'h') then cmd_help(); return; end
    if (sub == 'status' or sub == '')              then cmd_status(); return; end

    -- UI toggles
    if (sub == 'ui' or sub == 'show' or sub == 'hide' or sub == 'toggle') then
        if (sub == 'show') then
            state.ui_visible = true;
        elseif (sub == 'hide') then
            state.ui_visible = false;
        else
            state.ui_visible = not state.ui_visible;
        end
        echo('UI: ' .. (state.ui_visible and 'shown' or 'hidden'));
        return;
    end

    if (sub == 'on') then
        if (state.hard_stopped) then
            warn('cleared hard-stop first:  /chd clear  (then re-enable)');
            return;
        end
        settings.enabled = true;
        state.running = true;
        state.cycle_start = os.clock();
        schedule_next_break();
        schedule_next_dig();
        echo('ChharDig ON');
        return;
    end
    if (sub == 'off') then
        settings.enabled = false;
        state.running    = false;
        path.panic_release();
        echo('ChharDig OFF');
        return;
    end
    if (sub == 'clear') then
        state.hard_stopped = false;
        state.hard_reason  = '';
        echo('hard-stop cleared.  /chd on to resume');
        return;
    end
    if (sub == 'mark' and args[3]) then
        local ok, err = path.record_wp(args[3]);
        if (ok) then
            local x,y,z = path.self_pos();
            echo(('waypoint %q = (%.1f, %.1f, %.1f) in zone %d'):format(
                args[3], x, y, z, path.current_zone()));
        else warn(err or 'mark failed'); end
        return;
    end
    if (sub == 'wps') then
        local list = path.list_wps();
        if (#list == 0) then echo('no waypoints in this zone'); return; end
        for _, wp in ipairs(list) do
            echo(('  %-16s (%.1f, %.1f, %.1f)'):format(wp.name, wp.x, wp.y, wp.z));
        end
        return;
    end
    if (sub == 'exitroute' and args[3]) then
        local parts = {}; for i = 3, #args do parts[#parts+1] = args[i]; end
        settings.exit_route = table.concat(parts, ','):gsub('%s+', '');
        echo('exit_route = ' .. settings.exit_route);
        return;
    end
    if (sub == 'exit') then start_exit('manual'); return; end
    if (sub == 'skill' and args[3]) then
        local n = tonumber(args[3]) or 0;
        state.wing_rank = math.min(10, math.floor(n / 10));
        echo(('wing rank set to %d'):format(state.wing_rank));
        return;
    end
    if (sub == 'staff') then
        local parts = {}; for i = 3, #args do parts[#parts+1] = args[i]; end
        settings.staff_names = table.concat(parts, ' ');
        rebuild_staff();
        local n = 0; for _ in pairs(staff_set) do n = n + 1; end
        echo(('%d staff names loaded'):format(n));
        return;
    end
    if (sub == 'paranoia' and args[3]) then
        local p = args[3]:lower();
        settings.paranoia = p;
        if (p == 'max') then
            settings.suspicion_cap = 2;
            settings.distraction_rate = 0.15;
            settings.break_every_min = { 45, 75 };
            settings.auto_logout = true;
        elseif (p == 'metacast') then
            settings.suspicion_cap = 3;
            settings.distraction_rate = 0.09;
            settings.break_every_min = { 60, 90 };
            settings.auto_logout = false;
        end
        echo('paranoia: ' .. p);
        return;
    end
    if (sub == 'debug') then
        settings.debug = not settings.debug;
        echo('debug: ' .. tostring(settings.debug));
        return;
    end
    warn('unknown subcommand: ' .. sub);
end);

-- ============================================================================
-- Event wiring
-- ============================================================================
ashita.events.register('text_in', 'chhardig_text', function(e)
    local ok, err = pcall(on_text, e);
    if (not ok) then dbg('text_in error: ' .. tostring(err)); end
end);
ashita.events.register('packet_in', 'chhardig_pkt', function(e)
    local ok, err = pcall(on_packet, e);
    if (not ok) then dbg('packet_in error: ' .. tostring(err)); end
end);
-- ----- UI context + actions ---------------------------------------------
local function current_zone_name()
    local zid = path.current_zone();
    local okR, res = pcall(function() return AshitaCore:GetResourceManager(); end);
    if (okR and res and zid > 0) then
        local s = res:GetString('zones.names', zid);
        if (s and s ~= '') then return (s:gsub('%z.*$', '')); end
    end
    return 'zone ' .. tostring(zid);
end

-- Build the "possible finds" table from Phoenix digdata for the current zone.
-- Returns a list of { name=..., pct=..., xp=... } sorted desc by pct.
local function build_pool()
    local zid  = path.current_zone();
    local zone = digdata.zones and digdata.zones[zid];
    if (not zone or not zone.items) then return {}; end
    local rank = state.wing_rank or 0;
    local total = 0;
    for _, it in ipairs(zone.items) do
        local w = (it.weight and it.weight[rank + 1]) or 0;
        total = total + w;
    end
    if (total == 0) then return {}; end
    local out = {};
    local okR, res = pcall(function() return AshitaCore:GetResourceManager(); end);
    for _, it in ipairs(zone.items) do
        local w = (it.weight and it.weight[rank + 1]) or 0;
        if (w > 0) then
            local nm = ('item ' .. it.id);
            if (okR and res) then
                local item = res:GetItemById(it.id);
                if (item and item.Name and item.Name[1]) then
                    nm = item.Name[1]:gsub('%z.*$', '');
                end
            end
            out[#out+1] = {
                name = nm,
                pct  = (w / total) * 100,
                xp   = digdata.xp_per_rank and digdata.xp_per_rank[it.rank] or '?',
            };
        end
    end
    table.sort(out, function(a,b) return a.pct > b.pct; end);
    return out;
end

local function build_ctx()
    local zid = path.current_zone();
    state.current_cooldown = dig_cooldown();
    return {
        version       = addon.version,
        visible       = state.ui_visible,
        settings      = settings,
        state         = state,
        zone_id       = zid,
        zone_name     = current_zone_name(),
        greens        = count_greens(),
        on_chocobo    = on_chocobo(),
        wps           = path.list_wps(),
        recent        = state.recent,
        today         = state.today,
        pool          = build_pool(),
        daily_cap     = state.daily_cap,
        session_start = state.session_start,
        actions = {
            toggle = function(on)
                if (on) then
                    if (state.hard_stopped) then
                        warn('clear hard-stop first (Safety tab)');
                        return;
                    end
                    settings.enabled = true; state.running = true;
                    state.session_start = os.clock();
                    schedule_next_break(); schedule_next_dig();
                    echo('ChharDig ON');
                else
                    settings.enabled = false; state.running = false;
                    path.panic_release();
                    echo('ChharDig OFF');
                end
            end,
            exit_now        = function() start_exit('ui'); end,
            clear_hardstop  = function()
                state.hard_stopped = false; state.hard_reason = '';
                echo('hard-stop cleared');
            end,
            mark            = function(nm)
                local ok, err = path.record_wp(nm);
                if (not ok) then warn(err or 'mark failed'); end
            end,
            remove_wp       = function(nm) path.remove_wp(nm); end,
            set_route       = function(csv)
                settings.exit_route = (csv or ''):gsub('%s+', '');
                echo('exit_route = ' .. settings.exit_route);
            end,
            set_skill       = function(n)
                local v = tonumber(n) or 0;
                state.wing_rank = math.min(10, math.max(0, math.floor(v / 10)));
            end,
            set_staff       = function(csv)
                settings.staff_names = csv or '';
                rebuild_staff();
            end,
            set_paranoia    = function(p)
                settings.paranoia = p;
                if (p == 'max') then
                    settings.suspicion_cap    = 2;
                    settings.distraction_rate = 0.15;
                    settings.break_every_min  = { 45, 75 };
                    settings.auto_logout      = true;
                else
                    settings.suspicion_cap    = 3;
                    settings.distraction_rate = 0.09;
                    settings.break_every_min  = { 60, 90 };
                    settings.auto_logout      = false;
                end
            end,
        },
    };
end

ashita.events.register('d3d_present', 'chhardig_tick', function()
    if (state.exiting) then
        path.tick();
    elseif (not state.hard_stopped) then
        try_dig();
    end
    -- Render UI every frame (cheap; imgui handles invisibility)
    if (state.ui_visible) then
        local ctx = build_ctx();
        local ok, err = pcall(ui.render, ctx);
        if (not ok) then dbg('ui error: ' .. tostring(err)); end
        -- Copy visibility back (window close button toggles ctx.visible)
        state.ui_visible = ctx.visible;
    end
end);

ashita.events.register('load', 'chhardig_load', function()
    path.load();
    rebuild_staff();
    schedule_next_break();
    schedule_next_dig();
    state.ui_visible = true;    -- open the panel on load
    echo(('v%s loaded. UI shown. /chd hide to hide, /chd help for commands.'):format(addon.version));
end);
ashita.events.register('unload', 'chhardig_unload', function()
    path.panic_release();
end);
