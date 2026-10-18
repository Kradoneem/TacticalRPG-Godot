extends Node2D

## Small calibration scene, not a replacement for tacticaltest.
## All calibration points are local to this map root.

const GridProjectionData = preload(
    "res://scripts/systems/tactical_grid_projection.gd"
)

@export var grid_size: Vector2i = Vector2i(5, 4)
@export var start_cell: Vector2i = Vector2i(1, 1)
@export var grid_origin: Vector2 = Vector2(840.0, 355.0)
@export var grid_axis_x: Vector2 = Vector2(100.0, 57.0)
@export var grid_axis_y: Vector2 = Vector2(-64.0, 65.0)
@export var show_debug_grid: bool = true

## When assigned, this Resource takes precedence over the legacy vectors.
@export var grid_calibration: GridProjectionData

@onready var player_marker: TacticalPlayer = $PlayerMarker

var tactical_grid: TacticalGrid
var projection: GridProjectionData

var _calibrating: bool = false
var _points: Array[Vector2] = []
var _drag_index: int = -1
var _before_origin: Vector2
var _before_x: Vector2
var _before_y: Vector2
var _candidate_valid: bool = false

var _panel: PanelContainer
var _status: Label
var _x_steps: SpinBox
var _y_steps: SpinBox
var _save_button: Button
var _hint: Label


func _ready() -> void:
	player_marker.set_input_enabled(false)

	if grid_size.x <= 0 or grid_size.y <= 0:
		push_error("Entrance test requires a positive grid size.")
		return

	projection = GridProjectionData.new()

	if grid_calibration != null:
		projection.origin = grid_calibration.origin
		projection.axis_x = grid_calibration.axis_x
		projection.axis_y = grid_calibration.axis_y
	else:
		projection.origin = grid_origin
		projection.axis_x = grid_axis_x
		projection.axis_y = grid_axis_y

	if not _axes_are_valid(projection.axis_x, projection.axis_y):
		push_error("Entrance grid axes must not be parallel or zero.")
		return

	tactical_grid = TacticalGrid.new(grid_size)

	if not tactical_grid.is_walkable(start_cell):
		push_error("Entrance start cell is outside the walkable test zone.")
		return

	# F6 skips main.gd. Never reset an existing game or copy its units.
	if GameState.get_main_squad() == null:
		GameState.start_new_game()

	var main_squad: Squad = GameState.get_main_squad()

	if main_squad == null:
		push_error("Entrance test could not find a Main Squad.")
		return

	player_marker.configure(
		tactical_grid,
		Vector2.ZERO,
		42.0,
		start_cell,
		main_squad,
		projection
	)

	player_marker.movement_requested.connect(_on_movement_requested)

	_build_calibration_ui()
	player_marker.set_input_enabled(true)
	queue_redraw()


func _axes_are_valid(axis_x: Vector2, axis_y: Vector2) -> bool:
	if axis_x.length() < 1.0 or axis_y.length() < 1.0:
		return false

	# Reject almost parallel directions, independent of their lengths.
	return absf(
		axis_x.normalized().cross(axis_y.normalized())
	) > 0.05


func _build_calibration_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_hint = Label.new()
	_hint.position = Vector2(16.0, 16.0)
	_hint.text = "F2: grid kalibreren | WASD: squad bewegen"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hint)

	_panel = PanelContainer.new()
	_panel.position = Vector2(16.0, 48.0)
	_panel.custom_minimum_size = Vector2(440.0, 0.0)
	layer.add_child(_panel)

	var margin := MarginContainer.new()

	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)

	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Gridkalibratie — drie vloerpunten"
	column.add_child(title)

	_status = Label.new()
	_status.custom_minimum_size.x = 416.0
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)

	var x_label := Label.new()
	x_label.text = "Tegelstappen van O naar X (rechtsbeneden):"
	column.add_child(x_label)

	_x_steps = SpinBox.new()
	_x_steps.min_value = 1.0
	_x_steps.max_value = 256.0
	_x_steps.step = 1.0
	_x_steps.value = grid_size.x
	column.add_child(_x_steps)

	var y_label := Label.new()
	y_label.text = "Tegelstappen van O naar Y (linksbeneden):"
	column.add_child(y_label)

	_y_steps = SpinBox.new()
	_y_steps.min_value = 1.0
	_y_steps.max_value = 256.0
	_y_steps.step = 1.0
	_y_steps.value = grid_size.y
	column.add_child(_y_steps)

	_x_steps.value_changed.connect(_on_steps_changed)
	_y_steps.value_changed.connect(_on_steps_changed)

	var restart_button := Button.new()
	restart_button.text = "Punten opnieuw kiezen"
	restart_button.pressed.connect(_restart_points)
	column.add_child(restart_button)

	_save_button = Button.new()
	_save_button.text = "Bewaar als nieuwe kalibratie-Resource"
	_save_button.pressed.connect(_save_calibration)
	column.add_child(_save_button)

	var cancel_button := Button.new()
	cancel_button.text = "Annuleren / vorige kalibratie herstellen"
	cancel_button.pressed.connect(_cancel_calibration)
	column.add_child(cancel_button)

	_panel.hide()


