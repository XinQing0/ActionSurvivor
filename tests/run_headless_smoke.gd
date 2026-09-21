extends SceneTree

## Headless smoke test for the milestone 1 run loop.
##
## Run it from the repository root:
##
##     godot --headless --path . --script res://tests/run_headless_smoke.gd
##
## It boots the real main scene, advances a fixed span of game time, and asserts
## that the wave director, the auto-casting spell, and the run-end transition
## all actually did something. It exits non-zero on the first failed check so it
## can gate CI later.

const SIMULATED_SECONDS := 20.0
const FRAME_BUDGET := 30000

var _main: Node
var _frame := 0
var _failures: Array[String] = []
var _saw_projectile := false
var _peak_alive := 0


func _initialize() -> void:
    var scene: PackedScene = load("res://src/main.tscn")
    _main = scene.instantiate()
    root.add_child(_main)


func _process(_delta: float) -> bool:
    _frame += 1
    _peak_alive = maxi(_peak_alive, _main.director.get_alive_enemy_count())
    var projectiles := _main.get_node_or_null("Projectiles")
    if projectiles != null and projectiles.get_child_count() > 0:
        _saw_projectile = true
    # The run clock stops when the run ends, so stopping on elapsed time alone
    # would spin until the frame budget after the player goes down.
    var run_over: bool = _main.run_state != _main.RunState.RUNNING
    if not run_over and _main.director.elapsed_time < SIMULATED_SECONDS and _frame < FRAME_BUDGET:
        return false

    _report()
    return true


func _report() -> void:
    var director: Node = _main.director
    var player: Node = _main.player

    _check(director.is_ready, "wave director loaded its configuration")
    _check(director.elapsed_time > 0.0, "run clock advanced")
    _check(director.total_spawned > 0, "enemies spawned")
    _check(_peak_alive > 0, "enemies were alive in the arena")
    _check(_saw_projectile, "the auto-casting spell produced a projectile")
    _check(director.total_killed > 0, "projectiles killed at least one enemy")
    _check(player.max_health > 0.0, "player loadout applied")
    # Nobody drives the pawn in headless, so a stationary player must be worn
    # down by contact damage. This covers damage, death, and the run-end path.
    _check(player.health <= 0.0, "an idle player took lethal contact damage")
    _check(_main.run_state == _main.RunState.LOST, "the run ended in a loss")
    _check(not director.run_active, "the run clock stopped when the run ended")
    _check(
        absf(player.global_position.y - player.body_height * 0.5) < 0.01,
        "player stayed on the ground plane"
    )
    _check(
        Vector2(player.global_position.x, player.global_position.z).length() <= director.arena_radius,
        "player stayed inside the arena"
    )

    print("--- headless smoke ---")
    print("frames            %d" % _frame)
    print("elapsed           %.2fs" % director.elapsed_time)
    print("wave              %d" % (director.current_wave_index + 1))
    print("spawned / killed  %d / %d" % [director.total_spawned, director.total_killed])
    print("peak alive        %d" % _peak_alive)
    print("player hp         %.0f / %.0f" % [player.health, player.max_health])

    if _failures.is_empty():
        print("PASS")
        quit(0)
        return
    for failure in _failures:
        printerr("FAIL: %s" % failure)
    quit(1)


func _check(condition: bool, description: String) -> void:
    if not condition:
        _failures.append(description)
