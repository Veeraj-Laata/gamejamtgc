extends CanvasGroup


const GRIT_SHADER: Shader = preload(
	"res://battle/ui/noir_ui_grit.gdshader"
)


var ui_root: Control = null


func _ready() -> void:
	# CanvasGroup is a Node2D-style canvas node, not a Control,
	# so there is no mouse_filter property here.

	# We do not need mipmaps for this effect.
	use_mipmaps = false

	# Keep the captured canvas region as tight as possible.
	clear_margin = 0.0
	fit_margin = 0.0

	var material_instance: ShaderMaterial = (
		ShaderMaterial.new()
	)

	material_instance.shader = GRIT_SHADER

	material_instance.set_shader_parameter(
		"threshold",
		0.48
	)

	material_instance.set_shader_parameter(
		"contrast",
		1.18
	)

	material_instance.set_shader_parameter(
		"fine_grain",
		0.055
	)

	material_instance.set_shader_parameter(
		"coarse_grain",
		0.16
	)

	material_instance.set_shader_parameter(
		"ink_breakup",
		0.16
	)

	material_instance.set_shader_parameter(
		"paper_breakup",
		0.08
	)

	material = material_instance

	call_deferred(
		"_attach_battle_ui"
	)


func _attach_battle_ui() -> void:
	var parent_node: Node = get_parent()

	if parent_node == null:
		return

	ui_root = parent_node.get_node_or_null(
		"BattleUIRoot"
	) as Control

	if ui_root == null:
		call_deferred(
			"_attach_battle_ui"
		)

		return

	ui_root.reparent(
		self
	)

	_resize_ui_root()

	var viewport: Viewport = get_viewport()

	if not viewport.size_changed.is_connected(
		_resize_ui_root
	):
		viewport.size_changed.connect(
			_resize_ui_root
	)


func _resize_ui_root() -> void:
	if ui_root == null:
		return

	var viewport_size: Vector2 = (
		get_viewport()
		.get_visible_rect()
		.size
	)

	ui_root.position = Vector2.ZERO
	ui_root.size = viewport_size
