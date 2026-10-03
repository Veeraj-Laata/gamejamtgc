class_name BattleSkill
extends RefCounted


enum EffectType {
	DAMAGE,
	HEAL,
	BUFF_DEFENSE,
	BUFF_OFFENSE,
	DEBUFF_DEFENSE,
	DEBUFF_OFFENSE,
	GUARD
}


enum TargetMode {
	ONE_ENEMY,
	ALL_ENEMIES,
	ONE_ALLY,
	SELF
}


var skill_id: String = ""
var display_name: String = ""

var lp_cost: int = 0

var effect_type: EffectType = EffectType.DAMAGE
var target_mode: TargetMode = TargetMode.ONE_ENEMY

var base_damage: int = 0
var heal_amount: int = 0

var min_hits: int = 1
var max_hits: int = 1

var self_hp_fraction: float = 0.0

var duration_turns: int = 0

var counts_for_tracker: bool = true


func _init(
	p_id: String,
	p_name: String,
	p_lp_cost: int,
	p_effect_type: EffectType,
	p_target_mode: TargetMode
) -> void:
	skill_id = p_id
	display_name = p_name
	lp_cost = p_lp_cost
	effect_type = p_effect_type
	target_mode = p_target_mode
