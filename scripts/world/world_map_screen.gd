class_name WorldMapScreen
extends Control

enum Page { SELECT, CONFIRM }

var _current: WorldLocation
var _locations: Array[WorldLocation] = []

var _page: Page = Page.SELECT
var _pending_id: StringName = &""
var _selected_index: int = 0
var _page_frame: int = -1
var _transitioning: bool = false
var _message: String = ""

var _title: Label
var _status: Label
var _map_layer: Control
var _confirm_panel: PanelContainer
var _confirm_label: Label

## One button per location, then "Terug" as the last entry.
var _map_buttons: Array[Button] = []
var _confirm_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	GameState.in_city = false

	_current = WorldMapData.get_location(GameState.world_location_id)

	if _current == null:
		push_error("World map: onbekende huidige locatie, fallback Aldenmoor.")
		_current = WorldMapData.get_location(WorldMapData.ALDENMOOR_ID)

	_locations = WorldMapData.get_locations()

	_build_screen()
	_show_select()
	call_deferred("_update_layout")


func _build_screen() -> void:
	var background := ColorRect.new()
	background.color = Color("#1d2a30")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var header := VBoxContainer.new()
	header.position = Vector2(24.0, 20.0)
	header.custom_minimum_size = Vector2(900.0, 100.0)
	add_child(header)

	_title = Label.new()
	_title.text = "World map"
	_title.add_theme_font_size_override("font_size", 28)
	header.add_child(_title)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_status)

	_map_layer = Control.new()
	_map_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map_layer)

	for location: WorldLocation in _locations:
		var button := _make_button()
		button.pressed.connect(
			_on_location_pressed.bind(location.location_id)
		)
		_map_layer.add_child(button)
		_map_buttons.append(button)

	var back := _make_button()
	back.text = "Terug"
	back.pressed.connect(_on_back_pressed)
	_map_layer.add_child(back)
	_map_buttons.append(back)

	_confirm_panel = PanelContainer.new()
	_confirm_panel.anchor_left = 0.30
	_confirm_panel.anchor_right = 0.70
	_confirm_panel.anchor_top = 0.35
	_confirm_panel.anchor_bottom = 0.65
	_confirm_panel.hide()
	add_child(_confirm_panel)

	var margin := MarginContainer.new()

	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)

	_confirm_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	_confirm_label = Label.new()
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_confirm_label)

	var confirm := _make_button()
	confirm.text = "Confirm"
	confirm.pressed.connect(_commit_travel)
	box.add_child(confirm)
	_confirm_buttons.append(confirm)

	var cancel := _make_button()
	cancel.text = "Cancel"
	cancel.pressed.connect(_cancel_confirm)
	box.add_child(cancel)
	_confirm_buttons.append(cancel)

	resized.connect(_update_layout)


func _make_button() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(260.0, 56.0)

	# Only our keyboard handler confirms; mouse still works.
	button.focus_mode = Control.FOCUS_NONE

	return button


func _show_select() -> void:
	_page = Page.SELECT
	_page_frame = Engine.get_process_frames()
	_pending_id = &""
	_confirm_panel.hide()

	_refresh_buttons()
	_selected_index = _first_enabled_index(_map_buttons)
	_update_status()
	_update_layout()
	_refresh_selection()


func _show_confirm(destination: WorldLocation) -> void:
	_page = Page.CONFIRM
	_page_frame = Engine.get_process_frames()
	_selected_index = 0

	var today: int = floori(GameState.day)
	var arrival: int = floori(GameState.day + WorldMapData.TRAVEL_DAYS)

	_confirm_label.text = (
		"Reizen naar %s?\nKost %d dag(en): dag %d → dag %d."
		% [
			destination.display_name,
			roundi(WorldMapData.TRAVEL_DAYS),
			today,
			arrival
		]
	)

	_confirm_panel.show()
	_update_status()
	_refresh_selection()


func _refresh_buttons() -> void:
	for index in range(_locations.size()):
		var location: WorldLocation = _locations[index]
		var button: Button = _map_buttons[index]

		if location.location_id == _current.location_id:
			button.text = "◆ %s — hier" % location.display_name
			button.disabled = true
		elif WorldMapData.are_connected(
			_current.location_id,
			location.location_id
		):
			button.text = "%s — %d dag(en)" % [
				location.display_name,
				roundi(WorldMapData.TRAVEL_DAYS)
			]
			button.disabled = false
		else:
			button.text = "%s — niet verbonden" % location.display_name
			button.disabled = true


func _update_status() -> void:
	var controls: String = (
		"Escape: annuleren"
		if _page == Page.CONFIRM
		else "WASD/pijltjes: selecteren | Enter/Spatie: kiezen | Escape: Party"
	)

	_status.text = "Dag %d | Huidige locatie: %s\n%s" % [
		floori(GameState.day),
		_current.display_name,
		controls
	]

	if not _message.is_empty():
		_status.text += "\n" + _message


