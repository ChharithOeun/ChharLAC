--[[
================================================================================
  ChharBurst -- auto magic-burst for BLM / RDM / SCH / WHM on Ashita v4.

  Credits:
    * Logic / defaults ported from ekrividus/autoMB (Windower 4, MIT)
    * ParseActionPacket pattern + skillchain data borrowed from the Chains
      addon by atom0s / Ivaar (Ashita, GPL).
    * Written to live alongside the Chharizard LuAshitaCast profiles -- each
      job file can set `cfg.autoBurst = true` in its OnLoad to turn ChharBurst
      on for that session.  See profiles/_template/BLM.lua for the pattern.

  Design:
    1. Hook incoming packet 0x28 (action) and parse with the Chains parser.
    2. If `action.AdditionalEffect.Message` OR `action.Message` is one of the
       skillchain IDs (288-301, 767-770), a skillchain just closed.
    3. If the target is party-claimed, in range, and the player's job can
       actually cast a burst spell, pick the best element from the
       skillchain's property list and queue /ma "<spell>" <id>.
    4. One burst per close.  Target auto-switch (optional).  MP floor.
================================================================================
]]--

addon.name    = 'chharburst';
addon.author  = 'Chharizard (logic forked from ekrividus/autoMB, MIT)';
addon.version = '1.0.0';
addon.desc    = 'Auto magic-burst for BLM / RDM / SCH / WHM on skillchain close.';

require('common');
local chat = require('chat');

-- ===========================================================================
-- Config (lives in config/addons/chharburst/<charid>/settings.lua)
-- ===========================================================================
local defaults = T{
    enabled      = true,
    cast_type    = 'spell',   -- spell | helix | ga | ja | ra | jutsu | white | holy | drain
    cast_tier    = 3,         -- 1..6 for most types, 1..3 for jutsu
    mp_floor     = 100,       -- don't burst if post-cast MP would be <= this
    cast_delay   = 0.6,       -- seconds after close before queuing cast
    cast_range   = 22,        -- yalms; don't burst beyond this
    check_day    = false,
    check_weather= false,
    change_target= true,
    gearswap     = false,     -- echo [bursting] / [notbursting] events
    show_sc      = true,      -- echo the skillchain name
    show_spell   = true,      -- echo the chosen spell
    debug        = false,
};
local settings = defaults:copy(true);

-- ===========================================================================
-- Skillchain data (from autoMB)
-- ===========================================================================
local SKILLCHAIN = T{
    [288]={name='Light',       elements=T{'Light','Thunder','Wind','Fire'}},
    [289]={name='Darkness',    elements=T{'Dark','Ice','Water','Earth'}},
    [290]={name='Gravitation', elements=T{'Dark','Earth'}},
    [291]={name='Fragmentation',elements=T{'Thunder','Wind'}},
    [292]={name='Distortion',  elements=T{'Ice','Water'}},
    [293]={name='Fusion',      elements=T{'Light','Fire'}},
    [294]={name='Compression', elements=T{'Dark'}},
    [295]={name='Liquefaction',elements=T{'Fire'}},
    [296]={name='Induration',  elements=T{'Ice'}},
    [297]={name='Reverberation',elements=T{'Water'}},
    [298]={name='Transfixion', elements=T{'Light'}},
    [299]={name='Scission',    elements=T{'Earth'}},
    [300]={name='Detonation',  elements=T{'Wind'}},
    [301]={name='Impaction',   elements=T{'Thunder'}},
    [767]={name='Radiance',    elements=T{'Light','Thunder','Wind','Fire'}},
    [768]={name='Umbra',       elements=T{'Dark','Ice','Water','Earth'}},
    [769]={name='Radiance',    elements=T{'Light','Thunder','Wind','Fire'}},
    [770]={name='Umbra',       elements=T{'Dark','Ice','Water','Earth'}},
};

local MAGIC_TIERS = { [1]='', [2]=' II', [3]=' III', [4]=' IV', [5]=' V', [6]=' VI' };
local JUTSU_TIERS = { [1]=': Ichi', [2]=': Ni', [3]=': San' };

