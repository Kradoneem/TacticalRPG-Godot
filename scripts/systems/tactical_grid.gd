class_name TacticalGrid

extends RefCounted

## Stores the logical rules of a tactical map.
## It has no visual responsibilities: backgrounds and map art remain separate.

var size: Vector2i
var blocked_cells: Dictionary = {}


func _init(grid_size: Vector2i) -> void:
	size = grid_size


func is_inside_grid(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < size.x
		and cell.y < size.y
	)


func set_blocked(cell: Vector2i, is_blocked: bool = true) -> void:
	if not is_inside_grid(cell):
		push_warning("Tried to configure a cell outside the tactical grid.")
		return

	if is_blocked:
		blocked_cells[cell] = true
	else:
		blocked_cells.erase(cell)


func is_walkable(cell: Vector2i) -> bool:
	return is_inside_grid(cell) and not blocked_cells.has(cell)
