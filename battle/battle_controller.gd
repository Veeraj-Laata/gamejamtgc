class_name BattleController
extends Node
## Battle state machine and turn flow. No visuals in here: everything the
## presentation needs is exposed as signals.
##
## Turn model (side based, NOT speed based):
##   round: every living ally acts once, then every living enemy acts once.
## Status ticking: statuses are applied with duration 2 and ticked ONCE at the
## END of each round, so a status lasts the rest of the round it was applied in
## plus the next full round.


enum State {
	NONE,
	ACTION_MENU,
	SKILL_MENU,
	TARGET_MENU,
	RESOLVING,
	BATTLE_OVER
}


# ---- presentation hooks ----

signal battle_started(encounter: BattleEncounter)
signal round_started(round_number: int)
signal turn_started(combatant: BattleCombatant)
signal guard_cleared(combatant: BattleCombatant)
signal enemy_thinking(combatant: BattleCombatant)

signal action_selected(
	combatant: BattleCombatant,
	skill: BattleSkill,
	targets: Array
)

signal action_started(
	combatant: BattleCombatant,
	skill: BattleSkill,
	targets: Array
)

signal impact(
	combatant: BattleCombatant,
	target: BattleCombatant,
	amount: int,
	info: Dictionary
)

signal heal_applied(
	combatant: BattleCombatant,
	target: BattleCombatant,
	amount: int
)

signal buff_applied(
	combatant: BattleCombatant,
	target: BattleCombatant,
	kind: int
)

signal debuff_applied(
	combatant: BattleCombatant,
	target: BattleCombatant,
	kind: int
)

signal guard_applied(combatant: BattleCombatant)

signal self_damaged(
	combatant: BattleCombatant,
	amount: int
)

signal combatant_defeated(
	combatant: BattleCombatant
)

signal status_expired(
	combatant: BattleCombatant,
	kind: int
)

signal turn_finished(
	combatant: BattleCombatant
)

signal battle_won
signal battle_lost
signal battle_finished(
	victory: bool
)


# ---- menu / feedback for the UI ----

signal menu_updated(
	kind: String,
	entries: Array,
	selected: int
)

signal target_highlight(
	targets: Array
)

signal notice(
	text: String
)

signal state_changed(
	new_state: int
)

signal _decided(
	choice: Dictionary
)


# pacing (seconds, multiplied by beat_scale; set beat_scale = 0 for instant tests)

@export var beat_scale: float = 1.0

const INTRO_TIME: float = 1.0
const ROUND_TIME: float = 0.8
const TURN_START_TIME: float = 0.35
const THINK_TIME: float = 1.0
const WINDUP_TIME: float = 0.55
const HIT_GAP: float = 0.32
const DEFEAT_TIME: float = 0.6
const AFTER_ACTION_TIME: float = 0.55

const LP_REGEN_PER_TURN: int = 2


var encounter: BattleEncounter = null
var state: State = State.NONE
var round_number: int = 0
var current: BattleCombatant = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Replaceable enemy targeting. Signature:
## (actor, skill, valid_targets) -> Array
var target_picker: Callable = Callable()


var rejected_skill_id: String = ""

## Boss mechanic: after Energy Surge, the boss is locked into its next
## devastating HIGH ENERGY attack. The flag is cleared immediately after
## that attack resolves.
var boss_devastating_attack_pending: bool = false

## Counts made during the current battle.
var _room1_skill_counts: Dictionary = {}
var _room2_skill_counts: Dictionary = {}


const ROOM1_ENCOUNTER_ID: String = "room1"
const ROOM2_ENCOUNTER_ID: String = "room2"
const BOSS_ENCOUNTER_ID: String = "boss"

const ROOM1_COUNTS_META: String = (
	"robruzz_room1_skill_counts"
)

const ROOM1_MOST_USED_SKILL_META: String = (
	"robruzz_room1_most_used_skill_id"
)

const ROOM1_TRACKING_INITIALIZED_META: String = (
	"robruzz_room1_tracking_initialized"
)

const ROOM2_COUNTS_META: String = (
	"robruzz_room2_skill_counts"
)

const ROOM2_RESISTED_SKILL_META: String = (
	"robruzz_room2_resisted_skill_id"
)

const ROOM2_TRACKING_INITIALIZED_META: String = (
	"robruzz_room2_tracking_initialized"
)

const BOSS_REJECTED_SKILL_META: String = (
	"robruzz_boss_rejected_skill_id"
)


var _action_labels: Array[String] = [
	"attack",
	"skills",
	"guard"
]

var _menu_index: int = 0
var _skill_menu: Array[BattleSkill] = []
var _skill_index: int = 0

var _pending_skill: BattleSkill = null
var _target_list: Array[BattleCombatant] = []
var _target_index: int = 0
var _target_all: bool = false
var _target_return: State = State.ACTION_MENU


# =========================================================
# START
# =========================================================

func start_battle(
	p_encounter: BattleEncounter
) -> void:
	encounter = p_encounter

	rng.randomize()

	round_number = 0
	rejected_skill_id = ""
	boss_devastating_attack_pending = false

	_room1_skill_counts.clear()
	_room2_skill_counts.clear()

	_pending_skill = null
	_target_list.clear()
	_target_index = 0
	_target_all = false

	_prepare_tracking_state()

	if (
		encounter != null
		and
		encounter.encounter_id == ROOM2_ENCOUNTER_ID
	):
		_apply_room2_resistance_from_room1()

	if (
		encounter != null
		and
		encounter.encounter_id == BOSS_ENCOUNTER_ID
	):
		_load_boss_rejection()

	_set_state(
		State.NONE
	)

	battle_started.emit(
		encounter
	)

	if _check_battle_end():
		return

	_run_battle()


