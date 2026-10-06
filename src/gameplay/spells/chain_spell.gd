extends "res://src/gameplay/spells/spell.gd"

## Strikes the nearest enemy, then leaps to further enemies near the last hit.
##
## The chain follows the crowd rather than the player, so it rewards letting
## enemies bunch up - the opposite of what the nova rewards.

const BeamEffect := preload("res://src/gameplay/spells/beam_effect.gd")


func _has_valid_target() -> bool:
    return nearest_enemy(get_range()) != null


func _cast() -> void:
    var current := nearest_enemy(get_range())
    if current == null:
        return

    var jump_range := base_stat("jump_range", 4.0) * _multiplier("area_multiplier")
    var jumps := int(base_stat("jumps", 2.0))
    var falloff := base_stat("falloff", 0.85)
    if has_augment("conductive_web"):
        jumps += int(augment_param("conductive_web", "extra_jumps", 0.0))
        falloff = maxf(falloff, augment_param("conductive_web", "falloff", falloff))
    falloff = clampf(falloff, 0.1, 1.0)
    var damage := get_damage()
    var color := Color.from_string(str(_base.get("color", "9ef2ff")), Color.CYAN)

    var from: Vector3 = caster.global_position
    var struck: Array[int] = []

    for step in range(jumps + 1):
        if current == null:
            break
        struck.append(current.get_instance_id())
        var to: Vector3 = current.global_position
        _draw_arc(from, to, color)
        # Capture the position before the hit: a lethal hit frees the node and
        # the next jump still needs somewhere to search from.
        from = to
        deal_hit(current, damage)
        damage *= falloff
        current = _next_link(from, jump_range, struck)


func _next_link(from: Vector3, jump_range: float, struck: Array[int]) -> Node3D:
    var best: Node3D = null
    var best_distance := jump_range * jump_range
    for candidate in get_tree().get_nodes_in_group("enemies"):
        var enemy := candidate as Node3D
        if enemy == null or struck.has(enemy.get_instance_id()):
            continue
        var distance := flat_distance_squared(from, enemy.global_position)
        if distance <= best_distance:
            best_distance = distance
            best = enemy
    return best


func _draw_arc(from: Vector3, to: Vector3, color: Color) -> void:
    var beam := BeamEffect.new()
    beam.configure(from, to, color)
    projectile_parent.add_child(beam)
