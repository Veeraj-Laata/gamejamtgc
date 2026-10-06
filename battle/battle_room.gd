extends Node3D
## Root script for battle_room.tscn.
## Bridges BattleCombatant data to 3D actors, builds the stage and UI, and wires
## controller signals to presentation.
##
## Party persistence:
## - The first battle starts at the character defaults.
## - After victory, current HP/LP is saved.
## - The next battle starts with those saved HP/LP values.
## - On defeat, the pre-battle HP/LP snapshot is restored for the next attempt.
## - Encounter defeat state is only recorded on victory.
##
## Boss survival persistence:
## - After the boss is defeated, each ally's final alive state is saved.
## - The ending can use that state to select the correct outcome.


enum EncounterKind {
	TUTORIAL,
	FULL_PARTY_TEST,
	NORMAL_ONE_ENEMY,
	BOSS
}


@export var encounter_kind: EncounterKind = (
	EncounterKind.FULL_PARTY_TEST
)


var encounter: BattleEncounter = null
var controller: BattleController = null
var stage: BattleStage = null
var ui: BattleUI = null

var actors: Dictionary = {}
var _finished: bool = false


const FALLBACK_ALLY: Array[Vector3] = [
	Vector3(-4, 0, 0),
	Vector3(-5, 0, 2),
	Vector3(-5, 0, -2)
]


const FALLBACK_ENEMY: Array[Vector3] = [
	Vector3(4, 0, 0),
	Vector3(5, 0, -2)
]


const BOSS_ENCOUNTER_ID: String = "boss"

const BOSS_SURVIVAL_META: String = (
	"robruzz_boss_survival_state"
)


func _ready() -> void:
	_remove_old_placeholders()

	encounter = _make_encounter()

	# Apply the party state carried from previous encounters.
	_apply_persistent_party_state()

	# Capture the exact values at the start of this battle.
	_capture_party_state()

	var ally_center: Vector3 = Vector3.ZERO
	var enemy_center: Vector3 = Vector3.ZERO

	var centers: Array[Vector3] = _spawn_actors()

	ally_center = centers[0]
	enemy_center = centers[1]

	_build_stage(
		ally_center,
		enemy_center
	)

	controller = BattleController.new()
	controller.name = "BattleController"
	add_child(controller)

	ui = BattleUI.new()
	ui.name = "BattleUI"
	add_child(ui)

	ui.bind(
		controller,
		Callable(
			self,
			"get_screen_anchor"
		)
	)

	_connect_presentation()

	controller.start_battle(
		encounter
	)


func _remove_old_placeholders() -> void:
	var old_ui: Node = get_node_or_null(
		"BattleUI"
	)

	if old_ui != null:
		remove_child(old_ui)
		old_ui.free()

	var old_label: Node = get_node_or_null(
		"Label"
	)

	if old_label != null:
		remove_child(old_label)
		old_label.free()


# =========================================================
# ENCOUNTER SELECTION
# =========================================================

func _make_encounter() -> BattleEncounter:
	if get_tree().has_meta(
		"robruzz_active_encounter_id"
	):
		var stored_id: Variant = (
			get_tree().get_meta(
				"robruzz_active_encounter_id"
			)
		)

		if stored_id is String:
			var active_id: String = (
				stored_id as String
			)

			match active_id:
				"traversal_enemy_01":
					return (
						BattleEncounter
						.room1_enemy_01_battle()
					)

				"traversal_enemy_02":
					return (
						BattleEncounter
						.room1_enemy_02_battle()
					)

				"traversal_enemy_03":
					return (
						BattleEncounter
						.room2_enemy_03_battle()
					)

				"traversal_enemy_04":
					return (
						BattleEncounter
						.room2_enemy_04_battle()
					)

				"boss":
					return (
						BattleEncounter
						.boss_battle()
					)

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
# PARTY STATE
# =========================================================

func _capture_party_state() -> void:
	if encounter == null:
		return

	var snapshot: Array[Dictionary] = []

	for combatant: BattleCombatant in encounter.allies:
		snapshot.append(
			{
				"name": combatant.character_name,
				"hp": combatant.hp,
				"lp": combatant.lp,
				"max_hp": combatant.max_hp,
				"max_lp": combatant.max_lp
			}
		)

	get_tree().set_meta(
		"robruzz_battle_party_snapshot",
		snapshot
	)


