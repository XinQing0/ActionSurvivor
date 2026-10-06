# Tests

Store automated tests, test fixtures, and test-specific helpers here. Organize
tests to mirror the source structure when practical.

Both tests boot the real `src/main.tscn` under a headless Godot and exit
non-zero on the first failed check, so either can gate CI.

**Always pass `--fixed-fps 60`.** Godot then advances the clock by a fixed step
instead of by real elapsed time. Together with the seeded spawn RNG this makes
a whole run reproducible; two consecutive full runs produce byte-identical
results. Without it the same code diverges wildly between runs and neither test
means anything.

## `run_headless_smoke.gd`

Boots the scene and checks that every system fires at least once: waves spawn,
spells kill, experience drops and is collected, levelling opens a draft, a
draft pick applies, and the run ends. The pawn is never driven, so a stationary
player is worn down by contact damage; that is the loss path.

```powershell
godot --headless --fixed-fps 60 --path . --script res://tests/run_headless_smoke.gd
```

## `run_headless_playthrough.gd`

Drives the pawn with a simple kiting policy through a whole run and checks the
win path, which the smoke test never reaches. Movement goes through
`Input.action_press` rather than being written onto the pawn, so the real input
path is exercised. Draft picks follow a rough imitation of competent play:
collect a few spells, then specialise, with about one pick in three spent on a
stat.

```powershell
godot --headless --fixed-fps 60 --path . --script res://tests/run_headless_playthrough.gd
godot --headless --fixed-fps 60 --path . --script res://tests/run_headless_playthrough.gd -- full
```

## `run_headless_build_test.gd`

Does not play a run. Builds small controlled situations inside the real scene
and asserts exact outcomes: statuses apply, expire and refresh; each reaction
fires, consumes its statuses and respects its lockout; Wildfire, Catalyst and
Brittle Cold behave; a bolt rebounds only when Ricochet is owned; the draft
offers an augment only when its requirement is met and never twice.

```powershell
godot --headless --fixed-fps 60 --path . --script res://tests/run_headless_build_test.gd
```

The bot is a difficulty *floor*, not a stand-in for a player. It passing means
a run is completable, not that it is fun or well balanced.
