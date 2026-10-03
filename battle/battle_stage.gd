class_name BattleStage
extends Node


const GROUND_SHADER: Shader = preload(
	"res://battle/battle_ground.gdshader"
)


const FOG_COLOR: Color = Color(
	0.012,
	0.025,
	0.085,
	1.0
)


@export var fog_begin: float = 6.0
@export var fog_end: float = 34.0
@export var fog_curve: float = 1.6

@export var distance_scale: float = 1.0
@export var camera_back: float = 9.0
@export var camera_side: float = 10.5
@export var camera_height: float = 5.2
@export var camera_fov: float = 52.0

@export var orbit_amount: float = 0.30
@export var orbit_speed: float = 0.20
@export var drift_amount: float = 0.7
@export var shake_strength: float = 0.22


var camera: Camera3D = null
var world_env: WorldEnvironment = null
var ground: MeshInstance3D = null

var _pivot: Vector3 = Vector3.ZERO
var _base_offset: Vector3 = Vector3(
	-9.0,
	5.0,
	10.0
)

var _t: float = 0.0
var _trauma: float = 0.0
var _fov_punch: float = 0.0
var _ready_to_orbit: bool = false


func configure(
	p_camera: Camera3D,
	p_env: WorldEnvironment,
	p_ground: MeshInstance3D,
	ally_center: Vector3,
	enemy_center: Vector3
) -> void:
	camera = p_camera
	world_env = p_env
	ground = p_ground

	_build_environment()
	_build_ground()

	_pivot = (
		ally_center +
		enemy_center
	) * 0.5 + Vector3(
		0.0,
		0.9,
		0.0
	)

	var direction: Vector3 = (
		enemy_center -
		ally_center
	)

	direction.y = 0.0

	if direction.length() < 0.01:
		direction = Vector3.RIGHT

	direction = direction.normalized()

	var side: Vector3 = (
		direction.cross(
			Vector3.UP
	).normalized())

	_base_offset = (
		-direction * camera_back +
		side * camera_side
	) * distance_scale

	_base_offset.y = camera_height

	camera.current = true
	camera.fov = camera_fov
	camera.far = 160.0

	_ready_to_orbit = true

	_update_camera(0.0)


func _build_environment() -> void:
	if world_env == null:
		return

	var environment: Environment = Environment.new()

	environment.background_mode = (
		Environment.BG_COLOR
	)

	environment.background_color = FOG_COLOR

	environment.ambient_light_source = (
		Environment.AMBIENT_SOURCE_COLOR
	)

	environment.ambient_light_color = Color(
		0.02,
		0.03,
		0.08,
		1.0
	)

	environment.ambient_light_energy = 0.3

	environment.fog_enabled = true
	environment.fog_light_color = FOG_COLOR
	environment.fog_mode = (
		Environment.FOG_MODE_DEPTH
	)

	environment.fog_depth_begin = fog_begin
	environment.fog_depth_end = fog_end
	environment.fog_depth_curve = fog_curve
	environment.fog_density = 1.0
	environment.fog_sky_affect = 1.0

	environment.tonemap_mode = (
		Environment.TONE_MAPPER_LINEAR
	)

	environment.tonemap_exposure = 1.0

	world_env.environment = environment


func _build_ground() -> void:
	if ground == null:
		return

	var plane: PlaneMesh = PlaneMesh.new()

	plane.size = Vector2(
		320.0,
		320.0
	)

	ground.mesh = plane

	ground.transform = Transform3D(
		Basis(),
		Vector3(
			8.0,
			-0.01,
			0.0
		)
	)

	ground.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)

	var material: ShaderMaterial = (
		ShaderMaterial.new()
	)

	material.shader = GROUND_SHADER

	material.set_shader_parameter(
		"ground_color",
		Color(
			0.002,
			0.003,
			0.010,
			1.0
		)
	)

	material.set_shader_parameter(
		"line_color",
		Color(
			0.01,
			0.10,
			0.55,
			1.0
		)
	)

	material.set_shader_parameter(
		"cell",
		2.0
	)

	material.set_shader_parameter(
		"line_width",
		0.03
	)

	ground.material_override = material


func add_trauma(
	amount: float
) -> void:
	_trauma = minf(
		_trauma + amount,
		1.0
	)


func punch_fov(
	amount: float = 3.0
) -> void:
	_fov_punch = maxf(
		_fov_punch,
		amount
	)


func _process(
	delta: float
) -> void:
	if not _ready_to_orbit:
		return

	if camera == null:
		return

	_t += delta

	_update_camera(delta)


func _update_camera(
	delta: float
) -> void:
	var yaw: float = (
		sin(
			_t * orbit_speed
		) * orbit_amount
	)

	var offset: Vector3 = (
		_base_offset.rotated(
			Vector3.UP,
			yaw
		)
	)

	offset *= (
		1.0 +
		sin(
			_t * orbit_speed * 0.7 +
			1.3
		) * 0.04
	)

	offset.y += (
		sin(
			_t * orbit_speed * 1.3 +
			0.6
		) *
		drift_amount *
		0.25
	)

	camera.global_position = (
		_pivot +
		offset
	)

	camera.look_at(
		_pivot,
		Vector3.UP
	)

	_trauma = maxf(
		_trauma -
		delta * 1.8,
		0.0
	)

	var trauma_squared: float = (
		_trauma *
		_trauma
	)

	camera.h_offset = (
		randf_range(-1.0, 1.0) *
		trauma_squared *
		shake_strength
	)

	camera.v_offset = (
		randf_range(-1.0, 1.0) *
		trauma_squared *
		shake_strength
	)

	_fov_punch = maxf(
		_fov_punch -
		delta * 14.0,
		0.0
	)

	camera.fov = (
		camera_fov -
		_fov_punch
	)
