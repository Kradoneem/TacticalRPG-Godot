class_name PartyMenu

extends CanvasLayer

## Read-only party navigation overlay.
##
## TacticalTest decides when opening is permitted. This menu reads existing
## Squad and Unit references from GameState and never creates gameplay copies.

signal closed

enum Screen {
	ROOT,
	STATUS_SQUAD_SELECTION,
	STATUS_MEMBER_INSPECTION,
	ITEM_SELECTION,
	ITEM_SQUAD_SELECTION,
	ITEM_TARGET_SELECTION,
	EQUIPMENT_SQUAD_SELECTION,
	EQUIPMENT_MEMBER_SELECTION,
	EQUIPMENT_SLOT_SELECTION,
	EQUIPMENT_CHOICE,
	PLACEHOLDER
}

var _overlay: ColorRect
var _subtitle_label: Label
var _navigation_list: VBoxContainer
var _detail_column: VBoxContainer
var _hint_label: Label

var _navigation_buttons: Array[Button] = []
var _available_squads: Array[Squad] = []
var _current_squad: Squad
var _selected_navigation_index: int = 0
var _screen: Screen = Screen.ROOT
var _is_open: bool = false

var _available_item_ids: Array[StringName] = []
var _selected_item_id: StringName = &""
var _item_targets: Array[Unit] = []
var _equipment_squad: Squad
var _equipment_unit: Unit
var _equipment_slot: StringName = &""
var _equipment_choices: Array[StringName] = []

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

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.modulate = Color("#b8c1cb")
	content.add_child(_subtitle_label)

	content.add_child(HSeparator.new())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	content.add_child(body)

	_navigation_list = VBoxContainer.new()
	_navigation_list.custom_minimum_size = Vector2(360.0, 0.0)
	_navigation_list.add_theme_constant_override("separation", 10)
	body.add_child(_navigation_list)

	_detail_column = VBoxContainer.new()
	_detail_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_column.add_theme_constant_override("separation", 12)
	body.add_child(_detail_column)

	content.add_child(HSeparator.new())

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.modulate = Color("#b8c1cb")
	content.add_child(_hint_label)

	_overlay.hide()


func open_for_squads(squads: Array) -> void:
	_available_squads.clear()

	for squad in squads:
		if not squad is Squad:
			continue

		if squad.autonomy_mode == Squad.AutonomyMode.ENEMY:
			continue

		_available_squads.append(squad)

	if _available_squads.is_empty():
		return

	_current_squad = null
	_is_open = true
	_overlay.show()
	_show_root()


func is_open() -> bool:
	return _is_open


func close() -> void:
	if not _is_open:
		return

	_is_open = false
	_current_squad = null
	_overlay.hide()
	closed.emit()

func _show_root() -> void:
	_screen = Screen.ROOT
	_selected_navigation_index = 0
	_selected_item_id = &""
	_available_item_ids.clear()
	_item_targets.clear()

	_equipment_squad = null
	_equipment_unit = null
	_equipment_slot = &""
	_equipment_choices.clear()

	_set_subtitle("Review status, manage equipment or use recovery items.")
	_set_hint(
		"Navigate: WASD or arrow keys"
		+ "   •   Confirm: Enter or Space"
		+ "   •   Close: Escape"
	)

	_clear_navigation()
	_clear_details()

	_add_navigation_button(
		"Status",
		"Inspect squad condition, members and known abilities."
	)
	_add_navigation_button(
		"Equipment",
		"Equip, replace or remove gear."
	)
	_add_navigation_button(
		"Items",
		"Use recovery items on individual living squad members."
	)
	_add_navigation_button(
		"Formation",
		"Organise units between player squads."
	)

	var overview_template: String = (
		"%d player squad(s) are currently available.\n\n"
		+ "Status, Equipment and single-target recovery items "
		+ "are available.\n\nFormation remains a placeholder."
	)

	_add_detail_heading("PARTY OVERVIEW")
	_add_detail_text(overview_template % _available_squads.size())

	_refresh_navigation_selection()
	call_deferred("_focus_selected_navigation_button")

