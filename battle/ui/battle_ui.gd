class_name BattleUI
extends CanvasLayer
## Minimal monochrome battle HUD.
##
## Visual rules:
## - rectangular boxes only
## - black standby surfaces
## - white borders
## - white selection cursor
## - white/grey typography
## - procedural halftone inside panels
## - evenly distributed menu rows
##
## UI is kept lightweight for browser performance.


const FONT_PATH_BODY: String = (
	"res://assets/font/BarlowSemiCondensed-SemiBold.ttf"
)

const FONT_PATH_HEAVY: String = (
	"res://assets/font/BarlowSemiCondensed-Black.ttf"
)

const HALFTONE_SHADER: Shader = preload(
	"res://battle/ui/noir_panel_halftone.gdshader"
)


const UI_SCALE: float = 0.78


# =========================================================
# COLOURS
# =========================================================

const BLACK: Color = Color(
	0.0,
	0.0,
	0.0,
	1.0
)

const PANEL_BLACK: Color = Color(
	0.006,
	0.007,
	0.010,
	0.98
)

const WHITE: Color = Color(
	0.92,
	0.93,
	0.95,
	1.0
)

const SOFT_WHITE: Color = Color(
	0.70,
	0.72,
	0.76,
	1.0
)

const DIM_WHITE: Color = Color(
	0.40,
	0.42,
	0.46,
	1.0
)


# =========================================================
# ROOT
# =========================================================

var root: Control

var enemy_panel: Panel
var command_panel: Panel
var party_panel: Panel
var round_panel: Panel
var action_panel: Panel
var notice_panel: Panel
var result_panel: Panel

var enemy_content: VBoxContainer
var enemy_rows_box: VBoxContainer

var command_content: VBoxContainer
var command_rows_box: VBoxContainer
var command_hint_label: Label

var party_content: VBoxContainer
var party_rows_box: VBoxContainer

var round_label: Label
var turn_label: Label

var action_actor_label: Label
var action_label: Label

var notice_label: Label

var result_label: Label
var result_sub_label: Label

var action_tween: Tween
var notice_tween: Tween
var result_tween: Tween

var flash_rect: ColorRect

var controller: BattleController = null
var anchor_provider: Callable = Callable()

var font_body: Font = null
var font_heavy: Font = null


# =========================================================
# BATTLE STATE
# =========================================================

var combatants: Array[BattleCombatant] = []
var current_combatant: BattleCombatant = null

var menu_rows: Array[Button] = []
var target_markers: Array[Label] = []

var highlighted_targets: Array[BattleCombatant] = []

var row_lookup: Dictionary = {}


# =========================================================
# READY
# =========================================================

func _ready() -> void:
	layer = 10

	if ResourceLoader.exists(FONT_PATH_BODY):
		font_body = load(
			FONT_PATH_BODY
		) as Font

	if ResourceLoader.exists(FONT_PATH_HEAVY):
		font_heavy = load(
			FONT_PATH_HEAVY
		) as Font

	if font_heavy == null:
		font_heavy = font_body

	_build_ui()

	get_viewport().size_changed.connect(
		_layout_ui
	)

	call_deferred(
		"_layout_ui"
	)


# =========================================================
# CONTROLLER BINDING
# =========================================================

func bind(
	p_controller: BattleController,
	p_anchor_provider: Callable
) -> void:
	controller = p_controller
	anchor_provider = p_anchor_provider

	controller.battle_started.connect(
		_on_battle_started
	)

	controller.round_started.connect(
		_on_round_started
	)

	controller.turn_started.connect(
		_on_turn_started
	)

	controller.guard_cleared.connect(
		_on_guard_cleared
	)

	controller.turn_finished.connect(
		_on_turn_finished
	)

	controller.enemy_thinking.connect(
		_on_enemy_thinking
	)

	controller.action_started.connect(
		_on_action_started
	)

	controller.impact.connect(
		_on_impact
	)

	controller.heal_applied.connect(
		_on_heal
	)

	controller.buff_applied.connect(
		_on_buff
	)

	controller.debuff_applied.connect(
		_on_debuff
	)

	controller.guard_applied.connect(
		_on_guard
	)

	controller.self_damaged.connect(
		_on_self_damaged
	)

	controller.combatant_defeated.connect(
		_on_defeated
	)

	controller.status_expired.connect(
		_on_status_expired
	)

	controller.menu_updated.connect(
		_on_menu_updated
	)

	controller.target_highlight.connect(
		_on_target_highlight
	)

	controller.notice.connect(
		_on_notice
	)

	controller.battle_won.connect(
		_on_battle_won
	)

	controller.battle_lost.connect(
		_on_battle_lost
	)


