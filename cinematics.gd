extends Node3D

enum CinematicMode {
	OPENING,
	TRAIN_ONE,
	TRAIN_TWO,
	ENDING
}

@export var mode: CinematicMode = CinematicMode.OPENING
@export_file("*.tscn") var battle_scene_path: String = "res://battle_room.tscn"
@export var auto_start: bool = true

# ============================================================
# CAMERA
# ============================================================

@export_category("Cinematic Camera")

@export var camera_position: Vector3 = Vector3(3.4, 1.65, 3.8)
@export var camera_fov: float = 42.0
@export var camera_look_at: Vector3 = Vector3(0.0, 1.35, 0.0)

# ============================================================
# TIMING
# ============================================================

const DIALOGUE_MIN_TIME: float = 5.0
const DIALOGUE_TIME_PER_LINE: float = 6.0

# ============================================================
# ASSETS
# ============================================================

const PLAYER_MODEL: String = (
	"res://assets/animations/"
	+ "smoking.fbx"
)

const FONT_PATH: String = "res://assets/font/Bangers-Regular.ttf"

# ============================================================
# COMIC LOOK
# ============================================================

const BAR_HEIGHT: float = 70.0

# Yellow caption boxes. Edit the text, or set to "" to hide.
const CAPTION_OPENING: String = "11:47 PM. THE SUBWAY."
const CAPTION_TRAIN_ONE: String = "THE TWIST BEGINS."
const CAPTION_TRAIN_TWO: String = "TOO QUIET."
const CAPTION_ENDING: String = "DAWN."

# Building heights for the background skyline.
const SKYLINE_HEIGHTS: Array = [
	5.0, 8.0, 6.0, 9.5, 4.5, 7.0, 10.0, 5.5, 8.0, 6.5, 7.5, 5.0
]

# Screen filter: crushes the picture into 3 inks with halftone dots.
const NOIR_SHADER: String = """
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

uniform vec3 shadow_color = vec3(0.02, 0.02, 0.07);
uniform vec3 mid_color = vec3(0.12, 0.20, 0.55);
uniform vec3 light_color = vec3(0.93, 0.96, 1.0);
uniform float gain = 1.5;
uniform float dot_density = 70.0;
uniform float halftone_amount = 1.0;
uniform float vignette = 0.6;
uniform float grain = 0.05;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 src = texture(screen_tex, SCREEN_UV).rgb;
	float lum = dot(src, vec3(0.299, 0.587, 0.114));
	float t = lum * gain;

	// Dark edges, like an inked panel.
	float edge = length(SCREEN_UV - 0.5) * 1.4142;
	t *= 1.0 - vignette * smoothstep(0.45, 1.0, edge);

	// Flickering film grain.
	float n = hash(floor(SCREEN_UV * vec2(240.0, 135.0)) + floor(TIME * 10.0)) - 0.5;
	t = clamp(t + n * grain, 0.0, 1.0);

	// Rotated halftone dot pattern.
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = SCREEN_UV * vec2(aspect, 1.0) * dot_density;
	float c = 0.70710678;
	p = mat2(vec2(c, -c), vec2(c, c)) * p;
	float h = length(fract(p) - 0.5) * 1.41421356;
	h = mix(0.5, h, halftone_amount);

	vec3 col;
	if (t < 0.5) {
		col = mix(shadow_color, mid_color, step(h, t * 2.0));
	} else {
		col = mix(mid_color, light_color, step(h, (t - 0.5) * 2.0));
	}

	// Preserve warm orange/red effects such as cigar smoke and ember.
	bool warm_effect = src.r > src.b * 1.35 && src.g > src.b * 1.15 && src.r > 0.45;

	if (warm_effect) {
		COLOR = vec4(src, 1.0);
	} else {
		COLOR = vec4(col, 1.0);
		};
	}
"""

# ============================================================
# DIALOGUE
# ============================================================
const OPENING_DIALOGUE: Array = [
	["Soulanki", "Control, we're at the subway entrance. Confirming the RIFT is still active."],
	["Control", "Confirmed. Last scan showed activity below the east platform."],
	["Soulanki", "Any civilians left inside?"],
	["Control", "None that we can detect. The station was cleared twenty minutes ago."],
	["Soulanki", "And the other teams?"],
	["Control", "Five agents went in before you. None came back."],
	["Soulanki", "Who's with me?"],
	["Control", "Aoryn and Feydor. Both are cleared for field work."],
	["Aoryn", "We're ready."],
	["Soulanki", "Stay close. Watch your output."],
	["Control", "Remember the TWIST protocol. The RIFT adapts to attacks it sees repeatedly."],
	["Soulanki", "Understood. We change attacks before it adapts."]
]

const TRAIN_ONE_DIALOGUE: Array = [
	["Soulanki", "Stop. Did you feel that?"],
	["Aoryn", "My last attack barely did anything."],
	["Soulanki", "That's the TWIST. It adapted."],
	["Feydor", "Then we switch attacks."],
	["Soulanki", "Yes. Don't give it enough data to adapt again."]
]

const TRAIN_TWO_DIALOGUE: Array = [
	["Soulanki", "Control, we're through the platform. Nothing here."],
	["Control", "Copy. I'm not reading any RIFT activity either."],
	["Feydor", "Nothing at all?"],
	["Control", "Nothing on the scanners."],
	["Soulanki", "That's not possible. We were tracking it less than a minute ago."],
	["Aoryn", "Could it have moved?"],
	["Control", "Possible. Hold position while I run another scan."],
	["Soulanki", "How long?"],
	["Control", "Thirty seconds."],
	["Soulanki", "...Something's wrong."]
]

