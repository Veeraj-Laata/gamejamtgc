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

enum State { NONE, ACTION_MENU, SKILL_MENU, TARGET_MENU, RESOLVING, BATTLE_OVER }

# ---- presentation hooks ----
signal battle_started(encounter: BattleEncounter)
signal round_started(round_number: int)
signal turn_started(combatant: BattleCombatant)
signal guard_cleared(combatant: BattleCombatant)
signal enemy_thinking(combatant: BattleCombatant)
signal action_selected(combatant: BattleCombatant, skill: BattleSkill, targets: Array)
signal action_started(combatant: BattleCombatant, skill: BattleSkill, targets: Array)
signal impact(combatant: BattleCombatant, target: BattleCombatant, amount: int, info: Dictionary)
signal heal_applied(combatant: BattleCombatant, target: BattleCombatant, amount: int)
signal buff_applied(combatant: BattleCombatant, target: BattleCombatant, kind: int)
signal debuff_applied(combatant: BattleCombatant, target: BattleCombatant, kind: int)
signal guard_applied(combatant: BattleCombatant)
signal self_damaged(combatant: BattleCombatant, amount: int)
signal combatant_defeated(combatant: BattleCombatant)
signal status_expired(combatant: BattleCombatant, kind: int)
signal turn_finished(combatant: BattleCombatant)
signal battle_won
signal battle_lost
signal battle_finished(victory: bool)

# ---- menu / feedback for the UI ----
signal menu_updated(kind: String, entries: Array, selected: int)
signal target_highlight(targets: Array)
signal notice(text: String)
signal state_changed(new_state: int)

signal _decided(choice: Dictionary)

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

var encounter: BattleEncounter = null
var state: State = State.NONE
var round_number: int = 0
var current: BattleCombatant = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Replaceable enemy targeting. Signature: (actor, skill, valid_targets) -> Array
var target_picker: Callable = Callable()

var _action_labels: Array[String] = ["attack", "skills", "guard"]
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

func start_battle(p_encounter: BattleEncounter) -> void:
	encounter = p_encounter
	rng.randomize()
	round_number = 0
	_set_state(State.NONE)
	battle_started.emit(encounter)
	_run_battle()


func _run_battle() -> void:
	await _wait(INTRO_TIME)
	while state != State.BATTLE_OVER:
		round_number += 1
		round_started.emit(round_number)
		await _wait(ROUND_TIME)

		for ally in _snapshot(false):
			if state == State.BATTLE_OVER:
				return
			if not ally.is_alive:
				continue
			await _take_player_turn(ally)
			if _check_battle_end():
				return

		for enemy in _snapshot(true):
			if state == State.BATTLE_OVER:
				return
			if not enemy.is_alive:
				continue
			await _take_enemy_turn(enemy)
			if _check_battle_end():
				return

		_tick_round_end()


func _snapshot(is_enemy_side: bool) -> Array[BattleCombatant]:
	var out: Array[BattleCombatant] = []
	for c in _side(is_enemy_side):
		out.append(c)
	return out


func _side(is_enemy_side: bool) -> Array[BattleCombatant]:
	if is_enemy_side:
		return encounter.enemies
	return encounter.allies


func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(int(new_state))


func _wait(seconds: float) -> void:
	var t: float = seconds * beat_scale
	if t <= 0.0:
		return
	await get_tree().create_timer(t).timeout


# =========================================================
# TURNS
# =========================================================

func _begin_turn(c: BattleCombatant) -> void:
	current = c
	if c.is_guarding:
		c.clear_guard()
		guard_cleared.emit(c)
	turn_started.emit(c)


func _take_player_turn(c: BattleCombatant) -> void:
	_set_state(State.RESOLVING)
	_begin_turn(c)
	await _wait(TURN_START_TIME)

	_menu_index = 0
	_open_action_menu()
	var choice: Dictionary = await _decided

	_set_state(State.RESOLVING)
	menu_updated.emit("none", [], 0)
	target_highlight.emit([])

	var skill: BattleSkill = choice["skill"] as BattleSkill
	var targets: Array = choice["targets"] as Array
	action_selected.emit(c, skill, targets)
	await _execute(c, skill, targets)
	turn_finished.emit(c)


