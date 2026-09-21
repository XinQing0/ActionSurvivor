extends "res://src/gameplay/spells/spell.gd"

## Self-centred pulse that damages everything around the caster at once.
##
## This is the answer to being surrounded, which is exactly the situation the
## bolt handles worst, so the two spells cover different failure states rather
## than stacking the same one.

const RingEffect := preload("res://src/gameplay/spells/ring_effect.gd")


func _has_valid_target() -> bool:
    return not enemies_within(get_area()).is_empty()


func _cast() -> void:
    var radius := get_area()
    var damage := get_damage()
    for enemy in enemies_within(radius):
        if enemy.has_method("take_damage"):
            enemy.take_damage(damage)

    var effect := RingEffect.new()
    effect.configure(radius, Color.from_string(str(_base.get("color", "ffb45c")), Color.ORANGE))
    effect.position = caster.global_position
    projectile_parent.add_child(effect)
