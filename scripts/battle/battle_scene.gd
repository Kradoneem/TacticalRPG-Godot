class_name BattleScene

extends Control

## A temporary 2D side-view presentation of one tactical encounter.
## It receives shared Squad and Unit references through EncounterContext.
## It never owns tactical-grid state.

signal presentation_finished(context: EncounterContext)
signal command_selected(command_id: StringName)

const MAX_FORMATION_SLOTS: int = 4

var encounter_context: EncounterContext
var battle_session: BattleSession
var _party_formation: VBoxContainer
var _enemy_formation: VBoxContainer
var _status_label: Label
var _return_button: Button
var _attack_button: Button
var _focused_strike_button: Button
var _target_buttons: Array[Button] = []
var _selected_target_index: int = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	command_selected.connect(_on_command_selected)

	_build_interface()

func configure(context: EncounterContext) -> void:
	encounter_context = context
	battle_session = BattleSession.new(encounter_context)
	battle_session.begin_battle()

	if not is_node_ready():
		return

	_refresh_presentation()

func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("#18212a")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var outer_margin := MarginContainer.new()
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 42)
	outer_margin.add_theme_constant_override("margin_top", 20)
	outer_margin.add_theme_constant_override("margin_right", 42)
	outer_margin.add_theme_constant_override("margin_bottom", 20)
	add_child(outer_margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	outer_margin.add_child(page)

	var title_label := Label.new()
	title_label.text = "BATTLE PRESENTATION — PROTOTYPE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	page.add_child(title_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.modulate = Color("#c9d4dd")
	page.add_child(_status_label)

	var separator := HSeparator.new()
	page.add_child(separator)

	var formations := HBoxContainer.new()
	formations.size_flags_vertical = Control.SIZE_EXPAND_FILL
	formations.add_theme_constant_override("separation", 40)
	page.add_child(formations)

	_party_formation = _create_formation_column(
		"MAIN SQUAD",
		HORIZONTAL_ALIGNMENT_LEFT
	)
	formations.add_child(_party_formation)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	formations.add_child(spacer)

	_enemy_formation = _create_formation_column(
		"ENEMY SQUAD",
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	formations.add_child(_enemy_formation)

	var footer_separator := HSeparator.new()
	page.add_child(footer_separator)
	_build_command_hud(page)

	_return_button = Button.new()
	_return_button.text = "Return to tactical test"
	_return_button.custom_minimum_size = Vector2(0.0, 42.0)
	_return_button.focus_mode = Control.FOCUS_ALL
	_return_button.pressed.connect(_on_return_button_pressed)
	page.add_child(_return_button)

	var hint_label := Label.new()
	hint_label.text = (
		"Temporary transition test — "
		+ "the battle scene does not resolve combat yet."
	)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.modulate = Color("#aab8c4")
	page.add_child(hint_label)

	_refresh_presentation()

func _build_command_hud(parent: VBoxContainer) -> void:
	var hud_panel := PanelContainer.new()
	hud_panel.custom_minimum_size = Vector2(0.0, 72.0)

	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = Color("#10171d")
	hud_style.border_color = Color("#71889a")
	hud_style.set_border_width_all(2)
	hud_style.set_corner_radius_all(8)
	hud_panel.add_theme_stylebox_override("panel", hud_style)

	parent.add_child(hud_panel)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	hud_panel.add_child(content)

	var command_label := Label.new()
	command_label.text = "COMMAND"
	command_label.custom_minimum_size = Vector2(170.0, 0.0)
	command_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	command_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	command_label.add_theme_font_size_override("font_size", 20)
	content.add_child(command_label)

	_attack_button = _create_command_button(
		"Attack\nReliable physical damage"
	)
	_attack_button.pressed.connect(_on_attack_button_pressed)
	content.add_child(_attack_button)

	_focused_strike_button = _create_command_button(
		"Focused Strike\nPowerful weapon technique"
	)
	_focused_strike_button.pressed.connect(
		_on_focused_strike_button_pressed
	)
	content.add_child(_focused_strike_button)

	_configure_command_navigation()

func _create_command_button(button_text: String) -> Button:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(280.0, 52.0)
	button.focus_mode = Control.FOCUS_ALL

	button.add_theme_stylebox_override(
		"normal",
		_create_command_button_style(
			Color("#27323a"),
			Color("#61707a"),
			2
		)
	)

	button.add_theme_stylebox_override(
		"hover",
		_create_command_button_style(
			Color("#344751"),
			Color("#9fb7c2"),
			2
		)
	)

	button.add_theme_stylebox_override(
		"focus",
		_create_command_button_style(
			Color("#5a5128"),
			Color("#ffe183"),
			4
		)
	)

	button.add_theme_stylebox_override(
		"pressed",
		_create_command_button_style(
			Color("#75652e"),
			Color("#fff1ae"),
			4
		)
	)

	return button

func _create_command_button_style(
	background_color: Color,
	border_color: Color,
	border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)

	return style

func _configure_command_navigation() -> void:
	_attack_button.focus_neighbor_left = _attack_button.get_path_to(
		_focused_strike_button
	)

	_attack_button.focus_neighbor_right = _attack_button.get_path_to(
		_focused_strike_button
	)

	_attack_button.focus_neighbor_top = _attack_button.get_path_to(
		_focused_strike_button
	)

	_attack_button.focus_neighbor_bottom = _attack_button.get_path_to(
		_focused_strike_button
	)

	_focused_strike_button.focus_neighbor_left = (
		_focused_strike_button.get_path_to(_attack_button)
	)

	_focused_strike_button.focus_neighbor_right = (
		_focused_strike_button.get_path_to(_attack_button)
	)

	_focused_strike_button.focus_neighbor_top = (
		_focused_strike_button.get_path_to(_attack_button)
	)

	_focused_strike_button.focus_neighbor_bottom = (
		_focused_strike_button.get_path_to(_attack_button)
	)

func _focus_first_available_command() -> void:
	if _attack_button != null and not _attack_button.disabled:
		_attack_button.grab_focus()
		return

	if (
		_focused_strike_button != null
		and not _focused_strike_button.disabled
	):
		_focused_strike_button.grab_focus()

func _create_formation_column(
	formation_title: String,
	alignment: HorizontalAlignment
) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(350.0, 0.0)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)

	var title_label := Label.new()
	title_label.text = formation_title
	title_label.horizontal_alignment = alignment
	title_label.add_theme_font_size_override("font_size", 22)
	column.add_child(title_label)

	return column

func _refresh_presentation() -> void:
	if _party_formation == null or _enemy_formation == null:
		return

	_clear_formation_slots(_party_formation)
	_clear_formation_slots(_enemy_formation)
	_target_buttons.clear()

	if battle_session == null or not battle_session.is_valid():
		_status_label.text = "No valid battle session was received."
		_return_button.disabled = true
		_attack_button.disabled = true
		_focused_strike_button.disabled = true
		return

	var protagonist := battle_session.get_protagonist()
	var primary_enemy := battle_session.get_primary_enemy_target()

	var protagonist_name := "Unknown commander"
	var target_text := "No living enemy"

	if protagonist != null:
		protagonist_name = protagonist.display_name

	if battle_session.is_target_selection_active():
		target_text = (
			"Choose a target for %s — arrows select, Enter confirms, Escape cancels."
			% battle_session.get_selected_command_text()
		)
	elif primary_enemy != null:
		target_text = "Primary target: %s" % primary_enemy.display_name

	_status_label.text = "%s  |  Strategy: %s\nPhase: %s\nCommander: %s  |  %s" % [
		battle_session.get_initiator_text(),
		encounter_context.active_strategy,
		battle_session.get_phase_text(),
		protagonist_name,
		target_text
	]

	var latest_log := battle_session.get_latest_log_text(5)

	if not latest_log.is_empty():
		_status_label.text += "\n\n" + latest_log

	_attack_button.disabled = not battle_session.can_accept_protagonist_command()

	_focused_strike_button.disabled = (
		protagonist == null
		or not protagonist.knows_skill(&"focused_strike")
		or not battle_session.can_accept_protagonist_command()
	)

	_return_button.disabled = not battle_session.is_finished()

	if battle_session.is_finished():
		_return_button.text = "Return to tactical map"
	else:
		_return_button.text = "Battle in progress"

	_add_formation_slots(
		_party_formation,
		battle_session.get_player_squad(),
		Color("#587aa0"),
		Color("#b8d8ff")
	)

	_add_formation_slots(
		_enemy_formation,
		battle_session.get_enemy_squad(),
		Color("#994d4d"),
		Color("#ffd0ca")
	)

	if battle_session.is_target_selection_active():
		_configure_target_navigation()
		call_deferred("_focus_first_target")
	elif battle_session.can_accept_protagonist_command():
		call_deferred("_focus_first_available_command")

func _clear_formation_slots(formation: VBoxContainer) -> void:
	for child in formation.get_children():
		if child is Label:
			continue

		child.queue_free()


func _add_formation_slots(
	formation: VBoxContainer,
	squad: Squad,
	background_color: Color,
	border_color: Color
) -> void:
	var is_enemy_formation := formation == _enemy_formation

	for slot_index in range(MAX_FORMATION_SLOTS):
		var unit: Unit = null

		if squad != null and slot_index < squad.members.size():
			unit = squad.members[slot_index]

		formation.add_child(
			_create_formation_slot(
				slot_index,
				unit,
				background_color,
				border_color,
				is_enemy_formation
			)
		)

func _create_formation_slot(
	slot_index: int,
	unit: Unit,
	background_color: Color,
	border_color: Color,
	is_enemy_formation: bool
) -> Control:
	var is_targetable := (
		is_enemy_formation
		and unit != null
		and unit.is_alive()
		and battle_session != null
		and battle_session.is_target_selection_active()
	)

	var slot: Control

	if is_targetable:
		var target_button := Button.new()
		target_button.focus_mode = Control.FOCUS_ALL
		target_button.custom_minimum_size = Vector2(350.0, 78.0)
		target_button.tooltip_text = (
			"Target %s with %s"
			% [
				unit.display_name,
				battle_session.get_selected_command_text()
			]
		)
		target_button.set_meta("target_unit_id", unit.unit_id)

		target_button.add_theme_stylebox_override(
			"normal",
			_create_command_button_style(
				Color(background_color, 0.9),
				border_color,
				2
			)
		)

		target_button.add_theme_stylebox_override(
			"hover",
			_create_command_button_style(
				Color("#7a3f3f"),
				Color("#fff0a6"),
				3
			)
		)

		target_button.add_theme_stylebox_override(
			"focus",
			_create_command_button_style(
				Color("#7a5428"),
				Color("#ffe183"),
				4
			)
		)

		target_button.pressed.connect(
			_on_enemy_target_selected.bind(unit.unit_id)
		)

		_target_buttons.append(target_button)
		slot = target_button
	else:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(350.0, 78.0)

		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(background_color, 0.9)
		panel_style.border_color = border_color
		panel_style.set_border_width_all(2)
		panel_style.set_corner_radius_all(8)

		panel.add_theme_stylebox_override("panel", panel_style)
		slot = panel

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 2)
	slot.add_child(content)

	if unit == null:
		var empty_label := Label.new()
		empty_label.text = "FORMATION SLOT %d — EMPTY" % (slot_index + 1)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty_label.modulate = Color("#93a0aa")
		content.add_child(empty_label)

		return slot

	var name_label := Label.new()
	name_label.text = unit.display_name
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 18)
	content.add_child(name_label)

	var hp_label := Label.new()
	hp_label.text = "HP %d / %d" % [unit.hp, unit.max_hp]
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(hp_label)

	var hp_bar := ProgressBar.new()
	hp_bar.max_value = unit.max_hp
	hp_bar.value = unit.hp
	hp_bar.show_percentage = false
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.custom_minimum_size = Vector2(0.0, 12.0)
	content.add_child(hp_bar)

	var mp_label := Label.new()
	mp_label.text = "MP %d / %d" % [unit.mp, unit.max_mp]
	mp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mp_label.modulate = Color("#d2e3ff")
	content.add_child(mp_label)

	return slot

