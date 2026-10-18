extends Node2D

## Standalone authoring only. Saves new files; never changes live gameplay.
## Coordinate shift is relative to Source Area at the start of this run.
@export_file("*.tres") var source_area: String = "res://assets/areas/sewer_junction_authoring_v1.tres"
@export var save_prefix: String = "sewer_junction"

var _data: ExplorationAreaData
var _history: Array[Dictionary] = []
var _selection := Vector2i(-1, -1)
var _coordinate_shift := Vector2i.ZERO
var _background: Sprite2D
var _camera: Camera2D
var _scroll: ScrollContainer
var _status: Label
var _grid_info: Label
var _selected_label: Label
var _terrain: LineEdit
var _walkable: CheckBox
var _tags: LineEdit
var _content_id: LineEdit
var _x_steps: SpinBox
var _y_steps: SpinBox
var _confirm_calibration: Button
var _reload_dialog: ConfirmationDialog
var _expand_dialog: ConfirmationDialog
var _pending_side := Vector2i.ZERO
var _dirty := false
var _panning := false
var _calibration_active := false
var _calibration_before: Dictionary = {}
var _points: Array[Vector2] = []
var _drag_index := -1
var _candidate_valid := false


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
	layer.add_child(panel)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(420, 850)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	_scroll.add_child(column)
	_add_label(column, "AREA AUTHORING — geen gameplay")
	_status = _add_label(column, "")
	_grid_info = _add_label(column, "")
	_add_label(column, "Klik: selecteren | MMB: slepen | Wiel: zoom\nHome: centreren (buiten tekstvelden)")
	_selected_label = _add_label(column, "Geen cel geselecteerd")
	_add_label(column, "Terrain (vrij label):")
	_terrain = LineEdit.new()
	column.add_child(_terrain)
	_walkable = CheckBox.new()
	_walkable.text = "Begaanbaar (UNKNOWN blijft blocked)"
	column.add_child(_walkable)
	_add_label(column, "Tags, gescheiden door komma's:")
	_tags = LineEdit.new()
	_tags.placeholder_text = "EXIT, TREASURE"
	column.add_child(_tags)
	_add_label(column, "Content ID (optioneel):")
	_content_id = LineEdit.new()
	column.add_child(_content_id)
	_add_button(column, "Cel toepassen", _apply_cell)
	_add_button(column, "Ongedaan maken", _undo_last)
	_add_label(column, "GRID UITBREIDEN — één rij/kolom per klik")
	_add_button(column, "Kolom vóór X=0 (linksboven)", _request_expand.bind(Vector2i.LEFT))
	_add_button(column, "Kolom na laatste X (rechtsbeneden)", _request_expand.bind(Vector2i.RIGHT))
	_add_button(column, "Rij vóór Y=0 (rechtsboven)", _request_expand.bind(Vector2i.UP))
	_add_button(column, "Rij na laatste Y (linksbeneden)", _request_expand.bind(Vector2i.DOWN))
	_add_label(column, "Richtingen hierboven gelden voor de junction-projectie.\nNieuw: UNKNOWN/blocked. Vóór nul: coördinaten verschuiven.")
	_add_label(column, "KALIBRATIE — tel afstanden, niet kruispunten")
	_x_steps = _add_steps(column, "Stappen O → X")
	_y_steps = _add_steps(column, "Stappen O → Y")
	_x_steps.value_changed.connect(_on_steps_changed)
	_y_steps.value_changed.connect(_on_steps_changed)
	_add_button(column, "Nieuwe kalibratie: O, X, Y", _begin_calibration)
	_confirm_calibration = _add_button(column, "Kalibratie toepassen", _accept_calibration)
	_confirm_calibration.disabled = true
	_add_button(column, "Kalibratie annuleren", _cancel_calibration)
	_add_button(column, "Opslaan als NIEUWE Resource", _save_new_version)
	_add_button(column, "Source Area opnieuw laden", _request_reload)
	_reload_dialog = ConfirmationDialog.new()
	_reload_dialog.dialog_text = "Wijzigingen weggooien en Source Area opnieuw laden?"
	_reload_dialog.confirmed.connect(_load_source)
	layer.add_child(_reload_dialog)
	_expand_dialog = ConfirmationDialog.new()
	_expand_dialog.confirmed.connect(_confirm_expand)
	layer.add_child(_expand_dialog)


func _add_label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 390
	parent.add_child(label)
	return label


