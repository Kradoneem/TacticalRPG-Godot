class_name ExplorationExitData
extends Resource

## Connection content, not mutable gameplay state.
## cells belong to this map; arrival_cell belongs to the destination.

@export var exit_id: StringName = &""
@export var display_name: String = ""
@export var cells: Array[Vector2i] = []
@export_file("*.tscn") var destination_scene: String = ""
@export var arrival_cell: Vector2i = Vector2i.ZERO


static func create(
	assigned_id: StringName,
	assigned_display_name: String,
	assigned_cells: Array[Vector2i],
	assigned_destination_scene: String,
	assigned_arrival_cell: Vector2i = Vector2i.ZERO
) -> ExplorationExitData:
	var exit := ExplorationExitData.new()
	exit.exit_id = assigned_id
	exit.display_name = assigned_display_name
	exit.cells.assign(assigned_cells)
	exit.destination_scene = assigned_destination_scene
	exit.arrival_cell = assigned_arrival_cell
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
