# Changelog

## v1.0.0 - 2026-09-28

Initial public release.

### Added
- Shared `subjob_features.lua` library covering all 17 usable subjobs:
  /WAR /MNK /WHM /BLM /RDM /THF /PLD /DRK /BRD /RNG /NIN /DRG /SAM /BLU /COR /DNC /SCH
- 22 job profiles with era-progressive gear (RSE → HQ crafted → mission → salvage/nyzul/limbus for ToAU jobs, WoTG relic for SCH/DNC).
- `_TEMPLATE.lua` canonical starter for future jobs.
- `SETUP.ps1` one-time character rename + path rewrite.
- Docs: `README.md`, `docs/COMMANDS.md`, `docs/ARCHITECTURE.md`, `docs/SUBJOB-FEATURES.md`.

### Design decisions
- All auto-features default OFF for private-server TOS compliance.
- Event-driven where possible (Shield Bash on mob-cast, Third Eye on aggro, Utsusemi shadow refresh, DRG hate-shed).
- Threshold-gated where useful (Waltz at HP threshold, Aspir at MP threshold, Souleater above HP floor).
- Subjob automation drives from `HandleDefault`/`HandleEngaged` — no external `ashita.timer` dependency.
- Internal per-feature throttle prevents queue spam.

### Known limitations
- Recast/spell/buff IDs are retail-stable defaults; private servers may reassign. Override in `subjob_features.lua` if needed.
- Item names assume Horizon XI / Phoenix XI item DB; some pieces may be renamed on your server.
