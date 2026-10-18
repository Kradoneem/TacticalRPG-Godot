extends "res://scripts/exploration/exploration_map.gd"

## Corridor connection zone.
## Kept as a thin compatibility base for the existing scene script.

@export var entrance_cells: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(0, 1),
	Vector2i(0, 2)
]