const ENDING_DIALOGUE: Array = [
	["Control", "Soulanki, report."],
	["Soulanki", "Aoryn and Feydor are clear. RIFT is sealed. We're waiting for evac."],
	["Control", "Copy."],
	["Soulanki", "That's it?"],
	["Control", "What did you want? Applause?"],
	["Soulanki", "I was hoping for something more official."],
	["Control", "Fine. Your first command is officially over."],
	["Soulanki", "And?"],
	["Control", "You brought everyone back."],
	["Soulanki", "...Good."],
	["Control", "You sound surprised."],
	["Soulanki", "Just making sure you noticed."],
	["Control", "Get some sleep, Captain."],
	["Soulanki", "After the report."],
	["Control", "Of course. Wouldn't want you getting away that easily."]
]
# ============================================================
# RUNTIME
# ============================================================

var environment: Environment = null
var camera: Camera3D = null
var camera_tween: Tween = null
var key_light: DirectionalLight3D = null
var blue_rim_light: OmniLight3D = null

var player_character: Node3D = null

var silhouette_meshes: Array[MeshInstance3D] = []
var black_silhouette_material: StandardMaterial3D = null
var navy_silhouette_material: StandardMaterial3D = null

var opening_props: Node3D = null
var ending_props: Node3D = null
var train_props: Node3D = null

var snow_particles: GPUParticles3D = null
var cigar_smoke: GPUParticles3D = null
var cigar_tip_glow: OmniLight3D = null
var leaf_particles: GPUParticles3D = null

var noir_material: ShaderMaterial = null
var top_bar: ColorRect = null
var bottom_bar: ColorRect = null
var caption_panel: PanelContainer = null
var caption_label: Label = null

var dialogue_panel: Panel = null
var dialogue_name: Label = null
var dialogue_text: Label = null

# ============================================================
# READY
# ============================================================

func _ready() -> void:
	_build_world()
	_build_camera()
	_build_character()
	_build_ui()
	_apply_mode_visuals()

	if auto_start:
		call_deferred("_start_cinematic")

# ============================================================
# WORLD
# ============================================================

func _build_world() -> void:
	var world_environment: WorldEnvironment = WorldEnvironment.new()

	environment = Environment.new()

	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK

	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.08, 0.10, 0.18, 1.0)
	environment.ambient_light_energy = 0.35

	# The screen filter handles atmosphere, so no fog.
	environment.fog_enabled = false

	world_environment.environment = environment
	add_child(world_environment)

	# KEY LIGHT
	key_light = DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.light_color = Color(0.35, 0.50, 1.0, 1.0)
	key_light.light_energy = 0.7
	key_light.rotation_degrees = Vector3(-35.0, -35.0, 0.0)
	add_child(key_light)

	# RIM LIGHT (draws the thin edge-light on the silhouette)
	blue_rim_light = OmniLight3D.new()
	blue_rim_light.name = "RimLight"
	blue_rim_light.position = Vector3(-2.0, 2.5, -2.0)
	blue_rim_light.light_color = Color(0.30, 0.50, 1.0, 1.0)
	blue_rim_light.light_energy = 3.0
	blue_rim_light.omni_range = 7.0
	add_child(blue_rim_light)

	_build_props()
	_build_snow()
	_build_black_leaves()

# ============================================================
# PROP HELPERS (unshaded flat shapes)
# ============================================================

func _flat_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color

	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	return material

func _add_quad(
	parent: Node3D,
	size: Vector2,
	pos: Vector3,
	color: Color,
	flat_on_ground: bool = false
) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()

	var quad: QuadMesh = QuadMesh.new()
	quad.size = size
	quad.material = _flat_material(color)

	mesh_instance.mesh = quad
	mesh_instance.position = pos

	if flat_on_ground:
		mesh_instance.rotation_degrees = Vector3(-90.0, 0.0, 0.0)

	parent.add_child(mesh_instance)

	return mesh_instance

func _add_box(
	parent: Node3D,
	size: Vector3,
	pos: Vector3,
	color: Color
) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()

	var box: BoxMesh = BoxMesh.new()
	box.size = size
	box.material = _flat_material(color)

	mesh_instance.mesh = box
	mesh_instance.position = pos

	parent.add_child(mesh_instance)

	return mesh_instance

func _add_sphere(
	parent: Node3D,
	radius: float,
	pos: Vector3,
	color: Color
) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()

	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.material = _flat_material(color)

	mesh_instance.mesh = sphere
	mesh_instance.position = pos

	parent.add_child(mesh_instance)

	return mesh_instance

func _vertical_gradient(top: Color, bottom: Color) -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, top)
	gradient.set_color(1, bottom)

	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	texture.width = 4
	texture.height = 256

	return texture

func _add_textured_quad(
	parent: Node3D,
	size: Vector2,
	pos: Vector3,
	texture: Texture2D,
	use_alpha: bool,
	flat_on_ground: bool = false
) -> MeshInstance3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = texture

	if use_alpha:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()

	var quad: QuadMesh = QuadMesh.new()
	quad.size = size
	quad.material = material

	mesh_instance.mesh = quad
	mesh_instance.position = pos

	if flat_on_ground:
		mesh_instance.rotation_degrees = Vector3(-90.0, 0.0, 0.0)

	parent.add_child(mesh_instance)

	return mesh_instance

# Soft round glow (moon halo, lamp halo).
func _add_halo(parent: Node3D, pos: Vector3, size: float, color: Color) -> void:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))

	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256

	_add_textured_quad(parent, Vector2(size, size), pos, texture, true)

# ============================================================
# PROP PIECES
# ============================================================

# Subway entrance building: glowing opening in a black frame. No lettering.
func _make_entrance(parent: Node3D, glow: Color) -> void:
	var doorway: Node3D = Node3D.new()
	doorway.name = "SubwayEntrance"
	doorway.position = Vector3(0.0, 0.0, -2.8)
	parent.add_child(doorway)

	# The glowing opening.
	_add_quad(doorway, Vector2(3.0, 2.9), Vector3(0.0, 1.45, 0.0), glow)

	# Black frame: left, right, top.
	var black: Color = Color(0.0, 0.0, 0.0, 1.0)
	_add_box(doorway, Vector3(0.5, 3.3, 0.5), Vector3(-1.75, 1.65, 0.0), black)
	_add_box(doorway, Vector3(0.5, 3.3, 0.5), Vector3(1.75, 1.65, 0.0), black)
	_add_box(doorway, Vector3(4.0, 0.5, 0.5), Vector3(0.0, 3.05, 0.0), black)

