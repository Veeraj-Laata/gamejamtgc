extends Node


var encounter: BattleEncounter = null

var round_number: int = 0

var current_side: String = ""
var current_index: int = 0

var waiting_for_player_input: bool = false


func _ready() -> void:
	start_tutorial_battle()


func _unhandled_input(event: InputEvent) -> void:
	if not waiting_for_player_input:
		return

	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey

	if not key_event.pressed:
		return

	if key_event.echo:
		return

	match key_event.keycode:
		KEY_1:
			_player_choose_action("physical_attack")

		KEY_2:
			_player_choose_action("guard")

		KEY_3:
			_player_choose_action("radio_wavelength")

		KEY_4:
			_player_choose_action("violet_bullets")

		KEY_5:
			_player_choose_action("ultraviolet_violence")


func start_tutorial_battle() -> void:
	encounter = BattleEncounter.tutorial()

	round_number = 0
	current_side = ""
	current_index = 0
	waiting_for_player_input = false

	print("")
	print("================================")
	print("BATTLE START")
	print("================================")

	_print_party(
		"ALLIES",
		encounter.allies
	)

	_print_party(
		"ENEMIES",
		encounter.enemies
	)

	print("")
	print("RULE: ALL ALLIES ACT, THEN ALL ENEMIES ACT.")
	print("")

	_start_next_round()


func _start_next_round() -> void:
	round_number += 1

	print("--------------------------------")
	print("ROUND " + str(round_number))
	print("--------------------------------")

	_start_ally_phase()


func _start_ally_phase() -> void:
	current_side = "allies"
	current_index = 0

	print("ALLY PHASE")

	_announce_next_living_combatant()


func _start_enemy_phase() -> void:
	current_side = "enemies"
	current_index = 0

	print("ENEMY PHASE")

	_announce_next_living_combatant()


func _announce_next_living_combatant() -> void:
	var current_list: Array[BattleCombatant]

	if current_side == "allies":
		current_list = encounter.allies
	else:
		current_list = encounter.enemies

	while current_index < current_list.size():
		var combatant: BattleCombatant = (
			current_list[current_index]
		)

		current_index += 1

		if not combatant.is_alive:
			continue

		print(
			"TURN: "
			+ combatant.character_name
			+ " | "
			+ current_side
		)

		if current_side == "allies":
			_begin_player_turn(combatant)
		else:
			_begin_enemy_turn(combatant)

		return

	if current_side == "allies":
		_start_enemy_phase()
	else:
		_finish_current_round()


func _begin_player_turn(
	combatant: BattleCombatant
) -> void:

	waiting_for_player_input = true

	print("")
	print(
		combatant.character_name
		+ " - CHOOSE ACTION:"
	)

	print("1 - Physical Attack")
	print("2 - Guard")
	print("3 - Radio Wavelength")
	print("4 - Violet Bullets")
	print("5 - Ultraviolet Violence")
	print("")


func _begin_enemy_turn(
	combatant: BattleCombatant
) -> void:

	waiting_for_player_input = false

	print(
		combatant.character_name
		+ " chooses Physical Attack."
	)

	var target: BattleCombatant = (
		_get_first_living_combatant(
			encounter.allies
		)
	)

	if target != null:
		_execute_skill(
			combatant,
			"physical_attack",
			[target]
		)

	_check_battle_end()

	if _battle_is_over():
		return

	_announce_next_living_combatant()


func _player_choose_action(
	skill_id: String
) -> void:

	if not waiting_for_player_input:
		return

	waiting_for_player_input = false

	var player: BattleCombatant = (
		_get_current_actor()
	)

	if player == null:
		return

	print(
		"Protagonist chooses "
		+ skill_id
		+ "."
	)

	var skill := BattleSkills.get_skill(
		skill_id
	)

	if skill == null:
		print("ERROR: Skill not found.")
		waiting_for_player_input = true
		return

	if player.lp < skill.lp_cost:
		print("Not enough LP.")
		waiting_for_player_input = true
		return

	var targets: Array[BattleCombatant] = []

	match skill.target_mode:

		BattleSkill.TargetMode.ONE_ENEMY:
			var enemy := _get_first_living_combatant(
				encounter.enemies
			)

			if enemy != null:
				targets.append(enemy)

		BattleSkill.TargetMode.ALL_ENEMIES:
			for enemy: BattleCombatant in encounter.enemies:
				if enemy.is_alive:
					targets.append(enemy)

		BattleSkill.TargetMode.ONE_ALLY:
			var ally := _get_first_living_combatant(
				encounter.allies
			)

			if ally != null:
				targets.append(ally)

		BattleSkill.TargetMode.SELF:
			targets.append(player)

	if targets.is_empty():
		print("No valid target.")
		waiting_for_player_input = true
		return

	_execute_skill(
		player,
		skill_id,
		targets
	)

	_check_battle_end()

	if _battle_is_over():
		return

	_announce_next_living_combatant()


