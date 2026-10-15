-- ============================================================================
-- subjob_features.lua  --  shared subjob automation for all Chharizard jobs.
--
-- Provides event-driven automation for every subjob usable in era content.
-- Coverage is scoped to Horizon XI (ToAU cap, up to BLU/PUP/COR) AND
-- Phoenix XI (WoTG cap, adds SCH + DNC). Server-appropriate features are
-- gated per-subjob so a WAR/DNC combo on Horizon won't try to summon SCH
-- stratagems that don't exist yet.
--
-- Coverage:
--   /WAR -- Berserk, Aggressor, Warcry, Defender, Provoke (hate)
--   /MNK -- Boost stacking, Focus, Dodge, Counterstance
--   /WHM -- Auto-Cure self, auto-status removal (na spells), Divine Seal
--   /BLM -- Aspir when MP low, Elemental Seal, Sneak/Invis refresh
--   /RDM -- Self buff cycle: Refresh, Haste, Phalanx, Stoneskin, Blink, Aquaveil
--   /THF -- Flee on movement key, Steal, Sneak Attack setup, Hide
--   /PLD -- Cover, Shield Bash, Sentinel, Rampart, self-cure
--   /DRK -- Last Resort, Weapon Bash, Souleater (HP-gated), Arcane Circle
--   /BST -- (no auto -- pet management is manual by design)
--   /BRD -- Self-song refresh: March, Minuet, Madrigal (per config)
--   /RNG -- Sharpshot, Barrage, Scavenge
--   /SMN -- (no auto -- BP macros are manual)
--   /NIN -- Auto-refresh Utsusemi shadows when they drop
--   /DRG -- Super/High Jump on hate spike; Jump on cooldown for DPS
--   /SAM -- Auto-Hasso stance; Meditate when TP low; Third Eye on aggro
--   /BLU -- Cocoon, Refueling, Metallic Body, Head Butt (stun)
--   /COR -- Auto-roll pair: Chaos Roll + Samurai Roll (configurable)
--   /PUP -- (no auto -- automaton management belongs to PUP main)
--   /DNC -- Curing Waltz at HP threshold, Haste Samba upkeep, Drain Samba
--   /SCH -- Sublimation charging, Light Arts stratagem regen, tabula
--
-- All features default OFF. Toggle via /lac fwd <feature> on/off, or the
-- master `/lac fwd sub on` enables everything sensible for the current sub.
--
-- Usage from any job profile:
--
--   local Sub = dofile(AshitaCore:GetInstallPath() ..
--       'config/addons/luashitacast/_template/subjob_features.lua');
--
--   profile.OnLoad = function()
--       ashita.timer.create('<job>_sub_tick', 1.0, 0, function()
--           Sub.tick(gProfile == profile);
--       end);
--   end
--
--   profile.HandleCommand = function(args)
--       if (Sub.handleCommand(args)) then return; end
--   end
--
--   -- In debug print block:  Sub.debug();
--
-- Server-rule notice: auto-JA-on-cooldown may be classified as botting on
-- private servers. Defaults are OFF. Verify Horizon/Phoenix TOS before
-- enabling anything that isn't reactive/event-driven.
-- ============================================================================

local M = {};

-- ---------------------------------------------------------------------------
-- Log privacy: automation is SILENT by default so nothing gets written to
-- the client's chat log file (Documents/My Games/FFXI/USER/<ID>/LOG/).
-- Toggle at runtime with `/lac fwd verbose on|off`. When off, Sub.echo() and
-- every profile's M.echo() are no-ops. When explicitly on, messages appear in
-- the local chat window AND get logged to disk -- turn it off before you
-- finish playing so screenshots/log dumps stay clean.
-- ---------------------------------------------------------------------------
M.verbose = false;

function M.echo(msg)
    if (M.verbose) then print(msg); end
end

-- ---------------------------------------------------------------------------
-- Server profile: which private server this profile is running on.
-- Supported: "horizon" (Horizon XI, ToAU cap) | "phoenix" (Phoenix XI, ToAU
-- cap, WoTG pending) | "retail" (full jobs+abilities). Set by SETUP.ps1 based
-- on the user's answer; can be overridden at runtime with `/lac fwd server X`.
-- Recast/spell/buff IDs are the same on both era servers (both simulate ToAU-
-- accurate retail), so the only current behavioural difference is which jobs
-- are unlocked.
-- ---------------------------------------------------------------------------
M.server = "horizon";  -- SETUP.ps1 rewrites this on install

-- Which jobs the current server supports. Sub.jobLive(job) is used by the
-- profile files to fail-soft when a job's automation is invoked on a server
-- where the job doesn't yet exist.
M.jobsByServer = {
    horizon = { WAR=true, MNK=true, WHM=true, BLM=true, RDM=true, THF=true,
                PLD=true, DRK=true, BST=true, BRD=true, RNG=true, SMN=true,
                NIN=true, DRG=true, SAM=true, BLU=true, COR=true, PUP=true },
    phoenix = { WAR=true, MNK=true, WHM=true, BLM=true, RDM=true, THF=true,
                PLD=true, DRK=true, BST=true, BRD=true, RNG=true, SMN=true,
                NIN=true, DRG=true, SAM=true, BLU=true, COR=true, PUP=true },
    -- Phoenix will add DNC + SCH when WoTG launches; users can override
    -- their local M.jobsByServer.phoenix.DNC = true and .SCH = true then.
    retail  = { WAR=true, MNK=true, WHM=true, BLM=true, RDM=true, THF=true,
                PLD=true, DRK=true, BST=true, BRD=true, RNG=true, SMN=true,
                NIN=true, DRG=true, SAM=true, BLU=true, COR=true, PUP=true,
                DNC=true, SCH=true, GEO=true, RUN=true },
};

function M.jobLive(job)
    local set = M.jobsByServer[M.server] or M.jobsByServer.retail;
    return set[job:upper()] == true;
end

-- Server-specific ID overrides -- fill in only when a value is known to
-- differ from the retail defaults declared below. Empty by default; if
-- Phoenix or Horizon reassigns a recast/spell/buff ID, add here so the
-- one library stays authoritative.
M.overrides = {
    horizon = { recastId = {}, spellId = {}, buffId = {} },
    phoenix = { recastId = {}, spellId = {}, buffId = {} },
    retail  = { recastId = {}, spellId = {}, buffId = {} },
};

-- Apply any per-server overrides on top of the retail defaults. Called once
-- after the tables are populated below.
function M.applyServerOverrides()
    local o = M.overrides[M.server];
    if (not o) then return; end
    for k, v in pairs(o.recastId or {}) do M.recastId[k] = v; end
    for k, v in pairs(o.spellId  or {}) do M.spellId[k]  = v; end
    for k, v in pairs(o.buffId   or {}) do M.buffId[k]   = v; end
end

