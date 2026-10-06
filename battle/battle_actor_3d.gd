class_name BattleActor3D
extends Node3D
## Runtime visual for one BattleCombatant.
##
## Ally_0 = MainCharacterInBattle.fbx
## Ally_1 = PartyMemberBattle.fbx
## Ally_2 = PartyMemberBattle.fbx
##
## IMPORTANT TRANSFORM ARCHITECTURE:
##
## BattleActor3D rotation:
##     Controls which direction the combatant faces in battle.
##
## battle_model rotation:
##     Controls the imported FBX's local orientation.
##
## battle_model position:
##     Controls the FBX's local position offset.
##
## battle_model scale:
##     Controls the FBX's visual size.
##
## The imported FBX itself is never modified.
##
## Imported character materials/textures are preserved.
## The original comic player + outline shaders are added
## as an additional material pass.


const PLAYER_SHADER: Shader = preload(
	"res://scripts/comic_player.gdshader"
)

const OUTLINE_SHADER: Shader = preload(
	"res://scripts/comic_outline.gdshader"
)


const MAIN_CHARACTER_BATTLE_PATH := (
	"res://assets/animations/MainCharacterInBattle.fbx"
)

const PARTY_MEMBER_BATTLE_PATH := (
	"res://assets/animations/PartyMemberBattle.fbx"
)


const BLACK := Color(
	0.001,
	0.002,
	0.006,
	1.0
)

const PROTAGONIST_COLOR := Color(
	0.01,
	0.16,
	0.95,
	1.0
)

const COMPANION_COLOR := Color(
	0.05,
	1.0,
	0.20,
	1.0
)

const ENEMY_COLOR := Color(
	0.95,
	0.02,
	0.07,
	1.0
)


enum VisualState {
	IDLE,
	READY,
	THINKING,
	WINDUP,
	ATTACK,
	HIT,
	GUARD,
	RECOVER,
	DEFEATED,
	INTRO,
	VICTORY
}


# =========================================================
# MODEL TRANSFORM CONTROLS
# =========================================================
#
# These transform ONLY the imported FBX model.
#
# BattleActor3D itself is still free to rotate toward the
# opposing formation.
#
# If the character is facing backwards, change the rotation
# correction here.
#
# Common values:
#
#   Vector3(0, 0, 0)
#       Original FBX orientation.
#
#   Vector3(0, 180, 0)
#       Turn model around completely.
#
#   Vector3(0, 90, 0)
#       Rotate model 90 degrees.
#
#   Vector3(0, -90, 0)
#       Rotate model -90 degrees.
#


@export_category("Character Model Transform")


@export var ally_model_position: Vector3 = Vector3.ZERO


@export var ally_model_rotation_degrees: Vector3 = Vector3(
	0.0,
	180.0,
	0.0
)


@export var ally_model_scale: Vector3 = Vector3.ONE


@export var enemy_model_position: Vector3 = Vector3.ZERO


@export var enemy_model_rotation_degrees: Vector3 = Vector3(
	0.0,
	180.0,
	0.0
)


@export var enemy_model_scale: Vector3 = Vector3.ONE


# =========================================================
# ACTOR DATA
# =========================================================


var combatant: BattleCombatant = null

var is_enemy: bool = false

var spawn_index: int = 0

var visual_state: VisualState = VisualState.IDLE

var accent: Color = PROTAGONIST_COLOR


## Direction toward the opposing side.
## Used for battle lunges.
##
## This is supplied by battle_room.gd.
var forward: Vector3 = Vector3.RIGHT


# ---------------------------------------------------------
# ENEMY / FALLBACK VISUAL
# ---------------------------------------------------------


var body: MeshInstance3D = null

var body_material: ShaderMaterial = null


# ---------------------------------------------------------
# ALLY CHARACTER VISUAL
# ---------------------------------------------------------


var battle_model: Node3D = null

var battle_animation_player: AnimationPlayer = null


# ---------------------------------------------------------
# TURN MARKER
# ---------------------------------------------------------


var marker: MeshInstance3D = null


var base_position: Vector3 = Vector3.ZERO

var _tween: Tween = null

var _marker_on: bool = false

var _time: float = 0.0

var _body_base_y: float = 0.95

var _last_alive_state: bool = true


# =========================================================
# SETUP
# =========================================================


