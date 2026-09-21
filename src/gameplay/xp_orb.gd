extends Node3D

## An experience pickup dropped by a dying enemy.
##
## Collection is a distance check against the player rather than an Area3D.
## There can be hundreds of these on the floor late in a run, and a plain
## distance test is both cheaper than physics queries and deterministic, which
## matters for the eventual move to a server authority.

const BOB_HEIGHT := 0.12
const BOB_SPEED := 4.0

signal collected(value: int)

var value := 1
var magnet_speed := 14.0

var _player: Node3D
var _base_y := 0.35
var _time := 0.0
var _magnetised := false


func configure(xp_value: int, player: Node3D, radius: float, color: Color, speed: float) -> void:
    value = xp_value
    _player = player
    magnet_speed = speed
    _base_y = radius * 1.6

    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0

    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 2.2
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mesh.material = material

    var mesh_instance := MeshInstance3D.new()
    mesh_instance.mesh = mesh
    add_child(mesh_instance)


func _process(delta: float) -> void:
    if not is_instance_valid(_player):
        return

    var to_player: Vector3 = _player.global_position - global_position
    to_player.y = 0.0
    var distance := to_player.length()

    var pickup_radius := 1.0
    if _player.has_method("get_pickup_radius"):
        pickup_radius = _player.get_pickup_radius()

    # Once an orb starts flying it keeps flying, so widening the pickup radius
    # never strands an orb halfway.
    if distance <= pickup_radius:
        _magnetised = true

    if _magnetised:
        var step := magnet_speed * delta
        if distance <= step + 0.3:
            collected.emit(value)
            queue_free()
            return
        global_position += to_player.normalized() * step
        global_position.y = _base_y
        return

    _time += delta
    global_position.y = _base_y + sin(_time * BOB_SPEED) * BOB_HEIGHT
