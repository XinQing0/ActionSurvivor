extends SceneTree

## Headless smoke test for the run loop.
##
## Run it from the repository root:
##
##     godot --headless --path . --script res://tests/run_headless_smoke.gd
##
## It boots the real main scene, plays a run without a human, and asserts that
## every system actually did something: waves spawn, spells kill, experience
## drops and is collected, levelling opens a draft, a draft pick is applied,
## and the run ends. It exits non-zero on the first failed check so it can gate
## CI later.
##
## The pawn is never driven, so a stationary player is worn down by contact
## damage. That is the loss path, and it is what ends the run here.

const SIMULATED_SECONDS := 30.0
const FRAME_BUDGET := 40000
const MainScript := preload("res://src/main.gd")

var _main: Node
var _frame := 0
var _failures: Array[String] = []
var _saw_projectile := false
var _saw_orb := false
var _saw_draft := false
var _peak_alive := 0
var _drafts_resolved := 0


func _initialize() -> void:
    # Skip the title screen: nothing is here to click through it.
    MainScript.skip_title = true
    MainScript.selected_waves_path = "res://config/waves_demo.json"

    var scene: PackedScene = load("res://src/main.tscn")
    _main = scene.instantiate()
    root.add_child(_main)


func _process(_delta: float) -> bool:
    # A script that failed to compile leaves `_main` null. Without this the
    # test spins for its whole frame budget emitting one error per frame.
    if _main == null:
        printerr("FAIL: the main scene did not instantiate; check for parse errors above")
        quit(1)
        return true

    _frame += 1
    _peak_alive = maxi(_peak_alive, _main.director.get_alive_enemy_count())
    _saw_projectile = _saw_projectile or _child_count("Projectiles") > 0
    _saw_orb = _saw_orb or _child_count("Orbs") > 0

    if _main.run_state == _main.RunState.DRAFTING:
        _saw_draft = true
        _pick_first_option()

    # The run clock stops when the run ends, so stopping on elapsed time alone
    # would spin until the frame budget after the player goes down.
    var run_over: bool = _main.run_state == _main.RunState.WON or _main.run_state == _main.RunState.LOST
    if not run_over and _main.director.elapsed_time < SIMULATED_SECONDS and _frame < FRAME_BUDGET:
        return false

    _report()
    return true


## Stands in for a player clicking a card, so the draft path is exercised
## rather than merely reached.
func _pick_first_option() -> void:
    var screen: Node = _main.get_node("DraftScreen")
    if screen == null or screen._options.is_empty():
        return
    _drafts_resolved += 1
    screen._choose(0)


func _child_count(node_name: String) -> int:
    var node: Node = _main.get_node_or_null(node_name)
    return 0 if node == null else node.get_child_count()


func _report() -> void:
    var director: Node = _main.director
    var player: Node = _main.player
    var progression: RefCounted = _main.progression

    _check(director.is_ready, "wave director loaded its configuration")
    _check(director.elapsed_time > 0.0, "run clock advanced")
    _check(director.total_spawned > 0, "enemies spawned")
    _check(_peak_alive > 0, "enemies were alive in the arena")
    _check(_saw_projectile, "the auto-casting spell produced a projectile")
    _check(director.total_killed > 0, "spells killed at least one enemy")
    _check(_saw_orb, "a dying enemy dropped an experience orb")
    _check(progression.experience > 0 or progression.level > 1, "experience was collected")
    _check(progression.level > 1, "the player levelled up")
    _check(_saw_draft, "levelling opened a draft")
    _check(_drafts_resolved > 0, "a draft option was picked")
    _check(_main._owned_spells.size() >= 1, "the run tracks owned spells")
    _check(player.max_health > 0.0, "player loadout applied")
    _check(player.health <= 0.0, "an idle player took lethal contact damage")
    _check(_main.run_state == _main.RunState.LOST, "the run ended in a loss")
    _check(not director.run_active, "the run clock stopped when the run ended")
    _check(paused, "the tree is paused on the result screen")
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
    print("level             %d" % progression.level)
    print("drafts resolved   %d" % _drafts_resolved)
    print("build             %s" % _main._describe_build())
    print("player hp         %.0f / %.0f" % [player.health, player.get_max_health()])

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
