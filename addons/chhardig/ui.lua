--[[
    chhardig/ui.lua -- Metacast-styled imgui panel for ChharDig.
    theme.lua is vendored verbatim from Metacast (same slate-navy look).
    Public: M.render(ctx) called once per d3d_present frame.

    ctx is a table the main addon fills each frame:
      visible         boolean  -- toggle for the main window
      settings        table    -- the live settings table
      state           table    -- the live state table
      actions = {
          toggle(on)       -- enable/disable the loop
          exit_now()       -- fire the exit sequence
          clear_hardstop() -- reset after a hard-stop
          mark(name)       -- record waypoint at current pos
          remove_wp(name)  -- delete waypoint
          set_route(csv)   -- set exit_route from a csv string
          set_skill(n)     -- update wing skill
          set_staff(csv)   -- update staff name list
          set_paranoia(p)  -- 'max' | 'metacast'
      }
      zone_name       string   -- current zone label
      greens          number   -- live gysahl count
      on_chocobo      boolean
      wps             list     -- waypoints in current zone
      recent          list     -- last ~15 dig results
      pool            list     -- current zone's possible finds
      daily_cap       number   -- 100 on Phoenix
      session_start   clock    -- for session timer
]]--

local imgui = require('imgui');
local theme = require('theme');

local M = {};

-- Current tab (persisted across frames).
local current_tab = 'overview';

-- Scratch buffers for input fields (imgui needs stable storage).
local io_staff = { '' };
local io_route = { '' };
local io_wp    = { '' };
local io_skill = { 0 };

local function fmt_time(secs)
    secs = math.max(0, math.floor(secs or 0));
    local h = math.floor(secs / 3600);
    local m = math.floor((secs % 3600) / 60);
    local s = secs % 60;
    if (h > 0) then return string.format('%dh %02dm %02ds', h, m, s); end
    return string.format('%dm %02ds', m, s);
end

-- Label helper that colors text with the theme's accent.
local function heading(text)
    imgui.TextColored(theme.T.accent, text);
end
local function muted(text)
    imgui.TextColored(theme.T.muted, text);
end
local function value(text, col)
    imgui.TextColored(col or theme.T.text, tostring(text));
end

-- Stat tile: label on top (muted), big value underneath.
local function tile(label, val, col)
    muted(label);
    imgui.TextColored(col or theme.T.text, tostring(val));
end

-- Status-pill colour by state.
local function status_pill(ctx)
    local st = ctx.state;
    local label, col;
    if (st.hard_stopped) then
        label, col = 'HARD STOP', theme.T.bad;
    elseif (st.exiting) then
        label, col = 'exiting', theme.T.warn;
    elseif (st.running) then
        label, col = 'running', theme.T.good;
    elseif (ctx.settings.enabled) then
        label, col = 'armed', theme.T.warn;
    else
        label, col = 'stopped', theme.T.muted;
    end
    imgui.TextColored(col, '* ' .. label);
end

