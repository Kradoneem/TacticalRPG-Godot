extends "res://scripts/exploration/sewer_corridor_test.gd"

## Adds a maintenance-room visit to the existing corridor test.
## The corridor remains alive while maintenance is presented.

const MAINTENANCE_SCENE_PATH: String = (
    "res://scenes/exploration/sewer_maintenance_test.tscn"
)

enum Destination {
	ENTRANCE,
	MAINTENANCE
}

## Provisional: assign the actual cells before the maintenance opening.
@export var maintenance_cells: Array[Vector2i] = [
	Vector2i(11, 0)
]

var _selected_destination: Destination = Destination.ENTRANCE
var _maintenance_active: bool = false


func _update_exit_hint() -> void:
	if _exit_hint == null:
		return

	if maintenance_cells.has(player_marker.cell):
		_exit_hint.text = (
            "Naar de maintenance room"
			+ "  —  Enter / Spatie: opties"
		)
	else:
		super._update_exit_hint()


func _input(event: InputEvent) -> void:
	if _exit_hint == null or _transitioning:
		return

	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey

	if not key_event.pressed:
		return

	if key_event.echo:
		if _exit_menu_open:
			get_viewport().set_input_as_handled()
		return

	if _exit_menu_open:
		_handle_exit_menu_key(key_event.keycode)
		get_viewport().set_input_as_handled()
		return

	if _calibrating:
		return

	if not _is_confirm_key(key_event.keycode):
		return

	if maintenance_cells.has(player_marker.cell):
		_selected_destination = Destination.MAINTENANCE
	elif entrance_cells.has(player_marker.cell):
		_selected_destination = Destination.ENTRANCE
	else:
		return

	_open_exit_menu()
	get_viewport().set_input_as_handled()


func _refresh_exit_menu() -> void:
	var destination_label: String = (
        "Naar de maintenance room"
		if _selected_destination == Destination.MAINTENANCE
		else "Terug naar de entrance"
	)

	var travel_prefix: String = (
		"> " if _exit_selection == 0 else "  "
	)

	var cancel_prefix: String = (
		"> " if _exit_selection == 1 else "  "
	)

	_exit_menu_text.text = (
        "INGANG\n\n"
		+ travel_prefix
		+ destination_label
		+ "\n"
		+ cancel_prefix
		+ "Annuleren"
		+ "\n\nW/S of pijltjes: kiezen"
		+ "\nEnter / Spatie: bevestigen"
		+ "\nEscape: sluiten"
	)


func _handle_exit_menu_key(keycode: int) -> void:
	if keycode == KEY_ESCAPE:
		_close_exit_menu()
		return

	if keycode in [KEY_W, KEY_UP, KEY_S, KEY_DOWN]:
		_exit_selection = 1 - _exit_selection
		_refresh_exit_menu()
		return

	if not _is_confirm_key(keycode):
		return

	if _exit_selection == 1:
		_close_exit_menu()
		return

	_exit_menu_open = false
	_exit_overlay.hide()
	_transitioning = true

	call_deferred("_travel_to_selected_destination")


func _travel_to_selected_destination() -> void:
	if _selected_destination == Destination.ENTRANCE:
		# Retains the existing entrance departure-cell context.
		_return_to_entrance()
		return

	if SceneManager.get_current_game_scene() != self:
		_recover_from_return_error(
            "Gebruik F5 en betreed de corridor vanuit de entrance."
		)
		return

	# hide() alone does not disable input.
	player_marker.set_input_enabled(false)
	set_process_unhandled_input(false)

	_maintenance_active = true

	var maintenance: Node = SceneManager.present_game_scene(
		MAINTENANCE_SCENE_PATH
	)

	if maintenance == null:
		_maintenance_active = false
		set_process_unhandled_input(true)

		_recover_from_return_error(
            "Maintenance laden mislukt. Controleer Output."
		)


func on_game_presentation_finished(_context: Variant) -> void:
	if not _maintenance_active:
		push_warning(
            "Corridor received an unexpected presentation result."
		)
		return

	_maintenance_active = false
	_transitioning = false

	GameState.current_location = "Sewer Corridor"
	GameState.in_city = false

	set_process_unhandled_input(true)
	player_marker.set_input_enabled(true)

	_update_exit_hint()

	print(
		"Returned from maintenance to the same corridor cell: ",
		player_marker.cell
	)
