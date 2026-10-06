extends "res://cinematics.gd"

const ROOM_1_PATH: String = "res://room1.tscn"
const ROOM_2_PATH: String = "res://room2.tscn"
const BOSS_PATH: String = "res://battle_room.tscn"


func _start_cinematic() -> void:
	var requested_mode: CinematicMode = CinematicMode.OPENING

	if get_tree().has_meta("robruzz_cinematic_mode"):
		var stored_mode: Variant = get_tree().get_meta(
			"robruzz_cinematic_mode"
		)

		if stored_mode is int:
			var mode_value: int = int(stored_mode)

			if (
				mode_value >= int(CinematicMode.OPENING)
				and
				mode_value <= int(CinematicMode.ENDING)
			):
				requested_mode = mode_value as CinematicMode

	get_tree().set_meta(
		"robruzz_cinematic_mode",
		int(requested_mode)
	)

	mode = requested_mode

	_bars_in()

	match mode:
		CinematicMode.OPENING:
			await _play_opening_flow()

		CinematicMode.TRAIN_ONE:
			await _play_train_one_flow()

		CinematicMode.TRAIN_TWO:
			await _play_train_two_flow()

		CinematicMode.ENDING:
			await _play_ending_flow()


func _play_opening_flow() -> void:
	_set_opening_visuals()
	_show_caption(CAPTION_OPENING)
	_shot_opening()

	await _play_dialogue(OPENING_DIALOGUE)

	await get_tree().create_timer(2.0).timeout

	await _go_to_scene(ROOM_1_PATH)


func _play_train_one_flow() -> void:
	_set_train_visuals(-41.0)
	_show_caption(CAPTION_TRAIN_ONE)
	_shot_train_one()

	await _play_dialogue(TRAIN_ONE_DIALOGUE)

	await get_tree().create_timer(1.5).timeout

	await _go_to_scene(ROOM_2_PATH)


func _play_train_two_flow() -> void:
	_set_train_visuals(34.0)
	_show_caption(CAPTION_TRAIN_TWO)
	_shot_train_two()

	await _play_dialogue(TRAIN_TWO_DIALOGUE)

	await get_tree().create_timer(2.0).timeout

	await _play_train_crash()

	get_tree().set_meta(
		"robruzz_active_encounter_id",
		"boss"
	)

	get_tree().set_meta(
		"robruzz_return_scene",
		"res://cinematics.tscn"
	)

	get_tree().set_meta(
		"robruzz_cinematic_mode",
		int(CinematicMode.ENDING)
	)

	await _go_to_scene(BOSS_PATH)


func _play_ending_flow() -> void:
	_set_ending_visuals()
	_show_caption(CAPTION_ENDING)
	_shot_ending()

	await _play_dialogue(ENDING_DIALOGUE)

	await get_tree().create_timer(5.0).timeout


func _play_train_crash() -> void:
	if camera_tween != null and camera_tween.is_valid():
		camera_tween.kill()

	var light_tween: Tween = create_tween()
	light_tween.set_parallel(true)

	if key_light != null:
		light_tween.tween_property(
			key_light,
			"light_energy",
			0.0,
			1.0
		)

	if blue_rim_light != null:
		light_tween.tween_property(
			blue_rim_light,
			"light_energy",
			0.0,
			1.0
		)

	await light_tween.finished

	await get_tree().create_timer(0.2).timeout

	var impact_origin: Vector3 = camera.position
	var impact_rotation: Vector3 = camera.rotation

	for i: int in range(10):
		var direction: Vector3 = Vector3(
			1.0 if i % 2 == 0 else -1.0,
			1.0 if i % 3 == 0 else -1.0,
			0.0
		)

		camera.position = (
			impact_origin
			+
			direction * 0.08
		)

		camera.rotation = (
			impact_rotation
			+
			Vector3(
				0.0,
				0.0,
				0.03 if i % 2 == 0 else -0.03
			)
		)

		await get_tree().create_timer(0.05).timeout

	camera.position = impact_origin
	camera.rotation = impact_rotation

	await get_tree().create_timer(0.4).timeout


func _go_to_scene(scene_path: String) -> void:
	if scene_path.is_empty():
		return

	if not ResourceLoader.exists(scene_path):
		push_error(
			"Cinematic flow scene not found: "
			+
			scene_path
		)
		return

	await SceneTransition.change_scene(
		scene_path
	)