func _add_button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _add_steps(parent: Node, text: String) -> SpinBox:
	_add_label(parent, text)
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = 256
	spin.step = 1
	parent.add_child(spin)
	return spin


func _load_source() -> void:
	var loaded := ResourceLoader.load(source_area, "", ResourceLoader.CACHE_MODE_IGNORE) as ExplorationAreaData
	if loaded == null:
		_status.text = "Geen ExplorationAreaData: " + source_area
		return
	var problem: String = loaded.validation_error()
	if not problem.is_empty():
		_status.text = problem
		return
	var texture := load(loaded.background_path) as Texture2D
	if texture == null:
		_status.text = "Achtergrond ontbreekt: " + loaded.background_path
		return
	_data = loaded.duplicate(true) as ExplorationAreaData
	_background.texture = texture
	_history.clear()
	_selection = Vector2i(-1, -1)
	_coordinate_shift = Vector2i.ZERO
	_calibration_active = false
	_calibration_before = {}
	_points.clear()
	_drag_index = -1
	_candidate_valid = false
	_confirm_calibration.disabled = true
	_dirty = false
	_x_steps.set_value_no_signal(_data.grid_size.x)
	_y_steps.set_value_no_signal(_data.grid_size.y)
	_camera.zoom = Vector2.ONE
	_center_grid()
	_refresh_fields()
	_status.text = "Geladen: " + source_area
	queue_redraw()


func _snapshot() -> Dictionary:
	return {"data": _data.duplicate(true), "selection": _selection, "shift": _coordinate_shift}


func _remember(snapshot: Dictionary) -> void:
	_history.append(snapshot)
	if _history.size() > 50:
		_history.pop_front()


func _restore(snapshot: Dictionary) -> void:
	_data = snapshot["data"] as ExplorationAreaData
	_selection = snapshot["selection"]
	_coordinate_shift = snapshot["shift"]
	_refresh_fields()
	queue_redraw()


func _refresh_fields() -> void:
	_grid_info.text = "Grid: %d × %d\nCoördinatenoffset sinds laden: (%d, %d)\nOude cel + offset = nieuwe cel." % [_data.grid_size.x, _data.grid_size.y, _coordinate_shift.x, _coordinate_shift.y]
	if not _data.contains(_selection):
		_selection = Vector2i(-1, -1)
		_selected_label.text = "Geen cel geselecteerd"
		_terrain.clear()
		_tags.clear()
		_content_id.clear()
		_walkable.button_pressed = false
		return
	var info: Dictionary = _data.get_cell_data(_selection)
	_selected_label.text = "Cel: " + str(_selection)
	_terrain.text = String(info["terrain"])
	_walkable.button_pressed = bool(info["walkable"])
	var tags: PackedStringArray = info["tags"]
	_tags.text = ", ".join(tags)
	_content_id.text = String(info["content_id"])


func _apply_cell() -> void:
	if _data == null or _calibration_active or not _data.contains(_selection):
		_status.text = "Selecteer een cel en sluit kalibratie af."
		return
	_remember(_snapshot())
	_data.set_cell_data(_selection, _terrain.text, _walkable.button_pressed, _tags.text.split(",", false), _content_id.text)
	_dirty = true
	_refresh_fields()
	_status.text = "Cel toegepast; nog niet opgeslagen."
	queue_redraw()


func _undo_last() -> void:
	if _calibration_active or _history.is_empty():
		_status.text = "Sluit kalibratie af / geen Undo beschikbaar."
		return
	var snapshot: Dictionary = _history.pop_back()
	_restore(snapshot)
	_dirty = true
	_status.text = "Undo: data, selectie en coördinatenoffset hersteld."


func _request_expand(side: Vector2i) -> void:
	if _data == null or _calibration_active:
		_status.text = "Sluit eerst kalibratie af."
		return
	if side == Vector2i.LEFT or side == Vector2i.UP:
		_pending_side = side
		var shift := Vector2i(1, 0) if side == Vector2i.LEFT else Vector2i(0, 1)
		_expand_dialog.dialog_text = "Bestaande cellen blijven visueel op hun plek.\nHun coördinaten verschuiven met %s.\nPas later startcel, aankomstcellen en eventuele spawns/routes handmatig aan.\nDe editor wijzigt geen gameplay-scenes. Doorgaan?" % str(shift)
		_expand_dialog.popup_centered()
	else:
		_expand_grid(side)


