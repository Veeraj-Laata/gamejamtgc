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


const LIGHT_NEUTRAL: Color = Color(
	1.0,
	1.0,
	1.0,
	1.0
)

const LIGHT_LOW_ENERGY: Color = Color(
	0.15,
	1.0,
	0.25,
	1.0
)

const LIGHT_HIGH_ENERGY: Color = Color(
	1.0,
	0.12,
	0.12,
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

	var center_between: Vector3 = (
		ally_center + enemy_center
	) * 0.5

	var pivot_height: Vector3 = Vector3(
		0.0,
		0.9,
		0.0
	)

	_pivot = center_between + pivot_height

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


# =========================================================
# SKILL LIGHT ANIMATIONS
# =========================================================

func play_skill_effect(
	from_position: Vector3,
	to_position: Vector3,
	shot_color: Color,
	effect_type: BattleSkill.EffectType,
	skill_id: String
) -> void:
	match effect_type:
		BattleSkill.EffectType.DAMAGE:
			await _play_damage_effect(
				from_position,
				to_position,
				shot_color,
				skill_id
			)

		BattleSkill.EffectType.HEAL:
			await _play_heal_effect(
				to_position,
				shot_color
			)

		BattleSkill.EffectType.REVIVE:
			await _play_revive_effect(
				to_position,
				shot_color
			)

		BattleSkill.EffectType.BUFF_DEFENSE:
			await _play_buff_effect(
				to_position,
				shot_color
			)

		BattleSkill.EffectType.BUFF_OFFENSE:
			await _play_buff_effect(
				to_position,
				shot_color
			)

		BattleSkill.EffectType.DEBUFF_DEFENSE:
			await _play_debuff_effect(
				to_position,
				shot_color
			)

		BattleSkill.EffectType.DEBUFF_OFFENSE:
			await _play_debuff_effect(
				to_position,
				shot_color
			)

		BattleSkill.EffectType.GUARD:
			await _play_guard_effect(
				to_position,
				shot_color
			)

		_:
			return


# =========================================================
# DAMAGE
# =========================================================

func play_light_shot(
	from_position: Vector3,
	to_position: Vector3,
	shot_color: Color
) -> void:
	await _play_damage_effect(
		from_position,
		to_position,
		shot_color,
		BattleSkills.ATTACK
	)


func _play_damage_effect(
	from_position: Vector3,
	to_position: Vector3,
	shot_color: Color,
	skill_id: String
) -> void:
	var direction: Vector3 = (
		to_position -
		from_position
	)

	var distance: float = direction.length()

	if distance < 0.05:
		return

	direction = direction.normalized()

	# ---------------------------------------------------------
	# CHARGE
	# ---------------------------------------------------------

	var charge_position: Vector3 = (
		from_position +
		direction * 0.45 +
		Vector3.UP * 0.15
	)

	var charge_light: OmniLight3D = OmniLight3D.new()

	add_child(
		charge_light
	)

	charge_light.global_position = charge_position
	charge_light.light_color = shot_color
	charge_light.light_energy = 0.0
	charge_light.omni_range = 2.5

	var charge_mesh: MeshInstance3D = (
		MeshInstance3D.new()
	)

	add_child(
		charge_mesh
	)

	charge_mesh.global_position = charge_position

	var charge_sphere: SphereMesh = SphereMesh.new()

	charge_sphere.radius = 0.07
	charge_sphere.height = 0.14

	charge_mesh.mesh = charge_sphere

	var charge_material: StandardMaterial3D = (
		StandardMaterial3D.new()
	)

	charge_material.albedo_color = shot_color
	charge_material.emission_enabled = true
	charge_material.emission = shot_color
	charge_material.emission_energy_multiplier = 6.0

	charge_mesh.material_override = charge_material

	charge_mesh.scale = Vector3(
		0.35,
		0.35,
		0.35
	)

	var charge_tween: Tween = create_tween()

	charge_tween.set_parallel(true)

	charge_tween.tween_property(
		charge_mesh,
		"scale",
		Vector3(
			1.7,
			1.7,
			1.7
		),
		0.14
	)

	charge_tween.tween_property(
		charge_light,
		"light_energy",
		3.5,
		0.10
	)

	await charge_tween.finished


	# ---------------------------------------------------------
	# DETERMINE DOT COUNT
	# ---------------------------------------------------------

	var dot_count: int = 3

	if skill_id == BattleSkills.VIOLET_BULLETS:
		dot_count = 6

	elif skill_id == BattleSkills.MICROWAVE_MELT:
		dot_count = 5

	elif skill_id == BattleSkills.XXXRAY:
		dot_count = 1

	elif skill_id == BattleSkills.ULTRAVIOLET_VIOLENCE:
		dot_count = 2

	elif skill_id == BattleSkills.BOSS_CRUSH:
		dot_count = 1

	elif skill_id == BattleSkills.BOSS_XRAY:
		dot_count = 2

	elif skill_id == BattleSkills.BOSS_GAMMA:
		dot_count = 5

	elif skill_id == BattleSkills.RED_RAY:
		dot_count = 2

	elif skill_id == BattleSkills.BLUE_SHIFT:
		dot_count = 3

	elif skill_id == BattleSkills.VIOLET_FLASH:
		dot_count = 4

	elif skill_id == BattleSkills.INFRARED_BURN:
		dot_count = 3

	elif skill_id == BattleSkills.MICROWAVE_PULSE:
		dot_count = 5

	elif skill_id == BattleSkills.ULTRAVIOLET_CUT:
		dot_count = 3

	elif skill_id == BattleSkills.XRAY_BURST:
		dot_count = 4

	elif skill_id == BattleSkills.GAMMA_RAY:
		dot_count = 5


	# ---------------------------------------------------------
	# PROJECTILE
	# ---------------------------------------------------------

	var projectile_group: Node3D = Node3D.new()

	add_child(
		projectile_group
	)

	var start_position: Vector3 = (
		from_position +
		direction * 0.65 +
		Vector3.UP * 0.15
	)

	projectile_group.global_position = start_position


	for i: int in range(dot_count):
		var dot: MeshInstance3D = (
			MeshInstance3D.new()
		)

		projectile_group.add_child(
			dot
		)

		var sphere: SphereMesh = SphereMesh.new()

		var radius: float = 0.055

		if dot_count == 1:
			radius = 0.11

		elif i == 0:
			radius = 0.070

		elif i == 1:
			radius = 0.060

		else:
			radius = 0.050

		sphere.radius = radius
		sphere.height = radius * 2.0

		dot.mesh = sphere

		var material: StandardMaterial3D = (
			StandardMaterial3D.new()
		)

		material.albedo_color = shot_color
		material.emission_enabled = true
		material.emission = shot_color
		material.emission_energy_multiplier = 10.0

		dot.material_override = material

		dot.position = (
			-direction *
			(float(i) * 0.14)
		)


	var projectile_light: OmniLight3D = (
		OmniLight3D.new()
	)

	projectile_group.add_child(
		projectile_light
	)

	projectile_light.light_color = shot_color
	projectile_light.light_energy = 5.0
	projectile_light.omni_range = 2.5


	# ---------------------------------------------------------
	# FLIGHT
	# ---------------------------------------------------------

	var flight_time: float = (
		clampf(
			distance * 0.04,
			0.15,
			0.40
		)
	)

	var flight_tween: Tween = create_tween()

	flight_tween.set_trans(
		Tween.TRANS_QUAD
	)

	flight_tween.set_ease(
		Tween.EASE_IN
	)

	flight_tween.tween_property(
		projectile_group,
		"global_position",
		to_position +
		Vector3.UP * 0.15,
		flight_time
	)

	await flight_tween.finished


	# ---------------------------------------------------------
	# IMPACT FLASH
	# ---------------------------------------------------------

	var impact_light: OmniLight3D = (
		OmniLight3D.new()
	)

	add_child(
		impact_light
	)

	impact_light.global_position = (
		to_position +
		Vector3.UP * 0.15
	)

	impact_light.light_color = shot_color
	impact_light.light_energy = 9.0
	impact_light.omni_range = 3.0

	var impact_tween: Tween = create_tween()

	impact_tween.tween_property(
		impact_light,
		"light_energy",
		0.0,
		0.14
	)

	await impact_tween.finished

	charge_mesh.queue_free()
	charge_light.queue_free()
	projectile_group.queue_free()
	impact_light.queue_free()


# =========================================================
# HEAL
# =========================================================

func _play_heal_effect(
	position: Vector3,
	shot_color: Color
) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()

	add_child(
		ring
	)

	ring.global_position = (
		position +
		Vector3.UP * 0.1
	)

	var mesh: TorusMesh = TorusMesh.new()

	mesh.inner_radius = 0.15
	mesh.outer_radius = 0.23

	ring.mesh = mesh

	var material: StandardMaterial3D = (
		StandardMaterial3D.new()
	)

	material.albedo_color = shot_color
	material.emission_enabled = true
	material.emission = shot_color
	material.emission_energy_multiplier = 7.0

	ring.material_override = material

	ring.scale = Vector3(
		0.2,
		0.2,
		0.2
	)

	var light: OmniLight3D = OmniLight3D.new()

	add_child(
		light
	)

	light.global_position = (
		position +
		Vector3.UP * 0.6
	)

	light.light_color = shot_color
	light.light_energy = 0.0
	light.omni_range = 2.5

	var tween: Tween = create_tween()

	tween.set_parallel(true)

	tween.tween_property(
		ring,
		"scale",
		Vector3(
			2.5,
			2.5,
			2.5
		),
		0.35
	)

	tween.tween_property(
		ring,
		"rotation",
		Vector3(
			0.0,
			TAU,
			0.0
		),
		0.35
	)

	tween.tween_property(
		light,
		"light_energy",
		5.0,
		0.12
	)

	await tween.finished

	var fade: Tween = create_tween()

	fade.tween_property(
		light,
		"light_energy",
		0.0,
		0.18
	)

	await fade.finished

	ring.queue_free()
	light.queue_free()


# =========================================================
# REVIVE
# =========================================================

func _play_revive_effect(
	position: Vector3,
	shot_color: Color
) -> void:
	var effect_root: Node3D = Node3D.new()

	add_child(
		effect_root
	)

	effect_root.global_position = (
		position +
		Vector3.UP * 0.05
	)

	var ring: MeshInstance3D = MeshInstance3D.new()

	effect_root.add_child(
		ring
	)

	var ring_mesh: TorusMesh = TorusMesh.new()

	ring_mesh.inner_radius = 0.22
	ring_mesh.outer_radius = 0.32

	ring.mesh = ring_mesh

	var ring_material: StandardMaterial3D = (
		StandardMaterial3D.new()
	)

	ring_material.albedo_color = shot_color
	ring_material.emission_enabled = true
	ring_material.emission = shot_color
	ring_material.emission_energy_multiplier = 9.0

	ring.material_override = ring_material

	ring.scale = Vector3(
		0.15,
		0.15,
		0.15
	)

	var core: MeshInstance3D = MeshInstance3D.new()

	effect_root.add_child(
		core
	)

	core.position = Vector3(
		0.0,
		0.45,
		0.0
	)

	var core_mesh: SphereMesh = SphereMesh.new()

	core_mesh.radius = 0.10
	core_mesh.height = 0.20

	core.mesh = core_mesh

	var core_material: StandardMaterial3D = (
		StandardMaterial3D.new()
	)

	core_material.albedo_color = shot_color
	core_material.emission_enabled = true
	core_material.emission = shot_color
	core_material.emission_energy_multiplier = 12.0

	core.material_override = core_material

	core.scale = Vector3(
		0.25,
		0.25,
		0.25
	)

	var light: OmniLight3D = OmniLight3D.new()

	effect_root.add_child(
		light
	)

	light.position = Vector3(
		0.0,
		0.5,
		0.0
	)

	light.light_color = shot_color
	light.light_energy = 0.0
	light.omni_range = 3.5

	var rise: Tween = create_tween()

	rise.set_parallel(true)

	rise.tween_property(
		ring,
		"scale",
		Vector3(
			2.3,
			2.3,
			2.3
		),
		0.40
	)

	rise.tween_property(
		ring,
		"rotation",
		Vector3(
			0.0,
			TAU,
			0.0
		),
		0.55
	)

	rise.tween_property(
		core,
		"scale",
		Vector3(
			1.6,
			1.6,
			1.6
		),
		0.24
	)

	rise.tween_property(
		core,
		"position",
		Vector3(
			0.0,
			1.5,
			0.0
		),
		0.50
	)

	rise.tween_property(
		light,
		"light_energy",
		6.0,
		0.16
	)

	await rise.finished

	var release: Tween = create_tween()

	release.set_parallel(true)

	release.tween_property(
		ring,
		"scale",
		Vector3(
			3.0,
			3.0,
			3.0
		),
		0.18
	)

	release.tween_property(
		core,
		"scale",
		Vector3(
			0.0,
			0.0,
			0.0
		),
		0.18
	)

	release.tween_property(
		light,
		"light_energy",
		0.0,
		0.20
	)

	await release.finished

	effect_root.queue_free()


# =========================================================
# BUFF
# =========================================================

func _play_buff_effect(
	position: Vector3,
	shot_color: Color
) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()

	add_child(
		ring
	)

	ring.global_position = (
		position +
		Vector3.UP * 0.1
	)

	var mesh: TorusMesh = TorusMesh.new()

	mesh.inner_radius = 0.20
	mesh.outer_radius = 0.28

	ring.mesh = mesh

	var material: StandardMaterial3D = (
		StandardMaterial3D.new()
	)

	material.albedo_color = shot_color
	material.emission_enabled = true
	material.emission = shot_color
	material.emission_energy_multiplier = 8.0

	ring.material_override = material

	ring.scale = Vector3(
		0.25,
		0.25,
		0.25
	)

	var light: OmniLight3D = OmniLight3D.new()

	add_child(
		light
	)

	light.global_position = (
		position +
		Vector3.UP * 0.7
	)

	light.light_color = shot_color
	light.light_energy = 0.0
	light.omni_range = 2.8

	var tween: Tween = create_tween()

	tween.set_parallel(true)

	tween.tween_property(
		ring,
		"scale",
		Vector3(
			1.8,
			1.8,
			1.8
		),
		0.22
	)

	tween.tween_property(
		ring,
		"position",
		Vector3(
			0.0,
			1.0,
			0.0
		),
		0.35
	)

	tween.tween_property(
		ring,
		"rotation",
		Vector3(
			0.0,
			TAU,
			0.0
		),
		0.45
	)

	tween.tween_property(
		light,
		"light_energy",
		6.0,
		0.18
	)

	await tween.finished

	var fade: Tween = create_tween()

	fade.tween_property(
		light,
		"light_energy",
		0.0,
		0.22
	)

	await fade.finished

	ring.queue_free()
	light.queue_free()


# =========================================================
# DEBUFF
# =========================================================

func _play_debuff_effect(
	position: Vector3,
	shot_color: Color
) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()

	add_child(
		ring
	)

	ring.global_position = (
		position +
		Vector3.UP * 0.3
	)

	var mesh: TorusMesh = TorusMesh.new()

	mesh.inner_radius = 0.25
	mesh.outer_radius = 0.32

	ring.mesh = mesh

	var material: StandardMaterial3D = (
		StandardMaterial3D.new()
	)

	material.albedo_color = shot_color
	material.emission_enabled = true
	material.emission = shot_color
	material.emission_energy_multiplier = 8.0

	ring.material_override = material

	ring.scale = Vector3(
		2.2,
		2.2,
		2.2
	)

	var light: OmniLight3D = OmniLight3D.new()

	add_child(
		light
	)

	light.global_position = (
		position +
		Vector3.UP * 0.35
	)

	light.light_color = shot_color
	light.light_energy = 5.0
	light.omni_range = 2.5

	var tween: Tween = create_tween()

	tween.set_parallel(true)

	tween.tween_property(
		ring,
		"scale",
		Vector3(
			0.15,
			0.15,
			0.15
		),
		0.30
	)

	tween.tween_property(
		ring,
		"rotation",
		Vector3(
			0.0,
			-TAU,
			0.0
		),
		0.30
	)

	tween.tween_property(
		light,
		"light_energy",
		0.0,
		0.30
	)

	await tween.finished

	ring.queue_free()
	light.queue_free()


# =========================================================
# GUARD
# =========================================================

func _play_guard_effect(
	position: Vector3,
	shot_color: Color
) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()

	add_child(
		ring
	)

	ring.global_position = (
		position +
		Vector3.UP * 0.7
	)

	var mesh: TorusMesh = TorusMesh.new()

	mesh.inner_radius = 0.45
	mesh.outer_radius = 0.55

	ring.mesh = mesh

	var material: StandardMaterial3D = (
		StandardMaterial3D.new()
	)

	material.albedo_color = shot_color
	material.emission_enabled = true
	material.emission = shot_color
	material.emission_energy_multiplier = 8.0

	ring.material_override = material

	ring.scale = Vector3(
		0.2,
		0.2,
		0.2
	)

	var light: OmniLight3D = OmniLight3D.new()

	add_child(
		light
	)

	light.global_position = (
		position +
		Vector3.UP * 0.7
	)

	light.light_color = shot_color
	light.light_energy = 0.0
	light.omni_range = 3.0

	var tween: Tween = create_tween()

	tween.set_parallel(true)

	tween.tween_property(
		ring,
		"scale",
		Vector3(
			1.5,
			1.5,
			1.5
		),
		0.25
	)

	tween.tween_property(
		ring,
		"rotation",
		Vector3(
			0.0,
			TAU,
			0.0
		),
		0.50
	)

	tween.tween_property(
		light,
		"light_energy",
		5.0,
		0.18
	)

	await tween.finished

	var fade: Tween = create_tween()

	fade.set_parallel(true)

	fade.tween_property(
		ring,
		"scale",
		Vector3(
			1.1,
			1.1,
			1.1
		),
		0.18
	)

	fade.tween_property(
		light,
		"light_energy",
		0.0,
		0.18
	)

	await fade.finished

	ring.queue_free()
	light.queue_free()


# =========================================================
# CAMERA
# =========================================================

func _process(
	delta: float
) -> void:
	if not _ready_to_orbit:
		return

	if camera == null:
		return

	_t += delta

	_update_camera(
		delta
	)


func _update_camera(
	delta: float
) -> void:
	var yaw: float = (
		sin(
			_t * orbit_speed
		)
		*
		orbit_amount
	)

	var offset: Vector3 = (
		_base_offset.rotated(
			Vector3.UP,
			yaw
		)
	)

	offset *= (
		1.0
		+
		sin(
			_t * orbit_speed * 0.7
			+
			1.3
		)
		*
		0.04
	)

	offset.y += (
		sin(
			_t * orbit_speed * 1.3
			+
			0.6
		)
		*
		drift_amount
		*
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
		randf_range(
			-1.0,
			1.0
		)
		*
		trauma_squared
		*
		shake_strength
	)

	camera.v_offset = (
		randf_range(
			-1.0,
			1.0
		)
		*
		trauma_squared
		*
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