func setup(
	p_combatant: BattleCombatant,
	p_is_enemy: bool,
	p_index: int
) -> void:
	combatant = p_combatant

	is_enemy = p_is_enemy

	spawn_index = p_index

	_last_alive_state = (
		combatant != null
		and combatant.is_alive
	)


	if is_enemy:
		accent = ENEMY_COLOR

	elif spawn_index == 0:
		accent = PROTAGONIST_COLOR

	else:
		accent = COMPANION_COLOR


	if combatant == null:
		name = "Actor"

	else:
		name = (
			"Actor_"
			+
			combatant.character_name.replace(
				" ",
				"_"
			)
		)


	_build_visual()


	# Store the actual world position assigned by
	# BattleRoom.
	base_position = position


	if combatant != null and not combatant.is_alive:
		set_state(
			VisualState.DEFEATED
		)

	else:
		set_state(
			VisualState.INTRO
		)


# =========================================================
# VISUAL BUILD
# =========================================================


func _build_visual() -> void:
	var s: float = 1.0


	if combatant != null:
		s = combatant.visual_scale


	var enemy_scale: float = (
		0.9
		if is_enemy
		else 1.0
	)


	# -----------------------------------------------------
	# ALLIES
	# -----------------------------------------------------


	if not is_enemy:
		_build_party_member(s)


	else:

		# -------------------------------------------------
		# ENEMY CAPSULE
		# -------------------------------------------------

		body = MeshInstance3D.new()

		var capsule: CapsuleMesh = CapsuleMesh.new()

		capsule.radius = (
			0.55
			* s
			* enemy_scale
		)

		capsule.height = (
			1.9
			* s
			* enemy_scale
		)

		body.mesh = capsule

		body.cast_shadow = (
			GeometryInstance3D
			.SHADOW_CASTING_SETTING_OFF
		)

		_body_base_y = (
			capsule.height
			* 0.5
		)

		body.position.y = _body_base_y

		body_material = _make_material(
			accent
		)

		body.material_override = body_material

		add_child(body)


	# -----------------------------------------------------
	# TURN MARKER
	# -----------------------------------------------------


	marker = MeshInstance3D.new()

	var ring: TorusMesh = TorusMesh.new()

	ring.inner_radius = (
		0.95 * s
	)

	ring.outer_radius = (
		1.12 * s
	)

	marker.mesh = ring

	marker.scale = Vector3(
		1.0,
		0.08,
		1.0
	)

	marker.position.y = 0.03

	marker.cast_shadow = (
		GeometryInstance3D
		.SHADOW_CASTING_SETTING_OFF
	)

	var mm: StandardMaterial3D = (
		StandardMaterial3D.new()
	)

	mm.shading_mode = (
		BaseMaterial3D.SHADING_MODE_UNSHADED
	)

	mm.albedo_color = Color(
		0.9,
		0.95,
		1.0,
		1.0
	)

	marker.material_override = mm

	marker.visible = false

	add_child(marker)


# =========================================================
# PARTY MODEL
# =========================================================


func _build_party_member(
	scale_value: float
) -> void:

	var model_path: String


	# Ally 0 = protagonist.
	#
	# Ally 1 / Ally 2 = companions.


	if spawn_index == 0:
		model_path = MAIN_CHARACTER_BATTLE_PATH

	else:
		model_path = PARTY_MEMBER_BATTLE_PATH


	var party_scene: PackedScene = (
		load(model_path)
		as PackedScene
	)


	if party_scene == null:

		push_error(
			"BattleActor3D: Could not load battle "
			+ "character at: "
			+ model_path
		)

		_build_fallback_body(
			scale_value
		)

		return


	battle_model = (
		party_scene.instantiate()
		as Node3D
	)


	if battle_model == null:

		push_error(
			"BattleActor3D: Could not instantiate "
			+ "battle character: "
			+ model_path
		)

		_build_fallback_body(
			scale_value
		)

		return


	if spawn_index == 0:
		battle_model.name = (
			"MainCharacterInBattle"
		)

	else:
		battle_model.name = (
			"PartyMemberBattle"
		)


	add_child(battle_model)


	# -----------------------------------------------------
	# MODEL TRANSFORM
	# -----------------------------------------------------
	#
	# IMPORTANT:
	#
	# We do NOT rotate the BattleActor3D here.
	#
	# The BattleActor3D's rotation belongs to the battle
	# formation and is controlled by BattleRoom.
	#
	# This rotation only corrects the FBX itself.
	# -----------------------------------------------------


	_apply_model_transform(
		scale_value
	)


	# -----------------------------------------------------
	# FIND ANIMATION PLAYER
	# -----------------------------------------------------


	battle_animation_player = (
		_find_animation_player(
			battle_model
		)
	)


	if battle_animation_player != null:

		_play_battle_animation()

	else:

		push_warning(
			"BattleActor3D: No AnimationPlayer "
			+ "found in "
			+ model_path
		)


	# -----------------------------------------------------
	# COMIC SHADER
	# -----------------------------------------------------


	_apply_comic_shader_to_model(
		battle_model
	)


