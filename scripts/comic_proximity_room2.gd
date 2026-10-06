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
	0.01,
	0.45,
	0.58,
	1.0
)

@export var blue_color: Color = Color(
	0.60,
	0.015,
	0.04,
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
var meshes: Array[MeshInstance3D] = []
var update_timer: float = 0.0
var last_player_position: Vector3 = Vector3(INF, INF, INF)

# Proximity reactions are visual-only. Updating them every rendered frame was
# needlessly expensive in the browser, especially with many station meshes.
const UPDATE_INTERVAL: float = 0.08
const MIN_MOVE_DISTANCE_SQ: float = 0.0025


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

	if station != null:
		_cache_meshes(station)


func _process(delta: float) -> void:
	if player == null or meshes.is_empty():
		return

	update_timer += delta
	if update_timer < UPDATE_INTERVAL:
		return

	update_timer = 0.0
	var player_position := player.global_position
	if last_player_position != Vector3(INF, INF, INF):
		if player_position.distance_squared_to(last_player_position) < MIN_MOVE_DISTANCE_SQ:
			return

	last_player_position = player_position
	_update_objects(player_position)


func _cache_meshes(root: Node) -> void:
	meshes.clear()
	_collect_meshes(root)


func _collect_meshes(root: Node) -> void:
	for child: Node in root.get_children():
		if child is MeshInstance3D:
			meshes.append(child as MeshInstance3D)
		_collect_meshes(child)


func _update_objects(player_position: Vector3) -> void:
	for mesh: MeshInstance3D in meshes:
		if not is_instance_valid(mesh) or mesh.mesh == null:
			continue

		var distance: float = _get_proximity_distance(mesh, player_position)
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
		_update_mesh(mesh, color_reaction, outline_reaction)


func _get_proximity_distance(
	mesh: MeshInstance3D,
	player_position: Vector3
) -> float:
	if _is_long_object(mesh):
		return player_position.distance_to(mesh.global_position)

	return _distance_to_mesh(mesh, player_position)



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
				shader_material.get_meta(
					"comic_outline_material",
					null
				)
				as ShaderMaterial
			)

			# Distant environment outlines are visually negligible but cost a full
			# extra draw pass. Remove that pass until the object is close enough.
			if outline_material != null:
				if outline_reaction <= 0.02:
					shader_material.next_pass = null
				else:
					shader_material.next_pass = outline_material

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
