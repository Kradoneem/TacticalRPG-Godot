class_name ShopDefinition
extends Resource

@export var shop_id: StringName
@export var display_name: String
@export var offers: Array[ShopOffer] = []
@export var talk_dialogue: DialogueDefinition


func get_offer(
	product_kind: int,
	product_id: StringName
) -> ShopOffer:
	for offer: ShopOffer in offers:
		if (
			offer != null
			and offer.product_kind == product_kind
			and offer.product_id == product_id
		):
			return offer

	return null


func validation_error() -> String:
	if shop_id == &"":
		return "Shop-ID ontbreekt."

	var seen: Dictionary = {}

	for offer: ShopOffer in offers:
		if offer == null:
			return "Lege shopaanbieding."

		var problem: String = offer.validation_error()

		if not problem.is_empty():
			return problem

		var key: String = "%d/%s" % [
			offer.product_kind,
			offer.product_id
		]

		if seen.has(key):
			return "Dubbel shopproduct: " + key

		seen[key] = true

	if talk_dialogue != null:
		if not talk_dialogue.allow_replay:
			return "Shop Talk moet herhaalbaar zijn."

		return talk_dialogue.validation_error()

	return ""
