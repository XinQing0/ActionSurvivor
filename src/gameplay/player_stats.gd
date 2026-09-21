extends RefCounted

## Global run modifiers owned by the run, read by spells and the player pawn.
##
## Spells never store their own final numbers. They ask for a base value and
## multiply it through here, so a stat upgrade taken at minute two changes every
## spell the player already owns without any of them knowing the upgrade exists.

var damage_multiplier := 1.0
var cooldown_multiplier := 1.0
var area_multiplier := 1.0
var projectile_speed_multiplier := 1.0
var projectile_count_bonus := 0
var move_speed_multiplier := 1.0
var max_health_bonus := 0.0
var health_regen_per_second := 0.0
var pickup_radius_bonus := 0.0
var xp_multiplier := 1.0

const FIELDS := [
    "damage_multiplier",
    "cooldown_multiplier",
    "area_multiplier",
    "projectile_speed_multiplier",
    "projectile_count_bonus",
    "move_speed_multiplier",
    "max_health_bonus",
    "health_regen_per_second",
    "pickup_radius_bonus",
    "xp_multiplier",
]

## Multipliers must never reach zero. A zero cooldown multiplier would make a
## spell cast every frame, and a zero area multiplier would silently disable it.
const MINIMUM_MULTIPLIER := 0.1


func apply_modifier(field: String, amount: float) -> bool:
    if not FIELDS.has(field):
        push_error("Unknown player stat: %s" % field)
        return false
    if field == "projectile_count_bonus":
        projectile_count_bonus += int(round(amount))
        return true
    var current: float = float(get(field))
    var updated := current + amount
    if field.ends_with("_multiplier"):
        updated = maxf(updated, MINIMUM_MULTIPLIER)
    set(field, updated)
    return true


func describe() -> Dictionary:
    var snapshot := {}
    for field in FIELDS:
        snapshot[field] = get(field)
    return snapshot
