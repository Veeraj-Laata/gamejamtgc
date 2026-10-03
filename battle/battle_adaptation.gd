class_name BattleAdaptation
extends RefCounted
## Enemy adaptation: skill_id -> effectiveness multiplier.
## 1.0 normal, 0.5 resisted (room 2), 0.0 repelled (boss / later).
## Nothing here knows about any specific skill.

var resistances: Dictionary = {}


func get_multiplier(skill_id: String) -> float:
	return float(resistances.get(skill_id, 1.0))


func set_resistance(skill_id: String, multiplier: float) -> void:
	if skill_id.is_empty():
		return
	resistances[skill_id] = multiplier


## Adapt to the most used tracked skill from a previous room.
static func from_tracker(tracker: BattleTracker, multiplier: float = 0.5) -> BattleAdaptation:
	var a: BattleAdaptation = BattleAdaptation.new()
	var top: String = tracker.most_used()
	if not top.is_empty():
		a.set_resistance(top, multiplier)
	return a
