--[[
ChharControl -- an Ashita v4 sidecart for ChharLAC's PUP profile.

Holds named automaton attachment sets (blm, whm, rdm, tank, turtle, meva,
rng, rngtank, lvl60) that match the maneuver presets baked into PUP.lua.
Loaded/unloaded automatically by PUP.lua's OnLoad/OnUnload hooks.

Credits: inspired by autocontrol (Nitrous/Nifim/Ricky Gall, 2013-2020).
This is a native Ashita v4 reimplementation of the per-preset attachment-set
workflow -- not a port of the original Windower code.

Attachment-swap mechanics in Ashita v4:
  * The game does not expose /attach as a client command, so ChharControl v1
    ECHOES the attachment list for the active preset instead of swapping them
    automatically. Open Pet Commands > Change Attachments (out of combat) and
    equip from the list in the chat log.
  * Full packet-driven auto-equip is on the roadmap -- it needs 0x102 packet
    construction and server-side acceptance which varies between retail/era.

Commands (prefix: /cc or /chharcontrol):
  /cc preset <name>         Set active preset (also called by PUP.lua)
  /cc preset                Show current preset + list
  /cc equipset <name>       Alias: set preset + echo attachment list to equip
  /cc list                  List all defined presets
  /cc show <name>           Print the attachment list for <name>
  /cc save <name>           Save currently-equipped attachments as <name>
  /cc current               Print the automaton's currently-equipped set
  /cc delete <name>         Remove a saved preset
  /cc help                  Show help
]]--

addon.name     = 'chharcontrol';
addon.author   = 'Chharizard';
addon.version  = '1.0.0';
addon.desc     = 'Named automaton attachment sets, sidecart to ChharLAC PUP.';
addon.commands = { '/chharcontrol', '/cc' };

require('common');
local chat = require('chat');

-- ----------------------------------------------------------------------------
-- Settings persistence (own-rolled, no dep on Ashita's settings lib which
-- varies in signature between Ashita versions).  We write a plain Lua file
-- next to the addon containing a `return { ... }` so loading is just dofile.
-- ----------------------------------------------------------------------------
local function new_slot() return { head = '', frame = '', attachments = {} }; end

local default_settings = {
    active_preset = 'tank',
    presets = {
        blm     = new_slot(),
        whm     = new_slot(),
        rdm     = new_slot(),
        tank    = new_slot(),
        turtle  = new_slot(),
        meva    = new_slot(),
        rng     = new_slot(),
        rngtank = new_slot(),
        lvl60   = new_slot(),
    },
};

