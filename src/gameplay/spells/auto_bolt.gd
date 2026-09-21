extends Node

## A data-driven auto-casting spell.
##
## The emitter owns its own cooldown and targeting rule and never reads the
## input layer, so adding manually triggered abilities later does not change
## how automatic spells work.

const Projectile := preload("res://src/gameplay/spells/projectile.gd")

var spell_id := "arc_bolt"
var targeting := "nearest"
var cooldown_seconds := 0.75
var cast_range := 9.0
var definition := {}
var enabled := true

var _caster: Node3D
var _projectile_parent: Node
var _cooldown := 0.0
var _random := RandomNumberGenerator.new()


func configure(spell_definition: Dictionary, caster: Node3D, projectile_parent: Node, seed_value: int) -> void:
    definition = spell_definition
    spell_id = str(spell_definition.get("id", spell_id))
    targeting = str(spell_definition.get("targeting", targeting))
    cooldown_seconds = maxf(float(spell_definition.get("cooldown_seconds", cooldown_seconds)), 0.05)
    cast_range = float(spell_definition.get("range", cast_range))
    _caster = caster
    _projectile_parent = projectile_parent
    _random.seed = seed_value
    # Stagger the first cast so several spells do not all fire on frame one.
    _cooldown = _random.randf_range(0.0, cooldown_seconds)


func _process(delta: float) -> void:
    if not enabled or not is_instance_valid(_caster):
        return
    if _caster.has_method("is_alive") and not _caster.is_alive():
        return

    _cooldown -= delta
    if _cooldown > 0.0:
        return

    var target := _pick_target()
    if target == null:
        # Retry next frame rather than burning the cooldown on an empty arena.
        _cooldown = 0.0
        return

    _cooldown = cooldown_seconds
    _cast_at(target)


func _cast_at(target: Node3D) -> void:
    var origin := _caster.global_position
    var aim := target.global_position - origin
    aim.y = 0.0

    var projectile := Projectile.new()
    projectile.configure(definition, origin, aim)
    _projectile_parent.add_child(projectile)


func _pick_target() -> Node3D:
    var candidates := get_tree().get_nodes_in_group("enemies")
    if candidates.is_empty():
        return null

    var origin := _caster.global_position
    var range_squared := cast_range * cast_range

    match targeting:
        "random":
            var in_range: Array[Node3D] = []
            for candidate in candidates:
                var enemy := candidate as Node3D
                if enemy != null and _flat_distance_squared(origin, enemy.global_position) <= range_squared:
                    in_range.append(enemy)
            if in_range.is_empty():
                return null
            return in_range[_random.randi_range(0, in_range.size() - 1)]
        _:
            var best: Node3D = null
            var best_distance := range_squared
            for candidate in candidates:
                var enemy := candidate as Node3D
                if enemy == null:
                    continue
                var distance := _flat_distance_squared(origin, enemy.global_position)
                if distance <= best_distance:
                    best_distance = distance
                    best = enemy
            return best


func _flat_distance_squared(a: Vector3, b: Vector3) -> float:
    var delta := b - a
    delta.y = 0.0
    return delta.length_squared()
