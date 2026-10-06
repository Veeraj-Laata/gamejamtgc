class_name SceneTransition
extends RefCounted

const LAYER_NAME: String = "SceneTransitionLayer"
const FADE_NAME: String = "Fade"

const DEFAULT_FADE_TIME: float = 0.35


static func change_scene(
	scene_path: String,
	fade_time: float = DEFAULT_FADE_TIME
) -> void:
	var tree: SceneTree = (
		Engine.get_main_loop()
		as SceneTree
	)

	if tree == null:
		return

	if tree.root == null:
		return

	if scene_path.is_empty():
		push_error(
			"SceneTransition: scene path is empty."
		)
		return

	if not ResourceLoader.exists(scene_path):
		push_error(
			"SceneTransition: scene not found: "
			+
			scene_path
		)
		return

	var layer: CanvasLayer = (
		tree.root.get_node_or_null(
			LAYER_NAME
		)
		as CanvasLayer
	)

	if layer == null:
		layer = CanvasLayer.new()
		layer.name = LAYER_NAME
		layer.layer = 999

		tree.root.add_child(layer)

	var existing_fade: ColorRect = (
		layer.get_node_or_null(
			FADE_NAME
		)
		as ColorRect
	)

	if existing_fade != null:
		existing_fade.queue_free()

	var fade: ColorRect = ColorRect.new()
	fade.name = FADE_NAME

	fade.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	fade.color = Color(
		0.0,
		0.0,
		0.0,
		1.0
	)

	fade.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	fade.modulate.a = 0.0

	layer.add_child(fade)

	var safe_fade_time: float = max(
		fade_time,
		0.01
	)

	await _tween_alpha(
		fade,
		1.0,
		safe_fade_time
	)

	var error: Error = (
		tree.change_scene_to_file(
			scene_path
		)
	)

	if error != OK:
		push_error(
			"SceneTransition: failed to change scene: "
			+
			scene_path
			+
			" error="
			+
			str(error)
		)

		await _tween_alpha(
			fade,
			0.0,
			safe_fade_time
		)

		fade.queue_free()
		return

	# Keep the fade covering the screen while the
	# destination scene finishes entering the tree.
	await tree.process_frame
	await tree.process_frame

	await _tween_alpha(
		fade,
		0.0,
		safe_fade_time
	)

	fade.queue_free()


static func _tween_alpha(
	fade: ColorRect,
	target_alpha: float,
	duration: float
) -> void:
	if fade == null:
		return

	var tween: Tween = fade.create_tween()

	tween.tween_property(
		fade,
		"modulate:a",
		target_alpha,
		duration
	)

	await tween.finished
