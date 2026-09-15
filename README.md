# ActionSurvivor

An action-survival game inspired by horde shooters, arena combat, and roguelite dungeon adventures.

## Project status

The project is in pre-production. Godot 4 with GDScript has been selected for the first 2D prototype. The current prototype focuses on data-driven enemy spawning and wave pacing using programmatically drawn placeholder visuals.

See [the engine decision](docs/engine-decision-godot.md) and [the wave prototype guide](docs/wave-prototype.md).

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

Each top-level directory contains a short README describing what belongs there. Engine-generated directories should be added only after the engine is selected, with generated files excluded through `.gitignore`.

## Development workflow

Direct work on `main` is prohibited.

1. Synchronize `main`: `git switch main` and `git pull --ff-only`.
2. Create a branch: `git switch -c feature/<short-description>`.
3. Make focused commits on that feature branch.
4. Push it: `git push -u origin feature/<short-description>`.
5. Review the changes, then merge the feature branch into `main`.

Run `powershell -ExecutionPolicy Bypass -File tools/setup-git-hooks.ps1` once after cloning. See [CONTRIBUTING.md](CONTRIBUTING.md) for the complete rules.

## Run the wave prototype

1. Install the standard Godot 4 build (the .NET build is not required).
2. Open `project.godot` in Godot, or run `godot --path .` from the repository root.
3. Move with WASD or the arrow keys. The prototype runs an accelerated 90-second wave demonstration.

Godot is not currently available on this development machine, so the repository includes a static configuration check that can run without it:

```powershell
powershell -ExecutionPolicy Bypass -File tools/validate-wave-config.ps1
```
