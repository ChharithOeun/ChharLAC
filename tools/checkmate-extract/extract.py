#!/usr/bin/env python3
"""checkmate -> ChharLAC data extractor

Walks checkmate's data/zones/*.lua files (Phoenix-authoritative mob data,
generated from phoenixffxi/Phoenix source), executes each with lupa, and
emits two Lua-friendly outputs:

  moves_from_checkmate.lua  -- deduplicated move table for reChhar's abilities.lua
  nms_from_checkmate.lua    -- zone-tagged NM/lottery-mob entries for ChharTarget

Usage:
    python extract.py --checkmate <path-to-checkmate-repo-root> --out <dir>

Example:
    python extract.py \
        --checkmate /sessions/inspiring-amazing-thompson/ext/checkmate/checkmate \
        --out       /sessions/inspiring-amazing-thompson/mnt/Chharith/ChharLAC/tools/checkmate-extract/out
"""
import argparse, os, sys, json
from pathlib import Path

try:
    import lupa
    from lupa import LuaRuntime
except ImportError:
    print("pip install lupa --break-system-packages", file=sys.stderr); sys.exit(1)

# ---------------------------------------------------------------------------
# Lua execution
# ---------------------------------------------------------------------------

def exec_zone(path: Path):
    """Return the Lua table that `path` returns. None on failure."""
    lua = LuaRuntime(unpack_returned_tuples=True)
    try:
        src = path.read_text(encoding='utf-8')
        return lua.execute(src)
    except Exception as e:
        print(f"  skip {path.name}: {e}", file=sys.stderr)
        return None

def t2d(obj):
    """Lua table -> Python dict/list recursively (depth-limited)."""
    if obj is None or isinstance(obj, (bool, int, float, str, bytes)):
        return obj
    try:
        keys = list(obj.keys())
    except Exception:
        return str(obj)
    # Detect array vs dict
    if keys and all(isinstance(k, (int, float)) for k in keys):
        try:
            if sorted(keys) == list(range(1, len(keys) + 1)):
                return [t2d(obj[i]) for i in range(1, len(keys) + 1)]
        except Exception:
            pass
    out = {}
    for k in keys:
        try:
            out[k if not isinstance(k, bytes) else k.decode('utf-8', 'ignore')] = t2d(obj[k])
        except Exception:
            pass
    return out

# ---------------------------------------------------------------------------
# Shape -> reChhar kind mapping
# ---------------------------------------------------------------------------

SHAPE_TO_KIND = {
    'area around the monster': 'aoe',
    'area around the target':  'aoe',
    'front cone':              'cone',
    'line':                    'line',
    # 'single target' is NOT dodgeable via positioning -> excluded from reChhar
}

def pick_kind(details, notes_text, summary_text=''):
    """Return reChhar 'kind' for a move, or None to exclude.

    Gazes are often shape='single target' in Phoenix source because they
    hit one player, but the mechanic is 'face away to resist' -- these
    should be in rechhar so the user gets a TURN-AWAY alert.  We detect
    gazes via notes + summary text.
    """
    if not isinstance(details, dict):
        return None
    shape = (details.get('shape') or '').lower()
    hay = (notes_text + ' ' + summary_text).lower()
    # Gaze if the summary tags it as a gaze (checkmate uses "X: Y gaze" or
    # "gaze: X" phrasing in summaries); OR notes explicitly mention facing.
    is_gaze = ('gaze' in summary_text.lower()) or ('face the monster' in hay)
    if is_gaze:
        return 'gaze'
    return SHAPE_TO_KIND.get(shape)

# ---------------------------------------------------------------------------
# Walk zone + collect
# ---------------------------------------------------------------------------