func _prepare_tracking_state() -> void:
	var active_id: String = (
		_get_active_encounter_id()
	)

	if (
		encounter != null
		and
		(
			encounter.encounter_id == ROOM1_ENCOUNTER_ID
			or
			active_id == "traversal_enemy_01"
			or
			active_id == "traversal_enemy_02"
		)
	):
		if not get_tree().has_meta(
			ROOM1_TRACKING_INITIALIZED_META
		):
			get_tree().set_meta(
				ROOM1_COUNTS_META,
				{}
			)

			get_tree().set_meta(
				ROOM1_MOST_USED_SKILL_META,
				""
			)

			get_tree().set_meta(
				ROOM1_TRACKING_INITIALIZED_META,
				true
			)

	if (
		encounter != null
		and
		encounter.encounter_id == ROOM2_ENCOUNTER_ID
	):
		if not get_tree().has_meta(
			ROOM2_TRACKING_INITIALIZED_META
		):
			get_tree().set_meta(
				ROOM2_COUNTS_META,
				{}
			)

			get_tree().set_meta(
				ROOM2_RESISTED_SKILL_META,
				""
			)

			get_tree().set_meta(
				ROOM2_TRACKING_INITIALIZED_META,
				true
			)


func _get_active_encounter_id() -> String:
	if not get_tree().has_meta(
		"robruzz_active_encounter_id"
	):
		return ""

	var stored: Variant = (
		get_tree().get_meta(
			"robruzz_active_encounter_id"
		)
	)

	if stored is String:
		return stored as String

	return ""


func _apply_room2_resistance_from_room1() -> void:
	if encounter == null:
		return

	var resisted_skill_id: String = ""

	if get_tree().has_meta(
		ROOM1_MOST_USED_SKILL_META
	):
		var stored: Variant = (
			get_tree().get_meta(
				ROOM1_MOST_USED_SKILL_META
			)
		)

		if stored is String:
			resisted_skill_id = (
				stored as String
			)

	if resisted_skill_id.is_empty():
		get_tree().set_meta(
			ROOM2_RESISTED_SKILL_META,
			""
		)

		return

	get_tree().set_meta(
		ROOM2_RESISTED_SKILL_META,
		resisted_skill_id
	)

	for enemy: BattleCombatant in encounter.enemies:
		if enemy == null:
			continue

		encounter.adaptation.set_enemy_resistance(
			enemy.character_name,
			resisted_skill_id,
			0.5
		)


func _load_boss_rejection() -> void:
	if not get_tree().has_meta(
		BOSS_REJECTED_SKILL_META
	):
		return

	var stored: Variant = (
		get_tree().get_meta(
			BOSS_REJECTED_SKILL_META
		)
	)

	if stored is String:
		var skill_id: String = (
			stored as String
		)

		if not skill_id.is_empty():
			rejected_skill_id = skill_id


func _run_battle() -> void:
	await _wait(
		INTRO_TIME
	)

	if _check_battle_end():
		return

	while state != State.BATTLE_OVER:
		round_number += 1

		round_started.emit(
			round_number
		)

		await _wait(
			ROUND_TIME
		)

		for ally in _snapshot(false):
			if state == State.BATTLE_OVER:
				return

			if not ally.is_alive:
				continue

			await _take_player_turn(
				ally
			)

			if _check_battle_end():
				return

		for enemy in _snapshot(true):
			if state == State.BATTLE_OVER:
				return

			if not enemy.is_alive:
				continue

			await _take_enemy_turn(
				enemy
			)

			if _check_battle_end():
				return

		_tick_round_end()


func _snapshot(
	is_enemy_side: bool
) -> Array[BattleCombatant]:
	var out: Array[BattleCombatant] = []

	for c in _side(
		is_enemy_side
	):
		out.append(c)

	return out


func _side(
	is_enemy_side: bool
) -> Array[BattleCombatant]:
	if is_enemy_side:
		return encounter.enemies

	return encounter.allies


func _set_state(
	new_state: State
) -> void:
	state = new_state

	state_changed.emit(
		int(new_state)
	)


func _wait(
	seconds: float
) -> void:
	var t: float = (
		seconds
		*
		beat_scale
	)

	if t <= 0.0:
		return

	await get_tree().create_timer(
		t
	).timeout


# =========================================================
# TURNS
# =========================================================

func _begin_turn(
	c: BattleCombatant
) -> void:
	current = c

	if c.is_guarding:
		c.clear_guard()

		guard_cleared.emit(
			c
		)

	if not c.is_enemy:
		c.lp = clampi(
			c.lp + LP_REGEN_PER_TURN,
			0,
			c.max_lp
		)

	turn_started.emit(
		c
	)


func _take_player_turn(
	c: BattleCombatant
) -> void:
	_set_state(
		State.RESOLVING
	)

	_begin_turn(c)

	await _wait(
		TURN_START_TIME
	)

	_menu_index = 0
	_open_action_menu()

	var choice: Dictionary = await _decided

	_set_state(
		State.RESOLVING
	)

	menu_updated.emit(
		"none",
		[],
		0
	)

	target_highlight.emit([])

	var skill: BattleSkill = (
		choice["skill"]
		as BattleSkill
	)

	var targets: Array = (
		choice["targets"]
		as Array
	)

	action_selected.emit(
		c,
		skill,
		targets
	)

	await _execute(
		c,
		skill,
		targets
	)

	turn_finished.emit(
		c
	)


func _take_enemy_turn(
	c: BattleCombatant
) -> void:
	_set_state(
		State.RESOLVING
	)

	_begin_turn(c)

	await _wait(
		TURN_START_TIME
	)

	enemy_thinking.emit(
		c
	)

	await _wait(
		THINK_TIME
	)

	var choice: Dictionary = _enemy_choose(
		c
	)

	var skill: BattleSkill = (
		choice["skill"]
		as BattleSkill
	)

	var targets: Array = (
		choice["targets"]
		as Array
	)

	action_selected.emit(
		c,
		skill,
		targets
	)

	await _execute(
		c,
		skill,
		targets
	)

	# Energy Surge is a telegraphed setup move. Once it actually resolves,
	# force the boss's next turn to be the devastating HIGH ENERGY attack and
	# warn the player immediately while they still have a full turn to react.
	if (
		c.character_name == "twIST"
		and
		skill != null
		and
		skill.skill_id == BattleSkills.BOSS_SURGE
		and
		not _is_skill_rejected(skill)
	):
		boss_devastating_attack_pending = true
		notice.emit(
			"⚠ warning: twIST is charging a devastating attack! guard now!"
		)

	if (
		c.character_name == "twIST"
		and
		boss_devastating_attack_pending
		and
		skill != null
		and
		skill.skill_id == BattleSkills.BOSS_XRAY
	):
		boss_devastating_attack_pending = false

	turn_finished.emit(
		c
	)