func _show_status_squad_selection() -> void:
	_screen = Screen.STATUS_SQUAD_SELECTION
	_selected_navigation_index = 0

	_set_subtitle(
		"Select a squad to inspect its members and persistent condition."
	)
	_set_hint("Navigate: WASD or arrow keys   •   Confirm: Enter or Space   •   Back: Escape")

	_clear_navigation()
	_clear_details()

	for squad: Squad in _available_squads:
		_add_navigation_button(
			squad.display_name,
			"%d/%d members  •  Strategy: %s" % [
				squad.members.size(),
				Squad.MAX_MEMBERS,
				squad.default_strategy
			]
		)

	_add_detail_heading("SELECT A SQUAD")
	_add_detail_text(
		"Every tactical token represents exactly one Squad.\n\n"
		+ "Squads remain separate. This menu only reads their shared "
		+ "Unit references; it does not create alternate party copies."
	)

	_refresh_navigation_selection()
	call_deferred("_focus_selected_navigation_button")


func _show_status_member_inspection(squad: Squad) -> void:
	if squad == null:
		return

	_current_squad = squad
	_screen = Screen.STATUS_MEMBER_INSPECTION
	_selected_navigation_index = 0

	_set_subtitle(
		"%s — inspect condition, combat stats and known abilities."
		% _current_squad.display_name
	)
	_set_hint("Navigate: WASD or arrow keys   •   Back: Escape")

	_clear_navigation()
	_clear_details()

	for member: Unit in _current_squad.members:
		_add_navigation_button(
			member.display_name,
			"Lv.%d  •  HP %d/%d  •  MP %d/%d" % [
				member.level,
				member.hp,
				member.max_hp,
				member.mp,
				member.max_mp
			]
		)

	if _current_squad.members.is_empty():
		_add_detail_heading("EMPTY SQUAD")
		_add_detail_text("This squad currently has no members.")
	else:
		_refresh_member_details()

	_refresh_navigation_selection()
	call_deferred("_focus_selected_navigation_button")


func _show_placeholder(
	section_title: String,
	section_description: String
) -> void:
	_screen = Screen.PLACEHOLDER
	_selected_navigation_index = 0

	_set_subtitle(section_title)
	_set_hint("Back: Escape")

	_clear_navigation()
	_clear_details()

	_add_detail_heading(section_title)
	_add_detail_text(section_description)

func _activate_selected_option() -> void:
	match _screen:
		Screen.ROOT:
			match _selected_navigation_index:
				0:
					_show_status_squad_selection()
				1:
					_show_equipment_screen(
						Screen.EQUIPMENT_SQUAD_SELECTION
					)
				2:
					_show_item_selection()
				3:
					_show_placeholder(
						"FORMATION",
						"Formation management is not available yet.\n\n"
						+ "It will later move existing Unit references "
						+ "between existing player Squads. It will never "
						+ "merge tactical squad tokens."
					)

		Screen.STATUS_SQUAD_SELECTION:
			if _selected_navigation_index < _available_squads.size():
				_show_status_member_inspection(
					_available_squads[_selected_navigation_index]
				)

		Screen.STATUS_MEMBER_INSPECTION:
			_refresh_member_details()

		Screen.ITEM_SELECTION:
			if (
				_selected_navigation_index >= 0
				and _selected_navigation_index < _available_item_ids.size()
			):
				_selected_item_id = _available_item_ids[
					_selected_navigation_index
				]
				_show_item_squad_selection()

		Screen.ITEM_SQUAD_SELECTION:
			if (
				_selected_navigation_index >= 0
				and _selected_navigation_index < _available_squads.size()
			):
				_show_item_target_selection(
					_available_squads[_selected_navigation_index]
				)

		Screen.ITEM_TARGET_SELECTION:
			_use_selected_item()

		Screen.EQUIPMENT_SQUAD_SELECTION, \
		Screen.EQUIPMENT_MEMBER_SELECTION, \
		Screen.EQUIPMENT_SLOT_SELECTION, \
		Screen.EQUIPMENT_CHOICE:
			_activate_equipment_option()

func _move_navigation_selection(direction: int) -> void:
	if _navigation_buttons.is_empty():
		return

	_selected_navigation_index = posmod(
		_selected_navigation_index + direction,
		_navigation_buttons.size()
	)

	_refresh_navigation_selection()

	if _screen == Screen.STATUS_MEMBER_INSPECTION:
		_refresh_member_details()
	elif _screen == Screen.ITEM_TARGET_SELECTION:
		_refresh_item_target_details()

	_focus_selected_navigation_button()