func _make_lamp(parent: Node3D, pos: Vector3, glow: Color) -> void:
	var lamp: Node3D = Node3D.new()
	lamp.name = "Lamp"
	lamp.position = pos
	parent.add_child(lamp)

	var black: Color = Color(0.0, 0.0, 0.0, 1.0)

	_add_box(lamp, Vector3(0.12, 4.2, 0.12), Vector3(0.0, 2.1, 0.0), black)
	_add_box(lamp, Vector3(0.9, 0.1, 0.1), Vector3(-0.4, 4.2, 0.0), black)
	_add_sphere(lamp, 0.22, Vector3(-0.8, 4.05, 0.0), glow)
	_add_halo(lamp, Vector3(-0.8, 4.05, 0.1), 3.5, Color(glow.r, glow.g, glow.b, 0.55))

# Row of black buildings with a few lit windows.
func _make_skyline(parent: Node3D, window: Color, z: float) -> void:
	var black: Color = Color(0.0, 0.0, 0.0, 1.0)

	for i: int in range(16):
		var height: float = SKYLINE_HEIGHTS[i % SKYLINE_HEIGHTS.size()]
		var x: float = -17.0 + float(i) * 2.3

		_add_box(
			parent,
			Vector3(2.0, height, 1.5),
			Vector3(x, height * 0.5, z),
			black
		)

		for j: int in range(3):
			if (i * 3 + j * 2) % 5 != 0:
				continue

			var window_y: float = 1.5 + float(j) * 1.9

			if window_y > height - 0.8:
				continue

			var window_x: float = x + float((i + j) % 3) * 0.5 - 0.5

			_add_quad(
				parent,
				Vector2(0.3, 0.45),
				Vector3(window_x, window_y, z + 0.76),
				window
			)

# One full city set: gradient sky, ground, big moon/sun, skyline, entrance.
func _build_city_set(
	group: Node3D,
	sky_top: Color,
	sky_bottom: Color,
	ground: Color,
	orb_color: Color,
	orb_pos: Vector3,
	orb_radius: float,
	halo_color: Color,
	door_glow: Color,
	spill_color: Color,
	with_lamp: bool
) -> void:
	# Sky.
	_add_textured_quad(
		group,
		Vector2(70.0, 12.0),
		Vector3(0.0, 6.0, -18.0),
		_vertical_gradient(sky_top, sky_bottom),
		false
	)

	# Ground.
	_add_quad(
		group,
		Vector2(70.0, 50.0),
		Vector3(0.0, -0.01, -12.0),
		ground,
		true
	)

	# Moon or sun, with a glow.
	_add_sphere(group, orb_radius, orb_pos, orb_color)
	_add_halo(
		group,
		orb_pos + Vector3(0.0, 0.0, 0.3),
		orb_radius * 5.0,
		halo_color
	)

	# City.
	_make_skyline(group, Color(1.0, 0.95, 0.70, 1.0), -11.0)

	# Entrance building behind Soulanki.
	_make_entrance(group, door_glow)

	# Light spilling out onto the floor, fading toward the camera.
	_add_textured_quad(
		group,
		Vector2(3.2, 4.5),
		Vector3(0.0, 0.01, -0.55),
		_vertical_gradient(
			spill_color,
			Color(spill_color.r, spill_color.g, spill_color.b, 0.0)
		),
		true,
		true
	)

	if with_lamp:
		_make_lamp(group, Vector3(3.6, 0.0, -1.8), Color(1.0, 0.95, 0.75, 1.0))

# ============================================================
# PROPS (one group per look, shown or hidden by mode)
# ============================================================

func _build_props() -> void:
	opening_props = Node3D.new()
	opening_props.name = "OpeningProps"
	add_child(opening_props)

	ending_props = Node3D.new()
	ending_props.name = "EndingProps"
	add_child(ending_props)

	train_props = Node3D.new()
	train_props.name = "TrainProps"
	add_child(train_props)

	_build_opening_props()
	_build_ending_props()
	_build_train_props()

func _build_opening_props() -> void:
	# Night: giant pale moon, indigo sky fading to a cold glow at the horizon.
	_build_city_set(
		opening_props,
		Color(0.04, 0.04, 0.10, 1.0),
		Color(0.50, 0.52, 0.62, 1.0),
		Color(0.22, 0.24, 0.32, 1.0),
		Color(1.0, 1.0, 1.0, 1.0),
		Vector3(-4.0, 5.5, -16.0),
		2.8,
		Color(1.0, 1.0, 1.0, 0.45),
		Color(1.0, 0.97, 0.85, 1.0),
		Color(1.0, 1.0, 0.85, 0.75),
		true
	)

func _build_ending_props() -> void:
	# Dawn: huge low sun half-hidden behind the skyline.
	_build_city_set(
		ending_props,
		Color(0.10, 0.04, 0.08, 1.0),
		Color(0.85, 0.58, 0.25, 1.0),
		Color(0.30, 0.20, 0.12, 1.0),
		Color(1.0, 0.95, 0.80, 1.0),
		Vector3(3.5, 3.0, -16.0),
		4.0,
		Color(1.0, 0.85, 0.50, 0.5),
		Color(1.0, 0.95, 0.80, 1.0),
		Color(1.0, 0.90, 0.60, 0.75),
		false
	)

