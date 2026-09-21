extends Node3D

## Purely cosmetic expanding ring used to make an area hit readable.
##
## Damage is already resolved by the time this appears; it exists so the player
## can tell what hit the crowd.

const DURATION := 0.28

var _radius := 3.0
var _elapsed := 0.0
var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D


func configure(radius: float, color: Color) -> void:
    _radius = radius
    _material = StandardMaterial3D.new()
    _material.albedo_color = color
    _material.emission_enabled = true
    _material.emission = color
    _material.emission_energy_multiplier = 2.5
    _material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

    var mesh := TorusMesh.new()
    mesh.inner_radius = 0.1
    mesh.outer_radius = 0.28
    mesh.rings = 32
    mesh.material = _material

    _mesh_instance = MeshInstance3D.new()
    _mesh_instance.mesh = mesh
    add_child(_mesh_instance)


func _process(delta: float) -> void:
    _elapsed += delta
    var t := clampf(_elapsed / DURATION, 0.0, 1.0)
    var scale_factor := maxf(_radius * t / 0.28, 0.01)
    _mesh_instance.scale = Vector3(scale_factor, 1.0, scale_factor)
    _material.albedo_color.a = 1.0 - t
    if t >= 1.0:
        queue_free()
