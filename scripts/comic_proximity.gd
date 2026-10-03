extends Node3D

@export var player_path: NodePath = NodePath(
	"../player"
)

@export var station_path: NodePath = NodePath(
	"../station_01"
)

@export var reaction_distance: float = 8.0

@export var full_reaction_distance: float = 2.0

@export var green_color: Color = Color(
	0.02,
	0.85,
	0.42,
	1.0
)

@export var blue_color: Color = Color(
	0.005,
	0.10,
	0.75,
	1.0
)

@export var outline_reaction_distance: float = 18.0

@export var outline_full_distance: float = 2.0

@export var outline_min_strength: float = 0.18

@export var outline_max_strength: float = 0.95

@export var outline_min_width: float = 0.006

@export var outline_max_width: float = 0.045

var player: Node3D = null
var station: Node = null


func _ready() -> void:
	player = get_node_or_null(
		player_path
	)

	station = get_node_or_null(
		station_path
	)

	if player == null:
		push_error(
			"ComicProximity: player not found: "
			+ str(player_path)
		)

	if station == null:
		push_error(
			"ComicProximity: station not found: "
			+ str(station_path)
		)


func _process(_delta: float) -> void:
	if player == null:
		return

	if station == null:
		return

	_update_objects()


func _update_objects() -> void:
	var meshes: Array[Node] = _get_meshes(
		station
	)

	for mesh_node: Node in meshes:
		var mesh := mesh_node as MeshInstance3D

		if mesh == null:
			continue

		var distance: float = _get_proximity_distance(
			mesh
		)

		var color_reaction: float = _calculate_reaction(
			distance,
			reaction_distance,
			full_reaction_distance
		)

		var outline_reaction: float = _calculate_reaction(
			distance,
			outline_reaction_distance,
			outline_full_distance
		)

		_update_mesh(
			mesh,
			color_reaction,
			outline_reaction
		)


func _get_proximity_distance(
	mesh: MeshInstance3D
) -> float:
	if _is_long_object(mesh):
		return player.global_position.distance_to(
			mesh.global_position
		)

	return _distance_to_mesh(
		mesh,
		player.global_position
	)


func _is_long_object(
	mesh: MeshInstance3D
) -> bool:
	var object_name: String = mesh.name.to_lower()

	var long_object_keywords: Array[String] = [
		"rail",
		"track",
		"wall",
		"ceiling",
		"beam",
		"floor",
		"tunnel",
		"platform"
	]

	for keyword: String in long_object_keywords:
		if object_name.contains(keyword):
			return true

	return false


func _calculate_reaction(
	distance: float,
	start_distance: float,
	full_distance: float
) -> float:
	if distance >= start_distance:
		return 0.0

	if distance <= full_distance:
		return 1.0

	return clamp(
		inverse_lerp(
			start_distance,
			full_distance,
			distance
		),
		0.0,
		1.0
	)


func _distance_to_mesh(
	mesh: MeshInstance3D,
	point: Vector3
) -> float:
	if mesh.mesh == null:
		return point.distance_to(
			mesh.global_position
		)

	var local_aabb: AABB = mesh.mesh.get_aabb()

	var local_point: Vector3 = mesh.to_local(
		point
	)

	var closest_local: Vector3 = Vector3(
		clamp(
			local_point.x,
			local_aabb.position.x,
			local_aabb.end.x
		),
		clamp(
			local_point.y,
			local_aabb.position.y,
			local_aabb.end.y
		),
		clamp(
			local_point.z,
			local_aabb.position.z,
			local_aabb.end.z
		)
	)

	var closest_world: Vector3 = mesh.to_global(
		closest_local
	)

	return point.distance_to(
		closest_world
	)


func _update_mesh(
	mesh: MeshInstance3D,
	color_reaction: float,
	outline_reaction: float
) -> void:
	if mesh.mesh == null:
		return

	var surface_count: int = (
		mesh.mesh.get_surface_count()
	)

	for surface_index: int in range(surface_count):
		var material: Material = (
			mesh.get_surface_override_material(
				surface_index
			)
		)

		if material == null:
			continue

		if material is ShaderMaterial:
			var shader_material: ShaderMaterial = (
				material as ShaderMaterial
			)

			var accent: Color = blue_color.lerp(
				green_color,
				color_reaction
			)

			shader_material.set_shader_parameter(
				"accent_color",
				accent
			)

			shader_material.set_shader_parameter(
				"accent_strength",
				color_reaction
			)

			var outline_material: ShaderMaterial = (
				shader_material.next_pass
				as ShaderMaterial
			)

			if outline_material != null:
				var outline_strength: float = lerp(
					outline_min_strength,
					outline_max_strength,
					outline_reaction
				)

				var outline_width: float = lerp(
					outline_min_width,
					outline_max_width,
					outline_reaction
				)

				outline_material.set_shader_parameter(
					"outline_strength",
					outline_strength
				)

				outline_material.set_shader_parameter(
					"outline_width",
					outline_width
				)


func _get_meshes(
	root: Node
) -> Array[Node]:
	var result: Array[Node] = []

	for child: Node in root.get_children():
		if child is MeshInstance3D:
			result.append(child)

		result.append_array(
			_get_meshes(child)
		)

	return result
