extends Node2D

## Standalone layout authoring.
## Never modifies GameState, CityData or existing saved files.

@export var source_layout: CityLayoutData
@export var background_texture: Texture2D
@export var save_prefix: String = "castletown_labels"

var _data: CityLayoutData
var _background: Sprite2D
var _camera: Camera2D

var _scroll: ScrollContainer
var _status: Label
var _position_label: Label
var _destination_picker: OptionButton
var _reload_dialog: ConfirmationDialog

var _destinations: Array[CityDestination] = []
var _selected_index: int = 0
var _history: Array[Dictionary] = []

var _dirty: bool = false
var _panning: bool = false
var _placing: bool = false
var _drag_before: Dictionary = {}


func _ready() -> void:
	_background = Sprite2D.new()
	_background.centered = false
	_background.z_index = -10
	add_child(_background)

	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()

	_destinations = CityData.get_destinations()

	_build_ui()
	_load_source()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(16.0, 16.0)
	layer.add_child(panel)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(420.0, 850.0)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)

	var margin := MarginContainer.new()

	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)

	_scroll.add_child(margin)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	_add_label(column, "CITY LABEL AUTHORING — geen gameplay")

	_status = _add_label(column, "")

	_add_label(
		column,
		"Selecteer een bestemming.\n"
		+ "Klik/sleep op de afbeelding: label plaatsen.\n"
		+ "MMB: pannen | Wiel: zoom | Home: centreren"
	)

	_destination_picker = OptionButton.new()
	column.add_child(_destination_picker)

	for destination: CityDestination in _destinations:
		_destination_picker.add_item(destination.display_name)

	_destination_picker.item_selected.connect(_on_destination_selected)

	_position_label = _add_label(column, "")

	_add_button(column, "Ongedaan maken", _undo_last)
	_add_button(column, "Afbeelding centreren", _center_image)
	_add_button(column, "Opslaan als NIEUWE Resource", _save_new_version)
	_add_button(column, "Source opnieuw laden", _request_reload)

	_add_label(
		column,
		"Opslag: res://assets/city_layouts/\n"
		+ "Na F8: wijs de nieuwe Resource toe aan CityScreen → City Layout.\n"
		+ "Bestemming-ID's en gebouwenlogica worden niet gewijzigd."
	)

	_reload_dialog = ConfirmationDialog.new()
	_reload_dialog.dialog_text = (
		"Onopgeslagen labelposities weggooien en Source opnieuw laden?"
	)
	_reload_dialog.confirmed.connect(_load_source)
	layer.add_child(_reload_dialog)


func _add_label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 380.0
	parent.add_child(label)
	return label


func _add_button(
	parent: Node,
	text: String,
	action: Callable
) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _load_source() -> void:
	_finish_placement()

	var candidate: CityLayoutData

	if source_layout != null:
		candidate = source_layout.duplicate(true) as CityLayoutData
	else:
		candidate = CityLayoutData.new()
		candidate.background = background_texture

		for destination: CityDestination in _destinations:
			candidate.label_positions[destination.destination_id] = (
				destination.position_ratio
			)

	var problem: String = candidate.validation_error()

	if not problem.is_empty():
		_status.text = problem
		return

	# Materialize fallback positions so every destination is saved explicitly.
	for destination: CityDestination in _destinations:
		var position_ratio: Vector2 = candidate.get_label_position(
			destination.destination_id
		)
		candidate.label_positions.erase(String(destination.destination_id))
		candidate.label_positions[destination.destination_id] = position_ratio

	_data = candidate
	_background.texture = _data.background

	_history.clear()
	_dirty = false
	_selected_index = 0
	_destination_picker.select(0)

	_center_image()
	_refresh_position_label()

	_status.text = "Layout geladen. Klik om het geselecteerde label te plaatsen."
	queue_redraw()


func _on_destination_selected(index: int) -> void:
	_finish_placement()
	_selected_index = index
	_refresh_position_label()
	queue_redraw()


func _refresh_position_label() -> void:
	if _data == null or _destinations.is_empty():
		_position_label.text = "Geen layout geladen."
		return

	var destination: CityDestination = _destinations[_selected_index]
	var position_ratio: Vector2 = _data.get_label_position(
		destination.destination_id
	)

	_position_label.text = (
		"ID: %s\nBeeldpositie: %.5f, %.5f"
		% [
			destination.destination_id,
			position_ratio.x,
			position_ratio.y
		]
	)


func _center_image() -> void:
	if _data == null or _data.background == null:
		return

	var texture_size: Vector2 = _data.background.get_size()
	var viewport_size: Vector2 = get_viewport_rect().size

	# Reserve room for the authoring sidebar.
	var panel_width: float = 460.0
	var available_size := Vector2(
		maxf(100.0, viewport_size.x - panel_width - 24.0),
		maxf(100.0, viewport_size.y - 48.0)
	)

	var fit_zoom: float = minf(
		available_size.x / texture_size.x,
		available_size.y / texture_size.y
	)

	fit_zoom = clampf(fit_zoom, 0.05, 8.0)
	_camera.zoom = Vector2.ONE * fit_zoom

	var desired_center := Vector2(
		panel_width + available_size.x * 0.5,
		viewport_size.y * 0.5
	)

	_camera.position = (
		texture_size * 0.5
		- (desired_center - viewport_size * 0.5) / fit_zoom
	)