func _on_return_button_pressed() -> void:
	if battle_session == null or not battle_session.is_finished():
		return

	presentation_finished.emit(encounter_context)

func _on_attack_button_pressed() -> void:
	if battle_session == null:
		return

	if not battle_session.can_accept_protagonist_command():
		return

	command_selected.emit(&"basic_attack")

func _on_focused_strike_button_pressed() -> void:
	if battle_session == null:
		return

	if not battle_session.can_accept_protagonist_command():
		return

	command_selected.emit(&"focused_strike")

func _on_command_selected(command_id: StringName) -> void:
	if battle_session == null:
		return

	battle_session.begin_enemy_target_selection(command_id)
	_refresh_presentation()

func _on_enemy_target_selected(target_unit_id: String) -> void:
	if battle_session == null:
		return

	battle_session.confirm_enemy_target(target_unit_id)
	_refresh_presentation()

func _focus_first_target() -> void:
	if _target_buttons.is_empty():
		return

	_selected_target_index = 0
	_target_buttons[_selected_target_index].grab_focus()


func _move_target_focus(direction: int) -> void:
	if _target_buttons.is_empty():
		return

	_selected_target_index = posmod(
		_selected_target_index + direction,
		_target_buttons.size()
	)

	_target_buttons[_selected_target_index].grab_focus()

