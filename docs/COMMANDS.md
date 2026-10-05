# Command reference

All commands go through LuAshitaCast's forwarder: `/lac fwd <command> [args]`.

## Master toggles

| Command | Effect |
|---|---|
| `/lac fwd sub on` | Enable the sensible bundle for whatever subjob is currently equipped |
| `/lac fwd sub off` | Disable that same bundle |
| `/lac fwd suballoff` | Panic-off ALL subjob automation across every sub |
| `/lac fwd verbose on\|off` | Show / hide automation chat lines. **Default OFF** so nothing is written to the FFXI chat log file. |
| `/lac fwd subdebug` | One-shot state dump (bypasses verbose, always prints) |

**Log hygiene:** All chat output goes through `Sub.echo()` — self-echo only, never `/say`. When verbose is off (the default), nothing is written to the chat log file at all. To wipe existing log files, run `CLEAR-LOGS.ps1` from the repo root while FFXI is closed.

## Per-subjob

### /WAR

| Command | Effect |
|---|---|
| `/lac fwd berserk on\|off` | Auto-Berserk while engaged, off cd |
| `/lac fwd aggressor on\|off` | Auto-Aggressor while engaged |
| `/lac fwd warcry on\|off` | Auto-Warcry self-buff |
| `/lac fwd wardef on\|off` | Auto-Defender (tanking only) |
| `/lac fwd voke on\|off` | Provoke only when NOT being targeted (hate reclaim) |

### /MNK

| `/lac fwd boost on\|off` | Auto-Boost (stack pre-WS) |
| `/lac fwd focus on\|off` | Auto-Focus |
| `/lac fwd dodge on\|off` | Auto-Dodge |
| `/lac fwd counter on\|off` | Auto-Counterstance |

### /WHM

| `/lac fwd selfcure on\|off` | Auto-Cure at 55% HP (tiered: Cure III → II → I) |
| `/lac fwd na on\|off` | Auto-Na spells (Poisona/Paralyna/Blindna/etc) |
| `/lac fwd divine on\|off` | Auto-Divine Seal |

### /BLM

| `/lac fwd aspir on\|off` | Auto-Aspir when MP < 30% |
| `/lac fwd esell on\|off` | Auto-Elemental Seal |

### /RDM

| `/lac fwd refresh on\|off` | Auto-Refresh self |
| `/lac fwd haste on\|off` | Auto-Haste self |
| `/lac fwd phalanx on\|off` | Auto-Phalanx |
| `/lac fwd ss on\|off` | Auto-Stoneskin |
| `/lac fwd blink on\|off` | Auto-Blink |
| `/lac fwd aquaveil on\|off` | Auto-Aquaveil |

### /THF (all on-demand)

| `/lac fwd flee` | Fire Flee now |
| `/lac fwd steal` | Fire Steal on current target |
| `/lac fwd hide` | Fire Hide |
| `/lac fwd sa` | Sneak Attack setup |
| `/lac fwd ta` | Trick Attack setup |

### /PLD

| `/lac fwd sb on\|off` | Auto Shield Bash to interrupt mob casts |
| `/lac fwd sentinel on\|off` | Sentinel when not being targeted |
| `/lac fwd rampart on\|off` | Rampart at 60% HP |

### /DRK

| `/lac fwd lr on\|off` | Auto Last Resort |
| `/lac fwd se on\|off` | Auto Souleater (only when HP > 70%) |
| `/lac fwd wb on\|off` | Auto Weapon Bash on mob cast |
| `/lac fwd arcane on\|off` | Auto Arcane Circle |

### /BRD

| `/lac fwd march on\|off` | Keep configured March song up |
| `/lac fwd minuet on\|off` | Keep configured Minuet up |

### /RNG

| `/lac fwd sharpshot on\|off` | Pre-WS Sharpshot at TP ≥ 900 |
| `/lac fwd barrage on\|off` | Pre-WS Barrage at TP ≥ 900 |
| `/lac fwd scavenge on\|off` | Scavenge while idle |

### /NIN

| `/lac fwd shadows on\|off` | Auto-refresh Utsusemi (Ni preferred) |
| `/lac fwd utsu on\|off` | Alias for shadows |

### /DRG

| `/lac fwd jumps on\|off` | Master toggle for jumps |
| `/lac fwd shed on\|off` | Super/High Jump on aggro to shed hate |
| `/lac fwd dpsjump on\|off` | Regular Jump on cd for TP/DPS |

### /SAM

| `/lac fwd hasso on\|off` | Auto-Hasso stance upkeep |
| `/lac fwd meditate on\|off` | Meditate at TP < 900 |
| `/lac fwd thirdeye on\|off` | Third Eye on aggro |

### /BLU

| `/lac fwd cocoon on\|off` | Cocoon PDT self-buff |
| `/lac fwd refueling on\|off` | Refueling haste |
| `/lac fwd metallic on\|off` | Metallic Body (stoneskin-alike) |
| `/lac fwd headbutt on\|off` | Head Butt on mob cast (stun) |

### /COR

| `/lac fwd rolls on\|off` | Auto-roll primary + secondary |
| `/lac fwd reroll` | Reset roll cycle (fire both rolls again) |

### /DNC

| `/lac fwd waltz on\|off` | Curing Waltz III → II → I at HP threshold |
| `/lac fwd hsamba on\|off` | Auto-Haste Samba upkeep |
| `/lac fwd dsamba on\|off` | Auto-Drain Samba upkeep |

### /SCH

| `/lac fwd sublimation on\|off` | Sublimation charging while idle |
| `/lac fwd lightarts on\|off` | Keep Light Arts stance |
