extends "res://scripts/exploration/sewer_corridor_test.gd"

## Corridor content only. Shared map code owns gameplay composition.

const SewerEnemyContent = preload(
	"res://scripts/content/sewer_enemy_content.gd"
)

@export var maintenance_cells: Array[Vector2i] = [
	Vector2i(11, 0)
]

@export var rat_start_cell: Vector2i = Vector2i(11, 3)


func get_location_name() -> String:
	return "Sewer Corridor"


func get_calibration_prefix() -> String:
	return "sewer_corridor"


func get_exit_definitions() -> Array[ExplorationExitData]:
	return [
		ExplorationExitData.create(
			&"to_entrance",
			"Terug naar de entrance",
			entrance_cells,
			"res://scenes/exploration/sewer_entrance_test.tscn",
			Vector2i(6, 0)
		),
		ExplorationExitData.create(
			&"to_maintenance",
			"Naar de maintenance room",
			maintenance_cells,
			"res://scenes/exploration/sewer_maintenance_test.tscn",
			Vector2i(0, 1)
		)
	]


func get_enemy_spawns() -> Array[TacticalEnemySpawn]:
	return [
		TacticalEnemySpawn.new(
			&"corridor_sewer_rats",
			rat_start_cell,
			SewerEnemyContent.create_corridor_rat_squad
		)
	]