func _execute_skill(
	attacker: BattleCombatant,
	skill_id: String,
	targets: Array[BattleCombatant]
) -> void:

	var skill := BattleSkills.get_skill(
		skill_id
	)

	if skill == null:
		return

	if attacker.lp < skill.lp_cost:
		return

	attacker.lp -= skill.lp_cost

	match skill.effect_type:

		BattleSkill.EffectType.DAMAGE:
			for target: BattleCombatant in targets:
				if not target.is_alive:
					continue

				var hits: int = 1

				if skill_id == "microwave_melt":
					hits = _get_microwave_hits()

				for hit_index in range(hits):
					var damage := BattleRules.calculate_damage(
						skill.base_damage,
						attacker,
						target
					)

					target.take_damage(damage)

					print(
						target.character_name
						+ " takes "
						+ str(damage)
						+ " damage."
					)

					if not target.is_alive:
						print(
							target.character_name
							+ " is defeated."
						)
						break

			if skill.self_hp_fraction > 0.0:
				var self_damage := int(
					ceil(
						float(attacker.hp)
						* skill.self_hp_fraction
					)
				)

				attacker.take_damage(self_damage)

				print(
					attacker.character_name
					+ " loses "
					+ str(self_damage)
					+ " HP."
				)

		BattleSkill.EffectType.HEAL:
			for target: BattleCombatant in targets:
				target.heal(
					skill.heal_amount
				)

				print(
					target.character_name
					+ " heals "
					+ str(skill.heal_amount)
					+ " HP."
				)

		BattleSkill.EffectType.BUFF_DEFENSE:
			for target: BattleCombatant in targets:
				target.defense_multiplier = (
					BattleRules.DEFENSE_BUFF_MULTIPLIER
				)

				target.defense_buff_turns = (
					skill.duration_turns
				)

				print(
					target.character_name
					+ " gains Defense Boost."
				)

		BattleSkill.EffectType.BUFF_OFFENSE:
			for target: BattleCombatant in targets:
				target.offense_multiplier = (
					BattleRules.OFFENSE_BUFF_MULTIPLIER
				)

				target.offense_buff_turns = (
					skill.duration_turns
				)

				print(
					target.character_name
					+ " gains Offense Boost."
				)

		BattleSkill.EffectType.DEBUFF_DEFENSE:
			for target: BattleCombatant in targets:
				target.defense_multiplier = (
					BattleRules.DEFENSE_DEBUFF_MULTIPLIER
				)

				target.defense_debuff_turns = (
					skill.duration_turns
				)

				print(
					target.character_name
					+ " gains Defense Debuff."
				)

		BattleSkill.EffectType.DEBUFF_OFFENSE:
			for target: BattleCombatant in targets:
				target.offense_multiplier = (
					BattleRules.OFFENSE_DEBUFF_MULTIPLIER
				)

				target.offense_debuff_turns = (
					skill.duration_turns
				)

				print(
					target.character_name
					+ " gains Offense Debuff."
				)

		BattleSkill.EffectType.GUARD:
			attacker.is_guarding = true

			print(
				attacker.character_name
				+ " is guarding."
			)


func _get_current_actor() -> BattleCombatant:
	if current_side != "allies":
		return null

	var index: int = current_index - 1

	if index < 0:
		return null

	if index >= encounter.allies.size():
		return null

	return encounter.allies[index]


func _get_first_living_combatant(
	party: Array[BattleCombatant]
) -> BattleCombatant:

	for combatant: BattleCombatant in party:
		if combatant.is_alive:
			return combatant

	return null


func _get_microwave_hits() -> int:
	var roll: float = randf()

	if roll < 0.35:
		return 2

	if roll < 0.60:
		return 3

	if roll < 0.75:
		return 4

	if roll < 0.85:
		return 5

	if roll < 0.92:
		return 6

	if roll < 0.97:
		return 7

	return 8


func _check_battle_end() -> void:
	var allies_alive: bool = (
		_get_first_living_combatant(
			encounter.allies
		) != null
	)

	var enemies_alive: bool = (
		_get_first_living_combatant(
			encounter.enemies
		) != null
	)

	if not enemies_alive:
		print("")
		print("VICTORY")
		print("")

	if not allies_alive:
		print("")
		print("DEFEAT")
		print("")


func _battle_is_over() -> bool:
	var allies_alive: bool = (
		_get_first_living_combatant(
			encounter.allies
		) != null
	)

	var enemies_alive: bool = (
		_get_first_living_combatant(
			encounter.enemies
		) != null
	)

	return (
		not allies_alive
		or not enemies_alive
	)


func _finish_current_round() -> void:
	print(
		"ROUND "
		+ str(round_number)
		+ " COMPLETE"
	)

	print("")

	_start_next_round()


func _print_party(
	label: String,
	party: Array[BattleCombatant]
) -> void:

	print(label + ":")

	for combatant: BattleCombatant in party:
		print(
			"  "
			+ combatant.character_name
			+ " | "
			+ combatant.combat_class
			+ " | HP "
			+ str(combatant.hp)
			+ "/"
			+ str(combatant.max_hp)
			+ " | LP "
			+ str(combatant.lp)
			+ "/"
			+ str(combatant.max_lp)
		)
