extends SceneTree

func _init() -> void:
	var s: Node = load("res://assets/station1_vibrant.glb").instantiate()
	for name in ["Ticket_Counter", "Broken_Turnstile", "Old_Bench_Seat", "Broken_Stair"]:
		var node: Node3D = s.get_node_or_null(name)
		if node:
			print(name, " pos=", node.position)
	quit()
