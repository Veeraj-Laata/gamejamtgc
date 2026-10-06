extends SceneTree

func _init() -> void:
	var wp: Node = load("res://webproof.tscn").instantiate()
	var station: Node3D = wp.get_node_or_null("station_01")
	var player: Node3D = wp.get_node_or_null("player")
	var train: Node3D = wp.get_node_or_null("train")
	print("PLAYER position: ", player.position)
	print("TRAIN position: ", train.position)
	print("STATION position: ", station.position, " rot: ", station.rotation)
	for name in ["Station_Floor", "Track_Bed", "Platform_Left", "Platform_Right", "Platform_Edge_Left", "Platform_Edge_Right", "Platform_Panel", "Rail_-2_0", "Rail_2_0"]:
		var node: Node3D = station.get_node_or_null(name)
		if node:
			var world_pos: Vector3 = station.transform * node.position
			print(name, " local=", node.position, " world=", world_pos)
	for name in ["invisblewall", "platform_edge_left_barrier", "platform_edge_right_barrier", "platform_floor_left", "platform_floor_right", "station_track_floor"]:
		var node: Node3D = wp.get_node_or_null(name)
		if node:
			print("COLLIDER: ", name, " pos=", node.position)
	quit()
