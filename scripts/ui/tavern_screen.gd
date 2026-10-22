class_name TavernScreen
extends Control

signal closed
signal talk_requested(definition: DialogueDefinition)
signal dialogue_result(
	person_id: StringName,
	choice_id: StringName,
	committed: bool
)

var _tavern: TavernDefinition
var _selected_index: int = 0
var _page_frame: int = -1

var _background: TextureRect
var _persons_layer: Control
var _heading: Label
var _status: Label
var _back_button: Button

var _person_buttons: Array[Button] = []
var _buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_screen()
	resized.connect(_update_layout)
	hide()


func _build_screen() -> void:
	var color := ColorRect.new()
	color.color = Color("#302821")
	color.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(color)

	_background = TextureRect.new()
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_SCALE
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	var header := VBoxContainer.new()
	header.position = Vector2(24.0, 20.0)
	header.custom_minimum_size = Vector2(900.0, 100.0)
	add_child(header)

	_heading = Label.new()
	_heading.add_theme_font_size_override("font_size", 28)
	header.add_child(_heading)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_status)

	_persons_layer = Control.new()
	_persons_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_persons_layer)

	_back_button = Button.new()
	_back_button.text = "Back to city"
	_back_button.custom_minimum_size = Vector2(260.0, 56.0)
	_back_button.focus_mode = Control.FOCUS_NONE
	_back_button.pressed.connect(_close)
	add_child(_back_button)


func open_tavern(tavern: TavernDefinition) -> bool:
	if not is_node_ready() or is_open():
		return false

	if tavern == null:
		return false

	var problem: String = tavern.validation_error()

	if not problem.is_empty():
		push_warning(problem)
		return false

	_tavern = tavern
	_selected_index = 0
	_page_frame = Engine.get_process_frames()

	_person_buttons.clear()
	_buttons.clear()

	for child: Node in _persons_layer.get_children():
		_persons_layer.remove_child(child)
		child.queue_free()

	for person: TavernPerson in _tavern.persons:
		var button := Button.new()
		button.text = person.display_name
		button.custom_minimum_size = Vector2(260.0, 56.0)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_talk_to_person.bind(person.person_id))

		_persons_layer.add_child(button)
		_person_buttons.append(button)
		_buttons.append(button)

	_buttons.append(_back_button)
	_background.texture = _tavern.background
	_heading.text = _tavern.display_name

	_status.text = (
		"WASD/pijltjes: persoon selecteren | Enter/Spatie: praten "
		+ "| Escape: Party"
	)

	if _tavern.background == null:
		_status.text += "\nPROTOTYPE — tavern-interieur ontbreekt."

	show()
	_update_layout()
	call_deferred("_update_layout")
	_refresh_selection()

	return true


func is_open() -> bool:
	return visible and _tavern != null


func _close() -> void:
	if not is_open() or not can_process():
		return

	hide()
	_tavern = null
	closed.emit()


func _update_layout() -> void:
	if _tavern == null or _background == null:
		return

	var image_rect: Rect2 = CityLayoutData.get_image_rect(
		size,
		_tavern.background
	)

	_background.position = image_rect.position
	_background.size = image_rect.size
	_persons_layer.position = image_rect.position
	_persons_layer.size = image_rect.size

	for index in range(_person_buttons.size()):
		var button: Button = _person_buttons[index]
		var button_size: Vector2 = button.get_combined_minimum_size()

		button.size = button_size
		button.position = (
			_tavern.persons[index].position_ratio * image_rect.size
			- button_size * 0.5
		)

	var back_size: Vector2 = _back_button.get_combined_minimum_size()
	_back_button.size = back_size
	_back_button.position = Vector2(
		(size.x - back_size.x) * 0.5,
		maxf(0.0, size.y - back_size.y - 24.0)
	)


func _refresh_selection() -> void:
	for index in range(_buttons.size()):
		_buttons[index].modulate = (
			Color("#ffe183")
			if index == _selected_index
			else Color.WHITE
		)


func _move_selection(direction: int) -> void:
	if _buttons.is_empty():
		return

	_selected_index = posmod(
		_selected_index + direction,
		_buttons.size()
	)
	_refresh_selection()


func _confirm_selection() -> void:
	if Engine.get_process_frames() <= _page_frame:
		return

	if _selected_index < 0 or _selected_index >= _buttons.size():
		return

	_buttons[_selected_index].pressed.emit()


func handle_menu_input(event: InputEvent) -> void:
	if not is_open() or not can_process() or not event is InputEventKey:
		return

	# Escape belongs to the central PartyMenuController.
	if event.is_action("ui_cancel"):
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
		_confirm_selection()


func _talk_to_person(person_id: StringName) -> void:
	if not is_open() or not can_process():
		return

	var person: TavernPerson = _tavern.get_person(person_id)

	if person == null:
		return

	# Mouse selection also becomes the persistent keyboard selection.
	_selected_index = _tavern.persons.find(person)
	_refresh_selection()

	talk_requested.emit(person.dialogue)


func on_dialogue_finished(
	dialogue_id: StringName,
	choice_id: StringName,
	committed: bool
) -> void:
	if not is_open():
		return

	for person: TavernPerson in _tavern.persons:
		if person.dialogue.dialogue_id != dialogue_id:
			continue

		# The final confirm must not immediately start another conversation.
		_page_frame = Engine.get_process_frames()

		# Gameplay effects do not belong in the tavern UI.
		dialogue_result.emit(person.person_id, choice_id, committed)
		return
