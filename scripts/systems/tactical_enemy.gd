class_name TacticalEnemy

extends Node2D

## Tactical representation of an Enemy Squad.
## Detection remains grid-based, making encounters predictable.

signal player_detected(enemy_cell: Vector2i)
signal player_lost

enum AiMode {
	STATIC,
	PATROL
}

var squad: Squad
var cell: Vector2i
var detection_range: int

var _grid_origin: Vector2
var _cell_size: float
var _is_alert: bool = false
var _is_defeated: bool = false

var ai_mode: AiMode = AiMode.STATIC

var _tactical_grid: TacticalGrid
var _patrol_route: Array[Vector2i] = []
var _patrol_index: int = 0

func configure(
	assigned_grid: TacticalGrid,
	grid_origin: Vector2,
	cell_size: float,
	start_cell: Vector2i,
	range_in_cells: int,
	assigned_squad: Squad
) -> void:
	_tactical_grid = assigned_grid
	_grid_origin = grid_origin
	_cell_size = cell_size
	cell = start_cell
	detection_range = range_in_cells
	squad = assigned_squad

	position = get_cell_center(cell)
	queue_redraw()

func configure_patrol(route: Array[Vector2i]) -> void:
	if route.size() < 2:
		push_warning(
			"A PATROL enemy requires at least two waypoint cells."
		)
		return

	for waypoint: Vector2i in route:
		if _tactical_grid == null or not _tactical_grid.is_walkable(waypoint):
			push_warning(
				"PATROL route contains a blocked or invalid cell: %s."
				% waypoint
			)
			return

	_patrol_route = route
	_patrol_index = 0
	ai_mode = AiMode.PATROL

	if cell != _patrol_route[0]:
		cell = _patrol_route[0]
		position = get_cell_center(cell)

	queue_redraw()

func get_next_patrol_cell() -> Vector2i:
	if ai_mode != AiMode.PATROL or _patrol_route.is_empty():
		return cell

	var next_index := (_patrol_index + 1) % _patrol_route.size()
	return _patrol_route[next_index]

func advance_patrol() -> bool:
	if ai_mode != AiMode.PATROL or _patrol_route.is_empty():
		return false

	var next_cell := get_next_patrol_cell()

	if _tactical_grid == null or not _tactical_grid.is_walkable(next_cell):
		return false

	_patrol_index = (_patrol_index + 1) % _patrol_route.size()
	cell = next_cell
	position = get_cell_center(cell)

	queue_redraw()
	return true


func check_detection(player_cell: Vector2i) -> void:
	if _is_defeated:
		return

	var manhattan_distance: int = (
		absi(player_cell.x - cell.x)
		+ absi(player_cell.y - cell.y)
	)

	var player_is_detected: bool = manhattan_distance <= detection_range

	if player_is_detected and not _is_alert:
		_is_alert = true
		queue_redraw()
		player_detected.emit(cell)

	elif not player_is_detected and _is_alert:
		_is_alert = false
		queue_redraw()
		player_lost.emit()


func set_defeated() -> void:
	_is_defeated = true
	_is_alert = false
	queue_redraw()


func refresh_visual() -> void:
	queue_redraw()

func is_defeated() -> bool:
	return _is_defeated


func set_alert(is_alert: bool) -> void:
	if _is_defeated:
		return

	_is_alert = is_alert
	queue_redraw()


func get_manhattan_distance_to(target_cell: Vector2i) -> int:
	return (
		absi(target_cell.x - cell.x)
		+ absi(target_cell.y - cell.y)
	)

func get_leader() -> Unit:
	if squad == null:
		return null

	return squad.get_leader()


func get_cell_center(target_cell: Vector2i) -> Vector2:
	var cell_offset: Vector2 = Vector2(target_cell.x, target_cell.y) * _cell_size
	return _grid_origin + cell_offset + Vector2.ONE * (_cell_size * 0.5)


func _draw() -> void:
	draw_squad_label()
	draw_health_bar()

	var body_color: Color = Color("#b54a45")
	var inner_color: Color = Color("#e07b55")

	if _is_alert:
		body_color = Color("#e43d32")
		inner_color = Color("#ffce68")

	if _is_defeated:
		body_color = Color("#4b4b4b")
		inner_color = Color("#777777")

	draw_circle(Vector2.ZERO, 38.0, body_color)
	draw_circle(Vector2.ZERO, 27.0, inner_color)
	draw_circle(Vector2.ZERO, 38.0, Color("#d0d0d0"), false, 4.0)

	if _is_alert:
		draw_circle(
			Vector2.ZERO,
			52.0,
			Color("#ffda70", 0.35),
			false,
			4.0
		)


func draw_squad_label() -> void:
	if squad == null:
		return

	var font: Font = ThemeDB.fallback_font

	draw_string(
		font,
		Vector2(-70.0, -80.0),
		squad.display_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		140.0,
		16,
		Color("#ffd2cb")
	)


func draw_health_bar() -> void:
	var bar_rect := Rect2(-40.0, -62.0, 80.0, 10.0)
	draw_rect(bar_rect, Color("#1a1717"))

	if squad == null:
		return

	var hp_ratio: float = squad.get_health_ratio()

	draw_rect(
		Rect2(-38.0, -60.0, 76.0 * hp_ratio, 6.0),
		Color("#d96a5e")
	)