func _apply_persistent_party_state() -> void:
	if encounter == null:
		return

	var state: Variant = null

	if get_tree().has_meta(
		"robruzz_party_restore_state"
	):
		state = get_tree().get_meta(
			"robruzz_party_restore_state"
	)

	elif get_tree().has_meta(
		"robruzz_party_state"
	):
		state = get_tree().get_meta(
			"robruzz_party_state"
	)

	if state == null:
		return

	if not state is Array:
		push_warning(
			"BattleRoom: persistent party state is invalid."
		)

		_clear_party_restore_state()

		return

	var saved_array: Array = (
		state as Array
	)

	for combatant: BattleCombatant in encounter.allies:
		for entry: Variant in saved_array:
			if not entry is Dictionary:
				continue

			var data: Dictionary = (
				entry as Dictionary
			)

			if str(
				data.get(
					"name",
					""
				)
			) != combatant.character_name:
				continue

			var saved_hp: int = int(
				data.get(
					"hp",
					combatant.max_hp
				)
			)

			var saved_lp: int = int(
				data.get(
					"lp",
					combatant.max_lp
				)
			)

			combatant.hp = clampi(
				saved_hp,
				0,
				combatant.max_hp
			)

			combatant.lp = clampi(
				saved_lp,
				0,
				combatant.max_lp
			)

			combatant.is_alive = (
				combatant.hp > 0
			)

			combatant.is_guarding = false

			break

	_clear_party_restore_state()

	# Final-boss preparation: every party member gets +20 current HP and +10 LP.
	# If a companion was down after Room 2, bring them back at 10 HP first,
	# then apply the same +20 HP bonus. This only happens for the boss battle.
	if encounter.encounter_id == BOSS_ENCOUNTER_ID:
		for combatant: BattleCombatant in encounter.allies:
			if not combatant.is_alive:
				combatant.revive(10)

			combatant.hp = mini(
				combatant.hp + 20,
				combatant.max_hp
			)

			combatant.lp = mini(
				combatant.lp + 10,
				combatant.max_lp
			)


func _save_current_party_state() -> void:
	if encounter == null:
		return

	var state: Array[Dictionary] = []

	for combatant: BattleCombatant in encounter.allies:
		state.append(
			{
				"name": combatant.character_name,
				"hp": combatant.hp,
				"lp": combatant.lp,
				"max_hp": combatant.max_hp,
				"max_lp": combatant.max_lp
			}
		)

	get_tree().set_meta(
		"robruzz_party_state",
		state
	)


func _save_defeat_restore_state() -> void:
	if not get_tree().has_meta(
		"robruzz_battle_party_snapshot"
	):
		return

	var snapshot: Variant = (
		get_tree().get_meta(
			"robruzz_battle_party_snapshot"
		)
	)

	if not snapshot is Array:
		push_warning(
			"BattleRoom: battle party snapshot is invalid."
		)

		return

	get_tree().set_meta(
		"robruzz_party_restore_state",
		snapshot
	)


func _clear_party_restore_state() -> void:
	if get_tree().has_meta(
		"robruzz_party_restore_state"
	):
		get_tree().remove_meta(
			"robruzz_party_restore_state"
	)


func _clear_battle_snapshot() -> void:
	if get_tree().has_meta(
		"robruzz_battle_party_snapshot"
	):
		get_tree().remove_meta(
			"robruzz_battle_party_snapshot"
	)


# =========================================================
# BOSS SURVIVAL STATE
# =========================================================

func _store_boss_survival_state() -> void:
	if encounter == null:
		return

	if encounter.encounter_id != BOSS_ENCOUNTER_ID:
		return

	var survival_state: Array[Dictionary] = []

	for combatant: BattleCombatant in encounter.allies:
		survival_state.append(
			{
				"name": combatant.character_name,
				"alive": combatant.is_alive,
				"hp": combatant.hp,
				"lp": combatant.lp,
				"max_hp": combatant.max_hp,
				"max_lp": combatant.max_lp
			}
		)

	get_tree().set_meta(
		BOSS_SURVIVAL_META,
		survival_state
	)


# =========================================================
# ENCOUNTER PERSISTENCE
# =========================================================

func _mark_active_encounter_defeated() -> void:
	if not get_tree().has_meta(
		"robruzz_active_encounter_id"
	):
		return

	var stored_id: Variant = (
		get_tree().get_meta(
			"robruzz_active_encounter_id"
		)
	)

	if not stored_id is String:
		push_warning(
			"BattleRoom: active encounter ID is invalid."
		)

		return

	var encounter_id: String = (
		stored_id as String
	)

	if encounter_id.strip_edges().is_empty():
		push_warning(
			"BattleRoom: active encounter ID is empty."
		)

		return

	var defeated: Dictionary = {}

	if get_tree().has_meta(
		"robruzz_defeated_encounters"
	):
		var stored_defeated: Variant = (
			get_tree().get_meta(
				"robruzz_defeated_encounters"
			)
		)

		if stored_defeated is Dictionary:
			defeated = (
				stored_defeated
				as Dictionary
			)

	defeated[encounter_id] = true

	get_tree().set_meta(
		"robruzz_defeated_encounters",
		defeated
	)

	get_tree().remove_meta(
		"robruzz_active_encounter_id"
	)


func _clear_active_encounter() -> void:
	if get_tree().has_meta(
		"robruzz_active_encounter_id"
	):
		get_tree().remove_meta(
			"robruzz_active_encounter_id"
	)


# =========================================================
# ENEMY MODEL ROSTER
# =========================================================
# Deterministic visual roster. Nothing is random here.
#
# Boss: Robot_Eye
# Normal enemy slots cycle through: Bloodsac -> Scissors -> Skeleton.
# If an encounter has more than three normal enemies, the roster repeats.
# The model files can live in any of the candidate folders below.

