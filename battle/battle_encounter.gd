class_name BattleEncounter
extends RefCounted
## Data-driven encounter definitions. Add new encounters here, not in the controller.

var encounter_id: String = ""
var allies: Array[BattleCombatant] = []
var enemies: Array[BattleCombatant] = []
var tracker: BattleTracker = BattleTracker.new()
var adaptation: BattleAdaptation = BattleAdaptation.new()


# ---------------------------------------------------------
# FACTORIES
# ---------------------------------------------------------

## 1 ally vs deMON
static func tutorial() -> BattleEncounter:
	var e: BattleEncounter = BattleEncounter.new()
	e.encounter_id = "tutorial"
	e.allies.append(make_protagonist())
	e.enemies.append(make_demon())
	return e


## 3 allies vs 2 enemies (validation encounter)
static func full_party_test() -> BattleEncounter:
	return normal_battle(2)


## 3 allies vs 1-2 regular enemies
static func normal_battle(
	enemy_count: int = 2,
	p_adaptation: BattleAdaptation = null,
	p_tracker: BattleTracker = null
) -> BattleEncounter:
	var e: BattleEncounter = BattleEncounter.new()
	e.encounter_id = "normal_%d" % enemy_count
	e.allies.append(make_protagonist())
	e.allies.append(make_companion_1())
	e.allies.append(make_companion_2())
	e.enemies.append(make_regular_enemy("drifter", BattleCombatant.CombatClass.VISIBLE))
	if enemy_count >= 2:
		e.enemies.append(make_regular_enemy("stray", BattleCombatant.CombatClass.HIGH_ENERGY))
	if p_adaptation != null:
		e.adaptation = p_adaptation
	if p_tracker != null:
		e.tracker = p_tracker
	return e


## 3 allies vs 1 boss
static func boss_battle(
	p_adaptation: BattleAdaptation = null,
	p_tracker: BattleTracker = null
) -> BattleEncounter:
	var e: BattleEncounter = BattleEncounter.new()
	e.encounter_id = "boss"
	e.allies.append(make_protagonist())
	e.allies.append(make_companion_1())
	e.allies.append(make_companion_2())
	e.enemies.append(make_boss())
	if p_adaptation != null:
		e.adaptation = p_adaptation
	if p_tracker != null:
		e.tracker = p_tracker
	return e


# ---------------------------------------------------------
# PARTY
# ---------------------------------------------------------

static func make_protagonist() -> BattleCombatant:
	var c: BattleCombatant = BattleCombatant.create(
		"protagonist", BattleCombatant.CombatClass.VISIBLE, 48, 30, 10, false
	)
	c.skill_ids = [
		BattleSkills.RADIO_WAVELENGTH,
		BattleSkills.VIOLET_BULLETS,
		BattleSkills.ULTRAVIOLET_VIOLENCE
	]
	return c


static func make_companion_1() -> BattleCombatant:
	var c: BattleCombatant = BattleCombatant.create(
		"companion 1", BattleCombatant.CombatClass.HIGH_ENERGY, 42, 28, 9, false
	)
	c.skill_ids = [
		BattleSkills.XXXRAY,
		BattleSkills.GREEN_BOOST,
		BattleSkills.BLUE_BOOST
	]
	return c


static func make_companion_2() -> BattleCombatant:
	var c: BattleCombatant = BattleCombatant.create(
		"companion 2", BattleCombatant.CombatClass.LOW_ENERGY, 44, 26, 11, false
	)
	c.skill_ids = [
		BattleSkills.MICROWAVE_MELT,
		BattleSkills.RED_DEBOOST,
		BattleSkills.PURPLE_DEBOOST
	]
	return c


# ---------------------------------------------------------
# ENEMIES
# ---------------------------------------------------------

static func make_demon() -> BattleCombatant:
	var c: BattleCombatant = BattleCombatant.create(
		"deMON", BattleCombatant.CombatClass.LOW_ENERGY, 42, 0, 8, true
	)
	c.attack_skill_id = BattleSkills.ATTACK   # tutorial: gentle 4 damage
	c.ai_guard_chance = 0.20
	return c


static func make_regular_enemy(
	p_name: String,
	p_class: BattleCombatant.CombatClass
) -> BattleCombatant:
	var c: BattleCombatant = BattleCombatant.create(p_name, p_class, 38, 0, 9, true)
	c.attack_skill_id = BattleSkills.ENEMY_STRIKE
	c.ai_guard_chance = 0.10
	return c


static func make_boss() -> BattleCombatant:
	var c: BattleCombatant = BattleCombatant.create(
		"the boss", BattleCombatant.CombatClass.HIGH_ENERGY, 100, 0, 12, true
	)
	c.attack_skill_id = BattleSkills.BOSS_STRIKE
	c.visual_scale = 1.6
	return c
