class_name EquipmentData
extends RefCounted

## Migrated Python prototype gear.
## Catalog definitions are shared; callers must not mutate them.

static var _catalog: Dictionary = {}


static func get_equipment(equipment_id: StringName) -> Equipment:
	_ensure_catalog()
	return _catalog.get(equipment_id) as Equipment


static func get_all_equipment_ids() -> Array[StringName]:
	_ensure_catalog()

	var ids: Array[StringName] = []

	for equipment_id in _catalog:
		ids.append(StringName(equipment_id))

	return ids


static func _ensure_catalog() -> void:
	if not _catalog.is_empty():
		return

	_register(
		&"iron_sword",
		"Iron Sword",
		&"weapon",
		{&"attack": 5}
	)

	_register(
		&"wooden_shield",
		"Wooden Shield",
		&"armor",
		{&"defense": 3, &"max_hp": 5}
	)

	_register(
		&"berserkers_ring",
		"Berserker's Ring",
		&"accessory",
		{&"attack": 4}
	)

	_register(
		&"sages_ring",
		"Sage's Ring",
		&"accessory",
		{&"wisdom": 4}
	)


static func _register(
	equipment_id: StringName,
	display_name: String,
	slot: StringName,
	bonuses: Dictionary
) -> void:
	var gear := Equipment.new()

	gear.equipment_id = equipment_id
	gear.display_name = display_name
	gear.slot = String(slot)
	gear.bonuses = bonuses.duplicate()
	gear.description = gear.get_bonus_summary()

	_catalog[equipment_id] = gear
