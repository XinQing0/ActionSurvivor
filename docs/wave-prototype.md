# Milestone 1 prototype: the 2.5D run loop

## Purpose

The prototype validates a complete, losable run loop in 2.5D: wave pacing,
crowd density, contact damage, one auto-casting spell, and a run that ends in a
win or a loss. It uses only programmatically built placeholder meshes.

It supersedes the earlier 2D top-down wave prototype. See
[the design direction](design-direction.md) for why the presentation changed.

## Current behavior

- The arena is a circular platform of radius `arena_radius`. The player starts
  at the centre and moves with WASD or the arrow keys.
- The camera is a constrained follow rig: fixed 55-degree pitch, fixed yaw, and
  a distance that opens up as the arena fills so a dense crowd stays readable.
  Because the yaw never changes, input axes map straight onto the world XZ
  plane.
- Enemies spawn on a ring just outside the arena and keep a configured minimum
  distance from the player.
- Wave configuration changes spawn interval, batch size, simultaneous enemy
  cap, and enemy-type weights over elapsed time.
- Three placeholders are included: numerous slow vermin, quicker bats, and slow
  high-health golems. Each deals contact damage on its own attack interval.
- The player has health and a short invulnerability window after each hit,
  shown as a transparency flash.
- One spell, `arc_bolt`, fires automatically at the nearest enemy in range.
- The run ends as `SURVIVED` at `run_duration_seconds` or as `DOWNED` when the
  player reaches zero health.
- The HUD shows elapsed time, current wave, alive enemies, total spawned,
  kills, and player health.

## Units and scale

One world unit is one metre. The 2D prototype's pixel values were converted at
roughly 40 px per metre.

Enemy move speeds are the one deliberate exception: a faithful conversion left
them at a fifth of the player's speed, which made the player untouchable and so
left contact damage and player death unexercised. They are set to about twice
the converted value instead. With the current numbers a stationary player is
downed in roughly twenty seconds, which is the behaviour the headless smoke
test asserts.

## Configuration

`config/waves_demo.json` compresses all phases into 90 seconds for development.
`config/waves_10min.json` describes the intended ten-minute pacing. Change
`WAVE_CONFIG_PATH` in `src/main.gd` when moving from the accelerated demo to the
full run.

Each wave begins at `start_time_seconds`. The director uses the most recent wave
whose start time has passed. Type weights do not need to total one; they are
normalized during weighted selection.

`config/player_loadout.json` holds player stats and the starting spell list.
Each spell entry names the script that implements it, so adding a spell is a
config change plus one script under `src/gameplay/spells/`.

## Input

Gameplay actions (`move_left`, `move_right`, `move_forward`, `move_back`) are
registered at runtime by `src/gameplay/input_setup.gd` rather than stored in
`project.godot`. Godot's serialized `InputEventKey` layout has changed between
4.x minor releases, and a hand-written input map silently breaks on versions it
does not match. Actions already defined in the project are left untouched, so a
remapping UI can override them later.

## Physics layers

Enemies collide only with each other, so the crowd separates without shoving the
player around. Contact damage is resolved by an explicit distance check in
`enemy.gd` instead of by physics, which keeps it deterministic and easy to move
behind a server authority when multiplayer arrives. Layer bits live in
`src/gameplay/game_layers.gd`.

## Validation

Static check, no engine required:

```powershell
powershell -ExecutionPolicy Bypass -File tools/validate-wave-config.ps1
```

Headless runtime smoke test, which boots the real scene and asserts that waves
spawn, the spell kills enemies, and the run ends:

```powershell
godot --headless --path . --script res://tests/run_headless_smoke.gd
```

It exits non-zero on the first failed check, so it can gate CI later.

## Known gaps

- No level-up or draft flow yet, so there is no build decision inside a run.
- No restart: closing and relaunching is the only way to start a new run.
- Enemy crowd separation relies on capsule collisions and has not been profiled
  at the ten-minute config's 90-enemy cap.
