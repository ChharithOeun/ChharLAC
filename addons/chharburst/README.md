# ChharBurst

Auto magic-burst sidecar for the Chharizard LuAshitaCast profile set.
Ashita v4. Logic ported from [ekrividus/autoMB](https://github.com/ekrividus/autoMB)
(MIT); action-packet parsing borrowed from Chains (Ivaar / atom0s).

## What it does

Watches incoming action packets. When a skillchain *closes* on a target
your party owns, within range, and your current job can cast an
appropriate spell, it queues the burst spell automatically.

Covers all the standard chain closes (Light/Darkness/Fragmentation/
Fusion/Distortion/Gravitation + lv1/2 variants + Radiance/Umbra).

## Jobs covered

| Job | Default cast types |
|-----|---|
| BLM | spell → ga → ja → ra |
| RDM | spell → ra → ga |
| SCH | helix → spell → ga → ra |
| WHM | white (Banish) → holy |
| DRK | drain → spell |
| GEO | spell → ga |
| NIN | jutsu |
| BLU | spell |

If you want a different cast type for your current job, use
`/chb cast <type>`.

## Quick start

```
/addon load chharburst
/chb on
/chb cast spell       # or helix / ga / ra / ja / jutsu / white / holy / drain
/chb tier 3
```

Watch the chat for `[chharburst] skillchain: Fusion [Light, Fire]` + the
spell it picks.

## Commands

```
/chb on | off | toggle
/chb cast <type>              spell | helix | ga | ja | ra | jutsu | white | holy | drain
/chb tier <N>                 1..6 (1..3 for jutsu, 1..2 for helix/holy)
/chb mp <N>                   don't burst below this MP floor
/chb delay <sec>              seconds after close before casting (default 0.6)
/chb range <yalms>            max distance to target (default 22)
/chb day | weather            toggle day / weather element preference
/chb target                   toggle auto target-swap
/chb gs                       toggle "gs c bursting" echo
/chb show sc | spell          toggle each chat echo
/chb debug                    toggle verbose output
/chb status                   show current settings
```

## Job-file integration (per-job toggle)

The ChharLAC job templates (BLM, RDM, SCH, WHM) read a
`cfg.autoBurst` flag in their OnLoad hook. Setting it to true will
`/addon load chharburst; /chb on` with sensible per-job defaults
(e.g. SCH loads with `cast=helix`, WHM with `cast=white`).

To disable for one job, set `cfg.autoBurst = false` at the top of
that job's `.lua` file in your character folder.

## Safety

* MP floor (`/chb mp N`): refuses to cast if MP would drop below N.
* Range gate: 22 yalms by default; bursts within that range only.
* Alliance-only: only bursts on mobs claimed by your party/alliance.
* 1.5-second close-debounce: multiple actions from the same closing
  WS can't double-fire.
* One burst per close.

## Known limitations

* Doesn't check spell recast before queuing -- if the chosen spell is
  on cooldown, the game will just refuse. Tier step-down (autoMB's
  feature) not yet implemented.
* No double-burst support.
* Day/weather preference is parsed but element preference order
  currently just hits the first match from Thunder/Ice/Wind/Fire/
  Water/Earth/Dark/Light.
* AoE elements (Thundaga target → ally) are *not* used; single-target
  only.

## Credits

* Ekrividus / autoMB -- original algorithm, defaults, skillchain table.
* Ivaar / atom0s / Chains -- action-packet parser.
* Chharizard -- Ashita v4 port + job-aware cast selection + ChharLAC
  integration.