func _handle_back() -> void:
	match _screen:
		Screen.ROOT:
			close()

		Screen.STATUS_SQUAD_SELECTION:
			_show_root()

		Screen.STATUS_MEMBER_INSPECTION:
			_show_status_squad_selection()

		Screen.ITEM_SELECTION:
			_show_root()

		Screen.ITEM_SQUAD_SELECTION:
			_show_item_selection()

		Screen.ITEM_TARGET_SELECTION:
			_show_item_squad_selection()

		Screen.EQUIPMENT_SQUAD_SELECTION:
			_show_root()

		Screen.EQUIPMENT_MEMBER_SELECTION:
			_show_equipment_screen(Screen.EQUIPMENT_SQUAD_SELECTION)

		Screen.EQUIPMENT_SLOT_SELECTION:
			_show_equipment_screen(Screen.EQUIPMENT_MEMBER_SELECTION)

		Screen.EQUIPMENT_CHOICE:
			_show_equipment_screen(Screen.EQUIPMENT_SLOT_SELECTION)

		Screen.PLACEHOLDER:
			_show_root()

func _refresh_member_details() -> void:
	if _current_squad == null:
		return

	if (
		_selected_navigation_index < 0
		or _selected_navigation_index >= _current_squad.members.size()
	):
		return

	var member: Unit = _current_squad.members[
		_selected_navigation_index
	]

	_clear_details()
	_add_detail_heading(member.display_name)

	var stats_template: String = (
		"Level %d\n\n"
		+ "HP  %d / %d\n"
		+ "MP  %d / %d\n\n"
		+ "Attack   %d\n"
		+ "Defense  %d\n"
		+ "Speed    %d\n"
		+ "Wisdom   %d"
	)

	_add_detail_text(
		stats_template % [
			member.level,
			member.hp,
			member.max_hp,
			member.mp,
			member.max_mp,
			member.attack,
			member.defense,
			member.speed,
			member.wisdom
		]
	)

	var ability_heading := Label.new()
	ability_heading.text = "KNOWN ABILITIES"
	ability_heading.add_theme_font_size_override("font_size", 18)
	ability_heading.modulate = Color("#ffe183")
	_detail_column.add_child(ability_heading)

	var learned_ability_ids := member.get_all_learned_ability_ids()

	if learned_ability_ids.is_empty():
		_add_detail_text("No known abilities.")
		return

	for ability_id: StringName in learned_ability_ids:
		var ability := SkillData.get_skill(ability_id)

		if ability == null:
			continue

		var category_text := "Spell" if ability.is_spell() else "Skill"

		_add_detail_text(
			"%s — %s (MP %d)\n%s" % [
				ability.display_name,
				category_text,
				ability.mp_cost,
				ability.description
			]
		)

func _set_subtitle(new_text: String) -> void:
	_subtitle_label.text = new_text


func _set_hint(new_text: String) -> void:
	_hint_label.text = new_text


func _clear_navigation() -> void:
	for navigation_button in _navigation_buttons:
		navigation_button.queue_free()

	_navigation_buttons.clear()


func _clear_details() -> void:
	for detail_child in _detail_column.get_children():
		detail_child.queue_free()


func _add_navigation_button(
	title: String,
	description: String
) -> void:
	var button_index := _navigation_buttons.size()
	var button := Button.new()

	button.text = "%s\n%s" % [title, description]
	button.custom_minimum_size = Vector2(0.0, 82.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(_on_navigation_button_pressed.bind(button_index))

	_navigation_list.add_child(button)
	_navigation_buttons.append(button)


func _on_navigation_button_pressed(button_index: int) -> void:
	if button_index < 0 or button_index >= _navigation_buttons.size():
		return

	_selected_navigation_index = button_index
	_refresh_navigation_selection()
	_activate_selected_option()


func _refresh_navigation_selection() -> void:
	for button_index in range(_navigation_buttons.size()):
		var button := _navigation_buttons[button_index]

		if button_index == _selected_navigation_index:
			button.add_theme_stylebox_override(
				"normal",
				_create_button_style(
					Color("#5a5128"),
					Color("#ffe183"),
					4
				)
			)
		else:
			button.add_theme_stylebox_override(
				"normal",
				_create_button_style(
					Color("#27323a"),
					Color("#61707a"),
					2
				)
			)


func _focus_selected_navigation_button() -> void:
	if _navigation_buttons.is_empty():
		return

	if _selected_navigation_index >= _navigation_buttons.size():
		return

	_navigation_buttons[_selected_navigation_index].grab_focus()


func _add_detail_heading(heading_text: String) -> void:
	var heading := Label.new()

	heading.text = heading_text
	heading.add_theme_font_size_override("font_size", 24)
	heading.modulate = Color("#d8e1e8")
	_detail_column.add_child(heading)


func _add_detail_text(detail_text: String) -> void:
	var detail_label := Label.new()

	detail_label.text = detail_text
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 18)
	detail_label.modulate = Color("#d8e1e8")
	_detail_column.add_child(detail_label)


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
	# Fallback using the same public navigation entry point.
	# Events consumed by _input do not reach this stage.
	if handle_menu_input(event):
		get_viewport().set_input_as_handled()

