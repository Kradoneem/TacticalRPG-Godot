class_name TacticalActionPrompt

extends CanvasLayer

signal attack_selected(enemy_marker: TacticalEnemy)
signal cancelled

var _overlay: ColorRect
var _content: VBoxContainer
var _is_open: bool = false
var _target_buttons: Array[Button] = []


func _ready() -> void:
	layer = 11

	_overlay = ColorRect.new()
	_overlay.color = Color(0.03, 0.04, 0.06, 0.86)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var center_container := CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center_container)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560.0, 280.0)
	center_container.add_child(panel)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 14)
	panel.add_child(_content)

	_overlay.hide()


func open_for_targets(targets: Array[TacticalEnemy]) -> void:
	if targets.is_empty():
		return

	_clear_target_buttons()

	var title_label := Label.new()
	title_label.text = "TACTICAL ACTION"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	_content.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.text = "Choose an adjacent enemy squad to attack."
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(subtitle_label)

	_content.add_child(HSeparator.new())

	for enemy_marker: TacticalEnemy in targets:
		var button := Button.new()
		button.text = "Attack  —  %s" % enemy_marker.squad.display_name
		button.custom_minimum_size = Vector2(460.0, 58.0)
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_select_attack_target.bind(enemy_marker))
		_content.add_child(button)
		_target_buttons.append(button)

	var hint_label := Label.new()
	hint_label.text = "Navigate: WASD or arrow keys   •   Confirm: Enter or Space"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.modulate = Color("#b8c1cb")
	_content.add_child(hint_label)

	_is_open = true
	_overlay.show()
	call_deferred("_focus_first_target")

func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return

	if not event.is_action_pressed("ui_cancel"):
		return

	_is_open = false
	_overlay.hide()

	cancelled.emit()
	get_viewport().set_input_as_handled()

func _focus_first_target() -> void:
	if _target_buttons.is_empty():
		return

	_target_buttons[0].grab_focus()


func _clear_target_buttons() -> void:
	for child: Node in _content.get_children():
		child.queue_free()

	_target_buttons.clear()


func _select_attack_target(enemy_marker: TacticalEnemy) -> void:
	if not _is_open:
		return

	_is_open = false
	_overlay.hide()
	attack_selected.emit(enemy_marker)