func _tick_round_end() -> void:
	var everyone: Array[BattleCombatant] = []

	for c in encounter.allies:
		everyone.append(c)

	for c in encounter.enemies:
		everyone.append(c)

	for c in everyone:
		if not c.is_alive:
			continue

		for kind in c.tick_statuses():
			status_expired.emit(
				c,
				int(kind)
			)


func _check_battle_end() -> bool:
	if _protagonist_is_dead():
		_set_state(
			State.BATTLE_OVER
		)

		menu_updated.emit(
			"none",
			[],
			0
		)

		target_highlight.emit([])

		battle_lost.emit()
		battle_finished.emit(false)

		return true

	if _living_count(true) == 0:
		_store_room1_skill_counts()
		_store_room2_skill_counts()

		_set_state(
			State.BATTLE_OVER
		)

		menu_updated.emit(
			"none",
			[],
			0
		)

		target_highlight.emit([])

		battle_won.emit()
		battle_finished.emit(true)

		return true

	if _living_count(false) == 0:
		_set_state(
			State.BATTLE_OVER
		)

		menu_updated.emit(
			"none",
			[],
			0
		)

		target_highlight.emit([])

		battle_lost.emit()
		battle_finished.emit(false)

		return true

	return false


func _protagonist_is_dead() -> bool:
	if encounter == null:
		return false

	if encounter.allies.is_empty():
		return false

	var protagonist: BattleCombatant = (
		encounter.allies[0]
	)

	if protagonist == null:
		return true

	return not protagonist.is_alive


func _living_count(
	is_enemy_side: bool
) -> int:
	var n: int = 0

	for c in _side(
		is_enemy_side
	):
		if c.is_alive:
			n += 1

	return n


# =========================================================
# TARGETING
# =========================================================

func _get_revive_targets(
	actor: BattleCombatant
) -> Array[BattleCombatant]:
	var out: Array[BattleCombatant] = []

	if actor == null:
		return out

	for c in _side(
		actor.is_enemy
	):
		if c == null:
			continue

		if not c.is_alive:
			out.append(c)

	return out


func get_valid_targets(
	actor: BattleCombatant,
	skill: BattleSkill
) -> Array[BattleCombatant]:
	var out: Array[BattleCombatant] = []

	if skill == null or actor == null:
		return out

	if skill.effect_type == BattleSkill.EffectType.REVIVE:
		return _get_revive_targets(
			actor
		)

	match skill.target_mode:
		BattleSkill.TargetMode.SELF:
			if actor.is_alive:
				out.append(
					actor
				)

		BattleSkill.TargetMode.ONE_ENEMY, \
		BattleSkill.TargetMode.ALL_ENEMIES:
			for c in _side(
				not actor.is_enemy
			):
				if c.is_alive:
					out.append(c)

		BattleSkill.TargetMode.ONE_ALLY:
			for c in _side(
				actor.is_enemy
			):
				if c.is_alive:
					out.append(c)

	return out


func _target_is_still_valid(
	actor: BattleCombatant,
	skill: BattleSkill,
	target: BattleCombatant
) -> bool:
	if actor == null:
		return false

	if skill == null:
		return false

	if target == null:
		return false

	if skill.effect_type == BattleSkill.EffectType.REVIVE:
		return (
			not target.is_alive
			and
			not target.is_enemy == actor.is_enemy
		)

	var valid: Array[BattleCombatant] = (
		get_valid_targets(
			actor,
			skill
		)
	)

	return valid.has(target)


# =========================================================
# ENEMY AI
# =========================================================

