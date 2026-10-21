extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, description: String) -> void:
	if not value:
		_failures += 1
		push_error(description)


func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.start_new_game()

	var shop: ShopDefinition = ShopData.get_shop(
		ShopData.ALDENMOOR_SHOP_ID
	)

	_check(
		shop.validation_error().is_empty(),
		"Shopdefinition geldig"
	)

	var potion: ShopOffer = shop.get_offer(
		ShopOffer.ProductKind.ITEM,
		&"potion"
	)

	var gold_before: int = state.gold
	var quantity_before: int = state.get_item_quantity(&"potion")

	var result: Dictionary = state.buy_shop_product(
		shop.shop_id,
		potion.product_kind,
		potion.product_id
	)

	_check(result.success, "Potion kopen")

	_check(
		state.gold == gold_before - potion.buy_price,
		"Gold eenmaal afgeschreven"
	)

	_check(
		state.get_item_quantity(&"potion") == quantity_before + 1,
		"Potion eenmaal toegekend"
	)

	result = state.sell_shop_product(
		shop.shop_id,
		potion.product_kind,
		potion.product_id
	)

	_check(result.success, "Potion verkopen")

	_check(
		state.get_item_quantity(&"potion") == quantity_before,
		"Potion eenmaal verwijderd"
	)

	_check(
		state.gold == gold_before - potion.buy_price + potion.sell_price(),
		"Halve verkoopprijs"
	)

	state.gold = 0
	quantity_before = state.get_item_quantity(&"potion")

	result = state.buy_shop_product(
		shop.shop_id,
		potion.product_kind,
		potion.product_id
	)

	_check(
		not result.success
		and state.gold == 0
		and state.get_item_quantity(&"potion") == quantity_before,
		"Onvoldoende gold verandert niets"
	)

	# Explicit testfixture only, not game-start content.
	state.gold = 1000

	var elixir: ShopOffer = shop.get_offer(
		ShopOffer.ProductKind.ITEM,
		&"elixir"
	)

	result = state.buy_shop_product(
		shop.shop_id,
		elixir.product_kind,
		elixir.product_id
	)

	_check(
		not result.success and state.gold == 1000,
		"Locked aanbod geweigerd"
	)

	state.set_flag(ShopData.SPECIAL_STOCK_FLAG)

	result = state.buy_shop_product(
		shop.shop_id,
		elixir.product_kind,
		elixir.product_id
	)

	_check(result.success, "Flag unlockt aanbod")

	state.set_flag(ShopData.SPECIAL_STOCK_FLAG, false)
	gold_before = state.gold

	result = state.buy_shop_product(
		shop.shop_id,
		elixir.product_kind,
		elixir.product_id
	)

	_check(
		not result.success and state.gold == gold_before,
		"Transactie valideert flag opnieuw"
	)

	result = state.sell_shop_product(
		shop.shop_id,
		elixir.product_kind,
		elixir.product_id
	)

	_check(
		result.success,
		"Los verkregen locked product blijft verkoopbaar"
	)

	var unit: Unit = state.get_main_squad().get_leader()
	state.change_equipment(unit, &"weapon", &"iron_sword")

	var gear: ShopOffer = shop.get_offer(
		ShopOffer.ProductKind.EQUIPMENT,
		&"iron_sword"
	)

	gold_before = state.gold

	result = state.sell_shop_product(
		shop.shop_id,
		gear.product_kind,
		gear.product_id
	)

	_check(
		not result.success and state.gold == gold_before,
		"Uitgerust exemplaar niet verkopen"
	)

	_check(
		unit.get_equipment_id(&"weapon") == &"iron_sword",
		"Unit equipment blijft intact"
	)

	state.change_equipment(unit, &"weapon")

	result = state.sell_shop_product(
		shop.shop_id,
		gear.product_kind,
		gear.product_id
	)

	_check(result.success, "Afgelegd equipment verkopen")

	result = state.sell_shop_product(
		shop.shop_id,
		gear.product_kind,
		gear.product_id
	)

	_check(
		not result.success,
		"Geen dubbel verkoopbaar exemplaar"
	)

	gold_before = state.gold

	result = state.buy_shop_product(
		&"missing_shop",
		potion.product_kind,
		potion.product_id
	)

	_check(
		not result.success and state.gold == gold_before,
		"Onbekende shop veilig"
	)

	# Independent shop instance proves prices live on shops,
	# not catalog items.
	var other := ShopDefinition.new()
	other.shop_id = &"test_other_shop"

	var other_offer := ShopOffer.new()
	other_offer.product_id = &"potion"
	other_offer.buy_price = 31
	other.offers.append(other_offer)

	_check(
		other_offer.sell_price() == 15,
		"Oneven halve prijs naar beneden"
	)

	state.gold = 1000

	result = ShopTransaction.resolve(
		state,
		other,
		0,
		&"potion",
		false
	)

	_check(
		result.success and state.gold == 969,
		"Afzonderlijke shopprijs"
	)

	_check(
		potion.buy_price == 20,
		"Eerste shopprijs onveranderd"
	)

	_check(
		shop.talk_dialogue.allow_replay
		and shop.talk_dialogue.validation_error().is_empty(),
		"Herhaalbaar Talk-contract"
	)

	print("[Shops] %d failure(s)" % _failures)
	quit(0 if _failures == 0 else 1)
