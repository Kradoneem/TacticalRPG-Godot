class_name BattleScene

extends Control

## A temporary 2D side-view presentation of one tactical encounter.
## It receives shared Squad and Unit references through EncounterContext.
## It never owns tactical-grid state.

signal presentation_finished(context: EncounterContext)
signal command_selected(command_id: StringName)

const MAX_FORMATION_SLOTS: int = 4
const PROTAGONIST_ACTION_DISPLAY_SECONDS: float = 0.8

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
var _party_cards: Array[BattleUnitCard] = []
var _enemy_cards: Array[BattleUnitCard] = []
var _action_feedback_label: Label
var _action_feedback_serial: int = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	command_selected.connect(_on_command_selected)

	_build_interface()
	_build_formation_cards()
	_build_action_feedback()
	_refresh_presentation()

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
		+ "Actions resolve one at a time."
	)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.modulate = Color("#aab8c4")
	page.add_child(hint_label)

	_refresh_presentation()

func _build_action_feedback() -> void:
	_action_feedback_label = Label.new()
	_action_feedback_label.set_anchors_preset(Control.PRESET_CENTER)

	_action_feedback_label.offset_left = -220.0
	_action_feedback_label.offset_top = -70.0
	_action_feedback_label.offset_right = 220.0
	_action_feedback_label.offset_bottom = 70.0

	_action_feedback_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_action_feedback_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	_action_feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_action_feedback_label.add_theme_font_size_override("font_size", 34)
	_action_feedback_label.add_theme_color_override(
		"font_outline_color",
		Color("#10171d")
	)
	_action_feedback_label.add_theme_constant_override("outline_size", 8)

	_action_feedback_label.hide()
	add_child(_action_feedback_label)
	
func _show_action_feedback(action: BattleAction) -> void:
	if (
		action == null
		or not action.is_valid()
		or _action_feedback_label == null
	):
		return

	_action_feedback_serial += 1
	var feedback_serial := _action_feedback_serial

	var action_name := "Attack"
	var amount_prefix := "-"

	if action.skill != null:
		action_name = action.skill.display_name

	if action.action_type == BattleAction.Type.HEALING:
		amount_prefix = "+"
		_action_feedback_label.modulate = Color("#8ff0a4")
	elif action.action_type == BattleAction.Type.SKILL_DAMAGE:
		_action_feedback_label.modulate = Color("#ffe183")
	else:
		_action_feedback_label.modulate = Color("#ff9f9f")

	_action_feedback_label.text = "%s\n%s%d" % [
		action_name,
		amount_prefix,
		action.applied_amount
	]

	_action_feedback_label.show()
	_hide_action_feedback_after_delay(feedback_serial)
	
func _hide_action_feedback_after_delay(
	feedback_serial: int
) -> void:
	await get_tree().create_timer(0.65).timeout

	if (
		_action_feedback_label == null
		or feedback_serial != _action_feedback_serial
	):
		return

	_action_feedback_label.hide()

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

func _build_formation_cards() -> void:
	_party_cards.clear()
	_enemy_cards.clear()

	for slot_index in range(MAX_FORMATION_SLOTS):
		var party_card := BattleUnitCard.new()
		party_card.configure_visuals(
			Color("#587aa0"),
			Color("#b8d8ff")
		)

		_party_formation.add_child(party_card)
		_party_cards.append(party_card)

		var enemy_card := BattleUnitCard.new()
		enemy_card.configure_visuals(
			Color("#994d4d"),
			Color("#ffd0ca")
		)

		enemy_card.target_requested.connect(
			_on_enemy_target_selected
		)

		_enemy_formation.add_child(enemy_card)
		_enemy_cards.append(enemy_card)

func _get_formation_unit(
	squad: Squad,
	slot_index: int
) -> Unit:
	if squad == null or slot_index >= squad.members.size():
		return null

	return squad.members[slot_index]
	

func _refresh_formation_cards() -> void:
	_target_buttons.clear()

	var player_squad := battle_session.get_player_squad()
	var enemy_squad := battle_session.get_enemy_squad()

	var target_selection_active := (
		battle_session.is_target_selection_active()
	)

	var selected_command_text := (
		battle_session.get_selected_command_text()
	)

	for slot_index in range(MAX_FORMATION_SLOTS):
		var party_card := _party_cards[slot_index]
		var party_unit := _get_formation_unit(
			player_squad,
			slot_index
		)

		party_card.set_unit(party_unit)
		party_card.set_target_selection_enabled(false, "")

		var enemy_card := _enemy_cards[slot_index]
		var enemy_unit := _get_formation_unit(
			enemy_squad,
			slot_index
		)

		var can_target_enemy := (
			target_selection_active
			and enemy_unit != null
			and enemy_unit.is_alive()
		)

		enemy_card.set_unit(enemy_unit)
		enemy_card.set_target_selection_enabled(
			can_target_enemy,
			selected_command_text
		)

		if can_target_enemy:
			enemy_card.set_meta(
				"target_unit_id",
				enemy_unit.unit_id
			)

			_target_buttons.append(enemy_card)
		elif enemy_card.has_meta("target_unit_id"):
			enemy_card.remove_meta("target_unit_id")

func _refresh_presentation() -> void:
	if _party_formation == null or _enemy_formation == null:
		return

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

	_status_label.text = "%s | Strategy: %s\nPhase: %s\nCommander: %s | %s" % [
		battle_session.get_initiator_text(),
		encounter_context.active_strategy,
		battle_session.get_phase_text(),
		protagonist_name,
		target_text
	]

	var latest_log := battle_session.get_latest_log_text(5)

	if not latest_log.is_empty():
		_status_label.text += "\n\n" + latest_log

	_attack_button.disabled = (
		not battle_session.can_accept_protagonist_command()
	)

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

	_refresh_formation_cards()

	if battle_session.is_finished():
		call_deferred("_focus_return_button")
	elif battle_session.is_target_selection_active():
		_configure_target_navigation()
		call_deferred("_focus_first_target")
	elif battle_session.can_accept_protagonist_command():
		call_deferred("_focus_first_available_command")

func _focus_return_button() -> void:
	if _return_button == null or _return_button.disabled:
		return

	_return_button.grab_focus()

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

	_action_feedback_serial += 1

	if _action_feedback_label != null:
		_action_feedback_label.hide()

	battle_session.begin_enemy_target_selection(command_id)
	_refresh_presentation()

func _on_enemy_target_selected(target_unit_id: String) -> void:
	if battle_session == null:
		return

	var resolved_action := battle_session.confirm_enemy_target(
		target_unit_id
	)

	_refresh_presentation()

	if resolved_action == null or not resolved_action.is_valid():
		return

	_show_action_feedback(resolved_action)
	_continue_after_protagonist_action()

func _continue_after_protagonist_action() -> void:
	await get_tree().create_timer(
		PROTAGONIST_ACTION_DISPLAY_SECONDS
	).timeout

	_play_automatic_action_sequence()

func _play_automatic_action_sequence() -> void:
	while battle_session != null:
		var resolved_action := (
			battle_session.resolve_next_automatic_action()
		)

		_refresh_presentation()

		if resolved_action == null:
			return

		_show_action_feedback(resolved_action)

		await get_tree().create_timer(
			PROTAGONIST_ACTION_DISPLAY_SECONDS
		).timeout

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
