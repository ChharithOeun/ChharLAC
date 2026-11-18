--[[
ChharTarget -- Ashita v4 port of Arcon/Windower's TargetInfo (v1.0.1.2).

Shows the current target's full ID, hex (short) ID, movement speed, and name.
Adds a PH/NM identifier: if the mob is a known placeholder for a Notorious
Monster, the NM name(s) are shown so you know whether to kill it.

Works on era servers -- Phoenix XI (ERA / 75-cap), Horizon XI, and anything
else running Ashita v4.  Uses mob NAMES for the PH database (portable
across servers), not mob IDs (which vary).

Commands (prefix: /chhartarget or /ct):
  /ct show                 Show the HUD
  /ct hide                 Hide the HUD
  /ct toggle               Flip visibility
  /ct hex on|off           Toggle short/hex ID display
  /ct full on|off          Toggle full ID display
  /ct speed on|off         Toggle speed display
  /ct ph on|off            Toggle PH/NM annotation
  /ct add <ph>=<nm>        Add a user PH entry at runtime
  /ct count                Print how many PH entries are loaded
  /ct dump                 Dump current target's full mob record to chat
                           (useful for discovering unknown PHs on a new zone)
  /ct help

Original (c) 2013-2017 Arcon / Windower.  Era port rewritten for Ashita v4.
]]--

addon.name     = 'chhartarget';
addon.author   = 'Chharizard (Ashita port of Arcon/Windower TargetInfo)';
addon.version  = '1.0.0';
addon.desc     = 'Target info with PH->NM annotation for era servers.';
addon.commands = { '/chhartarget', '/ct' };

require('common');
local chat = require('chat');
local imgui_ok, imgui = pcall(require, 'imgui');
local PH   = require('ph_database');

-- Optional: checkmate-sourced BLU-learnable-spell table. Safe no-op if
-- the file isn't shipped. Lookup is BLU[mob_name_lower] -> { name, spells={...} }.
local okBlu, BLU_DB = pcall(require, 'blu_from_checkmate');
if (not okBlu) then BLU_DB = nil; end

local cfg = {
    show        = true,
    show_full   = true,
    show_hex    = true,
    show_speed  = true,
    show_name   = true,
    show_ph     = true,
    pos_x       = 100,
    pos_y       = 300,
};

local function echo(msg)
    print(chat.header('ChharTarget') .. chat.message(msg));
end

local function err(msg)
    print(chat.header('ChharTarget') .. chat.error(msg));
end

-- ----------------------------------------------------------------------------
-- Target lookup.  Ashita v4's Target class exposes the entity INDEX directly
-- via GetTargetIndex(slot) -- 0=main, 1=sub.  No need to walk 2000+ entities.
-- ----------------------------------------------------------------------------
local function getTargetEntity()
    local mm = AshitaCore:GetMemoryManager();
    if (not mm) then return nil; end
    local target = mm:GetTarget();
    if (not target) then return nil; end

    -- Try sub-target first (<stnpc>/<stpc>/<stmob>), then main target.
    local subIdx  = target.GetTargetIndex  and target:GetTargetIndex(1)  or 0;
    local mainIdx = target.GetTargetIndex  and target:GetTargetIndex(0)  or 0;
    local idx = (subIdx and subIdx > 0) and subIdx or mainIdx;
    if (not idx or idx == 0) then return nil; end
    return idx;
end

local function getMob(index)
    if (not index) then return nil; end
    local entity = AshitaCore:GetMemoryManager():GetEntity();
    if (not entity) then return nil; end
    local name = entity:GetName(index);
    if (not name or name == '') then return nil; end
    return {
        index   = index,
        id      = entity:GetServerId(index),
        name    = name,
        status  = entity:GetStatus(index),
        hpp     = entity:GetHPPercent(index),
        -- Speed is encoded; retail formula from original addon:
        -- status 5 (engaged) or 85 (?) -> speed/4; else speed/5 - 1
        move    = entity:GetMovementSpeed(index) or 0,
    };
end

local function formatSpeed(mob)
    if (not mob) then return '-'; end
    local raw = mob.move or 0;
    local pct;
    if (mob.status == 5 or mob.status == 85) then
        pct = math.floor(100 * (raw / 4) + 0.5);
    else
        pct = math.floor(100 * (raw / 5 - 1) + 0.5);
    end
    local sign = (pct >= 0) and '+' or '';
    return sign .. pct .. '%';
