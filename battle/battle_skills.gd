class_name BattleSkills
extends RefCounted
## Central skill database.
## Everything is data: enemies and players share it.


const ATTACK: String = "attack"
const GUARD: String = "guard"

const ENEMY_STRIKE: String = "enemy_strike"
const BOSS_STRIKE: String = "boss_strike"

const RADIO_WAVELENGTH: String = "radio_wavelength"
const VIOLET_BULLETS: String = "violet_bullets"
const ULTRAVIOLET_VIOLENCE: String = "ultraviolet_violence"

const XXXRAY: String = "xxxray"
const GREEN_BOOST: String = "green_boost"
const BLUE_BOOST: String = "blue_boost"

const MICROWAVE_MELT: String = "microwave_melt"
const RED_DEBOOST: String = "red_deboost"
const PURPLE_DEBOOST: String = "purple_deboost"


const STATUS_DURATION: int = 2


static var _db: Dictionary = {}


static func get_skill(
	skill_id: String
) -> BattleSkill:
	if _db.is_empty():
		_build()

	if _db.has(skill_id):
		return _db[skill_id] as BattleSkill

	push_warning(
		"BattleSkills: unknown skill id '%s'"
		% skill_id
	)

	return null


static func _add(
	skill: BattleSkill
) -> void:
	_db[skill.skill_id] = skill


static func _build() -> void:
	var E: Variant = BattleSkill.EffectType
	var T: Variant = BattleSkill.TargetMode
	var S: Variant = BattleSkill.SkillType


	# =====================================================
	# UNIVERSAL
	# =====================================================

	_add(
		BattleSkill.create(
			ATTACK,
			"attack",
			0,
			E.DAMAGE,
			T.ONE_ENEMY
		)
		.with_damage(4.0)
		.physical()
	)

	_add(
		BattleSkill.create(
			GUARD,
			"guard",
			0,
			E.GUARD,
			T.SELF
		)
		.with_type(S.NEUTRAL)
		.untracked()
	)


	# =====================================================
	# ENEMY BASIC ATTACKS
	# Physical / neutral.
	# Their CLASS is still displayed separately on enemies.
	# =====================================================

	_add(
		BattleSkill.create(
			ENEMY_STRIKE,
			"strike",
			0,
			E.DAMAGE,
			T.ONE_ENEMY
		)
		.with_damage(8.0)
		.physical()
	)

	_add(
		BattleSkill.create(
			BOSS_STRIKE,
			"crush",
			0,
			E.DAMAGE,
			T.ONE_ENEMY
		)
		.with_damage(12.0)
		.physical()
	)


	# =====================================================
	# PROTAGONIST — VISIBLE
	# =====================================================

	_add(
		BattleSkill.create(
			RADIO_WAVELENGTH,
			"radio wavelength",
			7,
			E.HEAL,
			T.ONE_ALLY
		)
		.with_heal(8)
		.with_type(S.SUPPORT)
	)

	_add(
		BattleSkill.create(
			VIOLET_BULLETS,
			"violet bullets",
			9,
			E.DAMAGE,
			T.ALL_ENEMIES
		)
		.with_damage(6.0)
		.with_type(S.VISIBLE)
	)

	_add(
		BattleSkill.create(
			ULTRAVIOLET_VIOLENCE,
			"ultraviolet violence",
			12,
			E.DAMAGE,
			T.ONE_ENEMY
		)
		.with_damage(12.0)
		.with_type(S.VISIBLE)
	)


	# =====================================================
	# COMPANION 1 — HIGH ENERGY
	# =====================================================

	_add(
		BattleSkill.create(
			XXXRAY,
			"xxxray",
			15,
			E.DAMAGE,
			T.ONE_ENEMY
		)
		.with_damage(20.0)
		.with_self_hp_fraction(0.5)
		.with_type(S.HIGH_ENERGY)
	)

	_add(
		BattleSkill.create(
			GREEN_BOOST,
			"green boost",
			6,
			E.BUFF_DEFENSE,
			T.ONE_ALLY
		)
		.with_duration(STATUS_DURATION)
		.with_type(S.SUPPORT)
	)

	_add(
		BattleSkill.create(
			BLUE_BOOST,
			"blue boost",
			8,
			E.BUFF_OFFENSE,
			T.ONE_ALLY
		)
		.with_duration(STATUS_DURATION)
		.with_type(S.SUPPORT)
	)


	# =====================================================
	# COMPANION 2 — LOW ENERGY
	# =====================================================

	var melt_weights: Array[float] = [
		30.0,
		26.0,
		15.0,
		10.0,
		8.0,
		6.0,
		5.0
	]

	_add(
		BattleSkill.create(
			MICROWAVE_MELT,
			"microwave melt",
			7,
			E.DAMAGE,
			T.ALL_ENEMIES
		)
		.with_damage(3.0)
		.with_hits(
			2,
			8,
			melt_weights
		)
		.with_type(S.LOW_ENERGY)
	)

	_add(
		BattleSkill.create(
			RED_DEBOOST,
			"red deboost",
			9,
			E.DEBUFF_DEFENSE,
			T.ONE_ENEMY
		)
		.with_duration(STATUS_DURATION)
		.with_type(S.SUPPORT)
	)

	_add(
		BattleSkill.create(
			PURPLE_DEBOOST,
			"purple deboost",
			10,
			E.DEBUFF_OFFENSE,
			T.ONE_ENEMY
		)
		.with_duration(STATUS_DURATION)
		.with_type(S.SUPPORT)
	)
