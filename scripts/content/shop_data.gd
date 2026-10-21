class_name ShopData
extends RefCounted

const ALDENMOOR_SHOP_ID: StringName = &"aldenmoor_general_store"
const SPECIAL_STOCK_FLAG: String = "shops/aldenmoor/special_stock"

static var _catalog: Dictionary = {}


static func get_shop(shop_id: StringName) -> ShopDefinition:
	_ensure_catalog()

	return _catalog.get(shop_id) as ShopDefinition


static func get_shop_for_destination(
	city: String,
	destination_id: StringName
) -> ShopDefinition:
	if city == CityData.CITY_NAME and destination_id == &"shop":
		return get_shop(ALDENMOOR_SHOP_ID)

	return null


static func _ensure_catalog() -> void:
	if not _catalog.is_empty():
		return

	var shop := ShopDefinition.new()
	shop.shop_id = ALDENMOOR_SHOP_ID
	shop.display_name = "Aldenmoor — General Store"

	# Newly chosen prototype prices; not migrated or balanced.
	shop.offers.append(_offer(
		ShopOffer.ProductKind.ITEM,
		&"potion",
		20
	))

	shop.offers.append(_offer(
		ShopOffer.ProductKind.ITEM,
		&"hi_potion",
		60
	))

	shop.offers.append(_offer(
		ShopOffer.ProductKind.ITEM,
		&"ether",
		40
	))

	shop.offers.append(_offer(
		ShopOffer.ProductKind.ITEM,
		&"elixir",
		120,
		PackedStringArray([SPECIAL_STOCK_FLAG])
	))

	shop.offers.append(_offer(
		ShopOffer.ProductKind.EQUIPMENT,
		&"iron_sword",
		80
	))

	shop.offers.append(_offer(
		ShopOffer.ProductKind.EQUIPMENT,
		&"wooden_shield",
		60
	))

	shop.offers.append(_offer(
		ShopOffer.ProductKind.EQUIPMENT,
		&"berserkers_ring",
		100
	))

	shop.offers.append(_offer(
		ShopOffer.ProductKind.EQUIPMENT,
		&"sages_ring",
		100
	))

	var dialogue := DialogueDefinition.new()
	dialogue.dialogue_id = &"aldenmoor_shop_talk"
	dialogue.allow_replay = true

	dialogue.lines.append(DialogueLine.create(
		"Shopkeeper",
		"Welkom. Je kunt hier supplies en uitrusting kopen of verkopen."
	))

	dialogue.choices.append(DialogueChoice.create(
		&"stock",
		"Wat verkoop je?",
		DialogueLine.create(
			"Shopkeeper",
			"Bekijk Buy voor ons huidige assortiment. "
			+ "De prijzen staan per product vermeld."
		)
	))

	dialogue.choices.append(DialogueChoice.create(
		&"selling",
		"Wat krijg ik voor mijn spullen?",
		DialogueLine.create(
			"Shopkeeper",
			"De helft van onze koopprijs, naar beneden afgerond. "
			+ "Leg uitgerust equipment eerst af."
		)
	))

	shop.talk_dialogue = dialogue
	_catalog[shop.shop_id] = shop


static func _offer(
	kind: ShopOffer.ProductKind,
	id: StringName,
	price: int,
	flags: PackedStringArray = PackedStringArray()
) -> ShopOffer:
	var offer := ShopOffer.new()

	offer.product_kind = kind
	offer.product_id = id
	offer.buy_price = price
	offer.required_flags = flags

	return offer
