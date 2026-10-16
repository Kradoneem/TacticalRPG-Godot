class_name TacticalGridProjection
extends Resource

## Coordinates are local to the map root, in source-image pixels.
## origin is the corner of cell (0, 0), not its center.
## Each axis describes one logical cell step on the rendered floor.

@export var origin: Vector2 = Vector2.ZERO
@export var axis_x: Vector2 = Vector2(42.0, 0.0)
@export var axis_y: Vector2 = Vector2(0.0, 42.0)


func grid_to_map(grid_position: Vector2) -> Vector2:
	return origin + axis_x * grid_position.x + axis_y * grid_position.y


func get_cell_center(cell: Vector2i) -> Vector2:
	return grid_to_map(Vector2(cell) + Vector2(0.5, 0.5))


func get_cell_outline(cell: Vector2i) -> PackedVector2Array:
	var corner: Vector2 = Vector2(cell)

	return PackedVector2Array([
		grid_to_map(corner),
		grid_to_map(corner + Vector2.RIGHT),
		grid_to_map(corner + Vector2.ONE),
		grid_to_map(corner + Vector2.DOWN),
		grid_to_map(corner)
	])
