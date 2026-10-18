extends Node2D

## Standalone development tool. Run its scene with F6.
## Never instantiates gameplay maps.
## Saves a new version, never overwrites a previous file.

@export_file("*.tres")
var source_area: String = (
	"res://assets/areas/sewer_junction_authoring_v1.tres"
)

@export var save_prefix: String = "sewer_junction"

var _data: ExplorationAreaData
var _undo: Array[ExplorationAreaData] = []

var _selection: Vector2i = Vector2i(-1, -1)

var _background: Sprite2D
var _camera: Camera2D

var _panning: bool = false
var _dirty: bool = false

var _calibration_active: bool = false
var _calibration_before: ExplorationAreaData

var _points: Array[Vector2] = []
var _drag_index: int = -1
var _candidate_valid: bool = false

var _status: Label
var _selected_label: Label

var _terrain: LineEdit
var _walkable: CheckBox
var _tags: LineEdit
var _content_id: LineEdit

var _x_steps: SpinBox
var _y_steps: SpinBox

var _confirm_calibration: Button
var _reload_dialog: ConfirmationDialog


func _ready() -> void:
	_background = Sprite2D.new()
	_background.centered = false
	_background.z_index = -10
	add_child(_background)

	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()

	_build_ui()
	_load_source()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(350, 0)
	layer.add_child(panel)

	var margin := MarginContainer.new()

	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override(
			"margin_" + side,
			12
		)

	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	_add_label(column, "AREA AUTHORING — geen gameplay")

	_status = _add_label(column, "")
	_status.custom_minimum_size.x = 326
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_add_label(
		column,
		"Klik: cel kiezen | MMB: kaart slepen"
		+ "\nWiel: zoom | Home: grid centreren"
	)

	_selected_label = _add_label(
		column,
		"Geen cel geselecteerd"
	)

	_add_label(column, "Terrain (vrij label, hoofdletters):")

	_terrain = LineEdit.new()
	_terrain.placeholder_text = (
		"FLOOR / PARTIAL_WATER / WATER / UNKNOWN"
	)
	column.add_child(_terrain)

	_walkable = CheckBox.new()
	_walkable.text = (
		"Begaanbaar (UNKNOWN blijft geblokkeerd)"
	)
	column.add_child(_walkable)

	_add_label(column, "Tags, gescheiden door komma's:")

	_tags = LineEdit.new()
	_tags.placeholder_text = "EXIT, TREASURE, jouw_eigen_tag"
	column.add_child(_tags)

	_add_label(
		column,
		"Content ID (optioneel; geen rewarddata):"
	)

	_content_id = LineEdit.new()
	_content_id.placeholder_text = "bijv. maintenance_cache"
	column.add_child(_content_id)

	_add_button(
		column,
		"Toepassen op geselecteerde cel",
		_apply_cell
	)

	_add_button(
		column,
		"Ongedaan maken",
		_undo_last
	)

	_add_label(
		column,
		"KALIBRATIE — aantallen tegelafstanden"
	)

	_x_steps = _add_steps(column, "Stappen O → X", 17)
	_y_steps = _add_steps(column, "Stappen O → Y", 9)

	_x_steps.value_changed.connect(_on_steps_changed)
	_y_steps.value_changed.connect(_on_steps_changed)

	_add_button(
		column,
		"Nieuwe kalibratie: kies O, X, Y",
		_begin_calibration
	)

	_confirm_calibration = _add_button(
		column,
		"Kalibratie toepassen",
		_accept_calibration
	)
	_confirm_calibration.disabled = true

	_add_button(
		column,
		"Kalibratie annuleren",
		_cancel_calibration
	)

	_add_button(
		column,
		"Opslaan als NIEUWE area-Resource",
		_save_new_version
	)

	_add_button(
		column,
		"Bron opnieuw laden / wijzigingen weggooien",
		_request_reload
	)

	_reload_dialog = ConfirmationDialog.new()
	_reload_dialog.dialog_text = (
		"Niet-opgeslagen wijzigingen weggooien"
		+ " en bron opnieuw laden?"
	)
	_reload_dialog.confirmed.connect(_load_source)

	layer.add_child(_reload_dialog)


func _add_label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
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


