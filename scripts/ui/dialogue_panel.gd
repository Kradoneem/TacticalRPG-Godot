class_name DialoguePanel
extends CanvasLayer

## Displays a session. Does not advance it or mutate gameplay state.

signal advance_requested
signal choice_requested(choice_id: StringName)
signal cancel_requested

var _overlay: ColorRect
var _speaker_label: Label
var _text_label: Label
var _options: VBoxContainer
var _hint_label: Label

var _buttons: Array[Button] = []
var _choices: Array[DialogueChoice] = []
var _selected_index: int = 0
var _active: bool = false
var _render_frame: int = -1


func _ready() -> void:
	layer = 30

	_overlay = ColorRect.new()
	_overlay.color = Color(0.02, 0.03, 0.04, 0.7)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 180)
	margin.add_theme_constant_override("margin_right", 180)
	margin.add_theme_constant_override("margin_top", 280)
	margin.add_theme_constant_override("margin_bottom", 100)
	_overlay.add_child(margin)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#10171d")
	style.border_color = Color("#71889a")
	style.set_border_width_all(3)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	panel.add_child(content)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 26)
	_speaker_label.modulate = Color("#ffe183")
	content.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 26)
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_text_label)

	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 12)
	content.add_child(_options)

	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_hint_label)

	_overlay.hide()


func show_session(session: DialogueSession) -> void:
	_clear_options()
	_selected_index = 0
	_active = true
	_render_frame = Engine.get_process_frames()
	_overlay.show()

	var line: DialogueLine = session.get_current_line()

	if session.phase == DialogueSession.Phase.CHOICE:
		_speaker_label.text = "Protagonist"
		_text_label.text = "Wat antwoord je?"
		_choices = session.get_choices()

		for index in range(_choices.size()):
			var button := Button.new()
			button.text = _choices[index].text
			button.custom_minimum_size = Vector2(0.0, 66.0)
			button.focus_mode = Control.FOCUS_ALL
			button.pressed.connect(_on_choice_pressed.bind(index))
			_options.add_child(button)
			_buttons.append(button)

		_hint_label.text = (
			"WASD/pijltjes: kiezen | Enter/Spatie: bevestigen"
			+ " | Escape: gesprek annuleren"
		)
		_refresh_selection()
	else:
		_speaker_label.text = line.speaker if line != null else ""
		_text_label.text = line.text if line != null else ""
		_hint_label.text = (
			"Enter/Spatie: verder | Escape: gesprek annuleren"
		)

		var button := Button.new()
		button.text = "Verder"
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_continue_pressed)
		_options.add_child(button)
		_buttons.append(button)


func close_panel() -> void:
	_active = false
	_clear_options()
	_overlay.hide()


func _clear_options() -> void:
	for child: Node in _options.get_children():
		_options.remove_child(child)
		child.queue_free()

	_buttons.clear()
	_choices.clear()


func _refresh_selection() -> void:
	for index in range(_buttons.size()):
		_buttons[index].modulate = (
			Color("#ffe183")
			if index == _selected_index
			else Color.WHITE
		)


func _can_confirm() -> bool:
	# Ignore another confirmation in the frame that created this page.
	return _active and Engine.get_process_frames() > _render_frame


func _on_continue_pressed() -> void:
	if _can_confirm():
		advance_requested.emit()


func _on_choice_pressed(index: int) -> void:
	if not _can_confirm() or index < 0 or index >= _choices.size():
		return

	_selected_index = index
	choice_requested.emit(_choices[index].choice_id)


func _input(event: InputEvent) -> void:
	if not _active:
		return

	if event is InputEventMouse:
		# Buttons and the full-screen overlay handle mouse GUI input.
		return

	if not event is InputEventKey:
		return

	# Consume releases and echoes too, preventing focused Buttons
	# or world input from interpreting the same keyboard event.
	get_viewport().set_input_as_handled()

	if not event.is_pressed() or event.is_echo():
		return

	if event.is_action_pressed("ui_cancel"):
		cancel_requested.emit()
		return

	if not _choices.is_empty():
		var direction: int = 0

		if (
			event.is_action_pressed("move_up")
			or event.is_action_pressed("ui_up")
			or event.is_action_pressed("move_left")
			or event.is_action_pressed("ui_left")
		):
			direction = -1
		elif (
			event.is_action_pressed("move_down")
			or event.is_action_pressed("ui_down")
			or event.is_action_pressed("move_right")
			or event.is_action_pressed("ui_right")
		):
			direction = 1

		if direction != 0:
			_selected_index = posmod(
				_selected_index + direction,
				_choices.size()
			)
			_refresh_selection()
			return

	if (
		event.keycode == KEY_ENTER
		or event.keycode == KEY_KP_ENTER
		or event.keycode == KEY_SPACE
	):
		if _choices.is_empty():
			_on_continue_pressed()
		else:
			_on_choice_pressed(_selected_index)
