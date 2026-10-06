class_name BattleTracker
extends RefCounted
## skill_id -> usage_count. Only named, tracked skills are counted.

var usage: Dictionary = {}


func record(skill: BattleSkill) -> void:
	if skill == null:
		return
	if skill.is_physical or not skill.counts_for_tracker:
		return
	if skill.effect_type == BattleSkill.EffectType.GUARD:
		return
	usage[skill.skill_id] = int(usage.get(skill.skill_id, 0)) + 1


func most_used() -> String:
	var best_id: String = ""
	var best_count: int = 0
	for id in usage.keys():
		var count: int = int(usage[id])
		if count > best_count:
			best_count = count
			best_id = str(id)
	return best_id
