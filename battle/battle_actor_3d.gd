class_name BattleActor3D
extends Node3D
## Runtime visual for one BattleCombatant. Placeholder capsule that uses the
## ORIGINAL comic_player + comic_outline shaders. Swap the body for a real
## model later: keep set_state() / flash() / set_turn_marker() and nothing else
## in the project needs to change.

const PLAYER_SHADER: Shader = preload("res://scripts/comic_player.gdshader")
const OUTLINE_SHADER: Shader = preload("res://scripts/comic_outline.gdshader")

const BLACK := Color(0.001, 0.002, 0.006, 1.0)
const PROTAGONIST_COLOR := Color(0.01, 0.16, 0.95, 1.0)
const COMPANION_COLOR := Color(1.0, 0.05, 0.42, 1.0)
const ENEMY_COLOR := Color(0.95, 0.02, 0.07, 1.0)

enum VisualState {
	IDLE, READY, THINKING, WINDUP, ATTACK, HIT, GUARD, RECOVER, DEFEATED, INTRO, VICTORY
}

var combatant: BattleCombatant = null
var is_enemy: bool = false
var spawn_index: int = 0
var visual_state: VisualState = VisualState.IDLE
var accent: Color = PROTAGONIST_COLOR

## direction toward the opposing side (set by the room), used for lunges
var forward: Vector3 = Vector3.RIGHT

var body: MeshInstance3D = null
var body_material: ShaderMaterial = null
var marker: MeshInstance3D = null

var base_position: Vector3 = Vector3.ZERO
var _tween: Tween = null
var _marker_on: bool = false
var _time: float = 0.0
var _body_base_y: float = 0.95


func setup(p_combatant: BattleCombatant, p_is_enemy: bool, p_index: int) -> void:
	combatant = p_combatant
	is_enemy = p_is_enemy
	spawn_index = p_index

	if is_enemy:
		accent = ENEMY_COLOR
	elif spawn_index == 0:
		accent = PROTAGONIST_COLOR
	else:
		accent = COMPANION_COLOR

	name = "Actor_" + combatant.character_name.replace(" ", "_")
	_build_visual()
	base_position = position
	set_state(VisualState.INTRO)


func _build_visual() -> void:
	var s: float = 1.0
	if combatant != null:
		s = combatant.visual_scale
	var enemy_scale: float = 0.9 if is_enemy else 1.0

	body = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.55 * s * enemy_scale
	capsule.height = 1.9 * s * enemy_scale
	body.mesh = capsule
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body_base_y = capsule.height * 0.5
	body.position.y = _body_base_y
	body_material = _make_material(accent)
	body.material_override = body_material
	add_child(body)

	# turn marker: thin flat ring on the ground
	marker = MeshInstance3D.new()
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.95 * s
	ring.outer_radius = 1.12 * s
	marker.mesh = ring
	marker.scale = Vector3(1.0, 0.08, 1.0)
	marker.position.y = 0.03
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm: StandardMaterial3D = StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(0.9, 0.95, 1.0, 1.0)
	marker.material_override = mm
	marker.visible = false
	add_child(marker)


func _make_material(color: Color) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = PLAYER_SHADER
	m.set_shader_parameter("black_color", BLACK)
	m.set_shader_parameter("blue_color", color)
	m.set_shader_parameter("blue_strength", 0.9)

	var o: ShaderMaterial = ShaderMaterial.new()
	o.shader = OUTLINE_SHADER
	o.set_shader_parameter("outline_color", Color(1, 1, 1, 1))
	o.set_shader_parameter("outline_width", 0.03)
	o.set_shader_parameter("outline_strength", 1.0)
	m.next_pass = o
	return m


func _process(delta: float) -> void:
	_time += delta
	if _marker_on and marker != null:
		var pulse: float = 1.0 + sin(_time * 5.0) * 0.06
		marker.scale = Vector3(pulse, 0.08, pulse)


func set_turn_marker(on: bool) -> void:
	_marker_on = on
	if marker != null:
		marker.visible = on


## quick white flash on hit
func flash() -> void:
	if body_material == null:
		return
	body_material.set_shader_parameter("black_color", Color(1, 1, 1, 1))
	body_material.set_shader_parameter("blue_color", Color(1, 1, 1, 1))
	var t: Tween = create_tween()
	t.tween_interval(0.07)
	t.tween_callback(func() -> void:
		if body_material != null:
			body_material.set_shader_parameter("black_color", BLACK)
			body_material.set_shader_parameter("blue_color", accent)
	)


# ---------------------------------------------------------
# STATES (all tween based placeholders)
# ---------------------------------------------------------

func set_state(new_state: VisualState) -> void:
	visual_state = new_state
	if _tween != null:
		_tween.kill()
	_tween = create_tween()

	position = base_position
	rotation = Vector3.ZERO
	if body != null:
		body.position.y = _body_base_y
		body.scale = Vector3.ONE
		body.rotation = Vector3.ZERO

	match new_state:
		VisualState.IDLE, VisualState.READY:
			_tween.set_loops()
			_tween.tween_property(body, "position:y", _body_base_y + 0.06, 0.9).set_trans(Tween.TRANS_SINE)
			_tween.tween_property(body, "position:y", _body_base_y, 0.9).set_trans(Tween.TRANS_SINE)
		VisualState.THINKING:
			_tween.set_loops()
			_tween.tween_property(body, "rotation:z", 0.10, 0.35)
			_tween.tween_property(body, "rotation:z", -0.10, 0.35)
		VisualState.WINDUP:
			_tween.tween_property(body, "scale", Vector3(0.88, 1.12, 0.88), 0.35)
			_tween.parallel().tween_property(self, "position", base_position - forward * 0.5, 0.35)
		VisualState.ATTACK:
			_tween.tween_property(self, "position", base_position + forward * 1.4, 0.10).set_trans(Tween.TRANS_EXPO)
			_tween.parallel().tween_property(body, "scale", Vector3(1.15, 0.9, 1.15), 0.10)
			_tween.tween_interval(0.10)
			_tween.tween_property(self, "position", base_position, 0.25)
			_tween.parallel().tween_property(body, "scale", Vector3.ONE, 0.25)
		VisualState.HIT:
			_tween.tween_property(self, "position", base_position - forward * 0.35, 0.05)
			_tween.tween_property(self, "position", base_position + forward * 0.1, 0.06)
			_tween.tween_property(self, "position", base_position, 0.08)
			_tween.tween_callback(func() -> void:
				if combatant != null and combatant.is_guarding:
					set_state(VisualState.GUARD)
				else:
					set_state(VisualState.IDLE)
			)
		VisualState.GUARD:
			_tween.tween_property(body, "scale", Vector3(1.12, 0.84, 1.12), 0.15)
		VisualState.RECOVER:
			_tween.tween_property(body, "scale", Vector3.ONE, 0.25)
			_tween.tween_callback(func() -> void: set_state(VisualState.IDLE))
		VisualState.DEFEATED:
			_tween.tween_property(body, "rotation:x", deg_to_rad(-85.0), 0.30).set_trans(Tween.TRANS_BACK)
			_tween.parallel().tween_property(body, "position:y", 0.45, 0.30)
			set_turn_marker(false)
		VisualState.INTRO:
			body.scale = Vector3(0.01, 0.01, 0.01)
			_tween.tween_property(body, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_tween.tween_callback(func() -> void: set_state(VisualState.IDLE))
		VisualState.VICTORY:
			_tween.set_loops()
			_tween.tween_property(body, "position:y", _body_base_y + 0.4, 0.22)
			_tween.tween_property(body, "position:y", _body_base_y, 0.22)
