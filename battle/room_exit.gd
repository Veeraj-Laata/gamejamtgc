extends Area3D
class_name RoomExit

@export_file("*.tscn") var next_room_path: String = "res://room2.tscn"

@export var interaction_distance: float = 3.0

@export var required_encounter_ids: Array[String] = [
	"traversal_enemy_01",
	"traversal_enemy_02"
]

var player: CharacterBody3D = null
var player_in_range: bool = false
var requirements_met: bool = false
var _transitioned: bool = false

var engage_prompt: Label = null


func _ready() -> void:
	_find_player()
	_create_engage_prompt()


func _process(_delta: float) -> void:
	if _transitioned:
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

	requirements_met = _requirements_met()

	if player_in_range and requirements_met:
		_show_engage_prompt()
	else:
		_hide_engage_prompt()


func _unhandled_input(
	event: InputEvent
) -> void:
	if _transitioned:
		return

	if not player_in_range:
		return

	if not requirements_met:
		return

	if not event is InputEventKey:
		return

	var key: InputEventKey = (
		event as InputEventKey
	)

	if not key.pressed or key.echo:
		return

	var confirm: bool = (
		key.keycode == KEY_ENTER
		or
		key.keycode == KEY_KP_ENTER
		or
		key.keycode == KEY_SPACE
	)

	if not confirm:
		return

	_hide_engage_prompt()
	_transition_to_cinematic()


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
		var font: Font = load(font_path) as Font

		if font != null:
			engage_prompt.add_theme_font_override(
				"font",
				font
			)

	var bubble: StyleBoxFlat = StyleBoxFlat.new()

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


func _requirements_met() -> bool:
	if required_encounter_ids.is_empty():
		return true

	if not get_tree().has_meta(
		"robruzz_defeated_encounters"
	):
		return false

	var stored: Variant = get_tree().get_meta(
		"robruzz_defeated_encounters"
	)

	if not stored is Dictionary:
		return false

	var defeated: Dictionary = (
		stored as Dictionary
	)

	for encounter_id: String in required_encounter_ids:
		if not bool(
			defeated.get(
				encounter_id,
				false
			)
		):
			return false

	return true


func _transition_to_cinematic() -> void:
	if _transitioned:
		return

	const CINEMATICS_PATH: String = (
		"res://cinematics.tscn"
	)

	const TRAIN_ONE_MODE: int = 1

	if not ResourceLoader.exists(
		CINEMATICS_PATH
	):
		push_error(
			"RoomExit: cinematics scene not found."
		)
		return

	_transitioned = true

	_restore_party_to_full()

	get_tree().set_meta(
		"robruzz_cinematic_mode",
		TRAIN_ONE_MODE
	)

	await SceneTransition.change_scene(
		CINEMATICS_PATH
	)


func _restore_party_to_full() -> void:
	if not get_tree().has_meta(
		"robruzz_party_state"
	):
		return

	var stored: Variant = (
		get_tree().get_meta(
			"robruzz_party_state"
		)
	)

	if not stored is Array:
		return

	var state: Array = (
		stored as Array
	)

	for entry: Variant in state:
		if not entry is Dictionary:
			continue

		var data: Dictionary = (
			entry as Dictionary
		)

		if not data.has("max_hp"):
			continue

		if not data.has("max_lp"):
			continue

		var max_hp: int = int(
			data.get(
				"max_hp",
				0
			)
		)

		var max_lp: int = int(
			data.get(
				"max_lp",
				0
			)
		)

		data["hp"] = max_hp
		data["lp"] = max_lp

	get_tree().set_meta(
		"robruzz_party_state",
		state
	)