func handle_menu_input(event: InputEvent) -> bool:
	## Public keyboard-navigation entry point.
	## Returns true when the open menu owns this keyboard event.
	## Navigation and back/close behavior remain inside PartyMenu.

	if not _is_open:
		return false

	if not event is InputEventKey:
		return false

	# Consume releases and repeats without executing another menu action.
	if not event.is_pressed() or event.is_echo():
		return true

	if event.is_action_pressed("ui_cancel"):
		_handle_back()

	elif (
		event.is_action_pressed("move_up")
		or event.is_action_pressed("ui_up")
		or event.is_action_pressed("move_left")
		or event.is_action_pressed("ui_left")
	):
		_move_navigation_selection(-1)

	elif (
		event.is_action_pressed("move_down")
		or event.is_action_pressed("ui_down")
		or event.is_action_pressed("move_right")
		or event.is_action_pressed("ui_right")
	):
		_move_navigation_selection(1)

	elif event.is_action_pressed("ui_accept"):
		_activate_selected_option()

	# Unknown keys also stay inside the open menu.
	return true


func _input(event: InputEvent) -> void:
	# Run before focused Buttons handle keyboard events.
	# Mouse clicks still use the existing Button.pressed connections.
	if handle_menu_input(event):
		get_viewport().set_input_as_handled()

func _show_item_selection(feedback: String = "") -> void:
	_screen = Screen.ITEM_SELECTION
	_selected_navigation_index = 0
	_selected_item_id = &""
	_item_targets.clear()
	_available_item_ids.clear()

	_set_subtitle("Select a single-target recovery item.")
	_set_hint(
		"Navigate: WASD or arrow keys"
		+ "   •   Confirm: Enter or Space"
		+ "   •   Back: Escape"
	)

	_clear_navigation()
	_clear_details()

	for item_id: StringName in ItemData.get_all_item_ids():
		var quantity: int = GameState.get_item_quantity(item_id)

		if quantity <= 0:
			continue

		var item: GameItem = ItemData.get_item(item_id)

		_available_item_ids.append(item_id)
		_add_navigation_button(
			"%s × %d" % [item.display_name, quantity],
			item.description
		)

	if not feedback.is_empty():
		_add_detail_heading("ITEM RESULT")
		_add_detail_text(feedback)

	if _available_item_ids.is_empty():
		_add_detail_heading("EMPTY INVENTORY")
		_add_detail_text("No usable items remain.")
	else:
		_add_detail_heading("RECOVERY ITEMS")
		_add_detail_text(
			"Choose an item, then a squad and one living member.\n\n"
			+ "Escape cancels without consuming an item.\n\n"
			+ "Confirming use consumes one item, even if the "
			+ "selected member is already fully restored."
		)

	_refresh_navigation_selection()
	call_deferred("_focus_selected_navigation_button")


func _show_item_squad_selection() -> void:
	var item: GameItem = ItemData.get_item(_selected_item_id)

	if item == null:
		_show_item_selection("Unknown item.")
		return

	_screen = Screen.ITEM_SQUAD_SELECTION
	_selected_navigation_index = 0
	_item_targets.clear()

	_set_subtitle(
		"%s — choose the target's squad." % item.display_name
	)
	_set_hint(
		"Navigate: WASD or arrow keys"
		+ "   •   Confirm: Enter or Space"
		+ "   •   Back: Escape"
	)

	_clear_navigation()
	_clear_details()

	for squad: Squad in _available_squads:
		_add_navigation_button(
			squad.display_name,
			"%d living member(s)" % squad.get_living_members().size()
		)

	_add_detail_heading(item.display_name)
	_add_detail_text(item.description)
	_add_detail_text(
		"Selecting a squad does not use the item. "
		+ "Choose one individual member next."
	)

	_refresh_navigation_selection()
	call_deferred("_focus_selected_navigation_button")


