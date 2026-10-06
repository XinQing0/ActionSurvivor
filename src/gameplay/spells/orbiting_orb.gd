extends Area3D

## One orb of the orbit spell.
##
## It keeps a per-enemy hit timestamp so a slow enemy sitting inside the ring
## takes damage on a fixed rhythm instead of once per physics frame.

const GameLayers := preload("res://src/gameplay/game_layers.gd")

var damage := 5.0
var hit_interval := 0.6
var source_spell: Node

var _anchor: Node3D
var _orbit_radius := 2.6
var _orbit_speed := 2.2
var _angle := 0.0
var _body_radius := 0.28
var _time := 0.0
var _last_hit := {}
var _collision_shape: CollisionShape3D
var _mesh_instance: MeshInstance3D


func _init() -> void:
    collision_layer = GameLayers.PROJECTILE
    collision_mask = GameLayers.ENEMY
    monitoring = true
    _collision_shape = CollisionShape3D.new()
    _collision_shape.shape = SphereShape3D.new()
    add_child(_collision_shape)
    _mesh_instance = MeshInstance3D.new()
    _mesh_instance.mesh = SphereMesh.new()
    add_child(_mesh_instance)


func configure(anchor: Node3D, orbit_radius: float, orbit_speed: float, start_angle: float, body_radius: float, color: Color) -> void:
    _anchor = anchor
    _orbit_radius = orbit_radius
    _orbit_speed = orbit_speed
    _angle = start_angle
    _body_radius = body_radius

    var shape := _collision_shape.shape as SphereShape3D
    shape.radius = body_radius

    var mesh := _mesh_instance.mesh as SphereMesh
    mesh.radius = body_radius
    mesh.height = body_radius * 2.0

    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 1.8
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mesh.material = material


func _physics_process(delta: float) -> void:
    if not is_instance_valid(_anchor):
        queue_free()
        return
    _time += delta
    _angle += _orbit_speed * delta
    var centre: Vector3 = _anchor.global_position
    global_position = Vector3(
        centre.x + cos(_angle) * _orbit_radius,
        centre.y,
        centre.z + sin(_angle) * _orbit_radius
    )

    for body in get_overlapping_bodies():
        _try_hit(body)


func _try_hit(body: Node3D) -> void:
    if not body.has_method("take_damage"):
        return
    var body_id := body.get_instance_id()
    var previous: float = _last_hit.get(body_id, -INF)
    if _time - previous < hit_interval:
        return
    _last_hit[body_id] = _time
    if is_instance_valid(source_spell) and source_spell.has_method("deal_hit"):
        source_spell.deal_hit(body, damage)
    else:
        body.take_damage(damage)