func _enemy_choose(
	e: BattleCombatant
) -> Dictionary:
	var guard_skill: BattleSkill = BattleSkills.get_skill(
		BattleSkills.GUARD
	)

	var living_allies: Array[BattleCombatant] = []

	for ally in encounter.allies:
		if ally.is_alive:
			living_allies.append(ally)

	if living_allies.is_empty():
		return {
			"skill": null,
			"targets": []
		}

	# ---------------------------------------------------------
	# BOSS
	# ---------------------------------------------------------
	#
	# twIST has a deterministic attack pattern:
	#
	# 1  Normal
	# 2  Normal
	# 3  Energy Surge
	# 4  X-Ray
	# 5  Normal
	# 6  Gamma
	# 7  Normal
	# 8  Energy Surge
	# 9  X-Ray
	# 10 Normal
	# 11 Gamma
	# 12 Normal
	# 13 Energy Surge
	# 14 X-Ray
	# ...and so on.
	#
	# After the opening four turns, the repeating pattern is:
	# Normal -> Gamma -> Normal -> Surge -> X-Ray
	#
	# This block is deliberately BEFORE the generic guard roll so that
	# twIST's attack pattern cannot be interrupted by an accidental Guard.
	# ---------------------------------------------------------

	if e.character_name == "twIST":
		var surge: BattleSkill = BattleSkills.get_skill(
			BattleSkills.BOSS_SURGE
		)

		var gamma: BattleSkill = BattleSkills.get_skill(
			BattleSkills.BOSS_GAMMA
		)

		var xray: BattleSkill = BattleSkills.get_skill(
			BattleSkills.BOSS_XRAY
		)

		var crush: BattleSkill = BattleSkills.get_skill(
			BattleSkills.BOSS_CRUSH
		)

		var boss_turn: int = round_number

		# Turns 1 and 2: normal attack.
		if boss_turn <= 2:
			if crush != null:
				var normal_target: BattleCombatant = (
					_lowest_hp_target(
						living_allies
					)
				)

				if normal_target != null:
					return {
						"skill": crush,
						"targets": [normal_target]
					}

		# A successful Energy Surge always forces X-Ray on the
		# immediately following turn.
		if boss_devastating_attack_pending:
			if xray != null:
				var charged_target: BattleCombatant = (
					_lowest_hp_target(
						living_allies
					)
				)

				if charged_target != null:
					return {
						"skill": xray,
						"targets": [charged_target]
					}

		# Turn 3: Energy Surge.
		if boss_turn == 3:
			if surge != null:
				return {
					"skill": surge,
					"targets": [e]
				}

		# From turn 5 onward:
		#
		# step 0 = Normal
		# step 1 = Gamma
		# step 2 = Normal
		# step 3 = Surge
		# step 4 = X-Ray
		#
		# This repeats forever.
		if boss_turn >= 5:
			var pattern_step: int = (
				posmod(
					boss_turn - 5,
					5
				)
			)

			match pattern_step:
				0:
					if crush != null:
						var normal_target_late: BattleCombatant = (
							_lowest_hp_target(
								living_allies
							)
						)

						if normal_target_late != null:
							return {
								"skill": crush,
								"targets": [normal_target_late]
							}

				1:
					if gamma != null:
						return {
							"skill": gamma,
							"targets": living_allies
						}

				2:
					if crush != null:
						var normal_target_again: BattleCombatant = (
							_lowest_hp_target(
								living_allies
							)
						)

						if normal_target_again != null:
							return {
								"skill": crush,
								"targets": [normal_target_again]
							}

				3:
					if surge != null:
						return {
							"skill": surge,
							"targets": [e]
						}

				4:
					if xray != null:
						var pattern_xray_target: BattleCombatant = (
							_lowest_hp_target(
								living_allies
							)
						)

						if pattern_xray_target != null:
							return {
								"skill": xray,
								"targets": [pattern_xray_target]
							}

		# Safety fallback if a boss skill is unavailable.
		if crush != null:
			var fallback_target: BattleCombatant = (
				_lowest_hp_target(
					living_allies
				)
			)

			if fallback_target != null:
				return {
					"skill": crush,
					"targets": [fallback_target]
				}

	# ---------------------------------------------------------
	# GENERIC GUARD
	# ---------------------------------------------------------

	var guard_chance: float = e.ai_guard_chance

	if e.hp <= int(e.max_hp * 0.35):
		guard_chance += 0.08

	if guard_skill != null and rng.randf() < guard_chance:
		return {
			"skill": guard_skill,
			"targets": [e]
		}

	# ---------------------------------------------------------
	# VISIBLE
	# ---------------------------------------------------------

	if e.combat_class == BattleCombatant.CombatClass.VISIBLE:
		var red_ray: BattleSkill = BattleSkills.get_skill(
			BattleSkills.RED_RAY
		)

		var violet_flash: BattleSkill = BattleSkills.get_skill(
			BattleSkills.VIOLET_FLASH
		)

		var blue_shift: BattleSkill = BattleSkills.get_skill(
			BattleSkills.BLUE_SHIFT
		)

		var uv_cut: BattleSkill = BattleSkills.get_skill(
			BattleSkills.ULTRAVIOLET_CUT
		)

		if e.attack_skill_id == BattleSkills.BLUE_SHIFT:
			if (
				round_number == 1
				and
				blue_shift != null
				and
				_has_living_target_without_def_debuff(
					living_allies
				)
			):
				var shift_target: BattleCombatant = (
					_target_for_regular_enemy(
						living_allies,
						0.55
					)
				)

				if shift_target != null:
					return {
						"skill": blue_shift,
						"targets": [shift_target]
					}

			if (
				blue_shift != null
				and
				_has_living_target_without_def_debuff(
					living_allies
				)
				and
				rng.randf() < 0.48
			):
				var shift_target_later: BattleCombatant = (
					_target_for_regular_enemy(
						living_allies,
						0.65
					)
				)

				if shift_target_later != null:
					return {
						"skill": blue_shift,
						"targets": [shift_target_later]
					}

			if (
				uv_cut != null
				and
				rng.randf() < 0.25
			):
				var uv_target: BattleCombatant = (
					_target_for_regular_enemy(
						living_allies,
						0.70
					)
				)

				if uv_target != null:
					return {
						"skill": uv_cut,
						"targets": [uv_target]
					}

			if violet_flash != null:
				var violet_target: BattleCombatant = (
					_target_for_regular_enemy(
						living_allies,
						0.70
					)
				)

				if violet_target != null:
					return {
						"skill": violet_flash,
						"targets": [violet_target]
					}

		if (
			round_number == 1
			and
			red_ray != null
		):
			var first_ray_target: BattleCombatant = (
				_target_for_regular_enemy(
					living_allies,
					0.55
				)
			)

			if first_ray_target != null:
				return {
					"skill": red_ray,
					"targets": [first_ray_target]
				}

		if (
			blue_shift != null
			and
			_has_living_target_without_def_debuff(
				living_allies
			)
			and
			rng.randf() < 0.18
		):
			var shift_target_type1: BattleCombatant = (
				_target_for_regular_enemy(
					living_allies,
					0.65
				)
			)

			if shift_target_type1 != null:
				return {
					"skill": blue_shift,
					"targets": [shift_target_type1]
				}

		if (
			violet_flash != null
			and
			rng.randf() < 0.28
		):
			var flash_target: BattleCombatant = (
				_target_for_regular_enemy(
					living_allies,
					0.70
				)
			)

			if flash_target != null:
				return {
					"skill": violet_flash,
					"targets": [flash_target]
				}

		if red_ray != null:
			var red_target: BattleCombatant = (
				_target_for_regular_enemy(
					living_allies,
					0.70
				)
			)

			if red_target != null:
				return {
					"skill": red_ray,
					"targets": [red_target]
				}

	# ---------------------------------------------------------
	# LOW ENERGY
	# ---------------------------------------------------------

	if e.combat_class == BattleCombatant.CombatClass.LOW_ENERGY:
		var pulse: BattleSkill = BattleSkills.get_skill(
			BattleSkills.MICROWAVE_PULSE
		)

		var static_skill: BattleSkill = BattleSkills.get_skill(
			BattleSkills.RADIO_STATIC
		)

		var infrared_burn: BattleSkill = BattleSkills.get_skill(
			BattleSkills.INFRARED_BURN
		)

		if (
			round_number >= 2
			and
			pulse != null
			and
			living_allies.size() >= 2
			and
			rng.randf() < 0.46
		):
			return {
				"skill": pulse,
				"targets": living_allies
			}

		if (
			static_skill != null
			and
			_has_living_target_without_off_debuff(
				living_allies
			)
			and
			rng.randf() < 0.28
		):
			var static_target: BattleCombatant = (
				_highest_threat_target(
					living_allies
				)
			)

			if static_target != null:
				return {
					"skill": static_skill,
					"targets": [static_target]
				}

		if infrared_burn != null:
			var burn_target: BattleCombatant = (
				_target_for_regular_enemy(
					living_allies,
					0.72
				)
			)

			if burn_target != null:
				return {
					"skill": infrared_burn,
					"targets": [burn_target]
				}

	# ---------------------------------------------------------
	# HIGH ENERGY
	# ---------------------------------------------------------

	var gamma_type: BattleSkill = BattleSkills.get_skill(
		BattleSkills.GAMMA_RAY
	)

	var xray_type: BattleSkill = BattleSkills.get_skill(
		BattleSkills.XRAY_BURST
	)

	var cut_type: BattleSkill = BattleSkills.get_skill(
		BattleSkills.ULTRAVIOLET_CUT
	)

	if (
		round_number == 1
		and
		cut_type != null
	):
		var first_cut_target: BattleCombatant = (
			_target_for_regular_enemy(
				living_allies,
				0.60
			)
		)

		if first_cut_target != null:
			return {
				"skill": cut_type,
				"targets": [first_cut_target]
			}

	if (
		gamma_type != null
		and
		living_allies.size() >= 2
		and
		rng.randf() < 0.24
	):
		return {
			"skill": gamma_type,
			"targets": living_allies
		}

	if (
		xray_type != null
		and
		rng.randf() < 0.52
	):
		var high_xray_target: BattleCombatant = (
			_target_for_regular_enemy(
				living_allies,
				0.80
			)
		)

		if high_xray_target != null:
			return {
				"skill": xray_type,
				"targets": [high_xray_target]
			}

	if cut_type != null:
		var high_cut_target: BattleCombatant = (
			_target_for_regular_enemy(
				living_allies,
				0.80
			)
		)

		if high_cut_target != null:
			return {
				"skill": cut_type,
				"targets": [high_cut_target]
			}

	return {
		"skill": null,
		"targets": []
	}


