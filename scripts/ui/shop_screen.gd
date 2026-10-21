class_name ShopScreen
extends Control

signal closed
signal talk_requested(definition: DialogueDefinition)
signal dialogue_result(
	dialogue_id: StringName,
	choice_id: StringName,
	committed: bool
)

enum Page { MENU, BUY, SELL, CONFIRM }

var _shop: ShopDefinition
var _page: Page = Page.MENU
var _return_page: Page = Page.BUY

var _pending_kind: int = 0
var _pending_id: StringName = &""

var _column: VBoxContainer
var _scroll: ScrollContainer
var _heading: Label
var _status: Label
var _details: Label

var _buttons: Array[Button] = []
var _row_offers: Array[ShopOffer] = []

var _selected: int = 0
var _page_frame: int = -1
var _message: String = ""
var _refresh_pending: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var color := ColorRect.new()
	color.color = Color("#18252c")
	color.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(color)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)

	add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	_heading = Label.new()
	_heading.add_theme_font_size_override("font_size", 28)
	content.add_child(_heading)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_scroll)

	_column = VBoxContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_theme_constant_override("separation", 8)
	_scroll.add_child(_column)

	_details = Label.new()
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.custom_minimum_size.y = 70
	content.add_child(_details)

	GameState.gold_changed.connect(_on_gold_changed)
	GameState.item_inventory_changed.connect(_queue_refresh)
	GameState.equipment_inventory_changed.connect(_queue_refresh)
	GameState.flag_changed.connect(_on_flag_changed)

	hide()


func open_shop(shop: ShopDefinition) -> bool:
	if shop == null or not shop.validation_error().is_empty():
		return false

	_shop = shop
	_message = ""

	show()
	_show_page(Page.MENU)

	return true


func is_open() -> bool:
	return visible and _shop != null


func is_confirming() -> bool:
	return is_open() and _page == Page.CONFIRM


func _close() -> void:
	if not is_open():
		return

	hide()
	_shop = null
	closed.emit()


func _show_page(
	page: Page,
	preserve_selection: bool = false
) -> void:
	_page = page
	_page_frame = Engine.get_process_frames()

	var previous_selection: int = _selected

	_buttons.clear()
	_row_offers.clear()

	for child: Node in _column.get_children():
		_column.remove_child(child)
		child.queue_free()

	_heading.text = _shop.display_name
	_update_status()

	match page:
		Page.MENU:
			_add_button(
				"Talk",
				_talk,
				null,
				_shop.talk_dialogue == null
			)
			_add_button("Buy", _show_page.bind(Page.BUY))
			_add_button("Sell", _show_page.bind(Page.SELL))
			_add_button("Back to city", _close)

		Page.BUY, Page.SELL:
			for offer: ShopOffer in _shop.offers:
				if page == Page.BUY and not offer.is_available(GameState):
					continue

				if page == Page.SELL and offer.quantity(GameState) <= 0:
					continue

				var price: int = (
					offer.sell_price()
					if page == Page.SELL
					else offer.buy_price
				)

				var text: String = (
					"%s — %d gold | Inventory: %d"
					% [
						offer.display_name(),
						price,
						offer.quantity(GameState)
					]
				)

				_add_button(
					text,
					_ask_transaction.bind(
						offer.product_kind,
						offer.product_id
					),
					offer
				)

			if _buttons.is_empty():
				var empty := Label.new()
				empty.text = "Geen beschikbare producten."
				_column.add_child(empty)

			_add_button(
				"Back to shop",
				_show_page.bind(Page.MENU)
			)

		Page.CONFIRM:
			var offer: ShopOffer = _shop.get_offer(
				_pending_kind,
				_pending_id
			)

			var summary := Label.new()

			if offer == null:
				summary.text = (
					"Product ontbreekt. Annuleer deze transactie."
				)
			else:
				var price: int = (
					offer.sell_price()
					if _return_page == Page.SELL
					else offer.buy_price
				)

				summary.text = (
					"%s: 1 × %s voor %d gold?"
					% [
						"Verkopen" if _return_page == Page.SELL else "Kopen",
						offer.display_name(),
						price
					]
				)

			_column.add_child(summary)

			_add_button(
				"Confirm",
				_commit_transaction,
				offer,
				offer == null
			)
			_add_button(
				"Cancel",
				_show_page.bind(_return_page)
			)

	_selected = (
		clampi(previous_selection, 0, _buttons.size() - 1)
		if preserve_selection
		else 0
	)

	if _buttons[_selected].disabled:
		_move_selection(1)
	else:
		_refresh_selection()


