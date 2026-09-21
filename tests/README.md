# Tests

Store automated tests, test fixtures, and test-specific helpers here. Organize tests to mirror the source structure when practical.

- `run_headless_smoke.gd` boots the real main scene under a headless Godot and
  asserts that the run loop works end to end. Run it from the repository root:

  ```
  godot --headless --path . --script res://tests/run_headless_smoke.gd
  ```

