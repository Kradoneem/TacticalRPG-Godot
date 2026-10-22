class_name ChestData
extends RefCounted

const CORRIDOR_CHEST_ID: StringName = &"sewer_corridor/prototype_chest"

static var _catalog: Dictionary = {}


static func get_chest(chest_id: StringName) -> ChestDefinition:
	_ensure_catalog()
	return _catalog.get(chest_id) as ChestDefinition


static func get_chests_for_room(room_id: String) -> Array[ChestDefinition]:
	_ensure_catalog()

	var results: Array[ChestDefinition] = []

	for definition: ChestDefinition in _catalog.values():
		if definition.room_id == room_id:
			results.append(definition)

	return results


static func _ensure_catalog() -> void:
	if not _catalog.is_empty():
		return

	var chest := ChestDefinition.new()
	chest.chest_id = CORRIDOR_CHEST_ID
	chest.room_id = "sewer_corridor"
	chest.cell = Vector2i(1, 3)
	chest.display_name = "Prototype Chest"
	chest.items[&"potion"] = 1

	_catalog[chest.chest_id] = chest