func _add_steps(
	parent: Node,
	text: String,
	initial: int
) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label: Label = _add_label(row, text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = 256
	spin.step = 1
	spin.value = initial
	row.add_child(spin)

	return spin


func _load_source() -> void:
	var loaded: ExplorationAreaData = (
		ResourceLoader.load(
			source_area,
			"",
			ResourceLoader.CACHE_MODE_IGNORE
		) as ExplorationAreaData
	)

	if loaded == null:
		_status.text = (
			"Geen geldige ExplorationAreaData: " + source_area
		)
		return

	var problem: String = loaded.validation_error()

	if not problem.is_empty():
		_status.text = "Ongeldige bron: " + problem
		return

	var texture: Texture2D = (
		load(loaded.background_path) as Texture2D
	)

	if texture == null:
		_status.text = (
			"Achtergrond ontbreekt: " + loaded.background_path
		)
		return

	_data = loaded.duplicate(true) as ExplorationAreaData
	_background.texture = texture

	_undo.clear()

	_selection = Vector2i(-1, -1)

	_points.clear()
	_drag_index = -1

	_calibration_active = false
	_calibration_before = null
	_candidate_valid = false

	_confirm_calibration.disabled = true
	_dirty = false

	_x_steps.set_value_no_signal(_data.grid_size.x)
	_y_steps.set_value_no_signal(_data.grid_size.y)

	_camera.zoom = Vector2.ONE
	_center_grid()

	_selected_label.text = "Geen cel geselecteerd"
	_terrain.clear()
	_tags.clear()
	_content_id.clear()
	_walkable.button_pressed = false

	_status.text = "Geladen: " + source_area

	queue_redraw()


func _request_reload() -> void:
	if _dirty or _calibration_active:
		_reload_dialog.popup_centered()
	else:
		_load_source()


func _center_grid() -> void:
	if _data == null:
		return

	_camera.position = _data.grid_to_map(
		Vector2(_data.grid_size) * 0.5
	)


func _unhandled_input(event: InputEvent) -> void:
	if _data == null:
		return

	if event is InputEventKey:
		var key := event as InputEventKey

		if not key.pressed or key.echo:
			return

		if key.keycode == KEY_ESCAPE and _calibration_active:
			_cancel_calibration()
			get_viewport().set_input_as_handled()

		elif key.keycode == KEY_HOME:
			_center_grid()
			get_viewport().set_input_as_handled()

		return

	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton

		if mouse.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mouse.pressed
			get_viewport().set_input_as_handled()
			return

		if (
			mouse.pressed
			and mouse.button_index in [
				MOUSE_BUTTON_WHEEL_UP,
				MOUSE_BUTTON_WHEEL_DOWN
			]
		):
			var factor: float = (
				1.1
				if mouse.button_index == MOUSE_BUTTON_WHEEL_UP
				else 1.0 / 1.1
			)

			var zoom_value: float = clampf(
				_camera.zoom.x * factor,
				0.25,
				3.0
			)

			_camera.zoom = Vector2.ONE * zoom_value

			get_viewport().set_input_as_handled()
			return

		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				if _calibration_active:
					_choose_calibration_point(
						get_local_mouse_position()
					)
				else:
					_select_cell_at(
						get_local_mouse_position()
					)

			else:
				_drag_index = -1

			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion

		if _panning:
			_camera.position -= motion.relative / _camera.zoom
			get_viewport().set_input_as_handled()

		elif _calibration_active and _drag_index >= 0:
			_points[_drag_index] = get_local_mouse_position()
			_update_calibration_candidate()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# UI can consume mouse releases.
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		_panning = false

	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_drag_index = -1


func _select_cell_at(point: Vector2) -> void:
	var determinant: float = (
		_data.axis_x.cross(_data.axis_y)
	)

	if absf(determinant) < 0.001:
		return

	var relative: Vector2 = point - _data.origin

	var grid_position := Vector2(
		relative.cross(_data.axis_y) / determinant,
		_data.axis_x.cross(relative) / determinant
	)

	var cell := Vector2i(
		floori(grid_position.x),
		floori(grid_position.y)
	)

	if not _data.contains(cell):
		_status.text = "Klik buiten het grid."
		return

	_selection = cell
	_refresh_cell_fields()
	queue_redraw()


func _refresh_cell_fields() -> void:
	if not _data.contains(_selection):
		return

	var info: Dictionary = _data.get_cell_data(_selection)

	_selected_label.text = "Geselecteerd: " + str(_selection)

	_terrain.text = String(info["terrain"])
	_walkable.button_pressed = bool(info["walkable"])

	var tags: PackedStringArray = info["tags"]
	_tags.text = ", ".join(tags)

	_content_id.text = String(info["content_id"])


func _apply_cell() -> void:
	if (
		_data == null
		or _calibration_active
		or not _data.contains(_selection)
	):
		_status.text = (
			"Selecteer eerst een cel; sluit kalibratie af."
		)
		return

	_push_undo()

	_data.set_cell_data(
		_selection,
		_terrain.text,
		_walkable.button_pressed,
		_tags.text.split(",", false),
		_content_id.text
	)

	_dirty = true

	_refresh_cell_fields()

	_status.text = (
		"Cel bijgewerkt; nog niet opgeslagen: "
		+ str(_selection)
	)

	queue_redraw()


func _push_undo() -> void:
	_undo.append(
		_data.duplicate(true) as ExplorationAreaData
	)

	if _undo.size() > 50:
		_undo.pop_front()


func _undo_last() -> void:
	if _calibration_active:
		_status.text = "Sluit eerst kalibratie af."
		return

	if _undo.is_empty():
		_status.text = (
			"Geen wijzigingen om ongedaan te maken."
		)
		return

	_data = _undo.pop_back()
	_dirty = true

	_refresh_cell_fields()

	_status.text = (
		"Laatste wijziging ongedaan gemaakt;"
		+ " nog niet opgeslagen."
	)

	queue_redraw()


func _begin_calibration() -> void:
	if _data == null or _calibration_active:
		return

	_calibration_before = (
		_data.duplicate(true) as ExplorationAreaData
	)

	_calibration_active = true
	_candidate_valid = false

	_points.clear()
	_drag_index = -1
	_confirm_calibration.disabled = true

	_status.text = (
		"1/3: kies O, de hoek van cel (0,0),"
		+ " niet het midden."
	)

	queue_redraw()


func _choose_calibration_point(point: Vector2) -> void:
	if _points.size() < 3:
		_points.append(point)
		_update_calibration_candidate()
		return

	_drag_index = -1

	var nearest: float = 18.0 / _camera.zoom.x

	for index in range(_points.size()):
		var distance: float = (
			point.distance_to(_points[index])
		)

		if distance < nearest:
			nearest = distance
			_drag_index = index


func _on_steps_changed(_value: float) -> void:
	if _calibration_active:
		_update_calibration_candidate()


func _update_calibration_candidate() -> void:
	_candidate_valid = false
	_confirm_calibration.disabled = true

	if _points.size() == 1:
		_status.text = (
			"2/3: kies X vanaf O naar rechtsbeneden;"
			+ " tel tegelafstanden."
		)

	elif _points.size() == 2:
		_status.text = (
			"3/3: kies Y vanaf O naar linksbeneden;"
			+ " tel tegelafstanden."
		)

	elif _points.size() == 3:
		var axis_x: Vector2 = (
			(_points[1] - _points[0]) / _x_steps.value
		)

		var axis_y: Vector2 = (
			(_points[2] - _points[0]) / _y_steps.value
		)

		if axis_x.length() < 1.0 or axis_y.length() < 1.0:
			_status.text = (
				"Ongeldige assen: punten te dicht bij elkaar."
			)

		elif absf(
			axis_x.normalized().cross(axis_y.normalized())
		) <= 0.05:
			_status.text = (
				"Ongeldige assen: richtingen bijna parallel."
			)

		else:
			_data.origin = _points[0]
			_data.axis_x = axis_x
			_data.axis_y = axis_y

			_candidate_valid = true
			_confirm_calibration.disabled = false

			_status.text = (
				"Preview. Sleep O/X/Y; pas toe of annuleer."
				+ " Celdata blijft gelijk."
			)

	queue_redraw()


func _accept_calibration() -> void:
	if not _calibration_active or not _candidate_valid:
		return

	_undo.append(_calibration_before)

	if _undo.size() > 50:
		_undo.pop_front()

	_calibration_before = null
	_calibration_active = false

	_points.clear()
	_drag_index = -1
	_confirm_calibration.disabled = true

	_dirty = true

	_status.text = (
		"Kalibratie toegepast; nog niet opgeslagen."
		+ " Celclassificaties behouden."
	)

	queue_redraw()


func _cancel_calibration() -> void:
	if not _calibration_active:
		return

	_data = _calibration_before

	_calibration_before = null
	_calibration_active = false

	_points.clear()
	_drag_index = -1
	_confirm_calibration.disabled = true

	_status.text = (
		"Kalibratie geannuleerd;"
		+ " vorige projectie hersteld."
	)

	queue_redraw()


func _save_new_version() -> void:
	if _data == null or _calibration_active:
		_status.text = (
			"Sluit eerst kalibratie af voordat je opslaat."
		)
		return

	var problem: String = _data.validation_error()

	if not problem.is_empty():
		_status.text = "Niet opgeslagen: " + problem
		return

	var directory: String = "res://assets/areas"

	var directory_error: Error = (
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(directory)
		)
	)

	if directory_error != OK:
		_status.text = (
			"Map aanmaken mislukt: "
			+ error_string(directory_error)
		)
		return

	var prefix: String = (
		save_prefix.validate_filename().strip_edges()
	)

	if prefix.is_empty():
		prefix = "exploration_area"

	var stamp: String = (
		Time.get_datetime_string_from_system()
		.replace(":", "-")
	)

	var base: String = (
		directory + "/" + prefix + "_" + stamp
	)

	var path: String = base + ".tres"
	var suffix: int = 1

	while FileAccess.file_exists(path):
		path = base + "_" + str(suffix) + ".tres"
		suffix += 1

	var saved: ExplorationAreaData = (
		_data.duplicate(true) as ExplorationAreaData
	)

	var save_error: Error = ResourceSaver.save(saved, path)

	if save_error != OK:
		_status.text = (
			"Opslaan mislukt: " + error_string(save_error)
		)
		return

	_dirty = false

	# This run continues with the new version.
	# Persist this Inspector choice after stopping the tool.
	source_area = path

	_status.text = (
		"Opgeslagen: " + path
		+ "\nNa F8: wijs dit toe aan gameplay Area Data"
		+ " én editor Source Area; sla scenes op."
	)

	print("[AreaEditor] Saved: ", path)

	print(
		"[AreaEditor] Assign to gameplay Area Data"
		+ " and editor Source Area after F8."
	)