func _confirm_focused_target() -> void:
	if _target_buttons.is_empty():
		return

	var target_button := _target_buttons[_selected_target_index]

	if not target_button.has_meta("target_unit_id"):
		push_warning("Target button has no target_unit_id metadata.")
		return

	var target_unit_id := String(
		target_button.get_meta("target_unit_id")
	)

	_on_enemy_target_selected(target_unit_id)

func _configure_target_navigation() -> void:
	if _target_buttons.is_empty():
		return

	for target_index in range(_target_buttons.size()):
		var current_button := _target_buttons[target_index]

		var previous_index := posmod(
			target_index - 1,
			_target_buttons.size()
		)

		var next_index := posmod(
			target_index + 1,
			_target_buttons.size()
		)

		var previous_button := _target_buttons[previous_index]
		var next_button := _target_buttons[next_index]

		current_button.focus_neighbor_top = (
			current_button.get_path_to(previous_button)
		)

		current_button.focus_neighbor_bottom = (
			current_button.get_path_to(next_button)
		)

		current_button.focus_neighbor_left = (
			current_button.get_path_to(previous_button)
		)

		current_button.focus_neighbor_right = (
			current_button.get_path_to(next_button)
		)

func _input(event: InputEvent) -> void:
	if (
		not event is InputEventKey
		or not event.is_pressed()
		or event.is_echo()
		or battle_session == null
		or not battle_session.is_target_selection_active()
	):
		return

	match event.keycode:
		KEY_UP, KEY_LEFT:
			_move_target_focus(-1)
			get_viewport().set_input_as_handled()

		KEY_DOWN, KEY_RIGHT:
			_move_target_focus(1)
			get_viewport().set_input_as_handled()

		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_confirm_focused_target()
			get_viewport().set_input_as_handled()

		KEY_ESCAPE:
			battle_session.cancel_target_selection()
			_refresh_presentation()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	## Tactical movement must not leak through to the hidden tactical scene.
	if event.is_action_pressed("move_up"):
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("move_down"):
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("move_left"):
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("move_right"):
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("engage"):
		get_viewport().set_input_as_handled()
