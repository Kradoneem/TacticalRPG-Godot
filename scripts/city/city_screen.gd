class_name CityScreen
extends Control

@export var city_background: Texture2D

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


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	GameState.current_city = CityData.CITY_NAME
	GameState.current_location = GameState.current_city
	GameState.in_city = true

	_build_screen()
	_show_city()


func _build_screen() -> void:
	var background_color := ColorRect.new()
	background_color.color = Color("#26343a")
	background_color.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	background_color.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_color)

	if city_background != null:
		var background := TextureRect.new()
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		background.texture = city_background
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(background)

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
	_locations_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_locations_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_locations_layer)

	for destination: CityDestination in CityData.get_destinations():
		var button := Button.new()
		button.text = destination.display_name
		button.custom_minimum_size = Vector2(230.0, 56.0)

		button.anchor_left = destination.position_ratio.x
		button.anchor_right = destination.position_ratio.x
		button.anchor_top = destination.position_ratio.y
		button.anchor_bottom = destination.position_ratio.y
		button.offset_left = -115.0
		button.offset_right = 115.0
		button.offset_top = -28.0
		button.offset_bottom = 28.0

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


func _show_city() -> void:
	_viewing_guild = false
	_selected_index = 0
	_page_frame = Engine.get_process_frames()

	_guild_panel.hide()
	_locations_layer.show()

	_title.text = "%s — City" % GameState.current_city
	_status.text = (
		"WASD/pijltjes: selecteren | Enter/Spatie: openen | Escape: Party\n"
		+ "Shop, Tavern, Castle en Home zijn nog niet geïmplementeerd."
	)

	if city_background == null:
		_status.text += "\nCity-background ontbreekt: layout-placeholder."

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
	if not event is InputEventKey:
		return

	# Escape remains available to the central PartyMenuController.
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
	if _transitioning:
		return

	var destination: CityDestination = CityData.get_destination(
		destination_id
	)

	if destination == null:
		return

	match destination.kind:
		CityDestination.Kind.GUILD:
			_show_guild()

		CityDestination.Kind.SEWERS:
			_enter_sewers()

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
	return not _transitioning and not _viewing_guild and can_process()


func can_open_party_menu() -> bool:
	return not _transitioning


func can_show_quest_updates() -> bool:
	return not _transitioning


func on_returned_from_exploration() -> void:
	_transitioning = false
	GameState.current_city = CityData.CITY_NAME
	GameState.current_location = GameState.current_city
	GameState.in_city = true
	_show_city()
