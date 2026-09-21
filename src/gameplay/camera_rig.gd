extends Camera3D

## A constrained follow camera, not a free orbit.
##
## Pitch and yaw are fixed so the input axes can map directly onto the world XZ
## plane, and the distance opens up as the arena fills so a dense crowd stays
## readable.

const PITCH_DEGREES := 55.0
const BASE_DISTANCE := 17.0
const CROWD_DISTANCE_BONUS := 6.0
const FOLLOW_SMOOTHING := 6.0
const DENSITY_SMOOTHING := 1.5

var target: Node3D

var _density := 0.0
var _distance := BASE_DISTANCE


func _ready() -> void:
    current = true
    fov = 60.0


func set_density(ratio: float) -> void:
    _density = clampf(ratio, 0.0, 1.0)


func _process(delta: float) -> void:
    if not is_instance_valid(target):
        return

    var desired_distance := BASE_DISTANCE + CROWD_DISTANCE_BONUS * _density
    _distance = lerpf(_distance, desired_distance, 1.0 - exp(-DENSITY_SMOOTHING * delta))

    var pitch := deg_to_rad(PITCH_DEGREES)
    var offset := Vector3(0.0, sin(pitch), cos(pitch)) * _distance
    var focus := target.global_position
    focus.y = 0.0
    var desired_position := focus + offset
    global_position = global_position.lerp(desired_position, 1.0 - exp(-FOLLOW_SMOOTHING * delta))
    look_at(focus, Vector3.UP)