const ENEMY_MODEL_CANDIDATE_DIRS: Array[String] = [
	"res://assets/enemies/",
	"res://assets/animations/",
	"res://assets/models/",
    "res://assets/"
]

const BOSS_MODEL_FILE: String = "Robot_Eye.fbx"

const NORMAL_ENEMY_MODEL_FILES: Array[String] = [
	"BloodsacCrawler_Stylized.fbx",
	"scissors.fbx",
    "skeleton.fbx"
]

# These are deliberately independent of combatant.visual_scale.
# The four imported models are not guaranteed to have the same source
# dimensions, so each gets a small presentation adjustment here.
const ENEMY_MODEL_SCALE: Dictionary = {
	"Robot_Eye.fbx": 0.72,
	"BloodsacCrawler_Stylized.fbx": 0.65,
	"scissors.fbx": 0.68,
	"skeleton.fbx": 0.65
}

const ENEMY_MODEL_Y_OFFSET: Dictionary = {
	"Robot_Eye.fbx": 0.15,
	"BloodsacCrawler_Stylized.fbx": 0.0,
	"scissors.fbx": 0.0,
	"skeleton.fbx": 0.0
}


func _enemy_model_file(
	combatant: BattleCombatant,
	enemy_index: int
) -> String:
	if combatant != null and combatant.character_name.to_lower() == "the boss":
		return BOSS_MODEL_FILE

	if NORMAL_ENEMY_MODEL_FILES.is_empty():
		return ""

	return NORMAL_ENEMY_MODEL_FILES[
		enemy_index % NORMAL_ENEMY_MODEL_FILES.size()
	]


func _find_enemy_model_path(
	file_name: String
) -> String:
	if file_name.is_empty():
		return ""

	for directory: String in ENEMY_MODEL_CANDIDATE_DIRS:
		var candidate: String = directory + file_name
		if ResourceLoader.exists(candidate):
			return candidate

	return ""


func _hide_enemy_placeholder_meshes(
	actor: Node
) -> void:
	if actor == null:
		return

	# BattleActor3D creates the red enemy capsule as its fallback visual.
	# At this point this function is called BEFORE the imported FBX is added,
	# so every existing MeshInstance3D under the actor is a placeholder.
	for node: Node in actor.get_children():
		if node is MeshInstance3D:
			(node as MeshInstance3D).visible = false

		_hide_enemy_placeholder_meshes(node)


func _remove_lights_from_imported_enemy(
	node: Node
) -> void:
	if node == null:
		return

	for child: Node in node.get_children():
		if child is Light3D:
			child.queue_free()
			continue

		_remove_lights_from_imported_enemy(child)


const ENEMY_OUTLINE_WIDTH: float = 0.0007


func _make_enemy_outline_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()

	shader.code = """
shader_type spatial;

render_mode
	unshaded,
	cull_front,
	depth_draw_never,
	depth_test_default,
	blend_mix;

uniform vec4 outline_color : source_color =
	vec4(1.0, 0.015, 0.015, 1.0);

uniform float outline_width = 0.0007;
uniform float death_alpha = 1.0;

void vertex()
{
	VERTEX += NORMAL * outline_width;
}

void fragment()
{
	ALBEDO = outline_color.rgb;
	ALPHA = death_alpha;
}
"""

	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader

	material.set_shader_parameter(
		"outline_color",
		Color(1.0, 0.015, 0.015, 1.0)
	)

	material.set_shader_parameter(
		"outline_width",
		ENEMY_OUTLINE_WIDTH
	)

	material.set_shader_parameter(
		"death_alpha",
		1.0
	)

	return material


func _make_red_enemy_material(
	_original: Material,
	outline: ShaderMaterial
) -> Material:
	# Enemies are intentionally rendered as near-black silhouettes.
	# The red outline is supplied by the second material pass above.
	var body_shader: Shader = Shader.new()

	body_shader.code = """
shader_type spatial;

render_mode
	unshaded,
	cull_back,
	blend_mix,
	depth_prepass_alpha;

uniform float death_alpha = 1.0;

void fragment()
{
	ALBEDO = vec3(0.008, 0.008, 0.008);
	ALPHA = death_alpha;
}
"""

	var body_material: ShaderMaterial = ShaderMaterial.new()
	body_material.shader = body_shader

	body_material.set_shader_parameter(
		"death_alpha",
		1.0
	)

	body_material.next_pass = outline

	return body_material


func _set_enemy_death_alpha(
	actor: BattleActor3D,
	alpha: float
) -> void:
	if actor == null:
		return

	var meshes: Array[MeshInstance3D] = []
	_collect_enemy_meshes(
		actor,
		meshes
	)

	for mesh_instance: MeshInstance3D in meshes:
		if mesh_instance == null:
			continue

		if mesh_instance.mesh == null:
			continue

		for surface_index in mesh_instance.mesh.get_surface_count():
			var body_material: Material = (
				mesh_instance.get_surface_override_material(
					surface_index
				)
			)

			if body_material is ShaderMaterial:
				var body_shader_material := (
					body_material as ShaderMaterial
				)

				if body_shader_material.shader != null:
					if body_shader_material.shader.code.contains(
						"uniform float death_alpha"
					):
						body_shader_material.set_shader_parameter(
							"death_alpha",
							alpha
						)

					var outline_material: ShaderMaterial = (
						body_shader_material.next_pass as ShaderMaterial
					)

					if outline_material != null:
						outline_material.set_shader_parameter(
							"death_alpha",
							alpha
						)


