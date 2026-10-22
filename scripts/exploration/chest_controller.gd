extends Node

var _host: Node2D
var _player: TacticalPlayer
var _state: Node
var _permission: Callable
var _definitions: Array[ChestDefinition] = []

var _markers: Dictionary = {}
var _hint: Label
var _result: Label
var _configured: bool = false


func configure(
	host: Node2D,
	player: TacticalPlayer,
	grid: TacticalGrid,
	projection: TacticalGridProjection,
	state: Node,
	definitions: Array[ChestDefinition],
	exits: Array[ExplorationExitData],
	permission: Callable
) -> bool:
	if _configured:
		return false

	if (
		host == null
		or player == null
		or grid == null
		or projection == null
		or state == null
		or not permission.is_valid()
	):
		return false

	var ids: Dictionary = {}
	var interaction_cells: Dictionary = {}

	for definition: ChestDefinition in definitions:
		if definition == null:
			push_error("Lege chest-definition.")
			return false

		var problem: String = definition.validation_error()

		if not problem.is_empty():
			push_error(problem)
			return false

		if ids.has(definition.chest_id):
			push_error("Dubbel chest-ID op map.")
			return false

		ids[definition.chest_id] = true

		if not grid.is_walkable(definition.cell):
			push_error("Prototypechest staat buiten het walkable grid.")
			return false

		var has_access: bool = false

		for direction: Vector2i in [
			Vector2i.UP,
			Vector2i.DOWN,
			Vector2i.LEFT,
			Vector2i.RIGHT
		]:
			var adjacent_cell: Vector2i = definition.cell + direction

			if not grid.is_walkable(adjacent_cell):
				continue

			has_access = true

			if interaction_cells.has(adjacent_cell):
				push_error("Chest-interactiezones overlappen.")
				return false

			for exit_data: ExplorationExitData in exits:
				if exit_data != null and exit_data.contains_cell(adjacent_cell):
					push_error("Chest-interactie overlapt een exitcel.")
					return false

			interaction_cells[adjacent_cell] = true

		if not has_access:
			push_error("Chest heeft geen walkable adjacent cel.")
			return false

	_host = host
	_player = player
	_state = state
	_permission = permission
	_definitions.assign(definitions)

	for definition: ChestDefinition in _definitions:
		var marker := Label.new()
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.add_theme_font_size_override("font_size", 18)
		marker.add_theme_color_override("font_outline_color", Color.BLACK)
		marker.add_theme_constant_override("outline_size", 4)
		marker.z_index = 15
		marker.position = (
			projection.get_cell_center(definition.cell)
			+ Vector2(-65.0, -45.0)
		)

		_host.add_child(marker)
		_markers[definition.chest_id] = marker

	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)

	_hint = Label.new()
	_hint.position = Vector2(24.0, 850.0)
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hint)

	_result = Label.new()
	_result.position = Vector2(24.0, 890.0)
	_result.add_theme_font_size_override("font_size", 24)
	_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_result)

	_player.cell_changed.connect(_on_cell_changed)
	_state.chest_opened.connect(_on_chest_opened)

	_configured = true
	_refresh_markers()
	_refresh_hint()
	return true


func _allowed() -> bool:
	return (
		_configured
		and _host.can_process()
		and _permission.is_valid()
		and bool(_permission.call())
	)


func _find_adjacent() -> ChestDefinition:
	for definition: ChestDefinition in _definitions:
		var offset: Vector2i = definition.cell - _player.cell

		if absi(offset.x) + absi(offset.y) == 1:
			return definition

	return null


func try_open_adjacent() -> Dictionary:
	if not _allowed():
		return {
			"success": false,
			"message": "Chest-interactie is nu niet beschikbaar."
		}

	var definition: ChestDefinition = _find_adjacent()

	if definition == null:
		return {
			"success": false,
			"message": "Geen adjacent chest."
		}

	# Permission and adjacency are checked immediately before the commit.
	var result: Dictionary = _state.open_chest(definition.chest_id)

	_result.text = String(result.get("message", ""))
	_refresh_hint()
	return result


func _input(event: InputEvent) -> void:
	if not _allowed() or not event is InputEventKey:
		return

	if not event.is_pressed() or event.is_echo():
		return

	var key_event := event as InputEventKey

	if key_event.keycode not in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		return

	if _find_adjacent() == null:
		return

	get_viewport().set_input_as_handled()
	try_open_adjacent()


func _process(_delta: float) -> void:
	if not _configured:
		return

	var allowed: bool = _allowed()
	_hint.visible = allowed
	_result.visible = allowed


func _on_cell_changed(
	_previous_cell: Vector2i,
	_new_cell: Vector2i
) -> void:
	_result.text = ""
	_refresh_hint()


func _on_chest_opened(_chest_id: StringName) -> void:
	_refresh_markers()
	_refresh_hint()


func _refresh_markers() -> void:
	for definition: ChestDefinition in _definitions:
		var marker: Label = _markers.get(definition.chest_id) as Label

		if marker == null:
			continue

		var opened: bool = _state.is_chest_opened(definition.chest_id)
		marker.text = "[OPEN]" if opened else "[CHEST]"
		marker.modulate = Color("#aaa89c") if opened else Color("#ffe183")


func _refresh_hint() -> void:
	if _hint == null:
		return

	var definition: ChestDefinition = _find_adjacent()

	if definition == null:
		_hint.text = ""
	elif _state.is_chest_opened(definition.chest_id):
		_hint.text = "%s — geopend." % definition.display_name
	else:
		_hint.text = "%s — Enter/Spatie: openen." % definition.display_name
