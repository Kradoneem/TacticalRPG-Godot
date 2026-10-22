class_name CityScreen
extends Control

@export var city_background: Texture2D
@export var city_layout: CityLayoutData

var _layout_background: TextureRect
var _layout_texture: Texture2D
var _city_destinations: Array[CityDestination] = []

var _title: Label
var _status: Label
var _locations_layer: Control
var _guild_panel: PanelContainer
var _guild_content: VBoxContainer

var _city_buttons: Array[Button] = []
var _guild_buttons: Array[Button] = []
var _selected_index: int = 0

var _viewing_guild: bool = false
var _transitioning: bool = false
var _page_frame: int = -1
var _shop_screen: ShopScreen
var _tavern_screen: TavernScreen

var _location: WorldLocation


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Without context (direct launch, tests): Aldenmoor.
	if _location == null:
		_location = WorldMapData.get_location(WorldMapData.ALDENMOOR_ID)

	GameState.current_city = _location.display_name
	GameState.current_location = _location.display_name
	GameState.in_city = true

	_build_screen()

	_shop_screen = ShopScreen.new()
	_shop_screen.name = "ShopScreen"
	add_child(_shop_screen)

	_shop_screen.closed.connect(_show_city)
	_shop_screen.talk_requested.connect(_on_shop_talk_requested)

	_tavern_screen = TavernScreen.new()
	_tavern_screen.name = "TavernScreen"
	add_child(_tavern_screen)

	_tavern_screen.closed.connect(_show_city)
	_tavern_screen.talk_requested.connect(_on_tavern_talk_requested)

	_show_city()

func _build_screen() -> void:
	_layout_texture = city_background

	if city_layout != null:
		var problem: String = city_layout.validation_error()

		if problem.is_empty():
			_layout_texture = city_layout.background
		else:
			push_error("City layout ongeldig: " + problem)
			city_layout = null

	var background_color := ColorRect.new()
	background_color.color = Color("#26343a")
	background_color.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	background_color.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_color)

	_layout_background = TextureRect.new()
	_layout_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_layout_background.stretch_mode = TextureRect.STRETCH_SCALE
	_layout_background.texture = _layout_texture
	_layout_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layout_background)

	var header := VBoxContainer.new()
	header.position = Vector2(24.0, 20.0)
	header.custom_minimum_size = Vector2(700.0, 100.0)
	add_child(header)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 28)
	header.add_child(_title)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_status)

	_locations_layer = Control.new()
	_locations_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_locations_layer)

	_city_destinations = CityData.get_destinations()

	for destination: CityDestination in _city_destinations:
		var button := Button.new()
		button.text = destination.display_name
		button.custom_minimum_size = Vector2(230.0, 56.0)

		button.pressed.connect(
			_on_destination_selected.bind(destination.destination_id)
		)

		_locations_layer.add_child(button)
		_city_buttons.append(button)

	_guild_panel = PanelContainer.new()
	_guild_panel.anchor_left = 0.20
	_guild_panel.anchor_right = 0.80
	_guild_panel.anchor_top = 0.25
	_guild_panel.anchor_bottom = 0.75
	add_child(_guild_panel)

	var margin := MarginContainer.new()

	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)

	_guild_panel.add_child(margin)

	_guild_content = VBoxContainer.new()
	_guild_content.add_theme_constant_override("separation", 18)
	margin.add_child(_guild_content)

	resized.connect(_update_city_layout)
	_update_city_layout()
	call_deferred("_update_city_layout")
	
func _show_city() -> void:
	_viewing_guild = false
	_selected_index = 0
	_page_frame = Engine.get_process_frames()

	_guild_panel.hide()
	_locations_layer.show()

	_title.text = "%s — City" % GameState.current_city

	_status.text = (
		"WASD/pijltjes: selecteren | Enter/Spatie: openen | Escape: Party\n"
		+ "Castle en Home zijn nog niet geïmplementeerd."
	)

	if _layout_texture == null:
		_status.text += "\nCity-background ontbreekt: layout-placeholder."

	_update_city_layout()
	_refresh_selection()
	
func _show_guild() -> void:
	_viewing_guild = true
	_selected_index = 0
	_page_frame = Engine.get_process_frames()

	_locations_layer.hide()
	_guild_panel.show()

	_title.text = "%s — Adventurer's Guild" % GameState.current_city
	_status.text = (
		"WASD/pijltjes: selecteren | Enter/Spatie: bevestigen | Escape: Party"
	)

	_build_guild_panel()