def walk_zone(zone_id: int, data: dict, moves: dict, nms: list, blus: dict = None,
              phs: dict = None):
    """Mutate moves, nms, blus from the zone's monster list.
    Also mutate phs: name_lower -> { pops={NM...}, zone, mob_ids }.
    PH inference rule: same zone + same family as a Lottery NM + mob_id
    within +/- NEIGHBOR_WINDOW of the NM's mob_id.
    """
    monsters = (data or {}).get('monsters') or []
    if not isinstance(monsters, list):
        return
    zone_cache = []   # populated by process_family
    for fam in monsters:
        if isinstance(fam, dict):
            process_family(zone_id, fam, moves, nms, blus, zone_cache)

    if phs is None:
        return
    NEIGHBOR_WINDOW = 8   # mob_id proximity (empirically covers lottery PH groups)
    # Index non-NM mobs by family.
    by_fam = {}
    for m in zone_cache:
        if m['family'] and m['spawn'] and 'lottery' not in m['spawn'].lower() \
                and 'timed' not in m['spawn'].lower() \
                and 'scripted' not in m['spawn'].lower():
            by_fam.setdefault(m['family'], []).append(m)
    # For each NM, find same-family mobs with adjacent mob_ids.
    for nm in zone_cache:
        if not nm['family'] or not nm['spawn']: continue
        if 'lottery' not in nm['spawn'].lower(): continue
        candidates = by_fam.get(nm['family'], [])
        for nm_id in nm['ids']:
            for ph in candidates:
                near = [i for i in ph['ids'] if abs(i - nm_id) <= NEIGHBOR_WINDOW]
                if not near: continue
                key = ph['name'].lower()
                existing = phs.get(key)
                if not existing:
                    existing = dict(name=ph['name'], zone=zone_id, mob_ids=[],
                                     pops=[])
                    phs[key] = existing
                for i in near:
                    if i not in existing['mob_ids']:
                        existing['mob_ids'].append(i)
                if nm['name'] not in existing['pops']:
                    existing['pops'].append(nm['name'])

def process_family(zone_id: int, fam: dict, moves: dict, nms: list, blus: dict = None,
                   zone_cache: list = None):
    name = fam.get('name')
    if not isinstance(name, str):
        return
    ids = fam.get('ids') or []
    info = fam.get('info') or {}
    spawn = info.get('spawn') or {}
    spawn_val = spawn.get('value') if isinstance(spawn, dict) else None
    claim = info.get('claim') or {}
    claim_val = claim.get('value') if isinstance(claim, dict) else None
    dangers = info.get('dangers') or {}
    family_val = None
    fam_field = info.get('family')
    if isinstance(fam_field, dict):
        family_val = fam_field.get('value')
    # Cache every mob family for post-pass PH inference.
    if zone_cache is not None:
        zone_cache.append(dict(
            name=name, ids=[int(i) for i in ids if isinstance(i, (int, float))],
            family=family_val, spawn=spawn_val, claim=claim_val,
        ))

    # Collect dangers (every move each family can use)
    if isinstance(dangers, dict):
        entries = dangers.get('entries') or []
        if isinstance(entries, list):
            for e in entries:
                if isinstance(e, dict):
                    mname = e.get('name')
                    if not isinstance(mname, str):
                        continue
                    details = e.get('details') or {}
                    notes_text = ' '.join(details.get('notes') or []) if isinstance(details, dict) else ''
                    kind = pick_kind(details, notes_text, e.get('summary') or '')
                    if not kind:
                        continue  # single-target / unknown -> excluded
                    summary = e.get('summary') or mname
                    radius = (details or {}).get('effect_radius') or (details or {}).get('cone_length')
                    rng    = (details or {}).get('activation_range')
                    # First-write wins; same-name moves across zones have identical shape.
                    if mname not in moves:
                        moves[mname] = dict(kind=kind, summary=summary,
                                            radius=radius, activation_range=rng,
                                            seen_in_zones=[])
                    if zone_id not in moves[mname]['seen_in_zones']:
                        moves[mname]['seen_in_zones'].append(zone_id)

    # Collect BLU-learnable spells for every mob family (not just NMs).
    # Key by lowercase name so chhartarget can look up by whatever name
    # the target widget shows.  We overwrite with the richest entry
    # (first-write typically wins, but the schema is identical across
    # zones for the same family name).
    blue = info.get('blue') or {}
    spells = blue.get('spells') if isinstance(blue, dict) else None
    if blus is not None and isinstance(spells, list) and spells:
        key = name.lower()
        if key not in blus:
            blus[key] = dict(name=name, spells=[])
        existing_ids = {s.get('id') for s in blus[key]['spells']}
        for s in spells:
            if isinstance(s, dict) and s.get('id') not in existing_ids:
                blus[key]['spells'].append(dict(
                    id    = int(s.get('id') or 0),
                    name  = str(s.get('name') or ''),
                    level = int(s.get('level') or 0),
                ))

    # Collect NMs: any mob where spawn is Lottery, Timed, or Scripted (NM pop)
    if isinstance(spawn_val, str) and any(k in spawn_val.lower()
                                           for k in ('lottery', 'timed', 'scripted')):
        nms.append(dict(
            zone_id    = zone_id,
            name       = name,
            mob_ids    = ids if isinstance(ids, list) else [],
            spawn      = spawn_val,
            claim      = claim_val,
        ))