-- ---------------------------------------------------------------------------
-- Config -- profiles can override any of these before their first tick.
-- ---------------------------------------------------------------------------
M.cfg = {
    -- ---- Hybrids / DPS subs ----
    war = {
        autoBerserk    = false,   -- fire when engaged, off cd
        autoAggressor  = false,   -- fire when engaged, off cd
        autoWarcry     = false,   -- self-buff on engage
        autoDefender   = false,   -- only when tanking
        autoProvoke    = false,   -- for hate-holders (PLD/NIN main w/ /WAR)
        provokeOnHateLoss = false, -- fire only when not being targeted
    },
    mnk = {
        autoBoost      = false,   -- stack Boost pre-WS
        boostStacks    = 5,       -- how many to stack before letting WS fire
        autoFocus      = false,
        autoDodge      = false,
        autoCounter    = false,   -- Counterstance while engaged
    },
    whm = {
        autoCureSelf   = false,
        selfHpCure     = 55,      -- % HP threshold
        autoNa         = false,   -- Poisona/Paralyna/Blindna/etc
        autoDivineSeal = false,   -- burst before big cure
    },
    blm = {
        autoAspir      = false,   -- when MP low + off cd
        mpAspirBelow   = 30,      -- % MP threshold
        autoElemSeal   = false,   -- before big nuke (manual burst)
        autoInvisSneak = false,   -- refresh when moving out of combat
    },
    rdm = {
        autoRefresh    = false,
        autoHaste      = false,
        autoPhalanx    = false,
        autoStoneskin  = false,
        autoBlink      = false,
        autoAquaveil   = false,
        buffCheckSec   = 20,      -- how often to sweep self-buffs
    },
    thf = {
        autoFlee       = false,   -- on 'flee' cmd only, not automatic
        autoSteal      = false,   -- one-shot on engage
        autoHide       = false,   -- pop Hide on shed cmd
    },
    pld = {
        autoShieldBash = false,   -- interrupt casts (event-driven)
        autoSentinel   = false,   -- only when tanking + hate low
        autoRampart    = false,
    },
    drk = {
        autoLastResort = false,   -- DPS burst on cd while engaged
        autoWeaponBash = false,   -- stun on cast
        autoSouleater  = false,   -- HP-gated
        souleaterHpMin = 70,      -- only pop when HP > this %
        autoArcaneCircle = false, -- only vs arcana mobs
    },
    brd = {
        autoMarch      = false,   -- keep Victory March or Advancing March up
        autoMinuet     = false,   -- Valor Minuet (dmg) if configured
        marchName      = "Victory March",  -- or "Advancing March"
        minuetName     = "Valor Minuet IV",
    },
    rng = {
        autoSharpshot  = false,   -- pre-WS burst
        autoBarrage    = false,   -- stack before WS
        autoScavenge   = false,   -- ammo recovery on idle
    },
    nin = {
        autoUtsusemi = false,
        preferNi     = true,
    },
    drg = {
        autoJumps    = false,
        shedOnAggro  = true,
        dpsJumpOnCd  = true,
    },
    sam = {
        autoHasso    = false,
        autoMeditate = false,
        autoThirdEye = false,
        meditateTpBelow = 900,
    },
    blu = {
        autoCocoon     = false,   -- PDT self-buff
        autoRefueling  = false,   -- haste
        autoMetallic   = false,   -- Stoneskin-alike
        autoHeadButt   = false,   -- stun on cast (event-driven)
    },
    cor = {
        autoRolls      = false,
        primaryRoll    = "Chaos Roll",     -- attack
        secondaryRoll  = "Samurai Roll",   -- store TP
        rerollOnBust   = true,
    },
    dnc = {
        autoWaltz      = false,   -- Curing Waltz II/III on self at threshold
        waltzHpBelow   = 60,
        autoHasteSamba = false,
        autoDrainSamba = false,   -- for HP regen while soloing
    },
    sch = {
        autoSublimation= false,   -- charging when idle
        autoLightArts  = false,   -- keep Light Arts stance
        stratagemFill  = false,   -- consume tabula at 3 charges
    },
    checkInterval = 2,           -- seconds between per-feature ticks
    buffCheckSec  = 20,           -- self-buff sweep cadence (RDM etc.)
};