# =========================================================
# MODEL TRANSFORM
# =========================================================


func _apply_model_transform(
	scale_value: float
) -> void:

	if battle_model == null:
		return


	var model_position: Vector3

	var model_rotation: Vector3

	var model_scale: Vector3


	if is_enemy:

		model_position = enemy_model_position

		model_rotation = (
			enemy_model_rotation_degrees
		)

		model_scale = enemy_model_scale

	else:

		model_position = ally_model_position

		model_rotation = (
			ally_model_rotation_degrees
		)

		model_scale = ally_model_scale


	# Position correction.
	battle_model.position = model_position


	# FBX orientation correction.
	battle_model.rotation_degrees = (
		model_rotation
	)


	# Combatant scale multiplied by the model-specific
	# transform scale.
	battle_model.scale = (
		model_scale
		* scale_value
	)


# =========================================================
# COMIC SHADER
# =========================================================


func _apply_comic_shader_to_model(
	root: Node
) -> void:

	for child in root.get_children():

		if child is MeshInstance3D:

			_apply_comic_shader_to_mesh(
				child as MeshInstance3D
			)

		_apply_comic_shader_to_model(
			child
		)


func _apply_comic_shader_to_mesh(
	mesh_instance: MeshInstance3D
) -> void:

	if mesh_instance == null:
		return


	var mesh: Mesh = mesh_instance.mesh


	if mesh == null:
		return


	var surface_count: int = (
		mesh.get_surface_count()
	)


	for surface_index in range(
		surface_count
	):

		var original_material: Material = (
			mesh_instance.get_active_material(
				surface_index
			)
		)


		if original_material == null:

			original_material = (
				mesh.surface_get_material(
					surface_index
				)
			)


		if original_material == null:
			continue


		if original_material is BaseMaterial3D:

			var base_material := (
				original_material
				as BaseMaterial3D
			)


			var comic_material := (
				_make_comic_material(
					accent
				)
			)


			base_material.next_pass = (
				comic_material
			)


func _make_comic_material(
	color: Color
) -> ShaderMaterial:

	var m: ShaderMaterial = (
		ShaderMaterial.new()
	)

	m.shader = PLAYER_SHADER

	m.set_shader_parameter(
		"black_color",
		BLACK
	)

	m.set_shader_parameter(
		"blue_color",
		color
	)

	m.set_shader_parameter(
		"blue_strength",
		0.9
	)


	var outline: ShaderMaterial = (
		ShaderMaterial.new()
	)

	outline.shader = OUTLINE_SHADER

	outline.set_shader_parameter(
		"outline_color",
		Color(
			1,
			1,
			1,
			1
		)
	)

	outline.set_shader_parameter(
		"outline_width",
		0.03
	)

	outline.set_shader_parameter(
		"outline_strength",
		1.0
	)


	m.next_pass = outline

	return m


# =========================================================
# FALLBACK BODY
# =========================================================


func _build_fallback_body(
	scale_value: float
) -> void:

	body = MeshInstance3D.new()

	var capsule: CapsuleMesh = (
		CapsuleMesh.new()
	)

	capsule.radius = (
		0.55 * scale_value
	)

	capsule.height = (
		1.9 * scale_value
	)

	body.mesh = capsule

	body.cast_shadow = (
		GeometryInstance3D
		.SHADOW_CASTING_SETTING_OFF
	)

	_body_base_y = (
		capsule.height * 0.5
	)

	body.position.y = _body_base_y

	body_material = _make_material(
		accent
	)

	body.material_override = (
		body_material
	)

	add_child(body)


# =========================================================
# ANIMATION
# =========================================================


func _find_animation_player(
	node: Node
) -> AnimationPlayer:

	if node is AnimationPlayer:

		return (
			node
			as AnimationPlayer
		)


	for child in node.get_children():

		var result: AnimationPlayer = (
			_find_animation_player(
				child
			)
		)

		if result != null:
			return result


	return null


func _play_battle_animation() -> void:

	if battle_animation_player == null:
		return


	var animation_list := (
		battle_animation_player
		.get_animation_list()
	)


	for animation_name in animation_list:

		if animation_name == "RESET":
			continue


		var animation := (
			battle_animation_player
			.get_animation(
				animation_name
			)
		)


		if animation != null:

			animation.loop_mode = (
				Animation.LOOP_LINEAR
			)


		battle_animation_player.play(
			animation_name
		)

		return


# =========================================================
# FALLBACK MATERIAL
# =========================================================