func _place_at(point: Vector2) -> bool:
	if _data == null or _destinations.is_empty():
		return false

	var texture_size: Vector2 = _data.background.get_size()
	var image_rect := Rect2(Vector2.ZERO, texture_size)

	if not image_rect.has_point(point):
		return false

	var destination: CityDestination = _destinations[_selected_index]

	_data.label_positions[destination.destination_id] = Vector2(
		clampf(point.x / texture_size.x, 0.0, 1.0),
		clampf(point.y / texture_size.y, 0.0, 1.0)
	)

	_refresh_position_label()
	queue_redraw()
	return true


func _finish_placement() -> void:
	if not _placing:
		return

	_placing = false

	if _data != null and _data.label_positions != _drag_before:
		_history.append(_drag_before)

		if _history.size() > 50:
			_history.pop_front()

		_dirty = true
		_status.text = "Label geplaatst; nog niet opgeslagen."

	_drag_before = {}


func _undo_last() -> void:
	_finish_placement()

	if _data == null or _history.is_empty():
		_status.text = "Geen Undo beschikbaar."
		return

	var previous_positions: Dictionary = _history.pop_back()
	_data.label_positions = previous_positions
	_dirty = true

	_refresh_position_label()
	_status.text = "Laatste labelwijziging teruggezet."
	queue_redraw()


func _request_reload() -> void:
	_finish_placement()

	if _dirty:
		_reload_dialog.popup_centered()
	else:
		_load_source()


func _unhandled_input(event: InputEvent) -> void:
	if _data == null:
		return

	if event is InputEventKey:
		if (
			event.is_pressed()
			and not event.is_echo()
			and event.keycode == KEY_HOME
		):
			_center_image()
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_finish_placement()
			_panning = event.pressed

		elif (
			event.pressed
			and event.button_index in [
				MOUSE_BUTTON_WHEEL_UP,
				MOUSE_BUTTON_WHEEL_DOWN
			]
		):
			var factor: float = (
				1.1
				if event.button_index == MOUSE_BUTTON_WHEEL_UP
				else 1.0 / 1.1
			)

			_camera.zoom = Vector2.ONE * clampf(
				_camera.zoom.x * factor,
				0.05,
				8.0
			)

		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_before = _data.label_positions.duplicate(true)
				_placing = _place_at(get_local_mouse_position())

				if not _placing:
					_drag_before = {}
					_status.text = "Klik binnen de afbeelding."
			else:
				_finish_placement()
		else:
			return

		get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if _panning:
			_camera.position -= event.relative / _camera.zoom
			get_viewport().set_input_as_handled()

		elif _placing:
			_place_at(get_local_mouse_position())
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _scroll != null:
		_scroll.custom_minimum_size.y = maxf(
			200.0,
			get_viewport_rect().size.y - 32.0
		)

	# Mouse release above the sidebar may be consumed by GUI.
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_placement()

	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		_panning = false


func _save_new_version() -> void:
	_finish_placement()

	if _data == null:
		return

	var problem: String = _data.validation_error()

	if not problem.is_empty():
		_status.text = problem
		return

	var directory: String = "res://assets/city_layouts"
	var error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directory)
	)

	if error != OK:
		_status.text = error_string(error)
		return

	var prefix: String = save_prefix.validate_filename().strip_edges()

	if prefix.is_empty():
		prefix = "city_labels"

	var base: String = (
		directory + "/" + prefix + "_"
		+ Time.get_datetime_string_from_system().replace(":", "-")
	)

	var path: String = base + ".tres"
	var suffix: int = 1

	while FileAccess.file_exists(path):
		path = base + "_" + str(suffix) + ".tres"
		suffix += 1

	var saved: CityLayoutData = _data.duplicate(true) as CityLayoutData
	error = ResourceSaver.save(saved, path)

	if error != OK:
		_status.text = error_string(error)
		return

	_dirty = false
	_status.text = (
		"Opgeslagen:\n%s\n"
		+ "Na F8: wijs toe aan CityScreen → City Layout."
	) % path

	print("[CityLabelEditor] Saved: ", path)


func _draw() -> void:
	if _data == null:
		return

	var texture_size: Vector2 = _data.background.get_size()
	var font: Font = ThemeDB.fallback_font

	for index in range(_destinations.size()):
		var destination: CityDestination = _destinations[index]
		var point: Vector2 = (
			_data.get_label_position(destination.destination_id)
			* texture_size
		)

		var selected: bool = index == _selected_index
		var color: Color = Color.YELLOW if selected else Color.WHITE
		var font_size: int = 20

		var text_size: Vector2 = font.get_string_size(
			destination.display_name,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size
		)

		var label_rect := Rect2(
			point - Vector2(text_size.x * 0.5 + 10.0, 20.0),
			Vector2(text_size.x + 20.0, 36.0)
		)

		draw_rect(label_rect, Color(0.03, 0.05, 0.06, 0.85))
		draw_rect(label_rect, color, false, 2.0)
		draw_circle(point, 4.0, color)

		draw_string(
			font,
			point + Vector2(-text_size.x * 0.5, 7.0),
			destination.display_name,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			color
		)