func _confirm_expand() -> void:
	_expand_grid(_pending_side)


func _expand_grid(side: Vector2i) -> void:
	if _data == null or _calibration_active:
		return
	if side not in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		return
	var old_size: Vector2i = _data.grid_size
	var growth := Vector2i(1, 0) if side.x != 0 else Vector2i(0, 1)
	var shift := Vector2i.ZERO
	if side == Vector2i.LEFT:
		shift.x = 1
	elif side == Vector2i.UP:
		shift.y = 1
	_remember(_snapshot())
	var candidate := _data.duplicate(true) as ExplorationAreaData
	candidate.grid_size = old_size + growth
	candidate.origin = _data.origin - _data.axis_x * shift.x - _data.axis_y * shift.y
	candidate.cells = {}
	# Materialize old defaults as well as overrides: no old cell is lost.
	for y in range(old_size.y):
		for x in range(old_size.x):
			var old_cell := Vector2i(x, y)
			candidate.cells[candidate.cell_key(old_cell + shift)] = _data.get_cell_data(old_cell)
	# Explicit overrides protect new cells even with default_walkable=true.
	for y in range(candidate.grid_size.y):
		for x in range(candidate.grid_size.x):
			var cell := Vector2i(x, y)
			var key: String = candidate.cell_key(cell)
			if not candidate.cells.has(key):
				candidate.cells[key] = {"terrain": "UNKNOWN", "walkable": false, "tags": PackedStringArray(), "content_id": ""}
	_data = candidate
	if _selection.x >= 0:
		_selection += shift
	_coordinate_shift += shift
	_dirty = true
	_refresh_fields()
	_status.text = "Grid uitgebreid; nieuw UNKNOWN/blocked. Controleer de coördinatenoffset vóór gameplay."
	queue_redraw()


func _request_reload() -> void:
	if _dirty or _calibration_active:
		_reload_dialog.popup_centered()
	else:
		_load_source()


func _center_grid() -> void:
	if _data != null:
		_camera.position = _data.grid_to_map(Vector2(_data.grid_size) * 0.5)


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
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mouse.pressed
		elif mouse.pressed and mouse.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var factor: float = 1.1 if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1
			_camera.zoom = Vector2.ONE * clampf(_camera.zoom.x * factor, 0.25, 3.0)
		elif mouse.button_index == MOUSE_BUTTON_LEFT:
			if not mouse.pressed:
				_drag_index = -1
			elif _calibration_active:
				_choose_calibration_point(get_local_mouse_position())
			else:
				_select_cell_at(get_local_mouse_position())
		else:
			return
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
	if _scroll != null:
		_scroll.custom_minimum_size.y = maxf(200.0, get_viewport_rect().size.y - 32.0)
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		_panning = false
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_drag_index = -1


func _select_cell_at(point: Vector2) -> void:
	var determinant: float = _data.axis_x.cross(_data.axis_y)
	if absf(determinant) < 0.001:
		return
	var relative: Vector2 = point - _data.origin
	var cell := Vector2i(floori(relative.cross(_data.axis_y) / determinant), floori(_data.axis_x.cross(relative) / determinant))
	if not _data.contains(cell):
		_status.text = "Klik buiten grid."
		return
	_selection = cell
	_refresh_fields()
	queue_redraw()


func _begin_calibration() -> void:
	if _data == null or _calibration_active:
		return
	_calibration_before = _snapshot()
	_calibration_active = true
	_candidate_valid = false
	_points.clear()
	_drag_index = -1
	_confirm_calibration.disabled = true
	_status.text = "Kies O: hoek van cel (0,0), niet het midden."
	queue_redraw()


func _choose_calibration_point(point: Vector2) -> void:
	if _points.size() < 3:
		_points.append(point)
		_update_calibration_candidate()
		return
	_drag_index = -1
	var nearest: float = 18.0 / _camera.zoom.x
	for index in range(_points.size()):
		var distance: float = point.distance_to(_points[index])
		if distance < nearest:
			nearest = distance
			_drag_index = index


func _on_steps_changed(_value: float) -> void:
	if _calibration_active:
		_update_calibration_candidate()


