# Architecture

## Layout

```
Chharizard-LAC/
├── README.md
├── LICENSE
├── CHANGELOG.md
├── SETUP.ps1              # one-time character rename + path rewrite
├── .gitignore
├── docs/
│   ├── ARCHITECTURE.md    # this file
│   ├── COMMANDS.md        # /lac fwd command reference
│   └── SUBJOB-FEATURES.md # per-subjob automation notes
└── profiles/
    └── CHAR_PID/         # renamed by SETUP.ps1
        ├── subjob_features.lua    # shared automation library
        ├── _TEMPLATE.lua          # starter for future jobs
        ├── WAR.lua ... SCH.lua    # 22 job profiles
        └── (settings.xml at runtime, .gitignored)
```

## Why this shape

Every job profile is thin — gear sets + LAC handlers. The shared library holds all the cross-cutting subjob automation, so:

- **One place to fix a bug.** If Utsusemi refresh misfires, the fix lives in `subjob_features.lua` and every profile inherits it. No more copy-pasting corrections across 22 files.
- **New jobs cost 3 lines of boilerplate.** Copy `_TEMPLATE.lua`, fill in gear, done. The library is already wired.
- **Server-agnostic.** Recast/spell/buff IDs are centralized. If Horizon changes an ability ID, override once in the library or in the profile's OnLoad.

## Tick model

LuAshitaCast v2.12 doesn't expose `ashita.timer` to profile sandboxes, so we can't register timers from a profile. Instead, subjob automation drives from **`HandleDefault`** and **`HandleEngaged`**, which LAC calls continuously while the profile is active (roughly every 250ms).

Each per-feature check is internally throttled via `M.throttled(key, seconds)`, so even though `Sub.tick()` runs ~4x/sec, each subjob feature only fires at most once every ~2 seconds.

This has three benefits over external timers:

1. **No timer registration** → nothing to leak on `/lac reload`.
2. **Automatic scoping** → automation only runs from the active profile's handlers, so job changes don't produce ghost ticks.
3. **No dependencies** → no external libraries or addons required.

## Command routing

LAC v2.12 registers `/lac fwd <cmd> [args]` for profile commands. Every profile's `HandleCommand` starts with:

```lua
profile.HandleCommand = function(args)
    if (Sub.handleCommand(args)) then return; end
    -- profile-specific commands below
end
```

`Sub.handleCommand` returns `true` if it consumed the command, so the profile only sees commands the shared library didn't handle. This means every job gets every subjob command for free.

## Equip semantics

Two gear-set functions matter:

- **`gFunc.EquipSet(sets.X)`** — buffered. Only applies during LAC's own natural equip pass, i.e. inside handler contexts (`HandleDefault`/`HandleEngaged`/`HandleWeaponskill`/etc.). Use this everywhere in handlers.
- **`gFunc.ForceEquipSet(sets.X)`** — immediate. Applies right now, bypassing the pass. Use in `HandleCommand` when a user command explicitly asked for a swap.

## Server-safe defaults

- Every auto-feature ships as `false`.
- Event-driven features (Shield Bash on mob cast, Third Eye on aggro) are preferred over cooldown loops.
- Threshold-gated features (Waltz below HP%, Aspir below MP%) fire only when the game state genuinely warrants a reaction.
- `suballoff` is the single "panic" command.

Verify your server's TOS before enabling anything.
