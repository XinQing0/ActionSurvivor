# The run loop

A run is a single self-contained game: pick a length, survive it, and the run
ends in `SURVIVED` or `DOWNED`. Nothing carries over between runs. All visuals
are programmatically built placeholder meshes.

See [the design direction](design-direction.md) for why the game looks and
plays this way.

## Playing

Move with WASD or the arrow keys. That is the only control during a run. Spells
cast themselves. Escape abandons a run.

The title screen offers a 90-second quick run and a 10-minute full run. The
choice survives a restart, so `Run it again` replays the same length.

Every level-up pauses the game and offers three cards: a new spell, a level for
a spell you already have, a stat upgrade, or an augment. Pick with the mouse or
with 1, 2 and 3.

## Systems

| Area | Where |
| --- | --- |
| Run state, arena, wiring | `src/main.gd` |
| Wave pacing and spawning | `src/gameplay/wave_director.gd` |
| Player, health, pickup radius | `src/gameplay/player_pawn.gd` |
| Global run modifiers | `src/gameplay/player_stats.gd` |
| Experience and levels | `src/gameplay/progression.gd`, `xp_orb.gd` |
| Level-up offers | `src/gameplay/draft.gd` |
| Statuses and reactions | `src/gameplay/reactions.gd`, `enemy.gd` |
| Spells | `src/gameplay/spells/` |
| Interface | `src/ui/` |

### Spells

Five spells, chosen to differ in *shape* rather than in numbers, so that two
runs with different spells actually play differently:

| Spell | Targeting | Shape | Role |
| --- | --- | --- | --- |
| Arc Bolt | Nearest | Single projectile, extra shots seek separate targets | Baseline single target |
| Cinder Nova | Self-centred | Ring pulse | Answer to being surrounded |
| Warding Orbs | None | Persistent orbiting orbs | Passive contact defence |
| Ember Spray | Movement direction | Piercing cone | Makes *where you run* a damage decision |
| Static Chain | Nearest, then leaps | Chain between nearby enemies | Rewards letting enemies bunch up |

Adding a spell is an entry in `config/spells.json` plus a short script
extending `src/gameplay/spells/spell.gd`. The base class owns levelling, stat
multipliers, cooldown and target selection, so a new spell only implements what
happens when it fires.

### Elements, statuses and reactions

Every spell has an element and applies a status on each hit it lands:

| Spell | Element | Status |
| --- | --- | --- |
| Cinder Nova, Ember Spray | Fire | Burn: damage over time, scales with your damage multiplier |
| Arc Bolt, Static Chain | Lightning | Shock: no effect alone |
| Warding Orbs | Frost | Chill: slows the enemy by 35% |

When one enemy carries two different statuses they react: both are consumed and
something happens.

| Reaction | Needs | Effect |
| --- | --- | --- |
| Overload | Burn + Shock | Area blast around the enemy |
| Shatter | Chill + Shock | Heavy hit on that enemy alone |
| Steam | Burn + Chill | Small blast that chills everything near it |

This is what makes the *pairing* of spells a decision: two fire spells never
react with each other, a fire spell and a lightning spell do. An enemy cannot
react again for a short lockout, and reactions that set up further reactions are
depth-limited (`max_chain_depth`). Definitions live in `config/reactions.json`.

All spell hits go through `Spell.deal_hit`, so a new spell that damaged enemies
directly would silently opt out of reactions. Enemies glow in the colour of the
status they carry, and a reaction prints its name above the enemy.

### Augments

An augment changes what a spell *does* rather than how hard it hits. Each is
taken once and is only offered when the player already owns what it needs: a
specific spell, any spell of an element, or spells of two different elements.

| Augment | Needs | Effect |
| --- | --- | --- |
| Ricochet | Arc Bolt | Bolts rebound to another enemy twice |
| Twin Pulse | Cinder Nova | A second, weaker pulse follows the first |
| Backdraft | Ember Spray | A smaller cone also fires behind you |
| Conductive Web | Static Chain | Two more leaps, far less falloff |
| Brittle Cold | Warding Orbs | Chilled enemies take 30% more damage from everything |
| Wildfire | Any fire spell | Burning enemies ignite their neighbours when they die |
| Catalyst | Two elements | Reactions hit 50% harder and reach 25% further |

Definitions and parameters live in `config/augments.json`. Augments are recorded
on the player stats object, and spells read them with `has_augment`.

### Stats

