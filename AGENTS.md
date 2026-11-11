# NEKO: DEAD SIGNAL — rules for future coding agents

## Binding decisions · 11 November 2026

1. **Read [Earth GDD v0.4](docs/DEAD_SIGNAL_EARTH_GDD_v0.4.md) first.** It is the only authority for world, factions and story: Earth 2116, Night Line, NEKO, Kontur, settlements, Echo and the terrestrial Zero network.
2. **Cancelled lore stays cancelled.** Space fleets, alien Saari, unknown planets, orbital command/deployment and space-pirate concepts exist only in Git history. Never restore them from old commits, branches, reports or test fixtures.
3. **Preserve working Godot mechanics:** Android tap movement, local PvE, 128×128 surface, RTS orders, construction, power, production, fog, saves, diagnostics, animations and tests. The server is not yet an online game simulation.
4. **Compatibility:** keep package `com.ncorror.neko.deadsignal`, faction indices 0=NEKO / 1=Kontur, officer IDs, character IDs and existing `user://` save paths.
5. **Heroines:** Amina, Reina, Mira Kade and Lyra Voss remain authored leads. Saira Nel and Oralin remain Kontur leads. Approved class contracts and art are preserved.
6. **Lyra:** runtime regressions for lab frame stepping, isolated animation resources, death playback, planted facing and target revalidation are part of the active code. Blender rifle drafts are still unapproved visual candidates.
7. **RTS networking:** preserve the order DTO and local executor. Future server work validates ownership, visibility and sequencing; do not import lockstep as a substitute.
8. **Branch hygiene:** the former `agent/neko32-gpt` work was audited and its unique runtime/test fixes were transferred into the active Earth branch. Do not merge or resurrect that diverged branch. Old feature branches may be deleted after the active PR is green.
9. **Documentation:** only files listed by [docs/README.md](docs/README.md) are active design documents. Removed reports remain available through Git history and must not be regenerated to satisfy obsolete tooling.

## Current source of truth

- World/story: `docs/DEAD_SIGNAL_EARTH_GDD_v0.4.md`
- Decisions: `docs/DECISIONS.md`
- Roadmap/status: `docs/ROADMAP.md`
- Architecture: `docs/ARCHITECTURE.md`
- Hero skill contract: `docs/MMORTS_HERO_SKILL_BALANCE_V03_2026-11-06.md`
- Lyra visual acceptance: `docs/LYRA_GOLD_STANDARD.md`

No released online MMO is claimed.
