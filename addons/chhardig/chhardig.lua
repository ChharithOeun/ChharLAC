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
    -- H3: exit_route is no longer driven by scripted walk; waypoints are
    -- reference-only.  Kept in settings for config-file compat.
    exit_route        = '',            -- (deprecated, reference only)
    debug             = false,
};
local settings = defaults:copy(true);

-- ============================================================================
-- M3 fix (audit 2026-11-17): settings persistence.
-- Previously defaults:copy(true) ran every load and every UI/command edit
-- evaporated on unload.  Now we persist a whitelist of user-tunable keys
-- to config/addons/chhardig/settings_<pid>.lua (per-character, matching
-- the waypoint save layout).  Transient state (`enabled`) and deprecated
-- keys (`exit_route`) are NOT persisted.
-- ============================================================================
local SETTINGS_KEYS = {
    'paranoia', 'suspicion_cap', 'auto_logout',
    'greens_floor', 'ride_min_floor',
    'break_every_min', 'break_dur_min',
    'cast_jitter_pct', 'distraction_rate', 'long_lapse_rate',
    'staff_names', 'debug',
};
local _settings_path = nil;
local function settings_path()
    if (_settings_path) then return _settings_path; end
    local okP, party = pcall(function()
        return AshitaCore:GetMemoryManager():GetParty();
    end);
    local pid = (okP and party) and party:GetMemberServerId(0) or 0;
    local base = AshitaCore:GetInstallPath() .. 'config/addons/chhardig/';
    pcall(ashita.fs.create_directory, base);
    _settings_path = base .. ('settings_%d.lua'):format(pid);
    return _settings_path;
end

