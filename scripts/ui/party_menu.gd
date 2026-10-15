class_name PartyMenu

extends CanvasLayer

## Read-only party inspection overlay.
## TacticalTest decides when opening is permitted.
## This menu reads shared Unit references from GameState and never owns copies.

signal closed

var _overlay: ColorRect
var _party_list: VBoxContainer
var _detail_label: Label
var _ability_list: VBoxContainer
var _member_buttons: Array[Button] = []
var _party_members: Array[Unit] = []
var _selected_member_index: int = 0
var _is_open: bool = false


func _ready() -> void:
	layer = 20

	_overlay = ColorRect.new()
	_overlay.color = Color(0.03, 0.04, 0.06, 0.9)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var outer_margin := MarginContainer.new()
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 110)
	outer_margin.add_theme_constant_override("margin_top", 80)
	outer_margin.add_theme_constant_override("margin_right", 110)
	outer_margin.add_theme_constant_override("margin_bottom", 80)
	_overlay.add_child(outer_margin)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_create_panel_style()
	)
	outer_margin.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	panel.add_child(content)

	var title_label := Label.new()
	title_label.text = "PARTY"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	content.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.text = "Inspect the Main Squad outside alert.\nSelect a member with WASD or arrow keys."
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.modulate = Color("#b8c1cb")
	content.add_child(subtitle_label)

	content.add_child(HSeparator.new())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	content.add_child(body)

	_party_list = VBoxContainer.new()
	_party_list.custom_minimum_size = Vector2(340.0, 0.0)
	_party_list.add_theme_constant_override("separation", 10)
	body.add_child(_party_list)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 12)
	body.add_child(details)

	_detail_label = Label.new()
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.add_theme_font_size_override("font_size", 20)
	details.add_child(_detail_label)

	var abilities_title := Label.new()
	abilities_title.text = "KNOWN ABILITIES"
	abilities_title.add_theme_font_size_override("font_size", 18)
	abilities_title.modulate = Color("#ffe183")
	details.add_child(abilities_title)

	_ability_list = VBoxContainer.new()
	_ability_list.add_theme_constant_override("separation", 8)
	details.add_child(_ability_list)

	content.add_child(HSeparator.new())

	var hint_label := Label.new()
	hint_label.text = "Navigate: WASD or arrow keys   •   Close: Escape"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.modulate = Color("#b8c1cb")
	content.add_child(hint_label)

	_overlay.hide()


func open_for_party(party_members: Array) -> void:
	_party_members.clear()

	for party_member in party_members:
		if party_member is Unit:
			_party_members.append(party_member)

	if _party_members.is_empty():
		return

	_selected_member_index = 0
	_is_open = true
	_overlay.show()

	_rebuild_member_list()
	_refresh_selected_member()
	call_deferred("_focus_selected_member")


func is_open() -> bool:
	return _is_open


func close() -> void:
	if not _is_open:
		return

	_is_open = false
	_overlay.hide()
	closed.emit()


func _rebuild_member_list() -> void:
	for member_button in _member_buttons:
		member_button.queue_free()

	_member_buttons.clear()

	for party_member: Unit in _party_members:
		var member_button := Button.new()
		member_button.custom_minimum_size = Vector2(0.0, 78.0)
		member_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		member_button.focus_mode = Control.FOCUS_ALL
		member_button.pressed.connect(
			_select_member.bind(_member_buttons.size())
		)

		_party_list.add_child(member_button)
		_member_buttons.append(member_button)

	_refresh_member_button_texts()
	_configure_member_navigation()


func _refresh_member_button_texts() -> void:
	for member_index in range(_member_buttons.size()):
		var member_button := _member_buttons[member_index]
		var party_member := _party_members[member_index]
		var selection_marker := "▶ " if member_index == _selected_member_index else "  "

		member_button.text = "%s%s\nLv.%d  HP %d/%d  MP %d/%d" % [
			selection_marker,
			party_member.display_name,
			party_member.level,
			party_member.hp,
			party_member.max_hp,
			party_member.mp,
			party_member.max_mp
		]

		if member_index == _selected_member_index:
			member_button.add_theme_stylebox_override(
				"normal",
				_create_button_style(
					Color("#5a5128"),
					Color("#ffe183"),
					4
				)
			)
		else:
			member_button.add_theme_stylebox_override(
				"normal",
				_create_button_style(
					Color("#27323a"),
					Color("#61707a"),
					2
				)
			)