func _make_material(
	color: Color
) -> ShaderMaterial:

	var m: ShaderMaterial = (
		ShaderMaterial.new()
	)

	m.shader = PLAYER_SHADER

	m.set_shader_parameter(
		"black_color",
		BLACK
	)

	m.set_shader_parameter(
		"blue_color",
		color
	)

	m.set_shader_parameter(
		"blue_strength",
		0.9
	)


	var o: ShaderMaterial = (
		ShaderMaterial.new()
	)

	o.shader = OUTLINE_SHADER

	o.set_shader_parameter(
		"outline_color",
		Color(
			1,
			1,
			1,
			1
		)
	)

	o.set_shader_parameter(
		"outline_width",
		0.03
	)

	o.set_shader_parameter(
		"outline_strength",
		1.0
	)


	m.next_pass = o

	return m


# =========================================================
# PROCESS
# =========================================================


func _process(
	delta: float
) -> void:

	_time += delta

	_sync_alive_visual_state()


	if _marker_on and marker != null:

		var pulse: float = (
			1.0
			+
			sin(_time * 5.0)
			* 0.06
		)


		marker.scale = Vector3(
			pulse,
			0.08,
			pulse
		)


func _sync_alive_visual_state() -> void:

	if combatant == null:
		return


	var alive_now: bool = (
		combatant.is_alive
	)


	if alive_now == _last_alive_state:
		return


	_last_alive_state = alive_now


	if not alive_now:

		set_turn_marker(false)

		set_state(
			VisualState.DEFEATED
		)

	else:

		set_turn_marker(false)

		set_state(
			VisualState.IDLE
		)


# =========================================================
# TURN MARKER
# =========================================================


func set_turn_marker(
	on: bool
) -> void:

	_marker_on = on


	if marker != null:
		marker.visible = on


# =========================================================
# HIT FLASH
# =========================================================


func flash() -> void:

	# Imported ally materials remain untouched.
	#
	# Enemies still use body_material.

	if body_material == null:
		return


	body_material.set_shader_parameter(
		"black_color",
		Color(
			1,
			1,
			1,
			1
		)
	)


	body_material.set_shader_parameter(
		"blue_color",
		Color(
			1,
			1,
			1,
			1
		)
	)


	var t: Tween = create_tween()


	t.tween_interval(
		0.07
	)


	t.tween_callback(
		func() -> void:

			if body_material != null:

				body_material.set_shader_parameter(
					"black_color",
					BLACK
				)

				body_material.set_shader_parameter(
					"blue_color",
					accent
				)
	)


# =========================================================
# STATES
# =========================================================


