class_name TacticalPlayer

extends Node2D

## Tactical representation of the Main Squad.
## One tactical token represents one entire Squad, not an individual Unit.

signal cell_changed(previous_cell: Vector2i, new_cell: Vector2i)
@warning_ignore("unused_signal")
signal movement_requested(direction: Vector2i)

var squad: Squad
var cell: Vector2i

var _grid: TacticalGrid
var _grid_origin: Vector2
var _cell_size: float
var _input_enabled: bool = true


func configure(
	grid: TacticalGrid,
	grid_origin: Vector2,
	cell_size: float,
	start_cell: Vector2i,
	assigned_squad: Squad
) -> void:
	_grid = grid
	_grid_origin = grid_origin
	_cell_size = cell_size
	cell = start_cell
	squad = assigned_squad

	position = get_cell_center(cell)
	queue_redraw()


func set_input_enabled(is_enabled: bool) -> void:
	_input_enabled = is_enabled


func refresh_visual() -> void:
	queue_redraw()


func get_leader() -> Unit:
	if squad == null:
		return null

	return squad.get_leader()


func is_cell_walkable(target_cell: Vector2i) -> bool:
	return _grid != null and _grid.is_walkable(target_cell)


func get_walkable_neighbor_cells(
	from_cell: Vector2i
) -> Array[Vector2i]:
	var walkable_neighbors: Array[Vector2i] = []

	for direction: Vector2i in [
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i.LEFT,
		Vector2i.RIGHT
	]:
		var target_cell: Vector2i = from_cell + direction

		if is_cell_walkable(target_cell):
			walkable_neighbors.append(target_cell)

	return walkable_neighbors

func _unhandled_input(event: InputEvent) -> void:
	if not _input_enabled:
		return

	if event.is_action_pressed("move_up"):
		movement_requested.emit(Vector2i.UP)
	elif event.is_action_pressed("move_down"):
		movement_requested.emit(Vector2i.DOWN)
	elif event.is_action_pressed("move_left"):
		movement_requested.emit(Vector2i.LEFT)
	elif event.is_action_pressed("move_right"):
		movement_requested.emit(Vector2i.RIGHT)


func move_by(direction: Vector2i) -> bool:
	return move_to(cell + direction)


func move_to(target_cell: Vector2i) -> bool:
	if not is_cell_walkable(target_cell):
		return false

	var previous_cell: Vector2i = cell
	cell = target_cell
	position = get_cell_center(cell)

	cell_changed.emit(previous_cell, cell)

	return true


func get_cell_center(target_cell: Vector2i) -> Vector2:
	var cell_offset: Vector2 = Vector2(target_cell.x, target_cell.y) * _cell_size

	return _grid_origin + cell_offset + Vector2.ONE * (_cell_size * 0.5)


func _draw() -> void:
	draw_squad_label()
	draw_health_bar()

	draw_circle(Vector2.ZERO, 38.0, Color("#d8c06b"))
	draw_circle(Vector2.ZERO, 27.0, Color("#f4e39a"))
	draw_circle(Vector2.ZERO, 38.0, Color("#fff1b0"), false, 4.0)


func draw_squad_label() -> void:
	if squad == null:
		return

	var font: Font = ThemeDB.fallback_font

	draw_string(
		font,
		Vector2(-60.0, -80.0),
		squad.display_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		120.0,
		16,
		Color("#fff4cb")
	)


func draw_health_bar() -> void:
	var bar_rect := Rect2(-40.0, -62.0, 80.0, 10.0)
	draw_rect(bar_rect, Color("#1a1717"))

	if squad == null:
		return

	var hp_ratio: float = squad.get_health_ratio()

	draw_rect(
		Rect2(-38.0, -60.0, 76.0 * hp_ratio, 6.0),
		Color("#79c66b")
	)
