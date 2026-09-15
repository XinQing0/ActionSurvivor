# Enemy wave prototype

## Purpose

The prototype validates enemy spawning and pacing for a relaxed, top-down horde-survival loop in the abandoned alchemy workshop setting. It uses only programmatically drawn placeholder shapes.

## Current behavior

- The player starts at the center of a 960 x 540 arena and moves with WASD or arrow keys.
- Enemies spawn just outside one of the four arena edges and maintain a configured minimum distance from the player.
- Wave configuration changes spawn interval, batch size, simultaneous enemy cap, and enemy-type weights over elapsed time.
- Three placeholders are included: numerous slow vermin, quicker bats, and slow high-health golems.
- The HUD shows elapsed time, current wave, alive enemies, and total spawned enemies.

## Configurations

`config/waves_demo.json` compresses all phases into 90 seconds for development. `config/waves_10min.json` describes the intended ten-minute pacing. Change `WAVE_CONFIG_PATH` in `src/main.gd` when moving from the accelerated demo to the full run.

Each wave begins at `start_time_seconds`. The director uses the most recent wave whose start time has passed. Type weights do not need to total one; they are normalized during weighted selection.

## Validation

Run the static check without Godot:

```powershell
powershell -ExecutionPolicy Bypass -File tools/validate-wave-config.ps1
```

When Godot 4 is available, load the project from the repository root and run it. A future automated runtime test should verify scene loading and spawn counts in headless mode.