func _unhandled_input(event: InputEvent) -> void:
	if projection == null or _panel == null:
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey

		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_F2:
				if not _calibrating:
					_begin_calibration()

				get_viewport().set_input_as_handled()
				return

			if _calibrating and key_event.keycode == KEY_ESCAPE:
				_cancel_calibration()
				get_viewport().set_input_as_handled()
				return

	if not _calibrating:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				var point: Vector2 = get_local_mouse_position()

				if _points.size() < 3:
					_points.append(point)
					_update_candidate()
				else:
					_drag_index = _find_handle(point)
			else:
				_drag_index = -1

			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _drag_index >= 0:
		_points[_drag_index] = get_local_mouse_position()
		_update_candidate()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# A release over the UI can be consumed by Control nodes.
	if _drag_index >= 0:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_drag_index = -1


func _begin_calibration() -> void:
	_before_origin = projection.origin
	_before_x = projection.axis_x
	_before_y = projection.axis_y

	_calibrating = true
	player_marker.set_input_enabled(false)
	_panel.show()
	_restart_points()


func _restart_points() -> void:
	_points.clear()
	_drag_index = -1
	_candidate_valid = false

	_restore_previous_projection()
	_save_button.disabled = true

	_status.text = (
        "1/3: klik het achterste vloerhoekpunt O. "
		+ "Dit is de hoek van cel (0, 0), niet het midden."
	)

	queue_redraw()


func _find_handle(point: Vector2) -> int:
	var closest: int = -1
	var best_distance: float = 18.0

	for index in range(_points.size()):
		var distance: float = point.distance_to(_points[index])

		if distance < best_distance:
			closest = index
			best_distance = distance

	return closest


func _on_steps_changed(_value: float) -> void:
	if _calibrating:
		_update_candidate()


func _update_candidate() -> void:
	_candidate_valid = false
	_save_button.disabled = true

	if _points.size() == 1:
		_status.text = (
            "2/3: klik een voegkruising vanaf O naar rechtsbeneden (X). "
			+ "Tel de tegelstappen ertussen."
		)

	elif _points.size() == 2:
		_status.text = (
            "3/3: klik een voegkruising vanaf O naar linksbeneden (Y). "
			+ "Tel ook hier de tegelstappen."
		)

	elif _points.size() == 3:
		var axis_x: Vector2 = (
			(_points[1] - _points[0]) / _x_steps.value
		)

		var axis_y: Vector2 = (
			(_points[2] - _points[0]) / _y_steps.value
		)

		if not _axes_are_valid(axis_x, axis_y):
			_status.text = (
                "Ongeldige punten: kies twee verschillende vloerrichtingen. "
				+ "Sleep de gekleurde punten of kies opnieuw."
			)
			queue_redraw()
			return

		projection.origin = _points[0]
		projection.axis_x = axis_x
		projection.axis_y = axis_y

		_candidate_valid = true
		_save_button.disabled = false

		_status.text = (
            "Preview actief. Sleep O, X of Y om bij te stellen. "
			+ "Controleer de tegelstappen: tel afstanden, niet kruispunten."
		)

		_refresh_projection_visuals()

	queue_redraw()