# =========================================================
# AI TARGET HELPERS
# =========================================================

func _lowest_hp_target(
	valid: Array[BattleCombatant]
) -> BattleCombatant:
	if valid.is_empty():
		return null

	var best: BattleCombatant = null
	var best_hp: int = 2147483647

	for c in valid:
		if c == null:
			continue

		if not c.is_alive:
			continue

		if c.hp < best_hp:
			best_hp = c.hp
			best = c

	return best


func _has_living_target_without_def_debuff(
	valid: Array[BattleCombatant]
) -> bool:
	for c in valid:
		if c == null:
			continue

		if not c.is_alive:
			continue

		if c.defense_debuff_turns <= 0:
			return true

	return false


func _has_living_target_without_off_debuff(
	valid: Array[BattleCombatant]
) -> bool:
	for c in valid:
		if c == null:
			continue

		if not c.is_alive:
			continue

		if c.offense_debuff_turns <= 0:
			return true

	return false


func _highest_threat_target(
	valid: Array[BattleCombatant]
) -> BattleCombatant:
	if valid.is_empty():
		return null

	var best: BattleCombatant = null
	var best_score: float = -INF

	for c in valid:
		if c == null:
			continue

		if not c.is_alive:
			continue

		var score: float = 0.0

		score += float(c.lp) * 0.8
		score += float(c.hp) * 0.2

		for id in c.skill_ids:
			var skill: BattleSkill = BattleSkills.get_skill(id)

			if skill == null:
				continue

			if skill.effect_type == BattleSkill.EffectType.DAMAGE:
				score += skill.base_damage

		if (
			encounter != null
			and
			not encounter.allies.is_empty()
			and
			c == encounter.allies[0]
		):
			score += 4.0

		if score > best_score:
			best_score = score
			best = c

	return best


func _target_for_regular_enemy(
	valid: Array[BattleCombatant],
	prefer_low_hp_chance: float
) -> BattleCombatant:
	if valid.is_empty():
		return null

	if rng.randf() < prefer_low_hp_chance:
		var lowest: BattleCombatant = (
			_lowest_hp_target(
				valid
			)
		)

		if lowest != null:
			return lowest

	return valid[
		rng.randi_range(
			0,
			valid.size() - 1
		)
	]


func _default_target_picker(
	_actor: BattleCombatant,
	skill: BattleSkill,
	valid: Array[BattleCombatant]
) -> Array:
	var out: Array = []

	if (
		skill.needs_target_choice()
		and
		not valid.is_empty()
	):
		out.append(
			valid[
				rng.randi_range(
					0,
					valid.size() - 1
				)
			]
		)
	else:
		for c in valid:
			out.append(c)

	return out


# =========================================================
# RESOLUTION
# =========================================================

func _execute(
	actor: BattleCombatant,
	skill: BattleSkill,
	raw_targets: Array
) -> void:
	_set_state(
		State.RESOLVING
	)

	if skill == null:
		return

	var targets: Array[BattleCombatant] = []

	for t in raw_targets:
		var combatant_target: BattleCombatant = (
			t as BattleCombatant
		)

		if combatant_target == null:
			continue

		if not _target_is_still_valid(
			actor,
			skill,
			combatant_target
		):
			continue

		targets.append(
			combatant_target
		)

	if (
		skill.effect_type
		==
		BattleSkill.EffectType.REVIVE
		and
		targets.is_empty()
	):
		notice.emit(
			"no fallen ally"
		)

		return

	if skill.lp_cost > 0:
		if not actor.is_enemy:
			if not actor.can_afford(skill):
				notice.emit(
					"not enough lp"
				)

				return

			actor.spend_lp(
				skill.lp_cost
			)

	action_started.emit(
		actor,
		skill,
		targets
	)

	await _wait(
		WINDUP_TIME
	)

	if not actor.is_enemy:
		encounter.tracker.record(
			skill
		)

		_record_room1_skill(
			skill
		)

		_record_room2_skill(
			skill
		)

	if _is_skill_rejected(
		skill
	):
		await _resolve_rejected_skill(
			actor,
			skill,
			targets
		)

		return

	match skill.effect_type:
		BattleSkill.EffectType.GUARD:
			actor.is_guarding = true

			guard_applied.emit(
				actor
			)

		BattleSkill.EffectType.DAMAGE:
			await _resolve_damage(
				actor,
				skill,
				targets
			)

		BattleSkill.EffectType.HEAL:
			await _resolve_heal(
				actor,
				skill,
				targets
			)

		BattleSkill.EffectType.REVIVE:
			await _resolve_revive(
				actor,
				skill,
				targets
			)

		BattleSkill.EffectType.BUFF_DEFENSE:
			await _apply_status(
				actor,
				skill,
				targets,
				BattleCombatant.StatusKind.DEFENSE_BUFF,
				true
			)

		BattleSkill.EffectType.BUFF_OFFENSE:
			await _apply_status(
				actor,
				skill,
				targets,
				BattleCombatant.StatusKind.OFFENSE_BUFF,
				true
			)

		BattleSkill.EffectType.DEBUFF_DEFENSE:
			await _apply_status(
				actor,
				skill,
				targets,
				BattleCombatant.StatusKind.DEFENSE_DEBUFF,
				false
			)

		BattleSkill.EffectType.DEBUFF_OFFENSE:
			await _apply_status(
				actor,
				skill,
				targets,
				BattleCombatant.StatusKind.OFFENSE_DEBUFF,
				false
			)

	if (
		skill.self_hp_fraction > 0.0
		and
		actor.is_alive
	):
		var loss: int = (
			BattleRules.self_damage_amount(
				actor.hp,
				skill.self_hp_fraction
			)
		)

		if loss > 0:
			actor.take_damage(
				loss
			)

			self_damaged.emit(
				actor,
				loss
			)

			await _wait(
				HIT_GAP
			)

			if not actor.is_alive:
				combatant_defeated.emit(
					actor
				)

				await _wait(
					DEFEAT_TIME
				)

				if _protagonist_is_dead():
					_check_battle_end()
					return

	await _wait(
		AFTER_ACTION_TIME
	)