-- ---------------------------------------------------------------------------
-- Recast timer IDs (Ashita's fixed ability-recast index).
-- These are retail-stable but Horizon/Phoenix may reassign; override in
-- profile.cfg if needed. Anything unknown falls through as "off cd" harmlessly.
-- ---------------------------------------------------------------------------
M.recastId = {
    -- WAR
    Berserk          = 1,
    Defender         = 3,
    Warcry           = 2,
    Aggressor        = 4,
    Provoke          = 5,
    -- MNK
    Boost            = 6,
    Focus            = 7,
    Dodge            = 8,
    Counterstance    = 10,
    Chakra           = 9,
    -- WHM
    DivineSeal       = 11,
    -- BLM
    ElementalSeal    = 12,
    -- PLD
    Cover            = 13,
    ShieldBash       = 15,
    Sentinel         = 16,
    HolyCircle       = 14,
    Rampart          = 44,
    -- DRK
    Souleater        = 17,
    ArcaneCircle     = 18,
    LastResort       = 19,
    WeaponBash       = 20,
    -- THF
    Hide             = 21,
    SneakAttack      = 22,
    Flee             = 23,
    Mug              = 24,
    TrickAttack      = 25,
    -- BRD -- no JA cds; songs are spells (see spellId below)
    -- RNG
    Sharpshot        = 72,
    Barrage          = 73,
    Scavenge         = 74,
    -- NIN spells (Utsusemi) handled via spellId
    -- DRG
    Jump             = 158,
    HighJump         = 159,
    SuperJump        = 160,
    -- SAM
    Meditate         = 133,
    ["Third Eye"]    = 134,
    Hasso            = 138,
    Seigan           = 139,
    -- BLU (JAs for /BLU sub -- but Cocoon/Refueling/etc. are SPELLS; see spellId)
    -- COR
    DoubleUp         = 195,
    Snake_Eye        = 196,
    -- DNC
    HasteSamba       = 220,
    DrainSamba       = 221,
    CuringWaltz      = 222,
    CuringWaltzII    = 223,
    CuringWaltzIII   = 224,
    -- SCH
    Sublimation      = 240,
    LightArts        = 232,
    DarkArts         = 233,
    Tabula           = 241,
};

-- Spell IDs (Ashita spell recast index).
M.spellId = {
    -- NIN
    ["Utsusemi: Ichi"]  = 338,
    ["Utsusemi: Ni"]    = 339,
    -- WHM na-spells
    ["Poisona"]         = 14,
    ["Paralyna"]        = 15,
    ["Blindna"]         = 16,
    ["Silena"]          = 17,
    ["Cursna"]          = 20,
    ["Viruna"]          = 19,
    ["Stona"]           = 18,
    ["Cure"]            = 1,
    ["Cure II"]         = 2,
    ["Cure III"]        = 3,
    ["Cure IV"]         = 4,
    -- BLM
    ["Aspir"]           = 227,
    ["Aspir II"]        = 228,
    ["Sneak"]           = 250,
    ["Invisible"]       = 251,
    -- RDM
    ["Refresh"]         = 108,
    ["Haste"]           = 358,
    ["Phalanx"]         = 106,
    ["Stoneskin"]       = 54,
    ["Blink"]           = 53,
    ["Aquaveil"]        = 55,
    -- BRD (song IDs range 389+)
    ["Victory March"]        = 419,
    ["Advancing March"]      = 420,
    ["Valor Minuet IV"]      = 400,
    ["Valor Minuet III"]     = 399,
    -- BLU (from /BLU sub -- these are blue magic spell IDs)
    ["Cocoon"]          = 511,
    ["Refueling"]       = 493,
    ["Metallic Body"]   = 495,
    ["Head Butt"]       = 496,
};

-- Buff IDs (Ashita status effect table).
M.buffId = {
    -- NIN
    ["Copy Image"]      = 66,
    ["Copy Image (2)"]  = 444,
    ["Copy Image (3)"]  = 445,
    -- WAR
    Berserk             = 33,
    Defender            = 32,
    Warcry              = 34,
    Aggressor           = 35,
    -- MNK
    Boost               = 45,
    Focus               = 42,
    Dodge               = 41,
    Counterstance       = 44,
    -- RDM/WHM buffs
    Refresh             = 43,
    Haste               = 33,   -- note: shares slot; check spell trace
    Phalanx             = 116,
    Stoneskin           = 37,
    Blink               = 38,
    Aquaveil            = 39,
    -- DRK
    LastResort          = 65,
    Souleater           = 71,
    ArcaneCircle        = 68,
    -- BLU
    Cocoon              = 105,
    Refueling           = 128,
    ["Metallic Body"]   = 37,   -- alias of Stoneskin slot
    -- SAM
    Hasso               = 358,
    Seigan              = 359,
    ["Third Eye"]       = 360,
    -- BRD (song slots are dynamic; presence-check by name)
    -- DNC
    ["Haste Samba"]     = 370,
    ["Drain Samba"]     = 369,
    -- SCH
    Sublimation         = 187,
    ["Light Arts"]      = 358,  -- shares
    ["Dark Arts"]       = 359,
};

-- Apply server-specific ID overrides now that the default tables are declared.
M.applyServerOverrides();

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function trimEnd(s) return type(s)=='string' and s:gsub('\x00.*','') or s; end

function M.subJob()
    local pid = AshitaCore:GetMemoryManager():GetPlayer():GetSubJob();
    local name = AshitaCore:GetResourceManager():GetString('jobs.names_abbr', pid);
    return trimEnd(name) or '';
end

function M.mainJob()
    local pid = AshitaCore:GetMemoryManager():GetPlayer():GetMainJob();
    local name = AshitaCore:GetResourceManager():GetString('jobs.names_abbr', pid);
    return trimEnd(name) or '';
end

function M.selfIndex()
    return AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0);
end

function M.selfTp() return AshitaCore:GetMemoryManager():GetPlayer():GetMainJobTP() or 0; end
function M.selfHpPct() return AshitaCore:GetMemoryManager():GetParty():GetMemberHPPercent(0) or 100; end
function M.selfMpPct() return AshitaCore:GetMemoryManager():GetParty():GetMemberMPPercent(0) or 100; end
function M.amEngaged() return gData.GetPlayer().Status == 'Engaged'; end
function M.amIdle()    return gData.GetPlayer().Status == 'Idle'; end
function M.amMoving()  return gData.GetPlayer().IsMoving == true; end

function M.hasBuff(id)
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    for i = 0, 31 do
        if (player:GetStatusIcon(i) == id) then return true; end
    end
    return false;
end

-- Check whether any status matching a set of debuff icons is on us.
-- Retail na-spell targets: poison=6, paralysis=4, blindness=5, silence=7,
-- curse=13/14, disease=20, petrification=8, virus=15
M.debuffMap = {
    poison       = { 6, "Poisona" },
    paralysis    = { 4, "Paralyna" },
    blindness    = { 5, "Blindna" },
    silence      = { 7, "Silena" },
    curse        = { 13, "Cursna" },
    disease      = { 20, "Viruna" },
    petrification= { 8, "Stona" },
    virus        = { 15, "Viruna" },
};

function M.abilityRecast(id) return AshitaCore:GetMemoryManager():GetRecast():GetAbilityTimer(id) or 999999; end
function M.spellRecast(id)   return AshitaCore:GetMemoryManager():GetRecast():GetSpellTimer(id) or 999999; end

function M.mobTargetingMe()
    local myIdx = M.selfIndex();
    if (not myIdx or myIdx == 0) then return nil; end
    local ent = AshitaCore:GetMemoryManager():GetEntity();
    for i = 0x400, 0x8FF do
        if (ent:GetServerId(i) ~= 0) and (ent:GetHPPercent(i) > 0) then
            if (ent:GetTargetIndex(i) == myIdx) then return i; end
        end
    end
    return nil;
end

function M.mobIsCasting()
    -- Detect target casting via entity flags (best-effort).
    local t = gData.GetTarget();
    if (not t or not t.Index) then return false; end
    local ent = AshitaCore:GetMemoryManager():GetEntity();
    local flags = ent:GetStatus(t.Index) or 0;
    return flags == 33;   -- casting
end

function M.queue(cmd) AshitaCore:GetChatManager():QueueCommand(1, cmd); end

-- Guard: only run this feature every N seconds.
local lastRun = {};
function M.throttled(key, seconds)
    local now = os.time();
    if ((lastRun[key] or 0) + (seconds or M.cfg.checkInterval) > now) then return false; end
    lastRun[key] = now;
    return true;
end

-- ============================================================================
-- TIER 1: TANK / MELEE SUBS
-- ============================================================================

-- /WAR --------------------------------------------------------------
function M.tickWar()
    if (M.subJob() ~= 'WAR') then return; end
    if (not M.amEngaged()) then return; end
    if (not M.throttled('war', 2)) then return; end
    local c = M.cfg.war;

    if (c.autoBerserk and not M.hasBuff(M.buffId.Berserk)
        and M.abilityRecast(M.recastId.Berserk) == 0) then
        M.queue('/ja "Berserk" <me>'); M.echo('[Sub /WAR] Berserk'); return;
    end
    if (c.autoAggressor and not M.hasBuff(M.buffId.Aggressor)
        and M.abilityRecast(M.recastId.Aggressor) == 0) then
        M.queue('/ja "Aggressor" <me>'); M.echo('[Sub /WAR] Aggressor'); return;
    end
    if (c.autoWarcry and not M.hasBuff(M.buffId.Warcry)
        and M.abilityRecast(M.recastId.Warcry) == 0) then
        M.queue('/ja "Warcry" <me>'); M.echo('[Sub /WAR] Warcry'); return;
    end
    if (c.autoDefender and not M.hasBuff(M.buffId.Defender)
        and M.abilityRecast(M.recastId.Defender) == 0) then
        M.queue('/ja "Defender" <me>'); M.echo('[Sub /WAR] Defender'); return;
    end
    -- Provoke: only fire when NOT being targeted (hate has slipped)
    if (c.autoProvoke and c.provokeOnHateLoss and not M.mobTargetingMe()
        and M.abilityRecast(M.recastId.Provoke) == 0) then
        M.queue('/ja "Provoke" <t>'); M.echo('[Sub /WAR] Provoke -> reclaim hate');
    end
