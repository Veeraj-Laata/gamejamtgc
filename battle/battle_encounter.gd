class_name BattleEncounter
extends RefCounted
## Data-driven encounter definitions.


var encounter_id: String = ""
var allies: Array[BattleCombatant] = []
var enemies: Array[BattleCombatant] = []
var tracker: BattleTracker = BattleTracker.new()
var adaptation: BattleAdaptation = BattleAdaptation.new()


# =========================================================
# TEST / GENERAL ENCOUNTERS
# =========================================================

static func tutorial() -> BattleEncounter:
	var e := BattleEncounter.new()

	e.encounter_id = "tutorial"

	e.allies.append(
		make_protagonist()
	)

	e.enemies.append(
		make_demon()
	)

	return e


static func full_party_test() -> BattleEncounter:
	return normal_battle(2)


static func normal_battle(
	enemy_count: int = 2,
	p_adaptation: BattleAdaptation = null,
	p_tracker: BattleTracker = null
) -> BattleEncounter:

	var e := BattleEncounter.new()

	e.encounter_id = "normal_%d" % enemy_count

	_add_full_party(e)

	e.enemies.append(
		make_visible_enemy("Enemy")
	)

	if enemy_count >= 2:
		e.enemies.append(
			make_high_energy_enemy("Enemy")
		)

	if p_adaptation != null:
		e.adaptation = p_adaptation

	if p_tracker != null:
		e.tracker = p_tracker

	return e


# =========================================================
# ROOM 1
# =========================================================

# FIGHT 1
# Bloodsac + Bloodsac
static func room1_enemy_01_battle(
	p_tracker: BattleTracker = null
) -> BattleEncounter:

	var e := BattleEncounter.new()

	e.encounter_id = "room1"

	_add_full_party(e)

	var bloodsac_1 := make_bloodsac(30)
	bloodsac_1.character_name = "Bloodsac"

	var bloodsac_2 := make_bloodsac(30)
	bloodsac_2.character_name = "Bloodsac"

	e.enemies.append(bloodsac_1)
	e.enemies.append(bloodsac_2)

	if p_tracker != null:
		e.tracker = p_tracker

	return e


# FIGHT 2
# Scissors + Scissors
static func room1_enemy_02_battle(
	p_tracker: BattleTracker = null
) -> BattleEncounter:

	var e := BattleEncounter.new()

	e.encounter_id = "room1"

	_add_full_party(e)

	var scissors_1 := make_scissors(38)
	scissors_1.character_name = "Scissors"

	var scissors_2 := make_scissors(38)
	scissors_2.character_name = "Scissors"

	e.enemies.append(scissors_1)
	e.enemies.append(scissors_2)

	if p_tracker != null:
		e.tracker = p_tracker

	return e


# =========================================================
# ROOM 2
# =========================================================

# FIGHT 3
# Bloodsac + Skeleton
static func room2_enemy_03_battle(
	p_tracker: BattleTracker = null
) -> BattleEncounter:

	var e := BattleEncounter.new()

	e.encounter_id = "room2"

	_add_full_party(e)

	var bloodsac := make_bloodsac(46)
	bloodsac.character_name = "Bloodsac"

	var skeleton := make_skeleton(44)
	skeleton.character_name = "Skeleton"

	e.enemies.append(bloodsac)
	e.enemies.append(skeleton)

	if p_tracker != null:
		e.tracker = p_tracker

	return e


# FIGHT 4
# Skeleton + Skeleton
static func room2_enemy_04_battle(
	p_tracker: BattleTracker = null
) -> BattleEncounter:

	var e := BattleEncounter.new()

	e.encounter_id = "room2"

	_add_full_party(e)

	var skeleton_1 := make_skeleton(54)
	skeleton_1.character_name = "Skeleton"

	var skeleton_2 := make_skeleton(54)
	skeleton_2.character_name = "Skeleton"

	e.enemies.append(skeleton_1)
	e.enemies.append(skeleton_2)

	if p_tracker != null:
		e.tracker = p_tracker

	return e


# =========================================================
# BOSS
# =========================================================

static func boss_battle(
	p_adaptation: BattleAdaptation = null,
	p_tracker: BattleTracker = null
) -> BattleEncounter:

	var e := BattleEncounter.new()

	e.encounter_id = "boss"

	_add_full_party(e)

	e.enemies.append(
		make_boss()
	)

	if p_adaptation != null:
		e.adaptation = p_adaptation

	if p_tracker != null:
		e.tracker = p_tracker

	return e


# =========================================================
# PARTY
# =========================================================

static func _add_full_party(
	e: BattleEncounter
) -> void:

	e.allies.append(
		make_protagonist()
	)

	e.allies.append(
		make_companion_1()
	)

	e.allies.append(
		make_companion_2()
	)


static func make_protagonist() -> BattleCombatant:

	var c := BattleCombatant.create(
		"Soulanki",
		BattleCombatant.CombatClass.VISIBLE,
		54,
		28,
		10,
		false
	)

	c.skill_ids = [
		BattleSkills.RADIO_WAVELENGTH,
		BattleSkills.VIOLET_BULLETS,
		BattleSkills.ULTRAVIOLET_VIOLENCE
	]

	return c


