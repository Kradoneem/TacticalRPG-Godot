extends "res://scripts/exploration/sewer_entrance_test.gd"

## Reuses the existing three-point calibration and squad movement.
## Adds corridor-specific calibration exports and a contextual return.
##
## The entrance departure cell belongs to the entrance map.
## start_cell belongs to this corridor map.

const ENTRANCE_SCENE_PATH: String = (
    "res://scenes/exploration/sewer_entrance_test.tscn"
)

## Provisional cells: validate these against the calibrated background.
@export var entrance_cells: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(0, 1),
	Vector2i(0, 2)
]

var _entrance_return_cell: Vector2i
var _has_return_context: bool = false
var _incoming_squad: Squad

var _exit_hint: Label
var _exit_overlay: ColorRect
var _exit_menu_text: Label

var _exit_menu_open: bool = false
var _exit_selection: int = 0
var _transitioning: bool = false


func _ready() -> void:
	# Initializes the same grid, projection, token and calibration UI.
	super._ready()

	if tactical_grid == null or projection == null:
		return

	if player_marker.squad == null:
		return

	GameState.current_location = "Sewer Corridor"
	GameState.in_city = false

	_build_exit_ui()
	player_marker.cell_changed.connect(_on_corridor_cell_changed)
	_update_exit_hint()

	print("Corridor arrival cell: ", player_marker.cell)


func configure_return(departure_cell: Vector2i) -> void:
	# Called by the existing entrance interaction after this scene loads.
	_entrance_return_cell = departure_cell
	_incoming_squad = GameState.get_main_squad()
	_has_return_context = true

	if player_marker.squad != _incoming_squad:
		push_error("Corridor did not receive the existing Main Squad.")

	_update_exit_hint()


func _build_exit_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)

	_exit_hint = Label.new()
	_exit_hint.position = Vector2(24.0, 970.0)
	_exit_hint.add_theme_font_size_override("font_size", 24)
	_exit_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_exit_hint)

	_exit_overlay = ColorRect.new()
	_exit_overlay.color = Color(0.02, 0.03, 0.04, 0.82)
	_exit_overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_exit_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(_exit_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_exit_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560.0, 260.0)
	center.add_child(panel)

	var margin := MarginContainer.new()

	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)

	panel.add_child(margin)

	_exit_menu_text = Label.new()
	_exit_menu_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exit_menu_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_exit_menu_text.add_theme_font_size_override("font_size", 24)
	margin.add_child(_exit_menu_text)

	_exit_overlay.hide()


func _process(delta: float) -> void:
	# Retains the calibration handle-release behavior.
	super._process(delta)

	if _exit_hint == null:
		return

	_exit_hint.visible = (
		not _calibrating
		and not _exit_menu_open
		and not _transitioning
	)


func _on_corridor_cell_changed(
	_previous_cell: Vector2i,
	_new_cell: Vector2i
) -> void:
	_update_exit_hint()


func _update_exit_hint() -> void:
	if _exit_hint == null:
		return

	if entrance_cells.has(player_marker.cell):
		_exit_hint.text = (
            "Terug naar de entrance"
			+ "  —  Enter / Spatie: opties"
		)
	else:
		_exit_hint.text = ""


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

	# F2 and mouse calibration stay with the inherited script.
	if _calibrating:
		return

	if not _is_confirm_key(key_event.keycode):
		return

	if not entrance_cells.has(player_marker.cell):
		return

	_open_exit_menu()
	get_viewport().set_input_as_handled()


func _is_confirm_key(keycode: int) -> bool:
	return keycode in [
		KEY_ENTER,
		KEY_KP_ENTER,
		KEY_SPACE
	]


func _open_exit_menu() -> void:
	_exit_menu_open = true
	_exit_selection = 0

	player_marker.set_input_enabled(false)
	_exit_hint.hide()
	_exit_overlay.show()
	_refresh_exit_menu()


func _refresh_exit_menu() -> void:
	var travel_prefix: String = (
		"> " if _exit_selection == 0 else "  "
	)
	var cancel_prefix: String = (
		"> " if _exit_selection == 1 else "  "
	)

	_exit_menu_text.text = (
        "INGANG\n\n"
		+ travel_prefix
		+ "Terug naar de entrance"
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

	# Replace scenes after input dispatch has finished.
	call_deferred("_return_to_entrance")


func _close_exit_menu() -> void:
	_exit_menu_open = false
	_exit_overlay.hide()

	player_marker.set_input_enabled(true)
	_update_exit_hint()


func _return_to_entrance() -> void:
	if (
		not _has_return_context
		or SceneManager.get_current_game_scene() != self
	):
		_recover_from_return_error(
            "Start met F5 en betreed de corridor vanuit de entrance."
		)
		return

	var next_entrance: Node = SceneManager.change_game_scene(
		ENTRANCE_SCENE_PATH
	)

	if next_entrance == null:
		_recover_from_return_error(
            "Entrance laden mislukt. Controleer Output."
		)
		return

	var marker: TacticalPlayer = (
		next_entrance.get_node("PlayerMarker") as TacticalPlayer
	)

	if marker.squad != _incoming_squad:
		push_error("Corridor return unexpectedly replaced the Main Squad.")

	if not marker.move_to(_entrance_return_cell):
		push_error(
            "Could not return to entrance cell: %s"
			% str(_entrance_return_cell)
		)

	print(
		"Returned to entrance cell ",
		marker.cell,
		" with the same Main Squad: ",
		marker.squad == _incoming_squad
	)


func _recover_from_return_error(message: String) -> void:
	_transitioning = false
	player_marker.set_input_enabled(true)
	_exit_hint.text = message
	push_warning(message)


func _on_movement_requested(direction: Vector2i) -> void:
	# Overrides only the movement guard and location-specific logging.
	if _calibrating or _exit_menu_open or _transitioning:
		return

	if player_marker.move_by(direction):
		print("Corridor Main Squad cell: ", player_marker.cell)

	get_viewport().set_input_as_handled()


func _save_calibration() -> void:
	# Same Resource-saving behavior as the entrance,
	# but always exports under a corridor-specific filename.
	if not _candidate_valid:
		return

	var directory: String = "res://assets/calibration"

	var directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directory)
	)

	if directory_error != OK:
		_status.text = (
            "Kalibratiemap aanmaken mislukt: "
			+ error_string(directory_error)
		)
		return

	var stamp: String = (
		Time.get_datetime_string_from_system().replace(":", "-")
	)

	var base_path: String = directory + "/sewer_corridor_" + stamp
	var path: String = base_path + ".tres"
	var suffix: int = 1

	# Never overwrite a previous calibration.
	while FileAccess.file_exists(path):
		path = base_path + "_" + str(suffix) + ".tres"
		suffix += 1

	var saved := GridProjectionData.new()
	saved.origin = projection.origin
	saved.axis_x = projection.axis_x
	saved.axis_y = projection.axis_y

	var save_error: Error = ResourceSaver.save(saved, path)

	if save_error != OK:
		_status.text = "Opslaan mislukt: " + error_string(save_error)
		return

	print("Corridor grid calibration saved: ", path)
	print(
        "Assign this Resource to SewerCorridorTest > Grid Calibration "
		+ "and save the scene."
	)

	_finish_calibration()

	_hint.text = (
		"Opgeslagen: " + path
		+ "\nNa F8: wijs dit bestand toe aan "
		+ "SewerCorridorTest > Grid Calibration en sla de scene op."
	)
