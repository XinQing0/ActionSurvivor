# ActionSurvivor

An action-survival game inspired by horde shooters, arena combat, and roguelite dungeon adventures.

## Project status

The project is in pre-production. The engine and gameplay architecture have not been selected yet.

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
