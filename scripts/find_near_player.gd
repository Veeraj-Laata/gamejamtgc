extends SceneTree

func _init() -> void:
	var wp: Node = load("res://webproof.tscn").instantiate()
	root.add_child(wp)
	var player: Node3D = wp.get_node_or_null("player")
	var ppos: Vector3 = player.position
	print("Player position: ", ppos)
	var stack: Array[Node] = [wp]
	while not stack.is_empty():
		var curr: Node = stack.pop_back()
		if curr is MeshInstance3D and curr.mesh:
			var aabb: AABB = curr.mesh.get_aabb()
			var min_pt := Vector3(99999, 99999, 99999)
			var max_pt := Vector3(-99999, -99999, -99999)
			for i in range(8):
				var pt: Vector3 = curr.global_transform * aabb.get_endpoint(i)
				min_pt.x = min(min_pt.x, pt.x)
				min_pt.y = min(min_pt.y, pt.y)
				min_pt.z = min(min_pt.z, pt.z)
				max_pt.x = max(max_pt.x, pt.x)
				max_pt.y = max(max_pt.y, pt.y)
				max_pt.z = max(max_pt.z, pt.z)
			if ppos.x >= min_pt.x - 2.0 and ppos.x <= max_pt.x + 2.0 and ppos.z >= min_pt.z - 2.0 and ppos.z <= max_pt.z + 2.0:
				print("NEAR MESH: ", curr.name, " of parent ", curr.get_parent().name, " [", min_pt, " to ", max_pt, "]")
		for c in curr.get_children():
			stack.append(c)
	quit()
