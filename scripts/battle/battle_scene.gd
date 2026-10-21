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
var _target_buttons: Array[Button] = []
var _selected_target_index: int = 0
var _party_cards: Array[BattleUnitCard] = []
var _enemy_cards: Array[BattleUnitCard] = []
var _action_feedback_label: Label
var _action_feedback_serial: int = 0
var _results_panel: EncounterResultsPanel
var _action_sequence_running: bool = false
var _transition_processed: bool = false
var _finish_emitted: bool = false
var _ability_menu: BattleAbilityMenu

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	command_selected.connect(_on_command_selected)

	_build_interface()
	_build_formation_cards()
	_build_action_feedback()
	_refresh_presentation()

func configure(context: EncounterContext) -> void:
	encounter_context = context

	battle_session = BattleSession.new(
		encounter_context,
		GameState.gameplay_clock
	)
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
	var feedback_serial: int = _action_feedback_serial

	var action_name: String = (
		action.skill.display_name if action.skill != null else "Attack"
	)

	if action.action_type == BattleAction.Type.BUFF:
		_action_feedback_label.modulate = Color("#ffe183")
		_action_feedback_label.text = "%s\n%s\nATK +%d" % [
			action_name,
			action.target.display_name,
			action.applied_amount
		]
	elif action.action_type == BattleAction.Type.HEALING:
		_action_feedback_label.modulate = Color("#8ff0a4")
		_action_feedback_label.text = "%s\n+%d" % [
			action_name, action.applied_amount
		]
	else:
		_action_feedback_label.modulate = (
			Color("#ffe183")
			if action.action_type == BattleAction.Type.SKILL_DAMAGE
			else Color("#ff9f9f")
		)
		_action_feedback_label.text = "%s\n-%d" % [
			action_name, action.applied_amount
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
	var panel := PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#10171d")
	style.border_color = Color("#71889a")
	style.set_border_width_all(2)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10

	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	_ability_menu = BattleAbilityMenu.new()
	_ability_menu.command_requested.connect(_on_command_selected)
	panel.add_child(_ability_menu)

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
			Color("#587aa0"), Color("#b8d8ff")
		)
		party_card.target_requested.connect(_on_target_selected)
		_party_formation.add_child(party_card)
		_party_cards.append(party_card)

		var enemy_card := BattleUnitCard.new()
		enemy_card.configure_visuals(
			Color("#994d4d"), Color("#ffd0ca")
		)
		enemy_card.target_requested.connect(_on_target_selected)
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

	var targets: Array[Unit] = battle_session.get_selected_targets()
	var command_text: String = battle_session.get_selected_command_text()

	for slot_index in range(MAX_FORMATION_SLOTS):
		var party_unit: Unit = _get_formation_unit(
			battle_session.get_player_squad(), slot_index
		)
		var enemy_unit: Unit = _get_formation_unit(
			battle_session.get_enemy_squad(), slot_index
		)

		_refresh_target_card(
			_party_cards[slot_index], party_unit, targets, command_text
		)
		_refresh_target_card(
			_enemy_cards[slot_index], enemy_unit, targets, command_text
		)

func _refresh_presentation() -> void:
	if (
		_party_formation == null
		or _enemy_formation == null
		or _return_button == null
		or _ability_menu == null
	):
		return

	if _transition_processed:
		return

	if battle_session == null or not battle_session.is_valid():
		_status_label.text = "No valid battle session was received."
		_return_button.disabled = true
		_ability_menu.refresh(null, true)
		return

	var protagonist: Unit = battle_session.get_protagonist()
	var primary_enemy: Unit = battle_session.get_primary_enemy_target()

	var protagonist_name: String = (
		protagonist.display_name
		if protagonist != null
		else "Unknown commander"
	)
	var target_text: String = "No living enemy"

	if battle_session.is_target_selection_active():
		target_text = (
			"Choose a target for %s — WASD/arrows, Enter/Space, Escape."
			% battle_session.get_selected_command_text()
		)
	elif primary_enemy != null:
		target_text = "Primary target: %s" % primary_enemy.display_name

	_status_label.text = (
		"%s | Strategy: %s\nPhase: %s\nCommander: %s | %s"
		% [
			battle_session.get_initiator_text(),
			encounter_context.active_strategy,
			battle_session.get_phase_text(),
			protagonist_name,
			target_text
		]
	)

	var latest_log: String = battle_session.get_latest_log_text(5)

	if not latest_log.is_empty():
		_status_label.text += "\n\n" + latest_log

	_refresh_formation_cards()
	_ability_menu.refresh(battle_session, _action_sequence_running)

	# Automatic ending is the normal route; button remains a fallback.
	_return_button.disabled = (
		not battle_session.is_finished()
		or _action_sequence_running
	)
	_return_button.text = (
		"Return to tactical map"
		if battle_session.is_finished()
		else "Battle in progress"
	)

	if battle_session.is_target_selection_active():
		_configure_target_navigation()
		call_deferred("_focus_first_target")

