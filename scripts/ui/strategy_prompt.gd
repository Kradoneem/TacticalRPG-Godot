class_name StrategyPrompt

extends CanvasLayer

## A quick, encounter-only strategy selection prompt.
## Every option is reachable with mouse, WASD, arrow keys,
## Enter and Space.

signal strategy_selected(strategy_id: StringName)

var _overlay: ColorRect
var _subtitle_label: Label
var _strategy_buttons: Array[Button] = []
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
	panel.custom_minimum_size = Vector2(620.0, 410.0)
	center_container.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)

	var title_label := Label.new()
	title_label.text = "INITIATIVE — QUICK ORDER"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	content.add_child(title_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_subtitle_label)

	content.add_child(HSeparator.new())

	var options_grid := GridContainer.new()
	options_grid.columns = 2
	options_grid.add_theme_constant_override("h_separation", 12)
	options_grid.add_theme_constant_override("v_separation", 12)
	content.add_child(options_grid)

	_strategy_buttons.append(
		add_strategy_button(
			options_grid,
			"1  Aggressive",
			"Fast eliminations.\nHigher risk.",
			&"aggressive"
		)
	)

	_strategy_buttons.append(
		add_strategy_button(
			options_grid,
			"2  Defensive",
			"Protect the squad.\nPreserve condition.",
			&"defensive"
		)
	)

	_strategy_buttons.append(
		add_strategy_button(
			options_grid,
			"3  Focus Target",
			"Prioritise one\ncritical enemy.",
			&"focus_target"
		)
	)

	_strategy_buttons.append(
		add_strategy_button(
			options_grid,
			"4  Support",
			"Prioritise healing,\ncontrol and protection.",
			&"support"
		)
	)

	configure_directional_navigation()

	var hint_label := Label.new()
	hint_label.text = "Navigate: WASD or arrow keys   •   Confirm: Enter or Space"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.modulate = Color("#b8c1cb")
	content.add_child(hint_label)

	_overlay.hide()


func open_for_squad(squad: Squad) -> void:
	if squad == null:
		return

	_subtitle_label.text = (
		"%s takes initiative.\n"
		+ "Choose a strategy for this encounter only."
	) % squad.display_name

	_is_open = true
	_overlay.show()
	call_deferred("_focus_first_option")


func _focus_first_option() -> void:
	if _strategy_buttons.is_empty():
		return

	_strategy_buttons[0].grab_focus()


func add_strategy_button(
	parent: GridContainer,
	title: String,
	description: String,
	strategy_id: StringName
) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [title, description]
	button.custom_minimum_size = Vector2(275.0, 86.0)
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

	button.pressed.connect(_choose_strategy.bind(strategy_id))
	parent.add_child(button)

	return button


func configure_directional_navigation() -> void:
	if _strategy_buttons.size() != 4:
		return

	var aggressive_button := _strategy_buttons[0]
	var defensive_button := _strategy_buttons[1]
	var focus_target_button := _strategy_buttons[2]
	var support_button := _strategy_buttons[3]

	# Top-left: Aggressive
	aggressive_button.focus_neighbor_left = aggressive_button.get_path_to(
		defensive_button
	)
	aggressive_button.focus_neighbor_right = aggressive_button.get_path_to(
		defensive_button
	)
	aggressive_button.focus_neighbor_top = aggressive_button.get_path_to(
		focus_target_button
	)
	aggressive_button.focus_neighbor_bottom = aggressive_button.get_path_to(
		focus_target_button
	)

	# Top-right: Defensive
	defensive_button.focus_neighbor_left = defensive_button.get_path_to(
		aggressive_button
	)
	defensive_button.focus_neighbor_right = defensive_button.get_path_to(
		aggressive_button
	)
	defensive_button.focus_neighbor_top = defensive_button.get_path_to(
		support_button
	)
	defensive_button.focus_neighbor_bottom = defensive_button.get_path_to(
		support_button
	)

	# Bottom-left: Focus Target
	focus_target_button.focus_neighbor_left = focus_target_button.get_path_to(
		support_button
	)
	focus_target_button.focus_neighbor_right = focus_target_button.get_path_to(
		support_button
	)
	focus_target_button.focus_neighbor_top = focus_target_button.get_path_to(
		aggressive_button
	)
	focus_target_button.focus_neighbor_bottom = focus_target_button.get_path_to(
		aggressive_button
	)

	# Bottom-right: Support
	support_button.focus_neighbor_left = support_button.get_path_to(
		focus_target_button
	)
	support_button.focus_neighbor_right = support_button.get_path_to(
		focus_target_button
	)
	support_button.focus_neighbor_top = support_button.get_path_to(
		defensive_button
	)
	support_button.focus_neighbor_bottom = support_button.get_path_to(
		defensive_button
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


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return

	if not event is InputEventKey:
		return

	if not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_1:
			_choose_strategy(&"aggressive")
		KEY_2:
			_choose_strategy(&"defensive")
		KEY_3:
			_choose_strategy(&"focus_target")
		KEY_4:
			_choose_strategy(&"support")
		_:
			return

	get_viewport().set_input_as_handled()


func _choose_strategy(strategy_id: StringName) -> void:
	if not _is_open:
		return

	_is_open = false
	_overlay.hide()
	strategy_selected.emit(strategy_id)
