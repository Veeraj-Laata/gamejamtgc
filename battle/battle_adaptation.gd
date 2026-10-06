class_name BattleAdaptation
extends RefCounted
## Enemy adaptation:
## - global skill_id -> effectiveness multiplier
## - enemy_name -> skill_id -> effectiveness multiplier
##
## 1.0 = normal
## 0.5 = resisted
## 0.0 = repelled
##
## Nothing here knows about any specific skill.


var resistances: Dictionary = {}
var enemy_resistances: Dictionary = {}


func get_multiplier(
	skill_id: String
) -> float:
	return float(
		resistances.get(
			skill_id,
			1.0
		)
	)


func get_enemy_multiplier(
	enemy_name: String,
	skill_id: String
) -> float:
	if enemy_name.is_empty():
		return get_multiplier(
			skill_id
		)

	if not enemy_resistances.has(
		enemy_name
	):
		return get_multiplier(
			skill_id
		)

	var stored: Variant = (
		enemy_resistances.get(
			enemy_name
		)
	)

	if not stored is Dictionary:
		return get_multiplier(
			skill_id
		)

	var enemy_table: Dictionary = (
		stored as Dictionary
	)

	if not enemy_table.has(
		skill_id
	):
		return get_multiplier(
			skill_id
		)

	return float(
		enemy_table.get(
			skill_id,
			1.0
		)
	)


func set_resistance(
	skill_id: String,
	multiplier: float
) -> void:
	if skill_id.is_empty():
		return

	resistances[skill_id] = multiplier


func set_enemy_resistance(
	enemy_name: String,
	skill_id: String,
	multiplier: float
) -> void:
	if enemy_name.is_empty():
		return

	if skill_id.is_empty():
		return

	if not enemy_resistances.has(
		enemy_name
	):
		enemy_resistances[enemy_name] = {}

	var stored: Variant = (
		enemy_resistances.get(
			enemy_name
		)
	)

	if not stored is Dictionary:
		enemy_resistances[enemy_name] = {}

	var enemy_table: Dictionary = (
		enemy_resistances[
			enemy_name
		]
		as Dictionary
	)

	enemy_table[skill_id] = multiplier

	enemy_resistances[
		enemy_name
	] = enemy_table


## Adapt to the most used tracked skill from a previous room.
static func from_tracker(
	tracker: BattleTracker,
	multiplier: float = 0.5
) -> BattleAdaptation:
	var a: BattleAdaptation = (
		BattleAdaptation.new()
	)

	var top: String = (
		tracker.most_used()
	)

	if not top.is_empty():
		a.set_resistance(
			top,
			multiplier
		)

	return a