Spells never store final numbers. They read a base value and multiply it
through `player_stats.gd`, so a stat upgrade taken at minute two changes every
spell already owned without any of them knowing the upgrade exists.

## Configuration

| File | Contents |
| --- | --- |
| `config/waves_demo.json` | The 90-second run |
| `config/waves_10min.json` | The 10-minute run |
| `config/spells.json` | Spell catalog: base stats and per-level growth |
| `config/progression.json` | Experience curve, orb behaviour, draft weights, stat upgrades |
| `config/reactions.json` | Which status pairs react, and what each reaction does |
| `config/augments.json` | The augment pool, its requirements and parameters |
| `config/player_loadout.json` | Starting player stats and starting spells |

Each wave begins at `start_time_seconds`; the director uses the most recent
wave whose start time has passed. Type weights are normalized, so they need not
total one.

## Design decisions worth knowing

### Enemies spawn around the player, not around the arena

Spawning on the arena edge made arena size double as the difficulty valve: the
crowd could only be as dense as the arena allowed, and once the alive cap was
reached there was nowhere left to run. Anchoring the spawn ring to the player
means the horde closes in from just out of view wherever the player has run to.

### Stragglers are culled

Enemies further than `despawn_radius` from the player are removed. Without
this, the alive cap fills with a single clump trailing the player, nothing new
can spawn ahead of them, and running in one direction is a free win. A cull is
not a kill: it awards no experience and does not count towards the slain total,
so running away is never a way to farm progress.

### Bats are faster than the player

Every enemy being slower made pure kiting a safe, optimal strategy - an
automated runner finished a full run at 87% health without fighting. Bats now
outpace the player and cannot be outrun, so they have to be killed. They stay
fragile, so the answer is damage, not more running.

### Contact damage is a distance check, not physics

Enemies collide only with each other, so the crowd separates without shoving
the player. Damage is resolved by an explicit distance check in `enemy.gd`,
which keeps it deterministic and easy to move behind a server authority when
multiplayer arrives. Layer bits live in `src/gameplay/game_layers.gd`.

### Input actions are registered in code

`src/gameplay/input_setup.gd` registers the movement actions at runtime rather
than storing them in `project.godot`. Godot's serialized `InputEventKey` layout
has changed between 4.x minor releases, and a hand-written input map fails
silently on versions it does not match. Actions already present in the project
are left alone, so a remapping UI can override them later.

## Units and scale

One world unit is one metre. Enemy and player speeds are tuned directly rather
than converted from the original 2D prototype's pixel values.

## Checks

Static configuration check, no engine required:

```powershell
powershell -ExecutionPolicy Bypass -File tools/validate-config.ps1
```

Headless runtime tests. **Always pass `--fixed-fps 60`**: Godot then advances
the clock by a fixed step instead of by real elapsed time, which together with
the seeded spawn RNG makes a run reproducible. Without it two runs of identical
code diverge wildly - one full run finished with 841 spawns and a win, another
with 176 and a loss - and the tests are worthless as regression checks.

```powershell
godot --headless --fixed-fps 60 --path . --script res://tests/run_headless_smoke.gd
godot --headless --fixed-fps 60 --path . --script res://tests/run_headless_playthrough.gd
godot --headless --fixed-fps 60 --path . --script res://tests/run_headless_playthrough.gd -- full
godot --headless --fixed-fps 60 --path . --script res://tests/run_headless_build_test.gd
```

The smoke test boots the scene and checks that every system fires. The
playthrough test drives the pawn with a kiting policy and checks that a whole
run can be survived. The build test sets up controlled situations (an enemy
carrying two statuses, a bolt meeting two enemies, a draft for a given
inventory) and asserts exactly what follows. See [the tests](../tests/README.md).

## Known gaps

- Balance is tuned against an automated kiting bot, which is a floor rather
  than a real player. Human playtesting has not happened yet.
- No audio.
- No pause during a run; Escape abandons it.
- No meta progression between runs, by design for now.
- Balance of augments is untested against people. In the automated full run the
  bot clears about 755 enemies with reactions alone and about 1470 once it also
  picks augments (before milestone 3 it cleared 624), so augments are the
  dominant source of power and the wave curve has not been retuned for them.
- Augments are one-off picks with no stacking, and none costs the player
  anything. There are no trade-off choices yet.
- Reaction and status visuals are placeholder glow and floating text, and have
  not been looked at in a running build.
