class_name ExplorationEntryContext
extends RefCounted

## One transition request. Squad ownership remains with GameState.
## Source and destination cells belong to different maps.

var source_scene: String
var destination_scene: String
var departure_cell: Vector2i
var arrival_cell: Vector2i
var main_squad: Squad


func _init(
	assigned_source: String,
	assigned_destination: String,
	assigned_departure: Vector2i,
	assigned_arrival: Vector2i,
	assigned_squad: Squad
) -> void:
	source_scene = assigned_source
	destination_scene = assigned_destination
	departure_cell = assigned_departure
	arrival_cell = assigned_arrival
	main_squad = assigned_squad
