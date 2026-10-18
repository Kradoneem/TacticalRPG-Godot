class_name ExplorationExitData
extends Resource

## Map content only.
## Departure cells belong to the source map.
## Arrival and return handling belong to the transition layer.

@export var exit_id: StringName = &""
@export var display_name: String = ""
@export var cells: Array[Vector2i] = []
@export_file("*.tscn") var destination_scene: String = ""


static func create(
	assigned_id: StringName,
	assigned_display_name: String,
	assigned_cells: Array[Vector2i],
	assigned_destination_scene: String
) -> ExplorationExitData:
	var exit := ExplorationExitData.new()
	exit.exit_id = assigned_id
	exit.display_name = assigned_display_name
	exit.cells.assign(assigned_cells)
	exit.destination_scene = assigned_destination_scene
	return exit


func contains_cell(target_cell: Vector2i) -> bool:
	return cells.has(target_cell)


func is_valid() -> bool:
	return (
		exit_id != &""
		and not display_name.is_empty()
		and not cells.is_empty()
		and not destination_scene.is_empty()
	)
