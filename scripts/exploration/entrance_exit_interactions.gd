extends Node

## Context interactions for this entrance test.
## The parent owns the grid and calibration.
## This node owns exits, menu input and transition requests.

const CITY_SCENE_PATH: String = (
    "res://scenes/exploration/city_return_test.tscn"
)
const CORRIDOR_SCENE_PATH: String = (
    "res://scenes/exploration/sewer_corridor_test.tscn"
)

enum Exit {
	NONE,
	CITY,
	CORRIDOR
}

@export var city_cells: Array[Vector2i] = [
	Vector2i(0, 2),
	Vector2i(0, 3)
]

@export var corridor_cells: Array[Vector2i] = [
	Vector2i(6, 0),
	Vector2i(7, 0)
]

@onready var entrance: Node2D = get_parent() as Node2D
@onready var player_marker: TacticalPlayer = (
	get_parent().get_node("PlayerMarker") as TacticalPlayer
)

var _hint: Label
var _menu_overlay: ColorRect
var _menu_text: Label

var _menu_open: bool = false
var _menu_exit: Exit = Exit.NONE
var _selection: int = 0
var _transitioning: bool = false


func _ready() -> void:
	_build_ui()

	player_marker.cell_changed.connect(_on_cell_changed)

	# Let the entrance root finish its own _ready first.
	call_deferred("_initialize_location")


func _initialize_location() -> void:
	GameState.current_location = "Sewer Entrance"
	GameState.in_city = false
	_update_hint()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)

	_hint = Label.new()
	_hint.position = Vector2(24.0, 970.0)
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hint)

	_menu_overlay = ColorRect.new()
	_menu_overlay.color = Color(0.02, 0.03, 0.04, 0.82)
	_menu_overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_menu_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(_menu_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_menu_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560.0, 260.0)
	center.add_child(panel)

	var margin := MarginContainer.new()

	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)

	panel.add_child(margin)

	_menu_text = Label.new()
	_menu_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_menu_text.add_theme_font_size_override("font_size", 24)
	margin.add_child(_menu_text)

	_menu_overlay.hide()


func _process(_delta: float) -> void:
	if _hint == null or _transitioning:
		return

	# The calibration UI has its own input flow.
	_hint.visible = not _is_calibrating() and not _menu_open


func _is_calibrating() -> bool:
	return bool(entrance.get("_calibrating"))


func _get_available_exit() -> Exit:
	if city_cells.has(player_marker.cell):
		return Exit.CITY

	if corridor_cells.has(player_marker.cell):
		return Exit.CORRIDOR

	return Exit.NONE


func _get_exit_label(exit_kind: Exit) -> String:
	match exit_kind:
		Exit.CITY:
			return "Terug naar de stad"
		Exit.CORRIDOR:
			return "Door naar de corridor"

	return ""


func _on_cell_changed(
	_previous_cell: Vector2i,
	_new_cell: Vector2i
) -> void:
	_update_hint()


func _update_hint() -> void:
	if _hint == null:
		return

	var available_exit: Exit = _get_available_exit()

	if available_exit == Exit.NONE:
		_hint.text = ""
		return

	_hint.text = (
		_get_exit_label(available_exit)
		+ "  —  Enter / Spatie: opties"
	)


func _input(event: InputEvent) -> void:
	if _transitioning or _hint == null:
		return

	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey

	if not key_event.pressed:
		return

	if key_event.echo:
		if _menu_open:
			get_viewport().set_input_as_handled()
		return

	if _menu_open:
		_handle_menu_key(key_event.keycode)
		get_viewport().set_input_as_handled()
		return

	if _is_calibrating():
		return

	if not _is_confirm_key(key_event.keycode):
		return

	var available_exit: Exit = _get_available_exit()

	if available_exit == Exit.NONE:
		return

	_open_menu(available_exit)
	get_viewport().set_input_as_handled()


func _is_confirm_key(keycode: int) -> bool:
	return keycode in [
		KEY_ENTER,
		KEY_KP_ENTER,
		KEY_SPACE
	]


func _open_menu(exit_kind: Exit) -> void:
	_menu_exit = exit_kind
	_selection = 0
	_menu_open = true

	player_marker.set_input_enabled(false)
	_hint.hide()
	_menu_overlay.show()
	_refresh_menu()


func _refresh_menu() -> void:
	var travel_prefix: String = "> " if _selection == 0 else "  "
	var cancel_prefix: String = "> " if _selection == 1 else "  "

	_menu_text.text = (
        "INGANG\n\n"
		+ travel_prefix
		+ _get_exit_label(_menu_exit)
		+ "\n"
		+ cancel_prefix
		+ "Annuleren"
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

	# Capture the actual departure cell, not an assumed spawn location.
	var departure_cell: Vector2i = player_marker.cell
	var selected_exit: Exit = _menu_exit

	_menu_open = false
	_menu_overlay.hide()
	_transitioning = true

	# Avoid replacing the scene from inside input dispatch.
	call_deferred(
		"_perform_transition",
		selected_exit,
		departure_cell
	)


func _close_menu() -> void:
	_menu_open = false
	_menu_exit = Exit.NONE
	_menu_overlay.hide()

	player_marker.set_input_enabled(true)
	_update_hint()
	_hint.show()


func _perform_transition(
	selected_exit: Exit,
	departure_cell: Vector2i
) -> void:
	# F6 runs this scene without Main. It can test the menu,
	# but actual SceneManager transitions require F5.
	if SceneManager.get_current_game_scene() != entrance:
		_recover_from_transition_error(
            "Start met F5 om kamerwissels te testen; F6 mist Main."
		)
		return

	var destination_path: String = (
		CITY_SCENE_PATH
		if selected_exit == Exit.CITY
		else CORRIDOR_SCENE_PATH
	)

	var destination: Node = SceneManager.change_game_scene(
		destination_path
	)

	if destination == null:
		_recover_from_transition_error(
            "Bestemming laden mislukt. Controleer Output."
		)
		return

	# This is the explicit contract of our two new test destinations.
	destination.call("configure_return", departure_cell)


func _recover_from_transition_error(message: String) -> void:
	_transitioning = false
	player_marker.set_input_enabled(true)
	_hint.text = message
	_hint.show()
	push_warning(message)
