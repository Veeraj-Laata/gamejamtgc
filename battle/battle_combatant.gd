class_name BattleCombatant
extends RefCounted
## Authoritative runtime state of one fighter. No visuals in here.


enum CombatClass {
	VISIBLE,
	HIGH_ENERGY,
	LOW_ENERGY
}


enum StatusKind {
	OFFENSE_BUFF,
	OFFENSE_DEBUFF,
	DEFENSE_BUFF,
	DEFENSE_DEBUFF
}


var character_name: String = ""
var combat_class: CombatClass = CombatClass.VISIBLE

var max_hp: int = 1
var hp: int = 1
var max_lp: int = 0
var lp: int = 0
var speed: int = 0   # kept for the future, turn order is side-based

var is_enemy: bool = false
var is_alive: bool = true
var is_guarding: bool = false

var offense_multiplier: float = 1.0
var defense_multiplier: float = 1.0

var defense_buff_turns: int = 0
var offense_buff_turns: int = 0
var defense_debuff_turns: int = 0
var offense_debuff_turns: int = 0

var skill_ids: Array[String] = []
var attack_skill_id: String = BattleSkills.ATTACK
var ai_guard_chance: float = 0.0   # enemies only
var visual_scale: float = 1.0      # hint for the actor, not used by rules
var visual_model_file: String = ""

static func create(
	p_name: String,
	p_class: CombatClass,
	p_hp: int,
	p_lp: int,
	p_speed: int,
	p_is_enemy: bool
) -> BattleCombatant:
	var c: BattleCombatant = BattleCombatant.new()

	c.character_name = p_name
	c.combat_class = p_class
	c.max_hp = maxi(
		p_hp,
		1
	)
	c.hp = c.max_hp

	c.max_lp = maxi(
		p_lp,
		0
	)
	c.lp = c.max_lp

	c.speed = p_speed
	c.is_enemy = p_is_enemy

	return c


# ---------------------------------------------------------
# HP / LP
# ---------------------------------------------------------

func take_damage(
	amount: int
) -> int:
	if not is_alive:
		return 0

	var applied: int = mini(
		maxi(
			amount,
			0
		),
		hp
	)

	hp -= applied

	if hp <= 0:
		hp = 0
		is_alive = false
		is_guarding = false

	return applied


func heal(
	amount: int
) -> int:
	if not is_alive:
		return 0

	var before: int = hp

	hp = mini(
		hp + maxi(
			amount,
			0
		),
		max_hp
	)

	return hp - before


func revive(
	amount: int
) -> int:
	if is_alive:
		return 0

	var restored_hp: int = clampi(
		amount,
		1,
		max_hp
	)

	hp = restored_hp
	is_alive = true
	is_guarding = false

	# A revived combatant returns without any guard state.
	return restored_hp


func can_afford(
	skill: BattleSkill
) -> bool:
	if skill == null:
		return false

	return lp >= skill.lp_cost


func spend_lp(
	amount: int
) -> bool:
	var cost: int = maxi(
		amount,
		0
	)

	if lp < cost:
		return false

	lp -= cost
	return true


# ---------------------------------------------------------
# GUARD
# ---------------------------------------------------------

func clear_guard() -> void:
	is_guarding = false


# ---------------------------------------------------------
# STATUSES
# Rule: each of the four statuses has its own timer. Reapplying the same one
# refreshes it. A buff and a debuff on the same stat can be active together;
# their multipliers multiply (1.25 x 0.75 = 0.9375). All of it is recomputed in
# _recalculate_multipliers() so there is exactly one place to change.
# ---------------------------------------------------------

func apply_status(
	kind: StatusKind,
	turns: int
) -> void:
	var duration: int = maxi(
		turns,
		0
	)

	match kind:
		StatusKind.OFFENSE_BUFF:
			offense_buff_turns = duration

		StatusKind.OFFENSE_DEBUFF:
			offense_debuff_turns = duration

		StatusKind.DEFENSE_BUFF:
			defense_buff_turns = duration

		StatusKind.DEFENSE_DEBUFF:
			defense_debuff_turns = duration

	_recalculate_multipliers()


## Called once at the END of every round. Returns statuses that just expired.
func tick_statuses() -> Array[StatusKind]:
	var expired: Array[StatusKind] = []

	if offense_buff_turns > 0:
		offense_buff_turns -= 1

		if offense_buff_turns == 0:
			expired.append(
				StatusKind.OFFENSE_BUFF
			)

	if offense_debuff_turns > 0:
		offense_debuff_turns -= 1

		if offense_debuff_turns == 0:
			expired.append(
				StatusKind.OFFENSE_DEBUFF
			)

	if defense_buff_turns > 0:
		defense_buff_turns -= 1

		if defense_buff_turns == 0:
			expired.append(
				StatusKind.DEFENSE_BUFF
			)

	if defense_debuff_turns > 0:
		defense_debuff_turns -= 1

		if defense_debuff_turns == 0:
			expired.append(
				StatusKind.DEFENSE_DEBUFF
			)

	_recalculate_multipliers()

	return expired


func _recalculate_multipliers() -> void:
	offense_multiplier = 1.0
	defense_multiplier = 1.0

	if offense_buff_turns > 0:
		offense_multiplier *= (
			BattleRules
			.OFFENSE_BUFF_MULTIPLIER
		)

	if offense_debuff_turns > 0:
		offense_multiplier *= (
			BattleRules
			.OFFENSE_DEBUFF_MULTIPLIER
		)

	if defense_buff_turns > 0:
		defense_multiplier *= (
			BattleRules
			.DEFENSE_BUFF_MULTIPLIER
		)

	if defense_debuff_turns > 0:
		defense_multiplier *= (
			BattleRules
			.DEFENSE_DEBUFF_MULTIPLIER
		)


## Between rooms/battles: full restore and neutral statuses.
func reset_for_new_battle() -> void:
	hp = max_hp
	lp = max_lp

	is_alive = true
	is_guarding = false

	offense_buff_turns = 0
	offense_debuff_turns = 0
	defense_buff_turns = 0
	defense_debuff_turns = 0

	_recalculate_multipliers()
