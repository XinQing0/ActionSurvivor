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

## Set by the wave director. Statuses resolve through it, and an enemy created
## without one (a bare test fixture) simply never reacts.
var reactions: Node

const HIT_FLASH_SECONDS := 0.09
const BURN_TICK_SECONDS := 0.5
const STATUS_COLORS := {
    "burn": Color(1.0, 0.45, 0.12),
    "shock": Color(1.0, 0.92, 0.3),
    "chill": Color(0.45, 0.78, 1.0),
}
const STATUS_GLOW := 0.7

var _attack_cooldown := 0.0
var _flash_for := 0.0
var _statuses := {}
var _reaction_lockout := 0.0
var _tinted := false
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


## `from_status` marks damage-over-time ticks, which skip the hit flash so a
## burning enemy does not strobe white.
func take_damage(amount: float, from_status: bool = false) -> void:
    if health <= 0.0:
        return
    if reactions != null:
        amount *= reactions.damage_taken_multiplier(self)
    health -= amount
    if not from_status:
        _flash_for = HIT_FLASH_SECONDS
    if health <= 0.0:
        if reactions != null:
            reactions.on_enemy_killed(self)
        died.emit(self, global_position, experience)
        queue_free()


## Statuses refresh rather than stack: re-applying keeps the longer duration and
## the stronger potency. Stacking would make the first spell to land one the only
## one that matters.
func apply_status(status_id: String, duration: float, potency: float) -> void:
    if health <= 0.0:
        return
    var current: Dictionary = _statuses.get(status_id, {})
    _statuses[status_id] = {
        "remaining": maxf(float(current.get("remaining", 0.0)), duration),
        "potency": maxf(float(current.get("potency", 0.0)), potency),
        "tick": float(current.get("tick", BURN_TICK_SECONDS)),
    }
    if reactions != null:
        reactions.evaluate(self, status_id)


func has_status(status_id: String) -> bool:
    return _statuses.has(status_id)


func get_status_potency(status_id: String) -> float:
    return float(_statuses.get(status_id, {}).get("potency", 0.0))


func clear_status(status_id: String) -> void:
    _statuses.erase(status_id)


func is_reaction_locked() -> bool:
    return _reaction_lockout > 0.0


func lock_reactions(seconds: float) -> void:
    _reaction_lockout = maxf(_reaction_lockout, seconds)


func _physics_process(delta: float) -> void:
    _attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
    _reaction_lockout = maxf(_reaction_lockout - delta, 0.0)
    _update_statuses(delta)
    if health <= 0.0:
        return
    _update_visuals(delta)
    if not is_instance_valid(target):
        velocity = Vector3.ZERO
        return

    var to_target := target.global_position - global_position
    to_target.y = 0.0
    var distance := to_target.length()
    var touch_distance := body_radius + _target_radius()

    if distance > touch_distance:
        velocity = to_target.normalized() * move_speed * _speed_factor()
    else:
        velocity = Vector3.ZERO
        _try_attack()
    move_and_slide()
    global_position.y = body_height * 0.5


func _update_statuses(delta: float) -> void:
    if _statuses.is_empty():
        return
    for status_id in _statuses.keys():
        var status: Dictionary = _statuses[status_id]
        status["remaining"] = float(status["remaining"]) - delta
        if status_id == "burn":
            status["tick"] = float(status["tick"]) - delta
            while float(status["tick"]) <= 0.0 and health > 0.0:
                status["tick"] = float(status["tick"]) + BURN_TICK_SECONDS
                take_damage(float(status["potency"]) * BURN_TICK_SECONDS, true)
        if health <= 0.0:
            return
        if float(status["remaining"]) <= 0.0:
            _statuses.erase(status_id)


func _speed_factor() -> float:
    if not _statuses.has("chill"):
        return 1.0
    return clampf(1.0 - get_status_potency("chill"), 0.1, 1.0)


## A brief white flash is the only feedback that a hit landed. Without it a
## high-health enemy walking through a stream of projectiles looks unaffected.
## Between flashes a glow in the colour of the active status shows what the
## enemy is primed for, which is what makes a reaction readable before it fires.
func _update_visuals(delta: float) -> void:
    _flash_for = maxf(_flash_for - delta, 0.0)
    var glow: Variant = _status_glow_color()
    if _flash_for <= 0.0 and glow == null and not _tinted:
        return
    var blend := _flash_for / HIT_FLASH_SECONDS
    if glow != null:
        _material.albedo_color = body_color.lerp(glow, 0.35).lerp(Color.WHITE, blend)
        _material.emission = glow.lerp(Color.WHITE, blend)
        _material.emission_energy_multiplier = maxf(STATUS_GLOW, blend * 1.5)
        _tinted = true
    else:
        _material.albedo_color = body_color.lerp(Color.WHITE, blend)
        _material.emission = Color.WHITE
        _material.emission_energy_multiplier = blend * 1.5
        _tinted = _flash_for > 0.0


func _status_glow_color() -> Variant:
    for status_id in ["shock", "burn", "chill"]:
        if _statuses.has(status_id):
            return STATUS_COLORS[status_id]
    return null


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
