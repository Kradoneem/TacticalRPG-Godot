class_name QuestObjective
extends Resource

## Immutable content definition, not progress.

enum Kind {
	SQUAD_DEFEATED,
	MAP_CLEARED,
	LOCATION_CLEARED
}

@export var objective_id: StringName = &""
@export var description: String = ""
@export var kind: Kind = Kind.SQUAD_DEFEATED
@export var target_id: String = ""


func is_valid_definition() -> bool:
	if (
		objective_id == &""
		or description.strip_edges().is_empty()
		or target_id.strip_edges().is_empty()
	):
		return false

	if kind == Kind.LOCATION_CLEARED:
		return not LocationData.get_required_map_ids(target_id).is_empty()

	return kind in [
		Kind.SQUAD_DEFEATED,
		Kind.MAP_CLEARED,
		Kind.LOCATION_CLEARED
	]


func is_satisfied(state: Node) -> bool:
	if state == null or not is_valid_definition():
		return false

	match kind:
		Kind.SQUAD_DEFEATED:
			return bool(state.call("is_enemy_squad_defeated", target_id))

		Kind.MAP_CLEARED:
			return bool(state.call("is_map_cleared", target_id))

		Kind.LOCATION_CLEARED:
			var maps: Array[String] = LocationData.get_required_map_ids(
				target_id
			)
			return bool(state.call("are_location_maps_cleared", maps))

	return false
