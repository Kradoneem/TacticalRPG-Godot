extends Node

## Shared exit interaction.
## Owns UI and input, but does not load scenes or own movement.
## The host supplies permission and handles transition requests.

signal interaction_active_changed(active: bool)
signal travel_requested(
	exit_data: ExplorationExitData,
	departure_cell: Vector2i
)

var _player: TacticalPlayer
var _exits: Array[ExplorationExitData] = []
var _can_interact: Callable
var _configured: bool = false

var _hint: Label
var _overlay: ColorRect
var _menu_text: Label

var _menu_open: bool = false
var _selection: int = 0
var _selected_exit: ExplorationExitData
var _transition_pending: bool = false
var _error_message: String = ""


func configure(
	assigned_player: TacticalPlayer,
	assigned_exits: Array[ExplorationExitData],
	permission_check: Callable
) -> bool:
	if _configured:
		push_error("ExplorationExitController cannot be configured twice.")
		return false

	if assigned_player == null or not permission_check.is_valid():
		push_error("Exit controller received incomplete configuration.")
		return false

	var known_ids: Dictionary = {}
	var occupied_cells: Dictionary = {}

	for exit_data: ExplorationExitData in assigned_exits:
		if exit_data == null or not exit_data.is_valid():
			push_error("Map contains an invalid exit definition.")
			return false

		if known_ids.has(exit_data.exit_id):
			push_error("Exit IDs must be unique within a map.")
			return false

		known_ids[exit_data.exit_id] = true

		for cell: Vector2i in exit_data.cells:
			if not assigned_player.is_cell_walkable(cell):
				push_error(
					"Exit '%s' contains a non-walkable cell: %s"
					% [str(exit_data.exit_id), str(cell)]
				)
				return false

			if occupied_cells.has(cell):
				push_error("Exit interaction zones cannot overlap.")
				return false

			occupied_cells[cell] = true

	_player = assigned_player
	_exits.assign(assigned_exits)
	_can_interact = permission_check

	_build_ui()
	_player.cell_changed.connect(_on_cell_changed)

	_configured = true
	_refresh_hint()
	return true


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)

	_hint = Label.new()
	_hint.position = Vector2(24.0, 970.0)
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hint)

	_overlay = ColorRect.new()
	_overlay.color = Color(0.02, 0.03, 0.04, 0.82)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560.0, 260.0)
	center.add_child(panel)

	var margin := MarginContainer.new()

	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)

	panel.add_child(margin)

	_menu_text = Label.new()
	_menu_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_menu_text.add_theme_font_size_override("font_size", 24)
	margin.add_child(_menu_text)

	_overlay.hide()


func _process(_delta: float) -> void:
	if not _configured:
		return

	_hint.visible = (
		not _menu_open
		and not _transition_pending
		and _interaction_is_allowed()
	)


func _interaction_is_allowed() -> bool:
	return (
		_can_interact.is_valid()
		and bool(_can_interact.call())
	)


func _find_exit(target_cell: Vector2i) -> ExplorationExitData:
	for exit_data: ExplorationExitData in _exits:
		if exit_data.contains_cell(target_cell):
			return exit_data

	return null


func _on_cell_changed(
	_previous_cell: Vector2i,
	_new_cell: Vector2i
) -> void:
	_error_message = ""
	_refresh_hint()


func _refresh_hint() -> void:
	if _hint == null:
		return

	if not _error_message.is_empty():
		_hint.text = _error_message
		return

	var available_exit: ExplorationExitData = _find_exit(_player.cell)

	if available_exit == null:
		_hint.text = ""
	else:
		_hint.text = (
			available_exit.display_name
			+ "  —  Enter / Spatie: opties"
		)


func _input(event: InputEvent) -> void:
	if not _configured or _transition_pending:
		return

	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey

	if not key_event.pressed:
		return

	if _menu_open:
		if not key_event.echo:
			_handle_menu_key(key_event.keycode)

		get_viewport().set_input_as_handled()
		return

	if key_event.echo or not _interaction_is_allowed():
		return

	if not _is_confirm_key(key_event.keycode):
		return

	var available_exit: ExplorationExitData = _find_exit(_player.cell)

	if available_exit == null:
		return

	_open_menu(available_exit)
	get_viewport().set_input_as_handled()


func _is_confirm_key(keycode: int) -> bool:
	return keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]


func _open_menu(exit_data: ExplorationExitData) -> void:
	_selected_exit = exit_data
	_selection = 0
	_error_message = ""
	_menu_open = true

	interaction_active_changed.emit(true)

	_hint.hide()
	_overlay.show()
	_refresh_menu()


func _refresh_menu() -> void:
	var travel_prefix: String = "> " if _selection == 0 else "  "
	var cancel_prefix: String = "> " if _selection == 1 else "  "

	_menu_text.text = (
		"INGANG\n\n"
		+ travel_prefix + _selected_exit.display_name
		+ "\n"
		+ cancel_prefix + "Annuleren"
		+ "\n\nW/S of pijltjes: kiezen"
		+ "\nEnter / Spatie: bevestigen"
		+ "\nEscape: sluiten"
	)


func _handle_menu_key(keycode: int) -> void:
	if keycode == KEY_ESCAPE:
		_close_menu()
		return

	if keycode in [KEY_W, KEY_UP, KEY_S, KEY_DOWN]:
		_selection = 1 - _selection
		_refresh_menu()
		return

	if not _is_confirm_key(keycode):
		return

	if _selection == 1:
		_close_menu()
		return

	var departure_cell: Vector2i = _player.cell
	var exit_data: ExplorationExitData = _selected_exit

	_menu_open = false
	_transition_pending = true
	_overlay.hide()
	_hint.hide()

	# Movement remains suspended until travel succeeds or fails.
	# Defer the request so scene replacement is outside input dispatch.
	call_deferred("_emit_travel_request", exit_data, departure_cell)


func _emit_travel_request(
	exit_data: ExplorationExitData,
	departure_cell: Vector2i
) -> void:
	travel_requested.emit(exit_data, departure_cell)


func _close_menu() -> void:
	_menu_open = false
	_selected_exit = null
	_overlay.hide()

	interaction_active_changed.emit(false)
	_refresh_hint()


func recover_from_transition_error(message: String) -> void:
	_transition_pending = false
	_selected_exit = null
	_error_message = message

	interaction_active_changed.emit(false)
	_refresh_hint()

	push_warning(message)