func _collect_enemy_meshes(
	node: Node,
	meshes: Array[MeshInstance3D]
) -> void:
	if node == null:
		return

	for child: Node in node.get_children():
		if child is MeshInstance3D:
			meshes.append(
				child as MeshInstance3D
			)

		_collect_enemy_meshes(
			child,
			meshes
		)


func _play_enemy_death_animation(
	actor: BattleActor3D
) -> void:
	if actor == null:
		return

	var original_position: Vector3 = actor.position

	# Make sure every enemy starts fully visible.
	_set_enemy_death_alpha(
		actor,
		1.0
	)

	var tween: Tween = create_tween()

	# Fast comic-style shake.
	tween.tween_property(
		actor,
		"position",
		original_position + Vector3(0.11, 0.0, 0.0),
		0.045
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		actor,
		"position",
		original_position + Vector3(-0.11, 0.025, 0.0),
		0.045
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		actor,
		"position",
		original_position + Vector3(0.075, -0.02, 0.0),
		0.04
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		actor,
		"position",
		original_position,
		0.04
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Fade both the black body and red outline at the same time.
	tween.parallel().tween_method(
		func(value: float) -> void:
			_set_enemy_death_alpha(
				actor,
				value
			),
		1.0,
		0.0,
		0.22
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween.tween_callback(
		func() -> void:
			if not is_instance_valid(actor):
				return

			# Remove the actor from the lookup table BEFORE freeing it.
			# Otherwise _on_won() can later try to cast a freed actor.
			var actor_id: int = actor.get_instance_id()
			if actors.has(actor_id):
				actors.erase(actor_id)

			# Remove it from the registry first. No battle callback can
			# discover this actor after this point.
			actor.queue_free()
	)


func _style_enemy_meshes(
	node: Node
) -> void:
	if node == null:
		return

	for child: Node in node.get_children():
		if child is MeshInstance3D:
			var mesh_instance: MeshInstance3D = (
				child as MeshInstance3D
			)

			var outline: ShaderMaterial = (
				_make_enemy_outline_material()
			)

			if mesh_instance.mesh != null:
				var surface_count: int = (
					mesh_instance.mesh.get_surface_count()
				)

				for surface_index in surface_count:
					var original_material: Material = (
						mesh_instance.mesh.surface_get_material(
							surface_index
						)
					)

					var styled_material: Material = (
						_make_red_enemy_material(
							original_material,
							outline
						)
					)

					if styled_material != null:
						mesh_instance.set_surface_override_material(
							surface_index,
							styled_material
						)

			# Tiny margin because the outline is intentionally thin.
			mesh_instance.extra_cull_margin = 0.005

		_style_enemy_meshes(child)


func _install_enemy_model(
	actor: BattleActor3D,
	combatant: BattleCombatant,
	enemy_index: int
) -> void:
	if actor == null or combatant == null:
		return

	var file_name: String = _enemy_model_file(
		combatant,
		enemy_index
	)

	var model_path: String = _find_enemy_model_path(
		file_name
	)

	if model_path.is_empty():
		push_warning(
			"BattleRoom: could not find enemy model: " + file_name
		)
		return

	var packed_model: PackedScene = load(
		model_path
	) as PackedScene

	if packed_model == null:
		push_warning(
			"BattleRoom: enemy model is not a PackedScene: " + model_path
		)
		return

	# BattleActor3D creates a fallback enemy capsule. Hide it before the
	# imported model is added so the capsule never remains visible underneath.
	_hide_enemy_placeholder_meshes(actor)

	var model_instance: Node = packed_model.instantiate()
	if model_instance == null:
		push_warning(
			"BattleRoom: failed to instantiate enemy model: " + model_path
		)
		return

	model_instance.name = "ImportedEnemyModel"
	actor.add_child(model_instance)

	# Imported assets should not bring their own lights into the battle.
	# Lighting is controlled by the BattleStage/Godot scene.
	_remove_lights_from_imported_enemy(model_instance)

	var model_root: Node3D = model_instance as Node3D
	if model_root == null:
		push_warning(
			"BattleRoom: enemy model root is not Node3D: " + model_path
		)
		return

	var model_scale: float = float(
		ENEMY_MODEL_SCALE.get(
			file_name,
			1.0
		)
	)

	var y_offset: float = float(
		ENEMY_MODEL_Y_OFFSET.get(
			file_name,
			0.0
		)
	)

	model_root.position = Vector3(
		0.0,
		y_offset,
		0.0
	)

	# The actor root handles battle-facing. This local rotation only corrects
	# the orientation authored in the imported FBX.
	model_root.rotation_degrees = Vector3(
		0.0,
		180.0,
		0.0
	)

	model_root.scale = Vector3.ONE * model_scale

	# Red comic body + thin white outline as a SECOND material pass.
	# Do not use material_overlay here: it would cover the red body.
	_style_enemy_meshes(model_instance)


# =========================================================
# ACTOR SPAWNING
# =========================================================

func _holder(
	path: String,
	fallback_name: String
) -> Node3D:
	var n: Node3D = (
		get_node_or_null(path)
		as Node3D
	)

	if n != null:
		return n

	var created: Node3D = Node3D.new()
	created.name = fallback_name
	add_child(created)

	return created


func _marker_position(
	kind: String,
	index: int
) -> Vector3:
	var m: Node3D = (
		get_node_or_null(
			"SpawnPoints/%s_%d" % [
				kind,
				index
			]
		)
		as Node3D
	)

	if m != null:
		return m.global_position

	if kind == "Ally":
		return FALLBACK_ALLY[
			mini(
				index,
				FALLBACK_ALLY.size() - 1
			)
		]

	return FALLBACK_ENEMY[
		mini(
			index,
			FALLBACK_ENEMY.size() - 1
		)
	]


func _spawn_actors() -> Array[Vector3]:
	var ally_holder: Node3D = _holder(
		"BattleActors/AllyActors",
		"AllyActors"
	)

	var enemy_holder: Node3D = _holder(
		"BattleActors/EnemyActors",
		"EnemyActors"
	)

	for child in ally_holder.get_children():
		child.queue_free()

	for child in enemy_holder.get_children():
		child.queue_free()

	var ally_positions: Array[Vector3] = []

	for i in encounter.allies.size():
		ally_positions.append(
			_marker_position(
				"Ally",
				i
			)
		)

	var enemy_positions: Array[Vector3] = []

	if encounter.enemies.size() == 1:
		enemy_positions.append(
			(
				_marker_position(
					"Enemy",
					0
				)
				+
				_marker_position(
					"Enemy",
					1
				)
			)
			* 0.5
		)
	else:
		for i in encounter.enemies.size():
			enemy_positions.append(
				_marker_position(
					"Enemy",
					i
				)
			)

	var ally_center: Vector3 = _average(
		ally_positions
	)

	var enemy_center: Vector3 = _average(
		enemy_positions
	)

	var to_enemy: Vector3 = (
		enemy_center
		-
		ally_center
	)

	to_enemy.y = 0.0

	if to_enemy.length_squared() > 0.0001:
		to_enemy = to_enemy.normalized()
	else:
		to_enemy = Vector3.FORWARD

	for i in encounter.allies.size():
		_spawn_one(
			encounter.allies[i],
			false,
			i,
			ally_positions[i],
			to_enemy,
			ally_holder
		)

	for i in encounter.enemies.size():
		_spawn_one(
			encounter.enemies[i],
			true,
			i,
			enemy_positions[i],
			-to_enemy,
			enemy_holder
		)

	var out: Array[Vector3] = [
		ally_center,
		enemy_center
	]

	return out


func _spawn_one(
	c: BattleCombatant,
	is_enemy: bool,
	index: int,
	pos: Vector3,
	facing: Vector3,
	holder: Node3D
) -> void:
	var a: BattleActor3D = BattleActor3D.new()

	holder.add_child(a)

	# Keep the imported models at sensible relative sizes.
	# Ally 0 is the main character; allies 1 and 2 are smaller.
	if is_enemy:
		c.visual_scale = 1.15
	else:
		match index:
			0:
				c.visual_scale = 1.25 # Main character
			1, 2:
				c.visual_scale = 0.50 # Ally 1 / Ally 2
			_:
				c.visual_scale = 0.50

	a.global_position = pos
	a.forward = facing

	a.setup(
		c,
		is_enemy,
		index
	)

	# BattleActor3D owns the imported model's local correction; the actor
	# root owns the actual battle direction. Keep this explicit so adding
	# enemy FBXs can never rotate the whole party toward the camera/side.
	var flat_facing: Vector3 = facing
	flat_facing.y = 0.0
	if flat_facing.length_squared() > 0.0001:
		flat_facing = flat_facing.normalized()
		var look_target: Vector3 = a.global_position + flat_facing
		look_target.y = a.global_position.y
		a.look_at(look_target, Vector3.UP)

	if is_enemy:
		_install_enemy_model(
			a,
			c,
			index
		)

	actors[
		c.get_instance_id()
	] = a


func _average(
	points: Array[Vector3]
) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO

	var sum: Vector3 = Vector3.ZERO

	for p in points:
		sum += p

	return sum / float(
		points.size()
	)


func _actor(
	c: BattleCombatant
) -> BattleActor3D:
	if c == null:
		return null

	var actor_id: int = c.get_instance_id()
	if not actors.has(actor_id):
		return null

	var raw_actor: Variant = actors[actor_id]

	# Never cast a stale/freed Godot Object. References are not automatically
	# cleared when a Node is freed, so validate BEFORE the cast.
	if not is_instance_valid(raw_actor):
		actors.erase(actor_id)
		return null

	var actor: BattleActor3D = raw_actor as BattleActor3D
	if actor == null:
		actors.erase(actor_id)
		return null

	return actor


# =========================================================
# STAGE
# =========================================================

func _build_stage(
	ally_center: Vector3,
	enemy_center: Vector3
) -> void:
	var stage_node: Node = get_node_or_null(
		"battlestage"
	)

	if stage_node == null:
		stage_node = self

	var cam: Camera3D = (
		stage_node.find_child(
			"BattleCamera",
			true,
			false
		)
		as Camera3D
	)

	if cam == null:
		cam = Camera3D.new()
		cam.name = "BattleCamera"
		add_child(cam)

	var env: WorldEnvironment = (
		stage_node.find_child(
			"BattleEnvironment",
			true,
			false
		)
		as WorldEnvironment
	)

	if env == null:
		env = WorldEnvironment.new()
		env.name = "BattleEnvironment"
		add_child(env)

	var ground: MeshInstance3D = (
		stage_node.find_child(
			"BattleGround",
			true,
			false
		)
		as MeshInstance3D
	)

	if ground == null:
		ground = MeshInstance3D.new()
		ground.name = "BattleGround"
		add_child(ground)

	stage = BattleStage.new()
	stage.name = "BattleStageController"
	add_child(stage)

	stage.configure(
		cam,
		env,
		ground,
		ally_center,
		enemy_center
	)


# =========================================================
# SKILL PRESENTATION
# =========================================================

func _skill_effect_color(
	skill: BattleSkill
) -> Color:
	if skill == null:
		return BattleStage.LIGHT_NEUTRAL

	# Every named skill gets a simple, memorable visual identity. The effect
	# system itself stays shared; only the color changes here.
	match skill.skill_id:
		BattleSkills.RED_RAY:
			return Color(1.0, 0.08, 0.08, 1.0)

		BattleSkills.BLUE_SHIFT:
			return Color(0.15, 0.40, 1.0, 1.0)

		BattleSkills.VIOLET_FLASH:
			return Color(0.85, 0.20, 1.0, 1.0)

		BattleSkills.INFRARED_BURN:
			return Color(1.0, 0.28, 0.06, 1.0)

		BattleSkills.MICROWAVE_PULSE:
			return Color(1.0, 0.82, 0.12, 1.0)

		BattleSkills.RADIO_STATIC:
			return Color(0.20, 1.0, 0.48, 1.0)

		BattleSkills.ULTRAVIOLET_CUT:
			return Color(0.58, 0.18, 1.0, 1.0)

		BattleSkills.XRAY_BURST:
			return Color(0.48, 0.90, 1.0, 1.0)

		BattleSkills.GAMMA_RAY:
			return Color(1.0, 0.94, 0.45, 1.0)

		BattleSkills.BOSS_CRUSH:
			return Color(1.0, 0.03, 0.12, 1.0)

		BattleSkills.BOSS_GAMMA:
			return Color(1.0, 0.60, 0.10, 1.0)

		BattleSkills.BOSS_XRAY:
			return Color(0.20, 1.0, 1.0, 1.0)

		BattleSkills.BOSS_SURGE:
			return Color(1.0, 0.35, 0.06, 1.0)

		BattleSkills.RADIO_WAVELENGTH:
			return Color(0.15, 1.0, 0.80, 1.0)

		BattleSkills.VIOLET_BULLETS:
			return Color(1.0, 0.18, 0.78, 1.0)

		BattleSkills.ULTRAVIOLET_VIOLENCE:
			return Color(0.62, 0.10, 1.0, 1.0)

		BattleSkills.XXXRAY:
			return Color(1.0, 0.04, 0.45, 1.0)

		BattleSkills.GREEN_BOOST:
			return Color(0.20, 1.0, 0.28, 1.0)

		BattleSkills.BLUE_BOOST:
			return Color(0.15, 0.55, 1.0, 1.0)

		BattleSkills.MICROWAVE_MELT:
			return Color(1.0, 0.48, 0.08, 1.0)

		BattleSkills.RED_DEBOOST:
			return Color(1.0, 0.12, 0.22, 1.0)

		BattleSkills.PURPLE_DEBOOST:
			return Color(0.66, 0.12, 1.0, 1.0)

		BattleSkills.REVIVE:
			return Color(0.30, 1.0, 0.88, 1.0)

		BattleSkills.GUARD:
			return Color(0.82, 0.90, 1.0, 1.0)

		_:
			match skill.skill_type:
				BattleSkill.SkillType.LOW_ENERGY:
					return BattleStage.LIGHT_LOW_ENERGY

				BattleSkill.SkillType.HIGH_ENERGY:
					return BattleStage.LIGHT_HIGH_ENERGY

				_:
					return BattleStage.LIGHT_NEUTRAL


func _is_rejected_boss_skill(
	skill: BattleSkill
) -> bool:
	if encounter == null:
		return false

	if controller == null:
		return false

	if encounter.encounter_id != BOSS_ENCOUNTER_ID:
		return false

	if skill == null:
		return false

	if controller.rejected_skill_id.is_empty():
		return false

	return (
		skill.skill_id
		==
		controller.rejected_skill_id
	)


func _play_skill_presentation(
	combatant: BattleCombatant,
	skill: BattleSkill,
	targets: Array
) -> void:
	if stage == null:
		return

	if combatant == null:
		return

	if skill == null:
		return

	var attacker_actor: BattleActor3D = _actor(
		combatant
	)

	if attacker_actor == null:
		return

	var from_position: Vector3 = (
		attacker_actor.global_position
		+
		Vector3.UP * 1.0
	)

	var shot_color: Color = (
		_skill_effect_color(
			skill
		)
	)

	if targets.is_empty():
		await stage.play_skill_effect(
			from_position,
			from_position,
			shot_color,
			skill.effect_type,
			skill.skill_id
		)

		return

	for target_variant: Variant in targets:
		if not target_variant is BattleCombatant:
			continue

		var target: BattleCombatant = (
			target_variant as BattleCombatant
		)

		var target_actor: BattleActor3D = _actor(
			target
		)

		if target_actor == null:
			continue

		var to_position: Vector3 = (
			target_actor.global_position
			+
			Vector3.UP * 1.0
		)

		await stage.play_skill_effect(
			from_position,
			to_position,
			shot_color,
			skill.effect_type,
			skill.skill_id
		)


func _play_rejected_skill_presentation(
	combatant: BattleCombatant,
	targets: Array
) -> void:
	if stage == null:
		return

	if combatant == null:
		return

	for target_variant: Variant in targets:
		if not target_variant is BattleCombatant:
			continue

		var target: BattleCombatant = (
			target_variant as BattleCombatant
		)

		var target_actor: BattleActor3D = _actor(
			target
		)

		if target_actor == null:
			continue

		var target_position: Vector3 = (
			target_actor.global_position
			+
			Vector3.UP * 1.0
		)

		# Rejected skills use the existing GUARD effect as a clean
		# "blocked/repelled" visual rather than showing a successful hit.
		await stage.play_skill_effect(
			target_position,
			target_position,
			BattleStage.LIGHT_NEUTRAL,
			BattleSkill.EffectType.GUARD,
			"rejected"
		)


# =========================================================
# CONTROLLER -> PRESENTATION
# =========================================================

func _connect_presentation() -> void:
	controller.turn_started.connect(
		_on_turn_started
	)

	controller.turn_finished.connect(
		_on_turn_finished
	)

	controller.enemy_thinking.connect(
		_on_enemy_thinking
	)

	controller.action_started.connect(
		_on_action_started
	)

	controller.impact.connect(
		_on_impact
	)

	controller.heal_applied.connect(
		_on_heal_applied
	)

	controller.guard_applied.connect(
		_on_guard_applied
	)

	controller.guard_cleared.connect(
		_on_guard_cleared
	)

	controller.self_damaged.connect(
		_on_self_damaged
	)

	controller.combatant_defeated.connect(
		_on_defeated
	)

	controller.battle_won.connect(
		_on_won
	)

	controller.battle_finished.connect(
		_on_battle_finished
	)


func _on_battle_finished(
	victory: bool
) -> void:
	_finished = true

	if victory:
		_save_current_party_state()

		_store_boss_survival_state()

		_mark_active_encounter_defeated()

		_clear_party_restore_state()
	else:
		_save_defeat_restore_state()


func _on_turn_started(
	c: BattleCombatant
) -> void:
	for id in actors.keys():
		# The death animation can free an actor before a later turn signal
		# arrives. Validate the raw reference BEFORE casting it.
		if not actors.has(id):
			continue

		var raw_actor: Variant = actors[id]
		if not is_instance_valid(raw_actor):
			actors.erase(id)
			continue

		var a: BattleActor3D = raw_actor as BattleActor3D
		if a == null:
			actors.erase(id)
			continue

		a.set_turn_marker(
			a.combatant == c
			and
			c != null
			and
			c.is_alive
		)


func _on_turn_finished(
	c: BattleCombatant
) -> void:
	var a: BattleActor3D = _actor(
		c
	)

	if a == null:
		return

	a.set_turn_marker(
		false
	)

	if c.is_alive:
		if c.is_guarding:
			a.set_state(
				BattleActor3D.VisualState.GUARD
			)
		else:
			a.set_state(
				BattleActor3D.VisualState.IDLE
			)


func _on_enemy_thinking(
	c: BattleCombatant
) -> void:
	var a: BattleActor3D = _actor(
		c
	)

	if a != null:
		a.set_state(
			BattleActor3D.VisualState.THINKING
		)


func _on_action_started(
	c: BattleCombatant,
	skill: BattleSkill,
	targets: Array
) -> void:
	var a: BattleActor3D = _actor(
		c
	)

	if a != null:
		a.set_state(
			BattleActor3D.VisualState.WINDUP
		)

	if _is_rejected_boss_skill(
		skill
	):
		_play_rejected_skill_presentation(
			c,
			targets
		)

		return

	# The devastating X-Ray gets a much heavier presentation than a normal skill.
	# The controller still owns the actual combat result.
	if skill != null and skill.skill_id == BattleSkills.BOSS_XRAY:
		if stage != null:
			stage.add_trauma(0.55)
			stage.punch_fov(5.0)

	_play_skill_presentation(
		c,
		skill,
		targets
	)


func _on_impact(
	attacker: BattleCombatant,
	target: BattleCombatant,
	amount: int,
	info: Dictionary
) -> void:
	var atk: BattleActor3D = _actor(
		attacker
	)

	if atk != null:
		atk.set_state(
			BattleActor3D.VisualState.ATTACK
		)

	if bool(
		info.get(
			"repelled",
			false
		)
	):
		return

	var tgt: BattleActor3D = _actor(
		target
	)

	if tgt != null and target.is_alive:
		tgt.flash()

		tgt.set_state(
			BattleActor3D.VisualState.HIT
		)

	elif tgt != null:
		tgt.flash()

	stage.add_trauma(
		clampf(
			0.18
			+
			float(amount) * 0.02,
			0.0,
			0.8
		)
	)

	if attacker != null and attacker.is_enemy and attacker.character_name == "the boss":
		var skill_id: String = str(info.get("skill_id", ""))
		if skill_id == BattleSkills.BOSS_XRAY:
			stage.add_trauma(0.75)
			stage.punch_fov(8.0)
		elif amount >= 14:
			stage.punch_fov(3.5)
	elif amount >= 14:
		stage.punch_fov(3.5)


func _on_heal_applied(
	_healer: BattleCombatant,
	target: BattleCombatant,
	_amount: int
) -> void:
	if target == null:
		return

	if not target.is_alive:
		return

	var a: BattleActor3D = _actor(
		target
	)

	if a == null:
		return

	a.set_turn_marker(
		false
	)

	if target.is_guarding:
		a.set_state(
			BattleActor3D.VisualState.GUARD
		)
	else:
		a.set_state(
			BattleActor3D.VisualState.IDLE
		)

	a.flash()

	stage.add_trauma(
		0.12
	)


func _on_guard_applied(
	c: BattleCombatant
) -> void:
	var a: BattleActor3D = _actor(
		c
	)

	if a != null:
		a.set_state(
			BattleActor3D.VisualState.GUARD
		)


func _on_guard_cleared(
	c: BattleCombatant
) -> void:
	var a: BattleActor3D = _actor(
		c
	)

	if (
		a != null
		and
		c.is_alive
	):
		a.set_state(
			BattleActor3D.VisualState.IDLE
		)


func _on_self_damaged(
	c: BattleCombatant,
	_amount: int
) -> void:
	var a: BattleActor3D = _actor(
		c
	)

	if a != null:
		a.flash()

	stage.add_trauma(
		0.3
	)


func _on_defeated(
	c: BattleCombatant
) -> void:
	var a: BattleActor3D = _actor(
		c
	)

	if a != null:
		a.set_state(
			BattleActor3D.VisualState.DEFEATED
		)

		if c.is_enemy:
			_play_enemy_death_animation(
				a
			)

	stage.add_trauma(
		0.5
	)

	stage.punch_fov(
		4.0
	)


func _on_won() -> void:
	for id in actors.keys():
		var raw_actor: Variant = actors[id]

		# Enemy death animations can free their actor before the
		# battle_won signal reaches this function.
		if not is_instance_valid(raw_actor):
			actors.erase(id)
			continue

		var a: BattleActor3D = raw_actor as BattleActor3D
		if a == null:
			actors.erase(id)
			continue

		a.set_turn_marker(
			false
		)

		if (
			a.combatant != null
			and
			not a.is_enemy
			and
			a.combatant.is_alive
		):
			a.set_state(
				BattleActor3D.VisualState.VICTORY
			)


# =========================================================
# UI SUPPORT
# =========================================================

func get_screen_anchor(
	c: BattleCombatant,
	height: float
) -> Vector2:
	var a: BattleActor3D = _actor(
		c
	)

	var cam: Camera3D = (
		get_viewport().get_camera_3d()
	)

	if a == null or cam == null:
		return (
			get_viewport()
			.get_visible_rect()
			.size
			* 0.5
		)

	var p: Vector3 = (
		a.global_position
		+
		Vector3(
			0,
			height,
			0
		)
	)

	if cam.is_position_behind(
		p
	):
		return Vector2(
			-2000,
			-2000
		)

	return cam.unproject_position(
		p
	)


func _unhandled_input(
	event: InputEvent
) -> void:
	if not _finished:
		return

	if not event is InputEventKey:
		return

	var k: InputEventKey = (
		event as InputEventKey
	)

	if not (
		k.pressed
		and
		not k.echo
		and
		(
			k.keycode == KEY_ENTER
			or
			k.keycode == KEY_KP_ENTER
		)
	):
		return

	var return_scene: String = (
		"res://webproof.tscn"
	)

	if get_tree().has_meta(
		"robruzz_return_scene"
	):
		var stored_scene: Variant = (
			get_tree().get_meta(
				"robruzz_return_scene"
			)
		)

		if stored_scene is String:
			var stored_scene_path: String = (
				stored_scene as String
			)

			if (
				not stored_scene_path.is_empty()
				and
				ResourceLoader.exists(
					stored_scene_path
				)
			):
				return_scene = stored_scene_path

	await SceneTransition.change_scene(
		return_scene
	)
