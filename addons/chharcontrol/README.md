# ChharControl

Ashita v4 sidecart for ChharLAC's Puppetmaster profile. Holds named automaton attachment sets that match the 9 maneuver presets baked into `PUP.lua`.

## Install

Copy `addons/chharcontrol/` into:
- `<Ashita>/config/addons/chharcontrol/` **—OR—**
- `<Ashita>/addons/chharcontrol/` (older layouts)

ChharLAC's `PUP.lua` auto-loads this addon in `OnLoad()` and unloads it in `OnUnload()`, so you don't normally need to type `/addon load chharcontrol` yourself.

## Workflow

1. In-game, out of combat, open **Pet Commands → Change Attachments** and equip the attachments you want for a role — say, **tank**: Valoredge head, Valoredge frame, Tension Spring II, Attuner, Flame Holder, Schurzen, etc. (On retail this used to be the NPC "Ebisu" in Nashmau; on era servers like HorizonXI/Phoenix the pet menu replaces that NPC.)
2. Switch to PUP and run:
   ```
   /cc save tank
   ```
3. ChharControl stores the exact head + frame + 1-12 attachments in `settings.lua`.
4. Later, when you want that setup again:
   ```
   /lac fwd setup tank
   ```
   PUP.lua switches the maneuver pattern **and** fires `/cc preset tank`, which echoes the attachment list to chat so you can equip at Ebisu.

Repeat `/cc save <name>` for each of the 9 preset slots.

## Preset slots (match PUP.lua maneuver patterns)

| Name      | Head         | Frame       | Maneuvers                        | WS-force / Special       |
|-----------|--------------|-------------|----------------------------------|--------------------------|
| `blm`     | Spiritreaver | Stormwaker  | ice ×2, dark                     | —                        |
| `whm`     | Soulsoother  | Stormwaker  | water, light, dark               | —                        |
| `rdm`     | Stormwaker   | Stormwaker  | dark, water, ice                 | —                        |
| `tank`    | Valoredge    | Valoredge   | earth, fire, light               | **Dark** @ 70–99% pet TP |
| `turtle`  | Soulsoother  | Valoredge   | light, water, earth              | **Fire** when Strobe ready (30s) |
| `meva`    | Soulsoother  | Harlequin   | light, water, dark               | —                        |
| `rng`     | Sharpshot    | Sharpshot   | wind ×2, fire                    | **Thunder** @ 70–99% pet TP |
| `rngtank` | Valoredge    | Sharpshot   | light, fire, wind                | **Thunder** @ 70–99% pet TP |
| `lvl60`   | Valoredge    | Valoredge   | light, water, thunder            | **Dark** @ 70–99% pet TP (BCNM-only) |

## Commands

```
/cc preset <name>     Set active preset
/cc preset            Show current + list descriptions
/cc equipset <name>   Set preset + echo attachment list to equip
/cc list              List all preset slots and their saved content
/cc show <name>       Print the attachment list for <name>
/cc save <name>       Save CURRENTLY equipped attachments as <name>
/cc current           Print what's currently on the automaton
/cc delete <name>     Clear a saved preset
/cc help              Show help
```

## v1 scope limitation

Attachment auto-swap requires a client-side packet injection (`0x102 Set
Automaton`) that isn't yet implemented. **v1 ECHOES the attachment list**
so you can equip from Pet Commands → Change Attachments. v2 will do the full detach→attach loop
automatically. Everything else (preset storage, PUP.lua integration,
Strobe-aware fire-maneuver, named presets) works today.

## Credits

Workflow inspired by [autocontrol](https://github.com/Nifim/autocontrol) (Nitrous of Shiva, Nifim, Ricky Gall; 2013–2020, Windower). ChharControl is a from-scratch Ashita v4 reimplementation, not a port.
