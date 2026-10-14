class_name BattleUnitCard

extends Button

## Persistent presentation card for one formation slot.
## It reads shared Unit state but never resolves combat.

signal target_requested(target_unit_id: String)

var _unit: Unit

var _name_label: Label
var _hp_label: Label
var _hp_bar: ProgressBar
var _mp_label: Label

var _target_selection_enabled: bool = false


func _ready() -> void:
	pressed.connect(_on_pressed)


func configure_visuals(
	background_color: Color,
	border_color: Color
) -> void:
	custom_minimum_size = Vector2(350.0, 78.0)
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_theme_stylebox_override(
		"normal",
		_create_card_style(background_color, border_color, 2)
	)

	add_theme_stylebox_override(
		"disabled",
		_create_card_style(background_color, border_color, 2)
	)

	add_theme_stylebox_override(
		"hover",
		_create_card_style(
			Color("#7a3f3f"),
			Color("#fff0a6"),
			3
		)
	)

	add_theme_stylebox_override(
		"focus",
		_create_card_style(
			Color("#7a5428"),
			Color("#ffe183"),
			4
		)
	)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 2)
	add_child(content)

	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.add_theme_font_size_override("font_size", 18)
	content.add_child(_name_label)

	_hp_label = Label.new()
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_hp_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(0.0, 12.0)
	content.add_child(_hp_bar)

	_mp_label = Label.new()
	_mp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mp_label.modulate = Color("#d2e3ff")
	content.add_child(_mp_label)

	set_unit(null)


func set_unit(new_unit: Unit) -> void:
	_unit = new_unit

	if _unit == null:
		_name_label.text = "FORMATION SLOT — EMPTY"
		_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		_hp_label.text = ""
		_hp_bar.max_value = 1.0
		_hp_bar.value = 0.0
		_mp_label.text = ""

		tooltip_text = ""
		return

	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name_label.text = _unit.display_name

	_hp_label.text = "HP %d / %d" % [_unit.hp, _unit.max_hp]
	_hp_bar.max_value = _unit.max_hp
	_hp_bar.value = _unit.hp

	_mp_label.text = "MP %d / %d" % [_unit.mp, _unit.max_mp]


func set_target_selection_enabled(
	is_enabled: bool,
	command_text: String
) -> void:
	_target_selection_enabled = is_enabled

	disabled = not is_enabled

	if is_enabled and _unit != null:
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP

		tooltip_text = "Target %s with %s" % [
			_unit.display_name,
			command_text
		]
		return

	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = ""


func get_unit_id() -> String:
	if _unit == null:
		return ""

	return _unit.unit_id


func _on_pressed() -> void:
	if (
		not _target_selection_enabled
		or _unit == null
		or not _unit.is_alive()
	):
		return

	target_requested.emit(_unit.unit_id)


func _create_card_style(
	background_color: Color,
	border_color: Color,
	border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(background_color, 0.9)
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)

	return style