end

-- /MNK --------------------------------------------------------------
function M.tickMnk()
    if (M.subJob() ~= 'MNK') then return; end
    if (not M.throttled('mnk', 2)) then return; end
    local c = M.cfg.mnk;

    if (c.autoBoost and M.amEngaged()
        and M.abilityRecast(M.recastId.Boost) == 0) then
        M.queue('/ja "Boost" <me>'); M.echo('[Sub /MNK] Boost'); return;
    end
    if (c.autoCounter and M.amEngaged() and not M.hasBuff(M.buffId.Counterstance)
        and M.abilityRecast(M.recastId.Counterstance) == 0) then
        M.queue('/ja "Counterstance" <me>'); M.echo('[Sub /MNK] Counterstance'); return;
    end
    if (c.autoFocus and M.amEngaged() and not M.hasBuff(M.buffId.Focus)
        and M.abilityRecast(M.recastId.Focus) == 0) then
        M.queue('/ja "Focus" <me>'); M.echo('[Sub /MNK] Focus'); return;
    end
    if (c.autoDodge and M.amEngaged() and not M.hasBuff(M.buffId.Dodge)
        and M.abilityRecast(M.recastId.Dodge) == 0) then
        M.queue('/ja "Dodge" <me>'); M.echo('[Sub /MNK] Dodge');
    end
end

-- /PLD --------------------------------------------------------------
function M.tickPld()
    if (M.subJob() ~= 'PLD') then return; end
    if (not M.throttled('pld', 2)) then return; end
    local c = M.cfg.pld;

    if (c.autoShieldBash and M.amEngaged() and M.mobIsCasting()
        and M.abilityRecast(M.recastId.ShieldBash) == 0) then
        M.queue('/ja "Shield Bash" <t>'); M.echo('[Sub /PLD] Shield Bash -> interrupt'); return;
    end
    if (c.autoSentinel and M.amEngaged() and not M.mobTargetingMe()
        and M.abilityRecast(M.recastId.Sentinel) == 0) then
        M.queue('/ja "Sentinel" <me>'); M.echo('[Sub /PLD] Sentinel -> hate'); return;
    end
    if (c.autoRampart and M.amEngaged() and M.selfHpPct() < 60
        and M.abilityRecast(M.recastId.Rampart) == 0) then
        M.queue('/ja "Rampart" <me>'); M.echo('[Sub /PLD] Rampart');
    end
end

-- /DRK --------------------------------------------------------------
function M.tickDrk()
    if (M.subJob() ~= 'DRK') then return; end
    if (not M.throttled('drk', 2)) then return; end
    local c = M.cfg.drk;

    if (c.autoLastResort and M.amEngaged() and not M.hasBuff(M.buffId.LastResort)
        and M.abilityRecast(M.recastId.LastResort) == 0) then
        M.queue('/ja "Last Resort" <me>'); M.echo('[Sub /DRK] Last Resort'); return;
    end
    if (c.autoSouleater and M.amEngaged() and M.selfHpPct() >= c.souleaterHpMin
        and not M.hasBuff(M.buffId.Souleater)
        and M.abilityRecast(M.recastId.Souleater) == 0) then
        M.queue('/ja "Souleater" <me>');
        M.echo('[Sub /DRK] Souleater ('..M.selfHpPct()..'% HP)'); return;
    end
    if (c.autoWeaponBash and M.amEngaged() and M.mobIsCasting()
        and M.abilityRecast(M.recastId.WeaponBash) == 0) then
        M.queue('/ja "Weapon Bash" <t>'); M.echo('[Sub /DRK] Weapon Bash -> stun');
    end
end

-- /THF --------------------------------------------------------------
function M.tickThf()
    if (M.subJob() ~= 'THF') then return; end
    -- Nothing runs unattended for /THF -- Steal/Flee/Hide are on-demand.
    -- Handled via handleCommand only.
end

-- ============================================================================
-- TIER 2: SUPPORT / HYBRID SUBS
-- ============================================================================

-- /WHM --------------------------------------------------------------
function M.tickWhm()
    if (M.subJob() ~= 'WHM') then return; end
    if (not M.throttled('whm', 2)) then return; end
    local c = M.cfg.whm;

    -- Auto-Cure self at HP threshold
    if (c.autoCureSelf and M.selfHpPct() <= c.selfHpCure) then
        for _, sp in ipairs({ "Cure III", "Cure II", "Cure" }) do
            if (M.spellRecast(M.spellId[sp]) == 0) then
                M.queue('/ma "'..sp..'" <me>');
                M.echo('[Sub /WHM] '..sp..' self ('..M.selfHpPct()..'%)'); return;
            end
        end
    end

    -- Auto-Na: iterate debuffs on us and cast matching na
    if (c.autoNa) then
        local player = AshitaCore:GetMemoryManager():GetPlayer();
        for i = 0, 31 do
            local icon = player:GetStatusIcon(i);
            for _, info in pairs(M.debuffMap) do
                if (icon == info[1]) then
                    local spell = info[2];
                    if (M.spellRecast(M.spellId[spell] or 0) == 0) then
                        M.queue('/ma "'..spell..'" <me>');
                        M.echo('[Sub /WHM] '..spell..' -> self'); return;
                    end
                end
            end
        end
    end
end

-- /BLM --------------------------------------------------------------
function M.tickBlm()
    if (M.subJob() ~= 'BLM') then return; end
    if (not M.throttled('blm', 2)) then return; end
    local c = M.cfg.blm;

    if (c.autoAspir and M.amEngaged() and M.selfMpPct() < c.mpAspirBelow) then
        for _, sp in ipairs({ "Aspir II", "Aspir" }) do
            if (M.spellRecast(M.spellId[sp] or 0) == 0) then
                M.queue('/ma "'..sp..'" <t>');
                M.echo('[Sub /BLM] '..sp..' ('..M.selfMpPct()..'% MP)'); return;
            end
        end
    end
end

