class_name EncounterResultsPanel
extends Control

## Displays an already settled result.
## Never grants rewards or changes gameplay data.
## BattleScene delegates keyboard input while this panel is open.

signal continued

var _result: EncounterResult
var _content: VBoxContainer
var _continued: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var background := ColorRect.new()
	background.color = Color("#10171d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 150)
	margin.add_theme_constant_override("margin_right", 150)
	margin.add_theme_constant_override("margin_top", 80)
	margin.add_theme_constant_override("margin_bottom", 80)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 18)
	margin.add_child(page)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	scroll.add_child(_content)

	var button := Button.new()
	button.text = "Continue — Enter / Space"
	button.custom_minimum_size = Vector2(0, 54)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_continue)
	page.add_child(button)


func configure(result: EncounterResult) -> void:
	_result = result

	if _content == null:
		return

	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	if _result == null:
		_add_text("No encounter result.", 28)
		return

	var title: String = (
		"VICTORY"
		if _result.defeat_rewards_claimed
		else "ENCOUNTER RESULTS"
	)
	_add_text(title, 32)

	if _result.enemy_squad_defeated:
		_add_text("%s defeated." % _result.enemy_squad_name, 22)

	if _result.defeat_rewards_claimed:
		_add_text("Gold gained: %d" % _result.gold_gained, 22)

		if _result.items_gained.is_empty():
			_add_text("Items: none.", 20)
		else:
			_add_text("ITEMS", 24)

			for raw_id in _result.items_gained:
				var item: GameItem = ItemData.get_item(StringName(raw_id))
				var name_text: String = (
					item.display_name if item != null else str(raw_id)
				)
				_add_text(
					"%s × %d" % [
						name_text,
						int(_result.items_gained[raw_id])
					],
					20
				)

		for row: Dictionary in _result.unit_results:
			_content.add_child(HSeparator.new())

			_add_text(
				"%s — Lv.%d" % [row["name"], row["level_after"]],
				24
			)

			if not bool(row["alive"]):
				_add_text("Defeated — no XP.", 20)
				continue

			_add_text(
				"+%d XP   •   XP %d/%d" % [
					row["xp_gained"],
					row["xp_after"],
					row["xp_needed"]
				],
				20
			)

			if int(row["levels_gained"]) > 0:
				_add_text(
					"LEVEL UP: %d → %d" % [
						row["level_before"],
						row["level_after"]
					],
					22
				)

				var before: Dictionary = row["stats_before"]
				var after: Dictionary = row["stats_after"]
				var changes: Array[String] = []

				for stat: String in [
					"max_hp", "attack", "defense", "speed", "wisdom"
				]:
					changes.append(
						"%s %d → %d" % [
							stat.to_upper(),
							before[stat],
							after[stat]
						]
					)

				_add_text("   •   ".join(changes), 18)

	if not _result.special_messages.is_empty():
		_content.add_child(HSeparator.new())
		_add_text("SPECIAL OUTCOMES", 24)

		for message: String in _result.special_messages:
			_add_text(message, 20)


func _add_text(text: String, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	_content.add_child(label)


func handle_input(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false

	# Releases and repeats must not trigger another confirmation.
	if not event.is_pressed() or event.is_echo():
		return true

	if (
		event.keycode == KEY_ENTER
		or event.keycode == KEY_KP_ENTER
		or event.keycode == KEY_SPACE
	):
		_continue()

	# All keyboard input belongs to this resultpanel.
	return true


func _continue() -> void:
	if _continued:
		return

	_continued = true
	continued.emit()
