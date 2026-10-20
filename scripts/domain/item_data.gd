class_name ItemData
extends RefCounted

## Central item catalog.
## Values are migrated from the Python prototype.
## Definitions are shared and must not be mutated by inventory or UI code.

static var _catalog: Dictionary = {}


static func get_item(item_id: StringName) -> GameItem:
	_ensure_catalog()
	return _catalog.get(item_id) as GameItem


static func get_all_item_ids() -> Array[StringName]:
	_ensure_catalog()

	var item_ids: Array[StringName] = []

	for item_id in _catalog:
		item_ids.append(StringName(item_id))

	return item_ids


static func _ensure_catalog() -> void:
	if not _catalog.is_empty():
		return

	var potion := _create_item(
		&"potion",
		"Potion",
		"Restores 20 HP to one living ally."
	)
	potion.effects.append(
		_create_effect(ItemEffect.Type.RESTORE_HP, 20)
	)
	_catalog[potion.item_id] = potion

	var hi_potion := _create_item(
		&"hi_potion",
		"Hi-Potion",
		"Restores 50 HP to one living ally."
	)
	hi_potion.effects.append(
		_create_effect(ItemEffect.Type.RESTORE_HP, 50)
	)
	_catalog[hi_potion.item_id] = hi_potion

	var ether := _create_item(
		&"ether",
		"Ether",
		"Restores 10 MP to one living ally."
	)
	ether.effects.append(
		_create_effect(ItemEffect.Type.RESTORE_MP, 10)
	)
	_catalog[ether.item_id] = ether

	var elixir := _create_item(
		&"elixir",
		"Elixir",
		"Restores 30 HP and MP to one living ally."
	)
	elixir.effects.append(
		_create_effect(ItemEffect.Type.RESTORE_HP, 30)
	)
	elixir.effects.append(
		_create_effect(ItemEffect.Type.RESTORE_MP, 30)
	)
	_catalog[elixir.item_id] = elixir


static func _create_item(
	item_id: StringName,
	display_name: String,
	description: String
) -> GameItem:
	var item := GameItem.new()

	item.item_id = item_id
	item.display_name = display_name
	item.description = description

	return item


static func _create_effect(
	effect_type: ItemEffect.Type,
	amount: int
) -> ItemEffect:
	var effect := ItemEffect.new()

	effect.effect_type = effect_type
	effect.amount = amount

	return effect
