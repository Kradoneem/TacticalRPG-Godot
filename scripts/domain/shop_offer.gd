class_name ShopOffer
extends Resource

enum ProductKind { ITEM, EQUIPMENT }

@export var product_kind: ProductKind = ProductKind.ITEM
@export var product_id: StringName
@export var buy_price: int = 0
@export var required_flags: PackedStringArray = PackedStringArray()


func definition() -> Resource:
	match product_kind:
		ProductKind.ITEM:
			return ItemData.get_item(product_id)
		ProductKind.EQUIPMENT:
			return EquipmentData.get_equipment(product_id)

	return null


func validation_error() -> String:
	if product_id == &"" or definition() == null:
		return "Onbekend shopproduct: %s" % product_id

	if buy_price <= 0:
		return "Shopprijs moet positief zijn: %s" % product_id

	for flag: String in required_flags:
		if flag.strip_edges().is_empty():
			return "Lege flagvoorwaarde."

	return ""


func is_available(state: Node) -> bool:
	for flag: String in required_flags:
		if not state.has_flag(flag):
			return false

	return true


func sell_price() -> int:
	return buy_price >> 1


func display_name() -> String:
	var data: Resource = definition()

	return (
		String(product_id)
		if data == null
		else String(data.get("display_name"))
	)


func description() -> String:
	var data: Resource = definition()

	return "" if data == null else String(data.get("description"))


func quantity(state: Node) -> int:
	if product_kind == ProductKind.ITEM:
		return state.get_item_quantity(product_id)

	return state.get_equipment_quantity(product_id)