func _resolve_heal(
	actor: BattleCombatant,
	skill: BattleSkill,
	targets: Array[BattleCombatant]
) -> void:
	for t in targets:
		if not t.is_alive:
			continue

		var healed: int = t.heal(
			skill.heal_amount
		)

		heal_applied.emit(
			actor,
			t,
			healed
		)

		await _wait(
			HIT_GAP
		)


func _resolve_revive(
	actor: BattleCombatant,
	skill: BattleSkill,
	targets: Array[BattleCombatant]
) -> void:
	for t in targets:
		if t.is_alive:
			continue

		var restored: int = t.revive(
			skill.heal_amount
		)

		if restored <= 0:
			continue

		heal_applied.emit(
			actor,
			t,
			restored
		)

		notice.emit(
			"%s revived"
			% t.character_name
		)

		await _wait(
			HIT_GAP
		)


func _is_skill_rejected(
	skill: BattleSkill
) -> bool:
	if skill == null:
		return false

	if encounter == null:
		return false

	if encounter.encounter_id != BOSS_ENCOUNTER_ID:
		return false

	if rejected_skill_id.is_empty():
		return false

	return (
		skill.skill_id
		==
		rejected_skill_id
	)


func _resolve_rejected_skill(
	actor: BattleCombatant,
	skill: BattleSkill,
	targets: Array[BattleCombatant]
) -> void:
	notice.emit(
		"%s rejected"
		% skill.display_name
	)

	for t in targets:
		if not t.is_alive:
			continue

		impact.emit(
			actor,
			t,
			0,
			{
				"amount": 0,
				"repelled": true,
				"rejected": true,
				"hit_index": 0,
				"hit_count": 1
			}
		)

		await _wait(
			HIT_GAP
		)

	await _wait(
		AFTER_ACTION_TIME
	)


# =========================================================
# SKILL TRACKING
# =========================================================

func _record_room1_skill(
	skill: BattleSkill
) -> void:
	if skill == null:
		return

	if not _is_room1_battle():
		return

	if not skill.counts_for_tracker:
		return

	if skill.effect_type != BattleSkill.EffectType.DAMAGE:
		return

	var count: int = int(
		_room1_skill_counts.get(
			skill.skill_id,
			0
		)
	)

	_room1_skill_counts[
		skill.skill_id
	] = count + 1


func _record_room2_skill(
	skill: BattleSkill
) -> void:
	if skill == null:
		return

	if not _is_room2_battle():
		return

	if not skill.counts_for_tracker:
		return

	if skill.effect_type != BattleSkill.EffectType.DAMAGE:
		return

	var count: int = int(
		_room2_skill_counts.get(
			skill.skill_id,
			0
		)
	)

	_room2_skill_counts[
		skill.skill_id
	] = count + 1


func _is_room1_battle() -> bool:
	if encounter == null:
		return false

	if encounter.encounter_id == ROOM1_ENCOUNTER_ID:
		return true

	var active_id: String = (
		_get_active_encounter_id()
	)

	return (
		active_id == "traversal_enemy_01"
		or
		active_id == "traversal_enemy_02"
	)


func _is_room2_battle() -> bool:
	if encounter == null:
		return false

	return (
		encounter.encounter_id
		==
		ROOM2_ENCOUNTER_ID
	)


func _store_room1_skill_counts() -> void:
	if not _is_room1_battle():
		return

	if _room1_skill_counts.is_empty():
		return

	var totals: Dictionary = {}

	if get_tree().has_meta(
		ROOM1_COUNTS_META
	):
		var stored: Variant = (
			get_tree().get_meta(
				ROOM1_COUNTS_META
			)
		)

		if stored is Dictionary:
			totals = (
				stored as Dictionary
			)

	for key in _room1_skill_counts.keys():
		var skill_id: String = str(
			key
		)

		var old_count: int = int(
			totals.get(
				skill_id,
				0
			)
		)

		var new_count: int = int(
			_room1_skill_counts.get(
				skill_id,
				0
			)
		)

		totals[skill_id] = (
			old_count
			+
			new_count
		)

	get_tree().set_meta(
		ROOM1_COUNTS_META,
		totals
	)

	var most_used: String = (
		_most_used_skill(
			totals
		)
	)

	if not most_used.is_empty():
		get_tree().set_meta(
			ROOM1_MOST_USED_SKILL_META,
			most_used
		)


func _store_room2_skill_counts() -> void:
	if not _is_room2_battle():
		return

	if _room2_skill_counts.is_empty():
		return

	var totals: Dictionary = {}

	if get_tree().has_meta(
		ROOM2_COUNTS_META
	):
		var stored: Variant = (
			get_tree().get_meta(
				ROOM2_COUNTS_META
			)
		)

		if stored is Dictionary:
			totals = (
				stored as Dictionary
			)

	for key in _room2_skill_counts.keys():
		var skill_id: String = str(
			key
		)

		var old_count: int = int(
			totals.get(
				skill_id,
				0
			)
		)

		var new_count: int = int(
			_room2_skill_counts.get(
				skill_id,
				0
			)
		)

		totals[skill_id] = (
			old_count
			+
			new_count
		)

	get_tree().set_meta(
		ROOM2_COUNTS_META,
		totals
	)

	var most_used: String = (
		_most_used_skill(
			totals
		)
	)

	if not most_used.is_empty():
		get_tree().set_meta(
			BOSS_REJECTED_SKILL_META,
			most_used
		)


