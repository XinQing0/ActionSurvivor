extends "res://src/gameplay/spells/spell.gd"

## Persistent orbs circling the caster.
##
## Unlike the other spells this one has no cast rhythm: it maintains its orbs
## and they damage on contact. The cooldown instead controls how often a given
## enemy can be hit by the same orb.

const OrbitingOrb := preload("res://src/gameplay/spells/orbiting_orb.gd")

var _orbs: Array[Node3D] = []


func _on_configured() -> void:
    _rebuild_orbs()


func _on_level_changed() -> void:
    _rebuild_orbs()


## The orbs are the spell, so the cooldown loop has nothing to fire.
func _has_valid_target() -> bool:
    return false


func _process(delta: float) -> void:
    super._process(delta)
    if not is_instance_valid(caster):
        return
    # Orb count follows the projectile-count bonus, so a count upgrade grows the
    # ring the same way it grows a fan of bolts.
    if _orbs.size() != get_projectile_count():
        _rebuild_orbs()
    for orb in _orbs:
        if is_instance_valid(orb):
            orb.damage = get_damage()
            orb.hit_interval = get_cooldown()


func _rebuild_orbs() -> void:
    for orb in _orbs:
        if is_instance_valid(orb):
            orb.queue_free()
    _orbs.clear()

    if not is_instance_valid(caster):
        return
    var count := get_projectile_count()
    var color := Color.from_string(str(_base.get("color", "c8a0ff")), Color.MEDIUM_PURPLE)
    for index in range(count):
        var orb := OrbitingOrb.new()
        orb.configure(
            caster,
            base_stat("orbit_radius", 2.6) * _multiplier("area_multiplier"),
            base_stat("orbit_speed", 2.2),
            TAU * float(index) / float(count),
            base_stat("projectile_radius", 0.28),
            color
        )
        orb.damage = get_damage()
        orb.hit_interval = get_cooldown()
        orb.source_spell = self
        projectile_parent.add_child(orb)
        _orbs.append(orb)
