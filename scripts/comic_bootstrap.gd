extends Node3D

const WORLD_SHADER: Shader = preload(
	"res://scripts/comic_world.gdshader"
)

const PLAYER_SHADER: Shader = preload(
	"res://scripts/comic_player.gdshader"
)

const OUTLINE_SHADER: Shader = preload(
	"res://scripts/comic_outline.gdshader"
)

const TRAIN_SHADER: Shader = preload(
	"res://scripts/comic_train.gdshader"
)

const BLACK: Color = Color(
	0.001,
	0.003,
	0.008,
	1.0
)

const BLUE: Color = Color(
	0.005,
	0.10,
	0.75,
	1.0
)

const GREEN: Color = Color(
	0.02,
	0.85,
	0.42,
	1.0
)

const WHITE: Color = Color(
	1.0,
	1.0,
	1.0,
	1.0
)


func _ready() -> void:
	_setup_environment()
	_apply_world_materials()
	_apply_train_materials()
	_setup_player()
	_restore_player_position()


func _setup_environment() -> void:
	var world_environment: WorldEnvironment = (
		get_node_or_null(
			"WorldEnvironment"
		)
	)

	if world_environment == null:
		push_warning(
			"Comic: WorldEnvironment not found."
		)
		return

	if world_environment.environment == null:
		push_warning(
			"Comic: WorldEnvironment has no Environment."
		)
		return

	var environment := world_environment.environment

	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color(
		0.005,
		0.025,
		0.12,
		1.0
	)
	environment.fog_light_energy = 1.0
	environment.fog_density = 0.95
	environment.fog_depth_begin = 3.0
	environment.fog_depth_end = 25.0
	environment.fog_depth_curve = 1.0
	environment.fog_sky_affect = 0.0


func _apply_world_materials() -> void:
	var station: Node = (
		get_node_or_null(
			"station_01"
		)
	)

	if station == null:
		push_warning(
			"Comic: station_01 not found."
		)
		return

	_apply_recursive(station)


func _apply_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		_apply_world_shader(
			node as MeshInstance3D
		)

	for child in node.get_children():
		_apply_recursive(child)


func _apply_world_shader(mesh: MeshInstance3D) -> void:
	if mesh.mesh == null:
		return

	var outline_material := _create_outline_material(
		0.015,
		0.0
	)

	var surface_count: int = (
		mesh.mesh.get_surface_count()
	)

	for surface_index in range(surface_count):
		var original_material: Material = (
			mesh.mesh.surface_get_material(
				surface_index
			)
		)

		var material := ShaderMaterial.new()
		material.shader = WORLD_SHADER

		material.set_shader_parameter(
			"black_color",
			BLACK
		)

		material.set_shader_parameter(
			"blue_color",
			BLUE
		)

		material.set_shader_parameter(
			"accent_color",
			GREEN
		)

		material.set_shader_parameter(
			"accent_strength",
			0.0
		)

		material.set_shader_parameter(
			"blue_amount",
			0.88
		)

		material.set_shader_parameter(
			"shadow_cutoff",
			0.06
		)

		material.set_shader_parameter(
			"light_cutoff",
			0.20
		)

		material.set_shader_parameter(
			"halftone_scale",
			85.0
		)

		material.set_shader_parameter(
			"dot_size",
			0.13
		)

		material.set_shader_parameter(
			"halftone_strength",
			0.16
		)

		material.set_shader_parameter(
			"animation_speed",
			0.75
		)

		material.set_shader_parameter(
			"blue_amount_animation",
			0.24
		)

		material.set_shader_parameter(
			"shadow_animation",
			0.055
		)

		material.set_shader_parameter(
			"light_animation",
			0.11
		)

		if original_material is BaseMaterial3D:
			var base_material := (
				original_material as BaseMaterial3D
			)

			var texture: Texture2D = (
				base_material.albedo_texture
			)

			if texture != null:
				material.set_shader_parameter(
					"albedo_tex",
					texture
				)

		# Keep the outline material available so proximity can disable the
		# extra outline draw call for distant geometry without rebuilding materials.
		material.set_meta("comic_outline_material", outline_material)
		material.next_pass = outline_material

		mesh.set_surface_override_material(
			surface_index,
			material
		)