func _update_layout() -> void:
	if _map_layer == null or _map_buttons.is_empty():
		return

	for index in range(_locations.size()):
		var button: Button = _map_buttons[index]
		var button_size: Vector2 = button.get_combined_minimum_size()

		button.size = button_size
		button.position = (
			_locations[index].map_position_ratio * _map_layer.size
			- button_size * 0.5
		)

	var back: Button = _map_buttons[_map_buttons.size() - 1]
	var back_size: Vector2 = back.get_combined_minimum_size()

	back.size = back_size
	back.position = (
		Vector2(_map_layer.size.x * 0.5, _map_layer.size.y * 0.92)
		- back_size * 0.5
	)


func _active_buttons() -> Array[Button]:
	return _confirm_buttons if _page == Page.CONFIRM else _map_buttons


func _first_enabled_index(buttons: Array[Button]) -> int:
	for index in range(buttons.size()):
		if not buttons[index].disabled:
			return index

	return 0


func _refresh_selection() -> void:
	var buttons: Array[Button] = _active_buttons()

	for button: Button in _map_buttons:
		button.modulate = Color.WHITE

	for button: Button in _confirm_buttons:
		button.modulate = Color.WHITE

	if _selected_index >= 0 and _selected_index < buttons.size():
		buttons[_selected_index].modulate = Color("#ffe183")


func _move_selection(direction: int) -> void:
	var buttons: Array[Button] = _active_buttons()

	if buttons.is_empty():
		return

	for attempt in range(buttons.size()):
		_selected_index = posmod(
			_selected_index + direction,
			buttons.size()
		)

		if not buttons[_selected_index].disabled:
			break

	_refresh_selection()


func _confirm_selection() -> void:
	if Engine.get_process_frames() <= _page_frame:
		return

	var buttons: Array[Button] = _active_buttons()

	if (
		_selected_index < 0
		or _selected_index >= buttons.size()
		or buttons[_selected_index].disabled
	):
		return

	buttons[_selected_index].pressed.emit()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	if event.is_action("ui_cancel"):
		if _page == Page.CONFIRM:
			get_viewport().set_input_as_handled()

			if event.is_pressed() and not event.is_echo():
				_cancel_confirm()

		# Outside CONFIRM, Escape stays available to PartyMenuController.
		return

	get_viewport().set_input_as_handled()

	if _transitioning or not event.is_pressed() or event.is_echo():
		return

	if (
		event.is_action_pressed("move_up")
		or event.is_action_pressed("ui_up")
		or event.is_action_pressed("move_left")
		or event.is_action_pressed("ui_left")
	):
		_move_selection(-1)

	elif (
		event.is_action_pressed("move_down")
		or event.is_action_pressed("ui_down")
		or event.is_action_pressed("move_right")
		or event.is_action_pressed("ui_right")
	):
		_move_selection(1)

	elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_confirm_selection()


func _on_location_pressed(location_id: StringName) -> void:
	if _transitioning or _page != Page.SELECT:
		return

	if not WorldMapData.are_connected(_current.location_id, location_id):
		return

	var destination: WorldLocation = WorldMapData.get_location(location_id)

	if destination == null:
		return

	_message = ""
	_pending_id = location_id
	_show_confirm(destination)


func _cancel_confirm() -> void:
	if _transitioning or _page != Page.CONFIRM:
		return

	_message = "Reis geannuleerd."
	_show_select()


func _commit_travel() -> void:
	if _transitioning or _page != Page.CONFIRM:
		return

	var destination: WorldLocation = WorldMapData.get_location(_pending_id)
	var result: Dictionary = GameState.travel_to_location(_pending_id)

	if destination == null or not bool(result.get("success", false)):
		_message = String(result.get("message", "Reis mislukt."))
		_show_select()
		return

	_current = destination
	_message = String(result.get("message", ""))
	_transitioning = true

	# Deferred: never change the scene tree inside a Button callback.
	call_deferred("_enter_location", destination)


func _on_back_pressed() -> void:
	if _transitioning or _page != Page.SELECT:
		return

	_transitioning = true
	call_deferred("_enter_location", _current)


func _enter_location(location: WorldLocation) -> void:
	var next: Node = SceneManager.change_game_scene(
		location.scene_path,
		location
	)

	if next != null:
		return

	_transitioning = false
	_message = "Scene kon niet openen. Controleer Output."
	_show_select()


func can_open_party_menu() -> bool:
	return not _transitioning and _page != Page.CONFIRM


func can_show_quest_updates() -> bool:
	return not _transitioning
