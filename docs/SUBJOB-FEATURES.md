# Subjob features — what each one actually does

Read this to understand what happens when you flip a switch.

## Tier 1: tank / melee subs

**`/WAR`** — five toggleable self-buffs. Berserk/Aggressor/Warcry/Defender fire while engaged, off cd. Provoke is special: fires only when `provokeOnHateLoss` is true AND you are NOT currently being targeted (i.e. hate slipped to someone else).

**`/MNK`** — Boost stacking pre-WS, Counterstance stance upkeep, Focus and Dodge as one-shot buffs on engage.

**`/PLD`** — three reactive tools: Shield Bash fires when the mob is casting (interrupt), Sentinel fires when you're NOT being targeted (hate-loss reclaim), Rampart fires when self HP drops below 60%.

**`/DRK`** — Last Resort while engaged; Souleater only above 70% self HP (safety floor); Weapon Bash on mob cast for stun.

**`/THF`** — no automatic ticks. All commands are one-shot (`/lac fwd flee`, `/lac fwd steal`, etc.) fired on demand.

## Tier 2: support / hybrid subs

**`/WHM`** — self-Cure at HP threshold, iterating Cure III → II → Cure until one is off cooldown. Auto-Na iterates a debuff table (poison → Poisona, paralysis → Paralyna, etc.) and casts whichever matches an active debuff icon.

**`/BLM`** — Aspir when self MP drops below the configured %. Prefers Aspir II if known.

**`/RDM`** — full self-buff sweep on a slow cadence (default 20s). Casts one missing buff per tick to avoid queue spam, in priority order: Refresh → Haste → Phalanx → Stoneskin → Blink → Aquaveil.

**`/BRD`** — song upkeep for a configured March and Minuet. Because song slots are dynamic in memory, we can't cleanly check "is Victory March up" — instead the library relies on the spell recast to gate refires. Set `M.cfg.brd.marchName` / `minuetName` in your profile.

**`/RNG`** — Sharpshot / Barrage pre-WS at TP ≥ 900; Scavenge while idle.

## Tier 3: NIN / DRG / SAM

**`/NIN`** — Utsusemi shadow refresh. Checks for Copy Image buff (retail id 66, also 444/445 on some servers). If missing while engaged, casts Ni if off cd; falls back to Ichi.

**`/DRG`** — event-driven jump management. If a mob is targeting you AND `shedOnAggro` is on: Super Jump if off cd, else High Jump. Otherwise Jump on cd for TP/DPS.

**`/SAM`** — Hasso stance upkeep while engaged; Meditate when TP drops below `meditateTpBelow` (default 900); Third Eye on aggro (event-driven, not on cooldown).

## Tier 4: ToAU subs (Horizon)

**`/BLU`** — Cocoon PDT, Refueling haste, Metallic Body stoneskin-alike (all self-buffs while engaged/off cd); Head Butt on mob cast for stun.

**`/COR`** — auto-roll cycle. Fires primary roll, then on next tick fires secondary. Only rolls when idle + out of combat. Bust detection is left to the user — `/lac fwd reroll` resets the state.

## Tier 5: WoTG subs (Phoenix)

**`/DNC`** — Curing Waltz at self HP threshold, walking through III → II → I until it finds one both TP-affordable and off cd. Haste Samba and Drain Samba upkeep while engaged (event-driven; buff-checked before recast).

**`/SCH`** — Sublimation charging while idle; Light Arts stance upkeep.

## Not covered

- **`/BST`** — pet management is manual by design; auto-charming or auto-summoning a jug is too situational.
- **`/SMN`** — BP macros are player-authored; the sub doesn't warrant automation.
- **`/PUP`** — automaton management belongs to PUP main; sub-only players get no benefit.
- **`/GEO` / `/RUN`** — post-WoTG, not in scope for this repo.

If you play a PUP or SMN main, use those job profiles' own HandleCommand hooks for automation — the sub library steps aside.
