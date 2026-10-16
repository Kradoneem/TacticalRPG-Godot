class_name TacticalEnemySpawn
extends RefCounted

## Configuration for exactly one independent enemy squad-token.
## This is initial content, not mutable gameplay state.

var spawn_id: StringName
var start_cell: Vector2i
var squad_factory: Callable
var patrol_route: Array[Vector2i] = []


func _init(
	assigned_id: StringName,
	assigned_start_cell: Vector2i,
	assigned_squad_factory: Callable,
	assigned_patrol_route: Array[Vector2i] = []
) -> void:
	spawn_id = assigned_id
	start_cell = assigned_start_cell
	squad_factory = assigned_squad_factory
	patrol_route.assign(assigned_patrol_route)


func create_squad() -> Squad:
	if not squad_factory.is_valid():
		push_error(
            "Enemy spawn '%s' has no valid Squad factory."
			% str(spawn_id)
		)
		return null

	var result: Variant = squad_factory.call()

	if not result is Squad:
		push_error(
            "Enemy spawn '%s' factory must return a Squad."
			% str(spawn_id)
		)
		return null

	return result as Squad