-- /RDM --------------------------------------------------------------
function M.tickRdm()
    if (M.subJob() ~= 'RDM') then return; end
    if (not M.throttled('rdm', M.cfg.buffCheckSec)) then return; end
    local c = M.cfg.rdm;

    -- Cast missing self-buffs in priority order. One per tick to avoid queue spam.
    local buffs = {
        { c.autoRefresh,   "Refresh",   M.buffId.Refresh },
        { c.autoHaste,     "Haste",     M.buffId.Haste },
        { c.autoPhalanx,   "Phalanx",   M.buffId.Phalanx },
        { c.autoStoneskin, "Stoneskin", M.buffId.Stoneskin },
        { c.autoBlink,     "Blink",     M.buffId.Blink },
        { c.autoAquaveil,  "Aquaveil",  M.buffId.Aquaveil },
    };
    for _, b in ipairs(buffs) do
        if (b[1] and not M.hasBuff(b[3])) then
            if (M.spellRecast(M.spellId[b[2]] or 0) == 0) then
                M.queue('/ma "'..b[2]..'" <me>');
                M.echo('[Sub /RDM] '..b[2]); return;
            end
        end
    end
end

-- /BRD --------------------------------------------------------------
function M.tickBrd()
    if (M.subJob() ~= 'BRD') then return; end
    if (not M.throttled('brd', M.cfg.buffCheckSec)) then return; end
    local c = M.cfg.brd;

    -- Songs sit in dynamic slots; presence-check by song name via buff text is
    -- unreliable, so we just refresh every buffCheckSec. Adjust in profile.
    if (c.autoMinuet and M.amEngaged()) then
        if (M.spellRecast(M.spellId[c.minuetName] or 0) == 0) then
            M.queue('/ma "'..c.minuetName..'" <me>');
            M.echo('[Sub /BRD] '..c.minuetName); return;
        end
    end
    if (c.autoMarch) then
        if (M.spellRecast(M.spellId[c.marchName] or 0) == 0) then
            M.queue('/ma "'..c.marchName..'" <me>');
            M.echo('[Sub /BRD] '..c.marchName);
        end
    end
end

-- /RNG --------------------------------------------------------------
function M.tickRng()
    if (M.subJob() ~= 'RNG') then return; end
    if (not M.throttled('rng', 2)) then return; end
    local c = M.cfg.rng;

    -- Pre-WS Sharpshot / Barrage burst (fire when TP is >= 900 and engaged)
    if (M.amEngaged() and M.selfTp() >= 900) then
        if (c.autoSharpshot and M.abilityRecast(M.recastId.Sharpshot) == 0) then
            M.queue('/ja "Sharpshot" <me>'); M.echo('[Sub /RNG] Sharpshot pre-WS'); return;
        end
        if (c.autoBarrage and M.abilityRecast(M.recastId.Barrage) == 0) then
            M.queue('/ja "Barrage" <me>'); M.echo('[Sub /RNG] Barrage pre-WS');
        end
    end
    -- Scavenge while idle
    if (c.autoScavenge and M.amIdle()
        and M.abilityRecast(M.recastId.Scavenge) == 0) then
        M.queue('/ja "Scavenge" <me>'); M.echo('[Sub /RNG] Scavenge');
    end
end

-- ============================================================================
-- TIER 3: NIN / DRG / SAM (existing)
-- ============================================================================

function M.tickNin()
    if (not M.cfg.nin.autoUtsusemi) then return; end
    if (M.subJob() ~= 'NIN') then return; end
    if (not M.amEngaged()) then return; end
    if (not M.throttled('nin', 2)) then return; end

    if (M.hasBuff(M.buffId["Copy Image"])
        or M.hasBuff(M.buffId["Copy Image (2)"])
        or M.hasBuff(M.buffId["Copy Image (3)"])) then return; end

    if (M.cfg.nin.preferNi and M.spellRecast(M.spellId["Utsusemi: Ni"]) == 0) then
        M.queue('/ma "Utsusemi: Ni" <me>');
        M.echo('[Sub /NIN] Utsusemi: Ni'); return;
    end
    if (M.spellRecast(M.spellId["Utsusemi: Ichi"]) == 0) then
        M.queue('/ma "Utsusemi: Ichi" <me>');
        M.echo('[Sub /NIN] Utsusemi: Ichi');
    end
end

function M.tickDrg()
    if (not M.cfg.drg.autoJumps) then return; end
    if (M.subJob() ~= 'DRG') then return; end
    if (not M.amEngaged()) then return; end
    if (not M.throttled('drg', 2)) then return; end

    if (M.cfg.drg.shedOnAggro and M.mobTargetingMe()) then
        if (M.abilityRecast(M.recastId.SuperJump) == 0) then
            M.queue('/ja "Super Jump" <me>');
            M.echo('[Sub /DRG] Super Jump -> shed hate'); return;
        elseif (M.abilityRecast(M.recastId.HighJump) == 0) then
            M.queue('/ja "High Jump" <me>');
            M.echo('[Sub /DRG] High Jump -> shed hate'); return;
        end
    end
    if (M.cfg.drg.dpsJumpOnCd and M.abilityRecast(M.recastId.Jump) == 0) then
        M.queue('/ja "Jump" <t>');
    end
end

function M.tickSam()
    if (M.subJob() ~= 'SAM') then return; end
    if (not M.throttled('sam', 2)) then return; end

    if (M.cfg.sam.autoThirdEye and M.amEngaged() and M.mobTargetingMe()) then
        if (not M.hasBuff(M.buffId["Third Eye"])
            and M.abilityRecast(M.recastId["Third Eye"]) == 0) then
            M.queue('/ja "Third Eye" <me>');
            M.echo('[Sub /SAM] Third Eye -> anticipate'); return;
        end
    end
    if (M.cfg.sam.autoHasso and M.amEngaged()
        and not M.hasBuff(M.buffId.Hasso) and not M.hasBuff(M.buffId.Seigan)
        and M.abilityRecast(M.recastId.Hasso) == 0) then
        M.queue('/ja "Hasso" <me>');
        M.echo('[Sub /SAM] Hasso -> stance up'); return;
    end
    if (M.cfg.sam.autoMeditate
        and M.selfTp() < M.cfg.sam.meditateTpBelow
        and M.abilityRecast(M.recastId.Meditate) == 0) then
        M.queue('/ja "Meditate" <me>');
        M.echo('[Sub /SAM] Meditate');
    end
end

-- ============================================================================
-- TIER 4: ToAU EXPANSION SUBS (Horizon has these)
-- ============================================================================

