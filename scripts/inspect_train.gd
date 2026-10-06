extends SceneTree

func _init() -> void:
	var wp: Node = load("res://webproof.tscn").instantiate()
	root.add_child(wp)
	var train: Node3D = wp.get_node_or_null("train")
	var player: Node3D = wp.get_node_or_null("player")
	print("PLAYER position: ", player.position)
	print("TRAIN position: ", train.position)
	var min_p := Vector3(99999, 99999, 99999)
	var max_p := Vector3(-99999, -99999, -99999)
	var count := 0
	var stack: Array[Node] = [train]
	while not stack.is_empty():
		var curr: Node = stack.pop_back()
		if curr is MeshInstance3D and curr.mesh:
			count += 1
			var aabb: AABB = curr.mesh.get_aabb()
			for i in range(8):
				var corner: Vector3 = curr.global_transform * aabb.get_endpoint(i)
				min_p.x = min(min_p.x, corner.x)
				min_p.y = min(min_p.y, corner.y)
				min_p.z = min(min_p.z, corner.z)
				max_p.x = max(max_p.x, corner.x)
				max_p.y = max(max_p.y, corner.y)
				max_p.z = max(max_p.z, corner.z)
		for c in curr.get_children():
			stack.append(c)
	print("Found meshes: ", count)
	print("TRAIN GLOBAL AABB min: ", min_p)
	print("TRAIN GLOBAL AABB max: ", max_p)
	quit()
