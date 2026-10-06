extends Node

## Base class for every spell.
##
## A spell owns a cooldown and a targeting rule and never reads the input layer,
## so automatic spells keep working unchanged when manually triggered abilities
## are added later.
##
## Subclasses override `_cast()` and, if the spell should hold fire when there is
## nothing to hit, `_has_valid_target()`. Everything else - levelling, stat
## multipliers, cooldown, target selection - lives here so a new spell is a
## config entry plus a short script.

const Projectile := preload("res://src/gameplay/spells/projectile.gd")

var spell_id := "unnamed"
var display_name := "Unnamed"
var description := ""
var element := ""
var level := 1
var max_level := 5
var enabled := true

var caster: Node3D
var projectile_parent: Node
var stats: RefCounted

var _base := {}
var _per_level := {}
var _status := {}
var _cooldown := 0.0
var _random := RandomNumberGenerator.new()


func configure(definition: Dictionary, new_caster: Node3D, new_projectile_parent: Node, new_stats: RefCounted, seed_value: int) -> void:
    spell_id = str(definition.get("id", spell_id))
    display_name = str(definition.get("name", spell_id))
    description = str(definition.get("description", ""))
    element = str(definition.get("element", ""))
    _status = definition.get("status", {})
    max_level = int(definition.get("max_level", max_level))
    _base = definition.get("base", {})
    _per_level = definition.get("per_level", {})
    caster = new_caster
    projectile_parent = new_projectile_parent
    stats = new_stats
    _random.seed = seed_value
    # Stagger the first cast so a fresh loadout does not fire everything on the
    # same frame.
    _cooldown = _random.randf_range(0.0, get_cooldown())
    _on_configured()


func can_level_up() -> bool:
    return level < max_level


func level_up() -> void:
    if can_level_up():
        level += 1
        _on_level_changed()


## Base value plus the per-level growth for the current level. Level 1 is the
## level at which a spell is acquired, so it gets no growth.
func base_stat(key: String, fallback: float) -> float:
    var value := float(_base.get(key, fallback))
    if _per_level.has(key):
        value += float(_per_level[key]) * float(level - 1)
    return value


func get_damage() -> float:
    return base_stat("damage", 6.0) * _multiplier("damage_multiplier")


func get_cooldown() -> float:
    return maxf(base_stat("cooldown_seconds", 1.0) * _multiplier("cooldown_multiplier"), 0.05)


func get_range() -> float:
    return maxf(base_stat("range", 9.0) * _multiplier("area_multiplier"), 0.5)


func get_area() -> float:
    return maxf(base_stat("area", 3.0) * _multiplier("area_multiplier"), 0.2)


func get_projectile_speed() -> float:
    return maxf(base_stat("projectile_speed", 18.0) * _multiplier("projectile_speed_multiplier"), 0.5)


## Extra projectiles from stat upgrades apply once per spell, not once per
## projectile, so a spell that already fires a fan does not explode in count.
func get_projectile_count() -> int:
    var count := int(floor(base_stat("projectile_count", 1.0)))
    if stats != null:
        count += int(stats.projectile_count_bonus)
    return maxi(count, 1)


func get_cooldown_progress() -> float:
    var cooldown := get_cooldown()
    if cooldown <= 0.0:
        return 1.0
    return clampf(1.0 - _cooldown / cooldown, 0.0, 1.0)


func _process(delta: float) -> void:
    if not enabled or not is_instance_valid(caster):
        return
    if caster.has_method("is_alive") and not caster.is_alive():
        return

    _cooldown -= delta
    if _cooldown > 0.0:
        return
    if not _has_valid_target():
        # Hold at zero rather than burning the cooldown on an empty arena.
        _cooldown = 0.0
        return

    _cooldown = get_cooldown()
    _cast()


# --- Subclass hooks -------------------------------------------------------

func _on_configured() -> void:
    pass


func _on_level_changed() -> void:
    pass


func _has_valid_target() -> bool:
    return true


func _cast() -> void:
    pass


# --- Shared helpers -------------------------------------------------------

## Every hit a spell lands goes through here, so the status that makes spells
## react with each other is applied in one place. A spell that damaged enemies
## directly would silently opt out of reactions.
func deal_hit(enemy: Node, damage: float) -> void:
    if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
        return
    enemy.take_damage(damage)
    # A lethal hit frees the enemy, and a dead enemy has nothing to apply to.
    if _status.is_empty() or not enemy.has_method("apply_status") or float(enemy.get("health")) <= 0.0:
        return
    var potency := float(_status.get("potency", 1.0))
    if bool(_status.get("scales_with_damage", false)):
        potency *= _multiplier("damage_multiplier")
    enemy.apply_status(str(_status.get("id", "")), float(_status.get("duration", 2.0)), potency)


func has_augment(augment_id: String) -> bool:
    return stats != null and stats.has_augment(augment_id)


func augment_param(augment_id: String, key: String, fallback: float) -> float:
    if stats == null:
        return fallback
    return stats.augment_param(augment_id, key, fallback)


func spawn_projectile(origin: Vector3, direction: Vector3, overrides: Dictionary = {}) -> void:
    var projectile := Projectile.new()
    var settings := {
        "damage": get_damage(),
        "projectile_speed": get_projectile_speed(),
        "projectile_radius": base_stat("projectile_radius", 0.18),
        "lifetime_seconds": base_stat("lifetime_seconds", 1.5),
        "pierce": int(base_stat("pierce", 0.0)),
        "color": str(_base.get("color", "8fd6ff")),
    }
    settings.merge(overrides, true)
    projectile.configure(settings, origin, direction)
    projectile.source_spell = self
    projectile_parent.add_child(projectile)


func nearest_enemy(within: float) -> Node3D:
    var origin := caster.global_position
    var best: Node3D = null
    var best_distance := within * within
    for candidate in get_tree().get_nodes_in_group("enemies"):
        var enemy := candidate as Node3D
        if enemy == null:
            continue
        var distance := flat_distance_squared(origin, enemy.global_position)
        if distance <= best_distance:
            best_distance = distance
            best = enemy
    return best


func enemies_within(radius: float) -> Array[Node3D]:
    var origin := caster.global_position
    var radius_squared := radius * radius
    var found: Array[Node3D] = []
    for candidate in get_tree().get_nodes_in_group("enemies"):
        var enemy := candidate as Node3D
        if enemy != null and flat_distance_squared(origin, enemy.global_position) <= radius_squared:
            found.append(enemy)
    return found


func flat_distance_squared(a: Vector3, b: Vector3) -> float:
    var delta := b - a
    delta.y = 0.0
    return delta.length_squared()


func _multiplier(field: String) -> float:
    if stats == null:
        return 1.0
    return float(stats.get(field))