-- /BLU --------------------------------------------------------------
function M.tickBlu()
    if (M.subJob() ~= 'BLU') then return; end
    if (not M.throttled('blu', 3)) then return; end
    local c = M.cfg.blu;

    -- Cocoon: PDT self-buff
    if (c.autoCocoon and M.amEngaged() and not M.hasBuff(M.buffId.Cocoon)
        and M.spellRecast(M.spellId["Cocoon"] or 0) == 0) then
        M.queue('/ma "Cocoon" <me>'); M.echo('[Sub /BLU] Cocoon'); return;
    end
    -- Refueling: haste
    if (c.autoRefueling and not M.hasBuff(M.buffId.Refueling)
        and M.spellRecast(M.spellId["Refueling"] or 0) == 0) then
        M.queue('/ma "Refueling" <me>'); M.echo('[Sub /BLU] Refueling'); return;
    end
    -- Metallic Body: stoneskin-alike
    if (c.autoMetallic and not M.hasBuff(M.buffId.Stoneskin)
        and M.spellRecast(M.spellId["Metallic Body"] or 0) == 0) then
        M.queue('/ma "Metallic Body" <me>'); M.echo('[Sub /BLU] Metallic Body'); return;
    end
    -- Head Butt: stun on cast (event-driven)
    if (c.autoHeadButt and M.amEngaged() and M.mobIsCasting()
        and M.spellRecast(M.spellId["Head Butt"] or 0) == 0) then
        M.queue('/ma "Head Butt" <t>'); M.echo('[Sub /BLU] Head Butt -> stun');
    end
end

-- /COR --------------------------------------------------------------
-- Auto-roll: fire primary, then wait for buff, then fire secondary.
-- Bust detection is left to server messages; profile can force reroll.
local corState = { phase = 'primary' };
function M.tickCor()
    if (M.subJob() ~= 'COR') then return; end
    if (not M.cfg.cor.autoRolls) then return; end
    if (not M.throttled('cor', 5)) then return; end

    -- Only roll when idle and out of combat (buff prep phase)
    if (M.amEngaged()) then return; end
    local c = M.cfg.cor;

    if (corState.phase == 'primary') then
        M.queue('/ja "'..c.primaryRoll..'" <me>');
        M.echo('[Sub /COR] '..c.primaryRoll);
        corState.phase = 'secondary';
    elseif (corState.phase == 'secondary') then
        M.queue('/ja "'..c.secondaryRoll..'" <me>');
        M.echo('[Sub /COR] '..c.secondaryRoll);
        corState.phase = 'done';
    end
end

-- Reset roll state (call from HandleCommand or on job change)
function M.resetCorRolls() corState.phase = 'primary'; end

-- ============================================================================
-- TIER 5: WoTG EXPANSION SUBS (Phoenix has these once WoTG unlocks)
-- ============================================================================

-- /DNC --------------------------------------------------------------
function M.tickDnc()
    if (M.subJob() ~= 'DNC') then return; end
    if (not M.throttled('dnc', 2)) then return; end
    local c = M.cfg.dnc;

    -- Curing Waltz: at HP threshold, use best available
    if (c.autoWaltz and M.selfHpPct() <= c.waltzHpBelow and M.selfTp() >= 200) then
        local sequence = {
            { M.recastId.CuringWaltzIII, "Curing Waltz III", 400 },
            { M.recastId.CuringWaltzII,  "Curing Waltz II",  350 },
            { M.recastId.CuringWaltz,    "Curing Waltz",     200 },
        };
        for _, w in ipairs(sequence) do
            if (M.selfTp() >= w[3] and M.abilityRecast(w[1]) == 0) then
                M.queue('/ja "'..w[2]..'" <me>');
                M.echo('[Sub /DNC] '..w[2]..' ('..M.selfHpPct()..'%)'); return;
            end
        end
    end

    -- Haste Samba: keep up while engaged
    if (c.autoHasteSamba and M.amEngaged() and not M.hasBuff(M.buffId["Haste Samba"])
        and M.selfTp() >= 150
        and M.abilityRecast(M.recastId.HasteSamba) == 0) then
        M.queue('/ja "Haste Samba" <me>'); M.echo('[Sub /DNC] Haste Samba'); return;
    end
    -- Drain Samba: HP regen while soloing
    if (c.autoDrainSamba and M.amEngaged() and not M.hasBuff(M.buffId["Drain Samba"])
        and M.selfTp() >= 150
        and M.abilityRecast(M.recastId.DrainSamba) == 0) then
        M.queue('/ja "Drain Samba" <me>'); M.echo('[Sub /DNC] Drain Samba');
    end
end

-- /SCH --------------------------------------------------------------
function M.tickSch()
    if (M.subJob() ~= 'SCH') then return; end
    if (not M.throttled('sch', 5)) then return; end
    local c = M.cfg.sch;

    -- Sublimation: charge while idle
    if (c.autoSublimation and M.amIdle() and not M.hasBuff(M.buffId.Sublimation)
        and M.abilityRecast(M.recastId.Sublimation) == 0) then
        M.queue('/ja "Sublimation" <me>'); M.echo('[Sub /SCH] Sublimation charging'); return;
    end
    -- Light Arts: keep stance for stratagem-based healing subjob use
    if (c.autoLightArts and not M.hasBuff(M.buffId["Light Arts"])
        and not M.hasBuff(M.buffId["Dark Arts"])
        and M.abilityRecast(M.recastId.LightArts) == 0) then
        M.queue('/ja "Light Arts" <me>'); M.echo('[Sub /SCH] Light Arts');
    end
end

-- ============================================================================
-- Public API
-- ============================================================================

-- ---------------------------------------------------------------------------
-- ChharMaton sidecar sync. When sub is PUP (and main isn't -- PUP.lua handles
-- its own case), auto-load the visual-orb addon; unload when sub changes
-- away. State-tracked so we only issue the command on transitions.
-- ---------------------------------------------------------------------------
local chharmatonLoaded = nil;   -- nil = unknown, true/false = tracked
local function syncChharmaton()
    local main = (M.mainJob() or ''):upper();
    local sub  = (M.subJob()  or ''):upper();
    -- PUP main is already handled by PUP.lua's OnLoad/OnUnload; don't fight it.
    if (main == 'PUP') then return; end
    local shouldLoad = (sub == 'PUP');
    if (shouldLoad == chharmatonLoaded) then return; end
    if (shouldLoad) then
        AshitaCore:GetChatManager():QueueCommand(1, '/addon load chharmaton');
    else
        AshitaCore:GetChatManager():QueueCommand(1, '/addon unload chharmaton');
    end
    chharmatonLoaded = shouldLoad;
end

function M.tick(active)
    if (not active) then return; end
    pcall(syncChharmaton);
    -- Tier 1: tank/melee
    M.tickWar(); M.tickMnk(); M.tickPld(); M.tickDrk(); M.tickThf();
    -- Tier 2: support/hybrid
    M.tickWhm(); M.tickBlm(); M.tickRdm(); M.tickBrd(); M.tickRng();
    -- Tier 3: existing
    M.tickNin(); M.tickDrg(); M.tickSam();
    -- Tier 4: ToAU
    M.tickBlu(); M.tickCor();
    -- Tier 5: WoTG
    M.tickDnc(); M.tickSch();
end

