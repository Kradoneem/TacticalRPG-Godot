class_name CombatCommandPrompt

extends CanvasLayer

## Command menu shown only during the protagonist's turn.
## It uses Godot Control focus, so WASD, arrow keys, Enter and
## Space work automatically through the global ui_* actions.

signal command_selected(command_id: StringName)

var _overlay: ColorRect
var _unit_label: Label

var _attack_button: Button
var _focused_strike_button: Button

var _is_open: bool = false


func _ready() -> void:
	layer = 10

	_overlay = ColorRect.new()
	_overlay.color = Color(0.03, 0.04, 0.06, 0.86)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var center_container := CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center_container)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560.0, 290.0)
	center_container.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)

	var title_label := Label.new()
	title_label.text = "COMMAND"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	content.add_child(title_label)

	_unit_label = Label.new()
	_unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_unit_label)

	content.add_child(HSeparator.new())

	_attack_button = add_command_button(
		content,
		"Attack",
		"A reliable physical attack.",
		&"basic_attack"
	)

	_focused_strike_button = add_command_button(
		content,
		"Focused Strike",
		"A stronger weapon technique. MP cost: 0.",
		&"focused_strike"
	)

	configure_directional_navigation()

	var hint_label := Label.new()
	hint_label.text = "Navigate: WASD or arrow keys   •   Confirm: Enter or Space"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.modulate = Color("#b8c1cb")
	content.add_child(hint_label)

	_overlay.hide()


func open_for_unit(unit: Unit) -> void:
	if unit == null:
		return

	_unit_label.text = "%s's turn — HP %d/%d | MP %d/%d" % [
		unit.display_name,
		unit.hp,
		unit.max_hp,
		unit.mp,
		unit.max_mp
	]

	_focused_strike_button.disabled = not unit.knows_skill(
		&"focused_strike"
	)

	_is_open = true
	_overlay.show()
	call_deferred("_focus_first_available_command")


func _focus_first_available_command() -> void:
	if not _attack_button.disabled:
		_attack_button.grab_focus()
		return

	if not _focused_strike_button.disabled:
		_focused_strike_button.grab_focus()


func add_command_button(
	parent: VBoxContainer,
	title: String,
	description: String,
	command_id: StringName
) -> Button:
	var button := Button.new()

	button.text = "%s\n%s" % [title, description]
	button.custom_minimum_size = Vector2(0.0, 68.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL

	button.add_theme_stylebox_override(
		"normal",
		create_button_style(
			Color("#27323a"),
			Color("#61707a"),
			2
		)
	)

	button.add_theme_stylebox_override(
		"hover",
		create_button_style(
			Color("#344751"),
			Color("#9fb7c2"),
			2
		)
	)

	button.add_theme_stylebox_override(
		"focus",
		create_button_style(
			Color("#5a5128"),
			Color("#ffe183"),
			4
		)
	)

	button.add_theme_stylebox_override(
		"pressed",
		create_button_style(
			Color("#75652e"),
			Color("#fff1ae"),
			4
		)
	)

	button.pressed.connect(_choose_command.bind(command_id))
	parent.add_child(button)

	return button


func configure_directional_navigation() -> void:
	_attack_button.focus_neighbor_top = _attack_button.get_path_to(
		_focused_strike_button
	)

	_attack_button.focus_neighbor_bottom = _attack_button.get_path_to(
		_focused_strike_button
	)

	_attack_button.focus_neighbor_left = _attack_button.get_path_to(
		_focused_strike_button
	)

	_attack_button.focus_neighbor_right = _attack_button.get_path_to(
		_focused_strike_button
	)

	_focused_strike_button.focus_neighbor_top = _focused_strike_button.get_path_to(
		_attack_button
	)

	_focused_strike_button.focus_neighbor_bottom = _focused_strike_button.get_path_to(
		_attack_button
	)

	_focused_strike_button.focus_neighbor_left = _focused_strike_button.get_path_to(
		_attack_button
	)

	_focused_strike_button.focus_neighbor_right = _focused_strike_button.get_path_to(
		_attack_button
	)


func create_button_style(
	background_color: Color,
	border_color: Color,
	border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)

	return style


func _choose_command(command_id: StringName) -> void:
	if not _is_open:
		return

	_is_open = false
	_overlay.hide()

	command_selected.emit(command_id)
