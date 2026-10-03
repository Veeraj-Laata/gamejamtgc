class_name BattleSkills
extends RefCounted


static func get_skill(skill_id: String) -> BattleSkill:
	match skill_id:

		"physical_attack":
			return _physical_attack()

		"guard":
			return _guard()

		"radio_wavelength":
			return _radio_wavelength()

		"violet_bullets":
			return _violet_bullets()

		"ultraviolet_violence":
			return _ultraviolet_violence()

		"xxxray":
			return _xxxray()

		"green_boost":
			return _green_boost()

		"blue_boost":
			return _blue_boost()

		"microwave_melt":
			return _microwave_melt()

		"red_deboost":
			return _red_deboost()

		"purple_deboost":
			return _purple_deboost()

	return null


static func _physical_attack() -> BattleSkill:
	var skill := BattleSkill.new(
		"physical_attack",
		"Physical Attack",
		0,
		BattleSkill.EffectType.DAMAGE,
		BattleSkill.TargetMode.ONE_ENEMY
	)

	skill.base_damage = 4
	skill.counts_for_tracker = false

	return skill


static func _guard() -> BattleSkill:
	var skill := BattleSkill.new(
		"guard",
		"Guard",
		0,
		BattleSkill.EffectType.GUARD,
		BattleSkill.TargetMode.SELF
	)

	skill.counts_for_tracker = false

	return skill


static func _radio_wavelength() -> BattleSkill:
	var skill := BattleSkill.new(
		"radio_wavelength",
		"Radio Wavelength",
		7,
		BattleSkill.EffectType.HEAL,
		BattleSkill.TargetMode.ONE_ALLY
	)

	skill.heal_amount = 8

	return skill


static func _violet_bullets() -> BattleSkill:
	var skill := BattleSkill.new(
		"violet_bullets",
		"Violet Bullets",
		9,
		BattleSkill.EffectType.DAMAGE,
		BattleSkill.TargetMode.ALL_ENEMIES
	)

	skill.base_damage = 6

	return skill


static func _ultraviolet_violence() -> BattleSkill:
	var skill := BattleSkill.new(
		"ultraviolet_violence",
		"Ultraviolet Violence",
		12,
		BattleSkill.EffectType.DAMAGE,
		BattleSkill.TargetMode.ONE_ENEMY
	)

	skill.base_damage = 12

	return skill


static func _xxxray() -> BattleSkill:
	var skill := BattleSkill.new(
		"xxxray",
		"XXXRay",
		15,
		BattleSkill.EffectType.DAMAGE,
		BattleSkill.TargetMode.ONE_ENEMY
	)

	skill.base_damage = 20
	skill.self_hp_fraction = 0.50

	return skill


static func _green_boost() -> BattleSkill:
	var skill := BattleSkill.new(
		"green_boost",
		"Green Boost",
		6,
		BattleSkill.EffectType.BUFF_DEFENSE,
		BattleSkill.TargetMode.ONE_ALLY
	)

	skill.duration_turns = 2

	return skill


static func _blue_boost() -> BattleSkill:
	var skill := BattleSkill.new(
		"blue_boost",
		"Blue Boost",
		8,
		BattleSkill.EffectType.BUFF_OFFENSE,
		BattleSkill.TargetMode.ONE_ALLY
	)

	skill.duration_turns = 2

	return skill


static func _microwave_melt() -> BattleSkill:
	var skill := BattleSkill.new(
		"microwave_melt",
		"Microwave Melt",
		7,
		BattleSkill.EffectType.DAMAGE,
		BattleSkill.TargetMode.ALL_ENEMIES
	)

	skill.base_damage = 3
	skill.min_hits = 2
	skill.max_hits = 8

	return skill


static func _red_deboost() -> BattleSkill:
	var skill := BattleSkill.new(
		"red_deboost",
		"Red Deboost",
		9,
		BattleSkill.EffectType.DEBUFF_DEFENSE,
		BattleSkill.TargetMode.ONE_ENEMY
	)

	skill.duration_turns = 2

	return skill


static func _purple_deboost() -> BattleSkill:
	var skill := BattleSkill.new(
		"purple_deboost",
		"Purple Deboost",
		10,
		BattleSkill.EffectType.DEBUFF_OFFENSE,
		BattleSkill.TargetMode.ONE_ENEMY
	)

	skill.duration_turns = 2

	return skill
