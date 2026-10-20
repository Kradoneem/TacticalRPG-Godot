class_name BattleAbilityMenu
extends VBoxContainer

## UI selection only. BattleSession supplies command permission.
## BattleScene delegates keyboard input before GUI handling.

signal command_requested(command_id: StringName)

enum Page {
	ROOT,
	SKILLS,
	SPELLS
}

var _session: BattleSession
var _page: Page = Page.ROOT
var _round: int = -1
var _selected_index: int = 0

var _list: VBoxContainer
var _description: Label
var _scroll: ScrollContainer
var _buttons: Array[Button] = []
var _command_ids: Array[StringName] = []


func _ready() -> void:
	add_theme_constant_override("separation", 8)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 126)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)

	_description = Label.new()
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.add_theme_font_size_override("font_size", 18)
	add_child(_description)

	hide()


func refresh(session: BattleSession, presentation_locked: bool) -> void:
	_session = session

	if (
		_session == null
		or presentation_locked
		or not _session.can_accept_protagonist_command()
	):
		hide()
		return

	var actor: Unit = _session.get_protagonist()

	if actor == null or not actor.is_alive():
		hide()
		return

	if _round != _session.current_round:
		_round = _session.current_round
		_page = Page.ROOT
		_selected_index = 0

	_rebuild()
	show()


func _rebuild() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	_buttons.clear()
	_command_ids.clear()

	if _page == Page.ROOT:
		_add_option("Attack", &"basic_attack")
		_add_option("Skills", &"menu_skills")
		_add_option("Spells", &"menu_spells")
	else:
		var category: Skill.Category = (
			Skill.Category.SKILL
			if _page == Page.SKILLS
			else Skill.Category.SPELL
		)

		for ability_id: StringName in _session.get_protagonist_ability_ids(
			category
		):
			var ability: Skill = SkillData.get_skill(ability_id)

			if ability == null:
				continue

			var reason: String = _session.get_protagonist_command_reason(
				ability_id
			)

			var label_text: String = "%s — MP %d / HP %d" % [
				ability.display_name,
				ability.mp_cost,
				ability.hp_cost
			]

			if not reason.is_empty():
				label_text += " [unavailable]"

			_add_option(label_text, ability_id)

		_add_option("Back", &"menu_back")

	_selected_index = clampi(
		_selected_index, 0, maxi(0, _buttons.size() - 1)
	)
	_refresh_selection()


func _add_option(text: String, command_id: StringName) -> void:
	var index: int = _buttons.size()
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 38)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_option_clicked.bind(index))

	_list.add_child(button)
	_buttons.append(button)
	_command_ids.append(command_id)


func _on_option_clicked(index: int) -> void:
	if (
		not visible
		or _session == null
		or not _session.can_accept_protagonist_command()
		or index < 0
		or index >= _command_ids.size()
	):
		return

	_selected_index = index
	_refresh_selection()
	_confirm_selection()


func _refresh_selection() -> void:
	for index in range(_buttons.size()):
		_buttons[index].modulate = (
			Color("#ffe183")
			if index == _selected_index
			else Color.WHITE
		)

	if _command_ids.is_empty():
		return

	var command_id: StringName = _command_ids[_selected_index]

	match command_id:
		&"basic_attack":
			_description.text = "Reliable physical attack. Choose one enemy."
		&"menu_skills":
			_description.text = "Choose one of the commander's known skills."
		&"menu_spells":
			_description.text = "Choose one of the commander's known spells."
		&"menu_back":
			_description.text = "Return without spending resources or a turn."
		_:
			var ability: Skill = SkillData.get_skill(command_id)
			_description.text = (
				ability.description if ability != null else "Unknown ability."
			)

			var reason: String = _session.get_protagonist_command_reason(
				command_id
			)

			if not reason.is_empty():
				_description.text += "\n" + reason

	call_deferred("_ensure_selected_visible")


func _ensure_selected_visible() -> void:
	if (
		not is_inside_tree()
		or _selected_index < 0
		or _selected_index >= _buttons.size()
	):
		return

	_scroll.ensure_control_visible(_buttons[_selected_index])


func _confirm_selection() -> void:
	if (
		_command_ids.is_empty()
		or _session == null
		or not _session.can_accept_protagonist_command()
	):
		return

	var command_id: StringName = _command_ids[_selected_index]

	match command_id:
		&"menu_skills":
			_page = Page.SKILLS
			_selected_index = 0
			_rebuild()
		&"menu_spells":
			_page = Page.SPELLS
			_selected_index = 0
			_rebuild()
		&"menu_back":
			_show_root()
		_:
			var reason: String = _session.get_protagonist_command_reason(
				command_id
			)

			if not reason.is_empty():
				_description.text = reason
				return

			command_requested.emit(command_id)


func _show_root() -> void:
	_page = Page.ROOT
	_selected_index = 0
	_rebuild()


func handle_input(event: InputEvent) -> bool:
	if (
		not visible
		or _session == null
		or not _session.can_accept_protagonist_command()
	):
		return false

	if not event is InputEventKey:
		return false

	if not event.is_pressed() or event.is_echo():
		return true

	if event.is_action_pressed("ui_cancel"):
		if _page != Page.ROOT:
			_show_root()
		return true

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

	elif (
		event.keycode == KEY_ENTER
		or event.keycode == KEY_KP_ENTER
		or event.keycode == KEY_SPACE
	):
		_confirm_selection()

	return true


func _move_selection(direction: int) -> void:
	if _buttons.is_empty():
		return

	_selected_index = posmod(
		_selected_index + direction, _buttons.size()
	)
	_refresh_selection()