func _update_calibration_candidate() -> void:
	_candidate_valid = false
	_confirm_calibration.disabled = true
	if _points.size() < 3:
		_status.text = "Kies X langs +X." if _points.size() == 1 else "Kies Y langs +Y."
	else:
		var axis_x: Vector2 = (_points[1] - _points[0]) / _x_steps.value
		var axis_y: Vector2 = (_points[2] - _points[0]) / _y_steps.value
		if axis_x.length() < 1.0 or axis_y.length() < 1.0:
			_status.text = "Punten te dicht bij elkaar."
		elif absf(axis_x.normalized().cross(axis_y.normalized())) <= 0.05:
			_status.text = "Assen bijna parallel."
		else:
			_data.origin = _points[0]
			_data.axis_x = axis_x
			_data.axis_y = axis_y
			_candidate_valid = true
			_confirm_calibration.disabled = false
			_status.text = "Preview: sleep O/X/Y; toepassen of annuleren."
	queue_redraw()


func _accept_calibration() -> void:
	if not _calibration_active or not _candidate_valid:
		return
	_remember(_calibration_before)
	_calibration_before = {}
	_calibration_active = false
	_points.clear()
	_drag_index = -1
	_confirm_calibration.disabled = true
	_dirty = true
	_status.text = "Kalibratie toegepast; celdata behouden. Nog niet opgeslagen."
	queue_redraw()


func _cancel_calibration() -> void:
	if not _calibration_active:
		return
	_restore(_calibration_before)
	_calibration_before = {}
	_calibration_active = false
	_points.clear()
	_drag_index = -1
	_confirm_calibration.disabled = true
	_status.text = "Kalibratie geannuleerd."
	queue_redraw()


func _save_new_version() -> void:
	if _data == null or _calibration_active:
		_status.text = "Sluit eerst kalibratie af."
		return
	var problem: String = _data.validation_error()
	if not problem.is_empty():
		_status.text = problem
		return
	var directory: String = "res://assets/areas"
	var error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if error != OK:
		_status.text = error_string(error)
		return
	var prefix: String = save_prefix.validate_filename().strip_edges()
	if prefix.is_empty():
		prefix = "exploration_area"
	var base: String = directory + "/" + prefix + "_" + Time.get_datetime_string_from_system().replace(":", "-")
	var path: String = base + ".tres"
	var suffix: int = 1
	while FileAccess.file_exists(path):
		path = base + "_" + str(suffix) + ".tres"
		suffix += 1
	var saved := _data.duplicate(true) as ExplorationAreaData
	error = ResourceSaver.save(saved, path)
	if error != OK:
		_status.text = error_string(error)
		return
	_dirty = false
	# Keep Source Area fixed this run: the displayed shift remains relative to it.
	_status.text = "Opgeslagen: " + path + "\nNa F8: wijs toe aan Area Data én Source Area. Pas externe cellen aan met offset " + str(_coordinate_shift) + "."
	print("[AreaEditor] Saved: ", path)
	print("[AreaEditor] External cell shift relative to Source Area: ", _coordinate_shift)


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
			var outline: PackedVector2Array = _data.get_cell_outline(cell)
			var fill: Color = color
			fill.a = 0.15
			draw_colored_polygon(PackedVector2Array([outline[0], outline[1], outline[2], outline[3]]), fill)
			draw_polyline(outline, color, 2.0, true)
			if cell == _selection:
				draw_polyline(outline, Color.YELLOW, 4.0, true)
			var tags: PackedStringArray = info["tags"]
			var lines: Array[String] = ["%d,%d" % [x, y], terrain]
			if not _data.is_cell_walkable(cell):
				lines.append("BLOCKED")
			if not tags.is_empty():
				lines.append(",".join(tags))
			for index in range(lines.size()):
				var line: String = lines[index]
				var width: float = ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12).x
				var position_in_map: Vector2 = _data.get_cell_center(cell) + Vector2(-width * 0.5, -10 + index * 14)
				draw_string_outline(ThemeDB.fallback_font, position_in_map, line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, 3, Color.BLACK)
				draw_string(ThemeDB.fallback_font, position_in_map, line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color.WHITE)
	var colors: Array[Color] = [Color.WHITE, Color.ORANGE, Color.SKY_BLUE]
	var names: Array[String] = ["O", "X", "Y"]
	for index in range(_points.size()):
		if index > 0:
			draw_line(_points[0], _points[index], colors[index], 3.0, true)
		draw_circle(_points[index], 9.0, colors[index])
		draw_string(ThemeDB.fallback_font, _points[index] + Vector2(14, -12), names[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, colors[index])