# =========================================================
# BUILD
# =========================================================

func _build_ui() -> void:
	root = Control.new()

	root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	root.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	add_child(root)


	# -----------------------------------------------------
	# ENEMIES
	# -----------------------------------------------------

	enemy_panel = _make_panel(
		"EnemiesPanel",
		Vector2(
			470.0,
			190.0
		)
	)

	enemy_content = _make_content_box(
		enemy_panel
	)

	enemy_content.add_child(
		_make_heading(
			"enemies"
		)
	)

	enemy_rows_box = VBoxContainer.new()

	enemy_rows_box.add_theme_constant_override(
		"separation",
		12
	)

	enemy_rows_box.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	enemy_rows_box.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	enemy_rows_box.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	enemy_content.add_child(
		enemy_rows_box
	)


	# -----------------------------------------------------
	# COMMAND
	# -----------------------------------------------------

	command_panel = _make_panel(
		"CommandPanel",
		Vector2(
			330.0,
			270.0
		)
	)

	command_content = _make_content_box(
		command_panel
	)

	command_content.add_theme_constant_override(
		"separation",
		8
	)

	command_content.add_child(
		_make_heading(
			"command"
		)
	)

	command_rows_box = VBoxContainer.new()

	command_rows_box.name = (
		"CommandRows"
	)

	command_rows_box.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	command_rows_box.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	command_rows_box.add_theme_constant_override(
		"separation",
		6
	)

	command_rows_box.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	command_content.add_child(
		command_rows_box
	)

	command_hint_label = _make_label(
		"w s move   enter ok   esc back",
		12,
		DIM_WHITE,
		false
	)

	command_hint_label.name = (
		"CommandHint"
	)

	command_hint_label.custom_minimum_size = Vector2(
		0.0,
		30.0
	)

	command_content.add_child(
		command_hint_label
	)

	command_panel.visible = false


	# -----------------------------------------------------
	# PARTY
	# -----------------------------------------------------

	party_panel = _make_panel(
		"PartyPanel",
		Vector2(
			450.0,
			245.0
		)
	)

	party_content = _make_content_box(
		party_panel
	)

	party_content.add_theme_constant_override(
		"separation",
		8
	)

	party_content.add_child(
		_make_heading(
			"party"
		)
	)

	party_rows_box = VBoxContainer.new()

	party_rows_box.add_theme_constant_override(
		"separation",
		12
	)

	party_rows_box.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	party_rows_box.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	party_rows_box.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	party_content.add_child(
		party_rows_box
	)


	# -----------------------------------------------------
	# ROUND / TURN
	# -----------------------------------------------------

	round_panel = _make_panel(
		"RoundPanel",
		Vector2(
			235.0,
			82.0
		)
	)

	var round_box: VBoxContainer = _make_content_box(
		round_panel
	)

	round_box.add_theme_constant_override(
		"separation",
		0
	)

	round_label = _make_label(
		"round 1",
		15,
		DIM_WHITE,
		false
	)

	round_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)

	round_box.add_child(
		round_label
	)

	turn_label = _make_label(
		"",
		23,
		WHITE,
		true
	)

	turn_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)

	round_box.add_child(
		turn_label
	)


	# -----------------------------------------------------
	# ACTION
	# -----------------------------------------------------

	action_panel = _make_panel(
		"ActionPanel",
		Vector2(
			600.0,
			92.0
		)
	)

	var action_box: VBoxContainer = _make_content_box(
		action_panel
	)

	action_box.add_theme_constant_override(
		"separation",
		0
	)

	action_actor_label = _make_label(
		"",
		13,
		DIM_WHITE,
		false
	)

	action_actor_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	action_box.add_child(
		action_actor_label
	)

	action_label = _make_label(
		"",
		32,
		WHITE,
		true
	)

	action_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	action_box.add_child(
		action_label
	)

	action_panel.visible = false


	# -----------------------------------------------------
	# NOTICE
	# -----------------------------------------------------

	notice_panel = _make_panel(
		"NoticePanel",
		Vector2(
			280.0,
			58.0
		)
	)

	var notice_box: VBoxContainer = _make_content_box(
		notice_panel
	)

	notice_label = _make_label(
		"",
		19,
		WHITE,
		true
	)

	notice_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	notice_box.add_child(
		notice_label
	)

	notice_panel.visible = false


	# -----------------------------------------------------
	# RESULT
	# -----------------------------------------------------

	result_panel = _make_panel(
		"ResultPanel",
		Vector2(
			500.0,
			185.0
		)
	)

	var result_box: VBoxContainer = _make_content_box(
		result_panel
	)

	result_box.add_theme_constant_override(
		"separation",
		3
	)

	result_label = _make_label(
		"",
		62,
		WHITE,
		true
	)

	result_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	result_box.add_child(
		result_label
	)

	result_sub_label = _make_label(
		"enter restart",
		16,
		SOFT_WHITE,
		false
	)

	result_sub_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	result_box.add_child(
		result_sub_label
	)

	result_panel.visible = false


	# -----------------------------------------------------
	# HIT FLASH
	# -----------------------------------------------------

	flash_rect = ColorRect.new()

	flash_rect.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	flash_rect.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	flash_rect.color = Color(
		1.0,
		1.0,
		1.0,
		0.0
	)

	root.add_child(
		flash_rect
	)


	# -----------------------------------------------------
	# TARGET MARKERS
	# -----------------------------------------------------

	for i: int in 5:
		var marker: Label = _make_label(
			"[ ]",
			22,
			WHITE,
			true
		)

		marker.name = (
			"TargetMarker_%d"
			% i
		)

		marker.size = Vector2(
			70.0,
			32.0
		)

		marker.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)

		marker.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

		marker.visible = false

		root.add_child(
			marker
		)

		target_markers.append(
			marker
		)