func _take_enemy_turn(c: BattleCombatant) -> void:
	_set_state(State.RESOLVING)
	_begin_turn(c)
	await _wait(TURN_START_TIME)

	enemy_thinking.emit(c)
	await _wait(THINK_TIME)

	var choice: Dictionary = _enemy_choose(c)
	var skill: BattleSkill = choice["skill"] as BattleSkill
	var targets: Array = choice["targets"] as Array
	action_selected.emit(c, skill, targets)
	await _execute(c, skill, targets)
	turn_finished.emit(c)


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
			status_expired.emit(c, int(kind))


func _check_battle_end() -> bool:
	if _living_count(true) == 0:
		_set_state(State.BATTLE_OVER)
		menu_updated.emit("none", [], 0)
		target_highlight.emit([])
		battle_won.emit()
		battle_finished.emit(true)
		return true
	if _living_count(false) == 0:
		_set_state(State.BATTLE_OVER)
		menu_updated.emit("none", [], 0)
		target_highlight.emit([])
		battle_lost.emit()
		battle_finished.emit(false)
		return true
	return false


func _living_count(is_enemy_side: bool) -> int:
	var n: int = 0
	for c in _side(is_enemy_side):
		if c.is_alive:
			n += 1
	return n


# =========================================================
# TARGETING (single source of truth for target validation)
# =========================================================

func get_valid_targets(actor: BattleCombatant, skill: BattleSkill) -> Array[BattleCombatant]:
	var out: Array[BattleCombatant] = []
	match skill.target_mode:
		BattleSkill.TargetMode.SELF:
			out.append(actor)
		BattleSkill.TargetMode.ONE_ENEMY, BattleSkill.TargetMode.ALL_ENEMIES:
			for c in _side(not actor.is_enemy):
				if c.is_alive:
					out.append(c)
		BattleSkill.TargetMode.ONE_ALLY:
			for c in _side(actor.is_enemy):
				if c.is_alive:
					out.append(c)
	return out


# =========================================================
# ENEMY AI (same skills, same rules)
# =========================================================

func _enemy_choose(e: BattleCombatant) -> Dictionary:
	var guard_skill: BattleSkill = BattleSkills.get_skill(BattleSkills.GUARD)
	if e.ai_guard_chance > 0.0 and rng.randf() < e.ai_guard_chance:
		return {"skill": guard_skill, "targets": [e]}

	var usable: Array[BattleSkill] = []
	for id in e.skill_ids:
		var s: BattleSkill = BattleSkills.get_skill(id)
		if s == null or not e.can_afford(s):
			continue
		if get_valid_targets(e, s).is_empty():
			continue
		usable.append(s)

	var chosen: BattleSkill = null
	if not usable.is_empty() and rng.randf() < 0.6:
		chosen = usable[rng.randi_range(0, usable.size() - 1)]
	else:
		chosen = BattleSkills.get_skill(e.attack_skill_id)

	var valid: Array[BattleCombatant] = get_valid_targets(e, chosen)
	var picked: Array = []
	if target_picker.is_valid():
		picked = target_picker.call(e, chosen, valid) as Array
	else:
		picked = _default_target_picker(e, chosen, valid)
	return {"skill": chosen, "targets": picked}


func _default_target_picker(_actor: BattleCombatant, skill: BattleSkill, valid: Array[BattleCombatant]) -> Array:
	var out: Array = []
	if skill.needs_target_choice() and not valid.is_empty():
		out.append(valid[rng.randi_range(0, valid.size() - 1)])
	else:
		for c in valid:
			out.append(c)
	return out


# =========================================================
# RESOLUTION
# =========================================================

