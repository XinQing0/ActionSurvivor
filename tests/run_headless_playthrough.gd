extends SceneTree

## Headless playthrough: survives a whole run and checks the win path.
##
##     godot --headless --path . --script res://tests/run_headless_playthrough.gd
##
## The smoke test only ever loses, so everything after the halfway point of a
## run - later waves, repeated level-ups, the full spell roster, the survival
## ending - was untested. This drives the pawn with a simple kiting policy
## through the accelerated 90-second run instead.
##
## Movement is applied through `Input.action_press` rather than by writing to
## the pawn, so the real input path is what gets exercised.
##
## Always run this with `--fixed-fps 60`. Godot then advances the clock by a
## fixed step instead of by real elapsed time, which together with the seeded
## spawn RNG makes the whole run reproducible. Without it two runs of identical
## code diverge wildly - one finished with 506 spawns and a win, the next with
## 176 and a loss - and the test is worthless as a regression check.

const MainScript := preload("res://src/main.gd")
const ACTIONS := ["move_left", "move_right", "move_forward", "move_back"]

## Pass `-- full` to play the ten-minute config instead of the 90-second one.
const FIXED_FPS := 60.0
var frame_budget := 0

## How far ahead of the crowd the pawn tries to stay, and how strongly it is
## pulled back once it nears the arena edge.
const THREAT_RADIUS := 7.0
const EDGE_MARGIN := 3.0

var _main: Node
var _frame := 0
var _started_at := 0.0
var _failures: Array[String] = []
var _peak_alive := 0
var _worst_frame_ms := 0.0
var _slow_frames := 0
var _drafts_resolved := 0
var _lowest_health_fraction := 1.0
var _last_frame_usec := 0


func _initialize() -> void:
    var full_run := OS.get_cmdline_user_args().has("full")
    MainScript.skip_title = true
    MainScript.selected_waves_path = (
        "res://config/waves_10min.json" if full_run else "res://config/waves_demo.json"
    )
    # A little past the run duration so the victory transition is included.
    frame_budget = int((600.0 if full_run else 90.0) * FIXED_FPS * 1.1)
    print("mode              %s" % ("full 10-minute run" if full_run else "90-second demo run"))

    var scene: PackedScene = load("res://src/main.tscn")
    _main = scene.instantiate()
    root.add_child(_main)
    _started_at = Time.get_ticks_msec() / 1000.0
    _last_frame_usec = Time.get_ticks_usec()


func _process(delta: float) -> bool:
    if _main == null:
        printerr("FAIL: the main scene did not instantiate; check for parse errors above")
        quit(1)
        return true

    _frame += 1
    _sample_performance(delta)

    if _main.run_state == _main.RunState.DRAFTING:
        _pick_option()
        return false

    if _main.run_state == _main.RunState.RUNNING:
        _drive()
        _peak_alive = maxi(_peak_alive, _main.director.get_alive_enemy_count())
        var maximum: float = _main.player.get_max_health()
        if maximum > 0.0:
            _lowest_health_fraction = minf(_lowest_health_fraction, _main.player.health / maximum)
        if _frame < frame_budget:
            return false

    _release_all()
    _report()
    return true


# --- Stand-in player ------------------------------------------------------

func _drive() -> void:
    var player: Node3D = _main.player
    var here := Vector2(player.global_position.x, player.global_position.z)
    var flee := Vector2.ZERO

    for candidate in _main.get_tree().get_nodes_in_group("enemies"):
        var enemy := candidate as Node3D
        if enemy == null:
            continue
        var offset := here - Vector2(enemy.global_position.x, enemy.global_position.z)
        var distance := offset.length()
        if distance > THREAT_RADIUS or distance < 0.001:
            continue
        # Closer enemies push harder, so the pawn squeezes out of the tightest
        # gap rather than averaging itself into the middle of the crowd.
        flee += offset.normalized() * (THREAT_RADIUS - distance) / THREAT_RADIUS

    var arena_radius: float = _main.director.arena_radius
    var from_edge := arena_radius - here.length()
    if from_edge < EDGE_MARGIN and here.length() > 0.001:
        flee += -here.normalized() * (EDGE_MARGIN - from_edge) / EDGE_MARGIN * 2.0

    if flee.length() < 0.01:
        # Nothing nearby: drift along the rim, which keeps orbiting spells
        # sweeping through enemies instead of standing in an empty patch.
        flee = Vector2(-here.y, here.x).normalized() if here.length() > 0.001 else Vector2.RIGHT

    _apply_direction(flee.normalized())