func _draw() -> void:
	if _data == null:
		return

	for y in range(_data.grid_size.y):
		for x in range(_data.grid_size.x):
			var cell := Vector2i(x, y)

			var info: Dictionary = _data.get_cell_data(cell)
			var terrain: String = info["terrain"]

			var color := Color(0.2, 1.0, 0.4, 0.75)

			if not _data.is_cell_walkable(cell):
				color = Color(1.0, 0.2, 0.2, 0.75)

			if terrain.contains("WATER"):
				color = Color(0.2, 0.65, 1.0, 0.85)

			if terrain == "UNKNOWN":
				color = Color(0.65, 0.65, 0.65, 0.75)

			var outline: PackedVector2Array = (
				_data.get_cell_outline(cell)
			)

			var fill: Color = color
			fill.a = 0.15

			draw_colored_polygon(
				PackedVector2Array([
					outline[0],
					outline[1],
					outline[2],
					outline[3]
				]),
				fill
			)

			draw_polyline(outline, color, 2.0, true)

			if cell == _selection:
				draw_polyline(
					outline,
					Color.YELLOW,
					4.0,
					true
				)

			var tags: PackedStringArray = info["tags"]

			var lines: Array[String] = [
				"%d,%d" % [x, y],
				terrain
			]

			if not _data.is_cell_walkable(cell):
				lines.append("BLOCKED")

			if not tags.is_empty():
				lines.append(",".join(tags))

			var center: Vector2 = _data.get_cell_center(cell)

			for index in range(lines.size()):
				var line: String = lines[index]

				var width: float = (
					ThemeDB.fallback_font.get_string_size(
						line,
						HORIZONTAL_ALIGNMENT_LEFT,
						-1.0,
						12
					).x
				)

				var text_position: Vector2 = (
					center
					+ Vector2(
						-width * 0.5,
						-10 + index * 14
					)
				)

				draw_string_outline(
					ThemeDB.fallback_font,
					text_position,
					line,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1.0,
					12,
					3,
					Color.BLACK
				)

				draw_string(
					ThemeDB.fallback_font,
					text_position,
					line,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1.0,
					12,
					Color.WHITE
				)

	var colors: Array[Color] = [
		Color.WHITE,
		Color.ORANGE,
		Color.SKY_BLUE
	]

	var names: Array[String] = ["O", "X", "Y"]

	for index in range(_points.size()):
		var point: Vector2 = _points[index]

		if index > 0:
			draw_line(
				_points[0],
				point,
				colors[index],
				3.0,
				true
			)

		draw_circle(point, 9.0, colors[index])

		draw_circle(
			point,
			12.0,
			Color.BLACK,
			false,
			2.0,
			true
		)

		draw_string(
			ThemeDB.fallback_font,
			point + Vector2(14, -12),
			names[index],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			22,
			colors[index]
		)
