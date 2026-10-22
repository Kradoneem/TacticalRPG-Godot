class_name ChestDefinition
extends Resource

@export var chest_id: StringName = &""
@export var room_id: String = ""
@export var cell: Vector2i = Vector2i.ZERO
@export var display_name: String = "Chest"

@export var gold: int = 0
@export var items: Dictionary = {}
@export var equipment: Dictionary = {}


func validation_error() -> String:
	if chest_id == &"":
		return "Chest-ID ontbreekt."

	if room_id.strip_edges().is_empty():
		return "Chest heeft geen map-ID."

	if display_name.strip_edges().is_empty():
		return "Chestnaam ontbreekt."

	if gold < 0:
		return "Chest-gold mag niet negatief zijn."

	var problem: String = _validate_products(items, false)

	if not problem.is_empty():
		return problem

	return _validate_products(equipment, true)


func _validate_products(
	products: Dictionary,
	is_equipment: bool
) -> String:
	var seen: Dictionary = {}

	for raw_id: Variant in products:
		if not raw_id is String and not raw_id is StringName:
			return "Chest-product-ID moet String of StringName zijn."

		var product_id := StringName(raw_id)

		if product_id == &"" or seen.has(product_id):
			return "Leeg of dubbel chest-product-ID."

		seen[product_id] = true

		var amount: Variant = products[raw_id]

		if not amount is int or int(amount) <= 0:
			return "Chest-hoeveelheid moet een positief geheel getal zijn."

		if is_equipment:
			var gear: Equipment = EquipmentData.get_equipment(product_id)

			if gear == null or not gear.is_valid_definition():
				return "Onbekend of ongeldig chest-equipment: %s" % product_id
		elif ItemData.get_item(product_id) == null:
			return "Onbekend chest-item: %s" % product_id

	return ""