func _show_item_target_selection(squad: Squad) -> void:
	var item: GameItem = ItemData.get_item(_selected_item_id)

	if item == null or squad == null:
		_show_item_selection()
		return

	_screen = Screen.ITEM_TARGET_SELECTION
	_selected_navigation_index = 0
	_item_targets = squad.get_living_members()

	_set_subtitle(
		"%s — choose one member of %s." % [
			item.display_name,
			squad.display_name
		]
	)
	_set_hint(
		"Navigate: WASD or arrow keys"
		+ "   •   Use item: Enter or Space"
		+ "   •   Back: Escape"
	)

	_clear_navigation()
	_clear_details()

	for member: Unit in _item_targets:
		_add_navigation_button(
			member.display_name,
			"HP %d/%d  •  MP %d/%d" % [
				member.hp,
				member.max_hp,
				member.mp,
				member.max_mp
			]
		)

	_refresh_item_target_details()
	_refresh_navigation_selection()
	call_deferred("_focus_selected_navigation_button")


func _refresh_item_target_details() -> void:
	_clear_details()

	var item: GameItem = ItemData.get_item(_selected_item_id)

	if item == null:
		return

	_add_detail_heading(item.display_name)
	_add_detail_text(item.description)

	if _item_targets.is_empty():
		_add_detail_text(
			"This squad has no living targets. "
			+ "Press Escape to choose another squad."
		)
		return

	if (
		_selected_navigation_index < 0
		or _selected_navigation_index >= _item_targets.size()
	):
		return

	var target: Unit = _item_targets[_selected_navigation_index]

	_add_detail_heading(target.display_name)
	_add_detail_text(
		"HP %d/%d\nMP %d/%d\n\nConfirm to consume one %s." % [
			target.hp,
			target.max_hp,
			target.mp,
			target.max_mp,
			item.display_name
		]
	)


func _use_selected_item() -> void:
	if (
		_selected_item_id == &""
		or _selected_navigation_index < 0
		or _selected_navigation_index >= _item_targets.size()
	):
		return

	var item: GameItem = ItemData.get_item(_selected_item_id)

	if item == null:
		_show_item_selection("Unknown item.")
		return

	var target: Unit = _item_targets[_selected_navigation_index]
	var result: Dictionary = GameState.use_item(_selected_item_id, target)

	var feedback: String = str(
		result.get("message", "Item use failed.")
	)

	if bool(result.get("success", false)):
		feedback = "%s used.\n%s" % [item.display_name, feedback]

	_show_item_selection(feedback)

func _show_equipment_screen(
	next_screen: Screen,
	feedback: String = ""
) -> void:
	_screen = next_screen
	_selected_navigation_index = 0
	_equipment_choices.clear()

	_clear_navigation()
	_clear_details()

	_set_hint(
		"Navigate: WASD or arrow keys"
		+ "   •   Confirm: Enter or Space"
		+ "   •   Back: Escape"
	)

	match _screen:
		Screen.EQUIPMENT_SQUAD_SELECTION:
			_equipment_squad = null
			_equipment_unit = null
			_equipment_slot = &""
			_set_subtitle("Equipment — choose a squad.")

			for squad: Squad in _available_squads:
				_add_navigation_button(
					squad.display_name,
					"%d member(s)" % squad.members.size()
				)

			_add_detail_heading("EQUIPMENT")
			_add_detail_text(
				"Choose a squad, member and equipment slot.\n\n"
				+ "Equipped gear is removed from available stock. "
				+ "Replaced gear returns to stock."
			)

		Screen.EQUIPMENT_MEMBER_SELECTION:
			if _equipment_squad == null:
				_show_equipment_screen(Screen.EQUIPMENT_SQUAD_SELECTION)
				return

			_set_subtitle(
				"%s — choose a member." % _equipment_squad.display_name
			)

			for member: Unit in _equipment_squad.members:
				_add_navigation_button(
					member.display_name,
					member.get_summary()
				)

			_add_detail_heading("CHOOSE A MEMBER")
			_add_detail_text(
				"Equipment changes the same Unit used by gameplay."
			)

		Screen.EQUIPMENT_SLOT_SELECTION:
			if _equipment_unit == null:
				_show_equipment_screen(Screen.EQUIPMENT_MEMBER_SELECTION)
				return

			_set_subtitle(
				"%s — choose a slot." % _equipment_unit.display_name
			)

			for slot: StringName in Equipment.SLOTS:
				var current_id: StringName = (
					_equipment_unit.get_equipment_id(slot)
				)
				var gear: Equipment = EquipmentData.get_equipment(
					current_id
				)
				var gear_name: String = (
					gear.display_name if gear != null else "(empty)"
				)

				_add_navigation_button(
					String(slot).capitalize(),
					gear_name
				)

			_add_equipment_unit_details()

		Screen.EQUIPMENT_CHOICE:
			if _equipment_unit == null or _equipment_slot == &"":
				_show_equipment_screen(Screen.EQUIPMENT_SLOT_SELECTION)
				return

			_set_subtitle(
				"%s — %s" % [
					_equipment_unit.display_name,
					_equipment_slot
				]
			)

			var current_id: StringName = (
				_equipment_unit.get_equipment_id(_equipment_slot)
			)

			for gear_id: StringName in EquipmentData.get_all_equipment_ids():
				var gear: Equipment = EquipmentData.get_equipment(gear_id)
				var quantity: int = GameState.get_equipment_quantity(gear_id)

				if (
					StringName(gear.slot) != _equipment_slot
					or quantity <= 0
					or gear_id == current_id
				):
					continue

				_equipment_choices.append(gear_id)
				_add_navigation_button(
					"%s × %d" % [gear.display_name, quantity],
					gear.get_bonus_summary()
				)

			if current_id != &"":
				_equipment_choices.append(&"")
				_add_navigation_button(
					"(Unequip)",
					"Return current gear to inventory."
				)

			_add_equipment_unit_details()

			if _equipment_choices.is_empty():
				_add_detail_text("No equipment is available for this slot.")

			_add_detail_text(
				"Maximum-HP changes preserve HP percentage, "
				+ "rounded down. Defeated members remain defeated."
			)

	if not feedback.is_empty():
		_add_detail_heading("EQUIPMENT RESULT")
		_add_detail_text(feedback)

	_refresh_navigation_selection()
	call_deferred("_focus_selected_navigation_button")


