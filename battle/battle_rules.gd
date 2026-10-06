class_name BattleRules
extends RefCounted
## All combat formulas live here and nowhere else.

const CLASS_ADVANTAGE_MULTIPLIER: float = 1.5
const CLASS_DISADVANTAGE_MULTIPLIER: float = 0.75

const GUARD_MULTIPLIER: float = 0.50
const BOSS_XRAY_GUARD_MULTIPLIER: float = 0.45

const OFFENSE_BUFF_MULTIPLIER: float = 1.30
const OFFENSE_DEBUFF_MULTIPLIER: float = 0.70
const DEFENSE_BUFF_MULTIPLIER: float = 0.70
const DEFENSE_DEBUFF_MULTIPLIER: float = 1.30


## Ambiguity isolated here: how 50% of current HP is rounded.
## floor => 41 -> 20,
## and the user can never kill itself with XXXRay.
static func self_damage_amount(
	current_hp: int,
	fraction: float
) -> int:
	return int(
		floor(
			float(current_hp) * fraction
		)
	)


## THE ONLY DAMAGE MATCHUP:
## visible > high energy > low energy > visible
##
## This is a closed cycle.
static func class_multiplier(
	attacker_class: BattleCombatant.CombatClass,
	target_class: BattleCombatant.CombatClass
) -> float:
	var C: Variant = BattleCombatant.CombatClass

	# Advantage:
	# VISIBLE > HIGH_ENERGY
	# HIGH_ENERGY > LOW_ENERGY
	# LOW_ENERGY > VISIBLE

	if (
		attacker_class == C.VISIBLE
		and
		target_class == C.HIGH_ENERGY
	):
		return CLASS_ADVANTAGE_MULTIPLIER

	if (
		attacker_class == C.HIGH_ENERGY
		and
		target_class == C.LOW_ENERGY
	):
		return CLASS_ADVANTAGE_MULTIPLIER

	if (
		attacker_class == C.LOW_ENERGY
		and
		target_class == C.VISIBLE
	):
		return CLASS_ADVANTAGE_MULTIPLIER

	# Disadvantage:
	# VISIBLE < LOW_ENERGY
	# HIGH_ENERGY < VISIBLE
	# LOW_ENERGY < HIGH_ENERGY

	if (
		attacker_class == C.VISIBLE
		and
		target_class == C.LOW_ENERGY
	):
		return CLASS_DISADVANTAGE_MULTIPLIER

	if (
		attacker_class == C.HIGH_ENERGY
		and
		target_class == C.VISIBLE
	):
		return CLASS_DISADVANTAGE_MULTIPLIER

	if (
		attacker_class == C.LOW_ENERGY
		and
		target_class == C.HIGH_ENERGY
	):
		return CLASS_DISADVANTAGE_MULTIPLIER

	return 1.0


## Damage skills carry their own spectrum.
## Neutral skills fall back to the attacker's class so legacy/test skills
## still have predictable behavior.
static func skill_combat_class(
	attacker: BattleCombatant,
	skill: BattleSkill
) -> BattleCombatant.CombatClass:
	var C: Variant = BattleCombatant.CombatClass
	var S: Variant = BattleSkill.SkillType

	if skill != null:
		match skill.skill_type:
			S.VISIBLE:
				return C.VISIBLE

			S.HIGH_ENERGY:
				return C.HIGH_ENERGY

			S.LOW_ENERGY:
				return C.LOW_ENERGY

	if attacker == null:
		return C.VISIBLE

	return attacker.combat_class


static func skill_class_multiplier(
	attacker: BattleCombatant,
	target: BattleCombatant,
	skill: BattleSkill
) -> float:
	if attacker == null or target == null:
		return 1.0

	return class_multiplier(
		skill_combat_class(attacker, skill),
		target.combat_class
	)


## One damaging hit.
##
## final = base x offense x defense x class x guard x resistance
##
## resistance:
## 1.0 = normal
## 0.5 = resisted
## 0.0 = repelled / rejected
static func calculate_hit(
	attacker: BattleCombatant,
	target: BattleCombatant,
	skill: BattleSkill,
	resistance: float = 1.0
) -> Dictionary:
	var class_mult: float = 1.0

	if skill != null and skill.effect_type == BattleSkill.EffectType.DAMAGE:
		class_mult = skill_class_multiplier(
			attacker,
			target,
			skill
		)
	elif skill.uses_class_multiplier:
		class_mult = skill_class_multiplier(
			attacker,
			target,
			skill
		)

	var guard_mult: float = 1.0

	if target.is_guarding:
		guard_mult = GUARD_MULTIPLIER

		# twIST's X-Ray is deliberately stronger even through Guard.
		if (
			skill != null
			and
			skill.skill_id == BattleSkills.BOSS_XRAY
		):
			guard_mult = BOSS_XRAY_GUARD_MULTIPLIER

	var repelled: bool = resistance <= 0.0
	var amount: int = 0

	if not repelled:
		var raw: float = (
			skill.base_damage
			* attacker.offense_multiplier
			* target.defense_multiplier
			* class_mult
			* guard_mult
			* resistance
		)

		amount = maxi(
			1,
			roundi(raw)
		)

	return {
		"amount": amount,
		"class_mult": class_mult,
		"weak": class_mult > 1.0,
		"guarded": target.is_guarding,
		"repelled": repelled,
		"resisted": (
			resistance > 0.0
			and
			resistance < 1.0
		)
	}


## Weighted hit count for multi-hit skills.
## Weights are per hit count.
static func roll_hit_count(
	skill: BattleSkill,
	rng: RandomNumberGenerator
) -> int:
	if skill.max_hits <= skill.min_hits:
		return skill.min_hits

	var count: int = (
		skill.max_hits
		-
		skill.min_hits
		+
		1
	)

	if skill.hit_weights.size() != count:
		return rng.randi_range(
			skill.min_hits,
			skill.max_hits
		)

	var total: float = 0.0

	for w in skill.hit_weights:
		total += w

	var roll: float = (
		rng.randf()
		*
		total
	)

	for i in count:
		roll -= skill.hit_weights[i]

		if roll <= 0.0:
			return skill.min_hits + i

	return skill.max_hits
