#!/usr/bin/env python3
"""Rebuild rechhar/data/abilities.lua from moves_from_checkmate.lua.

Keeps the existing M.lookup / INDEX / eraRank machinery intact.  Replaces
the DB{} block with Phoenix-authoritative data from checkmate, overlaying
a small override table for gaze reclassifications and era adjustments.
"""
import re, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
MOVES_LUA = HERE / 'out' / 'moves_from_checkmate.lua'
TARGET    = Path('/sessions/inspiring-amazing-thompson/mnt/Chharith/reChhar/addons/rechhar/data/abilities.lua')

# Moves that checkmate categorizes by shape ('cone') but are semantically
# a gaze (player should face AWAY, not sidestep).  reChhar wants these
# tagged 'gaze' so the alert reads "TURN AWAY" instead of "SIDESTEP".
GAZE_RECLASS = {
    'Stone Gaze', 'Mortal Ray', 'Hex Eye', 'Chaotic Eye', 'Charming Gaze',
    'Petro Eyes', 'Blaster', 'Baleful Gaze', 'Low Gaze',
    'Weakening Gaze', 'Breath Gaze', 'Jettatura',
    'Despotic Gaze', 'Shadow Spread', 'Dreamflower', 'Daydream',
    'Reaving Wind',       # Fenrir / HNM gaze
    'Blank Gaze Dispel',
}

# Era tagging.  Phoenix (WoTG-cap) and Horizon (ToAU-cap) both include
# base + ToAU; Phoenix also includes WoTG.  Default is 'base' so moves
# are shown on all era servers.  Override only when a move was ADDED by
# a specific expansion AND is absent on earlier-cap servers.
ERA_OVERRIDE = {
    # ToAU-added mob families (Aht Urhgan Whitegate, Besieged, Salvage, etc).
    'Soporific':     'toau',
    'Weakening Gaze':'toau',
    'Jettatura':     'toau',
    'Spinal Cleave': 'toau',   # Elvaan Executioner (ToAU areas)
    # WoTG-added
    'Despotic Gaze': 'wotg',
    'Shadow Spread': 'wotg',
    'Benthic Typhoon':'wotg',
    'Mortal Overture':'wotg',
    'Baleful Magilance':'wotg',
}

# ---------------------------------------------------------------------------

def parse_moves_lua(path: Path):
    """Parse the extractor's output into a list of (name, kind, note, radius, rng)."""
    out = []
    pat = re.compile(
        r"DB\[\'([^\']+)\'\]\s*=\s*\{\s*kind=\'([^\']+)\',\s*note=\'([^\']*)\'"
        r"(?:,\s*radius=([\d.]+))?(?:,\s*rng=([\d.]+))?\s*\};"
    )
    for line in path.read_text(encoding='utf-8').splitlines():
        m = pat.search(line)
        if not m: continue
        name, kind, note, radius, rng = m.groups()
        # Escape embedded quotes in note for Lua string literal
        safe_note = note.replace("\\", "\\\\").replace("'", "\\'")
        out.append((name, kind, safe_note, radius, rng))
    return out

def apply_overrides(entries):
    merged = []
    for name, kind, note, radius, rng in entries:
        if name in GAZE_RECLASS:
            kind = 'gaze'
        era = ERA_OVERRIDE.get(name, 'base')
        merged.append((name, kind, note, era, radius, rng))
    return merged

def emit(merged, out_path: Path):
    """Write new abilities.lua: new DB block + unchanged M.* tail."""
    header = '''-- ============================================================================
-- abilities.lua -- avoidable mob abilities, categorized by what dodges them.
--
-- SOURCE: checkmate v1.1.0 (KiplingFFXI/checkmate, derived from
--         phoenixffxi/Phoenix server code).  Regenerate by running:
--             tools/checkmate-extract/extract.py
--             tools/checkmate-extract/merge_rechhar.py
--
-- Categories:
--   gaze  -- target must face away from mob to resist
--   aoe   -- target must be out of radial AoE (run away)
--   cone  -- target must step out of a frontal cone (sidestep)
--   line  -- target must step off the mob->you line (step sideways)
--   track -- homing projectile; movement rarely helps but worth knowing
--
-- Eras:
--   base   : vanilla (default; all moves shown on era servers)
--   toau   : added in Treasures of Aht Urhgan
--   wotg   : added in Wings of the Goddess
--   retail : SoA/SoV/RoV only; filtered out on era-cap servers
--
-- NAME-keyed table. Chat text "The X readies Y." is matched against the
-- key Y (case-insensitive).  Only moves with a positional shape (not
-- 'single target') appear here, because single-target hits can't be
-- dodged by movement.
-- ============================================================================

local DB = {};

'''
    lines = [header]
    # Group by kind for readability.
    for kind_tag, label in [('gaze','Gazes (face away)'),
                            ('aoe', 'Area of Effect (run out)'),
                            ('cone','Frontal cones (sidestep)'),
                            ('line','Line attacks (step sideways)'),
                            ('track','Tracking / homing')]:
        batch = [e for e in merged if e[1] == kind_tag]
        if not batch: continue
        lines.append(f"-- {label}" + " " + "-"*(70 - len(label)))
        for name, kind, note, era, radius, rng in sorted(batch, key=lambda x: x[0]):
            parts = [f"kind='{kind}'", f"era='{era}'", f"note='{note}'"]
            if radius: parts.append(f"radius={radius}")
            if rng:    parts.append(f"rng={rng}")
            safe_name = name.replace("'", "\\'")
            lines.append(f"DB['{safe_name}'] = {{ " + ", ".join(parts) + " };")
        lines.append("")

    # Append the unchanged M.* module code from the existing file.
    existing = TARGET.read_text(encoding='utf-8')
    tail_start = existing.find('local M = {};')
    if tail_start < 0:
        tail_start = existing.find('local M = {}')
    if tail_start < 0:
        print("ERROR: couldn't locate 'local M = {}' in existing file.", file=sys.stderr)
        sys.exit(1)
    tail = existing[tail_start:]
    lines.append(tail)
    out_path.write_text("\n".join(lines), encoding='utf-8')
    print(f"wrote {len(merged)} entries to {out_path}")

def main():
    if not MOVES_LUA.exists():
        print(f"missing {MOVES_LUA}; run extract.py first", file=sys.stderr); sys.exit(1)
    entries = parse_moves_lua(MOVES_LUA)
    merged  = apply_overrides(entries)
    emit(merged, TARGET)

    # Report
    kinds = {}
    for _, kind, *_ in merged:
        kinds[kind] = kinds.get(kind, 0) + 1
    print("by kind:", kinds)

if __name__ == '__main__':
    main()
