class_name ExplorationEntryContext
extends RefCounted

## departure_cell is null for a non-grid source.
## arrival_cell always belongs to the destination exploration grid.

var source_scene: String
var destination_scene: String
var departure_cell: Variant
var arrival_cell: Vector2i
var main_squad: Squad


func _init(
	assigned_source: String,
	assigned_destination: String,
	assigned_departure: Variant,
	assigned_arrival: Vector2i,
	assigned_squad: Squad
) -> void:
	source_scene = assigned_source
	destination_scene = assigned_destination
	departure_cell = assigned_departure
	arrival_cell = assigned_arrival
	main_squad = assigned_squad