func _apply_train_materials() -> void:
	var train: Node = (
		get_node_or_null(
			"train"
		)
	)

	if train == null:
		push_warning(
			"Comic: train not found."
		)
		return

	_apply_train_recursive(train)


func _apply_train_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		_apply_train_shader(
			node as MeshInstance3D
		)

	for child in node.get_children():
		_apply_train_recursive(child)


func _apply_train_shader(mesh: MeshInstance3D) -> void:
	if mesh.mesh == null:
		return

	var surface_count: int = (
		mesh.mesh.get_surface_count()
	)

	for surface_index in range(surface_count):
		var original_material: Material = (
			mesh.mesh.surface_get_material(
				surface_index
			)
		)

		var material := ShaderMaterial.new()
		material.shader = TRAIN_SHADER

		material.set_shader_parameter(
			"dark_color",
			Color(
				0.08,
				0.005,
				0.025,
				1.0
			)
		)

		material.set_shader_parameter(
			"pink_color",
			Color(
				1.0,
				0.03,
				0.32,
				1.0
			)
		)

		material.set_shader_parameter(
			"pulse_speed",
			0.45
		)

		material.set_shader_parameter(
			"min_strength",
			0.35
		)

		material.set_shader_parameter(
			"max_strength",
			0.75
		)

		if original_material is BaseMaterial3D:
			var base_material := (
				original_material as BaseMaterial3D
			)

			var texture: Texture2D = (
				base_material.albedo_texture
			)

			if texture != null:
				material.set_shader_parameter(
					"albedo_tex",
					texture
				)

		mesh.set_surface_override_material(
			surface_index,
			material
		)


func _create_outline_material(
	width: float,
	strength: float
) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = OUTLINE_SHADER

	material.set_shader_parameter(
		"outline_color",
		WHITE
	)

	material.set_shader_parameter(
		"outline_width",
		width
	)

	material.set_shader_parameter(
		"outline_strength",
		strength
	)

	return material


func _setup_player() -> void:
	var player: Node = (
		get_node_or_null(
			"player"
		)
	)

	if player == null:
		push_warning(
			"Comic: player not found."
		)
		return

	if player is MeshInstance3D:
		_apply_player_material(
			player as MeshInstance3D
		)
		return

	_apply_player_recursive(player)


func _apply_player_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		_apply_player_material(
			node as MeshInstance3D
		)

	for child in node.get_children():
		_apply_player_recursive(child)


func _apply_player_material(mesh: MeshInstance3D) -> void:
	var material := ShaderMaterial.new()
	material.shader = PLAYER_SHADER

	material.set_shader_parameter(
		"black_color",
		BLACK
	)

	material.set_shader_parameter(
		"blue_color",
		BLUE
	)

	material.set_shader_parameter(
		"blue_strength",
		0.85
	)

	var outline_material := _create_outline_material(
		0.018,
		1.0
	)

	material.next_pass = outline_material

	mesh.material_override = material


func _restore_player_position() -> void:
	if not get_tree().has_meta(
		"robruzz_return_transform"
	):
		return

	var stored_transform: Variant = get_tree().get_meta(
		"robruzz_return_transform"
	)

	if not stored_transform is Transform3D:
		push_warning(
			"Comic: stored player transform is invalid."
		)
		get_tree().remove_meta(
			"robruzz_return_transform"
		)
		return

	var player: Node3D = (
		get_node_or_null(
			"player"
		) as Node3D
	)

	if player == null:
		push_warning(
			"Comic: player not found while restoring position."
		)
		return

	player.global_transform = (
		stored_transform as Transform3D
	)

	get_tree().remove_meta(
		"robruzz_return_transform"
	)
