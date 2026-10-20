class_name QuestLogPanel
extends Control

## Read-only Quest Log inside PartyMenu.
## Parent delegates keyboard input to preserve menu input isolation.

signal closed

var _quest_ids: Array[String] = []
var _selected_index: int = 0
var _list: VBoxContainer
var _details: Label
var _buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var background := ColorRect.new()
	background.color = Color("#10171d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 110)
	margin.add_theme_constant_override("margin_right", 110)
	margin.add_theme_constant_override("margin_top", 80)
	margin.add_theme_constant_override("margin_bottom", 80)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 20)
	margin.add_child(page)

	var title := Label.new()
	title.text = "QUEST LOG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	page.add_child(title)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 28)
	page.add_child(body)

	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(460, 0)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(list_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	list_scroll.add_child(_list)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(detail_scroll)

	_details = Label.new()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_theme_font_size_override("font_size", 22)
	detail_scroll.add_child(_details)

	var back := Button.new()
	back.text = "Back — Escape"
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(0, 48)
	back.pressed.connect(_close)
	page.add_child(back)

	GameState.quest_log_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	var previous_id: String = ""

	if _selected_index >= 0 and _selected_index < _quest_ids.size():
		previous_id = _quest_ids[_selected_index]

	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	_buttons.clear()
	_quest_ids = GameState.get_quest_log_ids()
	_selected_index = maxi(0, _quest_ids.find(previous_id))

	for index in range(_quest_ids.size()):
		var quest: QuestDefinition = QuestData.get_quest(_quest_ids[index])
		var button := Button.new()
		button.text = quest.title
		button.custom_minimum_size = Vector2(420, 64)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_select.bind(index))
		_list.add_child(button)
		_buttons.append(button)

	_refresh_details()


func _select(index: int) -> void:
	if index < 0 or index >= _quest_ids.size():
		return

	_selected_index = index
	_refresh_details()


func _refresh_details() -> void:
	if _quest_ids.is_empty():
		_details.text = "No quests in your log."
		return

	var quest_id: String = _quest_ids[_selected_index]
	var quest: QuestDefinition = QuestData.get_quest(quest_id)
	var status: String = GameState.get_quest_status(quest_id)

	var lines: Array[String] = [
		quest.title,
		"",
		quest.description,
		"",
		"Quest status: " + status,
		"",
		"OBJECTIVES"
	]

	for objective: QuestObjective in quest.objectives:
		var achieved: bool = GameState.is_quest_objective_achieved(
			quest_id, objective.objective_id
		)
		lines.append(
			"%s %s" % [
				"[DONE]" if achieved else "[OPEN]",
				objective.description
			]
		)

	if status == "active" and GameState.are_quest_objectives_achieved(quest_id):
		lines.append("")
		lines.append(
			"All objectives achieved. Quest completion is a separate step."
		)

	_details.text = "\n".join(lines)

	for index in range(_buttons.size()):
		_buttons[index].modulate = (
			Color("#ffe183")
			if index == _selected_index
			else Color.WHITE
		)


func handle_input(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false

	if not event.is_pressed() or event.is_echo():
		return true

	if event.is_action_pressed("ui_cancel"):
		_close()
		return true

	if _quest_ids.is_empty():
		return true

	if (
		event.is_action_pressed("move_up")
		or event.is_action_pressed("ui_up")
		or event.is_action_pressed("move_left")
		or event.is_action_pressed("ui_left")
	):
		_select(posmod(_selected_index - 1, _quest_ids.size()))

	elif (
		event.is_action_pressed("move_down")
		or event.is_action_pressed("ui_down")
		or event.is_action_pressed("move_right")
		or event.is_action_pressed("ui_right")
	):
		_select(posmod(_selected_index + 1, _quest_ids.size()))

	return true


func _close() -> void:
	closed.emit()
