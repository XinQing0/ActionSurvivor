# Engine decision: Godot 4 with GDScript

## Status

Accepted for the first playable prototype.

## Context

ActionSurvivor is a small 2D top-down action-survival game. The first milestone needs rapid iteration on movement, enemy density, wave pacing, and upgrade combinations. It does not require a high-end 3D renderer or engine-specific marketplace assets.

## Decision

Use the standard Godot 4 release with GDScript. Do not require the .NET/C# build.

Runtime source remains under `src/`, game balance data under `config/`, source assets under `assets/`, and tests under `tests/`. Godot's required `project.godot` file stays at the repository root so the editor and command-line runner can identify the project.

## Why

- Godot has a focused 2D toolset and a lightweight edit-run loop.
- GDScript is bundled with the engine, so no separate language runtime is needed.
- Scenes and resources are text-based and work well with source control.
- Headless execution supports later automated smoke tests and CI.
- Programmatic drawing allows gameplay to be validated before committing to final art.

## Consequences

- Contributors need a compatible Godot 4 editor or command-line executable.
- Generated `.godot/` state must not be committed.
- Final rendering and input feel still require a windowed playtest even when automated checks pass.
- Reconsidering the engine later requires a new documented decision.