func set_state(
	new_state: VisualState
) -> void:

	visual_state = new_state


	if _tween != null:
		_tween.kill()


	_tween = create_tween()


	# -----------------------------------------------------
	# IMPORTANT:
	#
	# DO NOT RESET BattleActor3D.rotation HERE.
	#
	# BattleRoom controls the actor's world-facing
	# direction using look_at().
	#
	# Previously this line:
	#
	#     rotation = Vector3.ZERO
	#
	# was destroying that facing every time a state changed.
	#
	# Position is still reset because attacks temporarily
	# move the actor forward/backward.
	# -----------------------------------------------------


	position = base_position


	# -----------------------------------------------------
	# FALLBACK BODY RESET
	# -----------------------------------------------------


	if body != null:

		body.position.y = _body_base_y

		body.scale = Vector3.ONE

		body.rotation = Vector3.ZERO


	# -----------------------------------------------------
	# IMPORTED MODEL RESET
	# -----------------------------------------------------
	#
	# Restore the model's transform correction instead of
	# blindly setting rotation/position/scale to zero.
	# -----------------------------------------------------


	if battle_model != null:

		_apply_model_transform(
			combatant.visual_scale
			if combatant != null
			else 1.0
		)


	match new_state:

		# =================================================
		# IDLE
		# =================================================


		VisualState.IDLE, VisualState.READY:

			if body != null:

				_tween.set_loops()


				_tween.tween_property(
					body,
					"position:y",
					_body_base_y + 0.06,
					0.9
				).set_trans(
					Tween.TRANS_SINE
				)


				_tween.tween_property(
					body,
					"position:y",
					_body_base_y,
					0.9
				).set_trans(
					Tween.TRANS_SINE
				)


		# =================================================
		# THINKING
		# =================================================


		VisualState.THINKING:

			if body != null:

				_tween.set_loops()


				_tween.tween_property(
					body,
					"rotation:z",
					0.10,
					0.35
				)


				_tween.tween_property(
					body,
					"rotation:z",
					-0.10,
					0.35
				)


		# =================================================
		# ATTACK WINDUP
		# =================================================


		VisualState.WINDUP:

			_tween.tween_property(
				self,
				"position",
				base_position
				-
				forward * 0.5,
				0.35
			)


		# =================================================
		# ATTACK
		# =================================================


		VisualState.ATTACK:

			_tween.tween_property(
				self,
				"position",
				base_position
				+
				forward * 1.4,
				0.10
			).set_trans(
				Tween.TRANS_EXPO
			)


			_tween.tween_interval(
				0.10
			)


			_tween.tween_property(
				self,
				"position",
				base_position,
				0.25
			)


		# =================================================
		# HIT
		# =================================================


		VisualState.HIT:

			_tween.tween_property(
				self,
				"position",
				base_position
				-
				forward * 0.35,
				0.05
			)


			_tween.tween_property(
				self,
				"position",
				base_position
				+
				forward * 0.1,
				0.06
			)


			_tween.tween_property(
				self,
				"position",
				base_position,
				0.08
			)


			_tween.tween_callback(
				func() -> void:

					if (
						combatant != null
						and
						not combatant.is_alive
					):

						set_state(
							VisualState.DEFEATED
						)

					elif (
						combatant != null
						and
						combatant.is_guarding
					):

						set_state(
							VisualState.GUARD
						)

					else:

						set_state(
							VisualState.IDLE
						)
			)


		# =================================================
		# GUARD
		# =================================================


		VisualState.GUARD:

			if body != null:

				_tween.tween_property(
					body,
					"scale",
					Vector3(
						1.12,
						0.84,
						1.12
					),
					0.15
				)


		# =================================================
		# RECOVER
		# =================================================


		VisualState.RECOVER:

			if body != null:

				_tween.tween_property(
					body,
					"scale",
					Vector3.ONE,
					0.25
				)


			_tween.tween_callback(
				func() -> void:

					if (
						combatant != null
						and
						not combatant.is_alive
					):

						set_state(
							VisualState.DEFEATED
						)

					else:

						set_state(
							VisualState.IDLE
						)
			)


		# =================================================
		# DEFEATED
		# =================================================


		VisualState.DEFEATED:

			set_turn_marker(false)


			if battle_model != null:

				_tween.tween_property(
					battle_model,
					"rotation:x",
					deg_to_rad(-85.0),
					0.30
				).set_trans(
					Tween.TRANS_BACK
				)


				_tween.parallel().tween_property(
					battle_model,
					"position:y",
					-0.50,
					0.30
				)


			elif body != null:

				_tween.tween_property(
					body,
					"rotation:x",
					deg_to_rad(-85.0),
					0.30
				).set_trans(
					Tween.TRANS_BACK
				)


				_tween.parallel().tween_property(
					body,
					"position:y",
					0.45,
					0.30
				)


		# =================================================
		# INTRO
		# =================================================


		VisualState.INTRO:

			if battle_model != null:

				# Preserve the configured model rotation
				# while doing the intro scale animation.

				battle_model.scale = Vector3(
					0.01,
					0.01,
					0.01
				)


				_tween.tween_property(
					battle_model,
					"scale",
					(
						ally_model_scale
						if not is_enemy
						else enemy_model_scale
					)
					*
					(
						combatant.visual_scale
						if combatant != null
						else 1.0
					),
					0.45
				).set_trans(
					Tween.TRANS_BACK
				).set_ease(
					Tween.EASE_OUT
				)


			elif body != null:

				body.scale = Vector3(
					0.01,
					0.01,
					0.01
				)


				_tween.tween_property(
					body,
					"scale",
					Vector3.ONE,
					0.45
				).set_trans(
					Tween.TRANS_BACK
				).set_ease(
					Tween.EASE_OUT
				)


			_tween.tween_callback(
				func() -> void:

					if (
						combatant != null
						and
						not combatant.is_alive
					):

						set_state(
							VisualState.DEFEATED
						)

					else:

						set_state(
							VisualState.IDLE
						)
			)


		# =================================================
		# VICTORY
		# =================================================


		VisualState.VICTORY:

			# Stay completely stationary.
			#
			# IMPORTANT:
			# Do NOT reset rotation here.
			#
			# The character keeps the direction assigned
			# by BattleRoom.

			position = base_position


			if battle_model != null:

				_apply_model_transform(
					combatant.visual_scale
					if combatant != null
					else 1.0
				)


			if body != null:

				body.position.y = _body_base_y

				body.scale = Vector3.ONE

				body.rotation = Vector3.ZERO


			# No victory tween.


		_:
			pass
