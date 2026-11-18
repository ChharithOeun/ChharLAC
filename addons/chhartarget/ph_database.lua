--[[
ChharTarget -- PH / NM database.

Each entry carries rich metadata (see ChharTarget README for schema):
    pops, ph_hex_ids, ph_hex_ids_retail, location, respawn_sec,
    window_sec, conditions, widescan, notes, nm (bool).

Hex-ID matching tiers:
    ph_hex_ids         -- confirmed PH on THIS server (user-learned or auto-learned)
    ph_hex_ids_retail  -- what BG-Wiki says; shown as "retail-match" tier,
                          since many era servers preserve retail IDs (LSB-based)

Verified data below cross-referenced BG-Wiki + FFXIclopedia during build.
To add more without manual editing, run WIKI-SCRAPE.ps1 on your Windows side.
]]--

local PH = {}

-- ============================================================================
-- CLASSIC CAMP LOTTERIES (verified BG-Wiki + FFXIclopedia)
-- ============================================================================

-- NOTE on timers:
--   PH entries use respawn_sec = NORMAL MOB RESPAWN (5 min standard; Yagudo
--   can be 12 min; etc).  That's how long until the PH mob you killed
--   comes back, with another chance to roll into the NM.
--   NM entries use respawn_sec = NM-WINDOW-OPENS-AT (minimum time after
--   NM's ToD before it CAN pop again).  window_sec = length of that window.

PH['rock lizard'] = {
    pops              = { 'Leaping Lizzy' },
    ph_hex_ids_retail = { 0x17B },
    location          = 'South Gustaberg (E-8)/(F-8), rock pillar at F-8',
    respawn_sec       = 300,            -- 5 min PH mob respawn
    conditions        = 'Lottery; kill PH only, do not clear the whole group',
    widescan          = 'first group of five Rock Lizards. The bottom lizard is the placeholder',
    notes             = 'Lizzy hex = 0x17C; two possible spawn spots on widescan',
};

PH['damselfly'] = {
    pops              = { 'Valkurm Emperor' },
    ph_hex_ids_retail = { 0x14A },
    location          = 'Valkurm Dunes (E-8/9)/(F-8/9)',
    respawn_sec       = 300,            -- 5 min PH mob respawn
    conditions        = 'Lottery; standard 5 min respawn',
    widescan          = 'Damselfly group of 4 between Snippers and Thread Leeches, half way down the list',
    notes             = 'Emperor hex = 0x14E',
};

PH['forest hare'] = {
    pops              = { 'Jaggedy-Eared Jack' },
    ph_hex_ids_retail = { 0x126 },
    location          = 'West Ronfaure (G-9)/(H-9)',
    respawn_sec       = 300,            -- 5 min standard mob respawn
    conditions        = 'Lottery',
    widescan          = '3rd Forest Hare in bottom group of 3 (near G/H-9 border); above a Carrion Worm',
    notes             = 'At night, Enchanted Bones appear above the hare group in widescan',
};

-- ============================================================================
-- RoZ / MID-LEVEL CAMP LOTTERIES (verified BG-Wiki + FFXIclopedia)
-- ============================================================================

PH['yagudo drummer'] = {
    pops              = { 'Mee Deggi the Punisher' },
    location          = 'Castle Oztroja (H-8)/(I-8), ground floor N courtyard, Map 7',
    respawn_sec       = 720,            -- 12 min (Yagudo have long respawn)
    conditions        = 'Lottery; either Drummer OR Interrogator rolls for Mee Deggi',
    widescan          = 'between Yagudo Elemental and Yagudo Zealot (below Mee Deggi in widescan)',
};
PH['yagudo interrogator'] = {
    pops              = { 'Mee Deggi the Punisher' },
    location          = 'Castle Oztroja (H-8)/(I-8), ground floor N courtyard, Map 7',
    respawn_sec       = 720,            -- 12 min
    conditions        = 'Lottery; alternate PH for Mee Deggi',
};

PH['flying manta'] = {
    pops              = { 'Lord of Onzozo' },
    location          = 'Labyrinth of Onzozo (H-8), single Flying Manta',
    respawn_sec       = 300,            -- 5 min standard respawn
    conditions        = 'Lottery; PH rages ~10 min after spawn, consider sleeping',
    notes             = 'Only one Flying Manta in zone -- the hex IS the real PH',
};

PH['snipper'] = {
    pops              = { 'Hurkan' },
    location          = 'Qufim Island',
    respawn_sec       = 300,            -- 5 min standard
    conditions        = 'Lottery',
};

PH['stroper'] = {
    pops              = { 'Mindseeker' },
    location          = 'Yuhtunga Jungle',
    respawn_sec       = 300,            -- 5 min standard
    conditions        = 'Lottery',
};

-- ============================================================================
-- KNOWN NM TARGETS (world spawn / timed / pop-item -- no PH)
-- Shown as cyan [NM target: X] when you have one targeted.  ToD countdown
-- works on these too, using the user-set respawn_sec as the window.
-- ============================================================================

-- Timed-spawn mid-tier NMs
PH['argus'] = {
    pops=nil, nm=true,
    location='Maze of Shakhrami (K-8)/(J-9), small room through J-8 hallway',
    respawn_sec=3600, window_sec=3600,
    conditions='Timed spawn 1-2 hr window; alternates with Leech King (one or the other)',
};
PH['leech king'] = {
    pops=nil, nm=true,
    location='Maze of Shakhrami',
    respawn_sec=3600, window_sec=3600,
    conditions='Timed; alternates with Argus',
};
PH['steelfleece baldarich'] = {
    pops=nil, nm=true,
    location='Konschtat Highlands (H-6) to (I-8), W of Crag of Dem',
    respawn_sec=75600, window_sec=10800,
    conditions='Timed 21-24 hr; often pops ~30min before/after Rampaging Ram',
};
PH['rampaging ram'] = {
    pops=nil, nm=true,
    location='Konschtat Highlands',
    respawn_sec=75600,
    conditions='Timed; shares area with Steelfleece Baldarich',
};

-- Ground kings / HNMs
PH['king behemoth']   = { pops=nil, nm=true, respawn_sec=75600, window_sec=10800,
    location='Behemoth\'s Dominion', conditions='21 hr window after ToD; cutscene spawn' };
PH['behemoth']        = { pops=nil, nm=true, respawn_sec=75600, window_sec=10800,
    location='Behemoth\'s Dominion' };
PH['nidhogg']         = { pops=nil, nm=true, respawn_sec=75600, window_sec=36000,
    location='Dragon\'s Aery', conditions='Shares spawn with Fafnir (random pick)' };
PH['fafnir']          = { pops=nil, nm=true, respawn_sec=75600, window_sec=36000,
    location='Dragon\'s Aery', conditions='Shares spawn with Nidhogg (random pick)' };
PH['adamantoise']     = { pops=nil, nm=true, respawn_sec=75600,
    location='Qufim Island', conditions='Timed ground spawn' };
PH['aspidochelone']   = { pops=nil, nm=true, respawn_sec=75600,
    location='Cape Teriggan' };
PH['serket']          = { pops=nil, nm=true, respawn_sec=75600,
    location='Palborough Mines', conditions='Timed ground spawn' };
PH['king vinegarroon']= { pops=nil, nm=true, respawn_sec=75600,
    location='Western Altepa Desert' };
PH['simurgh']         = { pops=nil, nm=true, respawn_sec=75600,
    location='Western Altepa Desert' };
PH['charybdis']       = { pops=nil, nm=true, respawn_sec=75600,
    location='Open sea / Sea Serpent Grotto' };
PH['lord of onzozo']  = { pops=nil, nm=true, respawn_sec=57600, window_sec=28800,
    location='Labyrinth of Onzozo (H-8)',
    conditions='Lottery off Flying Manta; 16-24+ hr window' };
PH['faust']           = { pops=nil, nm=true, respawn_sec=10800,
    location='Garlaige Citadel', conditions='Timed; see BG-Wiki for pop conditions' };

-- Famous starter / mid-tier NMs -- named entries so when you target the NM
-- directly you get its spawn-window info.  respawn_sec = NM-WINDOW-OPENS-AT.
PH['leaping lizzy']   = { pops=nil, nm=true, respawn_sec=300, window_sec=14100,
    location='South Gustaberg (E-8)/(F-8)',
    conditions='Lottery off Rock Lizard; 5min-4hr NM window' };
PH['valkurm emperor'] = { pops=nil, nm=true, respawn_sec=900,
    location='Valkurm Dunes (E-8/9)/(F-8/9)',
    conditions='Lottery off Damselfly; 15min min NM window after ToD' };
PH['jaggedy-eared jack']= { pops=nil, nm=true, respawn_sec=3000, window_sec=3600,
    location='West Ronfaure (G-9)/(H-9)',
    conditions='Lottery off Forest Hare; 50min min NM window after ToD' };
PH['mee deggi the punisher']={ pops=nil, nm=true, respawn_sec=3000, window_sec=18600,
    location='Castle Oztroja (H-8)/(I-8)',
    conditions='Lottery off Drummer/Interrogator; 50min-6hr NM window' };
PH['hurkan']          = { pops=nil, nm=true, respawn_sec=3600,
    location='Qufim Island',
    conditions='Lottery off Snipper' };
PH['mindseeker']      = { pops=nil, nm=true, respawn_sec=3600,
    location='Yuhtunga Jungle',
    conditions='Lottery off Stroper' };

-- ============================================================================
-- Public API
-- ============================================================================

local M = {}

function M.lookup(mobName)
    if (not mobName or mobName == '') then return nil; end
    return PH[mobName:lower()];
end

function M.count()
    local n = 0;
    for _ in pairs(PH) do n = n + 1; end
    return n;
end

function M.isExactPH(entry, hexIndex)
    if (not entry or not entry.ph_hex_ids or not hexIndex) then return false; end
    for _, id in ipairs(entry.ph_hex_ids) do
        if (id == hexIndex) then return true; end
    end
    return false;
end

function M.fmtDuration(sec)
    if (not sec or sec <= 0) then return '-'; end
    local h = math.floor(sec / 3600);
    local m = math.floor((sec % 3600) / 60);
    local s = sec % 60;
    if (h > 0) then return string.format('%dh %02dm', h, m); end
    if (m > 0) then return string.format('%dm %02ds', m, s); end
    return s .. 's';
end

function M.add(phName, nmName)
    if (not phName or not nmName) then return; end
    local key = phName:lower();
    PH[key] = PH[key] or { pops = {} };
    PH[key].pops = PH[key].pops or {};
    table.insert(PH[key].pops, nmName);
end

function M.learn(phKey, hexId)
    if (not phKey or not hexId) then return; end
    local k = phKey:lower();
    PH[k] = PH[k] or { pops = {} };
    PH[k].ph_hex_ids = PH[k].ph_hex_ids or {};
    for _, id in ipairs(PH[k].ph_hex_ids) do
        if (id == hexId) then return; end
    end
    table.insert(PH[k].ph_hex_ids, hexId);
end

function M.setRange(phKey, lo, hi)
    if (not phKey or not lo or not hi) then return; end
    local k = phKey:lower();
    PH[k] = PH[k] or { pops = {} };
    PH[k].hex_range = { lo, hi };
end

function M.inRange(entry, hex)
    if (not entry or not entry.hex_range or not hex) then return false; end
    return hex >= entry.hex_range[1] and hex <= entry.hex_range[2];
end

function M.each(fn)
    for k, v in pairs(PH) do fn(k, v); end
end

-- Overlay zone + mob_ids from checkmate's Phoenix-authoritative data.
-- Rules:
--   * Existing PH entries keep their user-authored fields (pops, hex ids,
--     location, notes, widescan, etc).  We only ADD zone + mob_ids +
--     checkmate_name when they're missing.
--   * NMs that exist in checkmate but not in PH{} get a stub entry so
--     ChharTarget at least knows their zone.  These stubs set `nm=true`
--     so the kill-handler's PH-echo gate doesn't fire on them.
-- The merge is pure data overlay -- always safe to re-run and never
-- stomps anything you've typed by hand.
local okCk, CK = pcall(require, 'ph_from_checkmate');
if (okCk and type(CK) == 'table') then
    for key, ckEntry in pairs(CK) do
        if (type(ckEntry) == 'table') then
            local existing = PH[key];
            if (existing) then
                existing.zone     = existing.zone     or ckEntry.zone;
                existing.mob_ids  = existing.mob_ids  or ckEntry.mob_ids;
                existing.checkmate_name = ckEntry.name;
                existing.spawn    = existing.spawn    or ckEntry.spawn;
                existing.claim    = existing.claim    or ckEntry.claim;
            else
                -- Stub: NM-level record, no PH pop list yet.  Tag as nm
                -- so kill-handler PH gate skips it (ToD still works on direct NM kills).
                PH[key] = {
                    nm       = true,
                    zone     = ckEntry.zone,
                    mob_ids  = ckEntry.mob_ids,
                    spawn    = ckEntry.spawn,
                    claim    = ckEntry.claim,
                    checkmate_name = ckEntry.name,
                };
            end
        end
    end
end

-- Overlay auto-inferred PH -> NM relationships from checkmate.
-- Rule: same zone + same family as a Lottery NM + mob_id within +/- 8
-- of the NM's mob_id.  This covers the standard FFXI lottery layout
-- (PH mobs grouped immediately before the NM's id slot).
--
-- Merge policy (safe):
--   * User-authored `pops` is preserved verbatim; checkmate pops only
--     fill when the PH entry has none.
--   * User-authored `ph_hex_ids` / `hex_range` win over checkmate.
--     Checkmate's `mob_ids_inferred` becomes a NEW `hex_range` only
--     when the user has not supplied either, so the hex-gate still
--     fires at camp.
--   * `zone` is copied in when missing.
local okPhs, PHS = pcall(require, 'phs_from_checkmate');
if (okPhs and type(PHS) == 'table') then
    for key, inf in pairs(PHS) do
        if (type(inf) == 'table') then
            local e = PH[key];
            if (not e) then
                e = {};
                PH[key] = e;
            end
            e.zone = e.zone or inf.zone;
            if ((not e.pops or #e.pops == 0) and inf.pops) then
                e.pops = {};
                for _, nm in ipairs(inf.pops) do table.insert(e.pops, nm); end
            end
            if ((not e.ph_hex_ids and not e.hex_range) and inf.mob_ids_inferred
                and #inf.mob_ids_inferred > 0) then
                local lo, hi = inf.mob_ids_inferred[1], inf.mob_ids_inferred[1];
                for _, id in ipairs(inf.mob_ids_inferred) do
                    if (id < lo) then lo = id; end
                    if (id > hi) then hi = id; end
                end
                e.hex_range = { lo, hi };
            end
            e.respawn_sec = e.respawn_sec or 300;   -- 5min default PH respawn
        end
    end
end

-- Load user override file written by `/ct learn`.
local userPath = AshitaCore
    and (AshitaCore:GetInstallPath() .. 'config/addons/chhartarget/ph_user.lua')
    or  nil;
if (userPath) then
    local f = io.open(userPath, 'r');
    if (f) then
        f:close();
        local ok, chunk = pcall(loadfile, userPath);
        if (ok and chunk) then
            setfenv(chunk, { PH = M, os = os, string = string });
            pcall(chunk);
        end
    end
end

return M;
