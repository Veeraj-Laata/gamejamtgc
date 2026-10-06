extends CharacterBody3D

# ============================================================
# PLAYER MOVEMENT
# ============================================================

@export var speed: float = 4.5

# How quickly the player reaches the target speed.
@export var acceleration: float = 18.0

# How quickly the player stops when no input is held.
@export var deceleration: float = 22.0

# How quickly the character turns toward movement direction.
@export var turn_speed: float = 12.0


# ============================================================
# CHARACTER MODELS
# ============================================================

@onready var idle_character: Node3D = $MainCharacterExplorationIdle
@onready var moving_character: Node3D = $MainCharacterExplorationMoving

@onready var idle_animation_player: AnimationPlayer = \
	$MainCharacterExplorationIdle/AnimationPlayer

@onready var moving_animation_player: AnimationPlayer = \
	$MainCharacterExplorationMoving/AnimationPlayer


# ============================================================
# STATE
# ============================================================

var is_moving: bool = false

var idle_base_rotation_y: float = 0.0
var moving_base_rotation_y: float = 0.0

var target_rotation_y: float = 0.0

# Prevents tiny input/noise from constantly switching animations.
const MOVEMENT_THRESHOLD := 0.05


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	# Enable Godot's physics interpolation.
	# This is important because CharacterBody3D moves on the
	# physics tick while the camera renders between physics ticks.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON

	idle_character.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	moving_character.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON

	idle_base_rotation_y = idle_character.rotation.y
	moving_base_rotation_y = moving_character.rotation.y

	target_rotation_y = idle_base_rotation_y

	_setup_animation(idle_animation_player)
	_setup_animation(moving_animation_player)

	_set_idle()


# ============================================================
# MOVEMENT
# ============================================================

func _physics_process(delta: float) -> void:
	var input_x := 0.0
	var input_z := 0.0

	# --------------------------------------------------------
	# INPUT
	# --------------------------------------------------------

	if Input.is_key_pressed(KEY_W):
		input_x -= 1.0

	if Input.is_key_pressed(KEY_S):
		input_x += 1.0

	if Input.is_key_pressed(KEY_A):
		input_z += 1.0

	if Input.is_key_pressed(KEY_D):
		input_z -= 1.0


	# --------------------------------------------------------
	# BUILD MOVEMENT DIRECTION
	# --------------------------------------------------------

	var direction := Vector3(input_x, 0.0, input_z)

	if direction.length_squared() > 1.0:
		direction = direction.normalized()


	# --------------------------------------------------------
	# ACCELERATE
	# --------------------------------------------------------

	if direction.length_squared() > MOVEMENT_THRESHOLD * MOVEMENT_THRESHOLD:

		var target_velocity := direction * speed

		velocity.x = move_toward(
			velocity.x,
			target_velocity.x,
			acceleration * delta
		)

		velocity.z = move_toward(
			velocity.z,
			target_velocity.z,
			acceleration * delta
		)

		_rotate_character(direction, delta)

		if not is_moving:
			is_moving = true
			_set_moving()


	# --------------------------------------------------------
	# DECELERATE
	# --------------------------------------------------------

	else:

		velocity.x = move_toward(
			velocity.x,
			0.0,
			deceleration * delta
		)

		velocity.z = move_toward(
			velocity.z,
			0.0,
			deceleration * delta
		)

		if is_moving and Vector2(velocity.x, velocity.z).length() < 0.05:

			velocity.x = 0.0
			velocity.z = 0.0

			is_moving = false

			_set_idle()


	# --------------------------------------------------------
	# MOVE
	# --------------------------------------------------------

	move_and_slide()


# ============================================================
# CHARACTER ROTATION
# ============================================================

func _rotate_character(direction: Vector3, delta: float) -> void:

	# Convert movement direction into a Y rotation.
	var desired_angle := atan2(direction.z, -direction.x)

	target_rotation_y = idle_base_rotation_y + desired_angle

	# Framerate-independent smoothing.
	var blend := 1.0 - exp(-turn_speed * delta)

	idle_character.rotation.y = lerp_angle(
		idle_character.rotation.y,
		target_rotation_y,
		blend
	)

	var moving_target := moving_base_rotation_y + desired_angle

	moving_character.rotation.y = lerp_angle(
		moving_character.rotation.y,
		moving_target,
		blend
	)


# ============================================================
# ANIMATION SETUP
# ============================================================

func _setup_animation(animation_player: AnimationPlayer) -> void:

	if animation_player == null:
		return

	for animation_name in animation_player.get_animation_list():

		if animation_name == "RESET":
			continue

		var animation := animation_player.get_animation(animation_name)

		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR


# ============================================================
# PLAY FIRST ANIMATION
# ============================================================

func _play_first_animation(animation_player: AnimationPlayer) -> void:

	if animation_player == null:
		return

	var animations := animation_player.get_animation_list()

	for animation_name in animations:

		if animation_name == "RESET":
			continue

		animation_player.play(animation_name, 0.12)

		return


# ============================================================
# IDLE
# ============================================================

func _set_idle() -> void:

	moving_character.visible = false

	if moving_animation_player != null:
		moving_animation_player.stop()

	idle_character.visible = true

	# Keep both models at the same facing direction.
	idle_character.rotation.y = moving_character.rotation.y

	if idle_animation_player != null:
		_play_first_animation(idle_animation_player)


# ============================================================
# MOVING
# ============================================================

func _set_moving() -> void:

	idle_character.visible = false

	if idle_animation_player != null:
		idle_animation_player.stop()

	moving_character.visible = true

	# Start moving from exactly the direction the idle model
	# was facing, rather than snapping to another rotation.
	moving_character.rotation.y = idle_character.rotation.y

	if moving_animation_player != null:
		_play_first_animation(moving_animation_player)