-- Serialize a Lua table (strings/numbers/bools/nested tables only) back to a
-- parseable source string.  Good enough for our settings shape.
local function serialize(v, indent)
    indent = indent or '';
    local t = type(v);
    if (t == 'nil') then return 'nil'; end
    if (t == 'boolean' or t == 'number') then return tostring(v); end
    if (t == 'string') then return string.format('%q', v); end
    if (t == 'table') then
        local lines = { '{' };
        local pad = indent .. '  ';
        -- array first
        local n = #v;
        for i = 1, n do
            lines[#lines+1] = pad .. serialize(v[i], pad) .. ',';
        end
        -- then hash keys (skip numeric indices up to n)
        for k, val in pairs(v) do
            if (not (type(k) == 'number' and k >= 1 and k <= n and k == math.floor(k))) then
                local key = (type(k) == 'string' and k:match('^[%a_][%w_]*$'))
                    and k or ('[' .. serialize(k) .. ']');
                lines[#lines+1] = pad .. key .. ' = ' .. serialize(val, pad) .. ',';
            end
        end
        lines[#lines+1] = indent .. '}';
        return table.concat(lines, '\n');
    end
    return 'nil';
end

local function settings_path()
    return AshitaCore:GetInstallPath()
        .. 'config/addons/chharcontrol/settings.lua';
end

local function ensure_dir()
    local dir = AshitaCore:GetInstallPath() .. 'config/addons/chharcontrol';
    -- Try to create; fail silently if it already exists.
    os.execute('mkdir "' .. dir:gsub('/', '\\') .. '" 2>nul');
end

local function load_config()
    local path = settings_path();
    local f = io.open(path, 'r');
    if (not f) then return default_settings; end
    f:close();
    local ok, loaded = pcall(dofile, path);
    if (ok and type(loaded) == 'table') then
        -- Merge: start from defaults, overlay loaded
        for k, v in pairs(loaded) do default_settings[k] = v; end
        if (not default_settings.presets) then
            default_settings.presets = {};
        end
        -- Make sure every known preset slot exists even if the file is older
        local known = {'blm','whm','rdm','tank','turtle','meva','rng','rngtank','lvl60'};
        for _, name in ipairs(known) do
            if (not default_settings.presets[name]) then
                default_settings.presets[name] = new_slot();
            end
        end
    end
    return default_settings;
end

local function save_config()
    ensure_dir();
    local path = settings_path();
    local f, err = io.open(path, 'w');
    if (not f) then
        print(chat.header('ChharControl') .. chat.error('Save failed: ' .. tostring(err)));
        return;
    end
    f:write('-- ChharControl settings -- auto-generated, safe to edit\n');
    f:write('return ' .. serialize(default_settings) .. '\n');
    f:close();
end

local config = load_config();

-- Preset descriptions (match PUP.lua).
local preset_desc = {
    blm     = 'Spiritreaver + Stormwaker  -- ice/ice/dark',
    whm     = 'Soulsoother  + Stormwaker  -- water/light/dark',
    rdm     = 'Stormwaker   + Stormwaker  -- dark/water/ice',
    tank    = 'Valoredge    + Valoredge   -- earth/fire/light + Dark @ WS',
    turtle  = 'Soulsoother  + Valoredge   -- light/water/earth + Fire on Strobe',
    meva    = 'Soulsoother  + Harlequin   -- light/water/dark',
    rng     = 'Sharpshot    + Sharpshot   -- wind/wind/fire + Thunder @ WS',
    rngtank = 'Valoredge    + Sharpshot   -- light/fire/wind + Thunder @ WS',
    lvl60   = 'Valoredge    + Valoredge   -- light/water/thunder + Dark @ WS (BCNM)',
};
local PRESET_NAMES = { 'blm','whm','rdm','tank','turtle','meva','rng','rngtank','lvl60' };

-- ----------------------------------------------------------------------------
-- Helpers
-- ----------------------------------------------------------------------------
local function echo(msg)
    print(chat.header('ChharControl') .. chat.message(msg));
end

local function err(msg)
    print(chat.header('ChharControl') .. chat.error(msg));
end

local function is_pup()
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (player == nil) then return false; end
    return player:GetMainJob() == 18;
end

-- Read the currently-equipped automaton attachments from pet memory.
-- Returns a table { head='', frame='', attachments={...} } with resolved names.
local function read_current_set()
    local mm   = AshitaCore:GetMemoryManager();
    local pet  = mm:GetPlayer();
    if (not pet) then return nil; end

    -- Pet attachments live under Player->Automaton* accessors in Ashita v4.
    local head_id  = (pet.GetAutomatonHead  and pet:GetAutomatonHead())  or 0;
    local frame_id = (pet.GetAutomatonFrame and pet:GetAutomatonFrame()) or 0;

    local function att_name(id)
        if (id == 0 or id == nil) then return ''; end
        local item = AshitaCore:GetResourceManager():GetItemById(id);
        return (item and item.Name and item.Name[1]) or ('ID:' .. tostring(id));
    end

    local set = {
        head        = att_name(head_id),
        frame       = att_name(frame_id),
        attachments = {},
    };
    for i = 1, 12 do
        local getter = pet['GetAutomatonAttachment' .. i];
        local id = getter and getter(pet) or 0;
        if (id and id > 0) then
            set.attachments[#set.attachments + 1] = att_name(id);
        end
    end
    return set;
end

-- Pretty-print a preset to chat.
local function print_set(name, s)
    if (not s) then
        err('Preset "' .. name .. '" is empty.');
        return;
    end
    echo(string.format('%s  [%s + %s]', name,
        s.head ~= '' and s.head or '(none)',
        s.frame ~= '' and s.frame or '(none)'));
    if (preset_desc[name]) then
        echo('  ' .. preset_desc[name]);
    end
    if (#s.attachments == 0) then
        echo('  (no attachments saved yet -- open Pet Commands > Change Attachments,');
        echo('   equip the set you want, then run /cc save ' .. name .. ')');
        return;
    end
    for i, att in ipairs(s.attachments) do
        echo(string.format('  %2d. %s', i, att));
    end
end

local function set_active_preset(name)
    if (not config.presets[name]) then
        err('Unknown preset: ' .. name);
        err('Known: ' .. table.concat(PRESET_NAMES, ', '));
        return false;
    end
    config.active_preset = name;
    save_config();
    return true;
end

-- ----------------------------------------------------------------------------
-- Command handler
-- ----------------------------------------------------------------------------
ashita.events.register('command', 'chharcontrol_cmd', function(e)
    local args = e.command:args();
    if (#args == 0) then return; end
    local cmd = args[1]:lower();
    if (cmd ~= '/chharcontrol' and cmd ~= '/cc') then return; end

    e.blocked = true;
    local sub = (args[2] or 'help'):lower();

    -- Help ---------------------------------------------------------------
    if (sub == 'help' or sub == '?') then
        echo('/cc preset <name>     -- set active preset (' .. table.concat(PRESET_NAMES, '|') .. ')');
        echo('/cc preset            -- show current + list descriptions');
        echo('/cc equipset <name>   -- set preset + echo attachment list');
        echo('/cc list              -- list all defined presets');
        echo('/cc show <name>       -- print the attachment list for <name>');
        echo('/cc save <name>       -- save CURRENTLY equipped as <name>');
        echo('/cc current           -- print currently equipped on automaton');
        echo('/cc delete <name>     -- erase a saved preset (resets to empty)');
        return;
    end

    -- Preset -------------------------------------------------------------
    if (sub == 'preset') then
        if (not args[3]) then
            echo('Active preset: ' .. (config.active_preset or '(none)'));
            echo('Available:');
            for _, n in ipairs(PRESET_NAMES) do
                local s = config.presets[n];
                local saved = (s and (s.head ~= '' or #s.attachments > 0)) and '*' or ' ';
                echo(string.format('  %s %-8s -- %s', saved, n, preset_desc[n] or ''));
            end
            echo('  (* = user-saved content.  blanks need /cc save <name> to populate)');
            return;
        end
        local name = args[3]:lower();
        if (set_active_preset(name)) then
            echo('Active preset: ' .. name .. '  (' .. (preset_desc[name] or '') .. ')');
            print_set(name, config.presets[name]);
        end
        return;
    end

    -- Equipset (alias: set preset + print attachments to equip) ----------
    if (sub == 'equipset' or sub == 'equip' or sub == 'e') then
        if (not args[3]) then err('/cc equipset <name>'); return; end
        local name = args[3]:lower();
        if (not set_active_preset(name)) then return; end
        local s = config.presets[name];
        if (not s or (s.head == '' and #s.attachments == 0)) then
            echo('Preset "' .. name .. '" has nothing saved yet.');
            echo('Open Pet Commands > Change Attachments, equip the set,');
            echo('then run: /cc save ' .. name);
            return;
        end
        echo('Equip this set at the automaton NPC:');
        print_set(name, s);
        -- Future: auto-detach + attach loop here once packet injection is in.
        return;
    end

    -- List ---------------------------------------------------------------
    if (sub == 'list' or sub == 'setlist') then
        echo('Preset slots:');
        for _, n in ipairs(PRESET_NAMES) do
            local s = config.presets[n];
            local tag = (s and (s.head ~= '' or #s.attachments > 0))
                and string.format('[%s + %s, %d atts]', s.head, s.frame, #s.attachments)
                or '[empty]';
            echo(string.format('  %-8s %s', n, tag));
        end
        return;
    end

    -- Show <name> --------------------------------------------------------
    if (sub == 'show' or sub == 'attlist') then
        local name = (args[3] or config.active_preset):lower();
        print_set(name, config.presets[name]);
        return;
    end

    -- Save <name> --------------------------------------------------------
    if (sub == 'save' or sub == 'saveset') then
        if (not is_pup()) then err('Must be on PUP (main job) to save.'); return; end
        if (not args[3]) then err('/cc save <name>'); return; end
        local name = args[3]:lower();
        if (not config.presets[name]) then
            err('Unknown preset slot: ' .. name
             .. '  (known: ' .. table.concat(PRESET_NAMES, ', ') .. ')');
            return;
        end
        local s = read_current_set();
        if (not s) then err('Could not read automaton equipment.'); return; end
        config.presets[name] = s;
        save_config();
        echo('Saved current automaton setup as "' .. name .. '":');
        print_set(name, s);
        return;
    end

    -- Current ------------------------------------------------------------
    if (sub == 'current' or sub == 'cur') then
        if (not is_pup()) then err('Must be on PUP to read automaton.'); return; end
        local s = read_current_set();
        if (not s) then err('Could not read automaton equipment.'); return; end
        echo('Currently equipped on automaton:');
        print_set('(current)', s);
        return;
    end

    -- Delete -------------------------------------------------------------
    if (sub == 'delete' or sub == 'del' or sub == 'clear') then
        if (not args[3]) then err('/cc delete <name>'); return; end
        local name = args[3]:lower();
        if (not config.presets[name]) then err('Unknown preset: ' .. name); return; end
        config.presets[name] = new_slot();
        save_config();
        echo('Cleared preset "' .. name .. '".');
        return;
    end

    err('Unknown subcommand: ' .. sub .. '  (/cc help for list)');
end);

-- ----------------------------------------------------------------------------
-- Settings reload hook (own-rolled; nothing to re-register)
-- ----------------------------------------------------------------------------

-- ----------------------------------------------------------------------------
-- Load / unload echo
-- ----------------------------------------------------------------------------
ashita.events.register('load', 'chharcontrol_load', function()
    echo('v' .. addon.version .. ' loaded.  Active preset: '
      .. (config.active_preset or '(none)')
      .. '  --  /cc help');
end);

ashita.events.register('unload', 'chharcontrol_unload', function()
    save_config();
end);