func _build_train_props() -> void:
	var group: Node3D = train_props

	# Long black train car.
	_add_box(
		group,
		Vector3(22.0, 2.8, 1.2),
		Vector3(0.0, 1.5, -3.2),
		Color(0.0, 0.0, 0.0, 1.0)
	)

	# Dim windows, high up so they never touch his head.
	for i: int in range(-5, 6):
		_add_quad(
			group,
			Vector2(1.2, 0.5),
			Vector3(float(i) * 2.0, 2.5, -2.58),
			Color(0.17, 0.17, 0.17, 1.0)
		)

	# One thin pale stripe along the car.
	_add_quad(
		group,
		Vector2(22.0, 0.1),
		Vector3(0.0, 0.75, -2.58),
		Color(0.95, 0.95, 1.0, 1.0)
	)

# Shows one set and turns it so "behind Soulanki" faces the camera.
func _show_set(which: Node3D, yaw_degrees: float) -> void:
	opening_props.visible = (which == opening_props)
	ending_props.visible = (which == ending_props)
	train_props.visible = (which == train_props)

	which.rotation_degrees = Vector3(0.0, yaw_degrees, 0.0)

# ============================================================
# SNOW
# ============================================================

func _build_snow() -> void:
	snow_particles = GPUParticles3D.new()

	snow_particles.name = "Snow"
	snow_particles.amount = 500
	snow_particles.lifetime = 7.0
	snow_particles.randomness = 0.4
	snow_particles.preprocess = 5.0

	snow_particles.visibility_aabb = AABB(
		Vector3(-10.0, -2.0, -10.0),
		Vector3(20.0, 14.0, 20.0)
	)

	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()

	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(7.0, 3.0, 7.0)
	process_material.direction = Vector3(0.0, -1.0, 0.0)
	process_material.spread = 15.0
	process_material.initial_velocity_min = 0.5
	process_material.initial_velocity_max = 1.3
	process_material.gravity = Vector3(0.0, -0.25, 0.0)
	process_material.scale_min = 0.35
	process_material.scale_max = 0.75

	snow_particles.process_material = process_material

	var snow_mesh: QuadMesh = QuadMesh.new()
	snow_mesh.size = Vector2(0.06, 0.06)

	var snow_material: StandardMaterial3D = StandardMaterial3D.new()
	snow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	snow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	snow_material.albedo_color = Color(1.0, 1.0, 1.0, 0.95)

	snow_mesh.material = snow_material
	snow_particles.draw_pass_1 = snow_mesh

	add_child(snow_particles)

# ============================================================
# BLACK LEAVES
# ============================================================

func _build_black_leaves() -> void:
	leaf_particles = GPUParticles3D.new()

	leaf_particles.name = "BlackLeaves"
	leaf_particles.amount = 60
	leaf_particles.lifetime = 7.0
	leaf_particles.randomness = 0.45
	leaf_particles.preprocess = 3.0

	leaf_particles.visibility_aabb = AABB(
		Vector3(-8.0, -2.0, -8.0),
		Vector3(16.0, 12.0, 16.0)
	)

	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()

	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(6.0, 3.0, 5.0)

	# Slow downward movement with sideways drift.
	process_material.direction = Vector3(0.15, -1.0, 0.05)
	process_material.spread = 22.0
	process_material.initial_velocity_min = 0.25
	process_material.initial_velocity_max = 0.65
	process_material.gravity = Vector3(0.0, -0.05, 0.0)
	process_material.angular_velocity_min = -1.5
	process_material.angular_velocity_max = 1.5
	process_material.scale_min = 0.7
	process_material.scale_max = 1.25

	leaf_particles.process_material = process_material

	var leaf_mesh: QuadMesh = QuadMesh.new()
	leaf_mesh.size = Vector2(0.14, 0.07)

	var leaf_material: StandardMaterial3D = StandardMaterial3D.new()
	leaf_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	leaf_material.albedo_color = Color.BLACK

	leaf_mesh.material = leaf_material
	leaf_particles.draw_pass_1 = leaf_mesh

	leaf_particles.visible = false

	add_child(leaf_particles)

# ============================================================
# CAMERA
# ============================================================

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "CinematicCamera"
	camera.position = camera_position
	camera.fov = camera_fov

	add_child(camera)

	camera.current = true
	camera.look_at(camera_look_at, Vector3.UP)

# Smooth, eased camera move with a slight dutch tilt (roll).
func _start_shot(
	from_pos: Vector3,
	to_pos: Vector3,
	look_from: Vector3,
	look_to: Vector3,
	fov_from: float,
	fov_to: float,
	tilt_from: float,
	tilt_to: float,
	duration: float
) -> void:
	if camera == null:
		return

	if camera_tween != null:
		camera_tween.kill()

	var update: Callable = func(t: float) -> void:
		camera.position = from_pos.lerp(to_pos, t)
		camera.fov = lerpf(fov_from, fov_to, t)
		camera.look_at(look_from.lerp(look_to, t), Vector3.UP)
		camera.rotate_object_local(
			Vector3(0.0, 0.0, 1.0),
			deg_to_rad(lerpf(tilt_from, tilt_to, t))
		)

	# Snap to the first frame of the shot.
	update.call(0.0)

	camera_tween = create_tween()
	camera_tween.set_trans(Tween.TRANS_SINE)
	camera_tween.set_ease(Tween.EASE_IN_OUT)
	camera_tween.tween_method(update, 0.0, 1.0, duration)

# Roughly how long a dialogue will run, so the shot lasts the whole scene.
func _estimate_dialogue_time(lines: Array) -> float:
	var total: float = 0.0

	for entry: Variant in lines:
		var dialogue_entry: Array = entry as Array

		if dialogue_entry.size() < 2:
			continue

		var length: float = float(str(dialogue_entry[1]).length())

		total += maxf(
			DIALOGUE_MIN_TIME,
			maxf(DIALOGUE_TIME_PER_LINE, length * 0.055)
		)

	return maxf(total, 4.0)

func _shot_opening() -> void:
	# Slow push-in, tilted a little.
	_start_shot(
		camera_position,
		Vector3(2.3, 1.55, 2.6),
		camera_look_at,
		Vector3(0.0, 1.45, 0.0),
		camera_fov,
		36.0,
		-4.0,
		-2.0,
		_estimate_dialogue_time(OPENING_DIALOGUE) + 2.0
	)

