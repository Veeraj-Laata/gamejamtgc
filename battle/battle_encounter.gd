class_name BattleEncounter
extends RefCounted


var allies: Array[BattleCombatant] = []
var enemies: Array[BattleCombatant] = []


static func tutorial():
	var encounter := BattleEncounter.new()

	var protagonist := BattleCombatant.new(
		"Protagonist",
		"Visible",
		48,
		30,
		10,
		false
	)

	protagonist.skill_ids = [
		"physical_attack",
		"guard",
		"radio_wavelength",
		"violet_bullets",
		"ultraviolet_violence"
	]

	encounter.allies.append(
		protagonist
	)


	var tutorial_demon := BattleCombatant.new(
		"Tutorial deMON",
		"LowEnergy",
		42,
		0,
		8,
		true
	)

	tutorial_demon.skill_ids = [
		"physical_attack",
		"guard"
	]

	encounter.enemies.append(
		tutorial_demon
	)

	return encounter


static func full_party_test():
	var encounter := BattleEncounter.new()

	var protagonist := BattleCombatant.new(
		"Protagonist",
		"Visible",
		48,
		30,
		10,
		false
	)

	protagonist.skill_ids = [
		"physical_attack",
		"guard",
		"radio_wavelength",
		"violet_bullets",
		"ultraviolet_violence"
	]

	encounter.allies.append(
		protagonist
	)


	var companion_1 := BattleCombatant.new(
		"Companion 1",
		"HighEnergy",
		42,
		28,
		8,
		false
	)

	companion_1.skill_ids = [
		"physical_attack",
		"guard",
		"xxxray",
		"green_boost",
		"blue_boost"
	]

	encounter.allies.append(
		companion_1
	)


	var companion_2 := BattleCombatant.new(
		"Companion 2",
		"LowEnergy",
		44,
		26,
		12,
		false
	)

	companion_2.skill_ids = [
		"physical_attack",
		"guard",
		"microwave_melt",
		"red_deboost",
		"purple_deboost"
	]

	encounter.allies.append(
		companion_2
	)


	var enemy_1 := BattleCombatant.new(
		"Enemy 1",
		"HighEnergy",
		38,
		0,
		7,
		true
	)

	enemy_1.skill_ids = [
		"physical_attack",
		"guard",
		"ultraviolet_violence",
		"green_boost",
		"xxxray"
	]

	encounter.enemies.append(
		enemy_1
	)


	var enemy_2 := BattleCombatant.new(
		"Enemy 2",
		"Visible",
		38,
		0,
		6,
		true
	)

	enemy_2.skill_ids = [
		"physical_attack",
		"guard",
		"violet_bullets",
		"red_deboost",
		"purple_deboost"
	]

	encounter.enemies.append(
		enemy_2
	)

	return encounter
