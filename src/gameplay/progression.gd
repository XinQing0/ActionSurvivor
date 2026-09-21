extends RefCounted

## Experience and levelling for a single run.
##
## It holds no nodes and emits nothing; the run asks it whether a level is
## pending. Keeping it a plain object makes the level curve trivial to unit
## test and keeps run state in data rather than in the scene tree.

var level := 1
var experience := 0
var pending_levels := 0

var _base := 5
var _growth := 4.0
var _exponent := 1.35


func configure(curve: Dictionary) -> void:
    _base = int(curve.get("base", _base))
    _growth = float(curve.get("growth", _growth))
    _exponent = float(curve.get("exponent", _exponent))


func experience_for_next_level() -> int:
    return maxi(_base + int(round(_growth * pow(float(level), _exponent))), 1)


func add_experience(amount: int) -> void:
    experience += amount
    while experience >= experience_for_next_level():
        experience -= experience_for_next_level()
        level += 1
        pending_levels += 1


func consume_pending_level() -> bool:
    if pending_levels <= 0:
        return false
    pending_levels -= 1
    return true


func progress_to_next_level() -> float:
    var needed := experience_for_next_level()
    if needed <= 0:
        return 0.0
    return clampf(float(experience) / float(needed), 0.0, 1.0)
