extends CharacterBody3D

const GameLayers := preload("res://src/gameplay/game_layers.gd")

signal died(enemy: Node3D, position: Vector3, experience: int)

var target: Node3D
var move_speed := 2.6
var max_health := 10.0
var health := 10.0
var body_radius := 0.35
var body_height := 0.8
var contact_damage := 6.0
var attack_interval := 0.8
var experience := 1
var body_color := Color.WHITE

const HIT_FLASH_SECONDS := 0.09

var _attack_cooldown := 0.0
var _flash_for := 0.0
var _mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D
var _material: StandardMaterial3D


func _init() -> void:
    motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
    collision_layer = GameLayers.ENEMY
    collision_mask = GameLayers.ENEMY
    _collision_shape = CollisionShape3D.new()
    _collision_shape.shape = CapsuleShape3D.new()
    add_child(_collision_shape)
    _mesh_instance = MeshInstance3D.new()
    _mesh_instance.mesh = CapsuleMesh.new()
    add_child(_mesh_instance)


func configure(definition: Dictionary, new_target: Node3D, health_multiplier: float = 1.0) -> void:
    target = new_target
    move_speed = float(definition.get("speed", move_speed))
    max_health = float(definition.get("health", max_health)) * maxf(health_multiplier, 0.1)
    health = max_health
    experience = int(definition.get("experience", experience))
    body_radius = float(definition.get("radius", body_radius))
    # A capsule's total height must cover both hemispheres.
    body_height = maxf(float(definition.get("height", body_height)), body_radius * 2.0)
    contact_damage = float(definition.get("contact_damage", contact_damage))
    attack_interval = maxf(float(definition.get("attack_interval_seconds", attack_interval)), 0.05)
    body_color = Color.from_string(str(definition.get("color", "ffffff")), Color.WHITE)
    _apply_shape()


func take_damage(amount: float) -> void:
    if health <= 0.0:
        return
    health -= amount
    _flash_for = HIT_FLASH_SECONDS
    if health <= 0.0:
        died.emit(self, global_position, experience)
        queue_free()


func _physics_process(delta: float) -> void:
    _attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
    _update_hit_flash(delta)
    if not is_instance_valid(target):
        velocity = Vector3.ZERO
        return

    var to_target := target.global_position - global_position
    to_target.y = 0.0
    var distance := to_target.length()
    var touch_distance := body_radius + _target_radius()

    if distance > touch_distance:
        velocity = to_target.normalized() * move_speed
    else:
        velocity = Vector3.ZERO
        _try_attack()
    move_and_slide()
    global_position.y = body_height * 0.5


## A brief white flash is the only feedback that a hit landed. Without it a
## high-health enemy walking through a stream of projectiles looks unaffected.
func _update_hit_flash(delta: float) -> void:
    if _flash_for <= 0.0:
        return
    _flash_for = maxf(_flash_for - delta, 0.0)
    var blend := _flash_for / HIT_FLASH_SECONDS
    _material.albedo_color = body_color.lerp(Color.WHITE, blend)
    _material.emission_energy_multiplier = blend * 1.5


func _target_radius() -> float:
    var value: Variant = target.get("body_radius")
    return float(value) if value != null else 0.5


func _try_attack() -> void:
    if _attack_cooldown > 0.0:
        return
    if not target.has_method("apply_damage"):
        return
    _attack_cooldown = attack_interval
    target.apply_damage(contact_damage)


func _apply_shape() -> void:
    var shape := _collision_shape.shape as CapsuleShape3D
    shape.radius = body_radius
    shape.height = body_height

    var mesh := _mesh_instance.mesh as CapsuleMesh
    mesh.radius = body_radius
    mesh.height = body_height

    _material = StandardMaterial3D.new()
    _material.albedo_color = body_color
    _material.roughness = 0.75
    _material.emission_enabled = true
    _material.emission = Color.WHITE
    _material.emission_energy_multiplier = 0.0
    mesh.material = _material
