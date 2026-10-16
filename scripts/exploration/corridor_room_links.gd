extends "res://scripts/exploration/sewer_corridor_test.gd"

const MapRuntimeScript = preload(
    "res://scripts/systems/tactical_map_runtime.gd"
)
const SewerEnemyContent = preload(
    "res://scripts/content/sewer_enemy_content.gd"
)

const MAINTENANCE_SCENE_PATH: String = (
    "res://scenes/exploration/sewer_maintenance_test.tscn"
)

enum Destination {
	ENTRANCE,
	MAINTENANCE
}

@export var maintenance_cells: Array[Vector2i] = [
	Vector2i(11, 0)
]

@export var rat_start_cell: Vector2i = Vector2i(11, 3)

var _selected_destination: Destination = Destination.ENTRANCE
var _maintenance_active: bool = false
var _combat_presentation_active: bool = false
var _runtime: MapRuntimeScript


func _ready() -> void:
	super._ready()

	if tactical_grid == null or player_marker.squad == null:
		return

	if player_marker.movement_requested.is_connected(
		_on_movement_requested
	):
		player_marker.movement_requested.disconnect(
			_on_movement_requested
		)

	var runtime := MapRuntimeScript.new()
	add_child(runtime)

	var spawns: Array[TacticalEnemySpawn] = [
		TacticalEnemySpawn.new(
			&"corridor_sewer_rats",
			rat_start_cell,
			SewerEnemyContent.create_corridor_rat_squad
		)
	]

	var configured: bool = runtime.configure(
		self,
		player_marker,
		tactical_grid,
		projection,
		"sewer_corridor",
		spawns
	)

	if not configured:
		runtime.queue_free()
		player_marker.set_input_enabled(false)
		_exit_hint.text = (
            "Tactical map configureren mislukt. Controleer Output."
		)
		return

	_runtime = runtime

	_runtime.status_changed.connect(_update_exit_hint)
	_runtime.presentation_active_changed.connect(
		set_combat_presentation_active
	)

	_update_exit_hint()


func _on_movement_requested(_direction: Vector2i) -> void:
	# The shared turncontroller is the exclusive movement owner.
	pass


func _update_exit_hint() -> void:
	if _exit_hint == null:
		return

	if _runtime == null:
		super._update_exit_hint()
		return

	if _runtime.can_open_door():
		if maintenance_cells.has(player_marker.cell):
			_exit_hint.text = (
                "Naar de maintenance room"
				+ "  —  Enter / Spatie: opties"
			)
			return

		if entrance_cells.has(player_marker.cell):
			_exit_hint.text = (
                "Terug naar de entrance"
				+ "  —  Enter / Spatie: opties"
			)
			return

	_exit_hint.text = _runtime.get_status_text()


func _input(event: InputEvent) -> void:
	if _exit_hint == null or _transitioning or _runtime == null:
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

	if key_event.keycode == KEY_F2:
		if not _runtime.can_calibrate():
			get_viewport().set_input_as_handled()
		return

	if not _is_confirm_key(key_event.keycode):
		return

	if not _runtime.can_open_door():
		return

	if maintenance_cells.has(player_marker.cell):
		_selected_destination = Destination.MAINTENANCE
	elif entrance_cells.has(player_marker.cell):
		_selected_destination = Destination.ENTRANCE
	else:
		return

	_runtime.set_suspended(true)
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


func _close_exit_menu() -> void:
	_exit_menu_open = false
	_exit_overlay.hide()

	_runtime.set_suspended(false)
	_update_exit_hint()


func _travel_to_selected_destination() -> void:
	_runtime.save_room_state()

	if _selected_destination == Destination.ENTRANCE:
		_return_to_entrance()
		return

	if SceneManager.get_current_game_scene() != self:
		_recover_from_return_error(
            "Gebruik F5 en betreed de corridor vanuit de entrance."
		)
		return

	_runtime.set_suspended(true)
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


func _recover_from_return_error(message: String) -> void:
	_transitioning = false

	if _runtime != null:
		_runtime.set_suspended(false)

	_exit_hint.text = message
	push_warning(message)


func set_combat_presentation_active(active: bool) -> void:
	_combat_presentation_active = active
	_transitioning = active
	set_process_unhandled_input(not active)


func on_game_presentation_finished(context: Variant) -> void:
	GameState.current_location = "Sewer Corridor"
	GameState.in_city = false

	if _combat_presentation_active:
		set_combat_presentation_active(false)
		_runtime.finish_battle(context)
		return

	if not _maintenance_active:
		push_warning(
            "Corridor received an unexpected presentation result."
		)
		return

	_maintenance_active = false
	_transitioning = false

	set_process_unhandled_input(true)
	_runtime.set_suspended(false)
	_update_exit_hint()

	print(
		"Returned from maintenance to the same corridor cell: ",
		player_marker.cell
	)


func _begin_calibration() -> void:
	if _runtime != null and not _runtime.can_calibrate():
		return

	super._begin_calibration()

	if _runtime != null:
		_runtime.set_suspended(true)


func _finish_calibration() -> void:
	super._finish_calibration()

	if _runtime != null:
		_runtime.set_suspended(false)


func _refresh_projection_visuals() -> void:
	super._refresh_projection_visuals()

	if _runtime != null:
		_runtime.refresh_projection(projection)
