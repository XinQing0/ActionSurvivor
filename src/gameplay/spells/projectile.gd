extends Area3D

const GameLayers := preload("res://src/gameplay/game_layers.gd")

var direction := Vector3.FORWARD
var speed := 18.0
var damage := 6.0
var pierce := 0
var lifetime := 1.5
var body_radius := 0.18
var body_color := Color(0.56, 0.84, 1.0)

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
    body.take_damage(damage)
    _hits_remaining -= 1
    if _hits_remaining <= 0:
        queue_free()


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