func _build_guild_panel() -> void:
	_guild_buttons.clear()

	for child: Node in _guild_content.get_children():
		_guild_content.remove_child(child)
		child.queue_free()

	var heading := Label.new()
	heading.text = "Adventurer's Guild"
	heading.add_theme_font_size_override("font_size", 26)
	_guild_content.add_child(heading)

	var description := Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var quest_status: String = GameState.get_quest_status(
		QuestData.GUILD_SEWER_QUEST_ID
	)

	if quest_status == "inactive":
		description.text = (
			"Prototypeopdracht beschikbaar: maak corridor en junction vrij."
		)
	else:
		description.text = (
			"Sewer investigation: %s. Bekijk de opdracht in het Quest Log."
			% quest_status
		)

	_guild_content.add_child(description)

	var talk := Button.new()
	talk.text = "Talk to the guild clerk"
	talk.custom_minimum_size = Vector2(0.0, 60.0)
	talk.disabled = quest_status != "inactive"
	talk.pressed.connect(_on_talk_to_guild_clerk)
	_guild_content.add_child(talk)
	_guild_buttons.append(talk)

	var back := Button.new()
	back.text = "Back to city"
	back.custom_minimum_size = Vector2(0.0, 60.0)
	back.pressed.connect(_show_city)
	_guild_content.add_child(back)
	_guild_buttons.append(back)

	_selected_index = 0 if not talk.disabled else 1
	_refresh_selection()


func _get_active_buttons() -> Array[Button]:
	return _guild_buttons if _viewing_guild else _city_buttons


func _refresh_selection() -> void:
	var buttons: Array[Button] = _get_active_buttons()

	for index in range(buttons.size()):
		buttons[index].modulate = (
			Color("#ffe183")
			if index == _selected_index
			else Color.WHITE
		)


func _move_selection(direction: int) -> void:
	var buttons: Array[Button] = _get_active_buttons()

	if buttons.is_empty():
		return

	for attempt in range(buttons.size()):
		_selected_index = posmod(
			_selected_index + direction,
			buttons.size()
		)

		if not buttons[_selected_index].disabled:
			break

	_refresh_selection()


func _confirm_selection() -> void:
	if Engine.get_process_frames() <= _page_frame:
		return

	var buttons: Array[Button] = _get_active_buttons()

	if (
		_selected_index < 0
		or _selected_index >= buttons.size()
		or buttons[_selected_index].disabled
	):
		return

	buttons[_selected_index].pressed.emit()

func _input(event: InputEvent) -> void:
	if _sub_screen_open():
		if _shop_screen != null and _shop_screen.is_open():
			_shop_screen.handle_menu_input(event)
		elif _tavern_screen != null and _tavern_screen.is_open():
			_tavern_screen.handle_menu_input(event)

		return

	if not event is InputEventKey:
		return

	if event.is_action("ui_cancel"):
		return

	get_viewport().set_input_as_handled()

	if _transitioning or not event.is_pressed() or event.is_echo():
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
		_confirm_selection()


func _on_destination_selected(destination_id: StringName) -> void:
	if (
		_transitioning
		or _sub_screen_open()
		or not can_process()
	):
		return

	var destination: CityDestination = CityData.get_destination(
		destination_id
	)

	if destination == null:
		return

	match destination.kind:
		CityDestination.Kind.GUILD:
			_show_guild()

		CityDestination.Kind.SHOP:
			var shop: ShopDefinition = ShopData.get_shop_for_destination(
				GameState.current_city,
				destination_id
			)

			if _shop_screen.open_shop(shop):
				_locations_layer.hide()
				_guild_panel.hide()
			else:
				_status.text = "Shop ontbreekt of heeft ongeldige content."

		CityDestination.Kind.TAVERN:
			var tavern: TavernDefinition = (
				TavernData.get_tavern_for_destination(
					GameState.current_city,
					destination_id
				)
			)

			if _tavern_screen.open_tavern(tavern):
				_locations_layer.hide()
				_guild_panel.hide()
			else:
				_status.text = "Tavern ontbreekt of heeft ongeldige content."

		CityDestination.Kind.SEWERS:
			_enter_sewers()

		CityDestination.Kind.WORLD_MAP:
			_open_world_map()

		_:
			_status.text = (
				"%s is nog niet geïmplementeerd."
				% destination.display_name
			)

func _on_talk_to_guild_clerk() -> void:
	if (
		_transitioning
		or not _viewing_guild
		or GameState.get_quest_status(
			QuestData.GUILD_SEWER_QUEST_ID
		) != "inactive"
	):
		return

	var main: Node = get_tree().current_scene

	if main == null or not main.has_method("request_dialogue"):
		push_warning("Guild dialogue requires Main.")
		return

	if not bool(main.call(
		"request_dialogue",
		self,
		DialogueData.get_guild_sewer_quest_dialogue()
	)):
		_status.text = "Dialogue kon niet starten. Controleer Output."

