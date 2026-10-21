class_name ShopTransaction
extends RefCounted


static func resolve(
	state: Node,
	shop: ShopDefinition,
	kind: int,
	id: StringName,
	selling: bool
) -> Dictionary:
	if state == null or shop == null:
		return _failure("Shop ontbreekt.")

	var problem: String = shop.validation_error()

	if not problem.is_empty():
		return _failure(problem)

	var offer: ShopOffer = shop.get_offer(kind, id)

	if offer == null:
		return _failure("Deze shop verhandelt dit product niet.")

	if not selling and not offer.is_available(state):
		return _failure("Aanbieding is niet beschikbaar.")

	var quantity: int = offer.quantity(state)
	var price: int = (
		offer.sell_price()
		if selling
		else offer.buy_price
	)

	if selling and quantity <= 0:
		return _failure("Geen los exemplaar in inventory.")

	if not selling and state.gold < price:
		return _failure("Onvoldoende gold.")

	# Guard addition overflow before any mutation.
	if selling and state.gold > 9223372036854775807 - price:
		return _failure("Goldlimiet bereikt.")

	if not selling and quantity == 9223372036854775807:
		return _failure("Inventorylimiet bereikt.")

	var inventory: Dictionary = (
		state.item_inventory
		if kind == ShopOffer.ProductKind.ITEM
		else state.equipment_inventory
	)

	var remaining: int = (
		quantity - 1
		if selling
		else quantity + 1
	)

	if remaining == 0:
		inventory.erase(id)
	else:
		inventory[id] = remaining

	state.gold = (
		state.gold + price
		if selling
		else state.gold - price
	)

	# No await/callbacks before this point: all state is committed.
	state.gold_changed.emit(state.gold)

	if kind == ShopOffer.ProductKind.ITEM:
		state.item_inventory_changed.emit()
	else:
		state.equipment_inventory_changed.emit()

	return {
		"success": true,
		"message": "%s: %s — %d gold." % [
			"Verkocht" if selling else "Gekocht",
			offer.display_name(),
			price
		]
	}


static func _failure(message: String) -> Dictionary:
	return {
		"success": false,
		"message": message
	}
