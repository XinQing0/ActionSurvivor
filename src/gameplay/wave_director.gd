extends Node

const Enemy := preload("res://src/gameplay/enemy.gd")

var elapsed_time := 0.0
var current_wave_index := 0
var total_spawned := 0
var is_ready := false

var _arena_bounds: Rect2
var _player: Node2D
var _enemy_types: Dictionary
var _waves: Array
var _spawn_margin := 36.0
var _minimum_player_distance := 220.0
var _spawn_timer := 0.0
var _random := RandomNumberGenerator.new()


func configure(config_path: String, arena_bounds: Rect2, player: Node2D) -> void:
    _arena_bounds = arena_bounds
    _player = player
    var config := _load_config(config_path)
    _enemy_types = config.get("enemy_types", {})
    _waves = config.get("waves", [])
    _spawn_margin = float(config.get("spawn_margin", _spawn_margin))
    _minimum_player_distance = float(config.get("minimum_player_distance", _minimum_player_distance))
    _random.seed = int(config.get("random_seed", 20260915))
    is_ready = not _waves.is_empty() and not _enemy_types.is_empty()


func _process(delta: float) -> void:
    if not is_ready:
        return
    elapsed_time += delta
    _update_wave_index()
    _spawn_timer -= delta
    if _spawn_timer > 0.0:
        return

    var wave: Dictionary = _waves[current_wave_index]
    _spawn_timer = float(wave.get("spawn_interval_seconds", 1.0))
    var available_slots := int(wave.get("max_alive", 100)) - get_alive_enemy_count()
    var batch_size := min(int(wave.get("batch_size", 1)), max(available_slots, 0))
    for index in range(batch_size):
        _spawn_enemy(wave.get("type_weights", {}), index)


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
    enemy.position = _pick_edge_position(batch_offset)
    add_child(enemy)
    total_spawned += 1


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


func _pick_edge_position(batch_offset: int) -> Vector2:
    var candidate := Vector2.ZERO
    for attempt in range(12):
        var edge := _random.randi_range(0, 3)
        match edge:
            0:
                candidate = Vector2(_random.randf_range(_arena_bounds.position.x, _arena_bounds.end.x), _arena_bounds.position.y - _spawn_margin)
            1:
                candidate = Vector2(_arena_bounds.end.x + _spawn_margin, _random.randf_range(_arena_bounds.position.y, _arena_bounds.end.y))
            2:
                candidate = Vector2(_random.randf_range(_arena_bounds.position.x, _arena_bounds.end.x), _arena_bounds.end.y + _spawn_margin)
            _:
                candidate = Vector2(_arena_bounds.position.x - _spawn_margin, _random.randf_range(_arena_bounds.position.y, _arena_bounds.end.y))
        candidate += Vector2(batch_offset * 5.0, batch_offset * 3.0)
        if not is_instance_valid(_player) or candidate.distance_to(_player.global_position) >= _minimum_player_distance:
            return candidate
    return candidate


func get_alive_enemy_count() -> int:
    return get_tree().get_nodes_in_group("enemies").size()


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