func _shot_train_one() -> void:
	# Low side angle, drifting closer, tilted the other way.
	_start_shot(
		Vector3(-3.0, 1.1, 3.4),
		Vector3(-2.3, 1.25, 2.7),
		Vector3(0.0, 1.3, 0.0),
		Vector3(0.0, 1.4, 0.0),
		40.0,
		36.0,
		6.0,
		3.0,
		_estimate_dialogue_time(TRAIN_ONE_DIALOGUE)
	)

func _shot_train_two() -> void:
	# Slow pull-out as unease builds, the tilt straightens.
	_start_shot(
		Vector3(1.6, 1.5, 2.4),
		Vector3(3.6, 1.7, 4.6),
		Vector3(0.0, 1.45, 0.0),
		Vector3(0.0, 1.3, 0.0),
		34.0,
		44.0,
		-5.0,
		0.0,
		_estimate_dialogue_time(TRAIN_TWO_DIALOGUE) + 3.0
	)

func _shot_ending() -> void:
	# Low heroic angle that rises slightly.
	_start_shot(
		Vector3(2.2, 0.8, 3.4),
		Vector3(2.7, 1.3, 3.9),
		Vector3(0.0, 1.5, 0.0),
		Vector3(0.0, 1.45, 0.0),
		40.0,
		42.0,
		3.0,
		0.0,
		_estimate_dialogue_time(ENDING_DIALOGUE) + 8.0
	)

# ============================================================
# SOULANKI
# ============================================================

func _build_character() -> void:
	player_character = _load_model(PLAYER_MODEL)

	if player_character == null:
		return

	player_character.name = "Soulanki"
	player_character.position = Vector3(0.0, 0.0, 0.0)

	# Face toward the existing cinematic camera.
	player_character.look_at(camera_position, Vector3.UP)

	add_child(player_character)

	_make_silhouette(player_character)

	var animation_player: AnimationPlayer = _find_animation_player(player_character)

	if animation_player != null:
		_play_first_animation(animation_player)

# Two silhouette looks: black (scenes 1 and 4), navy (scenes 2 and 3).
func _make_silhouette(root: Node) -> void:
	black_silhouette_material = StandardMaterial3D.new()
	black_silhouette_material.albedo_color = Color(0.0, 0.0, 0.0, 1.0)
	black_silhouette_material.roughness = 1.0
	black_silhouette_material.metallic_specular = 0.0
	black_silhouette_material.rim_enabled = true
	black_silhouette_material.rim = 1.0
	black_silhouette_material.rim_tint = 0.0

	# Navy glows on its own, so the screen filter turns it flat navy.
	navy_silhouette_material = StandardMaterial3D.new()
	navy_silhouette_material.albedo_color = Color(0.02, 0.04, 0.14, 1.0)
	navy_silhouette_material.roughness = 1.0
	navy_silhouette_material.metallic_specular = 0.0
	navy_silhouette_material.emission_enabled = true
	navy_silhouette_material.emission = Color(0.10, 0.20, 0.65, 1.0)
	navy_silhouette_material.emission_energy_multiplier = 1.0
	navy_silhouette_material.rim_enabled = true
	navy_silhouette_material.rim = 0.8
	navy_silhouette_material.rim_tint = 0.0

	silhouette_meshes.clear()
	_collect_meshes(root)
	_set_silhouette_style(false)
	_build_cigar_smoke(player_character)
	_build_cigar_tip(player_character)

func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		silhouette_meshes.append(node as MeshInstance3D)

	for child: Node in node.get_children():
		_collect_meshes(child)

func _set_silhouette_style(use_navy: bool) -> void:
	var material: StandardMaterial3D = black_silhouette_material

	if use_navy:
		material = navy_silhouette_material

	for mesh_instance: MeshInstance3D in silhouette_meshes:
		mesh_instance.material_override = material

# ============================================================
# MODEL
# ============================================================

