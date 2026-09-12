# Contributing to ActionSurvivor

## Branch policy

- `main` is the stable integration branch. Do not commit directly to it.
- All development commits must be created on a branch named `feature/<short-description>`.
- Use lowercase kebab-case after `feature/`, for example `feature/player-movement`.
- Keep one feature or clearly related change set per branch.
- Update your feature branch from `main` before integration and resolve conflicts on the feature branch.
- Push the feature branch for review. Do not push a local branch directly to remote `main`.
- Delete merged feature branches when they are no longer needed.

## Commit policy

- Make small, focused commits that leave the repository in a coherent state.
- Write commit subjects in the imperative mood, such as `Add player movement prototype`.
- Do not commit secrets, credentials, generated builds, caches, or machine-specific settings.
- Update tests and documentation when behavior or architecture changes.

## Merge policy

- Review the complete diff before merging.
- Confirm relevant checks and tests pass.
- Prefer a pull request even when working alone, so the reason for the change remains visible.
- Merge into `main` only after the branch is ready to be treated as a stable project state.

## Local enforcement

Run the setup script after every clone:

```powershell
powershell -ExecutionPolicy Bypass -File tools/setup-git-hooks.ps1
```

The tracked hooks reject commits outside `feature/*` and reject any push whose destination is `refs/heads/main`.

These hooks are local safeguards, not server-side security. A user can bypass them with `--no-verify`, remove the configuration, or push from a machine where setup was not run. Without GitHub branch protection, repository collaborators must install the hooks and follow this document.

