# ChharLAC

<!-- Phoenix-flame rule, neon-brick aesthetic -->
```
     🔥🔥🔥   C H H A R L A C   🔥🔥🔥
     ────────────────────────────────────
     LuAshitaCast profiles for FFXI
     Horizon XI  •  Phoenix XI  •  retail
     Era-cap (75), WoTG-ready (SCH / DNC)
     ────────────────────────────────────
```

[![License: MIT](https://img.shields.io/badge/License-MIT-cyan.svg?style=for-the-badge)](LICENSE)
[![Server: Horizon](https://img.shields.io/badge/Horizon-XI-ff6b35?style=for-the-badge)](https://horizonxi.com)
[![Server: Phoenix](https://img.shields.io/badge/Phoenix-XI-ff5f87?style=for-the-badge)](https://phoenix-xi.com)
[![LAC: v2.12](https://img.shields.io/badge/LuAshitaCast-v2.12%2B-ffd700?style=for-the-badge)](https://github.com/ThornyFFXI/LuAshitacast)
[![Jobs: 22](https://img.shields.io/badge/jobs-22%20profiles-00ffff?style=for-the-badge)]()

**All 22 FFXI job profiles for Ashita v4 LuAshitaCast, wired to a shared subjob-automation library.**

Era-progressive gear (RSE → HQ crafted → mission → salvage/nyzul/limbus for ToAU jobs, WoTG relic for SCH/DNC). Drop into Ashita, run the setup script, `/lac reload`, and everything works.

---

## What's in here

- **`subjob_features.lua`** — shared automation library covering every usable subjob:
  /WAR /MNK /WHM /BLM /RDM /THF /PLD /DRK /BRD /RNG /NIN /DRG /SAM /BLU /COR /DNC /SCH
  - Event-driven where it matters (Shield Bash on cast, Third Eye on aggro, Utsusemi shadow refresh, hate-shed Super Jump)
  - Threshold-gated where risky (Waltz at HP%, Aspir at MP%, Souleater above HP floor)
  - **All automation defaults OFF.** `/lac fwd sub on` enables the sensible bundle for whatever sub you're wearing.

- **22 job profiles** — era-progressive gear with aspirational slots that silently skip when the item isn't yet owned

- **`_TEMPLATE.lua`** — canonical starter for future jobs, already wired to Sub

- **`SETUP.ps1`** — one-time: prompts for character name + player ID + server, bakes everything in

- **`DEPLOY-TO-PHOENIX.ps1`** — one-click copy from Horizon install path → Phoenix install path, auto-detects your character folders

---

## Install

1. **Clone or download** this repo somewhere convenient (not Program Files)
2. **Double-click `SETUP.ps1`** — asks for character name, player ID, server (Horizon / Phoenix / retail)
3. **Copy** the generated `profiles/<YourName>_<ID>/` folder into your Ashita install at
   `<Ashita>\config\addons\luashitacast\`
4. In-game: `/addon load luashitacast` then `/lac load <JOB>`

Dual-boxing Horizon AND Phoenix? Run `DEPLOY-TO-PHOENIX.ps1` after the Horizon setup — it clones the profile into Phoenix's install path with the right server flag baked in.

---

## Server support

| Server | Cap | SCH / DNC | Notes |
|---|---|---|---|
| **Horizon XI** | ToAU (75) | Not yet | 18 playable jobs |
| **Phoenix XI** | ToAU (75) | Not yet | Same era as Horizon; WoTG planned |
| **Retail** | Full | ✓ | All 22 jobs |

Switch at runtime: `/lac fwd server horizon|phoenix|retail`. When Phoenix unlocks WoTG, two-line flip in `subjob_features.lua` (`M.jobsByServer.phoenix.SCH = true`) and everything else is already in place.

---

## Server rules — read this

Auto-JA-on-cooldown may be classified as botting on private servers. This library:

- Defaults every auto-feature to OFF
- Biases toward **event-driven** (fires on aggro, on cast, on HP drop) over pure cooldown loops
- Keeps all chat output silent by default — nothing writes to `Documents\My Games\FFXI\USER\<ID>\LOG\` unless you flip `/lac fwd verbose on` for debugging

Verify your server's TOS before enabling anything, and enable one feature at a time.

---

## Related

- 🔥 [**ChharClear**](https://github.com/ChharithOeun/ChharClear) — FFXI log + crash-dump cleaner, wiki mirrorer, task scheduler
- 🔥 [**reChhar**](https://github.com/ChharithOeun/reChhar) — Ashita port of the React addon (auto-face-away during gaze attacks)
- 🔥 [**Chharizard**](https://github.com/ChharithOeun/Chharizard) — the parent FFXI toolkit (Chharbar, Chharcam, Chharsai, Chhargear)

---

## Credits

Framework: [Thorny's LuAshitaCast](https://github.com/ThornyFFXI/LuAshitacast)
Author: Chharith / ChharithOeun
License: MIT