func _refresh_projection_visuals() -> void:
	# Reposition visually without changing gameplay state or emitting movement.
	player_marker.position = projection.get_cell_center(player_marker.cell)
	player_marker.refresh_visual()
	queue_redraw()


func _restore_previous_projection() -> void:
	projection.origin = _before_origin
	projection.axis_x = _before_x
	projection.axis_y = _before_y
	_refresh_projection_visuals()


func _cancel_calibration() -> void:
	if not _calibrating:
		return

	_restore_previous_projection()
	_finish_calibration()
	_hint.text = "Kalibratie geannuleerd. F2: opnieuw | WASD: bewegen"


func _finish_calibration() -> void:
	_calibrating = false
	_drag_index = -1
	_points.clear()
	_panel.hide()
	player_marker.set_input_enabled(true)
	queue_redraw()


func _save_calibration() -> void:
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

	# Always use a new filename. Never overwrite an existing calibration.
	var stamp: String = (
		Time.get_datetime_string_from_system().replace(":", "-")
	)

	var base_path: String = directory + "/sewer_entrance_" + stamp
	var path: String = base_path + ".tres"
	var suffix: int = 1

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

	print("Grid calibration saved: ", path)
	print(
        "Assign this Resource to SewerEntranceTest > Grid Calibration "
		+ "and save the scene."
	)

	_finish_calibration()

	_hint.text = (
		"Opgeslagen: " + path
		+ "\nNa F8: sleep dit bestand naar Grid Calibration "
		+ "en sla de scene op."
	)


func _on_movement_requested(direction: Vector2i) -> void:
	if _calibrating:
		return

	if player_marker.move_by(direction):
		print("Entrance Main Squad cell: ", player_marker.cell)

	get_viewport().set_input_as_handled()


func _draw() -> void:
	if projection == null or tactical_grid == null:
		return

	if show_debug_grid or _calibrating:
		for row in range(grid_size.y):
			for column in range(grid_size.x):
				var cell := Vector2i(column, row)

				draw_polyline(
					projection.get_cell_outline(cell),
					Color(0.2, 1.0, 0.8, 0.65),
					2.0,
					true
				)

				draw_circle(
					projection.get_cell_center(cell),
					3.0,
					Color(0.2, 1.0, 0.8, 0.9)
				)

	if not _calibrating:
		return

	var colors: Array[Color] = [
		Color("#ffffff"),
		Color("#ffad66"),
		Color("#83baff")
	]

	var names: Array[String] = ["O", "X", "Y"]

	for index in range(_points.size()):
		var point: Vector2 = _points[index]

		if index > 0:
			draw_line(
				_points[0],
				point,
				colors[index],
				3.0,
				true
			)

		draw_circle(point, 9.0, colors[index])
		draw_circle(point, 12.0, Color.BLACK, false, 2.0, true)

		draw_string(
			ThemeDB.fallback_font,
			point + Vector2(14.0, -12.0),
			names[index],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			22,
			colors[index]
		)

func prepare_exploration_entry(
	context: ExplorationEntryContext
) -> bool:
	if context == null or context.main_squad == null:
		push_error("Exploration entry requires an existing Main Squad.")
		return false

	var arrival: Vector2i = context.arrival_cell

	if (
		arrival.x < 0
		or arrival.y < 0
		or arrival.x >= grid_size.x
		or arrival.y >= grid_size.y
	):
		push_error("Arrival cell is outside the destination grid: " + str(arrival))
		return false

	if is_node_ready():
		if player_marker.squad != context.main_squad:
			push_error("Retained map has a different Main Squad.")
			return false

		# Existing maps return through their remembered departure cell.
		# Reject unexpected repositioning rather than corrupting tactical turns.
		if player_marker.cell != arrival:
			push_error("Retained map arrival differs from its departure cell.")
			return false
	else:
		# Configure logical arrival BEFORE _ready builds tokens and runtime.
		start_cell = arrival

	return true


func on_exploration_entered(
	_context: ExplorationEntryContext
) -> void:
	GameState.current_location = "Sewer Entrance"
	GameState.in_city = false

	var exit_adapter: Node = get_node_or_null("ExitInteractions")

	if exit_adapter != null and exit_adapter.has_method("resume_exploration"):
		exit_adapter.call("resume_exploration")