func _load_model(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("Cinematic model not found: " + path)
		return null

	var packed_scene: PackedScene = load(path) as PackedScene

	if packed_scene == null:
		return null

	var instance: Node = packed_scene.instantiate()

	if instance is Node3D:
		return instance as Node3D

	instance.queue_free()

	return null

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer

	for child: Node in root.get_children():
		var found: AnimationPlayer = _find_animation_player(child)

		if found != null:
			return found

	return null

func _play_first_animation(animation_player: AnimationPlayer) -> void:
	if animation_player == null:
		return

	for animation_name: String in animation_player.get_animation_list():
		if animation_name == "RESET":
			continue

		var animation: Animation = animation_player.get_animation(animation_name)

		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR

		animation_player.play(animation_name, 0.15)

		return
# ============================================================
# CIGAR SMOKE
# ============================================================

func _build_cigar_smoke(root: Node3D) -> void:
	var skeleton: Skeleton3D = _find_skeleton(root)

	if skeleton == null:
		return

	var hand_bone: StringName = _find_cigar_hand_bone(skeleton)

	if hand_bone == StringName(""):
		return

	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.name = "CigarSmokeAttachment"
	attachment.bone_name = hand_bone
	attachment.position = Vector3(0.08, 0.10, 0.10)
	skeleton.add_child(attachment)

	cigar_smoke = GPUParticles3D.new()
	cigar_smoke.name = "CigarSmoke"

	# More particles, but each individual particle is smaller.
	cigar_smoke.amount = 30
	cigar_smoke.lifetime = 2.2
	cigar_smoke.randomness = 0.55
	cigar_smoke.preprocess = 1.0

	cigar_smoke.visibility_aabb = AABB(
		Vector3(-1.0, -0.5, -1.0),
		Vector3(2.0, 3.0, 2.0)
	)

	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()

	process_material.emission_shape = (
		ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	)
	process_material.emission_sphere_radius = 0.018

	process_material.direction = Vector3(0.0, 1.0, 0.0)
	process_material.spread = 24.0

	process_material.initial_velocity_min = 0.10
	process_material.initial_velocity_max = 0.24

	process_material.gravity = Vector3(
		0.0,
		0.035,
		0.0
	)

	# Smaller individual smoke particles.
	process_material.scale_min = 0.055
	process_material.scale_max = 0.13

	# Stronger warm yellow/orange.
	process_material.color = Color(
		0.18,
		0.18,
		0.18,
		0.70
	)

	cigar_smoke.process_material = process_material

	var smoke_mesh: QuadMesh = QuadMesh.new()

	# Smaller actual particle.
	smoke_mesh.size = Vector2(0.065, 0.065)

	var smoke_material: StandardMaterial3D = StandardMaterial3D.new()
	smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

	smoke_material.albedo_color = Color(
		0.18,
		0.18,
		0.18,
		0.60
	)

	smoke_material.no_depth_test = true

	smoke_mesh.material = smoke_material
	cigar_smoke.draw_pass_1 = smoke_mesh

	attachment.add_child(cigar_smoke)

# ============================================================
# CIGAR TIP
# ============================================================

func _build_cigar_tip(root: Node3D) -> void:
	var skeleton: Skeleton3D = _find_skeleton(root)

	if skeleton == null:
		return

	var hand_bone: StringName = _find_cigar_hand_bone(skeleton)

	if hand_bone == StringName(""):
		return

	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.name = "CigarTipAttachment"
	attachment.bone_name = hand_bone
	attachment.position = Vector3(0.08, 0.10, 0.10)

	skeleton.add_child(attachment)

	# Tiny glowing red ember.
	var ember: MeshInstance3D = MeshInstance3D.new()
	ember.name = "CigarRedTip"

	var ember_mesh: SphereMesh = SphereMesh.new()
	ember_mesh.radius = 0.025
	ember_mesh.height = 0.05

	var ember_material: StandardMaterial3D = StandardMaterial3D.new()
	ember_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_material.albedo_color = Color(
		1.0,
		0.03,
		0.005,
		1.0
	)
	ember_material.emission_enabled = true
	ember_material.emission = Color(
		1.0,
		0.02,
		0.005,
		1.0
	)
	ember_material.emission_energy_multiplier = 3.0

	ember_mesh.material = ember_material
	ember.mesh = ember_mesh

	attachment.add_child(ember)

	cigar_tip_glow = OmniLight3D.new()
	cigar_tip_glow.name = "CigarTipRedGlow"
	cigar_tip_glow.light_color = Color(
		1.0,
		0.05,
		0.01,
		1.0
	)
	cigar_tip_glow.light_energy = 0.35
	cigar_tip_glow.omni_range = 0.60

	attachment.add_child(cigar_tip_glow)


func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D

	for child: Node in root.get_children():
		var found: Skeleton3D = _find_skeleton(child)

		if found != null:
			return found

	return null


func _find_cigar_hand_bone(skeleton: Skeleton3D) -> StringName:
	var candidates: Array[String] = [
		"RightHand",
		"right_hand",
		"Right_Hand",
		"hand_r",
		"Hand.R",
		"mixamorig:RightHand",
		"mixamorig_RightHand",
		"RightHandBone"
	]

	for candidate: String in candidates:
		var index: int = skeleton.find_bone(candidate)

		if index >= 0:
			return skeleton.get_bone_name(index)

	for i: int in range(skeleton.get_bone_count()):
		var bone_name: String = str(
			skeleton.get_bone_name(i)
		).to_lower()

		if (
			"hand" in bone_name
			and (
				"right" in bone_name
				or ".r" in bone_name
				or "_r" in bone_name
			)
		):
			return skeleton.get_bone_name(i)

	return StringName("")

# ============================================================
# UI: screen filter, letterbox bars, caption, dialogue
# ============================================================

func _build_ui() -> void:
	# ---------- Layer 1: comic noir screen filter ----------
	var post_layer: CanvasLayer = CanvasLayer.new()
	post_layer.name = "NoirFilter"
	post_layer.layer = 1
	add_child(post_layer)

	var shader: Shader = Shader.new()
	shader.code = NOIR_SHADER

	noir_material = ShaderMaterial.new()
	noir_material.shader = shader

	var post_rect: ColorRect = ColorRect.new()
	post_rect.name = "NoirRect"
	post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_rect.material = noir_material
	post_layer.add_child(post_rect)

	# ---------- Layer 2: letterbox bars and caption ----------
	var bars_layer: CanvasLayer = CanvasLayer.new()
	bars_layer.name = "CinematicBars"
	bars_layer.layer = 2
	add_child(bars_layer)

	top_bar = ColorRect.new()
	top_bar.name = "TopBar"
	top_bar.color = Color.BLACK
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_bottom = 0.0
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars_layer.add_child(top_bar)

	bottom_bar = ColorRect.new()
	bottom_bar.name = "BottomBar"
	bottom_bar.color = Color.BLACK
	bottom_bar.anchor_left = 0.0
	bottom_bar.anchor_right = 1.0
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars_layer.add_child(bottom_bar)

	# Yellow comic caption box.
	caption_panel = PanelContainer.new()
	caption_panel.name = "CaptionBox"
	caption_panel.anchor_left = 0.0
	caption_panel.anchor_right = 0.0
	caption_panel.anchor_top = 0.0
	caption_panel.anchor_bottom = 0.0
	caption_panel.offset_left = 45.0
	caption_panel.offset_top = BAR_HEIGHT + 22.0
	caption_panel.rotation = deg_to_rad(-1.5)
	caption_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)

	var caption_style: StyleBoxFlat = StyleBoxFlat.new()
	caption_style.bg_color = Color(1.0, 0.88, 0.30, 1.0)
	caption_style.border_color = Color.BLACK
	caption_style.set_border_width_all(4)
	caption_style.content_margin_left = 16.0
	caption_style.content_margin_right = 16.0
	caption_style.content_margin_top = 8.0
	caption_style.content_margin_bottom = 6.0

	caption_panel.add_theme_stylebox_override("panel", caption_style)

	caption_label = Label.new()
	caption_label.name = "CaptionText"
	caption_label.add_theme_font_size_override("font_size", 28)
	caption_label.add_theme_color_override("font_color", Color.BLACK)

	caption_panel.add_child(caption_label)
	bars_layer.add_child(caption_panel)

	# ---------- Layer 3: dialogue ----------
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "CinematicUI"
	canvas.layer = 3
	add_child(canvas)

	# DIALOGUE PANEL
	dialogue_panel = Panel.new()
	dialogue_panel.name = "DialoguePanel"

	dialogue_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)

	dialogue_panel.anchor_left = 0.0
	dialogue_panel.anchor_right = 1.0
	dialogue_panel.anchor_top = 1.0
	dialogue_panel.anchor_bottom = 1.0

	dialogue_panel.offset_left = 35.0
	dialogue_panel.offset_right = -35.0
	dialogue_panel.offset_top = -180.0
	dialogue_panel.offset_bottom = -25.0

	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.005, 0.005, 0.008, 0.96)
	panel_style.border_color = Color(0.75, 0.82, 1.0, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.corner_radius_bottom_right = 16
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.75)
	panel_style.shadow_size = 10

	dialogue_panel.add_theme_stylebox_override("panel", panel_style)

	canvas.add_child(dialogue_panel)

	# MARGIN CONTAINER
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 25)
	margin.add_theme_constant_override("margin_right", 25)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)

	dialogue_panel.add_child(margin)

	# VERTICAL LAYOUT
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	margin.add_child(box)

	# SPEAKER
	dialogue_name = Label.new()
	dialogue_name.name = "DialogueName"
	dialogue_name.custom_minimum_size = Vector2(0.0, 38.0)
	dialogue_name.add_theme_font_size_override("font_size", 29)
	dialogue_name.add_theme_color_override("font_color", Color(0.35, 0.65, 1.0, 1.0))
	dialogue_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	box.add_child(dialogue_name)

	# TEXT
	dialogue_text = Label.new()
	dialogue_text.name = "DialogueText"
	dialogue_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_text.add_theme_font_size_override("font_size", 23)
	dialogue_text.add_theme_color_override("font_color", Color.WHITE)
	dialogue_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	dialogue_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_text.clip_text = false

	box.add_child(dialogue_text)

	# FONT
	var font: Font = null

	if ResourceLoader.exists(FONT_PATH):
		font = load(FONT_PATH) as Font

	if font != null:
		dialogue_name.add_theme_font_override("font", font)
		dialogue_text.add_theme_font_override("font", font)
		caption_label.add_theme_font_override("font", font)

	dialogue_panel.visible = false

