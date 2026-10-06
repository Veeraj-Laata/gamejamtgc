class_name BattleSkills
extends RefCounted
## Central skill database.
## Players and enemies share the same BattleSkill data model.
##
## Damage skills have an explicit spectrum type:
## - VISIBLE
## - HIGH_ENERGY
## - LOW_ENERGY
##
## CLOSED MATCHUP LOOP — applies to every damaging attack:
## Visible -> beats -> High Energy
## High Energy -> beats -> Low Energy
## Low Energy -> beats -> Visible
##
## No damaging attack is allowed to bypass this matchup.


const ATTACK: String = "attack"
const GUARD: String = "guard"

# ---------------------------------------------------------
# ENEMY — VISIBLE SPECTRUM
# ---------------------------------------------------------

const RED_RAY: String = "red_ray"
const BLUE_SHIFT: String = "blue_shift"
const VIOLET_FLASH: String = "violet_flash"

# ---------------------------------------------------------
# ENEMY — LOW ENERGY
# ---------------------------------------------------------

const INFRARED_BURN: String = "infrared_burn"
const MICROWAVE_PULSE: String = "microwave_pulse"
const RADIO_STATIC: String = "radio_static"

# ---------------------------------------------------------
# ENEMY — HIGH ENERGY
# ---------------------------------------------------------

const ULTRAVIOLET_CUT: String = "ultraviolet_cut"
const XRAY_BURST: String = "xray_burst"
const GAMMA_RAY: String = "gamma_ray"

# ---------------------------------------------------------
# BOSS
# ---------------------------------------------------------

const BOSS_CRUSH: String = "boss_crush"
const BOSS_GAMMA: String = "boss_gamma"
const BOSS_XRAY: String = "boss_xray"
const BOSS_SURGE: String = "boss_surge"

# ---------------------------------------------------------
# PLAYER
# ---------------------------------------------------------

const RADIO_WAVELENGTH: String = "radio_wavelength"
const VIOLET_BULLETS: String = "violet_bullets"
const ULTRAVIOLET_VIOLENCE: String = "ultraviolet_violence"

const XXXRAY: String = "xxxray"
const GREEN_BOOST: String = "green_boost"
const BLUE_BOOST: String = "blue_boost"

const MICROWAVE_MELT: String = "microwave_melt"
const RED_DEBOOST: String = "red_deboost"
const PURPLE_DEBOOST: String = "purple_deboost"

# ---------------------------------------------------------
# SUPPORT
# ---------------------------------------------------------

