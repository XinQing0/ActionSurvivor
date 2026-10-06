extends "res://src/gameplay/spells/spell.gd"

## A cone of projectiles along the direction the player is moving.
##
## This is the one spell whose output depends on where the player is facing, so
## it turns "which way do I run" into a damage decision instead of pure evasion.


func _has_valid_target() -> bool:
    return not enemies_within(get_range()).is_empty()


func _cast() -> void:
    var origin: Vector3 = caster.global_position
    var forward := Vector3.FORWARD
    if caster.has_method("get_facing"):
        forward = caster.get_facing()
    if forward.length_squared() <= 0.0:
        forward = Vector3.FORWARD

    var count := get_projectile_count() + int(base_stat("extra_projectiles", 2.0))
    _fire_cone(origin, forward, count, {})

    if has_augment("backdraft"):
        var rear_count := maxi(int(ceil(float(count) * augment_param("backdraft", "rear_fraction", 0.5))), 1)
        var rear_damage := get_damage() * augment_param("backdraft", "rear_damage", 0.75)
        _fire_cone(origin, -forward, rear_count, {"damage": rear_damage})


func _fire_cone(origin: Vector3, forward: Vector3, count: int, overrides: Dictionary) -> void:
    var spread := deg_to_rad(base_stat("spread_degrees", 46.0))
    for index in range(count):
        # A single projectile goes straight ahead instead of off to one side.
        var t := 0.0 if count <= 1 else float(index) / float(count - 1) - 0.5
        var aim := forward.rotated(Vector3.UP, t * spread)
        spawn_projectile(origin, aim, overrides)