func _apply_direction(direction: Vector2) -> void:
    _release_all()
    if direction.x < -0.15:
        Input.action_press("move_left", -direction.x)
    elif direction.x > 0.15:
        Input.action_press("move_right", direction.x)
    if direction.y < -0.15:
        Input.action_press("move_forward", -direction.y)
    elif direction.y > 0.15:
        Input.action_press("move_back", direction.y)


func _release_all() -> void:
    for action in ACTIONS:
        if Input.is_action_pressed(action):
            Input.action_release(action)


## Picks the way a competent player does: collect a few spells, then pour
## levels into what you already have. Always taking the first offer instead
## spreads levels thinly across five spells, which is a weak build and made
## the run look harder than it is.
func _pick_option() -> void:
    var screen: Node = _main.get_node("DraftScreen")
    if screen == null or screen._options.is_empty():
        return
    var options: Array = screen._options
    var owned: int = _main._owned_spells.size()

    # Roughly one pick in three goes to a stat. Taking only spells leaves the
    # pawn with its starting health and no regeneration, which is not how the
    # game is meant to be played and makes a full run look unwinnable.
    var wanted := "stat"
    if _drafts_resolved % 3 != 2:
        wanted = "spell_level" if owned >= 3 else "new_spell"

    # Failing that, an augment beats an arbitrary card: it only ever improves a
    # spell the build already owns.
    var choice := _first_of_kind(options, wanted)
    if choice < 0:
        choice = _first_of_kind(options, "augment")
    if choice < 0:
        choice = 0

    _drafts_resolved += 1
    screen._choose(choice)


func _first_of_kind(options: Array, kind: String) -> int:
    for index in range(options.size()):
        if str(options[index].get("kind", "")) == kind:
            return index
    return -1


# --- Reporting ------------------------------------------------------------

## Under a fixed timestep `delta` is a constant, so it says nothing about cost.
## Real frame time has to be measured directly.
func _sample_performance(_delta: float) -> void:
    var now := Time.get_ticks_usec()
    var frame_ms := float(now - _last_frame_usec) / 1000.0
    _last_frame_usec = now
    # Early frames include scene construction.
    if _frame < 30:
        return
    _worst_frame_ms = maxf(_worst_frame_ms, frame_ms)
    if frame_ms > 16.7:
        _slow_frames += 1


func _elapsed_wall_clock() -> float:
    return Time.get_ticks_msec() / 1000.0 - _started_at


func _report() -> void:
    var director: Node = _main.director
    var progression: RefCounted = _main.progression
    var owned: Dictionary = _main._owned_spells

    _check(_main.run_state == _main.RunState.WON, "the run was survived to the end")
    _check(
        director.elapsed_time >= director.run_duration_seconds,
        "the full run duration elapsed"
    )
    _check(director.current_wave_index > 0, "later waves were reached")
    # Scaled by run length: a flat threshold judged the 90-second demo against
    # the same bar as a run seven times longer.
    var expected_kills: float = director.run_duration_seconds * 0.3
    _check(
        float(director.total_killed) > expected_kills,
        "the build cleared a meaningful number of enemies (%d, wanted over %d)" % [
            director.total_killed, int(expected_kills)
        ]
    )
    _check(progression.level >= 5, "the player levelled several times")
    _check(_drafts_resolved >= 4, "several drafts were resolved")
    _check(owned.size() >= 2, "the run acquired more than the starting spell")
    _check(_main.player.is_alive(), "the player finished alive")
    _check(director.get_alive_enemy_count() == 0, "the arena was cleared on victory")
    _check(_worst_frame_ms < 100.0, "no frame took longer than 100ms")

    print("--- headless playthrough ---")
    print("frames            %d" % _frame)
    print("wall clock        %.1fs real, fixed %.0f fps timestep" % [_elapsed_wall_clock(), FIXED_FPS])
    print("run time          %.1f / %.0fs" % [director.elapsed_time, director.run_duration_seconds])
    print("final wave        %d" % (director.current_wave_index + 1))
    print("spawned / killed  %d / %d  (%d walked off)" % [
        director.total_spawned, director.total_killed, director.total_despawned
    ])
    print("peak alive        %d" % _peak_alive)
    print("level             %d after %d drafts" % [progression.level, _drafts_resolved])
    print("build             %s" % _main._describe_build())
    print("reactions         %s" % str(_main.reactions.counts))
    print("lowest health     %d%%" % roundi(_lowest_health_fraction * 100.0))
    print("worst frame       %.1fms, %d frames over 16.7ms" % [_worst_frame_ms, _slow_frames])
    print("result            %s" % ("WON" if _main.run_state == _main.RunState.WON else "LOST"))

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
