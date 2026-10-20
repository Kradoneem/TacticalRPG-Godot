class_name QuestUpdateBanner
extends CanvasLayer

## One persistent, non-modal quest notification queue under Main.
## No keyboard input, no gameplay pause and no quest evaluation.

const DISPLAY_SECONDS: float = 3.5

var _label: Label
var _messages: Array[String] = []
var _current_message: String = ""
var _remaining: float = 0.0

var _display_allowed: Callable


func _ready() -> void:
	layer = 15

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_label.offset_left = 240
	_label.offset_right = -240
	_label.offset_top = 28
	_label.offset_bottom = 120
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color("#ffe183"))
	_label.add_theme_color_override("font_outline_color", Color("#10171d"))
	_label.add_theme_constant_override("outline_size", 6)
	root.add_child(_label)

	GameState.quest_objective_updated.connect(_on_objective_updated)
	GameState.quest_progress_reset.connect(_reset_queue)

	hide()


func configure(display_allowed: Callable) -> void:
	_display_allowed = display_allowed


func _on_objective_updated(
	quest_id: String,
	objective_id: StringName
) -> void:
	var quest: QuestDefinition = QuestData.get_quest(quest_id)

	if quest == null:
		return

	for objective: QuestObjective in quest.objectives:
		if objective.objective_id == objective_id:
			_messages.append(
				"Quest updated: %s\n%s — achieved" % [
					quest.title,
					objective.description
				]
			)
			return


func _process(delta: float) -> void:
	var allowed: bool = (
		_display_allowed.is_valid()
		and bool(_display_allowed.call())
	)

	if not allowed:
		# Preserve both pending messages and current display time.
		hide()
		return

	if _current_message.is_empty():
		if _messages.is_empty():
			hide()
			return

		_current_message = _messages.pop_front()
		_remaining = DISPLAY_SECONDS
		_label.text = _current_message

	show()
	_remaining -= delta

	if _remaining <= 0.0:
		_current_message = ""
		hide()


func _reset_queue() -> void:
	_messages.clear()
	_current_message = ""
	_remaining = 0.0
	hide()
