extends Node2D

## Minimal destination for testing entrance transitions.
## Not a city system or a corridor exploration controller.

const ENTRANCE_SCENE_PATH: String = (
    "res://scenes/exploration/sewer_entrance_test.tscn"
)

@export var is_city: bool = false
@export var location_name: String = "Sewer Corridor"

var _return_cell: Vector2i
var _has_return_context: bool = false
var _transitioning: bool = false
var _main_squad: Squad

var _title: Label
var _description: Label


func _ready() -> void:
	_build_ui()

	GameState.in_city = is_city
	GameState.current_location = (
		GameState.current_city if is_city else location_name
	)

	if is_city:
		_title.text = GameState.current_city + " — TESTBESTEMMING"
		_description.text = (
            "Stad-placeholder: nog geen stadsystemen."
			+ "\n\n"
			+ "Terugkeer wordt beschikbaar na een overgang vanuit de entrance."
		)
	else:
		_title.text = "SEWER CORRIDOR — TESTBESTEMMING"
		_description.text = (
            "Bestaande corridorachtergrond."
			+ "\nNog geen movement-grid in deze scene."
			+ "\n\n"
			+ "Terugkeer wordt beschikbaar na een overgang vanuit de entrance."
		)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(24.0, 24.0)
	panel.custom_minimum_size = Vector2(600.0, 0.0)
	layer.add_child(panel)

	var margin := MarginContainer.new()

	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)

	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	column.add_child(_title)

	_description = Label.new()
	_description.add_theme_font_size_override("font_size", 22)
	column.add_child(_description)


func configure_return(departure_cell: Vector2i) -> void:
	_return_cell = departure_cell
	_main_squad = GameState.get_main_squad()
	_has_return_context = true

	var destination_description: String = (
        "Stad-placeholder: nog geen stadsystemen."
		if is_city
		else "Corridorachtergrond: nog geen movement-grid."
	)

	_description.text = (
		destination_description
		+ "\n\nEnter / Spatie: terug naar de entrance"
		+ "\nAankomstcel: "
		+ str(_return_cell)
	)


func _input(event: InputEvent) -> void:
	if not _has_return_context or _transitioning:
		return

	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey

	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode not in [
		KEY_ENTER,
		KEY_KP_ENTER,
		KEY_SPACE
	]:
		return

	_transitioning = true
	get_viewport().set_input_as_handled()
	call_deferred("_return_to_entrance")


func _return_to_entrance() -> void:
	if SceneManager.get_current_game_scene() != self:
		_transitioning = false
		_description.text = "Start met F5 om kamerwissels te testen."
		return

	var entrance: Node = SceneManager.change_game_scene(
		ENTRANCE_SCENE_PATH
	)

	if entrance == null:
		_transitioning = false
		_description.text = "Entrance laden mislukt. Controleer Output."
		return

	# change_game_scene adds the scene to Main, so its _ready has run.
	var marker: TacticalPlayer = (
		entrance.get_node("PlayerMarker") as TacticalPlayer
	)

	if marker.squad != _main_squad:
		push_error("Room transition unexpectedly replaced the Main Squad.")

	if not marker.move_to(_return_cell):
		push_error(
            "Could not return to entrance cell: %s"
			% str(_return_cell)
		)

	print(
		"Returned to entrance cell ",
		marker.cell,
		" with the same Main Squad: ",
		marker.squad == _main_squad
	)
