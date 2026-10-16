extends "res://scripts/exploration/sewer_entrance_test.gd"

## Calibration and free movement reuse the existing entrance controller.
## This scene is temporarily presented above the retained corridor.

signal presentation_finished(context: Variant)

## Provisional: assign cells before the corridor opening.
@export var return_cells: Array[Vector2i] = [
	Vector2i(0, 1)
]

var _can_return: bool = false
var _return_menu_open: bool = false
var _return_selection: int = 0
var _returning: bool = false

var _return_hint: Label
var _return_overlay: ColorRect
var _return_menu_text: Label


func _ready() -> void:
	super._ready()

	if tactical_grid == null or projection == null:
		return

	if player_marker.squad == null:
		return

	GameState.current_location = "Sewer Maintenance"
	GameState.in_city = false

	_build_return_ui()

	player_marker.cell_changed.connect(
		_on_maintenance_cell_changed
	)

	_update_return_hint()


func configure(_context: Variant = null) -> void:
	# SceneManager calls this after adding the presentation to Main.
	_can_return = true


func _build_return_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)

	_return_hint = Label.new()
	_return_hint.position = Vector2(24.0, 970.0)
	_return_hint.add_theme_font_size_override("font_size", 24)
	_return_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_return_hint)

	_return_overlay = ColorRect.new()
	_return_overlay.color = Color(0.02, 0.03, 0.04, 0.82)
	_return_overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_return_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(_return_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_return_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560.0, 260.0)
	center.add_child(panel)

	var margin := MarginContainer.new()

	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override(
			"margin_" + side,
			24
		)

	panel.add_child(margin)

	_return_menu_text = Label.new()
	_return_menu_text.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_return_menu_text.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	_return_menu_text.add_theme_font_size_override(
		"font_size",
		24
	)
	margin.add_child(_return_menu_text)

	_return_overlay.hide()


func _process(delta: float) -> void:
	super._process(delta)

	if _return_hint != null:
		_return_hint.visible = (
			not _calibrating
			and not _return_menu_open
			and not _returning
		)


func _on_maintenance_cell_changed(
	_previous_cell: Vector2i,
	_new_cell: Vector2i
) -> void:
	_update_return_hint()


func _update_return_hint() -> void:
	if _return_hint == null:
		return

	if return_cells.has(player_marker.cell):
		_return_hint.text = (
            "Terug naar de corridor"
			+ "  —  Enter / Spatie: opties"
		)
	else:
		_return_hint.text = ""


func _input(event: InputEvent) -> void:
	if _return_hint == null or _returning:
		return

	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey

	if not key_event.pressed:
		return

	if key_event.echo:
		if _return_menu_open:
			get_viewport().set_input_as_handled()
		return

	if _return_menu_open:
		_handle_return_menu_key(key_event.keycode)
		get_viewport().set_input_as_handled()
		return

	if _calibrating:
		return

	if not _is_confirm_key(key_event.keycode):
		return

	if not return_cells.has(player_marker.cell):
		return

	_return_menu_open = true
	_return_selection = 0

	player_marker.set_input_enabled(false)
	_return_hint.hide()
	_return_overlay.show()

	_refresh_return_menu()
	get_viewport().set_input_as_handled()


func _is_confirm_key(keycode: int) -> bool:
	return keycode in [
		KEY_ENTER,
		KEY_KP_ENTER,
		KEY_SPACE
	]


func _refresh_return_menu() -> void:
	var travel_prefix: String = (
		"> " if _return_selection == 0 else "  "
	)

	var cancel_prefix: String = (
		"> " if _return_selection == 1 else "  "
	)

	_return_menu_text.text = (
        "INGANG\n\n"
		+ travel_prefix
		+ "Terug naar de corridor"
		+ "\n"
		+ cancel_prefix
		+ "Annuleren"
		+ "\n\nW/S of pijltjes: kiezen"
		+ "\nEnter / Spatie: bevestigen"
		+ "\nEscape: sluiten"
	)


func _handle_return_menu_key(keycode: int) -> void:
	if keycode == KEY_ESCAPE:
		_close_return_menu()
		return

	if keycode in [KEY_W, KEY_UP, KEY_S, KEY_DOWN]:
		_return_selection = 1 - _return_selection
		_refresh_return_menu()
		return

	if not _is_confirm_key(keycode):
		return

	if _return_selection == 1:
		_close_return_menu()
		return

	if not _can_return:
		_close_return_menu()
		_return_hint.text = (
            "Gebruik F5 en betreed maintenance vanuit de corridor."
		)
		return

	_returning = true
	_return_menu_open = false
	_return_overlay.hide()

	call_deferred("_finish_presentation")


func _close_return_menu() -> void:
	_return_menu_open = false
	_return_overlay.hide()

	player_marker.set_input_enabled(true)
	_update_return_hint()


func _finish_presentation() -> void:
	_can_return = false

	set_process_input(false)
	set_process_unhandled_input(false)
	player_marker.set_input_enabled(false)

	presentation_finished.emit(null)


func _on_movement_requested(direction: Vector2i) -> void:
	if _calibrating or _return_menu_open or _returning:
		return

	if player_marker.move_by(direction):
		print(
			"Maintenance Main Squad cell: ",
			player_marker.cell
		)

	get_viewport().set_input_as_handled()


func _save_calibration() -> void:
	if not _candidate_valid:
		return

	var directory: String = "res://assets/calibration"

	var directory_error: Error = (
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(directory)
		)
	)

	if directory_error != OK:
		_status.text = (
            "Kalibratiemap aanmaken mislukt: "
			+ error_string(directory_error)
		)
		return

	var stamp: String = (
		Time.get_datetime_string_from_system()
		.replace(":", "-")
	)

	var base_path: String = (
		directory + "/sewer_maintenance_" + stamp
	)

	var path: String = base_path + ".tres"
	var suffix: int = 1

	# Always use a new filename.
	while FileAccess.file_exists(path):
		path = base_path + "_" + str(suffix) + ".tres"
		suffix += 1

	var saved := GridProjectionData.new()
	saved.origin = projection.origin
	saved.axis_x = projection.axis_x
	saved.axis_y = projection.axis_y

	var save_error: Error = ResourceSaver.save(saved, path)

	if save_error != OK:
		_status.text = (
			"Opslaan mislukt: " + error_string(save_error)
		)
		return

	print("Maintenance grid calibration saved: ", path)

	_finish_calibration()

	_hint.text = (
		"Opgeslagen: " + path
		+ "\nNa F8: wijs dit bestand toe aan "
		+ "SewerMaintenanceTest > Grid Calibration "
		+ "en sla de scene op."
	)
