extends SceneTree

func _init() -> void:
	var wp: Node = load("res://webproof.tscn").instantiate()
	var train: Node3D = wp.get_node_or_null("train")
	var player: Node3D = wp.get_node_or_null("player")
	print("Player pos: ", player.position)
	print("Train pos: ", train.position, " rot=", train.rotation, " scale=", train.scale)
	var min_w := Vector3(99999, 99999, 99999)
	var max_w := Vector3(-99999, -99999, -99999)
	var stack: Array[Node] = [train]
	while not stack.is_empty():
		var curr: Node = stack.pop_back()
		if curr is MeshInstance3D and curr.mesh:
			var aabb: AABB = curr.mesh.get_aabb()
			for i in range(8):
				var local_pt: Vector3 = curr.transform * aabb.get_endpoint(i)
				var pt: Vector3 = train.transform * local_pt
				min_w.x = min(min_w.x, pt.x)
				min_w.y = min(min_w.y, pt.y)
				min_w.z = min(min_w.z, pt.z)
				max_w.x = max(max_w.x, pt.x)
				max_w.y = max(max_w.y, pt.y)
				max_w.z = max(max_w.z, pt.z)
		for c in curr.get_children():
			stack.append(c)
	print("TRAIN WORLD MIN: ", min_w)
	print("TRAIN WORLD MAX: ", max_w)
	quit()
