class_name BattleRules
extends RefCounted


const LIGHT_DAMAGE: int = 6
const MEDIUM_DAMAGE: int = 12
const HEAVY_DAMAGE: int = 20

const CLASS_ADVANTAGE_MULTIPLIER: float = 2.0
const NORMAL_CLASS_MULTIPLIER: float = 1.0

const OFFENSE_BUFF_MULTIPLIER: float = 1.25
const OFFENSE_DEBUFF_MULTIPLIER: float = 0.75

const DEFENSE_BUFF_MULTIPLIER: float = 0.75
const DEFENSE_DEBUFF_MULTIPLIER: float = 1.25

const GUARD_MULTIPLIER: float = 0.45


static func get_class_multiplier(
	attacker_class: String,
	target_class: String
) -> float:

	if (
		attacker_class == "Visible"
		and target_class == "HighEnergy"
	):
		return CLASS_ADVANTAGE_MULTIPLIER

	if (
		attacker_class == "HighEnergy"
		and target_class == "LowEnergy"
	):
		return CLASS_ADVANTAGE_MULTIPLIER

	if (
		attacker_class == "LowEnergy"
		and target_class == "Visible"
	):
		return CLASS_ADVANTAGE_MULTIPLIER

	return NORMAL_CLASS_MULTIPLIER


static func calculate_damage(
	base_damage: int,
	attacker: BattleCombatant,
	target: BattleCombatant
) -> int:

	var damage: float = float(base_damage)

	damage *= attacker.offense_multiplier
	damage *= target.defense_multiplier

	damage *= get_class_multiplier(
		attacker.combat_class,
		target.combat_class
	)

	if target.is_guarding:
		damage *= GUARD_MULTIPLIER

	return max(
		1,
		int(round(damage))
	)
