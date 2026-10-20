class_name ItemUseResolver
extends RefCounted

## Executes supported single-target item effects.
## Does not own inventory, UI, squad ownership or tactical turns.


static func validate_use(item: GameItem, target: Unit) -> String:
	if item == null:
		return "Unknown item."

	if item.item_id == &"" or item.display_name.is_empty():
		return "Invalid item identity."

	if item.effects.is_empty():
		return "This item has no effects."

	if target == null:
		return "No target selected."

	if not target.is_alive():
		return "This item requires a living target."

	for effect: ItemEffect in item.effects:
		if effect == null:
			return "This item contains a missing effect."

		if effect.amount <= 0:
			return "Item effect amounts must be positive."

		match effect.effect_type:
			ItemEffect.Type.RESTORE_HP, ItemEffect.Type.RESTORE_MP:
				pass
			_:
				return "This item effect is not supported."

	return ""


static func resolve(item: GameItem, target: Unit) -> Dictionary:
	var validation_error: String = validate_use(item, target)

	if not validation_error.is_empty():
		return {
			"success": false,
			"message": validation_error
		}

	var restored_hp: int = 0
	var restored_mp: int = 0
	var has_hp_effect: bool = false
	var has_mp_effect: bool = false

	for effect: ItemEffect in item.effects:
		match effect.effect_type:
			ItemEffect.Type.RESTORE_HP:
				has_hp_effect = true
				restored_hp += target.heal(effect.amount)

			ItemEffect.Type.RESTORE_MP:
				has_mp_effect = true
				restored_mp += target.restore_mp(effect.amount)

	var recovery_parts: Array[String] = []

	if has_hp_effect:
		recovery_parts.append("%d HP" % restored_hp)

	if has_mp_effect:
		recovery_parts.append("%d MP" % restored_mp)

	return {
		"success": true,
		"message": "%s recovers %s." % [
			target.display_name,
			" and ".join(recovery_parts)
		],
		"restored_hp": restored_hp,
		"restored_mp": restored_mp
	}
