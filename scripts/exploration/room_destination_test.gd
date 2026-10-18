extends Node2D

## Placeholder destination using the shared exploration entry contract.

@export var is_city: bool = false
@export var location_name: String = "Sewer Corridor"

var _entry_context: ExplorationEntryContext
var _transitioning: bool = false
var _description: Label


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(24.0, 24.0)
	panel.custom_minimum_size = Vector2(600.0, 0.0)
	layer.add_child(panel)

	var margin := MarginContainer.new()

	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)

	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 26)
	title.text = (
		GameState.current_city + " — TESTBESTEMMING"
		if is_city
		else location_name + " — TESTBESTEMMING"
	)
	column.add_child(title)

	_description = Label.new()
	_description.add_theme_font_size_override("font_size", 22)
	column.add_child(_description)

	_refresh_description()


func prepare_exploration_entry(
	context: ExplorationEntryContext
) -> bool:
	if context == null or context.main_squad == null:
		return false

	if context.main_squad != GameState.get_main_squad():
		return false

	_entry_context = context
	return true


func on_exploration_entered(
	context: ExplorationEntryContext
) -> void:
	_entry_context = context
	_transitioning = false

	GameState.in_city = is_city
	GameState.current_location = (
		GameState.current_city if is_city else location_name
	)

	_refresh_description()


func _refresh_description() -> void:
	if _description == null:
		return

	_description.text = (
		"Stad-placeholder: nog geen stadsystemen."
		if is_city
		else "Testbestemming: nog geen exploration-grid."
	)

	if _entry_context != null:
		_description.text += "\n\nEnter / Spatie: terug naar de vorige map"


func _input(event: InputEvent) -> void:
	if _entry_context == null or _transitioning:
		return

	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey

	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode not in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		return

	_transitioning = true
	get_viewport().set_input_as_handled()
	call_deferred("_return_to_source")


func _return_to_source() -> void:
	var placeholder_cells: Array[Vector2i] = [Vector2i.ZERO]
	var exit_data := ExplorationExitData.create(
		&"return",
		"Terug",
		placeholder_cells,
		_entry_context.source_scene,
		_entry_context.departure_cell
	)

	var destination: Node = SceneManager.travel_exploration(
		self, exit_data, Vector2i.ZERO
	)

	if destination == null:
		_transitioning = false
		_description.text = "Terugkeer mislukt. Controleer Output."