# =========================================================
# PANEL HELPERS
# =========================================================

func _make_panel(
	panel_name: String,
	panel_size: Vector2
) -> Panel:
	var panel: Panel = Panel.new()

	panel.name = panel_name

	panel.size = panel_size
	panel.custom_minimum_size = panel_size

	panel.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style()
	)

	root.add_child(
		panel
	)

	_add_halftone(
		panel
	)

	return panel


func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()

	style.bg_color = PANEL_BLACK

	style.border_color = WHITE

	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2

	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0

	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0

	return style


func _add_halftone(
	panel: Panel
) -> void:
	var dots: ColorRect = ColorRect.new()

	dots.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	dots.position = Vector2.ZERO
	dots.size = panel.size

	var material: ShaderMaterial = (
		ShaderMaterial.new()
	)

	material.shader = HALFTONE_SHADER

	dots.material = material

	panel.add_child(
		dots
	)

	panel.move_child(
		dots,
		0
	)


func _make_content_box(
	panel: Panel
) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()

	box.position = Vector2(
		18.0,
		12.0
	)

	box.size = panel.size - Vector2(
		36.0,
		24.0
	)

	box.add_theme_constant_override(
		"separation",
		8
	)

	box.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	box.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	box.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	panel.add_child(
		box
	)

	return box


func _make_heading(
	text_value: String
) -> Label:
	var heading: Label = _make_label(
		text_value,
		20,
		WHITE,
		true
	)

	heading.custom_minimum_size = Vector2(
		0.0,
		26.0
	)

	return heading


func _make_label(
	text_value: String,
	font_size: int,
	color: Color,
	heavy: bool
) -> Label:
	var label: Label = Label.new()

	label.text = (
		text_value.to_lower()
	)

	label.add_theme_font_size_override(
		"font_size",
		font_size
	)

	label.add_theme_color_override(
		"font_color",
		color
	)

	label.add_theme_color_override(
		"font_outline_color",
		BLACK
	)

	label.add_theme_constant_override(
		"outline_size",
		2
	)

	var selected_font: Font = (
		font_heavy
		if heavy
		else font_body
	)

	if selected_font != null:
		label.add_theme_font_override(
			"font",
			selected_font
		)

	label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	return label


# =========================================================
# LAYOUT
# =========================================================

