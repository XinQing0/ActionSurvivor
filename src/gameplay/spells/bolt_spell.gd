extends "res://src/gameplay/spells/spell.gd"

## Baseline single-target spell: fires at the nearest enemy in range.
##
## Extra projectile count is spent on separate targets when there are enough,
## so stacking count turns it into crowd clearing rather than overkill.


func _has_valid_target() -> bool:
    return nearest_enemy(get_range()) != null


func _cast() -> void:
    var origin: Vector3 = caster.global_position
    var wanted := get_projectile_count()
    var targets := enemies_within(get_range())
    if targets.is_empty():
        return

    targets.sort_custom(func(a: Node3D, b: Node3D) -> bool:
        return flat_distance_squared(origin, a.global_position) < flat_distance_squared(origin, b.global_position)
    )

    for index in range(wanted):
        var target: Node3D = targets[index % targets.size()]
        var aim: Vector3 = target.global_position - origin
        aim.y = 0.0
        # Repeat passes over the same target list get a slight spread so the
        # bolts stay visually distinct instead of overlapping exactly.
        if index >= targets.size():
            aim = aim.rotated(Vector3.UP, _random.randf_range(-0.12, 0.12))
        spawn_projectile(origin, aim)
