extends Node

const Enemy := preload("res://src/gameplay/enemy.gd")

## Handed to every enemy so statuses can resolve into reactions.
var reactions: Node

signal enemy_died(position: Vector3, experience: int)

var elapsed_time := 0.0
var current_wave_index := 0
var total_spawned := 0
var total_killed := 0
var total_despawned := 0
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
var _spawn_ring_radius := 17.0
var _minimum_player_distance := 9.0
var _despawn_radius := 30.0
var _cull_timer := 0.0
var _spawn_timer := 0.0
var _random := RandomNumberGenerator.new()


func configure(config_path: String, player: Node3D) -> void:
    _player = player
    var config := _load_config(config_path)
    _enemy_types = config.get("enemy_types", {})
    _waves = config.get("waves", [])
    arena_radius = float(config.get("arena_radius", arena_radius))
    run_duration_seconds = float(config.get("run_duration_seconds", run_duration_seconds))
    _spawn_ring_radius = float(config.get("spawn_ring_radius", _spawn_ring_radius))
    _despawn_radius = float(config.get("despawn_radius", _despawn_radius))
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
    _cull_distant_enemies(delta)
    _spawn_timer -= delta
    if _spawn_timer > 0.0:
        return

    var wave: Dictionary = _waves[current_wave_index]
    _spawn_timer = float(wave.get("spawn_interval_seconds", 1.0))
    var available_slots := int(wave.get("max_alive", 100)) - get_alive_enemy_count()
    var batch_size: int = mini(int(wave.get("batch_size", 1)), maxi(available_slots, 0))
    for index in range(batch_size):
        _spawn_enemy(wave.get("type_weights", {}), index)


## Enemy health scales with the wave rather than with the player's build, so
## the pacing curve stays in the config where it can be tuned without code.
## Removes enemies that have fallen far behind.
##
## Without this the alive cap fills up with a single clump trailing the player,
## nothing new can spawn ahead of them, and running in one direction becomes a
## free win. Culling the stragglers frees cap slots so the horde keeps
## re-forming around the player wherever they have run to.
##
## A cull is not a kill: it awards no experience and does not count towards the
## slain total, so running away is never a way to farm progress.
const CULL_INTERVAL := 0.5


func _cull_distant_enemies(delta: float) -> void:
    _cull_timer -= delta
    if _cull_timer > 0.0 or not is_instance_valid(_player):
        return
    _cull_timer = CULL_INTERVAL

    var origin: Vector3 = _player.global_position
    var limit_squared := _despawn_radius * _despawn_radius
    for candidate in get_tree().get_nodes_in_group("enemies"):
        var enemy := candidate as Node3D
        if enemy == null:
            continue
        var offset := enemy.global_position - origin
        offset.y = 0.0
        if offset.length_squared() > limit_squared:
            enemy.remove_from_group("enemies")
            enemy.queue_free()
            total_despawned += 1


func get_health_multiplier() -> float:
    if not is_ready:
        return 1.0
    return maxf(float(_waves[current_wave_index].get("health_multiplier", 1.0)), 0.1)


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
    enemy.reactions = reactions
    enemy.configure(_enemy_types[enemy_type], _player, get_health_multiplier())
    enemy.position = _pick_spawn_position(batch_offset, enemy.body_height)
    enemy.died.connect(_on_enemy_died)
    add_child(enemy)
    total_spawned += 1


func _on_enemy_died(_enemy: Node3D, position: Vector3, experience: int) -> void:
    total_killed += 1
    enemy_died.emit(position, experience)


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


## Enemies appear on a ring around the *player*, not around the arena.
##
## Spawning on the arena edge made the arena size double as the difficulty
## valve: the crowd could only ever be as dense as the arena allowed, and once
## the cap was reached there was nowhere left to run. Anchoring the ring to the
## player means the horde always closes in from just out of view no matter
## where the player has run to, so the arena can be large enough to kite in
## without making the pressure disappear.
func _pick_spawn_position(batch_offset: int, body_height: float) -> Vector3:
    var spawn_y := body_height * 0.5
    var origin := _player.global_position if is_instance_valid(_player) else Vector3.ZERO
    origin.y = 0.0

    var fallback := Vector3(_spawn_ring_radius, spawn_y, 0.0)
    for attempt in range(16):
        var angle := _random.randf_range(0.0, TAU) + float(batch_offset) * 0.09
        var candidate := origin + Vector3(cos(angle), 0.0, sin(angle)) * _spawn_ring_radius
        candidate.y = spawn_y
        fallback = candidate
        if Vector2(candidate.x, candidate.z).length() <= arena_radius:
            return candidate

    # Every angle landed outside the arena, which only happens when the ring is
    # wider than the arena. Pull the last candidate back inside, keeping it far
    # enough away that it does not appear on top of the player.
    var flat := Vector2(fallback.x, fallback.z)
    if flat.length() > 0.001:
        flat = flat.normalized() * arena_radius
    var pulled := Vector3(flat.x, spawn_y, flat.y)
    var separation := Vector2(pulled.x - origin.x, pulled.z - origin.z)
    if separation.length() < _minimum_player_distance and separation.length() > 0.001:
        separation = separation.normalized() * _minimum_player_distance
        pulled = Vector3(origin.x + separation.x, spawn_y, origin.z + separation.y)
    return pulled


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