# Letterbox bars slide in.
func _bars_in() -> void:
	if top_bar == null or bottom_bar == null:
		return

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(top_bar, "offset_bottom", BAR_HEIGHT, 1.0)
	tween.tween_property(bottom_bar, "offset_top", -BAR_HEIGHT, 1.0)

# Yellow caption box fades in, holds, fades out.
func _show_caption(text: String) -> void:
	if caption_panel == null or text == "":
		return

	caption_label.text = text
	caption_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)

	var tween: Tween = create_tween()
	tween.tween_property(caption_panel, "modulate:a", 1.0, 0.4)
	tween.tween_interval(4.0)
	tween.tween_property(caption_panel, "modulate:a", 0.0, 0.6)

# Sets the three inks and how strong the dots are.
func _set_noir_look(
	shadow: Color,
	mid: Color,
	light: Color,
	gain: float,
	dots: float,
	vignette: float,
	grain: float
) -> void:
	if noir_material == null:
		return

	noir_material.set_shader_parameter("shadow_color", Vector3(shadow.r, shadow.g, shadow.b))
	noir_material.set_shader_parameter("mid_color", Vector3(mid.r, mid.g, mid.b))
	noir_material.set_shader_parameter("light_color", Vector3(light.r, light.g, light.b))
	noir_material.set_shader_parameter("gain", gain)
	noir_material.set_shader_parameter("halftone_amount", dots)
	noir_material.set_shader_parameter("vignette", vignette)
	noir_material.set_shader_parameter("grain", grain)

# ============================================================
# VISUAL MODE
# ============================================================

func _apply_mode_visuals() -> void:
	match mode:
		CinematicMode.OPENING:
			_set_opening_visuals()

		CinematicMode.TRAIN_ONE:
			_set_train_visuals(-41.0)

		CinematicMode.TRAIN_TWO:
			_set_train_visuals(34.0)

		CinematicMode.ENDING:
			_set_ending_visuals()

func _set_opening_visuals() -> void:
	# Ink black, deep blue, pale ice. Full halftone dots.
	_set_noir_look(
		Color(0.02, 0.02, 0.07, 1.0),
		Color(0.12, 0.20, 0.55, 1.0),
		Color(0.93, 0.96, 1.0, 1.0),
		1.5,
		1.0,
		0.7,
		0.05
	)

	_show_set(opening_props, 42.0)
	_set_silhouette_style(false)

	if snow_particles != null:
		snow_particles.visible = true

	if leaf_particles != null:
		leaf_particles.visible = false

	if key_light != null:
		key_light.visible = true
		key_light.light_color = Color(0.35, 0.50, 1.0, 1.0)
		key_light.light_energy = 0.6

	if blue_rim_light != null:
		blue_rim_light.visible = true
		blue_rim_light.light_color = Color(0.30, 0.50, 1.0, 1.0)
		blue_rim_light.light_energy = 3.0

	if player_character != null:
		player_character.visible = true

