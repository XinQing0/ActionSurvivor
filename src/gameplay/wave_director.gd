extends Node

const Enemy := preload("res://src/gameplay/enemy.gd")

var elapsed_time := 0.0
var current_wave_index := 0
var total_spawned := 0
var total_killed := 0
var is_ready := false
## The clock and wave schedule advance while the run is active. Spawning is a
## separate switch so it can be stopped without freezing the run clock.
var run_active := true
var spawning_enabled := true

var arena_radius := 14.0
var run_duration_seconds := 90.0

var _player: Node3D
var _enemy_types: Dictionary
var _waves: Array
var _spawn_margin := 2.0
var _minimum_player_distance := 5.5
var _spawn_timer := 0.0
var _random := RandomNumberGenerator.new()


func configure(config_path: String, player: Node3D) -> void:
    _player = player
    var config := _load_config(config_path)
    _enemy_types = config.get("enemy_types", {})
    _waves = config.get("waves", [])
    arena_radius = float(config.get("arena_radius", arena_radius))
    run_duration_seconds = float(config.get("run_duration_seconds", run_duration_seconds))
    _spawn_margin = float(config.get("spawn_margin", _spawn_margin))
    _minimum_player_distance = float(config.get("minimum_player_distance", _minimum_player_distance))
    _random.seed = int(config.get("random_seed", 20260915))
    is_ready = not _waves.is_empty() and not _enemy_types.is_empty()


func _process(delta: float) -> void:
    if not is_ready or not run_active:
        return
    elapsed_time += delta
    _update_wave_index()
    if not spawning_enabled:
        return
    _spawn_timer -= delta
    if _spawn_timer > 0.0:
        return

    var wave: Dictionary = _waves[current_wave_index]
    _spawn_timer = float(wave.get("spawn_interval_seconds", 1.0))
    var available_slots := int(wave.get("max_alive", 100)) - get_alive_enemy_count()
    var batch_size: int = mini(int(wave.get("batch_size", 1)), maxi(available_slots, 0))
    for index in range(batch_size):
        _spawn_enemy(wave.get("type_weights", {}), index)


func get_current_max_alive() -> int:
    if not is_ready:
        return 0
    return int(_waves[current_wave_index].get("max_alive", 1))


func get_alive_enemy_count() -> int:
    return get_tree().get_nodes_in_group("enemies").size()


func get_crowd_density() -> float:
    var cap := get_current_max_alive()
    if cap <= 0:
        return 0.0
    return clampf(float(get_alive_enemy_count()) / float(cap), 0.0, 1.0)


func _update_wave_index() -> void:
    for index in range(_waves.size()):
        if elapsed_time >= float(_waves[index].get("start_time_seconds", 0.0)):
            current_wave_index = index


func _spawn_enemy(weights: Dictionary, batch_offset: int) -> void:
    var enemy_type := _pick_weighted_type(weights)
    if enemy_type.is_empty() or not _enemy_types.has(enemy_type):
        return
    var enemy := Enemy.new()
    enemy.add_to_group("enemies")
    enemy.configure(_enemy_types[enemy_type], _player)
    enemy.position = _pick_spawn_position(batch_offset, enemy.body_height)
    enemy.died.connect(_on_enemy_died)
    add_child(enemy)
    total_spawned += 1


func _on_enemy_died(_enemy: Node3D) -> void:
    total_killed += 1


func _pick_weighted_type(weights: Dictionary) -> String:
    var total_weight := 0.0
    for value in weights.values():
        total_weight += max(float(value), 0.0)
    if total_weight <= 0.0:
        return ""
    var roll := _random.randf_range(0.0, total_weight)
    for key in weights.keys():
        roll -= max(float(weights[key]), 0.0)
        if roll <= 0.0:
            return str(key)
    return str(weights.keys().back())


func _pick_spawn_position(batch_offset: int, body_height: float) -> Vector3:
    # Enemies arrive on a ring just outside the arena, which is the 3D
    # equivalent of the 2D prototype's off-screen edge spawning.
    var ring_radius := arena_radius + _spawn_margin
    var spawn_y := body_height * 0.5
    var candidate := Vector3(ring_radius, spawn_y, 0.0)
    for attempt in range(12):
        var angle := _random.randf_range(0.0, TAU) + float(batch_offset) * 0.09
        candidate = Vector3(cos(angle) * ring_radius, spawn_y, sin(angle) * ring_radius)
        if not is_instance_valid(_player):
            return candidate
        var to_player := _player.global_position - candidate
        to_player.y = 0.0
        if to_player.length() >= _minimum_player_distance:
            return candidate
    return candidate


func _load_config(config_path: String) -> Dictionary:
    if not FileAccess.file_exists(config_path):
        push_error("Wave configuration not found: %s" % config_path)
        return {}
    var file := FileAccess.open(config_path, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("Wave configuration must contain a JSON object: %s" % config_path)
        return {}
    return parsed