func _refresh_selected_member() -> void:
	if _party_members.is_empty():
		return

	_selected_member_index = clampi(
		_selected_member_index,
		0,
		_party_members.size() - 1
	)

	var party_member := _party_members[_selected_member_index]

	_detail_label.text = "%s\n\nLevel %d\n\nHP  %d / %d\nMP  %d / %d\n\nAttack  %d\nDefense %d\nSpeed   %d\nWisdom  %d" % [
		party_member.display_name,
		party_member.level,
		party_member.hp,
		party_member.max_hp,
		party_member.mp,
		party_member.max_mp,
		party_member.attack,
		party_member.defense,
		party_member.speed,
		party_member.wisdom
	]

	_refresh_member_button_texts()
	_refresh_ability_list(party_member)


func _refresh_ability_list(party_member: Unit) -> void:
	for ability_entry in _ability_list.get_children():
		ability_entry.queue_free()

	var learned_ability_ids := party_member.get_all_learned_ability_ids()

	if learned_ability_ids.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No known abilities."
		empty_label.modulate = Color("#b8c1cb")
		_ability_list.add_child(empty_label)
		return

	for ability_id: StringName in learned_ability_ids:
		var ability := SkillData.get_skill(ability_id)

		if ability == null:
			continue

		var ability_label := Label.new()
		var category_text := "Spell" if ability.is_spell() else "Skill"
		var mp_cost_text := "MP %d" % ability.mp_cost

		ability_label.text = "%s — %s (%s)\n%s" % [
			ability.display_name,
			category_text,
			mp_cost_text,
			ability.description
		]
		ability_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ability_label.modulate = Color("#d8e1e8")
		_ability_list.add_child(ability_label)


func _select_member(member_index: int) -> void:
	if member_index < 0 or member_index >= _party_members.size():
		return

	_selected_member_index = member_index
	_refresh_selected_member()
	_focus_selected_member()


func _focus_selected_member() -> void:
	if _member_buttons.is_empty():
		return

	_member_buttons[_selected_member_index].grab_focus()


func _move_selection(direction: int) -> void:
	if _party_members.is_empty():
		return

	_selected_member_index = posmod(
		_selected_member_index + direction,
		_party_members.size()
	)

	_refresh_selected_member()
	_focus_selected_member()


func _configure_member_navigation() -> void:
	if _member_buttons.is_empty():
		return

	for member_index in range(_member_buttons.size()):
		var current_button := _member_buttons[member_index]
		var previous_index := posmod(
			member_index - 1,
			_member_buttons.size()
		)
		var next_index := posmod(
			member_index + 1,
			_member_buttons.size()
		)

		current_button.focus_neighbor_top = current_button.get_path_to(
			_member_buttons[previous_index]
		)
		current_button.focus_neighbor_bottom = current_button.get_path_to(
			_member_buttons[next_index]
		)
		current_button.focus_neighbor_left = current_button.get_path_to(
			_member_buttons[previous_index]
		)
		current_button.focus_neighbor_right = current_button.get_path_to(
			_member_buttons[next_index]
		)


func _create_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color("#10171d")
	style.border_color = Color("#71889a")
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 28.0
	style.content_margin_top = 24.0
	style.content_margin_right = 28.0
	style.content_margin_bottom = 24.0

	return style


func _create_button_style(
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

	if not event.is_pressed() or event.is_echo():
		return

	if event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("move_up"):
		_move_selection(-1)
	elif event.is_action_pressed("move_down"):
		_move_selection(1)
	elif event.is_action_pressed("move_left"):
		_move_selection(-1)
	elif event.is_action_pressed("move_right"):
		_move_selection(1)
	else:
		return

	get_viewport().set_input_as_handled()
