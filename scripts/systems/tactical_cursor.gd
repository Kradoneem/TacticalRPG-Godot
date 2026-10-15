class_name TacticalCursor

extends Node2D

## Presentation-only keyboard cursor for alert tactical movement.
## TacticalTurnController owns validation and turn progression.

var cell: Vector2i
var _grid_origin: Vector2
var _cell_size: float
var _reachable_cells: Dictionary = {}
var _visible: bool = false


func configure(
	grid_origin: Vector2,
	cell_size: float
) -> void:
	_grid_origin = grid_origin
	_cell_size = cell_size
	hide()


func begin_selection(
	start_cell: Vector2i,
	reachable_cells: Array[Vector2i]
) -> void:
	cell = start_cell
	_reachable_cells.clear()

	for reachable_cell: Vector2i in reachable_cells:
		_reachable_cells[reachable_cell] = true

	position = get_cell_center(cell)
	_visible = true
	show()
	queue_redraw()


func end_selection() -> void:
	_visible = false
	hide()


func move_by(direction: Vector2i) -> bool:
	var target_cell: Vector2i = cell + direction

	if not _reachable_cells.has(target_cell):
		return false

	cell = target_cell
	position = get_cell_center(cell)
	queue_redraw()

	return true

func get_cell_center(target_cell: Vector2i) -> Vector2:
	var cell_offset := Vector2(target_cell.x, target_cell.y) * _cell_size

	return _grid_origin + cell_offset + Vector2.ONE * (_cell_size * 0.5)


func _draw() -> void:
	if not _visible:
		return

	var half_size := _cell_size * 0.42
	var cursor_rect := Rect2(
		Vector2(-half_size, -half_size),
		Vector2.ONE * half_size * 2.0
	)

	draw_rect(
		cursor_rect,
		Color("#ffe183", 0.18),
		true
	)

	draw_rect(
		cursor_rect,
		Color("#ffe183"),
		false,
		4.0
	)

	draw_circle(
		Vector2.ZERO,
		7.0,
		Color("#fff6bc")
	)