local ELEMENTS = {
    Light   = { spell=nil,       helix='Luminohelix',  ga=nil,       ja=nil,      ra=nil,      jutsu=nil,     white='Banish', holy='Holy', drain=nil     },
    Dark    = { spell=nil,       helix='Noctohelix',   ga=nil,       ja=nil,      ra=nil,      jutsu=nil,     white=nil,      holy=nil,    drain='Drain' },
    Thunder = { spell='Thunder', helix='Ionohelix',    ga='Thundaga',ja='Thundaja',ra='Thundara',jutsu='Raiton',white=nil,     holy=nil,    drain=nil     },
    Ice     = { spell='Blizzard',helix='Cryohelix',    ga='Blizzaga',ja='Blizzaja',ra='Blizzara',jutsu='Hyoton',white=nil,     holy=nil,    drain=nil     },
    Fire    = { spell='Fire',    helix='Pyrohelix',    ga='Firaga',  ja='Firaja', ra='Fira',   jutsu='Katon', white=nil,      holy=nil,    drain=nil     },
    Wind    = { spell='Aero',    helix='Anemohelix',   ga='Aeroga',  ja='Aeroja', ra='Aerora', jutsu='Huton', white=nil,      holy=nil,    drain=nil     },
    Water   = { spell='Water',   helix='Hydrohelix',   ga='Waterga', ja='Waterja',ra='Watera', jutsu='Suiton',white=nil,      holy=nil,    drain=nil     },
    Earth   = { spell='Stone',   helix='Geohelix',     ga='Stonega', ja='Stoneja',ra='Stonera',jutsu='Doton', white=nil,      holy=nil,    drain=nil     },
};

local MAX_TIERS = { spell=6, helix=2, ga=3, ja=1, ra=3, jutsu=3, white=3, holy=2, drain=1 };