static func make_companion_1() -> BattleCombatant:

	var c := BattleCombatant.create(
		"Aoryn",
		BattleCombatant.CombatClass.HIGH_ENERGY,
		48,
		26,
		9,
		false
	)

	c.skill_ids = [
		BattleSkills.XXXRAY,
		BattleSkills.GREEN_BOOST,
		BattleSkills.BLUE_BOOST,
		BattleSkills.REVIVE
	]

	return c


static func make_companion_2() -> BattleCombatant:

	var c := BattleCombatant.create(
		"Feydor",
		BattleCombatant.CombatClass.LOW_ENERGY,
		50,
		26,
		11,
		false
	)

	c.skill_ids = [
		BattleSkills.MICROWAVE_MELT,
		BattleSkills.RED_DEBOOST,
		BattleSkills.PURPLE_DEBOOST
	]

	return c


# =========================================================
# BLOODsac
# =========================================================

static func make_bloodsac(
	hp_value: int
) -> BattleCombatant:

	var c := BattleCombatant.create(
		"Bloodsac",
		BattleCombatant.CombatClass.VISIBLE,
		hp_value,
		14,
		10,
		true
	)

	c.attack_skill_id = BattleSkills.RED_RAY

	c.skill_ids = [
		BattleSkills.RED_RAY,
		BattleSkills.VIOLET_FLASH,
		BattleSkills.BLUE_SHIFT
	]

	c.ai_guard_chance = 0.02

	c.visual_model_file = "BloodsacCrawler_Stylized.fbx"
	

	return c


# =========================================================
# SCISSORS
# =========================================================

static func make_scissors(
	hp_value: int
) -> BattleCombatant:

	var c := BattleCombatant.create(
		"Scissors",
		BattleCombatant.CombatClass.HIGH_ENERGY,
		hp_value,
		16,
		9,
		true
	)

	c.attack_skill_id = BattleSkills.XRAY_BURST

	c.skill_ids = [
		BattleSkills.ULTRAVIOLET_CUT,
		BattleSkills.XRAY_BURST,
		BattleSkills.GAMMA_RAY
	]

	c.ai_guard_chance = 0.04

	c.visual_model_file = "scissors.fbx"

	return c


# =========================================================
# SKELETON
# =========================================================

static func make_skeleton(
	hp_value: int
) -> BattleCombatant:

	var c := BattleCombatant.create(
		"Skeleton",
		BattleCombatant.CombatClass.LOW_ENERGY,
		hp_value,
		15,
		8,
		true
	)

	c.attack_skill_id = BattleSkills.BLUE_SHIFT

	c.skill_ids = [
		BattleSkills.BLUE_SHIFT,
		BattleSkills.VIOLET_FLASH,
		BattleSkills.ULTRAVIOLET_CUT
	]

	c.ai_guard_chance = 0.12

	c.visual_model_file = "skeleton.fbx"

	return c


# =========================================================
# GENERIC ENEMIES
# =========================================================

static func make_demon() -> BattleCombatant:

	var c := BattleCombatant.create(
		"deMON",
		BattleCombatant.CombatClass.LOW_ENERGY,
		42,
		0,
		8,
		true
	)

	c.attack_skill_id = BattleSkills.ATTACK
	c.ai_guard_chance = 0.20

	return c


static func make_visible_enemy(
	p_name: String
) -> BattleCombatant:

	var c := BattleCombatant.create(
		p_name,
		BattleCombatant.CombatClass.VISIBLE,
		38,
		12,
		9,
		true
	)

	c.attack_skill_id = BattleSkills.RED_RAY

	c.skill_ids = [
		BattleSkills.RED_RAY,
		BattleSkills.BLUE_SHIFT,
		BattleSkills.VIOLET_FLASH
	]

	c.ai_guard_chance = 0.10

	return c


static func make_low_energy_enemy(
	p_name: String
) -> BattleCombatant:

	var c := BattleCombatant.create(
		p_name,
		BattleCombatant.CombatClass.LOW_ENERGY,
		38,
		12,
		9,
		true
	)

	c.attack_skill_id = BattleSkills.INFRARED_BURN

	c.skill_ids = [
		BattleSkills.RED_RAY,
		BattleSkills.MICROWAVE_PULSE,
		BattleSkills.RADIO_STATIC
	]

	c.ai_guard_chance = 0.10

	return c


static func make_high_energy_enemy(
	p_name: String
) -> BattleCombatant:

	var c := BattleCombatant.create(
		p_name,
		BattleCombatant.CombatClass.HIGH_ENERGY,
		38,
		14,
		9,
		true
	)

	c.attack_skill_id = BattleSkills.ULTRAVIOLET_CUT

	c.skill_ids = [
		BattleSkills.ULTRAVIOLET_CUT,
		BattleSkills.XRAY_BURST,
		BattleSkills.GAMMA_RAY
	]

	c.ai_guard_chance = 0.10

	return c


# =========================================================
# BOSS — twIST
# =========================================================

static func make_boss() -> BattleCombatant:

	var c := BattleCombatant.create(
		"twIST",
		BattleCombatant.CombatClass.HIGH_ENERGY,
		180,
		18,
		12,
		true
	)

	c.attack_skill_id = BattleSkills.BOSS_CRUSH

	c.skill_ids = [
		BattleSkills.BOSS_GAMMA,
		BattleSkills.BOSS_XRAY,
		BattleSkills.BOSS_SURGE
	]

	c.ai_guard_chance = 0.09

	c.visual_scale = 2.0
	c.visual_model_file = "Robot_Eye.fbx"

	return c