local function _serialize(v, indent)
    indent = indent or '';
    local t = type(v);
    if (t == 'string') then return string.format('%q', v); end
    if (t == 'number' or t == 'boolean') then return tostring(v); end
    if (t == 'table') then
        local parts = { '{' };
        local nin = indent .. '  ';
        -- Numeric keys first (for arrays like break_every_min)
        local n = #v;
        if (n > 0) then
            for i = 1, n do
                parts[#parts+1] = nin .. _serialize(v[i], nin) .. ',';
            end
        else
            for k, vv in pairs(v) do
                parts[#parts+1] = nin .. ('[%q] = %s,'):format(
                    tostring(k), _serialize(vv, nin));
            end
        end
        parts[#parts+1] = indent .. '}';
        return table.concat(parts, '\n');
    end
    return 'nil';
end

local function save_settings()
    local p = settings_path();
    local f = io.open(p, 'w');
    if (not f) then return false, 'cannot open ' .. p; end
    f:write('-- chhardig settings -- do not edit while addon is loaded\n');
    f:write('return {\n');
    for _, k in ipairs(SETTINGS_KEYS) do
        if (settings[k] ~= nil) then
            f:write(('  [%q] = %s,\n'):format(k, _serialize(settings[k], '  ')));
        end
    end
    f:write('};\n');
    f:close();
    return true;
end

local function load_settings()
    local p = settings_path();
    local f = io.open(p, 'r');
    if (not f) then return; end
    f:close();
    local ok, data = pcall(dofile, p);
    if (not ok or type(data) ~= 'table') then return; end
    for _, k in ipairs(SETTINGS_KEYS) do
        if (data[k] ~= nil) then settings[k] = data[k]; end
    end
end

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

-- Forward declaration so on_text/try_dig can refer to start_exit before it
-- is defined later in the file.  L1 fix (audit 2026-11-17): no longer a
-- global.
local start_exit

-- Count Gysahl Greens across inventory + wardrobes.
local function count_greens()
    local okI, inv = pcall(function()
        return AshitaCore:GetMemoryManager():GetInventory();
    end);
    if (not okI or not inv) then return 0; end
    local GREENS_ID = 4545;    -- Gysahl Green item id (Phoenix / retail)
    local total = 0;
    -- M1 fix (audit 2026-11-17): the old list skipped Wardrobe 2 (container 9)
    -- and all mog bags/cases.  Full in-reach list:
    --   0=inventory  5=mog_satchel  6=mog_sack  7=mog_case
    --   8..12 = Wardrobe 1..5
    local containers = { 0, 5, 6, 7, 8, 9, 10, 11, 12 };
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

-- Is the player mounted on a chocobo?  Status 5 = rental chocobo,
-- 85 = mount item (Chocobo Whistle, etc.).  Both can /dig on Phoenix.
-- M2 fix (audit 2026-11-17): sentinel.MOUNTED covers both.
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
    return sentinel.MOUNTED[st] == true;
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

-- H1 fix (audit 2026-11-17): the realism median is ~3.0s, but Phoenix's
-- rank-10 cooldown is ALSO 3s.  Using max(server_floor, realism) at high
-- rank clusters >50% of samples at exactly the server floor -- the bot
-- pattern.  A hard-raised floor just shifts the pile-up to the new value.
-- The fix spreads samples BELOW the server CD uniformly into a 2.5s
-- window ABOVE it, so no single value is a peak:
--   if realism < server_cd: gap = server_cd + U(1.5, 4.0)
--   else                  : gap = realism (log-normal, already spread)
-- Target: < 15% of rank-10 samples at any 0.3s bucket (tests enforce).

-- Hard-stop: unrecoverable until the user explicitly /chd clear.
local function hard_stop(reason)
    state.hard_stopped = true;
    state.hard_reason  = reason;
    state.running      = false;
    state.exiting      = false;
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

-- H2 fix (audit 2026-11-17): wire sentinel.add/total.  Tracks per-player:
--   * first "close appearance" -- someone showing up inside 25y        +1
--   * re-appearance after being gone >60s (likely a warp back)         +1
--   * abnormal speed (>80, past the server clamp)                      +2
-- When a player's 15-min total hits settings.suspicion_cap, hard_stop.
-- The /check gate (0x036 to our idx) is also wired -- a GM examining
-- you is the single highest-signal event other than their icon showing.
local seen = {};    -- idx -> { last_seen, last_name, last_x, last_y, was_close }
local CLOSE_Y = 25;
local REVISIT_GAP = 60;

local function my_target_index()
    local okP, party = pcall(function()
        return AshitaCore:GetMemoryManager():GetParty();
    end);
    if (not okP or not party) then return 0; end
    return party:GetMemberTargetIndex(0) or 0;
end

local function score_suspicion(d)
    if (state.hard_stopped) then return; end
    if (not d or not d.general or not d.name or not d.idx) then return; end
    local me = my_target_index();
    if (d.idx == me) then return; end        -- that's us
    local sx, sy = path.self_pos();
    local close_now = false;
    if (d.px and d.p2) then
        close_now = (path.distance(sx, sy, d.px, d.p2) < CLOSE_Y);
    end
    local now = os.clock();
    local prev = seen[d.idx];
    local pts, why = 0, nil;

    if (prev) then
        local dt = now - prev.last_seen;
        if (close_now and not prev.was_close and dt < REVISIT_GAP) then
            pts, why = 1, 'close appearance';
        elseif (close_now and dt >= REVISIT_GAP) then
            pts, why = 1, 'returned close after ' .. math.floor(dt) .. 's';
        end
    elseif (close_now) then
        pts, why = 1, 'first seen close';
    end

    local odd = sentinel.odd_speed(d);
    if (odd) then pts, why = 2, ('speed=%d (past clamp)'):format(odd); end

    seen[d.idx] = {
        last_seen = now, last_name = d.name,
        last_x = d.px, last_y = d.p2, was_close = close_now,
    };

    if (pts > 0) then
        local total = sentinel.add(d.name, pts, why);
        dbg(('suspicion +%d %s (%s)  total=%d / %d'):format(
            pts, d.name, why, total, settings.suspicion_cap));
        if (total >= (settings.suspicion_cap or 2)) then
            hard_stop(('suspicion %d: %s [%s]'):format(
                total, d.name, sentinel.reasons(d.name)));
        end
    end
end

-- 0x036: Examine (/check) -- sent by the examiner, echoed to the target.
-- If the target index in the packet is us, someone just /check'd us.
-- That's a +1 and worth noting the name if sentinel has one for the idx.
local function score_check(e)
    if (state.hard_stopped) then return; end
    if (#e.data_raw < 0x08) then return; end
    local target_idx = string.byte(e.data_raw, 0x07) * 256
                     + string.byte(e.data_raw, 0x06);
    if (target_idx ~= my_target_index()) then return; end
    local actor_idx = string.byte(e.data_raw, 0x05) * 256
                    + string.byte(e.data_raw, 0x04);
    local who = (seen[actor_idx] and seen[actor_idx].last_name) or '(unknown)';
    local total = sentinel.add(who, 1, '/check');
    dbg(('suspicion +1 %s (/check)  total=%d'):format(who, total));
    if (total >= (settings.suspicion_cap or 2)) then
        hard_stop(('suspicion %d: %s [%s]'):format(
            total, who, sentinel.reasons(who)));
    end
end

local function on_packet(e)
    if (state.hard_stopped) then return; end
    if (e.id == 0x00D) then
        local decoded = sentinel.decode_00D(e.data_raw, e.size);
        if (not decoded) then return; end
        local signs = sentinel.gm_signs(decoded);
        if (#signs > 0) then
            hard_stop('GM signs: ' .. table.concat(signs, ', '));
            return;
        end
        score_suspicion(decoded);
    elseif (e.id == 0x036) then
        score_check(e);
    end
end

-- ============================================================================
-- Main loop
-- ============================================================================
local function fatigue_hours()
    return state.hours_since_break;
end

local function schedule_next_dig()
    -- H1 fix: see human_floor comment above.  Samples that fall below the
    -- server CD get sprayed uniformly into [cd+1.5, cd+4.0], so no exact
    -- value becomes a spike.  Samples above the CD stay as realism gave
    -- them (log-normal, already well-spread).
    local base = dig_cooldown();
    local extra = realism.recast_gap(fatigue_hours());
    local gap;
    if (extra < base) then
        gap = base + 1.5 + math.random() * 2.5;
    else
        gap = extra;
    end
    -- 10% chance of adding a small extra gap on top -- avoids any residual
    -- clustering at the lower edge of the spray window.
    if (math.random() < 0.10) then
        gap = gap + 2 + math.random() * 4;
    end
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
-- H3 fix (audit 2026-11-17): the walk-to-zoneline path used keybd_event +
-- KEYEVENTF_SCANCODE, which sets LLKHF_INJECTED on every event -- the
-- textbook injection fingerprint.  That routine fired right when staff
-- was already watching (i.e., after a hard-stop trigger), making it the
-- single highest-signal thing the addon did.  We dismount in place and
-- logout; the scripted W-hold is gone.  /chd mark/wps still work as a
-- reference tool for the user, they just don't drive movement anymore.
start_exit = function(reason)
    if (state.exiting) then return; end
    state.exiting = true;
    state.running = false;
    echo('exit: ' .. reason .. ' -- dismounting in place');
    queue('/dismount');
    -- Logout after dismount settles.  /logout blocks for 30s on its own,
    -- so no need for a scheduled follow-up; firing both back-to-back
    -- lets the client sequence them correctly.
    if (settings.auto_logout) then
        queue('/logout');
    end
    state.exiting = false;
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
    echo('  /chd exit                  dismount in place + logout NOW');
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
    if (sub == 'exitroute') then
        warn('exitroute is deprecated (H3): exit is now dismount-in-place.');
        warn('waypoints are reference-only now; /chd mark still works.');
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
        save_settings();
        local n = 0; for _ in pairs(staff_set) do n = n + 1; end
        echo(('%d staff names loaded (persisted)'):format(n));
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
        save_settings();
        echo('paranoia: ' .. p .. ' (persisted)');
        return;
    end
    if (sub == 'debug') then
        settings.debug = not settings.debug;
        save_settings();
        echo('debug: ' .. tostring(settings.debug) .. ' (persisted)');
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
                save_settings();
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
                save_settings();
            end,
        },
    };
end

ashita.events.register('d3d_present', 'chhardig_tick', function()
    -- H3: no more scripted walking during exit; start_exit is one-shot.
    if (not state.hard_stopped and not state.exiting) then
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
    load_settings();         -- M3: pick up persisted user prefs
    rebuild_staff();
    schedule_next_break();
    schedule_next_dig();
    state.ui_visible = true;    -- open the panel on load
    echo(('v%s loaded. UI shown. /chd hide to hide, /chd help for commands.'):format(addon.version));
end);
ashita.events.register('unload', 'chhardig_unload', function()
    -- M3: final save catches any UI-slider edits that didn't go through
    -- an explicit mutator (greens_floor, ride_min_floor, auto_logout
    -- checkbox, debug checkbox).
    pcall(save_settings);
    -- H3: no more held VK_W to release.  No-op kept for symmetry.
end);