func _layout_ui() -> void:
	if root == null:
		return

	var viewport_size: Vector2 = (
		get_viewport()
		.get_visible_rect()
		.size
	)

	var virtual_size: Vector2 = (
		viewport_size /
		UI_SCALE
	)

	root.position = Vector2.ZERO

	root.scale = Vector2(
		UI_SCALE,
		UI_SCALE
	)

	root.size = virtual_size

	var margin: float = 28.0


	# -----------------------------------------------------
	# ENEMIES — upper left
	# -----------------------------------------------------

	if enemy_panel != null:
		enemy_panel.position = Vector2(
			margin,
			margin
		)


	# -----------------------------------------------------
	# ROUND / TURN — upper right
	# -----------------------------------------------------

	if round_panel != null:
		round_panel.position = Vector2(
			virtual_size.x -
			round_panel.size.x -
			margin,
			margin
		)


	# -----------------------------------------------------
	# ACTION — upper centre
	# -----------------------------------------------------

	if action_panel != null:
		action_panel.position = Vector2(
			(
				virtual_size.x -
				action_panel.size.x
			) * 0.5,
			round_panel.position.y +
			round_panel.size.y +
			22.0
		)


	# -----------------------------------------------------
	# COMMAND — lower left
	# -----------------------------------------------------

	if command_panel != null:
		command_panel.position = Vector2(
			margin,
			virtual_size.y -
			command_panel.size.y -
			margin
		)


	# -----------------------------------------------------
	# PARTY — lower right
	# -----------------------------------------------------

	if party_panel != null:
		party_panel.position = Vector2(
			virtual_size.x -
			party_panel.size.x -
			margin,
			virtual_size.y -
			party_panel.size.y -
			margin
		)


	# -----------------------------------------------------
	# NOTICE
	# -----------------------------------------------------

	if notice_panel != null:
		notice_panel.position = Vector2(
			margin,
			command_panel.position.y -
			notice_panel.size.y -
			14.0
		)


	# -----------------------------------------------------
	# RESULT
	# -----------------------------------------------------

	if result_panel != null:
		result_panel.position = Vector2(
			(
				virtual_size.x -
				result_panel.size.x
			) * 0.5,
			(
				virtual_size.y -
				result_panel.size.y
			) * 0.5
		)


# =========================================================
# BATTLE START
# =========================================================

func _on_battle_started(
	encounter: BattleEncounter
) -> void:
	combatants.clear()
	row_lookup.clear()

	_clear_rows(
		enemy_rows_box
	)

	_clear_rows(
		party_rows_box
	)

	_clear_rows(
		command_rows_box
	)

	_clear_target_markers()

	menu_rows.clear()

	for combatant: BattleCombatant in encounter.allies:
		combatants.append(
			combatant
		)

	for combatant: BattleCombatant in encounter.enemies:
		combatants.append(
			combatant
	)

	for combatant: BattleCombatant in encounter.enemies:
		_create_enemy_row(
			combatant
		)

	for combatant: BattleCombatant in encounter.allies:
		_create_party_row(
			combatant
		)

	_refresh_combatant_rows()


func _clear_rows(
	container: VBoxContainer
) -> void:
	if container == null:
		return

	for child: Node in container.get_children():
		child.queue_free()


func _clear_target_markers() -> void:
	highlighted_targets.clear()

	for marker: Label in target_markers:
		marker.visible = false

	set_process(false)


# =========================================================
# ENEMY ROW
# =========================================================

func _create_enemy_row(
	combatant: BattleCombatant
) -> void:
	var row: VBoxContainer = VBoxContainer.new()

	row.custom_minimum_size = Vector2(
		0.0,
		56.0
	)

	row.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	row.add_theme_constant_override(
		"separation",
		4
	)

	row.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	var top: HBoxContainer = HBoxContainer.new()

	top.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	top.add_theme_constant_override(
		"separation",
		14
	)


	var name_label: Label = _make_label(
		combatant.character_name,
		21,
		WHITE,
		true
	)

	name_label.custom_minimum_size = Vector2(
		170.0,
		28.0
	)


	var status_label: Label = _make_label(
		_get_enemy_type_text(
			combatant
		),
		14,
		SOFT_WHITE,
		false
	)

	status_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	status_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)


	top.add_child(
		name_label
	)

	top.add_child(
		status_label
	)


	var bar_row: HBoxContainer = HBoxContainer.new()

	bar_row.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	bar_row.add_theme_constant_override(
		"separation",
		8
	)


	var hp_bar: ProgressBar = _make_bar()

	hp_bar.custom_minimum_size = Vector2(
		0.0,
		11.0
	)

	hp_bar.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)


	var hp_text: Label = _make_label(
		"",
		13,
		SOFT_WHITE,
		false
	)

	hp_text.custom_minimum_size = Vector2(
		58.0,
		18.0
	)


	bar_row.add_child(
		hp_bar
	)

	bar_row.add_child(
		hp_text
	)


	row.add_child(
		top
	)

	row.add_child(
		bar_row
	)

	enemy_rows_box.add_child(
		row
	)


	row_lookup[combatant.get_instance_id()] = {
		"row": row,
		"name": name_label,
		"status": status_label,
		"hp": hp_bar,
		"hp_text": hp_text
	}


# =========================================================
# PARTY ROW
# =========================================================

