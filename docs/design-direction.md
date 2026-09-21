# Design direction: 2.5D spell-brigade survivors

## Status

Accepted. Milestones 1 and 2 are implemented; see
[the run loop](run-loop.md), which replaces the earlier 2D top-down
prototype. The [Godot engine decision](engine-decision-godot.md) remains
valid.

## Reference

The primary reference is *Spellbrigade*: a stylized, low-poly, cooperative
survivors-like where spells fire automatically and the player's decisions are
positioning and build. What we are taking from it:

- Readable, warm, low-poly art with strong spell-effect silhouettes rather than
  texture detail.
- Combat where damage is a consequence of the build, not of aim.
- A run structure that resolves in roughly 15-20 minutes.

What we are explicitly *not* copying: its exact classes, spell names, enemy
roster, or progression numbers.

A second reference title was raised during direction setting but has not been
identified precisely enough to derive requirements from. Fill this in before
treating any of its traits as a constraint.

## Pillars

1. **Build over execution.** A run is won by the combination of spells and
   modifiers the player assembles, not by mechanical precision.
2. **Legible chaos.** Hundreds of enemies and many simultaneous effects must
   still read at a glance. Silhouette, color, and effect budget are gameplay
   systems, not polish.
3. **Short, complete runs.** Every session ends in a clear win or loss inside
   20 minutes.

## Decisions

### Presentation: 2.5D

3D scenes and assets with a camera locked to a top-down / ~45-degree angled
view. This buys real lighting, volume, and effect depth while preserving the
wide field of view and movement readability that a horde survivors-like needs.

Consequences:

- The camera is a designed, constrained system (fixed pitch, clamped yaw, a
  distance that scales with on-screen enemy density), not a free orbit.
- Enemies need clear top-down silhouettes, which constrains character
  proportions toward large heads and wide shoulders.
- `project.godot` currently uses `gl_compatibility`. Stylized lighting and
  effects want Forward+ (or Mobile) instead. Change this deliberately and
  record the minimum target hardware when doing so.

### Combat: automatic casting plus a small active kit

Base spells fire on their own cooldowns. The player additionally controls one
to three manually triggered abilities (typically a dash or repositioning tool
plus one burst).

Consequences:

- Spells are independent, data-driven, timer-driven emitters. Each one owns its
  cooldown, targeting rule, and projectile or area behavior, and none of them
  read the input layer.
- The input layer handles movement plus a small fixed set of ability slots. It
  stays thin.
- Targeting rules (nearest, random, forward, self-centered) are part of spell
  data, because they are a build decision.

### Scope: single-player first, netcode-shaped architecture

Ship and iterate the single-player loop. Do not build multiplayer yet, but do
not write code that makes it expensive later.

Rules that follow from this:

- One seeded random source per run, owned by the simulation, never
  `randf()` at call sites. The wave director already does this correctly.
- Simulation state lives in plain data that a single authority owns and mutates.
  Nodes render that state; they do not *become* it.
- No gameplay decision reads the local camera, the local viewport size, or
  input directly from inside a simulation system.
- Spawning, damage, and loot resolution funnel through explicit systems, so an
  authority check can later be added in one place per system.

## Impact on the current prototype

Keep:

- `config/waves_demo.json` and `config/waves_10min.json`. The pacing schema
  (start time, spawn interval, batch size, alive cap, type weights) is
  dimension-independent.
- `tools/validate-config.ps1`.
- The wave-director *logic* in `src/gameplay/wave_director.gd`: wave selection,
  weighted type choice, alive cap, and minimum-spawn-distance are all portable.

Rewrite:

- `_pick_edge_position` and `_arena_bounds`: `Rect2` edge spawning becomes a
  spawn ring or navmesh-bounded region in 3D.
- `src/gameplay/enemy.gd` and `src/gameplay/player_avatar.gd`: `CharacterBody2D`
  with `_draw` placeholders becomes `CharacterBody3D` with placeholder meshes.
- `src/main.tscn` and `src/main.gd`: the arena, camera rig, and HUD.

Add:

- A spell system (definitions in `config/`, runtime in `src/gameplay/spells/`).
- A level-up / draft flow, which is where the build decisions actually happen.
- Enemy contact damage and player health, which the prototype does not have.

## Milestones

1. ~~**3D vertical slice of the existing loop.**~~ Done. Port the wave director to 3D,
   placeholder meshes, camera rig, player health, contact damage, death. No
   spells yet beyond one auto-firing projectile.
2. ~~**Spell system and draft.**~~ Done. Five spells that differ in targeting
   and shape, experience orbs, a level curve, and the level-up choice screen.
   Stat upgrades came along with it rather than waiting for milestone 3,
   because without them a build had no way to answer attrition.
3. **Build depth.** Modifiers and spell interactions; the first pass at what
   makes two runs feel different.
4. **Art direction pass.** Lock palette, lighting, and effect budget against the
   legibility pillar.
5. **Multiplayer.** Only after the single-player loop is worth repeating.

## Open questions

- The second reference title needs to be identified before its traits inform
  design.
- Target platform and minimum hardware, which gates the renderer choice.
- Whether progression between runs is permanent (meta-upgrades) or purely
  per-run.
