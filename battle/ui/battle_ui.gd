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
## - procedural halftone only inside panels
##
## No custom panel widgets.
## No animated panel redraw.
## No fullscreen UI post-process.
## No colour UI.


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
	0.90
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
var status_panel: Panel
var action_panel: Panel
var notice_panel: Panel
var result_panel: Panel

var result_content: VBoxContainer

var enemy_content: VBoxContainer
var command_content: VBoxContainer
var party_content: VBoxContainer

var round_label: Label
var turn_label: Label

var status_title_label: Label
var status_value_label: Label

var action_actor_label: Label
var action_label: Label

var notice_label: Label
var result_label: Label
var result_sub_label: Label

var action_tween: Tween
var notice_tween: Tween
var boss_warning_active: bool = false
var result_tween: Tween

var _result_mode: String = ""
var _victory_transition_started: bool = false

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
var tag_lookup: Dictionary = {}

var revive_spacer: Control = null


# =========================================================
# READY
# =========================================================

func _ready() -> void:
	layer = 10

	if ResourceLoader.exists(
		FONT_PATH_BODY
	):
		font_body = load(
			FONT_PATH_BODY
		) as Font

	if ResourceLoader.exists(
		FONT_PATH_HEAVY
	):
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


func _input(
	event: InputEvent
) -> void:
	if _result_mode != "defeat":
		return

	if not result_panel.visible:
		return

	if not event.is_action_pressed(
		"ui_accept"
	):
		return

	get_viewport().set_input_as_handled()
	get_tree().reload_current_scene()


