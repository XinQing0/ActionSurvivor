extends Node3D

## A short-lived line between two points, used to show a chain link.

const DURATION := 0.16
const THICKNESS := 0.09

var _elapsed := 0.0
var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D
var _from := Vector3.ZERO
var _to := Vector3.ZERO


func configure(from: Vector3, to: Vector3, color: Color) -> void:
    _from = from
    _to = to
    var delta := to - from
    var length := delta.length()

    _material = StandardMaterial3D.new()
    _material.albedo_color = color
    _material.emission_enabled = true
    _material.emission = color
    _material.emission_energy_multiplier = 3.0
    _material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

    var mesh := BoxMesh.new()
    mesh.size = Vector3(THICKNESS, THICKNESS, maxf(length, 0.01))
    mesh.material = _material

    _mesh_instance = MeshInstance3D.new()
    _mesh_instance.mesh = mesh
    add_child(_mesh_instance)


## `look_at` requires the node to be inside the tree, so the orientation cannot
## be set in `configure`, which callers run before adding the effect.
func _ready() -> void:
    global_position = (_from + _to) * 0.5
    var delta := _to - _from
    if delta.length() > 0.001 and absf(delta.normalized().dot(Vector3.UP)) < 0.999:
        look_at(_to, Vector3.UP)


func _process(delta: float) -> void:
    _elapsed += delta
    var t := clampf(_elapsed / DURATION, 0.0, 1.0)
    _material.albedo_color.a = 1.0 - t
    if t >= 1.0:
        queue_free()
