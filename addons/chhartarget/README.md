# ChharTarget

Ashita v4 port of **TargetInfo** (Arcon / Windower, 2013-2017) for era servers — **Phoenix XI** and **HorizonXI**. Shows your current target's full ID, hex (short) ID, movement speed, and name, with one critical addition:

> **PH / NM annotation.** When you target a mob that's a known placeholder for a Notorious Monster, the HUD shows `PH FOR: <NM name>` — so you know whether to kill it (yes, respawn clock) or ignore it (not a PH).

## Install

Copy `addons/chhartarget/` into `<Ashita>/addons/`, then in game:

```
/addon load chhartarget
```

Or add it to your auto-load list in `scripts/default.txt`.

## Commands (`/chhartarget` or `/ct`)

```
/ct show | hide | toggle            show / hide HUD
/ct hex   on|off                    toggle hex index display
/ct full  on|off                    toggle full server ID display
/ct speed on|off                    toggle movement-speed %
/ct ph    on|off                    toggle PH/NM annotation
/ct add   <phname>=<nmname>         add a user PH entry at runtime
/ct count                           show how many PH entries are loaded
/ct dump                            dump current target to chat (name, IDs,
                                    status, HP%, speed, PH match)
/ct help
```

## The PH database (`ph_database.lua`)

- Keyed by **mob name** (lowercase, exact spelling). This is portable: it works on retail, Phoenix, Horizon, and anything else that uses the standard FFXI mob naming.
- An empty NM list `{}` means "this is a known NM/HNM target — not a PH, go for it."
- Add entries in-game with `/ct add Snipper=Hurkan` (saved for the session only). For permanent entries, edit `ph_database.lua` directly.

### Why names, not IDs

Mob IDs differ across retail / Horizon / Phoenix / LSB private-server builds. Names are consistent. This also means **this addon works on any era server** without modification — the ID display is purely informational.

### Seeded data

Ships with ~40 popular era NM/PH pairs from the common farming camps:
- **Ground kings / HNMs** (King Behemoth, Nidhogg, Fafnir, Adamantoise, Aspidochelone, Serket, King Vinegarroon)
- **Classic camp lotteries** (Leaping Lizzy, Valkurm Emperor, Jaggedy-Eared Jack, Bigmouth Billy, Pelican, Steelfleece Baldarich, Mindseeker, Argus, Mee Deggi, Snow Lizard, etc.)

If you camp an NM whose PH isn't listed, cross-reference **BG-Wiki** (every NM article has a "Placeholder" field) and add it via `/ct add`. The curated list grows community-driven.

## Credits

- Original **TargetInfo** by Arcon (Windower, 2013-2017), BSD license.
- Ashita v4 rewrite + PH database by Chharizard.
- PH facts cross-referenced against BG-Wiki and the LandSandBoat server scripts.
