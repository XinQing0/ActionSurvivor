# Source

Runtime game source code for the Godot 4 prototype lives here.

- `main.tscn` and `main.gd` own the playable prototype scene.
- `gameplay/` contains reusable gameplay scripts: the player pawn, enemies,
  the wave director, the camera rig, physics layer bits, and input setup.
- `gameplay/spells/` contains one script per spell plus the shared projectile.
  A spell is data in `config/player_loadout.json` pointing at a script here.

