class_name BattleScene

extends Control

## A temporary 2D side-view presentation of one tactical encounter.
## It receives shared Squad and Unit references through EncounterContext.
## It never owns tactical-grid state.

signal presentation_finished(context: EncounterContext)

const MAX_FORMATION_SLOTS: int = 4

var encounter_context: EncounterContext

var _party_formation: VBoxContainer
var _enemy_formation: VBoxContainer
var _status_label: Label
var _return_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_interface()


func configure(context: EncounterContext) -> void:
	encounter_context = context

	if not is_node_ready():
		return

	_refresh_presentation()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("#18212a")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var outer_margin := MarginContainer.new()
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 70)
	outer_margin.add_theme_constant_override("margin_top", 48)
	outer_margin.add_theme_constant_override("margin_right", 70)
	outer_margin.add_theme_constant_override("margin_bottom", 48)
	add_child(outer_margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 20)
	outer_margin.add_child(page)

	var title_label := Label.new()
	title_label.text = "BATTLE PRESENTATION — PROTOTYPE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	page.add_child(title_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.modulate = Color("#c9d4dd")
	page.add_child(_status_label)

	var separator := HSeparator.new()
	page.add_child(separator)

	var formations := HBoxContainer.new()
	formations.size_flags_vertical = Control.SIZE_EXPAND_FILL
	formations.add_theme_constant_override("separation", 70)
	page.add_child(formations)

	_party_formation = _create_formation_column(
		"MAIN SQUAD",
		HORIZONTAL_ALIGNMENT_LEFT
	)
	formations.add_child(_party_formation)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	formations.add_child(spacer)

	_enemy_formation = _create_formation_column(
		"ENEMY SQUAD",
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	formations.add_child(_enemy_formation)

	var footer_separator := HSeparator.new()
	page.add_child(footer_separator)

	_return_button = Button.new()
	_return_button.text = "Return to tactical test"
	_return_button.custom_minimum_size = Vector2(0.0, 56.0)
	_return_button.focus_mode = Control.FOCUS_ALL
	_return_button.pressed.connect(_on_return_button_pressed)
	page.add_child(_return_button)

	var hint_label := Label.new()
	hint_label.text = (
		"Temporary transition test — "
		+ "the battle scene does not resolve combat yet."
	)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.modulate = Color("#aab8c4")
	page.add_child(hint_label)

	_refresh_presentation()


func _create_formation_column(
	formation_title: String,
	alignment: HorizontalAlignment
) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(350.0, 0.0)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)

	var title_label := Label.new()
	title_label.text = formation_title
	title_label.horizontal_alignment = alignment
	title_label.add_theme_font_size_override("font_size", 22)
	column.add_child(title_label)

	return column


func _refresh_presentation() -> void:
	if _party_formation == null or _enemy_formation == null:
		return

	_clear_formation_slots(_party_formation)
	_clear_formation_slots(_enemy_formation)

	if encounter_context == null:
		_status_label.text = "No encounter context was received."
		_return_button.disabled = true
		return

	_return_button.disabled = false

	var initiator_text := "Enemy initiative"

	if encounter_context.was_player_initiated():
		initiator_text = "Main Squad initiative"

	_status_label.text = "%s  |  Temporary strategy: %s" % [
		initiator_text,
		encounter_context.active_strategy
	]

	_add_formation_slots(
		_party_formation,
		encounter_context.player_squad,
		Color("#587aa0"),
		Color("#b8d8ff")
	)

	_add_formation_slots(
		_enemy_formation,
		encounter_context.enemy_squad,
		Color("#994d4d"),
		Color("#ffd0ca")
	)


func _clear_formation_slots(formation: VBoxContainer) -> void:
	for child in formation.get_children():
		if child is Label:
			continue

		child.queue_free()


func _add_formation_slots(
	formation: VBoxContainer,
	squad: Squad,
	background_color: Color,
	border_color: Color
) -> void:
	for slot_index in range(MAX_FORMATION_SLOTS):
		var unit: Unit = null

		if squad != null and slot_index < squad.members.size():
			unit = squad.members[slot_index]

		formation.add_child(
			_create_formation_slot(
				slot_index,
				unit,
				background_color,
				border_color
			)
		)


func _create_formation_slot(
	slot_index: int,
	unit: Unit,
	background_color: Color,
	border_color: Color
) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(350.0, 112.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(background_color, 0.9)
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	slot.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	slot.add_child(content)

	if unit == null:
		var empty_label := Label.new()
		empty_label.text = "FORMATION SLOT %d — EMPTY" % (slot_index + 1)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty_label.modulate = Color("#93a0aa")
		content.add_child(empty_label)

		return slot

	var name_label := Label.new()
	name_label.text = unit.display_name
	name_label.add_theme_font_size_override("font_size", 18)
	content.add_child(name_label)

	var hp_label := Label.new()
	hp_label.text = "HP %d / %d" % [unit.hp, unit.max_hp]
	content.add_child(hp_label)

	var hp_bar := ProgressBar.new()
	hp_bar.max_value = unit.max_hp
	hp_bar.value = unit.hp
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(0.0, 12.0)
	content.add_child(hp_bar)

	var mp_label := Label.new()
	mp_label.text = "MP %d / %d" % [unit.mp, unit.max_mp]
	mp_label.modulate = Color("#d2e3ff")
	content.add_child(mp_label)

	return slot


func _on_return_button_pressed() -> void:
	if encounter_context == null:
		return

	presentation_finished.emit(encounter_context)


func _unhandled_input(event: InputEvent) -> void:
	## Tactical movement must not leak through to the hidden tactical scene.
	if event.is_action_pressed("move_up"):
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("move_down"):
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("move_left"):
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("move_right"):
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("engage"):
		get_viewport().set_input_as_handled()