# ---------------------------------------------------------------------------
# Emit Lua files
# ---------------------------------------------------------------------------

def lua_q(s):
    if s is None: return 'nil'
    return "'" + str(s).replace("\\", "\\\\").replace("'", "\\'") + "'"

def emit_moves(moves: dict, out_path: Path):
    lines = [
        "-- Auto-generated from checkmate (phoenixffxi/Phoenix source).",
        "-- Do NOT edit by hand; re-run tools/checkmate-extract/extract.py.",
        "-- Schema per entry:",
        "--   kind   = 'aoe' | 'cone' | 'line' | 'gaze'",
        "--   note   = short summary from checkmate",
        "--   radius = effect_radius (aoe) or cone_length (cone), yalms",
        "--   rng    = activation_range, yalms",
        "--",
        "local DB = {};",
        "",
    ]
    for name in sorted(moves.keys()):
        e = moves[name]
        parts = ["kind=" + lua_q(e['kind']), "note=" + lua_q(e['summary'])]
        if e.get('radius') is not None:
            try: parts.append(f"radius={float(e['radius']):.1f}")
            except Exception: pass
        if e.get('activation_range') is not None:
            try: parts.append(f"rng={float(e['activation_range']):.1f}")
            except Exception: pass
        lines.append(f"DB[{lua_q(name)}] = {{ {', '.join(parts)} }};")
    lines.append("")
    lines.append("return DB;")
    out_path.write_text("\n".join(lines), encoding='utf-8')
    print(f"[moves] wrote {len(moves)} entries -> {out_path}")

def emit_blus(blus: dict, out_path: Path):
    """Emit BLU[name_lower] = { name='X', spells={ { name='Y', id=N, lvl=L }, ... } }."""
    lines = [
        "-- Auto-generated from checkmate (phoenixffxi/Phoenix source).",
        "-- Do NOT edit by hand; re-run tools/checkmate-extract/extract.py.",
        "-- Schema: BLU[mob_name_lower] = { name='Mob Name',",
        "--             spells={ { name='Spell', id=NNN, lvl=L }, ... } }",
        "--",
        "local BLU = {};",
        "",
    ]
    for key in sorted(blus.keys()):
        e = blus[key]
        spell_parts = []
        for s in sorted(e['spells'], key=lambda x: x.get('level', 0)):
            spell_parts.append(
                "{ name=" + lua_q(s['name']) +
                f", id={s['id']}, lvl={s['level']} }}"
            )
        spells_str = "spells={ " + ", ".join(spell_parts) + " }"
        lines.append(
            f"BLU[{lua_q(key)}] = {{ name={lua_q(e['name'])}, {spells_str} }};"
        )
    lines.append("")
    lines.append("return BLU;")
    out_path.write_text("\n".join(lines), encoding='utf-8')
    print(f"[blu] wrote {len(blus)} mobs with learnable spells -> {out_path}")

def emit_phs(phs: dict, out_path: Path):
    """Emit inferred PH[name_lower] = { pops={...}, zone, mob_ids_inferred }."""
    lines = [
        "-- Auto-generated from checkmate (phoenixffxi/Phoenix source).",
        "-- Do NOT edit by hand; re-run tools/checkmate-extract/extract.py.",
        "-- Schema: PHS[ph_name_lower] = { pops={'NM Name', ...}, zone=N,",
        "--                                 mob_ids_inferred={...}, name='PH Name' }",
        "-- Inferred by: same zone + same family as a Lottery NM + mob_id",
        "-- within +/- 8 of the NM's mob_id (typical lottery PH layout).",
        "-- ph_database.lua's existing user-authored entries win over this",
        "-- data; mob_ids_inferred is used as hex_range only when the user",
        "-- hasn't provided ph_hex_ids / hex_range on this server.",
        "--",
        "local PHS = {};",
        "",
    ]
    for key in sorted(phs.keys()):
        e = phs[key]
        pops_str = ", ".join(lua_q(p) for p in e['pops'])
        ids = sorted(set(e['mob_ids']))
        ids_str = ", ".join(str(i) for i in ids)
        lines.append(
            f"PHS[{lua_q(key)}] = {{ name={lua_q(e['name'])}, "
            f"zone={e['zone']}, pops={{ {pops_str} }}, "
            f"mob_ids_inferred={{ {ids_str} }} }};"
        )
    lines.append("")
    lines.append("return PHS;")
    out_path.write_text("\n".join(lines), encoding='utf-8')
    print(f"[phs] wrote {len(phs)} inferred PH entries -> {out_path}")