func _set_train_visuals(yaw_degrees: float) -> void:
	# Black, navy, steel. No dots: flat, clean, almost no colour.
	_set_noir_look(
		Color(0.0, 0.0, 0.0, 1.0),
		Color(0.05, 0.10, 0.38, 1.0),
		Color(0.55, 0.68, 1.0, 1.0),
		2.0,
		0.0,
		0.8,
		0.03
	)

	_show_set(train_props, yaw_degrees)
	_set_silhouette_style(true)

	if snow_particles != null:
		snow_particles.visible = false

	if leaf_particles != null:
		leaf_particles.visible = false

	if key_light != null:
		key_light.visible = true
		key_light.light_color = Color(0.35, 0.50, 1.0, 1.0)
		key_light.light_energy = 0.4

	if blue_rim_light != null:
		blue_rim_light.visible = true
		blue_rim_light.light_color = Color(0.30, 0.45, 1.0, 1.0)
		blue_rim_light.light_energy = 1.5

	if player_character != null:
		player_character.visible = true

func _set_ending_visuals() -> void:
	# Ink maroon, blood orange, hot yellow. Full halftone dots.
	_set_noir_look(
		Color(0.07, 0.01, 0.04, 1.0),
		Color(0.88, 0.28, 0.10, 1.0),
		Color(1.0, 0.90, 0.45, 1.0),
		1.4,
		1.0,
		0.55,
		0.05
	)

	_show_set(ending_props, 33.0)
	_set_silhouette_style(false)

	if snow_particles != null:
		snow_particles.visible = false

	# Black leaves drifting across the bright sky.
	if leaf_particles != null:
		leaf_particles.visible = true

	if key_light != null:
		key_light.visible = true
		key_light.light_color = Color(1.0, 0.75, 0.40, 1.0)
		key_light.light_energy = 0.8

	if blue_rim_light != null:
		blue_rim_light.visible = true
		blue_rim_light.light_color = Color(1.0, 0.70, 0.35, 1.0)
		blue_rim_light.light_energy = 3.0

	if player_character != null:
		player_character.visible = true

# ============================================================
# CINEMATIC FLOW
# ============================================================

func _start_cinematic() -> void:
	_bars_in()

	match mode:
		CinematicMode.OPENING:
			await _play_opening()

		CinematicMode.TRAIN_ONE:
			await _play_train_one()

		CinematicMode.TRAIN_TWO:
			await _play_train_two()

		CinematicMode.ENDING:
			await _play_ending()

func _play_opening() -> void:
	_show_caption(CAPTION_OPENING)
	_shot_opening()

	await _play_dialogue(OPENING_DIALOGUE)

	await get_tree().create_timer(2.0).timeout

	# CUTSCENE 1 -> 2 -> 3 -> 4
	await _play_train_one()
	await _play_train_two()
	await _play_ending()

	# No fight.
	# No scene transition.

func _play_train_one() -> void:
	_set_train_visuals(-41.0)
	_show_caption(CAPTION_TRAIN_ONE)
	_shot_train_one()

	await _play_dialogue(TRAIN_ONE_DIALOGUE)

func _play_train_two() -> void:
	_set_train_visuals(34.0)
	_show_caption(CAPTION_TRAIN_TWO)
	_shot_train_two()

	await _play_dialogue(TRAIN_TWO_DIALOGUE)

	await get_tree().create_timer(3.0).timeout

func _play_ending() -> void:
	_set_ending_visuals()
	_show_caption(CAPTION_ENDING)
	_shot_ending()

	await _play_dialogue(ENDING_DIALOGUE)

	await get_tree().create_timer(8.0).timeout

# ============================================================
# DIALOGUE
# ============================================================

func _play_dialogue(lines: Array) -> void:
	if lines.is_empty():
		return

	dialogue_panel.visible = true

	for entry: Variant in lines:
		var dialogue_entry: Array = entry as Array

		if dialogue_entry.size() < 2:
			continue

		var speaker: String = str(dialogue_entry[0])
		var text_value: String = str(dialogue_entry[1])

		dialogue_name.text = speaker
		dialogue_text.text = ""

		if speaker.to_lower() == "control":
			dialogue_name.add_theme_color_override(
				"font_color",
				Color(0.55, 1.0, 0.60, 1.0)
			)
		elif speaker.to_lower() == "soulanki":
			dialogue_name.add_theme_color_override(
				"font_color",
				Color(0.35, 0.65, 1.0, 1.0)
			)
		else:
			dialogue_name.add_theme_color_override(
				"font_color",
				Color.WHITE
			)

		dialogue_panel.queue_redraw()

		await get_tree().process_frame

		# ====================================================
		# SMART TYPEWRITER
		# ====================================================

		var skipped: bool = false

		for i: int in range(1, text_value.length() + 1):
			dialogue_text.text = text_value.substr(0, i)

			var current_char: String = text_value.substr(i - 1, 1)
			var delay: float = 0.022

			# Natural speech pauses.
			if current_char == ".":
				delay = 0.11
			elif current_char == ",":
				delay = 0.055
			elif current_char == "!":
				delay = 0.12
			elif current_char == "?":
				delay = 0.12
			elif current_char == ":":
				delay = 0.07
			elif current_char == ";":
				delay = 0.065
			elif current_char == "-":
				delay = 0.045

			# ENTER / SPACE instantly finishes the current line.
			if Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_SPACE):
				dialogue_text.text = text_value
				skipped = true
				break

			await get_tree().create_timer(delay).timeout

		# ====================================================
		# WAIT FOR KEY RELEASE AFTER SKIPPING
		# ====================================================

		if skipped:
			while (
				Input.is_key_pressed(KEY_ENTER)
				or Input.is_key_pressed(KEY_SPACE)
			):
				await get_tree().process_frame

		# ====================================================
		# SMART HOLD TIME
		# ====================================================

		var character_count: float = float(text_value.length())

		var hold_time: float = clampf(
			2.15 + character_count * 0.018,
			2.5,
			4.0
		)

		await get_tree().create_timer(hold_time).timeout

	dialogue_panel.visible = false
