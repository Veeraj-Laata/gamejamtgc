extends Area3D
class_name BattleTrigger

@export_file("*.tscn") var battle_scene_path: String = "res://battle_room.tscn"

@export var interaction_distance: float = 2.5

@export var encounter_id: String = "traversal_enemy_01"

@export var blocking_body_path: NodePath = NodePath(
	"BlockingBody"
)

@export var visual_mesh_path: NodePath = NodePath(
	"ZombieAgonizing"
)

var player: CharacterBody3D = null
var player_in_range: bool = false
var _triggered: bool = false

var engage_prompt: Label = null


func _ready() -> void:
	_find_player()
	_apply_defeated_state()
	_create_engage_prompt()


func _process(_delta: float) -> void:
	if _triggered:
		_hide_engage_prompt()
		return

	if player == null or not is_instance_valid(player):
		_find_player()

	if player == null:
		return

	var distance: float = (
		global_position.distance_to(
			player.global_position
		)
	)

	player_in_range = (
		distance <= interaction_distance
	)

	if player_in_range and not _is_defeated():
		_show_engage_prompt()
	else:
		_hide_engage_prompt()


func _unhandled_input(
	event: InputEvent
) -> void:
	if _triggered:
		return

	if not player_in_range:
		return

	if _is_defeated():
		return

	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey

	if not key_event.pressed:
		return

	if key_event.echo:
		return

	if (
		key_event.keycode == KEY_ENTER
		or
		key_event.keycode == KEY_KP_ENTER
	):
		_hide_engage_prompt()
		_trigger_battle()


# =========================================================
# ENGAGE PROMPT
# =========================================================

func _create_engage_prompt() -> void:
	engage_prompt = Label.new()

	engage_prompt.text = "press enter to engage"

	engage_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	engage_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	engage_prompt.add_theme_font_size_override(
		"font_size",
		26
	)

	engage_prompt.add_theme_color_override(
		"font_color",
		Color.BLACK
	)

	var font_path: String = (
		"res://assets/font/Bangers-Regular.ttf"
	)

	if ResourceLoader.exists(font_path):
		var font = load(font_path)

		if font != null:
			engage_prompt.add_theme_font_override(
				"font",
				font
			)

	# Comic bubble.
	var bubble := StyleBoxFlat.new()

	bubble.bg_color = Color(
		1.0,
		1.0,
		1.0,
		0.96
	)

	bubble.border_color = Color(
		0.0,
		0.0,
		0.0,
		1.0
	)

	bubble.set_border_width_all(4)

	bubble.corner_radius_top_left = 18
	bubble.corner_radius_top_right = 18
	bubble.corner_radius_bottom_left = 18
	bubble.corner_radius_bottom_right = 18

	bubble.shadow_color = Color(
		0.0,
		0.0,
		0.0,
		0.35
	)

	bubble.shadow_size = 5

	engage_prompt.add_theme_stylebox_override(
		"normal",
		bubble
	)

	engage_prompt.custom_minimum_size = Vector2(
		330.0,
		65.0
	)

	engage_prompt.set_anchors_preset(
		Control.PRESET_BOTTOM_RIGHT
	)

	engage_prompt.position = Vector2(
		-350.0,
		-100.0
	)

	engage_prompt.z_index = 100

	get_tree().current_scene.add_child(
		engage_prompt
	)

	engage_prompt.visible = false


func _show_engage_prompt() -> void:
	if engage_prompt == null:
		return

	engage_prompt.visible = true


func _hide_engage_prompt() -> void:
	if engage_prompt == null:
		return

	engage_prompt.visible = false


# =========================================================
# PLAYER
# =========================================================

func _find_player() -> void:
	var current_scene: Node = get_tree().current_scene

	if current_scene == null:
		return

	player = (
		current_scene.get_node_or_null(
			"player"
		)
		as CharacterBody3D
	)


# =========================================================
# BATTLE
# =========================================================

func _trigger_battle() -> void:
	if _triggered:
		return

	if player == null:
		return

	if _is_defeated():
		return

	if battle_scene_path.is_empty():
		push_error(
			"BattleTrigger: battle_scene_path is empty."
		)
		return

	if not ResourceLoader.exists(
		battle_scene_path
	):
		push_error(
			"BattleTrigger: battle scene not found: "
			+
			battle_scene_path
		)
		return

	if encounter_id.strip_edges().is_empty():
		push_error(
			"BattleTrigger: encounter_id is empty."
		)
		return

	_triggered = true

	get_tree().set_meta(
		"robruzz_return_transform",
		player.global_transform
	)

	get_tree().set_meta(
		"robruzz_return_scene",
		get_tree().current_scene.scene_file_path
	)

	get_tree().set_meta(
		"robruzz_active_encounter_id",
		encounter_id
	)

	await SceneTransition.change_scene(
		battle_scene_path
	)


# =========================================================
# DEFEAT STATE
# =========================================================

func _get_defeated_encounters() -> Dictionary:
	if not get_tree().has_meta(
		"robruzz_defeated_encounters"
	):
		var new_state: Dictionary = {}

		get_tree().set_meta(
			"robruzz_defeated_encounters",
			new_state
		)

		return new_state

	var stored: Variant = get_tree().get_meta(
		"robruzz_defeated_encounters"
	)

	if stored is Dictionary:
		return stored as Dictionary

	var reset_state: Dictionary = {}

	get_tree().set_meta(
		"robruzz_defeated_encounters",
		reset_state
	)

	return reset_state


func _is_defeated() -> bool:
	var defeated: Dictionary = (
		_get_defeated_encounters()
	)

	return bool(
		defeated.get(
			encounter_id,
			false
		)
	)


func _apply_defeated_state() -> void:
	var defeated: bool = _is_defeated()

	_set_blocking_collision_enabled(
		not defeated
	)

	_set_enemy_mesh_visible(
		not defeated
	)


func _set_blocking_collision_enabled(
	enabled: bool
) -> void:
	var blocking_body: Node = (
		get_node_or_null(
			blocking_body_path
		)
	)

	if blocking_body == null:
		push_warning(
			"BattleTrigger: blocking body not found."
		)
		return

	for child: Node in blocking_body.get_children():
		_set_collision_recursive(
			child,
			enabled
		)


func _set_collision_recursive(
	node: Node,
	enabled: bool
) -> void:
	if node is CollisionShape3D:
		var collision := (
			node as CollisionShape3D
		)

		collision.set_deferred(
			"disabled",
			not enabled
		)

	if node is CollisionPolygon3D:
		var polygon := (
			node as CollisionPolygon3D
		)

		polygon.set_deferred(
			"disabled",
			not enabled
		)

	for child: Node in node.get_children():
		_set_collision_recursive(
			child,
			enabled
		)


func _set_enemy_mesh_visible(
	visible_state: bool
) -> void:
	var enemy_mesh: Node = null

	if not visual_mesh_path.is_empty():
		enemy_mesh = get_node_or_null(
			visual_mesh_path
		)

	# Room scenes use ZombieAgonizing as the actual overworld
	# enemy node. Keep this fallback so an empty Inspector
	# override cannot break defeated-state persistence.
	if enemy_mesh == null:
		enemy_mesh = get_node_or_null(
			"ZombieAgonizing"
		)

	if enemy_mesh == null:
		push_warning(
			"BattleTrigger: zombie visual node not found."
		)
		return

	if enemy_mesh is CanvasItem:
		(
			enemy_mesh
			as CanvasItem
		).visible = visible_state
		return

	if enemy_mesh is Node3D:
		(
			enemy_mesh
			as Node3D
		).visible = visible_state
