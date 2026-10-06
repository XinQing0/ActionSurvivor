extends Area3D

const GameLayers := preload("res://src/gameplay/game_layers.gd")

var direction := Vector3.FORWARD
var speed := 18.0
var damage := 6.0
var pierce := 0
var lifetime := 1.5
var body_radius := 0.18
var body_color := Color(0.56, 0.84, 1.0)

## The spell that fired this. Hits are routed through it so its status applies.
var source_spell: Node

## Rebounds still available. Only an augment grants them.
var bounces := 0
var bounce_range := 6.0
var bounce_retained := 0.8

var _hits_remaining := 1
var _already_hit: Array[int] = []
var _collision_shape: CollisionShape3D
var _mesh_instance: MeshInstance3D


func _init() -> void:
    collision_layer = GameLayers.PROJECTILE
    collision_mask = GameLayers.ENEMY
    _collision_shape = CollisionShape3D.new()
    _collision_shape.shape = SphereShape3D.new()
    add_child(_collision_shape)
    _mesh_instance = MeshInstance3D.new()
    _mesh_instance.mesh = SphereMesh.new()
    add_child(_mesh_instance)


func configure(definition: Dictionary, start_position: Vector3, travel_direction: Vector3) -> void:
    speed = float(definition.get("projectile_speed", speed))
    damage = float(definition.get("damage", damage))
    pierce = int(definition.get("pierce", pierce))
    lifetime = float(definition.get("lifetime_seconds", lifetime))
    body_radius = float(definition.get("projectile_radius", body_radius))
    body_color = Color.from_string(str(definition.get("color", "8fd6ff")), body_color)
    bounces = int(definition.get("bounces", bounces))
    bounce_range = float(definition.get("bounce_range", bounce_range))
    bounce_retained = float(definition.get("bounce_retained", bounce_retained))
    _hits_remaining = pierce + 1
    direction = travel_direction.normalized() if travel_direction.length_squared() > 0.0 else Vector3.FORWARD
    position = start_position
    _apply_shape()


func _ready() -> void:
    body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
    lifetime -= delta
    if lifetime <= 0.0:
        queue_free()
        return
    global_position += direction * speed * delta


func _on_body_entered(body: Node3D) -> void:
    if not body.has_method("take_damage"):
        return
    var body_id := body.get_instance_id()
    if _already_hit.has(body_id):
        return
    _already_hit.append(body_id)
    if is_instance_valid(source_spell) and source_spell.has_method("deal_hit"):
        source_spell.deal_hit(body, damage)
    else:
        body.take_damage(damage)
    if bounces > 0 and _rebound(body):
        return
    _hits_remaining -= 1
    if _hits_remaining <= 0:
        queue_free()


## Redirects towards the nearest enemy this projectile has not touched yet.
## Returns false when there is nobody to rebound to, so the projectile ends
## normally instead of flying on through empty space.
func _rebound(from_body: Node3D) -> bool:
    var best: Node3D = null
    var best_distance := bounce_range * bounce_range
    for candidate in get_tree().get_nodes_in_group("enemies"):
        var enemy := candidate as Node3D
        if enemy == null or enemy == from_body or _already_hit.has(enemy.get_instance_id()):
            continue
        var offset := enemy.global_position - global_position
        offset.y = 0.0
        if offset.length_squared() <= best_distance:
            best_distance = offset.length_squared()
            best = enemy
    if best == null:
        return false
    var aim := best.global_position - global_position
    aim.y = 0.0
    direction = aim.normalized()
    bounces -= 1
    damage *= bounce_retained
    # Enough time to cross the gap even if the original flight was nearly spent.
    lifetime = maxf(lifetime, bounce_range / maxf(speed, 0.5) + 0.1)
    return true


func _apply_shape() -> void:
    var shape := _collision_shape.shape as SphereShape3D
    shape.radius = body_radius

    var mesh := _mesh_instance.mesh as SphereMesh
    mesh.radius = body_radius
    mesh.height = body_radius * 2.0

    var material := StandardMaterial3D.new()
    material.albedo_color = body_color
    material.emission_enabled = true
    material.emission = body_color
    material.emission_energy_multiplier = 2.0
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mesh.material = material
