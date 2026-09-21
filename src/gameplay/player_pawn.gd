extends CharacterBody3D

const GameLayers := preload("res://src/gameplay/game_layers.gd")

signal health_changed(current: float, maximum: float)
signal died

var max_health := 100.0
var health := 100.0
var move_speed := 6.5
var body_radius := 0.45
var body_height := 1.7
var invulnerability_seconds := 0.5
var body_color := Color(0.35, 0.9, 0.78)
var arena_radius := 14.0

var _invulnerable_for := 0.0
var _mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D
var _facing := Vector3.FORWARD


func _init() -> void:
    motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
    collision_layer = GameLayers.PLAYER
    collision_mask = 0
    _collision_shape = CollisionShape3D.new()
    _collision_shape.shape = CapsuleShape3D.new()
    add_child(_collision_shape)
    _mesh_instance = MeshInstance3D.new()
    _mesh_instance.mesh = CapsuleMesh.new()
    add_child(_mesh_instance)


func configure(definition: Dictionary) -> void:
    max_health = float(definition.get("max_health", max_health))
    health = max_health
    move_speed = float(definition.get("move_speed", move_speed))
    body_radius = float(definition.get("radius", body_radius))
    body_height = maxf(float(definition.get("height", body_height)), body_radius * 2.0)
    invulnerability_seconds = float(definition.get("invulnerability_seconds", invulnerability_seconds))
    body_color = Color.from_string(str(definition.get("color", "59e5c7")), body_color)
    _apply_shape()
    health_changed.emit(health, max_health)


func is_alive() -> bool:
    return health > 0.0


func get_facing() -> Vector3:
    return _facing


func apply_damage(amount: float) -> void:
    if not is_alive() or _invulnerable_for > 0.0:
        return
    health = maxf(health - amount, 0.0)
    _invulnerable_for = invulnerability_seconds
    health_changed.emit(health, max_health)
    if health <= 0.0:
        died.emit()


func _physics_process(delta: float) -> void:
    _invulnerable_for = maxf(_invulnerable_for - delta, 0.0)
    _mesh_instance.transparency = 0.55 if _invulnerable_for > 0.0 else 0.0

    if not is_alive():
        velocity = Vector3.ZERO
        return

    # The screen-space input axes map straight onto the world XZ plane because
    # the camera yaw is fixed. A rotatable camera would have to rotate this
    # vector by the camera basis instead.
    var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction := Vector3(input_vector.x, 0.0, input_vector.y)
    if direction.length_squared() > 0.0:
        _facing = direction.normalized()
    velocity = direction * move_speed
    move_and_slide()

    var flat := Vector2(global_position.x, global_position.z)
    var limit := maxf(arena_radius - body_radius, 0.0)
    if flat.length() > limit:
        flat = flat.normalized() * limit
        global_position.x = flat.x
        global_position.z = flat.y
    global_position.y = body_height * 0.5


func _apply_shape() -> void:
    var shape := _collision_shape.shape as CapsuleShape3D
    shape.radius = body_radius
    shape.height = body_height

    var mesh := _mesh_instance.mesh as CapsuleMesh
    mesh.radius = body_radius
    mesh.height = body_height

    var material := StandardMaterial3D.new()
    material.albedo_color = body_color
    material.emission_enabled = true
    material.emission = body_color * 0.35
    material.roughness = 0.5
    # Required for the hit-flash transparency toggle to have any effect.
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mesh.material = material