def emit_nms(nms: list, out_path: Path):
    lines = [
        "-- Auto-generated from checkmate (phoenixffxi/Phoenix source).",
        "-- Do NOT edit by hand; re-run tools/checkmate-extract/extract.py.",
        "-- Schema: PH[name_lower] = { zone=N, mob_ids={...}, spawn='Lottery',",
        "--                            claim='Claimshield 5 seconds' }",
        "-- Merge logic in ph_database.lua should prefer user-learned hex ids",
        "-- over anything derived here.",
        "--",
        "local PH = {};",
        "",
    ]
    for e in sorted(nms, key=lambda x: (x['zone_id'], x['name'])):
        key = e['name'].lower()
        parts = [f"zone={e['zone_id']}"]
        if e.get('mob_ids'):
            ids_str = ', '.join(str(int(i)) for i in e['mob_ids'] if isinstance(i, (int, float)))
            if ids_str:
                parts.append("mob_ids={ " + ids_str + " }")
        if e.get('spawn'):  parts.append("spawn=" + lua_q(e['spawn']))
        if e.get('claim'):  parts.append("claim=" + lua_q(e['claim']))
        parts.append("name=" + lua_q(e['name']))
        lines.append(f"PH[{lua_q(key)}] = {{ {', '.join(parts)} }};")
    lines.append("")
    lines.append("return PH;")
    out_path.write_text("\n".join(lines), encoding='utf-8')
    print(f"[nms] wrote {len(nms)} entries -> {out_path}")

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--checkmate', required=True, help='path to checkmate repo root (contains checkmate/data/zones)')
    ap.add_argument('--out',       required=True, help='output directory')
    ap.add_argument('--limit',     type=int, default=0, help='limit to N zones for testing (0 = all)')
    args = ap.parse_args()

    zones_dir = Path(args.checkmate) / 'checkmate' / 'data' / 'zones'
    if not zones_dir.exists():
        zones_dir = Path(args.checkmate) / 'data' / 'zones'
    if not zones_dir.exists():
        print(f"zones dir not found under {args.checkmate}", file=sys.stderr); sys.exit(1)

    out = Path(args.out); out.mkdir(parents=True, exist_ok=True)

    moves = {}
    nms   = []
    blus  = {}
    phs   = {}
    zone_files = sorted(zones_dir.glob('*.lua'), key=lambda p: int(p.stem) if p.stem.isdigit() else 0)
    if args.limit:
        zone_files = zone_files[:args.limit]
    for i, zf in enumerate(zone_files, 1):
        zone_id = int(zf.stem) if zf.stem.isdigit() else 0
        tbl = exec_zone(zf)
        if tbl is None: continue
        data = t2d(tbl)
        walk_zone(zone_id, data, moves, nms, blus, phs)
        if i % 20 == 0:
            print(f"  processed {i}/{len(zone_files)} zones ... moves={len(moves)}, nms={len(nms)}, blu-mobs={len(blus)}, phs={len(phs)}", file=sys.stderr)

    emit_moves(moves, out / 'moves_from_checkmate.lua')
    emit_nms(nms, out / 'nms_from_checkmate.lua')
    emit_blus(blus, out / 'blu_from_checkmate.lua')
    emit_phs(phs, out / 'phs_from_checkmate.lua')
    (out / 'summary.json').write_text(json.dumps(
        dict(zones=len(zone_files), moves=len(moves), nms=len(nms),
             blu_mobs=len(blus), phs=len(phs)),
        indent=2), encoding='utf-8')
    print(f"\nDone. zones={len(zone_files)} moves={len(moves)} nms={len(nms)} blu_mobs={len(blus)} phs={len(phs)}")

if __name__ == '__main__':
    main()
