# ChharDig

Single-box chocobo digging helper for Phoenix XI (and Horizon XI with
caveats). Ashita v4.

## IMPORTANT -- Read first

**Automated digging is prohibited on most private servers.** Phoenix and
Horizon both have active GM teams that watch for it, use AFK-check
prompts, and investigate players reported for suspicious cadence. The
"max paranoia" safety floor built into this addon reduces detection
probability; it does **not** eliminate it. Use at your own risk. You
own the account action if you get banned.

## What it does

Loops `/dig` at human-shaped intervals while watching your inventory,
your riding time, your /tells, and GM-level packet flags. Automatically
walks to a user-recorded zone-line waypoint and dismounts when:

- Gysahl Greens run out (configurable floor),
- Chocobo riding time drops below the configured minimum (default 5 min),
- Daily find cap of 100 is reached,
- You run `/chd exit` manually.

## Safety architecture

- **Metacast `sentinel.lua`** vendored verbatim. Decodes packet `0x00D`
  for GM level, HackMove / wallhack flags, "hidden GM" bit. Any of
  these -> hard stop + `/logout`.
- **Metacast `realism.lua`** vendored verbatim. Log-normal cooldowns
  (never uniform), 15% short distractions (6-25s), 2% long lapses
  (40-150s), 8%/hour fatigue drift reset by breaks, soft-edge jitter
  so values never pile up on exact numbers.
- **Staff name whitelist.** Any /tell from a configured staff name ->
  hard stop + `/logout`.
- **AFK check prompt detection.** `_CUSTOM_MENU` / GM prompt type-12
  chat -> hard stop + `/logout`. (Horizon's custom NPCs that use the
  same packet are whitelisted via sentinel's `MENU_NPCS`.)
- **Suspicion scoring.** sentinel's 15-min rolling window; threshold = 2
  in max-paranoia mode (stricter than Metacast's 3).
- **Scheduled breaks.** 45-75 min dig block, 7-14 min break,
  randomized ±20%.

## Data authority

`digdata.lua` is a verbatim vendor from
[Skold177/PhoenixTracker](https://github.com/Skold177/PhoenixTracker)
which generates its tables from the Phoenix server source at
`modules/phoenix/lua/globals/hobbies/chocobo_digging/`. So the cooldowns,
rank table, hit rates, item weights, and zone pools in this addon are
**the exact numbers the Phoenix server uses**. Not guesses, not retail
estimates.

| Field | Source |
|---|---|
| cooldowns 15/10/5/3s | `digdata.lua.accuracy` + Phoenix source |
| 60s post-zone -5/rank | Phoenix source |
| 100/day account cap | Phoenix source |
| rank hit rates 30-55% | `digdata.lua.accuracy` |
| per-zone item pools | `digdata.lua.zones` |

## Quick start

```
/addon load chhardig
/chd skill 55                 # tell it your wing skill once
/chd staff Rajka, Luckystrike  # names of known GMs (hard-stops on their tells)
# Walk to your zone-line safe spot:
/chd mark zoneline
# Walk to the halfway point you want the bot to pass through on exit:
/chd mark halfway
# Finally walk to the dig spot:
/chd mark home
/chd exitroute halfway,zoneline
# Mount up, equip greens, point camera forward along the exit path.
/chd on
```

The bot will dig until greens run low, then walk `halfway -> zoneline`
and dismount.

## Pathing limits (v1)

Keyboard emulation only drives **W (forward)**. The character does not
auto-turn to face each waypoint. Record waypoints along a path your
chocobo can walk forward through without turning, OR face each
waypoint manually before enabling auto-exit. A smarter facing primitive
(camera-heading read + A/D nudges) is on the v2 list.

The stuck watchdog bails after 2s of no movement -- if you tab out of
the game window, keyboard events don't reach the game and the walk
aborts cleanly.

## Commands

```
/chd on | off               start / stop the loop
/chd status                 show counts, flags, waypoints, exit route
/chd mark <name>            save current position as a waypoint in this zone
/chd wps                    list this zone's waypoints
/chd exitroute a,b,c        set the waypoints the exit sequence will walk
/chd exit                   trigger exit sequence now
/chd clear                  clear hard-stop (fix the root cause first)
/chd skill <N>              set wing skill level (e.g. 55 = rank 5)
/chd staff <names>          comma-sep staff list for hard-stop /tells
/chd paranoia max|metacast  bulk tuning preset
/chd debug                  toggle verbose
```

## Credits

- **PhoenixTracker** (Skold177, grimwaldr, Slowed) for `digdata.lua`.
- **Metacast** author for `sentinel.lua` + `realism.lua`.
- **Phoenix server team** for publishing the server source.

## Not-doing list (v1)

- No multibox orchestration (single-box by design).
- No camera-heading read; no auto-face-target.
- No daily-cap carry across characters on the same account (Phoenix caps
  per-account; the addon only sees one character).
- No OpenCV / screen-reading. Everything is packet / chat / memory-based.
- No packet injection for movement (keyboard emulation only -- forged
  position packets get snapped back and look obviously bot-like).
