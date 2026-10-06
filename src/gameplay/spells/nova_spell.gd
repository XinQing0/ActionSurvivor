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
    _pulse(1.0)
    if has_augment("twin_pulse"):
        var delay := augment_param("twin_pulse", "delay", 0.35)
        get_tree().create_timer(delay).timeout.connect(
            _pulse.bind(augment_param("twin_pulse", "scale", 0.6))
        )


func _pulse(damage_scale: float) -> void:
    if not is_instance_valid(caster):
        return
    var radius := get_area()
    var damage := get_damage() * damage_scale
    for enemy in enemies_within(radius):
        deal_hit(enemy, damage)

    var effect := RingEffect.new()
    effect.configure(radius, Color.from_string(str(_base.get("color", "ffb45c")), Color.ORANGE))
    effect.position = caster.global_position
    projectile_parent.add_child(effect)
