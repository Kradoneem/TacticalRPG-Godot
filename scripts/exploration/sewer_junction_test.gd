extends "res://scripts/exploration/exploration_map.gd"

## Junction content. Logical cell labels define movement rules.
## Projection only determines where cells are displayed.
## Initial labels are authoring placeholders, NOT a validated floor layout.

## Each string is one y-row; character index is x.
## . = FLOOR, # = BLOCKED, ? = UNKNOWN (also blocked).
## Only the existing start cell (2, 2) is provisionally enabled.
@export var cell_rows: PackedStringArray = PackedStringArray([
	"?????????????????", # y = 0
	"?????????????????", # y = 1
	"??.??????????????", # y = 2
	"?????????????????", # y = 3
	"?????????????????", # y = 4
	"?????????????????", # y = 5
	"?????????????????", # y = 6
	"?????????????????", # y = 7
	"?????????????????"  # y = 8
])

@export var show_cell_coordinates: bool = true

@onready var _background: Sprite2D = $Background
@onready var _map_camera: Camera2D = $MapCamera


func get_location_name() -> String:
	return "Sewer Junction"


func get_calibration_prefix() -> String:
	return "sewer_junction"


func _configure_tactical_grid() -> void:
	# Fail closed: invalid or unknown content never becomes walkable.
	for row in range(grid_size.y):
		for column in range(grid_size.x):
			tactical_grid.set_blocked(Vector2i(column, row))

	if not _cell_rows_are_valid():
		return

	var floor_count: int = 0

	for row in range(grid_size.y):
		for column in range(grid_size.x):
			var cell := Vector2i(column, row)
			var walkable: bool = get_cell_label(cell) == &"FLOOR"
			tactical_grid.set_blocked(cell, not walkable)

			if walkable:
				floor_count += 1

	print("[Junction] FLOOR cells: ", floor_count, " / ", grid_size.x * grid_size.y)


func _cell_rows_are_valid() -> bool:
	if cell_rows.size() != grid_size.y:
		push_error("Junction requires exactly %d cell rows." % grid_size.y)
		return false

	for row in range(cell_rows.size()):
		if cell_rows[row].length() != grid_size.x:
			push_error(
				"Junction row %d requires %d characters; found %d."
				% [row, grid_size.x, cell_rows[row].length()]
			)
			return false

		for column in range(grid_size.x):
			var symbol: String = cell_rows[row].substr(column, 1)

			if symbol not in [".", "#", "?"]:
				push_error(
					"Unknown junction symbol '%s' at (%d, %d)."
					% [symbol, column, row]
				)
				return false

	return true


func get_cell_label(cell: Vector2i) -> StringName:
	if (
		cell.x < 0
		or cell.y < 0
		or cell.y >= cell_rows.size()
	):
		return &"UNKNOWN"

	if cell.x >= cell_rows[cell.y].length():
		return &"UNKNOWN"

	match cell_rows[cell.y].substr(cell.x, 1):
		".":
			return &"FLOOR"
		"#":
			return &"BLOCKED"
		_:
			return &"UNKNOWN"


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
		+ "\nGroen: FLOOR | rood: BLOCKED | grijs: UNKNOWN (blocked)"
		+ "\nF2: kalibratie | cellenkaart nog handmatig valideren"
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
	# Labels are logical data: recalibration must not reclassify cells.
	_set_camera_hint()
	queue_redraw()


func _draw() -> void:
	if _calibrating:
		super._draw()
		return

	if (
		tactical_grid == null
		or projection == null
		or not show_debug_grid
	):
		return

	for row in range(grid_size.y):
		for column in range(grid_size.x):
			var cell := Vector2i(column, row)
			var label: StringName = get_cell_label(cell)
			var color := Color(0.65, 0.65, 0.65, 0.7)

			match label:
				&"FLOOR":
					color = Color(0.2, 1.0, 0.4, 0.8)
				&"BLOCKED":
					color = Color(1.0, 0.2, 0.2, 0.8)

			var outline: PackedVector2Array = projection.get_cell_outline(cell)
			var corners := PackedVector2Array([
				outline[0], outline[1], outline[2], outline[3]
			])
			var fill: Color = color
			fill.a = 0.15

			draw_colored_polygon(corners, fill)
			draw_polyline(outline, color, 2.0, true)

			if show_cell_coordinates:
				var text: String = "%d,%d" % [column, row]
				var font: Font = ThemeDB.fallback_font
				var text_size: Vector2 = font.get_string_size(
					text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16
				)
				var text_position: Vector2 = (
					projection.get_cell_center(cell)
					+ Vector2(-text_size.x * 0.5, 5.0)
				)

				draw_string_outline(
					font, text_position, text,
					HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, 3, Color.BLACK
				)
				draw_string(
					font, text_position, text,
					HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color.WHITE
				)