func _execute(actor: BattleCombatant, skill: BattleSkill, raw_targets: Array) -> void:
	_set_state(State.RESOLVING)

	var targets: Array[BattleCombatant] = []
	for t in raw_targets:
		targets.append(t as BattleCombatant)

	if skill.lp_cost > 0:
		if not actor.can_afford(skill):
			return
		actor.spend_lp(skill.lp_cost)

	action_started.emit(actor, skill, targets)
	await _wait(WINDUP_TIME)

	if not actor.is_enemy:
		encounter.tracker.record(skill)

	match skill.effect_type:
		BattleSkill.EffectType.GUARD:
			actor.is_guarding = true
			guard_applied.emit(actor)
		BattleSkill.EffectType.DAMAGE:
			await _resolve_damage(actor, skill, targets)
		BattleSkill.EffectType.HEAL:
			for t in targets:
				if not t.is_alive:
					continue
				var healed: int = t.heal(skill.heal_amount)
				heal_applied.emit(actor, t, healed)
				await _wait(HIT_GAP)
		BattleSkill.EffectType.BUFF_DEFENSE:
			await _apply_status(actor, skill, targets, BattleCombatant.StatusKind.DEFENSE_BUFF, true)
		BattleSkill.EffectType.BUFF_OFFENSE:
			await _apply_status(actor, skill, targets, BattleCombatant.StatusKind.OFFENSE_BUFF, true)
		BattleSkill.EffectType.DEBUFF_DEFENSE:
			await _apply_status(actor, skill, targets, BattleCombatant.StatusKind.DEFENSE_DEBUFF, false)
		BattleSkill.EffectType.DEBUFF_OFFENSE:
			await _apply_status(actor, skill, targets, BattleCombatant.StatusKind.OFFENSE_DEBUFF, false)

	# self damage happens AFTER the attack resolved, from CURRENT hp
	if skill.self_hp_fraction > 0.0 and actor.is_alive:
		var loss: int = BattleRules.self_damage_amount(actor.hp, skill.self_hp_fraction)
		if loss > 0:
			actor.take_damage(loss)
			self_damaged.emit(actor, loss)
			await _wait(HIT_GAP)
			if not actor.is_alive:
				combatant_defeated.emit(actor)
				await _wait(DEFEAT_TIME)

	await _wait(AFTER_ACTION_TIME)


func _resolve_damage(actor: BattleCombatant, skill: BattleSkill, targets: Array[BattleCombatant]) -> void:
	for t in targets:
		if not t.is_alive:
			continue

		var hits: int = 1
		if skill.max_hits > 1:
			hits = BattleRules.roll_hit_count(skill, rng)

		var resistance: float = 1.0
		if t.is_enemy and not actor.is_enemy:
			resistance = encounter.adaptation.get_multiplier(skill.skill_id)

		for i in hits:
			if not t.is_alive:
				break
			var info: Dictionary = BattleRules.calculate_hit(actor, t, skill, resistance)
			var amount: int = int(info["amount"])
			t.take_damage(amount)
			info["hit_index"] = i
			info["hit_count"] = hits
			impact.emit(actor, t, amount, info)
			await _wait(HIT_GAP)

		if not t.is_alive:
			combatant_defeated.emit(t)
			await _wait(DEFEAT_TIME)


func _apply_status(
	actor: BattleCombatant,
	skill: BattleSkill,
	targets: Array[BattleCombatant],
	kind: BattleCombatant.StatusKind,
	is_buff: bool
) -> void:
	var turns: int = skill.duration_turns
	if turns <= 0:
		turns = BattleSkills.STATUS_DURATION
	for t in targets:
		if not t.is_alive:
			continue
		t.apply_status(kind, turns)
		if is_buff:
			buff_applied.emit(actor, t, int(kind))
		else:
			debuff_applied.emit(actor, t, int(kind))
		await _wait(HIT_GAP)


# =========================================================
# PLAYER INPUT
# =========================================================

