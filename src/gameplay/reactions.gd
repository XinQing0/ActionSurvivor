extends Node

## Resolves what happens when two statuses meet on one enemy.
##
## Every spell applies a status (burn, shock or chill). A reaction fires when an
## enemy carries a complete set of statuses from one definition in
## `config/reactions.json`, which makes the pairing of two spells a build
## decision rather than an additive one. Both statuses are consumed, and the
## enemy cannot react again for a short lockout, so one unlucky target cannot be
## detonated every frame.
##
## Reactions can set up further reactions (steam chills neighbours that are
## already burning), so resolution is depth-limited rather than recursive
## without bound.

const RingEffect := preload("res://src/gameplay/spells/ring_effect.gd")
const ReactionPopup := preload("res://src/gameplay/reaction_popup.gd")

signal reaction_triggered(reaction_id: String, position: Vector3)

var stats: RefCounted
var effect_parent: Node

## How many times each reaction has fired this run. Read by tests and the end
## screen; nothing in the simulation depends on it.
var counts := {}

var _reactions: Array = []
var _lockout_seconds := 1.2
var _max_depth := 2
var _depth := 0


func configure(config: Dictionary, new_stats: RefCounted, new_effect_parent: Node) -> void:
    stats = new_stats
    effect_parent = new_effect_parent
    _lockout_seconds = float(config.get("lockout_seconds", _lockout_seconds))
    _max_depth = int(config.get("max_chain_depth", _max_depth))
    _reactions = config.get("reactions", [])


## Chilled enemies take extra damage once Brittle Cold is owned.
func damage_taken_multiplier(enemy: Node) -> float:
    if stats == null or not stats.has_augment("brittle_cold"):
        return 1.0
    if not enemy.has_status("chill"):
        return 1.0
    return 1.0 + stats.augment_param("brittle_cold", "bonus", 0.0)


## Called by an enemy right after a status lands on it.
func evaluate(enemy: Node3D, applied_status: String) -> void:
    if enemy.is_reaction_locked() or _depth >= _max_depth:
        return
    for reaction in _reactions:
        var requires: Array = reaction.get("requires", [])
        if not requires.has(applied_status):
            continue
        if _has_all(enemy, requires):
            _fire(enemy, reaction)
            return


## An enemy that dies while burning can carry the fire to its neighbours.
func on_enemy_killed(enemy: Node3D) -> void:
    if stats == null or not stats.has_augment("wildfire") or not enemy.has_status("burn"):
        return
    if _depth >= _max_depth:
        return
    var radius: float = stats.augment_param("wildfire", "radius", 3.0)
    var duration: float = stats.augment_param("wildfire", "duration", 3.0)
    var potency: float = enemy.get_status_potency("burn")
    _depth += 1
    for neighbour in _enemies_near(enemy.global_position, radius):
        if neighbour != enemy:
            neighbour.apply_status("burn", duration, potency)
    _depth -= 1
    _spawn_ring(enemy.global_position, radius, Color(1.0, 0.45, 0.12))


func _fire(enemy: Node3D, reaction: Dictionary) -> void:
    var reaction_id := str(reaction.get("id", ""))
    for status_id in reaction.get("requires", []):
        enemy.clear_status(str(status_id))
    enemy.lock_reactions(_lockout_seconds)

    var damage := float(reaction.get("damage", 0.0))
    var radius := float(reaction.get("radius", 0.0))
    if stats != null:
        damage *= stats.damage_multiplier
        if stats.has_augment("catalyst"):
            damage *= 1.0 + stats.augment_param("catalyst", "damage", 0.0)
            radius *= 1.0 + stats.augment_param("catalyst", "radius", 0.0)

    var origin := enemy.global_position
    var color := Color.from_string(str(reaction.get("color", "ffffff")), Color.WHITE)
    var follow_up: Dictionary = reaction.get("apply", {})

    counts[reaction_id] = int(counts.get(reaction_id, 0)) + 1
    reaction_triggered.emit(reaction_id, origin)
    _spawn_ring(origin, maxf(radius, 0.9), color)
    _spawn_popup(origin, str(reaction.get("name", reaction_id)), color)

    # Targets are gathered before any damage lands: a lethal hit frees nodes
    # and the list must not change underneath the loop.
    var targets: Array[Node3D] = [enemy]
    if radius > 0.0:
        for neighbour in _enemies_near(origin, radius):
            if neighbour != enemy:
                targets.append(neighbour)

    _depth += 1
    for target in targets:
        if not is_instance_valid(target):
            continue
        target.take_damage(damage)
        if not follow_up.is_empty() and target != enemy:
            target.apply_status(
                str(follow_up.get("id", "")),
                float(follow_up.get("duration", 2.0)),
                float(follow_up.get("potency", 0.0))
            )
    _depth -= 1


func _has_all(enemy: Node, requires: Array) -> bool:
    for status_id in requires:
        if not enemy.has_status(str(status_id)):
            return false
    return true


func _enemies_near(origin: Vector3, radius: float) -> Array[Node3D]:
    var found: Array[Node3D] = []
    var radius_squared := radius * radius
    for candidate in get_tree().get_nodes_in_group("enemies"):
        var other := candidate as Node3D
        if other == null or other.health <= 0.0:
            continue
        var offset := other.global_position - origin
        offset.y = 0.0
        if offset.length_squared() <= radius_squared:
            found.append(other)
    return found


func _spawn_ring(origin: Vector3, radius: float, color: Color) -> void:
    if effect_parent == null:
        return
    var ring := RingEffect.new()
    ring.configure(radius, color)
    ring.position = Vector3(origin.x, 0.1, origin.z)
    effect_parent.add_child(ring)


func _spawn_popup(origin: Vector3, text: String, color: Color) -> void:
    if effect_parent == null:
        return
    var popup := ReactionPopup.new()
    popup.configure(text, color)
    popup.position = origin + Vector3(0.0, 1.6, 0.0)
    effect_parent.add_child(popup)
