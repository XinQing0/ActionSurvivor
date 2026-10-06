# Configuration

Store version-controlled project, gameplay, balancing, input, and environment-independent configuration here. Never store secrets or machine-local settings.

- `waves_demo.json` contains the accelerated 90-second development demonstration.
- `waves_10min.json` contains the intended ten-minute first-run pacing.
- `player_loadout.json` contains player stats and the starting spell list.
- `spells.json` is the spell catalog: base stats and per-level growth.
- `progression.json` holds the experience curve, experience-orb behaviour,
  draft weights, and the stat upgrade pool.
- `augments.json` is the augment pool: build-defining modifiers that change what
  a spell does, each gated on a spell or element the player already owns.
- `reactions.json` defines what happens when two statuses meet on one enemy.

