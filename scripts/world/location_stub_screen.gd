class_name LocationStubScreen
extends Control

var _location: WorldLocation
var _status: Label
var _button: Button
var _page_frame: int = -1
var _transitioning: bool = false


func prepare_location_entry(location: WorldLocation) -> bool:
	if (
		location == null
		or location.kind != WorldLocation.Kind.PROTOTYPE_STUB
		or location.location_id != GameState.world_location_id
	):
		push_warning("LocationStubScreen weigert deze locatie.")
		return false

	_location = location
	return true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if _location == null:
		push_error("LocationStubScreen zonder geldige locatiecontext.")
		_location = WorldMapData.get_location(GameState.world_location_id)

	GameState.in_city = false

	if _location != null:
		GameState.current_location = _location.display_name

	_page_frame = Engine.get_process_frames()
	_build_screen()


func _build_screen() -> void:
	var background := ColorRect.new()
	background.color = Color("#2a2433")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.custom_minimum_size = Vector2(640.0, 0.0)
	center.add_child(box)

	var title := Label.new()
	title.text = (
		_location.display_name if _location != null else "Onbekende locatie"
	)
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = (
		"PROTOTYPE — geen content.\n"
		+ "Enter/Spatie: World map | Escape: Party"
	)
	box.add_child(_status)

	_button = Button.new()
	_button.text = "World map"
	_button.custom_minimum_size = Vector2(0.0, 60.0)
	_button.focus_mode = Control.FOCUS_NONE
	_button.modulate = Color("#ffe183")
	_button.pressed.connect(_on_world_map_pressed)
	box.add_child(_button)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	# Escape stays available to PartyMenuController.
	if event.is_action("ui_cancel"):
		return

	get_viewport().set_input_as_handled()

	if _transitioning or not event.is_pressed() or event.is_echo():
		return

	if (
		event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
		and Engine.get_process_frames() > _page_frame
	):
		_on_world_map_pressed()


func _on_world_map_pressed() -> void:
	if _transitioning:
		return

	_transitioning = true
	call_deferred("_open_world_map")


func _open_world_map() -> void:
	var next: Node = SceneManager.change_game_scene(
		WorldMapData.WORLD_MAP_SCENE
	)

	if next == null:
		_transitioning = false
		_status.text = "World map openen mislukt. Controleer Output."


func can_open_party_menu() -> bool:
	return not _transitioning


func can_show_quest_updates() -> bool:
	return not _transitioning
