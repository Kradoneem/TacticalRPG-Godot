extends "res://scripts/exploration/exploration_map.gd"

## Regular exploration map, no longer a temporary presentation.

@export var return_cells: Array[Vector2i] = [
	Vector2i(0, 1)
]


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
		)
	]