func _most_used_skill(
	totals: Dictionary
) -> String:
	var best_skill: String = ""
	var best_count: int = 0

	for key in totals.keys():
		var skill_id: String = str(
			key
		)

		var count: int = int(
			totals.get(
				skill_id,
				0
			)
		)

		if count > best_count:
			best_count = count
			best_skill = skill_id

	return best_skill


# =========================================================
# DAMAGE / EFFECT RESOLUTION
# =========================================================

func _resolve_damage(
	actor: BattleCombatant,
	skill: BattleSkill,
	targets: Array[BattleCombatant]
) -> void:
	for t in targets:
		if not t.is_alive:
			continue

		var hits: int = 1

		if skill.max_hits > 1:
			hits = BattleRules.roll_hit_count(
				skill,
				rng
			)

		var resistance: float = 1.0

		if (
			t.is_enemy
			and
			not actor.is_enemy
		):
			resistance = (
				encounter.adaptation
				.get_enemy_multiplier(
					t.character_name,
					skill.skill_id
				)
			)

		for i in hits:
			if not t.is_alive:
				break

			var info: Dictionary = (
				BattleRules.calculate_hit(
					actor,
					t,
					skill,
					resistance
				)
			)

			var amount: int = int(
				info["amount"]
			)

			t.take_damage(
				amount
			)

			info["hit_index"] = i
			info["hit_count"] = hits

			impact.emit(
				actor,
				t,
				amount,
				info
			)

			await _wait(
				HIT_GAP
			)

		if not t.is_alive:
			combatant_defeated.emit(
				t
			)

			await _wait(
				DEFEAT_TIME
			)

			if _protagonist_is_dead():
				_check_battle_end()
				return


func _apply_status(
	actor: BattleCombatant,
	skill: BattleSkill,
	targets: Array[BattleCombatant],
	kind: BattleCombatant.StatusKind,
	is_buff: bool
) -> void:
	var turns: int = (
		skill.duration_turns
	)

	if turns <= 0:
		turns = BattleSkills.STATUS_DURATION

	for t in targets:
		if not t.is_alive:
			continue

		t.apply_status(
			kind,
			turns
		)

		if is_buff:
			buff_applied.emit(
				actor,
				t,
				int(kind)
			)
		else:
			debuff_applied.emit(
				actor,
				t,
				int(kind)
			)

		await _wait(
			HIT_GAP
		)


# =========================================================
# PLAYER INPUT
# =========================================================

func _unhandled_input(
	event: InputEvent
) -> void:
	if encounter == null:
		return

	if not (
		event
		is InputEventKey
	):
		return

	var key: InputEventKey = (
		event as InputEventKey
	)

	if not key.pressed or key.echo:
		return

	var k: int = key.keycode

	var prev: bool = (
		k == KEY_W
		or
		k == KEY_UP
	)

	var next: bool = (
		k == KEY_S
		or
		k == KEY_DOWN
	)

	var left: bool = (
		k == KEY_A
		or
		k == KEY_LEFT
	)

	var right: bool = (
		k == KEY_D
		or
		k == KEY_RIGHT
	)

	var confirm: bool = (
		k == KEY_ENTER
		or
		k == KEY_KP_ENTER
		or
		k == KEY_SPACE
	)

	var cancel: bool = (
		k == KEY_ESCAPE
		or
		k == KEY_BACKSPACE
	)

	match state:
		State.ACTION_MENU:
			if prev:
				_menu_index = posmod(
					_menu_index - 1,
					_action_labels.size()
				)

				_emit_action_menu()

			elif next:
				_menu_index = posmod(
					_menu_index + 1,
					_action_labels.size()
				)

				_emit_action_menu()

			elif confirm:
				_confirm_action()

		State.SKILL_MENU:
			if prev:
				if not _skill_menu.is_empty():
					_skill_index = posmod(
						_skill_index - 1,
						_skill_menu.size()
					)

					_emit_skill_menu()

			elif next:
				if not _skill_menu.is_empty():
					_skill_index = posmod(
						_skill_index + 1,
						_skill_menu.size()
					)

					_emit_skill_menu()

			elif confirm:
				_confirm_skill()

			elif cancel:
				_open_action_menu()

		State.TARGET_MENU:
			if prev or left:
				_move_target(-1)

			elif next or right:
				_move_target(1)

			elif confirm:
				_confirm_target()

			elif cancel:
				_back_from_target()


func _open_action_menu() -> void:
	_set_state(
		State.ACTION_MENU
	)

	_emit_action_menu()


func _emit_action_menu() -> void:
	var entries: Array = []

	for i in _action_labels.size():
		entries.append(
			{
				"text": _action_labels[i],
				"sub": "",
				"enabled": true
			}
		)

	if current.skill_ids.is_empty():
		entries[1]["enabled"] = false

	menu_updated.emit(
		"action",
		entries,
		_menu_index
	)

	target_highlight.emit([])


func _confirm_action() -> void:
	match _menu_index:
		0:
			_begin_target_select(
				BattleSkills.get_skill(
					current.attack_skill_id
				),
				State.ACTION_MENU
			)

		1:
			if current.skill_ids.is_empty():
				notice.emit(
					"no skills"
				)

				return

			_skill_menu.clear()

			for id in current.skill_ids:
				var s: BattleSkill = BattleSkills.get_skill(
					id
				)

				if s != null:
					_skill_menu.append(
						s
					)

			if _skill_menu.is_empty():
				notice.emit(
					"no valid skills"
				)

				return

			_skill_index = clampi(
				_skill_index,
				0,
				_skill_menu.size() - 1
			)

			_set_state(
				State.SKILL_MENU
			)

			_emit_skill_menu()

		2:
			var guard_skill: BattleSkill = (
				BattleSkills.get_skill(
					BattleSkills.GUARD
				)
			)

			if guard_skill != null:
				_decide(
					guard_skill,
					[current]
				)