end

-- ----------------------------------------------------------------------------
-- ToD (Time of Death) tracker.  Watches chat for "<NM> was defeated" /
-- "<NM> falls to the ground" style lines and timestamps each NM's death.
-- ToD[nm_name_lower] = os.time() of last death.
-- The render path reads this to show "ToD: 23m ago -- opens in 37m".
--
-- All known NMs in our DB are tracked; unknown mobs are ignored.
-- ----------------------------------------------------------------------------
ToD = ToD or {};

-- Build a set of lowercase NM names from the PH DB (both pop targets and
-- NM-direct entries) so we only react to actual NM deaths.
local function buildNmSet()
    local set = {};
    -- Walk PH DB entries (we re-require it since the file is loaded as a module)
    local raw = PH;  -- the required module
    -- NM-direct entries are keys where entry.nm == true
    -- PH entries have entry.pops with NM names in them
    -- We can't iterate the PH table directly (it's module-local), so we
    -- do a scan via lookup() -- cheap because our DB is <200 entries.
    -- Easier approach: watch EVERY defeat message and only store a ToD if the
    -- name happens to appear in our DB. See the text_in handler below.
    return set;
end

-- Per-mob-name "last killed" hex tracker.  When something dies, if we saw
-- it as a current/sub target with a hex index, we remember the hex.  This
-- lets `/ct learn X` associate "last Forest Hare I killed" with NM X.
lastKilledHex = lastKilledHex or {};   -- [mobname_lower] = hex_index

-- Record the hex every time we TARGET a mob (so we have a record even if
-- a party member lands the killing blow).
local function trackLastSeen()
    local mm = AshitaCore:GetMemoryManager();
    if (not mm) then return; end
    local tgt = mm:GetTarget();
    if (not tgt or not tgt.GetTargetIndex) then return; end
    local idx = tgt:GetTargetIndex(0);
    if (not idx or idx == 0) then return; end
    local ent = mm:GetEntity();
    if (not ent) then return; end
    local name = ent:GetName(idx);
    if (name and name ~= '') then
        lastKilledHex[name:lower()] = idx;
    end
end
ashita.events.register('d3d_present', 'chhartarget_tracktgt', trackLastSeen);

