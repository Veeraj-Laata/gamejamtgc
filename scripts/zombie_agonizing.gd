extends Node3D

const CORRUPTION_SHADER_PATH: String = (
	"res://scripts/zombie_corruption.gdshader"
)

var animation_player: AnimationPlayer = null


func _ready() -> void:
	animation_player = _find_animation_player(self)

	_apply_zombie_material()

	_start_zombie_animation()

	_connect_to_battle_won()


# ============================================================
# ANIMATION
# ============================================================

func _start_zombie_animation() -> void:
	if animation_player == null:
		push_warning(
			"Zombie Agonizing: No AnimationPlayer found."
		)
		return

	var animations: PackedStringArray = (
		animation_player.get_animation_list()
	)

	print(
		"Zombie Agonizing animations: ",
		animations
	)

	if animations.is_empty():
		push_warning(
			"Zombie Agonizing: AnimationPlayer has no animations."
		)
		return

	var chosen_animation: StringName = (
		_find_agonizing_animation(
			animations
		)
	)

	print(
		"Zombie Agonizing playing: ",
		chosen_animation
	)

	var animation: Animation = (
		animation_player.get_animation(
			chosen_animation
		)
	)

	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR

	animation_player.play(
		chosen_animation
	)

	animation_player.advance(0.0)


func _find_animation_player(
	node: Node
) -> AnimationPlayer:

	if node is AnimationPlayer:
		return node as AnimationPlayer

	for child: Node in node.get_children():
		var result: AnimationPlayer = (
			_find_animation_player(child)
		)

		if result != null:
			return result

	return null


func _find_agonizing_animation(
	animations: PackedStringArray
) -> StringName:

	# Prefer an animation containing "agon".
	for animation_name: String in animations:
		var lower_name: String = (
			animation_name.to_lower()
		)

		if lower_name.contains("agon"):
			return animation_name

	# Otherwise look for pain/hurt/groan.
	for animation_name: String in animations:
		var lower_name: String = (
			animation_name.to_lower()
		)

		if (
			lower_name.contains("pain")
			or
			lower_name.contains("hurt")
			or
			lower_name.contains("groan")
		):
			return animation_name

	# Otherwise use idle.
	for animation_name: String in animations:
		var lower_name: String = (
			animation_name.to_lower()
		)

		if lower_name.contains("idle"):
			return animation_name

	# Final fallback.
	return animations[0]


# ============================================================
# ZOMBIE MATERIAL
# ============================================================

func _apply_zombie_material() -> void:
	var shader_file: Shader = load(
		CORRUPTION_SHADER_PATH
	)

	if shader_file == null:
		push_error(
			"Zombie Agonizing: Could not load shader: "
			+ CORRUPTION_SHADER_PATH
		)
		return

	_apply_material_to_meshes(
		self,
		shader_file
	)


func _apply_material_to_meshes(
	node: Node,
	shader_file: Shader
) -> void:

	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = (
			node as MeshInstance3D
		)

		if mesh_instance.mesh != null:

			var body_material := ShaderMaterial.new()

			body_material.shader = shader_file

			# Pitch black body.
			body_material.set_shader_parameter(
				"corruption_color",
				Color(
					0.0,
					0.0,
					0.0,
					1.0
				)
			)

			# No fancy distortion.
			body_material.set_shader_parameter(
				"distortion_strength",
				0.0
			)

			body_material.set_shader_parameter(
				"flicker_speed",
				0.0
			)

			# White comic outline.
			var outline_shader := Shader.new()

			outline_shader.code = """
shader_type spatial;

render_mode
	unshaded,
	cull_front,
	depth_draw_never;

uniform float outline_width = 0.015;

void vertex()
{
	VERTEX += NORMAL * outline_width;
}

void fragment()
{
	ALBEDO = vec3(1.0, 1.0, 1.0);
}
"""

			var outline_material := ShaderMaterial.new()

			outline_material.shader = outline_shader

			outline_material.set_shader_parameter(
				"outline_width",
				0.015
			)

			# White outline is rendered behind the black body.
			body_material.next_pass = outline_material

			# Override the entire imported material.
			# This makes sure the original FBX textures
			# cannot interfere with the black body.
			mesh_instance.material_override = body_material

	for child: Node in node.get_children():
		_apply_material_to_meshes(
			child,
			shader_file
		)


# ============================================================
# BATTLE WON
# ============================================================

func _connect_to_battle_won() -> void:
	var battle_controller: Node = (
		_find_battle_controller(
			get_tree().current_scene
		)
	)

	if battle_controller == null:
		print(
			"Zombie Agonizing: No battle controller found."
		)
		return

	if not battle_controller.has_signal(
		"battle_won"
	):
		print(
			"Zombie Agonizing: Battle controller has no battle_won signal."
		)
		return

	if not battle_controller.battle_won.is_connected(
		_on_battle_won
	):
		battle_controller.battle_won.connect(
			_on_battle_won
		)

	print(
		"Zombie Agonizing: Connected to battle_won."
	)


func _find_battle_controller(
	node: Node
) -> Node:

	if node == null:
		return null

	if node.has_signal(
		"battle_won"
	):
		return node

	for child: Node in node.get_children():
		var result: Node = (
			_find_battle_controller(
				child
			)
		)

		if result != null:
			return result

	return null


func _on_battle_won() -> void:
	print(
		"Zombie Agonizing: Battle won. Hiding zombie."
	)

	if animation_player != null:
		animation_player.stop()

	visible = false
