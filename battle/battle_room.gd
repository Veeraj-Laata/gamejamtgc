extends Node3D
## Root script for battle_room.tscn.
## Bridges BattleCombatant data to 3D actors, builds the stage and UI, and wires
## controller signals to presentation. No combat rules in here.
##
## Setup: select the root node "battle_room", clear its old inline script and
## attach this file. The old "BattleUI" node and the stray "Label" are removed
## automatically at runtime.

enum EncounterKind { TUTORIAL, FULL_PARTY_TEST, NORMAL_ONE_ENEMY, BOSS }

@export var encounter_kind: EncounterKind = EncounterKind.FULL_PARTY_TEST

var encounter: BattleEncounter = null
var controller: BattleController = null
var stage: BattleStage = null
var ui: BattleUI = null

var actors: Dictionary = {}       # combatant instance id -> BattleActor3D
var _finished: bool = false

# fallback spawn positions if a Marker3D is missing (from the technical spec)
const FALLBACK_ALLY: Array[Vector3] = [Vector3(-4, 0, 0), Vector3(-5, 0, 2), Vector3(-5, 0, -2)]
const FALLBACK_ENEMY: Array[Vector3] = [Vector3(4, 0, 0), Vector3(5, 0, -2)]


func _ready() -> void:
	_remove_old_placeholders()
	encounter = _make_encounter()

	var ally_center: Vector3 = Vector3.ZERO
	var enemy_center: Vector3 = Vector3.ZERO
	var centers: Array[Vector3] = _spawn_actors()
	ally_center = centers[0]
	enemy_center = centers[1]

	_build_stage(ally_center, enemy_center)

	controller = BattleController.new()
	controller.name = "BattleController"
	add_child(controller)

	ui = BattleUI.new()
	ui.name = "BattleUI"
	add_child(ui)
	ui.bind(controller, Callable(self, "get_screen_anchor"))

	_connect_presentation()
	controller.start_battle(encounter)


func _remove_old_placeholders() -> void:
	var old_ui: Node = get_node_or_null("BattleUI")
	if old_ui != null:
		remove_child(old_ui)
		old_ui.free()
	var old_label: Node = get_node_or_null("Label")
	if old_label != null:
		remove_child(old_label)
		old_label.free()


func _make_encounter() -> BattleEncounter:
	match encounter_kind:
		EncounterKind.TUTORIAL:
			return BattleEncounter.tutorial()
		EncounterKind.NORMAL_ONE_ENEMY:
			return BattleEncounter.normal_battle(1)
		EncounterKind.BOSS:
			return BattleEncounter.boss_battle()
		_:
			return BattleEncounter.full_party_test()


# =========================================================
# ACTOR SPAWNING
# =========================================================

func _holder(path: String, fallback_name: String) -> Node3D:
	var n: Node3D = get_node_or_null(path) as Node3D
	if n != null:
		return n
	var created: Node3D = Node3D.new()
	created.name = fallback_name
	add_child(created)
	return created


func _marker_position(kind: String, index: int) -> Vector3:
	var m: Node3D = get_node_or_null("SpawnPoints/%s_%d" % [kind, index]) as Node3D
	if m != null:
		return m.global_position
	if kind == "Ally":
		return FALLBACK_ALLY[mini(index, FALLBACK_ALLY.size() - 1)]
	return FALLBACK_ENEMY[mini(index, FALLBACK_ENEMY.size() - 1)]


## returns [ally_center, enemy_center]
func _spawn_actors() -> Array[Vector3]:
	var ally_holder: Node3D = _holder("BattleActors/AllyActors", "AllyActors")
	var enemy_holder: Node3D = _holder("BattleActors/EnemyActors", "EnemyActors")
	for child in ally_holder.get_children():
		child.queue_free()
	for child in enemy_holder.get_children():
		child.queue_free()

	var ally_positions: Array[Vector3] = []
	for i in encounter.allies.size():
		ally_positions.append(_marker_position("Ally", i))

	var enemy_positions: Array[Vector3] = []
	if encounter.enemies.size() == 1:
		# a lone enemy stands between the two enemy markers
		enemy_positions.append((_marker_position("Enemy", 0) + _marker_position("Enemy", 1)) * 0.5)
	else:
		for i in encounter.enemies.size():
			enemy_positions.append(_marker_position("Enemy", i))

	var ally_center: Vector3 = _average(ally_positions)
	var enemy_center: Vector3 = _average(enemy_positions)
	var to_enemy: Vector3 = (enemy_center - ally_center)
	to_enemy.y = 0.0
	to_enemy = to_enemy.normalized()

	for i in encounter.allies.size():
		_spawn_one(encounter.allies[i], false, i, ally_positions[i], to_enemy, ally_holder)
	for i in encounter.enemies.size():
		_spawn_one(encounter.enemies[i], true, i, enemy_positions[i], -to_enemy, enemy_holder)

	var out: Array[Vector3] = [ally_center, enemy_center]
	return out


func _spawn_one(c: BattleCombatant, is_enemy: bool, index: int, pos: Vector3, facing: Vector3, holder: Node3D) -> void:
	var a: BattleActor3D = BattleActor3D.new()
	holder.add_child(a)
	a.global_position = pos
	a.forward = facing
	a.setup(c, is_enemy, index)
	actors[c.get_instance_id()] = a


func _average(points: Array[Vector3]) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	var sum: Vector3 = Vector3.ZERO
	for p in points:
		sum += p
	return sum / float(points.size())


func _actor(c: BattleCombatant) -> BattleActor3D:
	return actors.get(c.get_instance_id()) as BattleActor3D