# =========================================================
# BIND CONTROLLER
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
# UI BUILD
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
			430.0,
			210.0
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

	enemy_panel.visible = true


	# -----------------------------------------------------
	# COMMAND
	# -----------------------------------------------------

	command_panel = _make_panel(
		"CommandPanel",
		Vector2(
			420.0,
			220.0
		)
	)

	command_content = _make_content_box(
		command_panel
	)

	command_content.add_child(
		_make_heading(
			"command"
		)
	)

	command_panel.visible = false


	# -----------------------------------------------------
	# PARTY
	# -----------------------------------------------------

	party_panel = _make_panel(
		"PartyPanel",
		Vector2(
			430.0,
			210.0
		)
	)

	party_content = _make_content_box(
		party_panel
	)

	party_content.add_child(
		_make_heading(
			"party"
		)
	)


	# -----------------------------------------------------
	# ROUND / TURN
	# -----------------------------------------------------

	round_panel = _make_panel(
		"RoundPanel",
		Vector2(
			300.0,
			78.0
		)
	)

	# Round panel keeps its original footprint; its border is intentionally
	# slightly rounded so it reads as a HUD element rather than a window.

	var round_box: VBoxContainer = _make_content_box(
		round_panel
	)

	round_label = _make_label(
		"round 1",
		15,
		DIM_WHITE,
		false
	)

	round_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
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
		HORIZONTAL_ALIGNMENT_CENTER
	)

	round_box.add_child(
		turn_label
	)


	# -----------------------------------------------------
	# ADAPTATION / BOSS STATUS
	# -----------------------------------------------------

	status_panel = _make_panel(
		"SkillStatusPanel",
		Vector2(
			260.0,
			68.0
		)
	)

	var status_box: VBoxContainer = _make_content_box(
		status_panel
	)

	status_title_label = _make_label(
		"",
		15,
		DIM_WHITE,
		false
	)

	status_title_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)

	status_box.add_child(
		status_title_label
	)

	status_value_label = _make_label(
		"",
		22,
		WHITE,
		true
	)

	status_value_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)

	status_value_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	status_box.add_child(
		status_value_label
	)

	status_panel.visible = false


	# -----------------------------------------------------
	# ACTION
	# -----------------------------------------------------

	action_panel = _make_panel(
		"ActionPanel",
		Vector2(
			650.0,
			110.0
		)
	)

	var action_box: VBoxContainer = _make_content_box(
		action_panel
	)

	action_actor_label = _make_label(
		"",
		16,
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
		44,
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
			620.0,
			82.0
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

	result_content = _make_content_box(
		result_panel
	)

	result_label = _make_label(
		"",
		62,
		WHITE,
		true
	)

	result_label.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	result_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	result_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	result_content.add_child(
		result_label
	)

	result_sub_label = _make_label(
		"",
		18,
		SOFT_WHITE,
		false
	)

	result_sub_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	result_sub_label.visible = false

	result_content.add_child(
		result_sub_label
	)

	result_panel.z_index = 1000
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
	# TARGET MARKERS LAYER
	# -----------------------------------------------------

	for i: int in 5:
		var marker: Label = _make_label(
			"[ ]",
			22,
			WHITE,
			true
		)

		marker.size = Vector2(
			70.0,
			32.0
		)

		marker.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
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

	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1

	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4

	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0

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
		14.0,
		9.0
	)

	box.size = panel.size - Vector2(
		28.0,
		18.0
	)

	box.add_theme_constant_override(
		"separation",
		6
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
		22,
		WHITE,
		true
	)

	heading.custom_minimum_size = Vector2(
		0.0,
		28.0
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

	var margin: float = 26.0


	# -----------------------------------------------------
	# ENEMIES — upper left
	# -----------------------------------------------------

	if enemy_panel != null:
		enemy_panel.position = Vector2(
			margin,
			margin
		)


	# -----------------------------------------------------
	# ROUND / TURN — top center
	# -----------------------------------------------------

	if round_panel != null:
		round_panel.position = Vector2(
			(virtual_size.x - round_panel.size.x) * 0.5,
			margin
		)


	# -----------------------------------------------------
	# STATUS — bottom-left message stack, above action banner
	# -----------------------------------------------------

	if status_panel != null:
		status_panel.position = Vector2(
			margin,
			virtual_size.y -
			action_panel.size.y -
			status_panel.size.y -
			margin -
			10.0
		)


	# -----------------------------------------------------
	# ACTION — bottom left
	# -----------------------------------------------------

	if action_panel != null:
		action_panel.position = Vector2(
			margin,
			virtual_size.y -
			action_panel.size.y -
			margin
		)


	# -----------------------------------------------------
	# PARTY — upper right
	# -----------------------------------------------------

	if party_panel != null:
		party_panel.position = Vector2(
			virtual_size.x -
			party_panel.size.x -
			margin,
			margin
		)


	# -----------------------------------------------------
	# COMMAND — lower right
	# -----------------------------------------------------

	if command_panel != null:
		command_panel.position = Vector2(
			virtual_size.x -
			command_panel.size.x -
			margin - 12.0,
			virtual_size.y -
			command_panel.size.y -
			margin - 8.0
		)


	# -----------------------------------------------------
	# NOTICE — directly above bottom-left action message
	# -----------------------------------------------------

	if notice_panel != null:
		var notice_y: float = (
			status_panel.position.y -
			notice_panel.size.y -
			10.0
			if status_panel.visible
			else action_panel.position.y -
			notice_panel.size.y -
			10.0
		)

		notice_panel.position = Vector2(
			action_panel.position.x,
			notice_y
		)


	# -----------------------------------------------------
	# RESULT
	# -----------------------------------------------------

	if result_panel != null:
		if _result_mode == "defeat":
			result_panel.position = Vector2.ZERO
			result_panel.size = virtual_size
			result_panel.custom_minimum_size = virtual_size

			if result_content != null:
				result_content.position = Vector2(
					18.0,
					14.0
				)

				result_content.size = (
					virtual_size -
					Vector2(
						36.0,
						28.0
					)
				)

			for child: Node in result_panel.get_children():
				if child is ColorRect:
					var dots: ColorRect = (
						child as ColorRect
					)

					dots.position = Vector2.ZERO
					dots.size = virtual_size

		else:
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
	tag_lookup.clear()

	if revive_spacer != null:
		revive_spacer.queue_free()
		revive_spacer = null

	for child: Node in enemy_content.get_children():
		if child != enemy_content.get_child(0):
			child.queue_free()

	for child: Node in party_content.get_children():
		if child != party_content.get_child(0):
			child.queue_free()

	for child: Node in command_content.get_children():
		child.queue_free()

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

	_update_skill_status_panel(
		encounter
	)


# =========================================================
# SKILL STATUS PANEL
# =========================================================

func _update_skill_status_panel(
	encounter: BattleEncounter
) -> void:
	status_panel.visible = false

	if encounter == null:
		return

	var encounter_id: String = (
		encounter.encounter_id
	)

	var meta_name: String = ""

	if encounter_id == "room2":
		meta_name = (
			"robruzz_room2_resisted_skill_id"
		)

		status_title_label.text = (
			"resisted skill"
		)

	elif encounter_id == "boss":
		meta_name = (
			"robruzz_boss_rejected_skill_id"
		)

		status_title_label.text = (
			"rejected skill"
		)

	else:
		return

	if not get_tree().has_meta(
		meta_name
	):
		return

	var stored: Variant = (
		get_tree().get_meta(
			meta_name
		)
	)

	if not stored is String:
		return

	var skill_id: String = (
		stored as String
	)

	if skill_id.is_empty():
		return

	var skill: BattleSkill = (
		BattleSkills.get_skill(
			skill_id
		)
	)

	if skill == null:
		return

	status_value_label.text = (
		skill.display_name.to_lower()
	)

	status_panel.visible = true


# =========================================================
# ENEMY ROW
# =========================================================

func _create_enemy_row(
	combatant: BattleCombatant
) -> void:
	var row: VBoxContainer = VBoxContainer.new()

	row.add_theme_constant_override(
		"separation",
		7
	)

	var top: HBoxContainer = HBoxContainer.new()

	top.add_theme_constant_override(
		"separation",
		18
	)

	var name_label: Label = _make_label(
		combatant.character_name,
		25,
		WHITE,
		true
	)

	name_label.custom_minimum_size = Vector2(
		145.0,
		30.0
	)

	var status_label: Label = _make_label(
		_get_enemy_type_text(combatant),
		20,
		WHITE,
		true
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

	bar_row.add_theme_constant_override(
		"separation",
		8
	)

	var hp_bar: ProgressBar = _make_bar()

	hp_bar.custom_minimum_size = Vector2(
		170.0,
		12.0
	)

	hp_bar.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	var hp_text: Label = _make_label(
		"",
		16,
		WHITE,
		true
	)

	hp_text.custom_minimum_size = Vector2(
		70.0,
		22.0
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

	enemy_content.add_child(
		row
	)

	row_lookup[
		combatant.get_instance_id()
	] = {
		"row": row,
		"name": name_label,
		"status": status_label,
		"hp": hp_bar,
		"hp_text": hp_text,
	}


# =========================================================
# PARTY ROW
# =========================================================

func _create_party_row(
	combatant: BattleCombatant
) -> void:
	var row: VBoxContainer = VBoxContainer.new()

	row.add_theme_constant_override(
		"separation",
		3
	)

	var top: HBoxContainer = HBoxContainer.new()

	top.add_theme_constant_override(
		"separation",
		12
	)

	var name_label: Label = _make_label(
		combatant.character_name,
		22,
		WHITE,
		true
	)

	name_label.custom_minimum_size = Vector2(
		170.0,
		28.0
	)

	var status_label: Label = _make_label(
		"ready",
		15,
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

	bars.add_theme_constant_override(
		"separation",
		8
	)

	var hp_bar: ProgressBar = _make_bar()

	hp_bar.custom_minimum_size = Vector2(
		155.0,
		10.0
	)

	hp_bar.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	var hp_text: Label = _make_label(
		"",
		14,
		SOFT_WHITE,
		true
	)

	hp_text.custom_minimum_size = Vector2(
		62.0,
		20.0
	)

	var lp_bar: ProgressBar = _make_bar()

	lp_bar.custom_minimum_size = Vector2(
		78.0,
		10.0
	)

	var lp_text: Label = _make_label(
		"",
		14,
		SOFT_WHITE,
		true
	)

	lp_text.custom_minimum_size = Vector2(
		54.0,
		20.0
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

	party_content.add_child(
		row
	)

	row_lookup[
		combatant.get_instance_id()
	] = {
		"row": row,
		"name": name_label,
		"status": status_label,
		"hp": hp_bar,
		"hp_text": hp_text,
		"lp": lp_bar,
		"lp_text": lp_text,
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

		name_label.text = (
			(
				"> "
				if combatant == current_combatant
				else ""
			)
			+
			combatant.character_name.to_lower()
		)

		name_label.add_theme_color_override(
			"font_color",
			WHITE if combatant.is_alive else DIM_WHITE
		)

		var status_text: String = _status_text(
			combatant
		)

		if data.has("lp"):
			status_label.text = status_text
		else:
			if status_text == "ready":
				status_label.text = _get_enemy_type_text(
					combatant
				)
			else:
				status_label.text = (
					_get_enemy_type_text(
						combatant
					)
					+
					"  "
					+
					status_text
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

		_hide_revive_spacer()

		return

	command_panel.visible = true

	# Keep the base command menu compact. Expand only when a skill list
	# needs the extra vertical room; this keeps the main HUD visually light.
	var desired_command_height: float = 220.0
	if kind == "skill":
		desired_command_height = 320.0

	command_panel.size = Vector2(
		420.0,
		desired_command_height
	)
	command_panel.custom_minimum_size = command_panel.size
	command_content.size = command_panel.size - Vector2(28.0, 18.0)
	var command_dots: ColorRect = command_panel.get_child(0) as ColorRect
	if command_dots != null:
		command_dots.size = command_panel.size
	_layout_ui()

	_set_command_heading(
		"command"
	)

	if kind == "skill":
		_set_command_heading(
			"skills"
	)

	elif kind == "target":
		_set_command_heading(
			"target"
	)

	while menu_rows.size() < entries.size():
		var row: Button = _make_menu_row()

		command_content.add_child(
			row
		)

		menu_rows.append(
			row
		)


	# -----------------------------------------------------
	# Determine row size.
	# Skill lists get tighter rows so all skills fit cleanly.
	# -----------------------------------------------------

	var row_count: int = entries.size()

	var available_height: float = (
		command_panel.size.y
		- 82.0
	)

	var row_height: float = 48.0

	if kind == "skill":
		row_height = 42.0
	else:
		if row_count > 0:
			row_height = (
				available_height /
				float(row_count)
			)

			row_height = clampf(
				row_height,
				48.0,
				78.0
			)

	for i: int in menu_rows.size():
		var row: Button = menu_rows[i]

		if i >= entries.size():
			row.visible = false
			continue

		var entry: Dictionary = (
			entries[i]
		)

		row.visible = true

		var entry_text: String = str(
			entry.get(
				"text",
				""
			)
		).to_lower()

		var entry_sub: String = str(
			entry.get(
				"sub",
				""
			)
		).to_lower()

		if entry_sub.is_empty():
			row.text = entry_text
		else:
			row.text = (
				entry_text
				+
				"   "
				+
				entry_sub
			)

		row.disabled = not bool(
			entry.get(
				"enabled",
				true
			)
		)

		if kind == "skill":
			row.set_meta(
				"skill_id",
				str(entry.get("skill_id", ""))
			)
		else:
			row.set_meta(
				"skill_id",
				""
			)

		var final_row_height: float = row_height

		if (
			kind == "skill"
			and
			entry_text == "revive"
		):
			final_row_height += 4.0

		row.custom_minimum_size = Vector2(
			0.0,
			final_row_height
		)

		row.size_flags_vertical = (
			Control.SIZE_EXPAND_FILL
		)

		_style_menu_row(
			row,
			i == selected,
			row.disabled
		)


	# -----------------------------------------------------
	# Revive separator.
	# -----------------------------------------------------

	_update_revive_spacing(
		kind,
		entries
	)


	# -----------------------------------------------------
	# Skill description.
	# -----------------------------------------------------

	if (
		kind == "skill"
		and
		selected >= 0
		and
		selected < entries.size()
	):
		var selected_entry: Dictionary = (
			entries[selected]
		)

		var description_text: String = str(
			selected_entry.get(
				"desc",
				""
			)
		)

		var skill_id: String = str(
			selected_entry.get(
				"skill_id",
				""
			)
		)

		var preview_text: String = _skill_matchup_preview(
			skill_id
		)

		if not preview_text.is_empty():
			description_text += "\n" + preview_text

		command_hint(
			"effect: "
			+
			description_text
		)

	else:
		var existing_hint: Label = (
			command_content.get_node_or_null(
				"CommandHint"
			) as Label
		)

		if existing_hint != null:
			existing_hint.text = ""


func _update_revive_spacing(
	kind: String,
	entries: Array
) -> void:
	if revive_spacer == null:
		revive_spacer = Control.new()

		revive_spacer.name = (
			"ReviveSpacer"
		)

		revive_spacer.custom_minimum_size = Vector2(
			0.0,
			8.0
		)

		revive_spacer.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

		command_content.add_child(
			revive_spacer
		)

	var revive_index: int = -1

	for i: int in entries.size():
		var entry: Dictionary = (
			entries[i]
		)

		var entry_text: String = str(
			entry.get(
				"text",
				""
			)
		).to_lower()

		if entry_text == "revive":
			revive_index = i
			break

	if (
		kind != "skill"
		or
		revive_index < 0
		or
		revive_index >= menu_rows.size()
	):
		revive_spacer.visible = false
		return

	revive_spacer.visible = true

	var revive_row: Button = (
		menu_rows[
			revive_index
		]
	)

	var row_child_index: int = (
		revive_row.get_index()
	)

	command_content.move_child(
		revive_spacer,
		row_child_index
	)


func _hide_revive_spacer() -> void:
	if revive_spacer != null:
		revive_spacer.visible = false


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


func _skill_matchup_preview(
	skill_id: String
) -> String:
	if controller == null:
		return ""

	if controller.encounter == null:
		return ""

	if skill_id.is_empty():
		return ""

	var skill: BattleSkill = BattleSkills.get_skill(
		skill_id
	)

	if skill == null:
		return ""

	# Matchup feedback is only meaningful for damaging skills.
	if skill.effect_type != BattleSkill.EffectType.DAMAGE:
		return ""

	if controller.current == null:
		return ""

	var weak_names: Array[String] = []
	var resist_names: Array[String] = []
	var rejected_names: Array[String] = []

	for enemy: BattleCombatant in controller.encounter.enemies:
		if enemy == null or not enemy.is_alive:
			continue

		if (
			controller.encounter.encounter_id == "boss"
			and
			controller.rejected_skill_id == skill.skill_id
		):
			rejected_names.append(
				enemy.character_name
			)
			continue

		var resistance: float = (
			controller.encounter.adaptation
			.get_enemy_multiplier(
				enemy.character_name,
				skill.skill_id
			)
		)

		if resistance < 1.0:
			resist_names.append(
				enemy.character_name
			)
			continue

		var class_mult: float = (
			BattleRules.skill_class_multiplier(
				controller.current,
				enemy,
				skill
			)
		)

		if class_mult > 1.0:
			weak_names.append(
				enemy.character_name
			)

	var lines: Array[String] = []

	if not weak_names.is_empty():
		lines.append(
			"WEAK → " + ", ".join(weak_names)
		)

	if not resist_names.is_empty():
		lines.append(
			"RESIST → " + ", ".join(resist_names)
		)

	if not rejected_names.is_empty():
		lines.append(
			"REJECTED → " + ", ".join(rejected_names)
		)

	if lines.is_empty():
		return "MATCHUP → neutral"

	return "MATCHUP → " + " | ".join(lines)


func _on_skill_row_hovered(
	row: Button
) -> void:
	if row == null:
		return

	var skill_id: String = str(
		row.get_meta(
			"skill_id",
			""
		)
	)

	if skill_id.is_empty():
		return

	var skill: BattleSkill = BattleSkills.get_skill(
		skill_id
	)

	if skill == null:
		return

	var hint_text: String = (
		"effect: " + skill.describe()
	)

	var preview_text: String = _skill_matchup_preview(
		skill_id
	)

	if not preview_text.is_empty():
		hint_text += "\n" + preview_text

	command_hint(
		hint_text
	)


func _make_menu_row() -> Button:
	var button: Button = Button.new()

	button.focus_mode = (
		Control.FOCUS_NONE
	)

	button.mouse_entered.connect(
		func() -> void:
			_on_skill_row_hovered(button)
	)

	button.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	button.alignment = (
		HORIZONTAL_ALIGNMENT_LEFT
	)

	button.custom_minimum_size = Vector2(
		0.0,
		42.0
	)

	button.add_theme_font_size_override(
		"font_size",
		28
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
			1
		)
	)

	var selected_style: StyleBoxFlat = (
		_make_menu_style(
			WHITE,
			WHITE,
			1
		)
	)

	var disabled_style: StyleBoxFlat = (
		_make_menu_style(
			PANEL_BLACK,
			DIM_WHITE,
			1
		)
	)

	button.add_theme_stylebox_override(
		"normal",
		disabled_style
		if disabled
		else (
			selected_style
			if selected
			else normal
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
		DIM_WHITE
		if disabled
		else (
			BLACK
			if selected
			else WHITE
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

	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4

	style.content_margin_left = 14.0
	style.content_margin_right = 10.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0

	return style


func command_hint(
	text_value: String
) -> void:
	var existing: Label = (
		command_content.get_node_or_null(
			"CommandHint"
		) as Label
	)

	if existing == null:
		existing = _make_label(
			"",
			15,
			WHITE,
			true
		)

		existing.name = (
			"CommandHint"
		)

		existing.custom_minimum_size = Vector2(
			0.0,
			60.0
		)

		existing.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)

		command_content.add_child(
			existing
		)

	existing.text = (
		text_value.to_lower()
	)


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


func _process(
	_delta: float
) -> void:
	if highlighted_targets.is_empty():
		return

	_update_target_markers()


func _update_target_markers() -> void:
	for i: int in target_markers.size():
		if (
			i >= highlighted_targets.size()
		):
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

	_show_floating_text(
		combatant,
		"+3 lp regenerated",
		30
	)


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
	if (
		boss_warning_active
		and
		skill != null
		and
		skill.skill_id == BattleSkills.BOSS_XRAY
	):
		_hide_notice()

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
# IMPACT FEEDBACK
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
			str(amount)
			+
			"  weak"
		)

	elif bool(
		info.get(
			"resisted",
			false
		)
	):
		text_value = (
			str(amount)
			+
			"  resist"
		)

	elif bool(
		info.get(
			"guarded",
			false
		)
	):
		text_value = (
			str(amount)
			+
			"  guarded"
		)

	_show_floating_text(
		target,
		text_value,
		56
	)

	_flash(
		0.16
	)

	_refresh_combatant_rows()


func _on_heal(
	_c: BattleCombatant,
	target: BattleCombatant,
	amount: int
) -> void:
	_show_floating_text(
		target,
		"+%d"
		% amount,
		52
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
		42
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
		42
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
		42
	)

	_refresh_combatant_rows()


func _on_self_damaged(
	target: BattleCombatant,
	amount: int
) -> void:
	_show_floating_text(
		target,
		"-%d"
		% amount,
		42
	)

	_refresh_combatant_rows()


func _on_defeated(
	target: BattleCombatant
) -> void:
	_show_floating_text(
		target,
		"down",
		60
	)

	_refresh_combatant_rows()


func _on_status_expired(
	target: BattleCombatant,
	kind: int
) -> void:
	_show_floating_text(
		target,
		_kind_text(kind)
		+
		" ended",
		38
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
		240.0,
		70.0
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
			120.0,
			35.0
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
	alpha: float,
	flash_color: Color = Color(
		1.0,
		1.0,
		1.0,
		1.0
	)
) -> void:
	flash_rect.color = Color(
		flash_color.r,
		flash_color.g,
		flash_color.b,
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
	var lower_text: String = text_value.to_lower()
	var is_boss_warning: bool = (
		lower_text.contains("devastating attack")
		and
		lower_text.contains("guard now")
	)

	if notice_tween != null:
		notice_tween.kill()

	notice_label.text = lower_text
	notice_panel.visible = true
	notice_panel.modulate.a = 1.0
	boss_warning_active = is_boss_warning

	# The boss warning is a persistent telegraph. It stays up until the
	# actual X-Ray action begins, instead of disappearing on a timer.
	if is_boss_warning:
		return

	notice_tween = create_tween()
	notice_tween.tween_interval(1.2)
	notice_tween.tween_property(
		notice_panel,
		"modulate:a",
		0.0,
		0.25
	)
	notice_tween.tween_callback(
		func() -> void:
			boss_warning_active = false
			notice_panel.visible = false
	)


func _hide_notice() -> void:
	boss_warning_active = false
	if notice_tween != null:
		notice_tween.kill()
		notice_tween = null
	if notice_panel != null:
		notice_panel.visible = false


# =========================================================
# RESULT
# =========================================================

func _on_battle_won() -> void:
	_hide_action()
	_hide_notice()

	result_panel.visible = false
	_result_mode = ""

	if _victory_transition_started:
		return

	_victory_transition_started = true

	await get_tree().create_timer(
		2.0
	).timeout

	var return_scene: String = ""

	if get_tree().has_meta(
		"robruzz_return_scene"
	):
		return_scene = str(
			get_tree().get_meta(
				"robruzz_return_scene"
			)
		)

	if return_scene.is_empty():
		return

	await SceneTransition.change_scene(
		return_scene
	)


func _on_battle_lost() -> void:
	_hide_action()
	_hide_notice()

	_victory_transition_started = false

	_show_defeat_result()


func _show_defeat_result() -> void:
	_result_mode = "defeat"

	result_panel.size = root.size
	result_panel.custom_minimum_size = root.size
	result_panel.position = Vector2.ZERO

	result_content.position = Vector2(
		18.0,
		14.0
	)

	result_content.size = (
		root.size -
		Vector2(
			36.0,
			28.0
		)
	)

	result_panel.z_index = 1000

	result_panel.add_theme_stylebox_override(
		"panel",
		_make_defeat_panel_style()
	)

	for child: Node in result_panel.get_children():
		if child is ColorRect:
			(
				child
				as ColorRect
			).visible = false

	result_label.text = (
		"you were demonized."
		+
		"\n"
		+
		"press enter to restart."
	)

	result_label.add_theme_color_override(
		"font_color",
		WHITE
	)

	result_label.add_theme_color_override(
		"font_outline_color",
		Color(
			0.35,
			0.01,
			0.02,
			1.0
		)
	)

	result_label.add_theme_constant_override(
		"outline_size",
		5
	)

	result_sub_label.text = ""
	result_sub_label.visible = false

	result_panel.visible = true
	result_panel.modulate.a = 0.0

	if result_tween != null:
		result_tween.kill()

	result_tween = create_tween()

	result_tween.tween_property(
		result_panel,
		"modulate:a",
		1.0,
		0.18
	)

	_flash(
		0.22,
		Color(
			0.35,
			0.01,
			0.02,
			1.0
		)
	)


func _make_defeat_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()

	style.bg_color = BLACK

	style.border_color = Color(
		0.35,
		0.01,
		0.02,
		1.0
	)

	style.border_width_left = 5
	style.border_width_right = 5
	style.border_width_top = 5
	style.border_width_bottom = 5

	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0

	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 28.0
	style.content_margin_bottom = 28.0

	return style


# =========================================================
# PUBLIC COMPATIBILITY METHODS
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