-- ---------------------------------------------------------------------------
-- Command handler.
-- ---------------------------------------------------------------------------
-- Consumes /lac fwd <cmd> [on|off]. Returns true if consumed.
local function toggle(section, key, val, label)
    section[key] = (val == 'on');
    M.echo('[Sub '..label..'] '..key..': '..(section[key] and 'ON' or 'OFF'));
end

function M.handleCommand(args)
    if (#args < 1) then return false; end
    local cmd = args[1]:lower();
    local val = args[2] and args[2]:lower() or nil;

    -- /WAR
    if (cmd == 'berserk')   then toggle(M.cfg.war, 'autoBerserk',   val, '/WAR'); return true; end
    if (cmd == 'aggressor') then toggle(M.cfg.war, 'autoAggressor', val, '/WAR'); return true; end
    if (cmd == 'warcry')    then toggle(M.cfg.war, 'autoWarcry',    val, '/WAR'); return true; end
    if (cmd == 'wardef')    then toggle(M.cfg.war, 'autoDefender',  val, '/WAR'); return true; end
    if (cmd == 'voke')      then toggle(M.cfg.war, 'autoProvoke',   val, '/WAR'); return true; end

    -- /MNK
    if (cmd == 'boost')     then toggle(M.cfg.mnk, 'autoBoost',   val, '/MNK'); return true; end
    if (cmd == 'focus')     then toggle(M.cfg.mnk, 'autoFocus',   val, '/MNK'); return true; end
    if (cmd == 'dodge')     then toggle(M.cfg.mnk, 'autoDodge',   val, '/MNK'); return true; end
    if (cmd == 'counter')   then toggle(M.cfg.mnk, 'autoCounter', val, '/MNK'); return true; end

    -- /WHM
    if (cmd == 'curese' or cmd == 'selfcure') then toggle(M.cfg.whm, 'autoCureSelf', val, '/WHM'); return true; end
    if (cmd == 'na')        then toggle(M.cfg.whm, 'autoNa',      val, '/WHM'); return true; end
    if (cmd == 'divine')    then toggle(M.cfg.whm, 'autoDivineSeal', val, '/WHM'); return true; end

    -- /BLM
    if (cmd == 'aspir')     then toggle(M.cfg.blm, 'autoAspir',   val, '/BLM'); return true; end
    if (cmd == 'esell')     then toggle(M.cfg.blm, 'autoElemSeal', val, '/BLM'); return true; end

    -- /RDM
    if (cmd == 'refresh')   then toggle(M.cfg.rdm, 'autoRefresh',  val, '/RDM'); return true; end
    if (cmd == 'haste')     then toggle(M.cfg.rdm, 'autoHaste',    val, '/RDM'); return true; end
    if (cmd == 'phalanx')   then toggle(M.cfg.rdm, 'autoPhalanx',  val, '/RDM'); return true; end
    if (cmd == 'stoneskin' or cmd == 'ss') then toggle(M.cfg.rdm, 'autoStoneskin', val, '/RDM'); return true; end
    if (cmd == 'blink')     then toggle(M.cfg.rdm, 'autoBlink',    val, '/RDM'); return true; end
    if (cmd == 'aquaveil')  then toggle(M.cfg.rdm, 'autoAquaveil', val, '/RDM'); return true; end

    -- /THF (all on-demand)
    if (cmd == 'flee')  then M.queue('/ja "Flee" <me>');           M.echo('[Sub /THF] Flee'); return true; end
    if (cmd == 'steal') then M.queue('/ja "Steal" <t>');           M.echo('[Sub /THF] Steal'); return true; end
    if (cmd == 'hide')  then M.queue('/ja "Hide" <me>');           M.echo('[Sub /THF] Hide'); return true; end
    if (cmd == 'sa')    then M.queue('/ja "Sneak Attack" <me>');   M.echo('[Sub /THF] Sneak Attack'); return true; end
    if (cmd == 'ta')    then M.queue('/ja "Trick Attack" <me>');   M.echo('[Sub /THF] Trick Attack'); return true; end

    -- /PLD
    if (cmd == 'shieldbash' or cmd == 'sb') then toggle(M.cfg.pld, 'autoShieldBash', val, '/PLD'); return true; end
    if (cmd == 'sentinel')   then toggle(M.cfg.pld, 'autoSentinel', val, '/PLD'); return true; end
    if (cmd == 'rampart')    then toggle(M.cfg.pld, 'autoRampart',  val, '/PLD'); return true; end

    -- /DRK
    if (cmd == 'lastresort' or cmd == 'lr') then toggle(M.cfg.drk, 'autoLastResort', val, '/DRK'); return true; end
    if (cmd == 'souleater' or cmd == 'se')  then toggle(M.cfg.drk, 'autoSouleater',  val, '/DRK'); return true; end
    if (cmd == 'weaponbash' or cmd == 'wb') then toggle(M.cfg.drk, 'autoWeaponBash', val, '/DRK'); return true; end
    if (cmd == 'arcane')     then toggle(M.cfg.drk, 'autoArcaneCircle', val, '/DRK'); return true; end

    -- /BRD
    if (cmd == 'march')     then toggle(M.cfg.brd, 'autoMarch',   val, '/BRD'); return true; end
    if (cmd == 'minuet')    then toggle(M.cfg.brd, 'autoMinuet',  val, '/BRD'); return true; end

    -- /RNG
    if (cmd == 'sharpshot')  then toggle(M.cfg.rng, 'autoSharpshot', val, '/RNG'); return true; end
    if (cmd == 'barrage')    then toggle(M.cfg.rng, 'autoBarrage',   val, '/RNG'); return true; end
    if (cmd == 'scavenge')   then toggle(M.cfg.rng, 'autoScavenge',  val, '/RNG'); return true; end

    -- /NIN (existing)
    if (cmd == 'shadows' or cmd == 'utsu') then
        toggle(M.cfg.nin, 'autoUtsusemi', val, '/NIN'); return true;
    end

    -- /DRG (existing)
    if (cmd == 'jumps')    then toggle(M.cfg.drg, 'autoJumps',   val, '/DRG'); return true; end
    if (cmd == 'shed')     then toggle(M.cfg.drg, 'shedOnAggro', val, '/DRG'); return true; end
    if (cmd == 'dpsjump')  then toggle(M.cfg.drg, 'dpsJumpOnCd', val, '/DRG'); return true; end

    -- /SAM (existing)
    if (cmd == 'hasso')    then toggle(M.cfg.sam, 'autoHasso',    val, '/SAM'); return true; end
    if (cmd == 'meditate') then toggle(M.cfg.sam, 'autoMeditate', val, '/SAM'); return true; end
    if (cmd == 'thirdeye') then toggle(M.cfg.sam, 'autoThirdEye', val, '/SAM'); return true; end

    -- /BLU
    if (cmd == 'cocoon')    then toggle(M.cfg.blu, 'autoCocoon',    val, '/BLU'); return true; end
    if (cmd == 'refueling') then toggle(M.cfg.blu, 'autoRefueling', val, '/BLU'); return true; end
    if (cmd == 'metallic')  then toggle(M.cfg.blu, 'autoMetallic',  val, '/BLU'); return true; end
    if (cmd == 'headbutt')  then toggle(M.cfg.blu, 'autoHeadButt',  val, '/BLU'); return true; end

    -- /COR
    if (cmd == 'rolls') then
        toggle(M.cfg.cor, 'autoRolls', val, '/COR');
        if (val == 'on') then M.resetCorRolls(); end
        return true;
    end
    if (cmd == 'reroll') then M.resetCorRolls(); M.echo('[Sub /COR] roll cycle reset'); return true; end

    -- /DNC
    if (cmd == 'waltz')     then toggle(M.cfg.dnc, 'autoWaltz',      val, '/DNC'); return true; end
    if (cmd == 'hastesamba' or cmd == 'hsamba') then toggle(M.cfg.dnc, 'autoHasteSamba', val, '/DNC'); return true; end
    if (cmd == 'drainsamba' or cmd == 'dsamba') then toggle(M.cfg.dnc, 'autoDrainSamba', val, '/DNC'); return true; end

    -- /SCH
    if (cmd == 'sublimation') then toggle(M.cfg.sch, 'autoSublimation', val, '/SCH'); return true; end
    if (cmd == 'lightarts')   then toggle(M.cfg.sch, 'autoLightArts',   val, '/SCH'); return true; end

    -- ============================================================
    -- Master toggles
    -- ============================================================
    if (cmd == 'sub') then
        local on = (val == 'on');
        local s = M.subJob();
        local sections = {
            WAR = { M.cfg.war, {'autoBerserk','autoAggressor','autoWarcry'} },
            MNK = { M.cfg.mnk, {'autoBoost','autoCounter','autoFocus','autoDodge'} },
            WHM = { M.cfg.whm, {'autoCureSelf','autoNa'} },
            BLM = { M.cfg.blm, {'autoAspir'} },
            RDM = { M.cfg.rdm, {'autoRefresh','autoHaste','autoPhalanx','autoStoneskin','autoBlink','autoAquaveil'} },
            PLD = { M.cfg.pld, {'autoShieldBash','autoSentinel','autoRampart'} },
            DRK = { M.cfg.drk, {'autoLastResort','autoWeaponBash','autoSouleater'} },
            BRD = { M.cfg.brd, {'autoMarch','autoMinuet'} },
            RNG = { M.cfg.rng, {'autoSharpshot','autoBarrage','autoScavenge'} },
            NIN = { M.cfg.nin, {'autoUtsusemi'} },
            DRG = { M.cfg.drg, {'autoJumps'} },
            SAM = { M.cfg.sam, {'autoHasso','autoMeditate','autoThirdEye'} },
            BLU = { M.cfg.blu, {'autoCocoon','autoRefueling','autoMetallic','autoHeadButt'} },
            COR = { M.cfg.cor, {'autoRolls'} },
            DNC = { M.cfg.dnc, {'autoWaltz','autoHasteSamba'} },
            SCH = { M.cfg.sch, {'autoSublimation','autoLightArts'} },
        };
        local sec = sections[s];
        if (sec) then
            for _, k in ipairs(sec[2]) do sec[1][k] = on; end
            M.echo('[Sub /'..s..'] All: '..(on and 'ON' or 'OFF'));
        else
            M.echo('[Sub] No automation defined for /'..s);
        end
        return true;
    end

    if (cmd == 'suballoff') then
        for _, section in pairs({M.cfg.war,M.cfg.mnk,M.cfg.whm,M.cfg.blm,M.cfg.rdm,
                M.cfg.pld,M.cfg.drk,M.cfg.brd,M.cfg.rng,M.cfg.nin,M.cfg.drg,M.cfg.sam,
                M.cfg.blu,M.cfg.cor,M.cfg.dnc,M.cfg.sch}) do
            for k, v in pairs(section) do
                if (type(v) == 'boolean') then section[k] = false; end
            end
        end
        M.echo('[Sub] ALL subjob automation disabled.');
        return true;
    end

    -- Server switch: change which private server this profile assumes.
    -- Persists only for the session -- SETUP.ps1 hard-writes the default
    -- into the file at install time. Use this to test a Phoenix behaviour
    -- while on Horizon or vice-versa.
    if (cmd == 'server') then
        if (val == 'horizon' or val == 'phoenix' or val == 'retail') then
            M.server = val;
            M.applyServerOverrides();
            print('[Sub] Server profile: '..M.server);
        else
            print('[Sub] Current server: '..M.server..'   (options: horizon, phoenix, retail)');
        end
        return true;
    end

    -- Verbose toggle: makes automation announce itself in the chat log.
    -- Default OFF so nothing gets written to Documents\My Games\FFXI\USER\<id>\LOG.
    if (cmd == 'verbose') then
        M.verbose = (val == 'on');
        -- One-shot raw print for confirmation; still writes to log so user knows
        -- what state they just left the flag in.
        print('[Sub] verbose: '..(M.verbose and 'ON' or 'OFF'));
        return true;
    end

    if (cmd == 'subdebug') then
        -- Force-flush debug output regardless of verbose flag (user asked).
        local wasVerbose = M.verbose;
        M.verbose = true;
        M.debug();
        M.verbose = wasVerbose;
        return true;
    end

    return false;
end

-- ---------------------------------------------------------------------------
-- Debug printer
-- ---------------------------------------------------------------------------
function M.debug()
    local s = M.subJob();
    M.echo('[Sub DEBUG] Main: /'..M.mainJob()..'  Sub: /'..s);
    M.echo('  HP: '..M.selfHpPct()..'%  MP: '..M.selfMpPct()..'%  TP: '..M.selfTp());
    M.echo('  Engaged: '..tostring(M.amEngaged())..'  Mob targeting me: '
          ..tostring(M.mobTargetingMe() ~= nil));

    local sections = {
        WAR = M.cfg.war, MNK = M.cfg.mnk, WHM = M.cfg.whm, BLM = M.cfg.blm,
        RDM = M.cfg.rdm, PLD = M.cfg.pld, DRK = M.cfg.drk, BRD = M.cfg.brd,
        RNG = M.cfg.rng, NIN = M.cfg.nin, DRG = M.cfg.drg, SAM = M.cfg.sam,
        BLU = M.cfg.blu, COR = M.cfg.cor, DNC = M.cfg.dnc, SCH = M.cfg.sch,
    };
    local cur = sections[s];
    if (cur) then
        M.echo('  Config for /'..s..':');
        for k, v in pairs(cur) do
            if (type(v) == 'boolean' or type(v) == 'number' or type(v) == 'string') then
                M.echo(string.format('    %s = %s', k, tostring(v)));
            end
        end
    else
        M.echo('  No automation configured for /'..s);
    end
end

return M;