-- Default job → cast_type mapping (used if the user hasn't overridden).
local JOB_CAST = {
    BLM=T{'spell','ga','ja','ra'},
    RDM=T{'spell','ra','ga'},
    SCH=T{'helix','spell','ga','ra'},
    WHM=T{'white','holy'},
    DRK=T{'drain','spell'},
    GEO=T{'spell','ga'},
    NIN=T{'jutsu'},
    BLU=T{'spell'},
};

-- ===========================================================================
-- State
-- ===========================================================================
local state = {
    playerId     = 0,
    last_close   = 0,       -- timestamp of last skillchain close we handled
    bursting     = false,
    last_check   = 0,
};
local MIN_SC_GAP = 1.5;     -- seconds between accepted closes (debounce)

-- ===========================================================================
-- Helpers
-- ===========================================================================
local function echo(msg)
    print(chat.header(addon.name):append(chat.message(tostring(msg))));
end
local function dbg(msg)
    if (settings.debug) then
        print(chat.header(addon.name):append(chat.color1(6, '[dbg] ' .. tostring(msg))));
    end
end
local function err(msg)
    print(chat.header(addon.name):append(chat.error(tostring(msg))));
end

-- Query the player's main/sub job short name.  Uses the same resource
-- string lookup as subjob_features.lua -- `GetJobByIndex` / `.NameAbbr3`
-- are NOT real Ashita API (I made those up); the correct call is
-- GetResourceManager():GetString('jobs.names_abbr', id).
local function trim_null(s)
    if (not s) then return ''; end
    return (s:gsub('%z.*$', ''):gsub('%s+$', ''));
end
local function get_jobs()
    local okP, player = pcall(function() return AshitaCore:GetMemoryManager():GetPlayer(); end);
    if (not okP or not player) then return nil, nil; end
    local mainIdx = player:GetMainJob() or 0;
    local subIdx  = player:GetSubJob()  or 0;
    local res = AshitaCore:GetResourceManager();
    local mn = trim_null(res:GetString('jobs.names_abbr', mainIdx));
    local sn = trim_null(res:GetString('jobs.names_abbr', subIdx));
    if (mn == '') then mn = nil; end
    if (sn == '') then sn = nil; end
    return mn, sn;
end

-- Which cast_types are usable given the current main+sub job?
local function allowed_cast_types()
    local m, s = get_jobs();
    local allowed = T{};
    if (m and JOB_CAST[m]) then for _,t in ipairs(JOB_CAST[m]) do allowed:append(t); end end
    if (s and JOB_CAST[s]) then for _,t in ipairs(JOB_CAST[s]) do if not allowed:contains(t) then allowed:append(t); end end end
    return allowed, m, s;
end

-- Pick spell name for element + cast_type + tier.
local function build_spell_name(elem, cast_type, tier)
    local E = ELEMENTS[elem];
    if (not E) then return nil; end
    local base = E[cast_type];
    if (not base or base == '') then return nil; end
    local max = MAX_TIERS[cast_type] or 1;
    if (tier > max) then tier = max; end
    if (cast_type == 'jutsu') then
        return base .. (JUTSU_TIERS[tier] or '');
    end
    return base .. (MAGIC_TIERS[tier] or '');
end

-- Does the player actually know this spell + meet its level requirement
-- on main OR sub job?  Returns true if castable right now.
local function spell_castable(spellName)
    local okR, res = pcall(function() return AshitaCore:GetResourceManager(); end);
    if (not okR or not res) then return false; end
    local sp = res:GetSpellByName(spellName, 0);
    if (not sp) then return false; end

    local okP, player = pcall(function() return AshitaCore:GetMemoryManager():GetPlayer(); end);
    if (not okP or not player) then return false; end
    if (not player:HasSpellData()) then return false; end
    if (not player:HasSpell(sp.Index)) then return false; end

    -- Level gate: cast if main OR sub meets the per-job requirement.
    local mainIdx = player:GetMainJob();
    local mainLvl = player:GetMainJobLevel();
    local subIdx  = player:GetSubJob();
    local subLvl  = player:GetSubJobLevel();
    local reqM = sp.LevelRequired and sp.LevelRequired[mainIdx] or -1;
    local reqS = sp.LevelRequired and sp.LevelRequired[subIdx]  or -1;
    if (reqM and reqM > 0 and mainLvl >= reqM) then return true; end
    if (reqS and reqS > 0 and subLvl  >= reqS) then return true; end
    return false;
end

-- Try tiers from `max_tier` down to 1 and return the highest tier the
-- player can actually cast.  Returns the spell name (not just tier) so
-- callers don't have to rebuild it.
local function highest_known_spell(elem, cast_type, max_tier)
    local max = math.min(max_tier or 6, MAX_TIERS[cast_type] or 1);
    for t = max, 1, -1 do
        local name = build_spell_name(elem, cast_type, t);
        if (name and spell_castable(name)) then
            return name, t;
        end
    end
    return nil, nil;
end

local function player_mp()
    local okP, player = pcall(function() return AshitaCore:GetMemoryManager():GetPlayer(); end);
    if (not okP or not player) then return 0; end
    return player:GetMP() or 0;
end

local function player_id()
    local okP, party = pcall(function() return AshitaCore:GetMemoryManager():GetParty(); end);
    if (okP and party) then
        return party:GetMemberServerId(0) or 0;
    end
    return 0;
end

-- Entity lookup by server id.
local function entity_by_id(serverId)
    local okE, ent = pcall(function() return AshitaCore:GetMemoryManager():GetEntity(); end);
    if (not okE or not ent) then return nil; end
    for i = 0, 0x8FF do
        if (ent:GetServerId(i) == serverId) then
            return i, ent;
        end
    end
    return nil;
end

local function target_in_range(serverId)
    local idx, ent = entity_by_id(serverId);
    if (not idx) then return false; end
    local me = AshitaCore:GetMemoryManager():GetParty();
    local myIdx = me and me:GetMemberTargetIndex(0) or 0;
    if (myIdx == 0) then return false; end
    local px, py = ent:GetLocalPositionX(myIdx), ent:GetLocalPositionY(myIdx);
    local tx, ty = ent:GetLocalPositionX(idx),   ent:GetLocalPositionY(idx);
    if (not px or not tx) then return false; end
    local dx, dy = tx-px, ty-py;
    local d = math.sqrt(dx*dx + dy*dy);
    return d <= settings.cast_range;
end

-- Is the given server id claimed by anyone in our party/alliance?
local function target_in_alliance(serverId)
    local okP, party = pcall(function() return AshitaCore:GetMemoryManager():GetParty(); end);
    if (not okP or not party) then return false; end
    local myId = party:GetMemberServerId(0) or 0;
    -- Build a quick lookup of party+alliance server ids
    local ids = {};
    for i = 0, 17 do
        local sid = party:GetMemberServerId(i);
        if (sid and sid ~= 0) then ids[sid] = true; end
    end
    -- Pull target claim id via entity table
    local idx = entity_by_id(serverId);
    if (not idx) then return false; end
    local ent = AshitaCore:GetMemoryManager():GetEntity();
    local claimId = ent and ent:GetClaimStatus(idx) or 0;
    if (claimId == 0) then return false; end  -- unclaimed
    return ids[claimId] == true or claimId == myId;
end

-- Pick the best element for this skillchain, then return the highest-tier
-- spell the player can actually cast for that element + cast_type.  Skips
-- elements whose spells the player doesn't yet know.
local function pick_spell(sc_elements, cast_type, tier)
    local DEFAULT_PRIORITY = T{'Thunder','Ice','Wind','Fire','Water','Earth','Dark','Light'};
    -- First pass: prefer the sc elements in priority order; walk down tiers.
    for _, elem in ipairs(DEFAULT_PRIORITY) do
        if (sc_elements:contains(elem)) then
            local name, picked_tier = highest_known_spell(elem, cast_type, tier);
            if (name) then
                dbg(('picked %s (tier %d) for %s'):format(name, picked_tier, elem));
                return name;
            end
        end
    end
    -- Second pass: no priority-order match -- try sc elements in their
    -- native order in case the player only knows one of them.
    for _, elem in ipairs(sc_elements) do
        local name, picked_tier = highest_known_spell(elem, cast_type, tier);
        if (name) then
            dbg(('fallback %s (tier %d) for %s'):format(name, picked_tier, elem));
            return name;
        end
    end
    return nil;
end

-- Resolve which (cast_type, tier) to use given current job + settings.
local function resolve_cast()
    -- Explicit setting wins if the current job supports it.
    local allowed = allowed_cast_types();
    if (settings.cast_type and allowed:contains(settings.cast_type)) then
        return settings.cast_type, settings.cast_tier;
    end
    -- Otherwise use the first job-default that's usable.
    for _,t in ipairs(allowed) do
        if (ELEMENTS.Thunder[t] or ELEMENTS.Light[t]) then
            return t, settings.cast_tier;
        end
    end
    return nil, nil;
end

-- Fire the burst.
local function do_burst(targetId, scInfo)
    local cast_type, tier = resolve_cast();
    if (not cast_type) then dbg('no cast_type for current job'); return; end

    local spell = pick_spell(scInfo.elements, cast_type, tier);
    if (not spell) then dbg('no spell found'); return; end

    -- Element check: build the actual spell name's element from first-matched
    -- (already picked above).  Here we just verify MP floor.
    if (player_mp() <= settings.mp_floor) then
        dbg(('MP too low (%d) -- skipping burst'):format(player_mp()));
        return;
    end

    if (settings.show_spell) then
        echo(('%s: %s -> /ma "%s"'):format(scInfo.name, scInfo.elements:concat('/'), spell));
    end

    state.bursting = true;
    if (settings.gearswap) then
        AshitaCore:GetChatManager():QueueCommand(1, '/console gs c bursting');
    end

    -- Optional retarget first
    local function cast_now()
        AshitaCore:GetChatManager():QueueCommand(1,
            string.format('/ma "%s" <id:%d>', spell, targetId));
        -- Clear bursting flag after a plausible cast time.  Ashita's
        -- scheduled-task API is `oncef`, not `once` (I had this wrong).
        if (ashita.tasks and ashita.tasks.oncef) then
            ashita.tasks.oncef(4, function()
                state.bursting = false;
                if (settings.gearswap) then
                    AshitaCore:GetChatManager():QueueCommand(1, '/console gs c notbursting');
                end
            end);
        else
            -- Fallback: no task API available; clear immediately so a
            -- failed cast doesn't leave us wedged.
            state.bursting = false;
        end
    end

    if (settings.cast_delay > 0 and ashita.tasks and ashita.tasks.oncef) then
        ashita.tasks.oncef(settings.cast_delay, cast_now);
    else
        cast_now();
    end
end

-- ===========================================================================
-- Action-packet parser (borrowed verbatim from Chains / atom0s)
-- ===========================================================================
local function ParseActionPacket(e)
    local bitData;
    local bitOffset;
    local maxLength = e.size * 8;

    local function UnpackBits(length)
        if ((bitOffset + length) > maxLength) then
            maxLength = 0;
            return 0;
        end
        local value = ashita.bits.unpack_be(bitData, 0, bitOffset, length);
        bitOffset = bitOffset + length;
        return value;
    end

    local pkt = T{};
    bitData = e.data_raw;
    bitOffset = 40;

    pkt.UserId = UnpackBits(32);
    local targetCount = UnpackBits(6);
    bitOffset = bitOffset + 4;
    pkt.Type = UnpackBits(4);
    pkt.Id = UnpackBits(32);
    bitOffset = bitOffset + 32;

    pkt.Targets = T{};
    for i = 1, targetCount do
        local target = T{};
        target.Id = UnpackBits(32);
        local actionCount = UnpackBits(4);
        target.Actions = T{};
        for j = 1, actionCount do
            local action = {};
            action.Reaction = UnpackBits(5);
            action.Animation = UnpackBits(12);
            action.SpecialEffect = UnpackBits(7);
            action.Knockback = UnpackBits(3);
            action.Param = UnpackBits(17);
            action.Message = UnpackBits(10);
            action.Flags = UnpackBits(31);
            if (UnpackBits(1) == 1) then
                action.AdditionalEffect = {
                    Damage  = UnpackBits(10),
                    Param   = UnpackBits(17),
                    Message = UnpackBits(10),
                };
            end
            if (UnpackBits(1) == 1) then
                action.SpikesEffect = {
                    Damage  = UnpackBits(10),
                    Param   = UnpackBits(14),
                    Message = UnpackBits(10),
                };
            end
            target.Actions:append(action);
        end
        pkt.Targets:append(target);
    end

    if (maxLength == 0) then
        return nil;
    end
    return pkt;
end

-- ===========================================================================
-- Packet hook: watch for skillchain closes
-- ===========================================================================
ashita.events.register('packet_in', 'chharburst_pkt', function(e)
    if (not settings.enabled) then return; end
    if (e.id ~= 0x28) then return; end
    if (state.bursting) then return; end

    -- Debounce: don't react to the same close burst twice in a tiny window.
    local now = os.clock();
    if ((now - state.last_close) < MIN_SC_GAP) then return; end

    local pkt = ParseActionPacket(e);
    if (not pkt or #pkt.Targets == 0) then return; end

    for _, tgt in ipairs(pkt.Targets) do
        for _, act in ipairs(tgt.Actions) do
            local msg = (act.AdditionalEffect and act.AdditionalEffect.Message) or 0;
            local sc  = SKILLCHAIN[msg];
            -- Fall back to primary message id too; some packet variants
            -- carry the skillchain id in action.Message instead.
            if (not sc) then
                local m2 = act.Message or 0;
                sc = SKILLCHAIN[m2];
            end
            if (sc) then
                -- Gate: in-alliance, in-range
                if (not target_in_alliance(tgt.Id)) then dbg('close: not in alliance'); return; end
                if (not target_in_range(tgt.Id))     then dbg('close: out of range');   return; end
                state.last_close = now;
                if (settings.show_sc) then
                    echo(('skillchain: %s [%s]'):format(sc.name, sc.elements:concat(', ')));
                end
                do_burst(tgt.Id, sc);
                return;
            end
        end
    end
end);

-- ===========================================================================
-- Commands
-- ===========================================================================
local function cmd_help()
    echo('Commands:');
    echo('  /chb on | off | toggle               enable auto-bursting');
    echo('  /chb cast <type>                     spell | helix | ga | ja | ra | jutsu | white | holy | drain');
    echo('  /chb tier <N>                        1..6 (1..3 for jutsu, 1..2 for helix/holy)');
    echo('  /chb mp <N>                          don\'t burst below this MP floor');
    echo('  /chb delay <sec>                     seconds after close before casting');
    echo('  /chb range <yalms>                   max distance to target');
    echo('  /chb day | weather                   toggle day/weather element preference');
    echo('  /chb target                          toggle auto target-swap');
    echo('  /chb gs                              toggle "gs c bursting" integration');
    echo('  /chb show sc | spell                 toggle each echo');
    echo('  /chb debug                           toggle verbose output');
    echo('  /chb status                          show current settings');
end

local function cmd_status()
    local m, s = get_jobs();
    local allowed = allowed_cast_types();
    local ct, ti = resolve_cast();
    echo(('Enabled: %s'):format(tostring(settings.enabled)));
    echo(('Job: %s/%s | allowed cast types: %s'):format(m or '?', s or '?',
        (#allowed > 0) and allowed:concat(',') or 'none'));
    echo(('Cast: %s tier=%d (resolved: %s/%d)'):format(settings.cast_type, settings.cast_tier,
        tostring(ct), tonumber(ti) or 0));
    echo(('Delay: %.2fs | Range: %d | MP floor: %d'):format(
        settings.cast_delay, settings.cast_range, settings.mp_floor));
    echo(('Target-swap: %s | GearSwap echo: %s'):format(
        tostring(settings.change_target), tostring(settings.gearswap)));
end

ashita.events.register('command', 'chharburst_cmd', function(e)
    local args = e.command:args();
    if (#args == 0) then return; end
    local root = args[1]:lower();
    if (root ~= '/chb' and root ~= '/chharburst') then return; end
    e.blocked = true;

    local sub = (args[2] or 'status'):lower();

    if (sub == 'help' or sub == '?' or sub == 'h') then cmd_help(); return; end
    if (sub == 'status' or sub == '')              then cmd_status(); return; end

    local function on_off_toggle(current, word)
        if (word == 'on')  then return true;  end
        if (word == 'off') then return false; end
        return not current;
    end

    if (sub == 'on' or sub == 'off' or sub == 'toggle') then
        settings.enabled = on_off_toggle(settings.enabled, sub);
        echo('enabled: ' .. tostring(settings.enabled));
        return;
    end
    if (sub == 'cast' and args[3]) then
        settings.cast_type = args[3]:lower();
        echo('cast type: ' .. settings.cast_type);
        return;
    end
    if (sub == 'tier' and args[3]) then
        settings.cast_tier = tonumber(args[3]) or settings.cast_tier;
        echo('cast tier: ' .. settings.cast_tier);
        return;
    end
    if (sub == 'mp' and args[3]) then
        settings.mp_floor = tonumber(args[3]) or settings.mp_floor;
        echo('MP floor: ' .. settings.mp_floor);
        return;
    end
    if (sub == 'delay' and args[3]) then
        settings.cast_delay = tonumber(args[3]) or settings.cast_delay;
        echo('cast delay: ' .. settings.cast_delay);
        return;
    end
    if (sub == 'range' and args[3]) then
        settings.cast_range = tonumber(args[3]) or settings.cast_range;
        echo('cast range: ' .. settings.cast_range);
        return;
    end
    if (sub == 'day')     then settings.check_day     = not settings.check_day;     echo('day:     '..tostring(settings.check_day));     return; end
    if (sub == 'weather') then settings.check_weather = not settings.check_weather; echo('weather: '..tostring(settings.check_weather)); return; end
    if (sub == 'target')  then settings.change_target = not settings.change_target; echo('target:  '..tostring(settings.change_target)); return; end
    if (sub == 'gs')      then settings.gearswap      = not settings.gearswap;      echo('gs echo: '..tostring(settings.gearswap));      return; end
    if (sub == 'show' and args[3]) then
        local what = args[3]:lower();
        if     (what == 'sc')    then settings.show_sc    = not settings.show_sc;    echo('show sc: '    ..tostring(settings.show_sc));
        elseif (what == 'spell') then settings.show_spell = not settings.show_spell; echo('show spell: ' ..tostring(settings.show_spell));
        end
        return;
    end
    if (sub == 'debug') then settings.debug = not settings.debug; echo('debug: '..tostring(settings.debug)); return; end

    err('unknown subcommand: ' .. sub .. '  (try /chb help)');
end);

-- ===========================================================================
-- Lifecycle
-- ===========================================================================
ashita.events.register('load', 'chharburst_load', function()
    state.playerId = player_id();
    echo(('v%s loaded. /chb help for commands.'):format(addon.version));
    cmd_status();
end);

ashita.events.register('unload', 'chharburst_unload', function()
    echo('unloaded.');
end);