func _unhandled_input(event: InputEvent) -> void:
	if encounter == null:
		return
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return

	var k: int = key.keycode
	var prev: bool = k == KEY_W or k == KEY_UP
	var next: bool = k == KEY_S or k == KEY_DOWN
	var left: bool = k == KEY_A or k == KEY_LEFT
	var right: bool = k == KEY_D or k == KEY_RIGHT
	var confirm: bool = k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE
	var cancel: bool = k == KEY_ESCAPE or k == KEY_BACKSPACE

	match state:
		State.ACTION_MENU:
			if prev:
				_menu_index = posmod(_menu_index - 1, _action_labels.size())
				_emit_action_menu()
			elif next:
				_menu_index = posmod(_menu_index + 1, _action_labels.size())
				_emit_action_menu()
			elif confirm:
				_confirm_action()
		State.SKILL_MENU:
			if prev:
				_skill_index = posmod(_skill_index - 1, _skill_menu.size())
				_emit_skill_menu()
			elif next:
				_skill_index = posmod(_skill_index + 1, _skill_menu.size())
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
	_set_state(State.ACTION_MENU)
	_emit_action_menu()


func _emit_action_menu() -> void:
	var entries: Array = []
	for i in _action_labels.size():
		entries.append({"text": _action_labels[i], "sub": "", "enabled": true})
	if current.skill_ids.is_empty():
		entries[1]["enabled"] = false
	menu_updated.emit("action", entries, _menu_index)
	target_highlight.emit([])


func _confirm_action() -> void:
	match _menu_index:
		0:
			_begin_target_select(BattleSkills.get_skill(current.attack_skill_id), State.ACTION_MENU)
		1:
			if current.skill_ids.is_empty():
				notice.emit("no skills")
				return
			_skill_menu.clear()
			for id in current.skill_ids:
				var s: BattleSkill = BattleSkills.get_skill(id)
				if s != null:
					_skill_menu.append(s)
			_skill_index = 0
			_set_state(State.SKILL_MENU)
			_emit_skill_menu()
		2:
			_decide(BattleSkills.get_skill(BattleSkills.GUARD), [current])


func _emit_skill_menu() -> void:
	var entries: Array = []
	for s in _skill_menu:
		entries.append({
			"text": s.display_name,
			"sub": "%d lp" % s.lp_cost,
			"desc": s.describe(),
			"enabled": current.can_afford(s)
		})
	menu_updated.emit("skill", entries, _skill_index)
	target_highlight.emit([])


func _confirm_skill() -> void:
	var s: BattleSkill = _skill_menu[_skill_index]
	if not current.can_afford(s):
		notice.emit("not enough lp")
		return
	_begin_target_select(s, State.SKILL_MENU)


func _begin_target_select(skill: BattleSkill, return_to: State) -> void:
	_pending_skill = skill
	_target_return = return_to
	var valid: Array[BattleCombatant] = get_valid_targets(current, skill)
	if valid.is_empty():
		notice.emit("no valid target")
		return

	if skill.target_mode == BattleSkill.TargetMode.SELF:
		_decide(skill, [current])
		return

	_target_list = valid
	_target_index = 0
	_target_all = not skill.needs_target_choice()
	_set_state(State.TARGET_MENU)
	_emit_target_menu()


func _emit_target_menu() -> void:
	var entries: Array = []
	if _target_all:
		entries.append({"text": _pending_skill.target_label(), "sub": "", "enabled": true})
		menu_updated.emit("target", entries, 0)
		var all: Array = []
		for c in _target_list:
			all.append(c)
		target_highlight.emit(all)
		return
	for c in _target_list:
		entries.append({
			"text": c.character_name,
			"sub": "%d/%d" % [c.hp, c.max_hp],
			"enabled": true
		})
	menu_updated.emit("target", entries, _target_index)
	target_highlight.emit([_target_list[_target_index]])


func _move_target(step: int) -> void:
	if _target_all:
		return
	_target_index = posmod(_target_index + step, _target_list.size())
	_emit_target_menu()


func _confirm_target() -> void:
	var targets: Array = []
	if _target_all:
		for c in _target_list:
			targets.append(c)
	else:
		targets.append(_target_list[_target_index])
	_decide(_pending_skill, targets)


func _back_from_target() -> void:
	if _target_return == State.SKILL_MENU:
		_set_state(State.SKILL_MENU)
		_emit_skill_menu()
	else:
		_open_action_menu()


func _decide(skill: BattleSkill, targets: Array) -> void:
	_decided.emit({"skill": skill, "targets": targets})