func _activate_equipment_option() -> void:
	var index: int = _selected_navigation_index

	if index < 0:
		return

	match _screen:
		Screen.EQUIPMENT_SQUAD_SELECTION:
			if index >= _available_squads.size():
				return

			_equipment_squad = _available_squads[index]
			_show_equipment_screen(Screen.EQUIPMENT_MEMBER_SELECTION)

		Screen.EQUIPMENT_MEMBER_SELECTION:
			if (
				_equipment_squad == null
				or index >= _equipment_squad.members.size()
			):
				return

			_equipment_unit = _equipment_squad.members[index]
			_show_equipment_screen(Screen.EQUIPMENT_SLOT_SELECTION)

		Screen.EQUIPMENT_SLOT_SELECTION:
			if index >= Equipment.SLOTS.size():
				return

			_equipment_slot = Equipment.SLOTS[index]
			_show_equipment_screen(Screen.EQUIPMENT_CHOICE)

		Screen.EQUIPMENT_CHOICE:
			if index >= _equipment_choices.size():
				return

			var result: Dictionary = GameState.change_equipment(
				_equipment_unit,
				_equipment_slot,
				_equipment_choices[index]
			)

			_show_equipment_screen(
				Screen.EQUIPMENT_SLOT_SELECTION,
				str(result.get("message", "Equipment change failed."))
			)


func _add_equipment_unit_details() -> void:
	if _equipment_unit == null:
		return

	_add_detail_heading(_equipment_unit.display_name)

	_add_detail_text(
		"HP %d/%d  •  MP %d/%d\n\n"
		% [
			_equipment_unit.hp,
			_equipment_unit.max_hp,
			_equipment_unit.mp,
			_equipment_unit.max_mp
		]
	)

	var stats_template: String = (
		"Attack   %d  (base %d)\n"
		+ "Defense  %d  (base %d)\n"
		+ "Speed    %d  (base %d)\n"
		+ "Wisdom   %d  (base %d)"
	)

	_add_detail_text(
		stats_template % [
			_equipment_unit.attack,
			_equipment_unit.base_attack,
			_equipment_unit.defense,
			_equipment_unit.base_defense,
			_equipment_unit.speed,
			_equipment_unit.base_speed,
			_equipment_unit.wisdom,
			_equipment_unit.base_wisdom
		]
	)

	for slot: StringName in Equipment.SLOTS:
		var gear: Equipment = EquipmentData.get_equipment(
			_equipment_unit.get_equipment_id(slot)
		)

		_add_detail_text(
			"%s: %s" % [
				String(slot).capitalize(),
				gear.display_name if gear != null else "(empty)"
			]
		)
