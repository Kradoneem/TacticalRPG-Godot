extends "res://scripts/exploration/exploration_map.gd"

## Maintenance map content.
## Both grate cells belong to one connection to the junction.

@export var return_cells: Array[Vector2i] = [
	Vector2i(0, 1)
]

@export var junction_exit_cells: Array[Vector2i] = [
	Vector2i(3, 0),
	Vector2i(4, 0)
]

@export var junction_arrival_cell: Vector2i = Vector2i(0, 7)


func get_location_name() -> String:
	return "Sewer Maintenance"


func get_calibration_prefix() -> String:
	return "sewer_maintenance"


func get_exit_definitions() -> Array[ExplorationExitData]:
	return [
		ExplorationExitData.create(
			&"to_corridor",
			"Terug naar de corridor",
			return_cells,
			"res://scenes/exploration/sewer_corridor_test.tscn",
			Vector2i(11, 0)
		),
		ExplorationExitData.create(
			&"to_junction",
			"Via het rooster naar de junction",
			junction_exit_cells,
			"res://scenes/exploration/sewer_junction_test.tscn",
			junction_arrival_cell
		)
	]
