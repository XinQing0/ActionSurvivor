# Source

Runtime game source code for the Godot 4 prototype lives here.

- `main.tscn` and `main.gd` own the playable prototype scene.
- `gameplay/` contains reusable gameplay scripts: the player pawn, enemies,
  the wave director, the camera rig, physics layer bits, and input setup.
- `gameplay/spells/` contains one script per spell plus the shared projectile
  and effects. A spell is an entry in `config/spells.json` naming a script
  here that extends `gameplay/spells/spell.gd`.
- `ui/` contains the HUD, the level-up draft screen, the title and result
  overlay, and the shared palette. All of it is built in code.

