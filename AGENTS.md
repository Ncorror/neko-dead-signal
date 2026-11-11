# NEKO: DEAD SIGNAL — rules for future coding agents

## Current binding decisions (11 November 2026)

1. **Read [Earth GDD v0.4](docs/DEAD_SIGNAL_EARTH_GDD_v0.4.md) first.** It is the sole authority for world, characters, factions and story. Earth 2116, 27 years after the Night of Silence; NEKO mobile headquarters **Night Line** vs quarantine authority **Kontur**, settlements, human memories/Echo, the terrestrial Zero network. Space fleets, Saari aliens, unknown planets, orbital command and orbital deployment are **cancelled concepts**, never features to implement.
2. **Preserve working Godot mechanics**: Android 2.5D tap movement, local RPG/PvE, 128×128 surface, RTS free movement/order queues, construction, power, production, fog, local saves, full diagnostics, animations and tests. Current server gameplay is not online; do not claim MMO functionality.
3. **Compatibility:** keep package `com.ncorror.neko.deadsignal`, persistent faction indices 0=NEKO and 1=Kontur (previously humans/Saari), existing officer indices, character IDs and `user://` save paths. No silent save migration or resets.
4. **Heroines:** Amina, Reina, Mira Kade and Lyra Voss remain adult authored leads. Preserve class and ability contracts and approved art. Saira Nel and Oralin remain as human Kontur leads with stable data identifiers. Lyra's unfinished Blender rifle grips are not accepted assets, even if CI passes.
5. **RTS networking**: preserve the existing order DTO and local command executor. Future server validates ownership, visibility and sequencing. Do not import lockstep as an MMO server substitute.
6. **Tests and documentation:** update all required scripts, tests and user-facing labels when changing names. Do not restore removed space-era GDDs based on historical git references, README snapshots or obsolete CI test assertions. Source history remains accessible through Git; it is not current design authority.
7. **Branch hygiene:** never merge diverged animation branch blindly; compare conflicts, run Godot/Python/Android CI and retain source assets. Remove old branches only after their changes are merged or independently preserved.