func _create_party_row(
	combatant: BattleCombatant
) -> void:
	var row: VBoxContainer = VBoxContainer.new()

	row.custom_minimum_size = Vector2(
		0.0,
		46.0
	)

	row.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	row.add_theme_constant_override(
		"separation",
		4
	)

	row.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	var top: HBoxContainer = HBoxContainer.new()

	top.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	top.add_theme_constant_override(
		"separation",
		12
	)


	var name_label: Label = _make_label(
		combatant.character_name,
		21,
		WHITE,
		true
	)

	name_label.custom_minimum_size = Vector2(
		175.0,
		27.0
	)


	var status_label: Label = _make_label(
		"ready",
		14,
		SOFT_WHITE,
		false
	)

	status_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	status_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)


	top.add_child(
		name_label
	)

	top.add_child(
		status_label
	)


	var bars: HBoxContainer = HBoxContainer.new()

	bars.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	bars.add_theme_constant_override(
		"separation",
		8
	)


	var hp_bar: ProgressBar = _make_bar()

	hp_bar.custom_minimum_size = Vector2(
		125.0,
		10.0
	)

	hp_bar.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)


	var hp_text: Label = _make_label(
		"",
		12,
		SOFT_WHITE,
		false
	)

	hp_text.custom_minimum_size = Vector2(
		52.0,
		18.0
	)


	var lp_bar: ProgressBar = _make_bar()

	lp_bar.custom_minimum_size = Vector2(
		62.0,
		10.0
	)


	var lp_text: Label = _make_label(
		"",
		12,
		SOFT_WHITE,
		false
	)

	lp_text.custom_minimum_size = Vector2(
		45.0,
		18.0
	)


	bars.add_child(
		hp_bar
	)

	bars.add_child(
		hp_text
	)

	bars.add_child(
		lp_bar
	)

	bars.add_child(
		lp_text
	)


	row.add_child(
		top
	)

	row.add_child(
		bars
	)

	party_rows_box.add_child(
		row
	)


	row_lookup[combatant.get_instance_id()] = {
		"row": row,
		"name": name_label,
		"status": status_label,
		"hp": hp_bar,
		"hp_text": hp_text,
		"lp": lp_bar,
		"lp_text": lp_text
	}


# =========================================================
# BARS
# =========================================================

func _make_bar() -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()

	bar.show_percentage = false

	bar.add_theme_stylebox_override(
		"background",
		_make_bar_style(
			Color(
				0.015,
				0.016,
				0.020,
				1.0
			),
			WHITE,
			1
		)
	)

	bar.add_theme_stylebox_override(
		"fill",
		_make_bar_style(
			WHITE,
			WHITE,
			1
		)
	)

	bar.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	return bar