ashita.events.register('text_in', 'chhartarget_tod', function(e)
    if (not e or not e.message) then return; end
    local msg = e.message;
    -- FFXI defeat messages take several forms depending on who got the KB:
    --   "Chharizard defeats the Forest Hare."    (you got the KB, player-first)
    --   "Chharizard defeats Jaggedy-Eared Jack." (NM, no "the")
    --   "The Snipper was defeated by Chharizard."
    --   "Hurkan is defeated by Chharizard."
    --   "The Hurkan falls to the ground."        (older)
    local name = msg:match('defeats the (.+)%.')
               or msg:match('defeats ([A-Z][^.]*)%.')  -- NM-named without "the"
               or msg:match('The (.+) was defeated')
               or msg:match('^(.+) is defeated by')
               or msg:match('The (.+) falls to the ground')
               or msg:match('^(.+) falls to the ground');
    if (name) then name = name:gsub('%s+$', ''); end  -- trim trailing space
    if (not name) then return; end
    local lower = name:lower();
    local echo = function(m) print(chat.header('ChharTarget') .. chat.message(m)); end

    -- Is this a known PH or NM?  (Check direct lookup AND any entry whose
    -- pops list contains this NM.)  Random XP mobs are silent -- no ToD spam.
    local entry = PH.lookup(lower);
    local isTrackedNM = false;
    if (not entry) then
        PH.each(function(k, v)
            if (v.pops) then
                for _, nmName in ipairs(v.pops) do
                    if (nmName:lower() == lower) then isTrackedNM = true; return; end
                end
            end
        end);
    end

    if (not entry and not isTrackedNM) then
        return;   -- silent for untracked mobs
    end

    -- FALSE-POSITIVE GUARD: a bare name match (e.g. "forest hare") is NOT
    -- enough to call a kill a PH kill.  Dozens of same-named mobs wander
    -- zones that aren't the NM camp.  For PH entries (entry.pops set and
    -- not entry.nm), require that the mob we just saw killed is hex-confirmed
    -- as a PH:
    --   * ph_hex_ids              (user-learned on THIS server)
    --   * ph_hex_ids_retail       (BG-Wiki authority; usually right on era)
    --   * hex_range               (user-set widescan group range)
    -- NM-direct kills (entry.nm) always echo.  Auto-learn below is unchanged
    -- so the DB can still bootstrap itself from an uncontaminated NM pop.
    -- NEW: zone gate (added via checkmate merge).  Reject the PH echo if
    -- entry has a zone id and the player is somewhere else.  Catches the
    -- case where the hex check isn't configured for a given PH yet but we
    -- still want to suppress out-of-zone noise.  Returns early -- no echo.
    if (entry and entry.zone) then
        local okZ, zoneId = pcall(function()
            local p = AshitaCore and AshitaCore:GetMemoryManager() and AshitaCore:GetMemoryManager():GetParty();
            return p and p:GetMemberZone(0);
        end);
        if (okZ and zoneId and zoneId ~= 0 and zoneId ~= entry.zone) then
            return;   -- player not in NM camp zone; silence the echo
        end
    end

    local isPhEntry  = entry and entry.pops and #entry.pops > 0 and not entry.nm;
    if (isPhEntry) then
        local lastHex = lastKilledHex[lower];
        local hexOk   = false;
        if (lastHex) then
            if (entry.ph_hex_ids) then
                for _, id in ipairs(entry.ph_hex_ids) do
                    if (id == lastHex) then hexOk = true; break; end
                end
            end
            if (not hexOk and entry.ph_hex_ids_retail) then
                for _, id in ipairs(entry.ph_hex_ids_retail) do
                    if (id == lastHex) then hexOk = true; break; end
                end
            end
            if (not hexOk and entry.hex_range) then
                if (lastHex >= entry.hex_range[1] and lastHex <= entry.hex_range[2]) then
                    hexOk = true;
                end
            end
        end
        if (not hexOk) then
            return;   -- name-only match -> treat as random XP mob, no echo
        end
    end

    -- Record ToD + echo (keyed by the dead mob's name, lowercased).
    local now = os.time();
    -- DEDUP: FFXI emits the same "defeats" message multiple times for a
    -- single kill (one per party member credit, retransmits, etc).  Treat
    -- any repeat within 30 seconds for the same mob name as a dupe.
    if (ToD[lower] and (now - ToD[lower]) < 30) then
        return;
    end
    ToD[lower] = now;
    -- Compute "next window opens" using whichever respawn_sec we have.
    -- Prefer the dead mob's own entry; fall back to the NM entry if the
    -- user killed the PH (so we show when the NM window opens).
    local respawnSec = entry and entry.respawn_sec;
    local nmLabel = '';
    if (not respawnSec and entry and entry.pops and entry.pops[1]) then
        local nmEntry = PH.lookup(entry.pops[1]);
        if (nmEntry and nmEntry.respawn_sec) then
            respawnSec = nmEntry.respawn_sec;
            nmLabel    = ' (NM: ' .. entry.pops[1] .. ')';
        end
    end
    local tag = 'ToD: ' .. name .. ' @ ' .. os.date('%H:%M:%S');
    if (respawnSec and respawnSec > 0) then
        local openAt = now + respawnSec;
        tag = tag .. string.format('  -- next window: %s (in %s)%s',
            os.date('%H:%M:%S', openAt),
            PH.fmtDuration(respawnSec),
            nmLabel);
    end
    echo(tag);

    -- AUTO-LEARN: if the mob that just died IS an NM our DB knows about,
    -- walk our DB to find the PH family that pops it, then check the
    -- lastKilledHex[phkey] -- that's the hex that just spawned this NM.
    -- Record it, persist to ph_user.lua, done.  No manual /ct learn needed.
    if (entry == nil) then
        PH.each(function(phKey, phEntry)
            if (phEntry.pops) then
                for _, nmName in ipairs(phEntry.pops) do
                    if (nmName:lower() == lower) then
                        local hex = lastKilledHex[phKey];
                        -- Also check who you targeted most-recently of that PH family
                        -- within the recent window (handles party-kill situations)
                        if (hex) then
                            local alreadyKnown = false;
                            if (phEntry.ph_hex_ids) then
                                for _, id in ipairs(phEntry.ph_hex_ids) do
                                    if (id == hex) then alreadyKnown = true; break; end
                                end
                            end
                            if (not alreadyKnown) then
                                PH.learn(phKey, hex);
                                echo(string.format('AUTO-LEARNED: %s PH = %s @ hex 0x%X',
                                    nmName, phKey, hex));
                                -- Persist to ph_user.lua for next session
                                local path = AshitaCore:GetInstallPath()
                                    .. 'config/addons/chhartarget/ph_user.lua';
                                os.execute('mkdir "' .. (AshitaCore:GetInstallPath()
                                    .. 'config/addons/chhartarget'):gsub('/','\\')
                                    .. '" 2>nul');
                                local f = io.open(path, 'a');
                                if (f) then
                                    f:write(string.format(
                                      'PH.learn(%q, 0x%X)   -- auto-learned, NM: %s\n',
                                      phKey, hex, nmName));
                                    f:close();
                                end
                            end
                        end
                    end
                end
            end
        end);
    end

    if (entry) then
        -- If this IS an NM, timestamp its own name.  If it's a PH, timestamp
        -- the NM(s) it pops (because killing the PH resets its spawn-cycle;
        -- but ToD technically means "when the NM died").  We store BOTH.
        ToD[lower] = os.time();
        if (entry.pops) then
            for _, nmName in ipairs(entry.pops) do
                -- Only overwrite NM ToD if this entry was the NM itself,
                -- otherwise we'd corrupt ToD by stamping on every PH kill.
                if (entry.nm) then
                    ToD[nmName:lower()] = os.time();
                end
            end
        end
        -- NM-direct kill: stamp both the lookup key and the display name
        if (entry.nm) then ToD[lower] = os.time(); end
    end
end);

