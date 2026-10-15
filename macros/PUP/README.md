# ChharLAC PUP macro pack

Ready-to-paste in-game macros for the Chharizard PUP profile.

## Where macros live in Ashita

Ashita stores macros per character in:

```
<Ashita>/config/macros/<CharacterName>/
```

Each macro palette = one `.txt` file. The game can hold multiple palettes
(1-10, 11-20, etc). Each file contains 10 macros × 6 lines of input.

**You have two options:**

1. **Easy — paste the lines yourself.** In-game, hit Ctrl+M (or /macro),
   edit the slot, and paste one of the lines below.

2. **Drop-in — copy the files in this folder** to your Ashita macros folder,
   then in-game run `/macro book <N>` to switch to that palette.

## Palette 1 — PUP core (recommended Ctrl palette)

| Slot | Name       | Line                                       |
|------|------------|--------------------------------------------|
| F1   | AM Toggle  | `/console lac fwd am toggle`               |
| F2   | Mode Melee | `/console lac fwd mode Melee`              |
| F3   | Mode Tank  | `/console lac fwd mode Tank`               |
| F4   | Mode Rngd  | `/console lac fwd mode Ranged`             |
| F5   | Mode Nuke  | `/console lac fwd mode Nuke`               |
| F6   | Mode Heal  | `/console lac fwd mode Heal`               |
| F7   | Repair     | `/console lac fwd repair toggle`           |
| F8   | HUD Toggle | `/console lac fwd hud`                     |
| F9   | Burden     | `/console lac fwd burden`                  |
| F10  | Config     | `/console lac fwd config`                  |

## Palette 2 — Automaton control

| Slot | Name       | Line                                       |
|------|------------|--------------------------------------------|
| F1   | Activate   | `/ja "Activate" <me>`                      |
| F2   | Deploy     | `/ja "Deploy" <t>`                         |
| F3   | Retrieve   | `/ja "Retrieve" <me>`                      |
| F4   | Deactivate | `/ja "Deactivate" <me>`                    |
| F5   | Overdrive  | `/ja "Overdrive" <me>`                     |
| F6   | Repair     | `/ja "Repair" <me>`                        |
| F7   | Maint.     | `/ja "Maintenance" <me>`                   |
| F8   | Vent.      | `/ja "Ventriloquy" <t>`                    |
| F9   | Role Rev.  | `/ja "Role Reversal" <me>`                 |
| F10  | Cooldown   | `/ja "Cooldown" <me>`                      |

## Suggested keybinds (paste in Ashita console once)

```
/bind ^f7  /console lac fwd repair toggle
/bind ^f8  /console lac fwd am toggle
/bind ^f9  /console lac fwd hud
```

Ctrl+F7/F8/F9 will now toggle Repair / Auto-Maneuvers / Burden-HUD from
anywhere, no macro slot needed.