func _make_bar_style(
	background: Color,
	border: Color,
	border_width: int
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()

	style.bg_color = background
	style.border_color = border

	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width

	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0

	return style


# =========================================================
# REFRESH
# =========================================================

func _refresh_combatant_rows() -> void:
	for combatant: BattleCombatant in combatants:
		var id: int = (
			combatant.get_instance_id()
		)

		if not row_lookup.has(id):
			continue

		var data: Dictionary = row_lookup[id]

		var name_label: Label = (
			data["name"] as Label
		)

		var status_label: Label = (
			data["status"] as Label
		)

		var hp_bar: ProgressBar = (
			data["hp"] as ProgressBar
		)

		var hp_text: Label = (
			data["hp_text"] as Label
		)


		var prefix: String = (
			"> "
			if combatant == current_combatant
			else ""
		)

		name_label.text = (
			prefix +
			combatant.character_name.to_lower()
		)

		name_label.add_theme_color_override(
			"font_color",
			WHITE if combatant.is_alive else DIM_WHITE
		)


		if combatant.is_enemy:
			status_label.text = (
				_get_enemy_type_text(
					combatant
				)
			)
		else:
			status_label.text = (
				_status_text(
					combatant
				)
			)


		hp_bar.max_value = (
			float(combatant.max_hp)
		)

		hp_bar.value = (
			float(combatant.hp)
		)

		hp_text.text = (
			"%d/%d"
			% [
				combatant.hp,
				combatant.max_hp
			]
		)


		if data.has("lp"):
			var lp_bar: ProgressBar = (
				data["lp"] as ProgressBar
			)

			var lp_text: Label = (
				data["lp_text"] as Label
			)

			lp_bar.max_value = (
				float(combatant.max_lp)
			)

			lp_bar.value = (
				float(combatant.lp)
			)

			lp_text.text = (
				"%d lp"
				% combatant.lp
			)


func _status_text(
	combatant: BattleCombatant
) -> String:
	if not combatant.is_alive:
		return "down"

	var parts: Array[String] = []

	if combatant.is_guarding:
		parts.append(
			"guard"
		)

	if combatant.offense_buff_turns > 0:
		parts.append(
			"atk+"
		)

	if combatant.defense_buff_turns > 0:
		parts.append(
			"def+"
		)

	if combatant.offense_debuff_turns > 0:
		parts.append(
			"atk-"
		)

	if combatant.defense_debuff_turns > 0:
		parts.append(
			"def-"
		)

	if parts.is_empty():
		return "ready"

	return " ".join(parts)


func _get_enemy_type_text(
	combatant: BattleCombatant
) -> String:
	if combatant == null:
		return "type: unknown"

	match combatant.combat_class:
		BattleCombatant.CombatClass.VISIBLE:
			return "type: visible"

		BattleCombatant.CombatClass.HIGH_ENERGY:
			return "type: high energy"

		BattleCombatant.CombatClass.LOW_ENERGY:
			return "type: low energy"

		_:
			return "type: unknown"


# =========================================================
# MENU
# =========================================================

func _on_menu_updated(
	kind: String,
	entries: Array,
	selected: int
) -> void:
	if kind == "none":
		command_panel.visible = false
		return

	command_panel.visible = true


	match kind:
		"action":
			_set_command_heading(
				"command"
			)

		"skill":
			_set_command_heading(
				"skills"
			)

		"target":
			_set_command_heading(
				"target"
			)

		_:
			_set_command_heading(
				"command"
			)


	# -----------------------------------------------------
	# Create enough rows.
	# -----------------------------------------------------

	while menu_rows.size() < entries.size():
		var row: Button = _make_menu_row()

		command_rows_box.add_child(
			row
		)

		menu_rows.append(
			row
		)


	# -----------------------------------------------------
	# Distribute all rows evenly through the dedicated
	# command-row area.
	# -----------------------------------------------------

	var row_count: int = entries.size()

	for i: int in menu_rows.size():
		var row: Button = menu_rows[i]

		if i >= row_count:
			row.visible = false
			continue


		var entry: Dictionary = (
			entries[i]
		)


		row.visible = true

		row.text = str(
			entry.get(
				"text",
				""
			)
		).to_lower()

		row.disabled = not bool(
			entry.get(
				"enabled",
				true
			)
		)

		row.size_flags_vertical = (
			Control.SIZE_EXPAND_FILL
		)

		row.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)


		_style_menu_row(
			row,
			i == selected,
			row.disabled
		)


	# -----------------------------------------------------
	# Skill description is separated from the menu rows.
	# -----------------------------------------------------

	if (
		kind == "skill"
		and
		selected >= 0
		and
		selected < entries.size()
	):
		command_hint_label.text = str(
			entries[selected].get(
				"desc",
				""
			)
		).to_lower()
	else:
		command_hint_label.text = (
			"w s move   enter ok   esc back"
		)


func _set_command_heading(
	text_value: String
) -> void:
	if command_content.get_child_count() == 0:
		return

	var heading: Label = (
		command_content.get_child(0)
		as Label
	)

	if heading != null:
		heading.text = (
			text_value.to_lower()
		)


func _make_menu_row() -> Button:
	var button: Button = Button.new()

	button.focus_mode = (
		Control.FOCUS_NONE
	)

	button.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	button.alignment = (
		HORIZONTAL_ALIGNMENT_LEFT
	)

	button.custom_minimum_size = Vector2(
		0.0,
		44.0
	)

	button.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	button.add_theme_font_size_override(
		"font_size",
		24
	)

	if font_heavy != null:
		button.add_theme_font_override(
			"font",
			font_heavy
		)

	return button


func _style_menu_row(
	button: Button,
	selected: bool,
	disabled: bool
) -> void:
	var normal: StyleBoxFlat = (
		_make_menu_style(
			PANEL_BLACK,
			WHITE,
			0
		)
	)

	var selected_style: StyleBoxFlat = (
		_make_menu_style(
			WHITE,
			WHITE,
			0
		)
	)

	var disabled_style: StyleBoxFlat = (
		_make_menu_style(
			PANEL_BLACK,
			DIM_WHITE,
			0
		)
	)


	button.add_theme_stylebox_override(
		"normal",
		disabled_style if disabled else (
			selected_style if selected else normal
		)
	)

	button.add_theme_stylebox_override(
		"hover",
		selected_style
	)

	button.add_theme_stylebox_override(
		"pressed",
		selected_style
	)


	button.add_theme_color_override(
		"font_color",
		DIM_WHITE if disabled else (
			BLACK if selected else WHITE
		)
	)

	button.add_theme_color_override(
		"font_hover_color",
		BLACK
	)

	button.add_theme_color_override(
		"font_pressed_color",
		BLACK
	)