-- ----------------------------------------------------------------------------
-- Render -- plain imgui window.  Falls back to primitive text if imgui is
-- not available (very old Ashita builds).
-- ----------------------------------------------------------------------------
local function render()
    if (not cfg.show) then return; end
    if (not imgui_ok or not imgui) then return; end

    -- Hide the HUD entirely when no target (matches retail TargetInfo UX).
    local idx = getTargetEntity();
    local mob = idx and getMob(idx) or nil;
    if (not mob or (mob.hpp or 0) <= 0) then return; end

    pcall(imgui.SetNextWindowPos, {cfg.pos_x, cfg.pos_y}, 4);  -- FirstUseEver
    pcall(imgui.SetNextWindowSize, {240, 0}, 4);
    local ok = pcall(imgui.Begin, 'ChharTarget', true,
                     bit and bit.bor(1, 64) or 0);   -- NoCollapse + NoFocusOnAppearing
    if (not ok) then
        if (not pcall(imgui.Begin, 'ChharTarget')) then return; end
    end

    do
        if (cfg.show_name) then
            pcall(imgui.Text, 'Target: ' .. tostring(mob.name));
        end
        if (cfg.show_full) then
            pcall(imgui.Text, string.format('ID:    %8d', mob.id or 0));
        end
        if (cfg.show_hex) then
            pcall(imgui.Text, string.format('Hex:        %3X', mob.index or 0));
        end
        if (cfg.show_speed) then
            pcall(imgui.Text, 'Speed:   ' .. formatSpeed(mob));
        end

        -- BLU learnable-spell teaser.  Shows the spell(s) this mob family
        -- can teach a Blue Mage, as a reminder to /check it with
        -- checkmate for authoritative learning status.  Data is from
        -- checkmate (phoenixffxi/Phoenix source); only shows when the
        -- player is on BLU main OR BLU subjob.
        if (BLU_DB and cfg.show_blu ~= false and mob.name) then
            local showBlu = false;
            do
                local okP, player = pcall(function()
                    return AshitaCore:GetMemoryManager():GetPlayer();
                end);
                if (okP and player) then
                    local okM, mj = pcall(player.GetMainJob, player);
                    local okS, sj = pcall(player.GetSubJob,  player);
                    if ((okM and mj == 16) or (okS and sj == 16)) then
                        showBlu = true;
                    end
                end
            end
            if (showBlu) then
                local b = BLU_DB[mob.name:lower()];
                if (b and b.spells and #b.spells > 0) then
                    for _, s in ipairs(b.spells) do
                        pcall(imgui.TextColored, {0.45, 0.85, 1.0, 1.0},
                              string.format('BLU: %s (Lv.%d) -- /check to verify',
                                            s.name, s.lvl or 0));
                    end
                end
            end
        end

        if (cfg.show_ph) then
            local entry  = PH.lookup(mob.name);
            local isNM   = entry and entry.nm;
            local isPH   = entry and entry.pops and #entry.pops > 0;
            local hexKnown = entry and entry.ph_hex_ids ~= nil;
            local hexHit   = hexKnown and PH.isExactPH(entry, mob.index);

            -- CERTAINTY-ONLY MODE: show the annotation block only when we
            -- know we're looking at something meaningful.
            --   isNM            -> NM itself (cyan)
            --   hexHit          -> user-CONFIRMED PH (green)   /ct learn
            --   in hex_range    -> within user-set widescan group (yellow)   /ct range
            --   retailHexHit    -> scraped retail hex matches on this server (teal)
            -- Everything else is silent -- plain target info only.
            local inRange     = entry and PH.inRange and PH.inRange(entry, mob.index);
            local retailHit   = false;
            if (entry and entry.ph_hex_ids_retail and mob.index) then
                for _, id in ipairs(entry.ph_hex_ids_retail) do
                    if (id == mob.index) then retailHit = true; break; end
                end
            end
            local relevant = entry and (isNM or hexHit or inRange or retailHit);

            if (relevant) then
                -- Compact mode: unverified "likely PH" shows ONE grey line
                -- just naming the NM it might pop + brief location.  Full
                -- block only appears for CONFIRMED hex or NM-direct target.
                local compact = (not isNM) and (not hexHit);

                if (isNM) then
                    pcall(imgui.TextColored, {0.6, 0.9, 1.0, 1.0},
                          '[NM target: ' .. mob.name .. ']');
                    -- Explicit "no placeholder" state so you know to just
                    -- camp timed/world or use the pop item -- no PH to kill.
                    if (not entry.pops or #entry.pops == 0) then
                        pcall(imgui.TextColored, {0.55, 0.55, 0.55, 1.0},
                              'No placeholder -- world / timed / pop-item NM');
                    end
                elseif (hexHit) then
                    pcall(imgui.TextColored, {0.4, 1.0, 0.4, 1.0},
                          '** CONFIRMED PH **');
                    pcall(imgui.TextColored, {1.0, 0.85, 0.3, 1.0},
                          'POPS: ' .. table.concat(entry.pops, ', '));
                elseif (retailHit) then
                    pcall(imgui.TextColored, {0.5, 0.95, 0.95, 1.0},
                          '[retail-hex match -- likely PH on this server]');
                    pcall(imgui.TextColored, {1.0, 0.85, 0.3, 1.0},
                          'POPS: ' .. table.concat(entry.pops, ', '));
                    pcall(imgui.TextColored, {0.65, 0.65, 0.65, 1.0},
                          'tip: /ct learn ' .. (entry.pops[1] or 'NM')
                               .. '  to confirm');
                else
                    -- Compact: one dim line.  Use /ct learn after NM pops.
                    pcall(imgui.TextColored, {0.6, 0.6, 0.6, 1.0},
                          'may pop: ' .. table.concat(entry.pops, ', ')
                          .. (entry.location and ('  @ ' .. entry.location) or ''));
                end

                -- Full block only in non-compact mode
                if (not compact) then
                    if (entry.location) then
                        pcall(imgui.TextColored, {0.75, 0.75, 0.9, 1.0},
                              'Loc: ' .. entry.location);
                    end
                    if (entry.respawn_sec) then
                        pcall(imgui.TextColored, {0.75, 0.9, 0.75, 1.0},
                              'Respawn: ' .. PH.fmtDuration(entry.respawn_sec)
                              .. (entry.window_sec
                                  and ('  Window: ' .. PH.fmtDuration(entry.window_sec))
                                  or ''));
                    end
                    if (entry.conditions) then
                        pcall(imgui.Text, 'Cond: ' .. entry.conditions);
                    end
                    if (entry.notes) then
                        pcall(imgui.TextColored, {0.65, 0.65, 0.65, 1.0},
                              entry.notes);
                    end
                    -- Widescan description from BG-Wiki / FFXIclopedia.
                    -- Server-independent -- works on retail AND era.
                    if (entry.widescan) then
                        pcall(imgui.TextColored, {0.85, 0.75, 1.0, 1.0},
                              'Widescan: ' .. entry.widescan);
                    end

                    local nmName = entry.pops and entry.pops[1] or mob.name;
                    local todSec = ToD and ToD[nmName:lower()];
                    if (todSec and entry.respawn_sec) then
                        local since  = os.time() - todSec;
                        local remain = entry.respawn_sec - since;
                        local color  = (remain <= 0) and {0.4, 1.0, 0.4, 1.0}
                                                     or {1.0, 0.85, 0.3, 1.0};
                        local text   = (remain <= 0)
                            and string.format('ToD: %s ago -- window OPEN', PH.fmtDuration(since))
                            or  string.format('ToD: %s ago -- opens in %s',
                                    PH.fmtDuration(since), PH.fmtDuration(remain));
                        pcall(imgui.TextColored, color, text);
                    end
                end
            end
        end
    end

    pcall(imgui.End);
end

ashita.events.register('d3d_present', 'chhartarget_render', render);

-- ----------------------------------------------------------------------------
-- Commands
-- ----------------------------------------------------------------------------
ashita.events.register('command', 'chhartarget_cmd', function(e)
    local args = e.command:args();
    if (#args == 0) then return; end
    local cmd = args[1]:lower();
    if (cmd ~= '/chhartarget' and cmd ~= '/ct') then return; end
    e.blocked = true;

    local sub = (args[2] or 'help'):lower();
    local function bool(w, cur)
        if (w == 'on')  then return true; end
        if (w == 'off') then return false; end
        return not cur;
    end

    if (sub == 'help' or sub == '?') then
        echo('/ct show | hide | toggle       show/hide HUD');
        echo('/ct hex | full | speed | ph on|off');
        echo('/ct add <phname>=<nmname>     user PH entry');
        echo('/ct learn <NM>                record THIS target as a PH hex');
        echo('/ct range <NM>=<lo>-<hi>      set widescan-group hex range');
        echo('/ct nm <mobname>              lookup DB entry for any mob');
        echo('/ct tod [nmname]              show tracked ToDs (all, or one)');
        echo('/ct tod set <nm>=<min_ago>    manually set a ToD (minutes ago)');
        echo('/ct count                     PH entries loaded');
        echo('/ct dump                      dump current target to chat');
        return;
    end

    -- NM lookup without needing to target it
    if (sub == 'nm') then
        local rest = table.concat(args, ' ', 3);
        if (rest == '') then err('Usage: /ct nm <mob name>'); return; end
        local entry = PH.lookup(rest);
        if (not entry) then
            echo('No DB entry for "' .. rest .. '".');
            return;
        end
        echo(rest .. ':');
        if (entry.nm)       then echo('  [NM target]'); end
        if (entry.pops)     then echo('  Pops: ' .. table.concat(entry.pops, ', ')); end
        if (entry.ph_hex_ids) then
            local ids = {};
            for _, id in ipairs(entry.ph_hex_ids) do ids[#ids+1] = string.format('%X', id); end
            echo('  PH hex IDs: ' .. table.concat(ids, ', '));
        end
        if (entry.location)   then echo('  Loc: ' .. entry.location); end
        if (entry.respawn_sec)then
            echo('  Respawn: ' .. PH.fmtDuration(entry.respawn_sec)
                .. (entry.window_sec and (' (window ' .. PH.fmtDuration(entry.window_sec) .. ')') or ''));
        end
        if (entry.conditions) then echo('  Cond: ' .. entry.conditions); end
        if (entry.notes)      then echo('  Notes: ' .. entry.notes); end
        -- Show any tracked ToD
        local nmName = (entry.nm and rest) or (entry.pops and entry.pops[1]);
        local todSec = nmName and ToD[nmName:lower()];
        if (todSec) then
            local since = os.time() - todSec;
            echo(string.format('  ToD: %s ago', PH.fmtDuration(since)));
            if (entry.respawn_sec) then
                local remain = entry.respawn_sec - since;
                if (remain <= 0) then
                    echo('    -> window OPEN');
                else
                    echo('    -> opens in ' .. PH.fmtDuration(remain));
                end
            end
        end
        return;
    end

    -- /ct learn <NM name>  --  record the hex of the last-targeted mob of
    -- that NM's PH family as the confirmed PH on THIS server.  Writes to
    -- ph_user.lua next to the addon so it survives reloads.
    if (sub == 'learn') then
        local rest = table.concat(args, ' ', 3);
        if (rest == '') then err('Usage: /ct learn <NM name>  (or /ct learn <t>)'); return; end
        -- Resolve <t> / <bt> / <st> to current target name
        if (rest == '<t>' or rest == '<bt>' or rest == '<st>') then
            local idx = getTargetEntity();
            local mob = idx and getMob(idx) or nil;
            if (not mob) then err('No target to resolve ' .. rest); return; end
            rest = mob.name;
            echo('Resolved target: ' .. rest);
        end
        -- Find the DB entry whose pops contain this NM
        local phKey, phEntry;
        local function search()
            -- lookup is name-indexed; we scan via a lookup of the NM too for
            -- the case where the user passes a PH name directly.
            if (PH.lookup(rest)) then
                -- They passed a PH name directly
                phKey   = rest:lower();
                phEntry = PH.lookup(rest);
                return;
            end
            -- Otherwise walk our DB for a pops-match (expose via PH.each)
            if (PH.each) then
                PH.each(function(k, v)
                    if (v.pops) then
                        for _, nm in ipairs(v.pops) do
                            if (nm:lower() == rest:lower()) then
                                phKey = k; phEntry = v; return;
                            end
                        end
                    end
                end);
            end
        end
        search();
        if (not phEntry) then
            err('No DB entry pops "' .. rest .. '". Add the PH first with /ct add.');
            return;
        end
        local hex = lastKilledHex[phKey];
        if (not hex) then
            err('No tracked hex for "' .. phKey .. '" yet. Target one in-game then retry.');
            return;
        end
        phEntry.ph_hex_ids = phEntry.ph_hex_ids or {};
        -- Dedupe
        local present = false;
        for _, id in ipairs(phEntry.ph_hex_ids) do
            if (id == hex) then present = true; break; end
        end
        if (not present) then
            table.insert(phEntry.ph_hex_ids, hex);
        end
        -- Persist to ph_user.lua
        local path = AshitaCore:GetInstallPath()
                     .. 'config/addons/chhartarget/ph_user.lua';
        -- Make sure dir exists
        os.execute('mkdir "' .. (AshitaCore:GetInstallPath()
                                 .. 'config/addons/chhartarget'):gsub('/','\\') .. '" 2>nul');
        local f = io.open(path, 'a');
        if (f) then
            f:write(string.format('PH.learn(%q, 0x%X)   -- NM: %s\n',
                phKey, hex, rest));
            f:close();
            echo(string.format('Learned: %s PH hex = 0x%X (saved to ph_user.lua)',
                phKey, hex));
        else
            err('Could not write ph_user.lua, change kept in-memory only.');
        end
        return;
    end

    -- /ct range <NM>=<lo>-<hi>   OR   /ct range <NM>=<lo> <hi>
    -- Set the widescan-group hex range for an NM's PHs.  Hexes inside
    -- the range show "may pop" (yellow), outside = SILENT.  Persisted
    -- to ph_user.lua.
    if (sub == 'range') then
        local rest = table.concat(args, ' ', 3);
        -- Accept  "NM Name=123-127"  or  "NM Name=123 127"  (space-separated)
        local nm, lo, hi = rest:match('(.+)=([%x]+)[%-%s]+([%x]+)');
        if (not nm) then
            err('Usage: /ct range <NM name>=<low_hex>-<high_hex>');
            err('  e.g. /ct range Jaggedy-Eared Jack=123-127');
            return;
        end
        local loNum = tonumber(lo, 16);
        local hiNum = tonumber(hi, 16);
        if (not loNum or not hiNum) then err('Hex range unparseable'); return; end
        -- Find the DB key: the PH key whose pops contains this NM, OR
        -- a direct PH-name key the user passed.
        local phKey;
        local direct = PH.lookup(nm);
        if (direct) then phKey = nm:lower();
        else
            PH.each(function(k, v)
                if (v.pops) then
                    for _, n in ipairs(v.pops) do
                        if (n:lower() == nm:lower()) then phKey = k; return; end
                    end
                end
            end);
        end
        if (not phKey) then
            err('No DB entry pops "' .. nm .. '". Add it with /ct add first.');
            return;
        end
        if (PH.setRange) then PH.setRange(phKey, loNum, hiNum); end
        -- Persist to ph_user.lua
        local path = AshitaCore:GetInstallPath()
                     .. 'config/addons/chhartarget/ph_user.lua';
        os.execute('mkdir "' .. (AshitaCore:GetInstallPath()
                                 .. 'config/addons/chhartarget'):gsub('/','\\') .. '" 2>nul');
        local f = io.open(path, 'a');
        if (f) then
            f:write(string.format('PH.setRange(%q, 0x%X, 0x%X)   -- NM: %s\n',
                phKey, loNum, hiNum, nm));
            f:close();
            echo(string.format('Range: %s PH hexes 0x%X-0x%X (saved)',
                phKey, loNum, hiNum));
        else
            err('Could not write ph_user.lua, change kept in-memory only.');
        end
        return;
    end

    -- ToD listing / manual set
    if (sub == 'tod') then
        if (args[3] and args[3]:lower() == 'set') then
            local rest = table.concat(args, ' ', 4);
            local nm, minAgo = rest:match('(.+)=(%d+)');
            if (not nm) then err('Usage: /ct tod set <nmname>=<minutes_ago>'); return; end
            ToD[nm:lower()] = os.time() - (tonumber(minAgo) * 60);
            echo('Set ToD: ' .. nm .. ' = ' .. minAgo .. ' min ago');
            return;
        end
        if (args[3]) then
            local key = table.concat(args, ' ', 3):lower();
            local t = ToD[key];
            if (not t) then echo('No ToD recorded for "' .. key .. '"'); return; end
            echo(key .. ' ToD: ' .. PH.fmtDuration(os.time() - t) .. ' ago');
            return;
        end
        -- List all
        local any = false;
        for name, t in pairs(ToD) do
            echo(string.format('%-30s %s ago', name, PH.fmtDuration(os.time() - t)));
            any = true;
        end
        if (not any) then echo('(no ToDs tracked yet)'); end
        return;
    end

    if (sub == 'show')   then cfg.show = true;  echo('shown.');  return; end
    if (sub == 'hide')   then cfg.show = false; echo('hidden.'); return; end
    if (sub == 'toggle') then cfg.show = not cfg.show;
        echo(cfg.show and 'shown.' or 'hidden.'); return; end
    if (sub == 'hex')    then cfg.show_hex   = bool(args[3], cfg.show_hex);
        echo('hex: ' .. tostring(cfg.show_hex)); return; end
    if (sub == 'full')   then cfg.show_full  = bool(args[3], cfg.show_full);
        echo('full: ' .. tostring(cfg.show_full)); return; end
    if (sub == 'speed')  then cfg.show_speed = bool(args[3], cfg.show_speed);
        echo('speed: ' .. tostring(cfg.show_speed)); return; end
    if (sub == 'ph')     then cfg.show_ph    = bool(args[3], cfg.show_ph);
        echo('ph: ' .. tostring(cfg.show_ph)); return; end

    if (sub == 'count') then
        echo('PH entries loaded: ' .. PH.count());
        return;
    end

    if (sub == 'add') then
        -- `/ct add <phname>=<nmname>` -- recombine remaining args
        local rest = table.concat(args, ' ', 3);
        local ph, nm = rest:match('(.+)=(.+)');
        if (not ph or not nm) then
            err('Usage: /ct add <phname>=<nmname>'); return;
        end
        PH.add(ph:gsub('^%s*(.-)%s*$', '%1'), nm:gsub('^%s*(.-)%s*$', '%1'));
        echo(string.format('Added PH: "%s" -> %s', ph, nm));
        return;
    end

    if (sub == 'dump') then
        local idx = getTargetEntity();
        if (not idx) then err('no target (idx=nil)'); return; end
        local mob = getMob(idx);
        if (not mob) then err('no target (getMob failed at idx '..idx..')'); return; end
        echo(string.format('name="%s" id=%d hex=%X status=%s hpp=%d%% speed=%s',
            mob.name, mob.id or 0, mob.index or 0,
            tostring(mob.status), mob.hpp or 0, formatSpeed(mob)));
        local pops = PH.lookup(mob.name);
        if (pops) then
            if (#pops == 0) then echo('(known NM target)');
            else echo('PH for: ' .. table.concat(pops, ', ')); end
        else
            echo('(not in PH database -- /ct add if you have info)');
        end
        return;
    end

    err('Unknown subcommand: ' .. sub .. '  (/ct help)');
end);

ashita.events.register('load', 'chhartarget_load', function()
    echo(string.format('v%s loaded.  PH entries: %d.  /ct help',
        addon.version, PH.count()));
end);