-- ---------------------------------------------------------------------------
-- Overview tab
-- ---------------------------------------------------------------------------
local function tab_overview(ctx)
    local st = ctx.state;
    local sess = (os.clock() - (ctx.session_start or os.clock()));
    local per_hr = (sess > 0) and (st.session_finds / (sess / 3600)) or 0;

    -- Stat tiles grid
    if (imgui.BeginTable('##stats', 3,
            bit.bor(ImGuiTableFlags_SizingStretchSame or 0,
                    ImGuiTableFlags_PadOuterX or 0))) then
        imgui.TableNextRow();
        imgui.TableNextColumn(); tile('Found',       st.session_finds, theme.T.good);
        imgui.TableNextColumn(); tile('Nothing',     st.session_nothing, theme.T.muted);
        imgui.TableNextColumn(); tile('Too close',   st.session_too_close, theme.T.warn);
        imgui.TableNextRow();
        imgui.TableNextColumn(); tile('Per hour',    string.format('%.1f', per_hr), theme.T.text);
        imgui.TableNextColumn(); tile('Digs',        st.session_digs, theme.T.text);
        imgui.TableNextColumn(); tile('Rank',        st.wing_rank, theme.T.accent);
        imgui.EndTable();
    end

    imgui.Spacing(); imgui.Separator(); imgui.Spacing();

    -- Session block (kv list)
    heading('Session');
    if (imgui.BeginTable('##sess', 2)) then
        imgui.TableSetupColumn('k', ImGuiTableColumnFlags_WidthFixed, 110);
        imgui.TableSetupColumn('v', ImGuiTableColumnFlags_WidthStretch);
        local function kv(k, v, c)
            imgui.TableNextRow();
            imgui.TableNextColumn(); muted(k);
            imgui.TableNextColumn(); value(v, c);
        end
        kv('Session',  fmt_time(sess));
        kv('Today',    string.format('%d / %d', st.daily_finds, ctx.daily_cap or 100),
           (st.daily_finds >= (ctx.daily_cap or 100)) and theme.T.good or nil);
        kv('Greens',   ctx.greens, (ctx.greens <= 10) and theme.T.warn or nil);
        kv('Chocobo',  ctx.on_chocobo and 'MOUNTED' or 'not mounted',
           ctx.on_chocobo and theme.T.good or theme.T.muted);
        kv('Last dig', st.last_dig_at > 0
             and (string.format('%ds ago', math.floor(os.clock() - st.last_dig_at)))
             or '-');
        imgui.EndTable();
    end

    imgui.Spacing(); imgui.Separator(); imgui.Spacing();

    -- Recent dig history
    heading('Recent');
    local recent = ctx.recent or {};
    if (#recent == 0) then
        muted('(no digs yet this session)');
    else
        if (imgui.BeginChild('##recent', { 0, 180 }, true)) then
            if (imgui.BeginTable('##rec', 2)) then
                imgui.TableSetupColumn('item', ImGuiTableColumnFlags_WidthStretch);
                imgui.TableSetupColumn('ago',  ImGuiTableColumnFlags_WidthFixed, 80);
                for _, r in ipairs(recent) do
                    imgui.TableNextRow();
                    imgui.TableNextColumn();
                    local col = r.ok and theme.T.text or theme.T.muted;
                    value(r.item or '(nothing)', col);
                    imgui.TableNextColumn();
                    muted(string.format('%ds ago', math.floor(os.clock() - (r.t or os.clock()))));
                end
                imgui.EndTable();
            end
            imgui.EndChild();
        end
    end
end

-- ---------------------------------------------------------------------------
-- Settings tab
-- ---------------------------------------------------------------------------
local function tab_settings(ctx)
    local s = ctx.settings;

    heading('Paranoia preset');
    if (theme.button(s.paranoia == 'max' and '* MAX' or 'MAX', 'tab'..(s.paranoia=='max' and '_on' or ''))) then
        ctx.actions.set_paranoia('max');
    end
    imgui.SameLine();
    if (theme.button(s.paranoia == 'metacast' and '* Metacast' or 'Metacast',
                     'tab'..(s.paranoia=='metacast' and '_on' or ''))) then
        ctx.actions.set_paranoia('metacast');
    end
    imgui.SameLine();
    muted(string.format('(suspicion=%d, distraction=%d%%)',
          s.suspicion_cap or 0, (s.distraction_rate or 0) * 100));

    imgui.Spacing(); imgui.Separator(); imgui.Spacing();

    heading('Safety floors');
    if (imgui.BeginTable('##safe', 2)) then
        imgui.TableSetupColumn('k', ImGuiTableColumnFlags_WidthFixed, 160);
        imgui.TableSetupColumn('v', ImGuiTableColumnFlags_WidthStretch);
        local function row(label, cb)
            imgui.TableNextRow();
            imgui.TableNextColumn(); muted(label);
            imgui.TableNextColumn(); cb();
        end
        row('Greens floor', function()
            local buf = { s.greens_floor };
            if (imgui.InputInt('##gf', buf)) then s.greens_floor = buf[1]; end
        end);
        row('Ride minutes floor', function()
            local buf = { s.ride_min_floor };
            if (imgui.InputInt('##rf', buf)) then s.ride_min_floor = buf[1]; end
        end);
        row('Auto-logout', function()
            local buf = { s.auto_logout };
            if (imgui.Checkbox('on hard-stop##al', buf)) then s.auto_logout = buf[1]; end
        end);
        row('Debug chat', function()
            local buf = { s.debug };
            if (imgui.Checkbox('verbose##dbg', buf)) then s.debug = buf[1]; end
        end);
        imgui.EndTable();
    end

    imgui.Spacing(); imgui.Separator(); imgui.Spacing();

    heading('Staff name watchlist (comma-separated)');
    io_staff[1] = s.staff_names or '';
    if (imgui.InputText('##staff', io_staff, 256)) then
        -- edit buffered; apply on button
    end
    imgui.SameLine();
    if (theme.button('Save', 'primary', 60)) then
        ctx.actions.set_staff(io_staff[1]);
    end
    muted('/tell from any of these names -> hard stop + logout');

    imgui.Spacing(); imgui.Separator(); imgui.Spacing();

    heading('Wing skill (0-100)');
    io_skill[1] = ctx.state.wing_rank * 10;
    if (imgui.InputInt('##skill', io_skill)) then end
    imgui.SameLine();
    if (theme.button('Set', 'primary', 60)) then
        ctx.actions.set_skill(io_skill[1]);
    end
    muted(('Current rank: %d  (cooldown: %ds)'):format(
        ctx.state.wing_rank, ctx.state.current_cooldown or 15));
end

-- ---------------------------------------------------------------------------
-- Waypoints tab
-- ---------------------------------------------------------------------------
local function tab_waypoints(ctx)
    heading(('Zone: %s (%d)'):format(ctx.zone_name or '?', ctx.zone_id or 0));
    muted('Walk to a spot, type a name, click Save to record a waypoint.');

    imgui.Spacing();
    if (imgui.InputText('name##wpname', io_wp, 32)) then end
    imgui.SameLine();
    if (theme.button('Save at current pos', 'primary', 170)) then
        if (io_wp[1] and io_wp[1] ~= '') then
            ctx.actions.mark(io_wp[1]);
            io_wp[1] = '';
        end
    end

    imgui.Spacing(); imgui.Separator(); imgui.Spacing();

    heading('Waypoints in this zone');
    local wps = ctx.wps or {};
    if (#wps == 0) then
        muted('(none)');
    else
        if (imgui.BeginTable('##wps', 3)) then
            imgui.TableSetupColumn('name', ImGuiTableColumnFlags_WidthStretch);
            imgui.TableSetupColumn('pos',  ImGuiTableColumnFlags_WidthFixed, 160);
            imgui.TableSetupColumn('x',    ImGuiTableColumnFlags_WidthFixed, 70);
            for _, w in ipairs(wps) do
                imgui.TableNextRow();
                imgui.TableNextColumn(); value(w.name, theme.T.accent);
                imgui.TableNextColumn();
                muted(string.format('%.1f, %.1f, %.1f', w.x, w.y, w.z));
                imgui.TableNextColumn();
                if (theme.button('X##rm'..w.name, 'danger', 32)) then
                    ctx.actions.remove_wp(w.name);
                end
            end
            imgui.EndTable();
        end
    end

    imgui.Spacing(); imgui.Separator(); imgui.Spacing();

    heading('Exit route (comma-separated waypoint names)');
    io_route[1] = ctx.settings.exit_route or '';
    if (imgui.InputText('##route', io_route, 256)) then end
    imgui.SameLine();
    if (theme.button('Save', 'primary', 60)) then
        ctx.actions.set_route(io_route[1]);
    end
    muted('Walked in order on exit.  e.g.: halfway, zoneline');
end

-- ---------------------------------------------------------------------------
-- Safety tab
-- ---------------------------------------------------------------------------
local function tab_safety(ctx)
    local st = ctx.state;

    heading('Hard-stop status');
    if (st.hard_stopped) then
        imgui.TextColored(theme.T.bad, 'HARD-STOPPED: ' .. (st.hard_reason or ''));
        imgui.Spacing();
        if (theme.button('Clear hard-stop', 'warn', 170)) then
            ctx.actions.clear_hardstop();
        end
        muted('Only clear this after you understand WHY it tripped.');
    else
        imgui.TextColored(theme.T.good, 'armed and clean');
    end

    imgui.Spacing(); imgui.Separator(); imgui.Spacing();

    heading('Hard-stop triggers');
    if (imgui.BeginTable('##trig', 2)) then
        imgui.TableSetupColumn('k', ImGuiTableColumnFlags_WidthFixed, 180);
        imgui.TableSetupColumn('v', ImGuiTableColumnFlags_WidthStretch);
        local function row(k, v) imgui.TableNextRow();
            imgui.TableNextColumn(); muted(k);
            imgui.TableNextColumn(); value(v);
        end
        row('GM level >= 3',       'always');
        row('Wallhack / hackmove', 'always');
        row('Hidden GM icon',      'always');
        row('AFK check prompt',    'always');
        row('Staff /tell',         (ctx.settings.staff_names ~= '')
            and ('(watching: ' .. ctx.settings.staff_names .. ')')
            or '(no staff list set)');
        row('Daily cap reached',   string.format('%d / %d finds',
            st.daily_finds, ctx.daily_cap or 100));
        imgui.EndTable();
    end

    imgui.Spacing(); imgui.Separator(); imgui.Spacing();

    heading('Break schedule');
    local now = os.clock();
    local to_break = math.max(0, st.next_break_at - now);
    local on_break = math.max(0, st.on_break_until - now);
    muted(('next break in %s'):format(fmt_time(to_break)));
    if (on_break > 0) then
        imgui.TextColored(theme.T.warn,
            ('ON BREAK: %s remaining'):format(fmt_time(on_break)));
    end
end

-- ---------------------------------------------------------------------------
-- Data tab -- today's totals + current zone pool
-- ---------------------------------------------------------------------------
local function tab_data(ctx)
    heading('Possible finds in this zone');
    local pool = ctx.pool or {};
    if (#pool == 0) then
        muted('(no pool loaded for this zone)');
    else
        if (imgui.BeginChild('##pool', { 0, 240 }, true)) then
            if (imgui.BeginTable('##pt', 3)) then
                imgui.TableSetupColumn('item', ImGuiTableColumnFlags_WidthStretch);
                imgui.TableSetupColumn('odds', ImGuiTableColumnFlags_WidthFixed, 70);
                imgui.TableSetupColumn('xp',   ImGuiTableColumnFlags_WidthFixed, 60);
                for _, p in ipairs(pool) do
                    imgui.TableNextRow();
                    imgui.TableNextColumn(); value(p.name);
                    imgui.TableNextColumn();
                    muted(string.format('%.2f%%', (p.pct or 0)));
                    imgui.TableNextColumn();
                    muted(tostring(p.xp or '?'));
                end
                imgui.EndTable();
            end
            imgui.EndChild();
        end
    end

    imgui.Spacing(); imgui.Separator(); imgui.Spacing();

    heading("Today's digs");
    local today = ctx.today or {};
    if (next(today) == nil) then
        muted('(nothing dug yet today)');
    else
        if (imgui.BeginTable('##tod', 2)) then
            imgui.TableSetupColumn('item', ImGuiTableColumnFlags_WidthStretch);
            imgui.TableSetupColumn('n',    ImGuiTableColumnFlags_WidthFixed, 60);
            for name, n in pairs(today) do
                imgui.TableNextRow();
                imgui.TableNextColumn(); value(name);
                imgui.TableNextColumn(); value(tostring(n));
            end
            imgui.EndTable();
        end
    end
end

-- ---------------------------------------------------------------------------
-- Main render
-- ---------------------------------------------------------------------------
function M.render(ctx)
    if (not ctx.visible) then return; end

    local nc, nv = theme.push(1.0);
    imgui.SetNextWindowSize({ 540, 720 }, ImGuiCond_FirstUseEver);
    local open = { ctx.visible };
    if (imgui.Begin('ChharDig##chhardig_main', open,
            bit.bor(ImGuiWindowFlags_NoCollapse or 0))) then

        -- ===== Header row =====
        imgui.TextColored(theme.T.accent, 'ChharDig v' .. (ctx.version or '1.0'));
        imgui.SameLine();
        muted('by Chharizard');
        imgui.SameLine();
        imgui.SetCursorPosX(imgui.GetWindowWidth() - 160);
        status_pill(ctx);
        imgui.SameLine();
        muted(string.format('Found %d', ctx.state.session_finds));

        -- START / STOP + EXIT
        if (ctx.state.running or ctx.state.exiting) then
            if (theme.button('STOP', 'danger', 90, 30)) then ctx.actions.toggle(false); end
        else
            if (theme.button('START', 'go', 90, 30)) then ctx.actions.toggle(true); end
        end
        imgui.SameLine();
        if (theme.button('Exit now', 'warn', 90, 30)) then ctx.actions.exit_now(); end
        imgui.SameLine();
        muted(ctx.zone_name or '?');
        imgui.SameLine();
        muted('| ' .. (ctx.on_chocobo and 'Chocobo' or 'ground'));

        -- Equipment / mode line
        muted(string.format('Greens %d  |  Rank %d  |  Daily %d / %d',
            ctx.greens or 0, ctx.state.wing_rank,
            ctx.state.daily_finds, ctx.daily_cap or 100));

        imgui.Separator();

        -- ===== Tab bar =====
        local function tbtn(key, label)
            local style = (current_tab == key) and 'tab_on' or 'tab';
            if (theme.button(label, style)) then current_tab = key; end
            imgui.SameLine();
        end
        tbtn('overview',  'Overview');
        tbtn('settings',  'Settings');
        tbtn('waypoints', 'Waypoints');
        tbtn('safety',    'Safety');
        tbtn('data',      'Data');
        imgui.NewLine();
        imgui.Separator();
        imgui.Spacing();

        -- ===== Tab body =====
        if     (current_tab == 'overview')  then tab_overview(ctx);
        elseif (current_tab == 'settings')  then tab_settings(ctx);
        elseif (current_tab == 'waypoints') then tab_waypoints(ctx);
        elseif (current_tab == 'safety')    then tab_safety(ctx);
        elseif (current_tab == 'data')      then tab_data(ctx);
        end

        imgui.End();
    else
        imgui.End();
    end
    ctx.visible = open[1];
    theme.pop(nc, nv);
end

return M;