func _make_menu_style(
	background: Color,
	border: Color,
	border_width: int
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()

	style.bg_color = background
	style.border_color = border

	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width

	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0

	style.content_margin_left = 14.0
	style.content_margin_right = 10.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0

	return style


# =========================================================
# TARGET MARKERS
# =========================================================

func _on_target_highlight(
	targets: Array
) -> void:
	highlighted_targets.clear()

	for target: Variant in targets:
		if target is BattleCombatant:
			highlighted_targets.append(
				target as BattleCombatant
			)

	for i: int in target_markers.size():
		if i < highlighted_targets.size():
			target_markers[i].visible = true

			target_markers[i].position = (
				_anchor(
					highlighted_targets[i],
					1.0
				)
				-
				Vector2(
					35.0,
					16.0
				)
			)
		else:
			target_markers[i].visible = false

	set_process(
		not highlighted_targets.is_empty()
	)


func _process(_delta: float) -> void:
	if highlighted_targets.is_empty():
		return

	_update_target_markers()


func _update_target_markers() -> void:
	for i: int in target_markers.size():
		if i >= highlighted_targets.size():
			target_markers[i].visible = false
			continue

		target_markers[i].visible = true

		target_markers[i].position = (
			_anchor(
				highlighted_targets[i],
				1.0
			)
			-
			Vector2(
				35.0,
				16.0
			)
		)


func _anchor(
	combatant: BattleCombatant,
	height: float
) -> Vector2:
	if anchor_provider.is_valid():
		var value: Variant = (
			anchor_provider.call(
				combatant,
				height
			)
		)

		if value is Vector2:
			return (
				value as Vector2
			) / UI_SCALE

	return root.size * 0.5


# =========================================================
# ACTION DISPLAY
# =========================================================

func _on_round_started(
	round_number: int
) -> void:
	round_label.text = (
		"round %d"
		% round_number
	)


func _on_turn_started(
	combatant: BattleCombatant
) -> void:
	current_combatant = combatant

	turn_label.text = (
		combatant.character_name.to_lower()
		+
		"'s turn"
	)

	_refresh_combatant_rows()


func _on_guard_cleared(
	_combatant: BattleCombatant
) -> void:
	_refresh_combatant_rows()


func _on_turn_finished(
	_combatant: BattleCombatant
) -> void:
	_hide_action()


func _on_enemy_thinking(
	combatant: BattleCombatant
) -> void:
	show_action_banner(
		combatant.character_name,
		"thinking..."
	)


func _on_action_started(
	combatant: BattleCombatant,
	skill: BattleSkill,
	_targets: Array
) -> void:
	show_action_banner(
		combatant.character_name,
		skill.display_name
	)


func show_action_banner(
	who: String,
	what: String,
	duration: float = 3.0
) -> void:
	action_actor_label.text = (
		who.to_lower()
	)

	action_label.text = (
		what.to_lower()
	)

	action_panel.visible = true
	action_panel.modulate.a = 0.0


	if action_tween != null:
		action_tween.kill()


	action_tween = create_tween()


	action_tween.tween_property(
		action_panel,
		"modulate:a",
		1.0,
		0.16
	)


	action_tween.tween_interval(
		max(
			duration - 0.46,
			0.1
		)
	)


	action_tween.tween_property(
		action_panel,
		"modulate:a",
		0.0,
		0.30
	)


	action_tween.tween_callback(
		func() -> void:
			action_panel.visible = false
	)


func _hide_action() -> void:
	if not action_panel.visible:
		return

	if action_tween != null:
		action_tween.kill()

	action_tween = create_tween()

	action_tween.tween_property(
		action_panel,
		"modulate:a",
		0.0,
		0.18
	)

	action_tween.tween_callback(
		func() -> void:
			action_panel.visible = false
	)


# =========================================================
# IMPACTS
# =========================================================

func _on_impact(
	_attacker: BattleCombatant,
	target: BattleCombatant,
	amount: int,
	info: Dictionary
) -> void:
	var text_value: String = (
		str(amount)
	)

	if bool(
		info.get(
			"repelled",
			false
		)
	):
		text_value = "repel"

	elif bool(
		info.get(
			"weak",
			false
		)
	):
		text_value = (
			str(amount) +
			"  weak"
		)

	elif bool(
		info.get(
			"resisted",
			false
		)
	):
		text_value = (
			str(amount) +
			"  resist"
		)

	elif bool(
		info.get(
			"guarded",
			false
		)
	):
		text_value = (
			str(amount) +
			"  guarded"
		)

	_show_floating_text(
		target,
		text_value,
		52
	)

	_flash(
		0.14
	)

	_refresh_combatant_rows()


func _on_heal(
	_c: BattleCombatant,
	target: BattleCombatant,
	amount: int
) -> void:
	_show_floating_text(
		target,
		"+%d" % amount,
		50
	)

	_refresh_combatant_rows()


func _on_buff(
	_c: BattleCombatant,
	target: BattleCombatant,
	kind: int
) -> void:
	_show_floating_text(
		target,
		_kind_text(kind),
		40
	)

	_refresh_combatant_rows()


func _on_debuff(
	_c: BattleCombatant,
	target: BattleCombatant,
	kind: int
) -> void:
	_show_floating_text(
		target,
		_kind_text(kind),
		40
	)

	_refresh_combatant_rows()


func _kind_text(
	kind: int
) -> String:
	match kind:
		BattleCombatant.StatusKind.OFFENSE_BUFF:
			return "atk up"

		BattleCombatant.StatusKind.OFFENSE_DEBUFF:
			return "atk down"

		BattleCombatant.StatusKind.DEFENSE_BUFF:
			return "def up"

		_:
			return "def down"


func _on_guard(
	target: BattleCombatant
) -> void:
	_show_floating_text(
		target,
		"guard",
		40
	)

	_refresh_combatant_rows()


func _on_self_damaged(
	target: BattleCombatant,
	amount: int
) -> void:
	_show_floating_text(
		target,
		"-%d" % amount,
		40
	)

	_refresh_combatant_rows()


func _on_defeated(
	target: BattleCombatant
) -> void:
	_show_floating_text(
		target,
		"down",
		56
	)

	_refresh_combatant_rows()


func _on_status_expired(
	target: BattleCombatant,
	kind: int
) -> void:
	_show_floating_text(
		target,
		_kind_text(kind) +
		" ended",
		36
	)

	_refresh_combatant_rows()


func _show_floating_text(
	target: BattleCombatant,
	text_value: String,
	font_size: int
) -> void:
	var label: Label = _make_label(
		text_value,
		font_size,
		WHITE,
		true
	)

	label.size = Vector2(
		220.0,
		64.0
	)

	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	label.position = (
		_anchor(
			target,
			2.1
		)
		-
		Vector2(
			110.0,
			32.0
		)
	)

	root.add_child(
		label
	)

	label.modulate.a = 0.0

	var tween: Tween = create_tween()

	tween.set_parallel(true)

	tween.tween_property(
		label,
		"modulate:a",
		1.0,
		0.08
	)

	tween.tween_property(
		label,
		"position:y",
		label.position.y - 16.0,
		0.42
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	tween.set_parallel(false)

	tween.tween_interval(
		0.10
	)

	tween.tween_property(
		label,
		"modulate:a",
		0.0,
		0.20
	)

	tween.tween_callback(
		func() -> void:
			label.queue_free()
	)


func _flash(
	alpha: float
) -> void:
	flash_rect.color = Color(
		1.0,
		1.0,
		1.0,
		alpha
	)

	var tween: Tween = create_tween()

	tween.tween_property(
		flash_rect,
		"color:a",
		0.0,
		0.12
	)


# =========================================================
# NOTICE
# =========================================================

func _on_notice(
	text_value: String
) -> void:
	notice_label.text = (
		text_value.to_lower()
	)

	notice_panel.visible = true
	notice_panel.modulate.a = 1.0

	if notice_tween != null:
		notice_tween.kill()

	notice_tween = create_tween()

	notice_tween.tween_interval(
		0.9
	)

	notice_tween.tween_property(
		notice_panel,
		"modulate:a",
		0.0,
		0.25
	)

	notice_tween.tween_callback(
		func() -> void:
			notice_panel.visible = false
	)


# =========================================================
# RESULT
# =========================================================

func _on_battle_won() -> void:
	_show_result(
		"victory"
	)


func _on_battle_lost() -> void:
	_show_result(
		"defeat"
	)


func _show_result(
	text_value: String
) -> void:
	_hide_action()

	result_label.text = (
		text_value.to_lower()
	)

	result_panel.visible = true
	result_panel.modulate.a = 0.0

	if result_tween != null:
		result_tween.kill()

	result_tween = create_tween()

	result_tween.tween_property(
		result_panel,
		"modulate:a",
		1.0,
		0.20
	)

	# Intentionally no jump, bounce, or scale.
	result_panel.scale = Vector2.ONE


# =========================================================
# PUBLIC COMPATIBILITY
# =========================================================

func show_action_menu(
	selected: int = 0
) -> void:
	_on_menu_updated(
		"action",
		[
			{
				"text": "attack",
				"enabled": true
			},
			{
				"text": "skill",
				"enabled": true
			},
			{
				"text": "guard",
				"enabled": true
			}
		],
		selected
	)


func hide_menus() -> void:
	command_panel.visible = false


func refresh() -> void:
	_refresh_combatant_rows()