func _focus_return_button() -> void:
	if _return_button == null or _return_button.disabled:
		return

	_return_button.grab_focus()

func _on_return_button_pressed() -> void:
	if (
		battle_session == null
		or not battle_session.is_finished()
		or _action_sequence_running
		or _transition_processed
	):
		return

	_transition_processed = true
	_return_button.disabled = true

	var result: EncounterResult = GameState.settle_encounter(
		encounter_context
	)

	if result == null or not result.should_show():
		_finish_transition()
		return

	# Remove old action feedback without deleting gameplay presentation.
	_action_feedback_serial += 1

	for child: Node in get_children():
		if child is CanvasItem:
			(child as CanvasItem).hide()

	_results_panel = EncounterResultsPanel.new()
	_results_panel.continued.connect(_finish_transition)
	add_child(_results_panel)
	_results_panel.configure(result)

func _on_command_selected(command_id: StringName) -> void:
	if (
		battle_session == null
		or _action_sequence_running
		or _transition_processed
		or not battle_session.can_accept_protagonist_command()
	):
		return

	_action_feedback_serial += 1

	if _action_feedback_label != null:
		_action_feedback_label.hide()

	battle_session.begin_target_selection(command_id)
	_refresh_presentation()

func _on_enemy_target_selected(target_unit_id: String) -> void:
	# Compatibility entrypoint only.
	_on_target_selected(target_unit_id)

func _continue_after_protagonist_action() -> void:
	if _action_sequence_running or _transition_processed:
		return

	_action_sequence_running = true
	_refresh_presentation()

	await get_tree().create_timer(
		PROTAGONIST_ACTION_DISPLAY_SECONDS
	).timeout

	await _play_automatic_action_sequence()

	_action_sequence_running = false

	if battle_session == null or _transition_processed:
		return

	# Expose the next command menu only after the automatic sequence ends.
	_refresh_presentation()

	if battle_session.is_finished():
		_on_return_button_pressed()

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

	if (
		_selected_target_index < 0
		or _selected_target_index >= _target_buttons.size()
	):
		return

	var target_button: Button = _target_buttons[_selected_target_index]

	if not target_button.has_meta("target_unit_id"):
		push_warning("Target button has no target_unit_id metadata.")
		return

	var target_unit_id: String = String(
		target_button.get_meta("target_unit_id")
	)

	_on_target_selected(target_unit_id)

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
	if _finish_emitted:
		return

	if is_instance_valid(_results_panel):
		if _results_panel.handle_input(event):
			get_viewport().set_input_as_handled()
		return

	if _transition_processed or _action_sequence_running:
		if event is InputEventKey:
			get_viewport().set_input_as_handled()
		return

	if battle_session == null:
		return

	if (
		_ability_menu != null
		and _ability_menu.handle_input(event)
	):
		get_viewport().set_input_as_handled()
		return

	if not battle_session.is_target_selection_active():
		return

	if not event is InputEventKey:
		return

	get_viewport().set_input_as_handled()

	if not event.is_pressed() or event.is_echo():
		return

	if (
		event.is_action_pressed("move_up")
		or event.is_action_pressed("ui_up")
		or event.is_action_pressed("move_left")
		or event.is_action_pressed("ui_left")
	):
		_move_target_focus(-1)

	elif (
		event.is_action_pressed("move_down")
		or event.is_action_pressed("ui_down")
		or event.is_action_pressed("move_right")
		or event.is_action_pressed("ui_right")
	):
		_move_target_focus(1)

	elif (
		event.keycode == KEY_ENTER
		or event.keycode == KEY_KP_ENTER
		or event.keycode == KEY_SPACE
	):
		_confirm_focused_target()

	elif event.is_action_pressed("ui_cancel"):
		battle_session.cancel_target_selection()
		_refresh_presentation()

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

func _finish_transition() -> void:
	if _finish_emitted:
		return

	_finish_emitted = true
	_action_feedback_serial += 1

	# Stop input immediately. SceneManager performs the existing teardown.
	set_process_input(false)
	set_process_unhandled_input(false)

	presentation_finished.emit(encounter_context)

func _refresh_target_card(
	card: BattleUnitCard,
	unit: Unit,
	targets: Array[Unit],
	command_text: String
) -> void:
	card.set_unit(unit)

	var enabled: bool = unit != null and unit in targets
	card.set_target_selection_enabled(enabled, command_text)
	card.tooltip_text = (
		unit.get_attack_buff_summary() if unit != null else ""
	)

	if enabled:
		card.set_meta("target_unit_id", unit.unit_id)
		_target_buttons.append(card)
	elif card.has_meta("target_unit_id"):
		card.remove_meta("target_unit_id")


func _on_target_selected(target_unit_id: String) -> void:
	if (
		battle_session == null
		or _action_sequence_running
		or _transition_processed
	):
		return

	var action: BattleAction = battle_session.confirm_target(target_unit_id)
	_refresh_presentation()

	if action == null or not action.is_valid():
		return

	_show_action_feedback(action)
	_continue_after_protagonist_action()