const REVIVE: String = "revive"

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
	if skill == null:
		return

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
		.with_damage(10.0)
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
		.untracked()
	)

	# =====================================================
	# ENEMY — VISIBLE
	# =====================================================

	_add(
		BattleSkill.create(
			RED_RAY,
			"red ray",
			3,
			E.DAMAGE,
			T.ONE_ENEMY
		)
		.with_damage(8.0)
		.with_type(S.VISIBLE)
	)

	_add(
		BattleSkill.create(
			BLUE_SHIFT,
			"blue shift",
			4,
			E.DEBUFF_DEFENSE,
			T.ONE_ENEMY
		)
		.with_duration(
			STATUS_DURATION
		)
		.with_type(S.VISIBLE)
	)

	_add(
		BattleSkill.create(
			VIOLET_FLASH,
			"violet flash",
			5,
			E.DAMAGE,
			T.ONE_ENEMY
		)
		.with_damage(7.0)
		.with_type(S.VISIBLE)
	)

	# =====================================================
	# ENEMY — LOW ENERGY
	# =====================================================

	_add(
		BattleSkill.create(
			INFRARED_BURN,
			"infrared burn",
			3,
			E.DAMAGE,
			T.ONE_ENEMY
		)
		.with_damage(6.0)
		.with_type(S.LOW_ENERGY)
	)

	_add(
		BattleSkill.create(
			MICROWAVE_PULSE,
			"microwave pulse",
			5,
			E.DAMAGE,
			T.ALL_ENEMIES
		)
		.with_damage(4.0)
		.with_type(S.LOW_ENERGY)
	)

	_add(
		BattleSkill.create(
			RADIO_STATIC,
			"radio static",
			4,
			E.DEBUFF_OFFENSE,
			T.ONE_ENEMY
		)
		.with_duration(
			STATUS_DURATION
		)
		.with_type(S.LOW_ENERGY)
	)

	# =====================================================
	# ENEMY — HIGH ENERGY
	# =====================================================

	_add(
		BattleSkill.create(
			ULTRAVIOLET_CUT,
			"ultraviolet cut",
			4,
			E.DAMAGE,
			T.ONE_ENEMY
		)
		.with_damage(7.0)
		.with_type(S.HIGH_ENERGY)
	)

	_add(
		BattleSkill.create(
			XRAY_BURST,
			"x-ray burst",
			6,
			E.DAMAGE,
			T.ONE_ENEMY
		)
		.with_damage(10.0)
		.with_type(S.HIGH_ENERGY)
	)

	_add(
		BattleSkill.create(
			GAMMA_RAY,
			"gamma ray",
			7,
			E.DAMAGE,
			T.ALL_ENEMIES
		)
		.with_damage(5.0)
		.with_type(S.HIGH_ENERGY)
	)

	# =====================================================
	# BOSS
	# =====================================================

	_add(
		BattleSkill.create(
			BOSS_CRUSH,
			"crush",
			0,
			E.DAMAGE,
			T.ONE_ENEMY
		)
		.with_damage(14.0)
		.physical()
		.with_type(S.HIGH_ENERGY)
	)

	_add(
		BattleSkill.create(
			BOSS_GAMMA,
			"gamma ray",
			5,
			E.DAMAGE,
			T.ALL_ENEMIES
		)
		.with_damage(7.0)
		.with_type(S.HIGH_ENERGY)
	)

	_add(
		BattleSkill.create(
			BOSS_XRAY,
			"x-ray",
			6,
			E.DAMAGE,
			T.ONE_ENEMY
		)
		.with_damage(84.0)
		.with_type(S.HIGH_ENERGY)
	)

	_add(
		BattleSkill.create(
			BOSS_SURGE,
			"energy surge",
			5,
			E.BUFF_OFFENSE,
			T.SELF
		)
		.with_duration(
			STATUS_DURATION
		)
		.with_type(S.SUPPORT)
	)

	# =====================================================
	# PROTAGONIST
	# =====================================================

	_add(
		BattleSkill.create(
			RADIO_WAVELENGTH,
			"radio wavelength",
			8,
			E.HEAL,
			T.ONE_ALLY
		)
		.with_heal(22)
		.with_type(S.SUPPORT)
	)

	_add(
		BattleSkill.create(
			VIOLET_BULLETS,
			"violet bullets",
			8,
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
			10,
			E.DAMAGE,
			T.ONE_ENEMY
		)
		.with_damage(12.0)
		.with_type(S.HIGH_ENERGY)
	)

	# =====================================================
	# COMPANION 1
	# =====================================================

	_add(
		BattleSkill.create(
			XXXRAY,
			"xxxray",
			12,
			E.DAMAGE,
			T.ONE_ENEMY
		)
		.with_damage(18.0)
		.with_self_hp_fraction(0.50)
		.with_type(S.HIGH_ENERGY)
	)

	_add(
		BattleSkill.create(
			GREEN_BOOST,
			"green boost",
			7,
			E.BUFF_DEFENSE,
			T.ONE_ALLY
		)
		.with_duration(
			STATUS_DURATION
		)
		.with_type(S.SUPPORT)
	)

	_add(
		BattleSkill.create(
			BLUE_BOOST,
			"blue boost",
			7,
			E.BUFF_OFFENSE,
			T.ONE_ALLY
		)
		.with_duration(
			STATUS_DURATION
		)
		.with_type(S.SUPPORT)
	)

	# =====================================================
	# COMPANION 2
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
			12,
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
			7,
			E.DEBUFF_DEFENSE,
			T.ONE_ENEMY
		)
		.with_duration(
			STATUS_DURATION
		)
		.with_type(S.VISIBLE)
	)

	_add(
		BattleSkill.create(
			PURPLE_DEBOOST,
			"purple deboost",
			8,
			E.DEBUFF_OFFENSE,
			T.ONE_ENEMY
		)
		.with_duration(
			STATUS_DURATION
		)
		.with_type(S.VISIBLE)
	)

	# =====================================================
	# REVIVE
	# =====================================================

	_add(
		BattleSkill.create(
			REVIVE,
			"revive",
			12,
			E.REVIVE,
			T.ONE_ALLY
		)
		.with_heal(10)
		.with_type(S.SUPPORT)
	)