func _add_button(
	text: String,
	action: Callable,
	offer: ShopOffer = null,
	disabled: bool = false
) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 52
	button.disabled = disabled

	# Only our keyboard handler confirms; mouse still works.
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)

	_column.add_child(button)
	_buttons.append(button)
	_row_offers.append(offer)


func _refresh_selection() -> void:
	for index in range(_buttons.size()):
		_buttons[index].modulate = (
			Color("#ffe183")
			if index == _selected
			else Color.WHITE
		)

	var offer: ShopOffer = _row_offers[_selected]
	_details.text = "" if offer == null else offer.description()

	_scroll.ensure_control_visible(_buttons[_selected])


func _move_selection(direction: int) -> void:
	for attempt in range(_buttons.size()):
		_selected = posmod(
			_selected + direction,
			_buttons.size()
		)

		if not _buttons[_selected].disabled:
			break

	_refresh_selection()


func handle_menu_input(event: InputEvent) -> void:
	if not is_open() or not event is InputEventKey:
		return

	if event.is_action("ui_cancel"):
		if _page == Page.CONFIRM:
			get_viewport().set_input_as_handled()

			if event.is_pressed() and not event.is_echo():
				_show_page(_return_page)

		return

	get_viewport().set_input_as_handled()

	if not event.is_pressed() or event.is_echo():
		return

	if (
		event.is_action_pressed("move_up")
		or event.is_action_pressed("ui_up")
		or event.is_action_pressed("move_left")
		or event.is_action_pressed("ui_left")
	):
		_move_selection(-1)

	elif (
		event.is_action_pressed("move_down")
		or event.is_action_pressed("ui_down")
		or event.is_action_pressed("move_right")
		or event.is_action_pressed("ui_right")
	):
		_move_selection(1)

	elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		if (
			Engine.get_process_frames() > _page_frame
			and not _buttons[_selected].disabled
		):
			_buttons[_selected].pressed.emit()


func _ask_transaction(kind: int, id: StringName) -> void:
	_return_page = _page
	_pending_kind = kind
	_pending_id = id

	_show_page(Page.CONFIRM)


func _commit_transaction() -> void:
	# Registry resolves the live offer again; do not trust UI snapshots.
	var result: Dictionary

	if _return_page == Page.SELL:
		result = GameState.sell_shop_product(
			_shop.shop_id,
			_pending_kind,
			_pending_id
		)
	else:
		result = GameState.buy_shop_product(
			_shop.shop_id,
			_pending_kind,
			_pending_id
		)

	_message = String(result.get("message", ""))
	_show_page(_return_page)


func _talk() -> void:
	if _shop.talk_dialogue != null:
		talk_requested.emit(_shop.talk_dialogue)


func on_dialogue_finished(
	id: StringName,
	choice: StringName,
	committed: bool
) -> void:
	if (
		_shop == null
		or _shop.talk_dialogue == null
		or id != _shop.talk_dialogue.dialogue_id
	):
		return

	_page_frame = Engine.get_process_frames()

	# Explicit hook only: no quests/rewards here.
	dialogue_result.emit(id, choice, committed)


func _update_status() -> void:
	_status.text = (
		"Gold: %d | WASD/pijltjes: selecteren "
		+ "| Enter/Spatie: bevestigen | Escape: Party\n%s"
	) % [GameState.gold, _message]

	if _page == Page.CONFIRM:
		_status.text = (
			"Gold: %d | Escape: annuleren\n%s"
			% [GameState.gold, _message]
		)


func _on_gold_changed(_amount: int) -> void:
	_queue_refresh()


func _on_flag_changed(_id: String, _enabled: bool) -> void:
	_queue_refresh()


func _queue_refresh() -> void:
	if not is_open() or _refresh_pending:
		return

	_refresh_pending = true
	call_deferred("_refresh_after_state_change")


func _refresh_after_state_change() -> void:
	_refresh_pending = false

	if not is_open():
		return

	if _page == Page.CONFIRM:
		_update_status()
	else:
		_show_page(_page, true)
