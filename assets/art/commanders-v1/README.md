# NEKO: DEAD SIGNAL — Character source art

Four human commander references are preserved in this private repository: **Amina, Reina, Lyra Voss, Mira Kade**. These are original 2D references, not automatically rigged game-ready models.

## Already uploaded and verified

- `characters/amina_dossier.png`
- `characters/reina_dossier.png`
- `characters/lyra_voss_dossier.png`
- `characters/mira_kade_dossier.png`

The existing `client/assets/portraits/*.jpg.b64` are low-weight in-game orbital portraits, separate from these source images. `client/assets/characters/amina/preview.glb` is an **unrigged 3D experiment**: it has no skin or animation.

## New full-body and turnaround references

See **[MODELING_SOURCES_v2.md](MODELING_SOURCES_v2.md)** for the six newly collected image paths, original dimensions and SHA-256 checksums. The additional binary PNG files are packaged for a safe one-time Termux upload; listing a path in documentation does not imply the binary is already on GitHub.

## Modeling pipeline

Production references are tracked through [MODELING_SOURCES_v2.md](MODELING_SOURCES_v2.md) and the active Lyra acceptance rules in `docs/LYRA_GOLD_STANDARD.md`. Historical external-archive catalogs were removed from the working tree; use Git history only when provenance review is explicitly needed.

For Meshy single-image conversion, submit **one isolated character**, not a four-panel sheet. Use multiple orthographic views only through an explicitly supported multi-image workflow. Save the untouched original and a versioned 3D export, verify the skeleton/animation count before using a GLB in battle.

Do not overwrite existing art or change game code merely to upload character references.
