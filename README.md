# ActionSurvivor

A 2.5D horde-survival roguelite set in an abandoned alchemy workshop. Your
spells cast themselves; you decide where to stand and what to build.

## Project status

Playable. A run has a title screen, a wave-paced horde, five spells that differ
in shape, experience orbs, a level-up draft, stat upgrades, and a win or loss
ending with a restart. Everything renders as programmatically built placeholder
meshes: no art yet.

See [the design direction](docs/design-direction.md), [the run
loop](docs/run-loop.md), and [the engine decision](docs/engine-decision-godot.md).

## Play it

1. Install the standard Godot 4 build (the .NET build is not required). The
   game uses the Forward+ renderer, so a Vulkan-capable GPU is needed.
2. Open `project.godot` in Godot and press play, or run `godot --path .` from
   the repository root.
3. Pick a 90-second quick run or a 10-minute full run.

Move with WASD or the arrow keys. That is the only control. Spells fire on
their own. Every level-up pauses for a three-card choice: press 1, 2 or 3, or
click. Escape abandons a run.

## Repository layout

```text
assets/       Source art, audio, fonts, and other game assets
config/       Version-controlled project and gameplay configuration
docs/         Design, architecture, and development documentation
src/          Runtime game source code
tests/        Automated tests and test fixtures
tools/        Development, content-pipeline, and repository scripts
.githooks/    Version-controlled local Git policy hooks
```

Each top-level directory contains a short README describing what belongs there.

## Checks

Headless runtime tests, which boot the real scene. `--fixed-fps 60` is required
for reproducible results; see [the tests](tests/README.md) for why.

```powershell
godot --headless --fixed-fps 60 --path . --script res://tests/run_headless_smoke.gd
```

```powershell
godot --headless --fixed-fps 60 --path . --script res://tests/run_headless_playthrough.gd -- full
```

Static configuration check, for environments where Godot is unavailable or not
on `PATH`:

```powershell
powershell -ExecutionPolicy Bypass -File tools/validate-config.ps1
```

## Development workflow

Direct work on `main` is prohibited.

1. Synchronize `main`: `git switch main` and `git pull --ff-only`.
2. Create a branch: `git switch -c feature/<short-description>`.
3. Make focused commits on that feature branch.
4. Push it: `git push -u origin feature/<short-description>`.
5. Review the changes, then merge the feature branch into `main`.

Run `powershell -ExecutionPolicy Bypass -File tools/setup-git-hooks.ps1` once
after cloning. See [CONTRIBUTING.md](CONTRIBUTING.md) for the complete rules.
