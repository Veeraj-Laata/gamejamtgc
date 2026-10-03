extends MeshInstance3D

@export var speed := 5.0

func _process(delta: float) -> void:
	var direction := Vector3.ZERO

	if Input.is_key_pressed(KEY_W):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_S):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_A):
		direction.z += 1.0
	if Input.is_key_pressed(KEY_D):
		direction.z -= 1.0

	if direction.length() > 0.0:
		direction = direction.normalized()
		position += direction * speed * delta