func _emit_skill_menu() -> void:
	var entries: Array = []

	for s in _skill_menu:
		var enabled: bool = (
			current.can_afford(s)
		)

		entries.append(
			{
				"text": s.display_name,
				"sub": "%d lp" % s.lp_cost,
				"desc": s.describe(),
				"skill_id": s.skill_id,
				"enabled": enabled
			}
		)

	menu_updated.emit(
		"skill",
		entries,
		_skill_index
	)

	target_highlight.emit([])


func _confirm_skill() -> void:
	if _skill_menu.is_empty():
		notice.emit(
			"no skills"
		)

		return

	var s: BattleSkill = (
		_skill_menu[
			_skill_index
		]
	)

	if not current.can_afford(s):
		notice.emit(
			"not enough lp"
		)

		return

	if s.effect_type == BattleSkill.EffectType.REVIVE:
		var revive_targets: Array[BattleCombatant] = (
			_get_revive_targets(
				current
			)
		)

		if revive_targets.is_empty():
			notice.emit(
				"no fallen ally"
			)

			return

		_begin_target_select(
			s,
			State.SKILL_MENU
		)

		return

	_begin_target_select(
		s,
		State.SKILL_MENU
	)


func _begin_target_select(
	skill: BattleSkill,
	return_to: State
) -> void:
	_pending_skill = skill
	_target_return = return_to

	var valid: Array[BattleCombatant] = []

	if (
		skill != null
		and
		skill.effect_type == BattleSkill.EffectType.REVIVE
	):
		valid = _get_revive_targets(
			current
		)
	else:
		valid = get_valid_targets(
			current,
			skill
		)

	if valid.is_empty():
		if (
			skill != null
			and
			skill.effect_type == BattleSkill.EffectType.REVIVE
		):
			notice.emit(
				"no fallen ally"
			)
		else:
			notice.emit(
				"no valid target"
			)

		return

	if skill.target_mode == BattleSkill.TargetMode.SELF:
		_decide(
			skill,
			[current]
		)

		return

	_target_list = valid
	_target_index = 0
	_target_all = (
		not skill.needs_target_choice()
	)

	_set_state(
		State.TARGET_MENU
	)

	_emit_target_menu()


func _emit_target_menu() -> void:
	var entries: Array = []

	if _pending_skill == null:
		return

	if _target_all:
		entries.append(
			{
				"text": _pending_skill.target_label(),
				"sub": "",
				"enabled": true
			}
		)

		menu_updated.emit(
			"target",
			entries,
			0
		)

		var all: Array = []

		for c in _target_list:
			all.append(c)

		target_highlight.emit(
			all
		)

		return

	for c in _target_list:
		var subtitle: String = (
			"%d/%d"
			%
			[
				c.hp,
				c.max_hp
			]
		)

		if not c.is_alive:
			subtitle = "DOWN"
		elif (
			_pending_skill != null
			and
			_pending_skill.effect_type
			==
			BattleSkill.EffectType.DAMAGE
		):
			var matchup: String = (
				_target_matchup_label(
					c,
					_pending_skill
				)
			)

			if not matchup.is_empty():
				subtitle += "   " + matchup

		entries.append(
			{
				"text": c.character_name,
				"sub": subtitle,
				"enabled": true
			}
		)

	menu_updated.emit(
		"target",
		entries,
		_target_index
	)

	if (
		_target_index >= 0
		and
		_target_index < _target_list.size()
	):
		target_highlight.emit(
			[
				_target_list[
					_target_index
				]
			]
		)
	else:
		target_highlight.emit([])


func _target_matchup_label(
	target: BattleCombatant,
	skill: BattleSkill
) -> String:
	if target == null or skill == null:
		return ""

	if skill.effect_type != BattleSkill.EffectType.DAMAGE:
		return ""

	if (
		encounter != null
		and
		encounter.encounter_id == BOSS_ENCOUNTER_ID
		and
		rejected_skill_id == skill.skill_id
	):
		return "REJECTED"

	var resistance: float = 1.0

	if (
		target.is_enemy
		and
		not current.is_enemy
		and
		encounter != null
	):
		resistance = (
			encounter.adaptation.get_enemy_multiplier(
				target.character_name,
				skill.skill_id
			)
		)

	if resistance < 1.0:
		return "RESIST"

	var class_mult: float = (
		BattleRules.skill_class_multiplier(
			current,
			target,
			skill
		)
	)

	if class_mult > 1.0:
		return "WEAK"

	return ""


func _move_target(
	step: int
) -> void:
	if _target_all:
		return

	if _target_list.is_empty():
		return

	_target_index = posmod(
		_target_index + step,
		_target_list.size()
	)

	_emit_target_menu()


func _confirm_target() -> void:
	if _target_list.is_empty():
		return

	if (
		_target_index < 0
		or
		_target_index >= _target_list.size()
	):
		return

	var chosen_target: BattleCombatant = (
		_target_list[
			_target_index
		]
	)

	if _pending_skill == null:
		return

	if not _target_is_still_valid(
		current,
		_pending_skill,
		chosen_target
	):
		notice.emit(
			"target no longer valid"
		)

		var refreshed: Array[BattleCombatant] = []

		if (
			_pending_skill.effect_type
			==
			BattleSkill.EffectType.REVIVE
		):
			refreshed = _get_revive_targets(
				current
			)
		else:
			refreshed = get_valid_targets(
				current,
				_pending_skill
			)

		if refreshed.is_empty():
			if (
				_pending_skill.effect_type
				==
				BattleSkill.EffectType.REVIVE
			):
				notice.emit(
					"no fallen ally"
				)
			else:
				notice.emit(
					"no valid target"
				)

			_back_from_target()
			return

		_target_list = refreshed
		_target_index = 0
		_emit_target_menu()
		return

	var targets: Array = []

	if _target_all:
		for c in _target_list:
			targets.append(c)
	else:
		targets.append(
			chosen_target
		)

	_decide(
		_pending_skill,
		targets
	)


func _back_from_target() -> void:
	if _target_return == State.SKILL_MENU:
		_set_state(
			State.SKILL_MENU
		)

		_emit_skill_menu()
	else:
		_open_action_menu()


func _decide(
	skill: BattleSkill,
	targets: Array
) -> void:
	_decided.emit(
		{
			"skill": skill,
			"targets": targets
		}
	)
