extends RefCounted

## Builds the level-up choices.
##
## It is deliberately a pure generator: given what the player owns it returns
## option descriptions, and the run decides what to do with the one that gets
## picked. That keeps the offer rules testable without a scene.

const KIND_NEW_SPELL := "new_spell"
const KIND_SPELL_LEVEL := "spell_level"
const KIND_STAT := "stat"
const KIND_AUGMENT := "augment"

var options_per_draft := 3

var _catalog := {}
var _catalog_order: Array[String] = []
var _upgrades := {}
var _upgrade_order: Array[String] = []
var _augments := {}
var _augment_order: Array[String] = []
var _max_spells := 5
var _weights := {}
var _random := RandomNumberGenerator.new()


func configure(spell_config: Dictionary, progression_config: Dictionary, seed_value: int, augment_config: Dictionary = {}) -> void:
    _max_spells = int(spell_config.get("max_spells", _max_spells))
    for entry in spell_config.get("spells", []):
        var spell_id := str(entry.get("id", ""))
        if spell_id.is_empty():
            continue
        _catalog[spell_id] = entry
        _catalog_order.append(spell_id)

    var draft_config: Dictionary = progression_config.get("draft", {})
    options_per_draft = int(draft_config.get("options", options_per_draft))
    _weights = {
        KIND_NEW_SPELL: float(draft_config.get("new_spell_weight", 3.0)),
        KIND_SPELL_LEVEL: float(draft_config.get("spell_level_weight", 2.0)),
        KIND_STAT: float(draft_config.get("stat_upgrade_weight", 2.0)),
        KIND_AUGMENT: float(draft_config.get("augment_weight", 3.0)),
    }

    for entry in augment_config.get("augments", []):
        var augment_id := str(entry.get("id", ""))
        if augment_id.is_empty():
            continue
        _augments[augment_id] = entry
        _augment_order.append(augment_id)

    for entry in progression_config.get("upgrades", []):
        var upgrade_id := str(entry.get("id", ""))
        if upgrade_id.is_empty():
            continue
        _upgrades[upgrade_id] = entry
        _upgrade_order.append(upgrade_id)

    _random.seed = seed_value


func get_spell_definition(spell_id: String) -> Dictionary:
    return _catalog.get(spell_id, {})


func get_upgrade_definition(upgrade_id: String) -> Dictionary:
    return _upgrades.get(upgrade_id, {})


func get_augment_definition(augment_id: String) -> Dictionary:
    return _augments.get(augment_id, {})


## The elements the player's spells cover, as a set of element ids.
func owned_elements(owned_spells: Dictionary) -> Dictionary:
    var elements := {}
    for spell_id in owned_spells:
        var element := str(_catalog.get(spell_id, {}).get("element", ""))
        if not element.is_empty():
            elements[element] = true
    return elements


## `owned_spells` maps spell id to its current level. `taken_upgrades` maps
## upgrade id to how many times it has been chosen. `taken_augments` maps augment
## id to anything; only its keys matter.
func build_options(owned_spells: Dictionary, taken_upgrades: Dictionary, taken_augments: Dictionary = {}) -> Array[Dictionary]:
    var pool: Array[Dictionary] = []

    if owned_spells.size() < _max_spells:
        for spell_id in _catalog_order:
            if owned_spells.has(spell_id):
                continue
            var definition: Dictionary = _catalog[spell_id]
            pool.append({
                "kind": KIND_NEW_SPELL,
                "id": spell_id,
                "name": str(definition.get("name", spell_id)),
                "description": str(definition.get("description", "")),
                "detail": "New spell",
                "weight": _weights[KIND_NEW_SPELL],
            })

    for spell_id in _catalog_order:
        if not owned_spells.has(spell_id):
            continue
        var definition: Dictionary = _catalog[spell_id]
        var current_level := int(owned_spells[spell_id])
        var max_level := int(definition.get("max_level", 5))
        if current_level >= max_level:
            continue
        pool.append({
            "kind": KIND_SPELL_LEVEL,
            "id": spell_id,
            "name": str(definition.get("name", spell_id)),
            "description": str(definition.get("description", "")),
            "detail": "Level %d to %d" % [current_level, current_level + 1],
            "weight": _weights[KIND_SPELL_LEVEL],
        })

    for upgrade_id in _upgrade_order:
        var upgrade: Dictionary = _upgrades[upgrade_id]
        var stacks := int(taken_upgrades.get(upgrade_id, 0))
        var max_stacks := int(upgrade.get("max_stacks", 5))
        if stacks >= max_stacks:
            continue
        pool.append({
            "kind": KIND_STAT,
            "id": upgrade_id,
            "name": str(upgrade.get("name", upgrade_id)),
            "description": str(upgrade.get("description", "")),
            "detail": "Stack %d of %d" % [stacks + 1, max_stacks],
            "weight": _weights[KIND_STAT],
        })

    var elements := owned_elements(owned_spells)
    for augment_id in _augment_order:
        if taken_augments.has(augment_id):
            continue
        var augment: Dictionary = _augments[augment_id]
        var label := _requirement_label(augment.get("requires", {}), owned_spells, elements)
        if label.is_empty():
            continue
        pool.append({
            "kind": KIND_AUGMENT,
            "id": augment_id,
            "name": str(augment.get("name", augment_id)),
            "description": str(augment.get("description", "")),
            "detail": "Augment - %s" % label,
            "weight": _weights[KIND_AUGMENT],
        })

    return _draw_without_replacement(pool, options_per_draft)


## Returns a short label for what unlocked an augment, or an empty string when
## the player does not meet its requirement. Augments are only offered for what
## the player already has, so every card on screen is something they can use.
func _requirement_label(requires: Dictionary, owned_spells: Dictionary, elements: Dictionary) -> String:
    if requires.has("spell"):
        var spell_id := str(requires["spell"])
        if owned_spells.has(spell_id):
            return str(_catalog.get(spell_id, {}).get("name", spell_id))
        return ""
    if requires.has("element"):
        var element := str(requires["element"])
        return element.capitalize() if elements.has(element) else ""
    if requires.has("distinct_elements"):
        return "Reactions" if elements.size() >= int(requires["distinct_elements"]) else ""
    return ""


func _draw_without_replacement(pool: Array[Dictionary], count: int) -> Array[Dictionary]:
    var remaining := pool.duplicate()
    var drawn: Array[Dictionary] = []
    while drawn.size() < count and not remaining.is_empty():
        var total := 0.0
        for option in remaining:
            total += maxf(float(option.get("weight", 1.0)), 0.0)
        if total <= 0.0:
            break
        var roll := _random.randf_range(0.0, total)
        var picked := remaining.size() - 1
        for index in range(remaining.size()):
            roll -= maxf(float(remaining[index].get("weight", 1.0)), 0.0)
            if roll <= 0.0:
                picked = index
                break
        drawn.append(remaining[picked])
        remaining.remove_at(picked)
    return drawn