func on_dialogue_finished(
	dialogue_id: StringName,
	choice_id: StringName,
	committed: bool
) -> void:
	if _sub_screen_open():
		if _shop_screen != null and _shop_screen.is_open():
			_shop_screen.on_dialogue_finished(
				dialogue_id,
				choice_id,
				committed
			)
		elif _tavern_screen != null and _tavern_screen.is_open():
			_tavern_screen.on_dialogue_finished(
				dialogue_id,
				choice_id,
				committed
			)

		return

	if dialogue_id != DialogueData.GUILD_SEWER_DIALOGUE_ID:
		return

	if committed and choice_id == &"accept_sewer_contract":
		GameState.activate_quest(QuestData.GUILD_SEWER_QUEST_ID)

	_page_frame = Engine.get_process_frames()
	_build_guild_panel()

func _enter_sewers() -> void:
	if not can_enter_sewers():
		return

	# Deferred removal avoids changing the scene tree inside a Button callback.
	_transitioning = true
	_status.text = "Sewers betreden..."
	call_deferred("_perform_sewer_entry")


func _perform_sewer_entry() -> void:
	# Release the local request guard for SceneManager's eligibility check.
	# The transition itself is synchronous and contains no await.
	_transitioning = false

	var destination: Node = SceneManager.enter_exploration_from_city(
		self,
		CityData.SEWER_ENTRANCE_SCENE,
		CityData.SEWER_ARRIVAL_CELL
	)

	if destination == null:
		_status.text = "Sewer-entry mislukt. Controleer Output."


func can_enter_sewers() -> bool:
	return (
		not _transitioning
		and not _viewing_guild
		and can_process()
		and not _sub_screen_open()
	)

func can_open_party_menu() -> bool:
	return (
		not _transitioning
		and not (
			_shop_screen != null
			and _shop_screen.is_confirming()
		)
	)

func can_show_quest_updates() -> bool:
	return not _transitioning

func on_returned_from_exploration() -> void:
	_transitioning = false
	GameState.current_city = _location.display_name
	GameState.current_location = _location.display_name
	GameState.in_city = true
	_show_city()

func _update_city_layout() -> void:
	if (
		_layout_background == null
		or _locations_layer == null
	):
		return

	var image_rect: Rect2 = CityLayoutData.get_image_rect(
		size,
		_layout_texture
	)

	_layout_background.position = image_rect.position
	_layout_background.size = image_rect.size

	_locations_layer.position = image_rect.position
	_locations_layer.size = image_rect.size

	for index in range(_city_buttons.size()):
		var destination: CityDestination = _city_destinations[index]
		var position_ratio: Vector2 = destination.position_ratio

		if city_layout != null:
			position_ratio = city_layout.get_label_position(
				destination.destination_id
			)

		var button: Button = _city_buttons[index]
		var button_size: Vector2 = button.get_combined_minimum_size()

		button.size = button_size
		button.position = (
			position_ratio * image_rect.size
			- button_size * 0.5
		)

func _on_shop_talk_requested(definition: DialogueDefinition) -> void:
	var main: Node = get_tree().current_scene

	if main == null or not main.has_method("request_dialogue"):
		push_warning("Shop Talk requires Main.")
		return

	if not bool(main.call(
		"request_dialogue",
		self,
		definition
	)):
		push_warning("Shop Talk kon niet starten.")

func prepare_location_entry(location: WorldLocation) -> bool:
	# CityScreen is Aldenmoor-only; another city needs its own design.
	if (
		location == null
		or location.kind != WorldLocation.Kind.CITY
		or location.location_id != WorldMapData.ALDENMOOR_ID
		or location.location_id != GameState.world_location_id
	):
		push_warning("CityScreen weigert deze locatie.")
		return false

	_location = location
	return true

func can_open_world_map() -> bool:
	return (
		not _transitioning
		and not _viewing_guild
		and can_process()
		and not _sub_screen_open()
	)

func _open_world_map() -> void:
	if not can_open_world_map():
		return

	# Deferred: never change the scene tree inside a Button callback.
	_transitioning = true
	_status.text = "World map openen..."
	call_deferred("_perform_world_map_open")


func _perform_world_map_open() -> void:
	var next: Node = SceneManager.change_game_scene(
		WorldMapData.WORLD_MAP_SCENE
	)

	if next == null:
		_transitioning = false
		_status.text = "World map openen mislukt. Controleer Output."

func _sub_screen_open() -> bool:
	return (
		(_shop_screen != null and _shop_screen.is_open())
		or (_tavern_screen != null and _tavern_screen.is_open())
	)


func _on_tavern_talk_requested(definition: DialogueDefinition) -> void:
	if (
		_transitioning
		or not can_process()
		or _tavern_screen == null
		or not _tavern_screen.is_open()
	):
		return

	var main: Node = get_tree().current_scene

	if main == null or not main.has_method("request_dialogue"):
		push_warning("Tavern Talk requires Main.")
		return

	if not bool(main.call(
		"request_dialogue",
		self,
		definition
	)):
		push_warning("Tavern Talk kon niet starten.")
