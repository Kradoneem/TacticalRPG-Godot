extends "res://scripts/exploration/exploration_map.gd"

## Junction floor authoring and camera integration.
## Grid calibration and walkable floor are separate responsibilities.

@onready var _background: Sprite2D = $Background
@onready var _map_camera: Camera2D = $MapCamera


func get_location_name() -> String:
	return "Sewer Junction"


func get_calibration_prefix() -> String:
	return "sewer_junction"


func _configure_tactical_grid() -> void:
	var floor_regions: WalkableFloorRegions = (
		get_node_or_null("WalkableFloor") as WalkableFloorRegions
	)

	if floor_regions == null:
		push_error("Junction requires a WalkableFloor node.")

		for row in range(grid_size.y):
			for column in range(grid_size.x):
				tactical_grid.set_blocked(Vector2i(column, row))

		return

	floor_regions.apply_to_grid(tactical_grid, projection, self)


func _ready() -> void:
	super._ready()

	if (
		tactical_grid == null
		or projection == null
		or player_marker.squad == null
	):
		return

	if _background.texture == null:
		push_error("Junction requires a background texture.")
		return

	var bounds := Rect2(
		_background.position,
		_background.texture.get_size()
	)

	_map_camera.call(
		"configure",
		bounds,
		player_marker,
		_is_junction_calibrating
	)

	_set_camera_hint()
	queue_redraw()


func _is_junction_calibrating() -> bool:
	return _calibrating


func _set_camera_hint() -> void:
	if _hint == null:
		return

	_hint.text = (
		"JUNCTION | WASD: bewegen; camera hervat volgen"
		+ "\nMiddelste muisknop: inspecteren | Home: centreren"
		+ "\nGroen: walkable | rood: blocked | F2: kalibratie"
	)


func _begin_calibration() -> void:
	super._begin_calibration()

	if _calibrating:
		_hint.text = (
			"KALIBRATIE | camera volgt tijdelijk niet"
			+ "\nMiddelste muisknop: kaart slepen"
			+ "\nLinkermuisknop: O, X en Y | Escape: annuleren"
		)


func _finish_calibration() -> void:
	super._finish_calibration()

	# Rebuild floor classification if the projection changed.
	_configure_tactical_grid()

	if not tactical_grid.is_walkable(player_marker.cell):
		push_warning(
			"Current token cell is blocked after recalibration. "
			+ "Stop the test and adjust the start cell or floor polygons."
		)

	_set_camera_hint()
	queue_redraw()


func _draw() -> void:
	# Keep existing calibration handles.
	super._draw()

	if (
		tactical_grid == null
		or projection == null
		or not show_debug_grid
		or _calibrating
	):
		return

	for row in range(grid_size.y):
		for column in range(grid_size.x):
			var cell := Vector2i(column, row)
			var walkable: bool = tactical_grid.is_walkable(cell)

			var fill_color: Color = (
				Color(0.15, 0.85, 0.35, 0.18)
				if walkable
				else Color(0.95, 0.15, 0.15, 0.24)
			)

			var outline_color: Color = (
				Color(0.2, 1.0, 0.4, 0.8)
				if walkable
				else Color(1.0, 0.2, 0.2, 0.8)
			)

			var outline: PackedVector2Array = (
				projection.get_cell_outline(cell)
			)
			var corners := PackedVector2Array([
				outline[0],
				outline[1],
				outline[2],
				outline[3]
			])

			draw_colored_polygon(corners, fill_color)
			draw_polyline(outline, outline_color, 2.0, true)