# =========================================================
# STAGE
# =========================================================

func _build_stage(ally_center: Vector3, enemy_center: Vector3) -> void:
	var stage_node: Node = get_node_or_null("battlestage")
	if stage_node == null:
		stage_node = self

	var cam: Camera3D = stage_node.find_child("BattleCamera", true, false) as Camera3D
	if cam == null:
		cam = Camera3D.new()
		cam.name = "BattleCamera"
		add_child(cam)

	var env: WorldEnvironment = stage_node.find_child("BattleEnvironment", true, false) as WorldEnvironment
	if env == null:
		env = WorldEnvironment.new()
		env.name = "BattleEnvironment"
		add_child(env)

	var ground: MeshInstance3D = stage_node.find_child("BattleGround", true, false) as MeshInstance3D
	if ground == null:
		ground = MeshInstance3D.new()
		ground.name = "BattleGround"
		add_child(ground)

	stage = BattleStage.new()
	stage.name = "BattleStageController"
	add_child(stage)
	stage.configure(cam, env, ground, ally_center, enemy_center)


# =========================================================
# CONTROLLER -> PRESENTATION
# =========================================================

func _connect_presentation() -> void:
	controller.turn_started.connect(_on_turn_started)
	controller.turn_finished.connect(_on_turn_finished)
	controller.enemy_thinking.connect(_on_enemy_thinking)
	controller.action_started.connect(_on_action_started)
	controller.impact.connect(_on_impact)
	controller.guard_applied.connect(_on_guard_applied)
	controller.guard_cleared.connect(_on_guard_cleared)
	controller.self_damaged.connect(_on_self_damaged)
	controller.combatant_defeated.connect(_on_defeated)
	controller.battle_won.connect(_on_won)
	controller.battle_finished.connect(func(_victory: bool) -> void: _finished = true)


func _on_turn_started(c: BattleCombatant) -> void:
	for id in actors.keys():
		var a: BattleActor3D = actors[id] as BattleActor3D
		a.set_turn_marker(a.combatant == c and c.is_alive)


func _on_turn_finished(c: BattleCombatant) -> void:
	var a: BattleActor3D = _actor(c)
	if a == null:
		return
	a.set_turn_marker(false)
	if c.is_alive:
		if c.is_guarding:
			a.set_state(BattleActor3D.VisualState.GUARD)
		else:
			a.set_state(BattleActor3D.VisualState.IDLE)


func _on_enemy_thinking(c: BattleCombatant) -> void:
	var a: BattleActor3D = _actor(c)
	if a != null:
		a.set_state(BattleActor3D.VisualState.THINKING)


func _on_action_started(c: BattleCombatant, _skill: BattleSkill, _targets: Array) -> void:
	var a: BattleActor3D = _actor(c)
	if a != null:
		a.set_state(BattleActor3D.VisualState.WINDUP)


func _on_impact(attacker: BattleCombatant, target: BattleCombatant, amount: int, info: Dictionary) -> void:
	var atk: BattleActor3D = _actor(attacker)
	if atk != null:
		atk.set_state(BattleActor3D.VisualState.ATTACK)

	if bool(info.get("repelled", false)):
		return

	var tgt: BattleActor3D = _actor(target)
	if tgt != null and target.is_alive:
		tgt.flash()
		tgt.set_state(BattleActor3D.VisualState.HIT)
	elif tgt != null:
		tgt.flash()

	stage.add_trauma(clampf(0.18 + float(amount) * 0.02, 0.0, 0.8))
	if amount >= 14:
		stage.punch_fov(3.5)


func _on_guard_applied(c: BattleCombatant) -> void:
	var a: BattleActor3D = _actor(c)
	if a != null:
		a.set_state(BattleActor3D.VisualState.GUARD)


func _on_guard_cleared(c: BattleCombatant) -> void:
	var a: BattleActor3D = _actor(c)
	if a != null and c.is_alive:
		a.set_state(BattleActor3D.VisualState.IDLE)


func _on_self_damaged(c: BattleCombatant, _amount: int) -> void:
	var a: BattleActor3D = _actor(c)
	if a != null:
		a.flash()
	stage.add_trauma(0.3)


func _on_defeated(c: BattleCombatant) -> void:
	var a: BattleActor3D = _actor(c)
	if a != null:
		a.set_state(BattleActor3D.VisualState.DEFEATED)
	stage.add_trauma(0.5)
	stage.punch_fov(4.0)


func _on_won() -> void:
	for id in actors.keys():
		var a: BattleActor3D = actors[id] as BattleActor3D
		a.set_turn_marker(false)
		if a.combatant != null and not a.is_enemy and a.combatant.is_alive:
			a.set_state(BattleActor3D.VisualState.VICTORY)


# =========================================================
# UI SUPPORT
# =========================================================

## Screen position (in UI coordinates) above a combatant.
func get_screen_anchor(c: BattleCombatant, height: float) -> Vector2:
	var a: BattleActor3D = _actor(c)
	var cam: Camera3D = get_viewport().get_camera_3d()
	if a == null or cam == null:
		return get_viewport().get_visible_rect().size * 0.5
	var p: Vector3 = a.global_position + Vector3(0, height, 0)
	if cam.is_position_behind(p):
		return Vector2(-2000, -2000)
	return cam.unproject_position(p)


func _unhandled_input(event: InputEvent) -> void:
	if not _finished:
		return
	if event is InputEventKey:
		var k: InputEventKey = event as InputEventKey
		if k.pressed and not k.echo and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER):
			get_tree().reload_current_scene()
