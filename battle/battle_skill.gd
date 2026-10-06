class_name BattleSkill
extends RefCounted
## Pure data definition of a skill.
## No visuals, no rules.


enum EffectType {
	DAMAGE,
	HEAL,
	REVIVE,
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


enum SkillType {
	NEUTRAL,
	VISIBLE,
	HIGH_ENERGY,
	LOW_ENERGY,
	SUPPORT
}


var skill_id: String = ""
var display_name: String = ""

var lp_cost: int = 0

var effect_type: EffectType = (
	EffectType.DAMAGE
)

var target_mode: TargetMode = (
	TargetMode.ONE_ENEMY
)

var skill_type: SkillType = (
	SkillType.NEUTRAL
)


var base_damage: float = 0.0
var heal_amount: int = 0

var min_hits: int = 1
var max_hits: int = 1
var hit_weights: Array[float] = []

var self_hp_fraction: float = 0.0

var duration_turns: int = 0

var counts_for_tracker: bool = true
var uses_class_multiplier: bool = true

var is_physical: bool = false


static func create(
	p_id: String,
	p_name: String,
	p_cost: int,
	p_effect: EffectType,
	p_target: TargetMode
) -> BattleSkill:
	var skill: BattleSkill = BattleSkill.new()

	skill.skill_id = p_id
	skill.display_name = p_name
	skill.lp_cost = p_cost
	skill.effect_type = p_effect
	skill.target_mode = p_target

	return skill


func with_damage(
	value: float
) -> BattleSkill:
	base_damage = value
	return self


func with_heal(
	value: int
) -> BattleSkill:
	heal_amount = value
	return self


func with_hits(
	p_min: int,
	p_max: int,
	weights: Array[float]
) -> BattleSkill:
	min_hits = p_min
	max_hits = p_max
	hit_weights = weights
	return self


func with_self_hp_fraction(
	value: float
) -> BattleSkill:
	self_hp_fraction = value
	return self


func with_duration(
	turns: int
) -> BattleSkill:
	duration_turns = turns
	return self


func with_type(
	value: SkillType
) -> BattleSkill:
	skill_type = value
	return self


func untracked() -> BattleSkill:
	counts_for_tracker = false
	return self


func no_class() -> BattleSkill:
	uses_class_multiplier = false
	return self


func physical() -> BattleSkill:
	# "Physical" only means it is not part of adaptation tracking.
	# It MUST still use the spectrum matchup when it deals damage.
	is_physical = true
	counts_for_tracker = false
	uses_class_multiplier = true
	skill_type = SkillType.NEUTRAL
	return self


func needs_target_choice() -> bool:
	return (
		target_mode ==
		TargetMode.ONE_ENEMY
		or
		target_mode ==
		TargetMode.ONE_ALLY
	)


func targets_opposite_side() -> bool:
	return (
		target_mode ==
		TargetMode.ONE_ENEMY
		or
		target_mode ==
		TargetMode.ALL_ENEMIES
	)


func target_label() -> String:
	match target_mode:
		TargetMode.ONE_ENEMY:
			return "one enemy"

		TargetMode.ALL_ENEMIES:
			return "all enemies"

		TargetMode.ONE_ALLY:
			return "one ally"

		TargetMode.SELF:
			return "self"

		_:
			return "unknown"


func type_label() -> String:
	match skill_type:
		SkillType.VISIBLE:
			return "visible"

		SkillType.HIGH_ENERGY:
			return "high energy"

		SkillType.LOW_ENERGY:
			return "low energy"

		SkillType.SUPPORT:
			return "support"

		SkillType.NEUTRAL:
			return "neutral"

		_:
			return "neutral"


func describe() -> String:
	var description: String = ""

	match effect_type:
		EffectType.DAMAGE:
			if max_hits > 1:
				description = (
					"%d-%d hits x%d  /  %s"
					% [
						min_hits,
						max_hits,
						int(base_damage),
						target_label()
					]
				)
			else:
				description = (
					"damage %d  /  %s"
					% [
						int(base_damage),
						target_label()
					]
				)

			if self_hp_fraction >= 0.5:
				description += "  /  halves user's current HP"

		EffectType.HEAL:
			description = (
				"heal %d  /  %s"
				% [
					heal_amount,
					target_label()
				]
			)

		EffectType.REVIVE:
			description = (
				"revive  /  %s"
				% target_label()
			)

		EffectType.BUFF_DEFENSE:
			description = (
				"defense up  /  %s"
				% target_label()
			)

		EffectType.BUFF_OFFENSE:
			description = (
				"offense up  /  %s"
				% target_label()
			)

		EffectType.DEBUFF_DEFENSE:
			description = (
				"defense down  /  %s"
				% target_label()
			)

		EffectType.DEBUFF_OFFENSE:
			description = (
				"offense down  /  %s"
				% target_label()
			)

		EffectType.GUARD:
			description = "brace for impact"

		_:
			description = "unknown"

	# Every skill exposes its type.
	return (
		"type: "
		+
		type_label()
		+
		"  /  "
		+
		description
	)
