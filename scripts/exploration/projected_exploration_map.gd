extends Node2D

## Shared gameplay base. Authoring lives in scenes/tools/exploration_area_editor.tscn.
## Legacy exports remain compatible with existing scenes during migration.

const GridProjectionData = preload("res://scripts/systems/tactical_grid_projection.gd")

@export var grid_size: Vector2i = Vector2i(5, 4)
@export var start_cell: Vector2i = Vector2i(1, 1)
@export var grid_origin: Vector2 = Vector2(840.0, 355.0)
@export var grid_axis_x: Vector2 = Vector2(100.0, 57.0)
@export var grid_axis_y: Vector2 = Vector2(-64.0, 65.0)
@export var grid_calibration: GridProjectionData
@export var area_data: ExplorationAreaData
@export var show_debug_grid: bool = true
@export var show_cell_coordinates: bool = true

@onready var player_marker: TacticalPlayer = $PlayerMarker

var tactical_grid: TacticalGrid
var projection: GridProjectionData
var _hint: Label
# Temporary read-only compatibility for the existing entrance exit adapter.
# This map has no authoring mode; the standalone editor cannot mutate gameplay.
var _calibrating: bool = false


func _ready() -> void:
	player_marker.set_input_enabled(false)
	projection = GridProjectionData.new()
	if area_data != null:
		var problem: String = area_data.validation_error()
		if not problem.is_empty():
			push_error(problem)
			return
		grid_size = area_data.grid_size
		projection.origin = area_data.origin
		projection.axis_x = area_data.axis_x
		projection.axis_y = area_data.axis_y
		var background: Sprite2D = get_node_or_null("Background") as Sprite2D
		if background != null and not area_data.background_path.is_empty():
			var texture: Texture2D = load(area_data.background_path) as Texture2D
			if texture == null:
				push_error("Area background could not be loaded.")
				return
			background.texture = texture
	elif grid_calibration != null:
		projection.origin = grid_calibration.origin
		projection.axis_x = grid_calibration.axis_x
		projection.axis_y = grid_calibration.axis_y
	else:
		projection.origin = grid_origin
		projection.axis_x = grid_axis_x
		projection.axis_y = grid_axis_y
	if grid_size.x <= 0 or grid_size.y <= 0:
		push_error("Exploration map requires a positive grid size.")
		return
	if not _axes_are_valid(projection.axis_x, projection.axis_y):
		push_error("Grid axes must not be parallel or zero.")
		return
	tactical_grid = TacticalGrid.new(grid_size)
	_configure_tactical_grid()
	if not tactical_grid.is_walkable(start_cell):
		push_error("Start/arrival cell is blocked: " + str(start_cell))
		tactical_grid = null
		return
	if GameState.get_main_squad() == null:
		GameState.start_new_game()
	var main_squad: Squad = GameState.get_main_squad()
	if main_squad == null:
		push_error("Exploration map could not find a Main Squad.")
		tactical_grid = null
		return
	player_marker.configure(
		tactical_grid, Vector2.ZERO, 42.0, start_cell, main_squad, projection
	)
	player_marker.movement_requested.connect(_on_movement_requested)
	var layer := CanvasLayer.new()
	add_child(layer)
	_hint = Label.new()
	_hint.position = Vector2(16.0, 16.0)
	_hint.text = "WASD: squad bewegen | Authoring: losse Area Editor-scene (F6)"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hint)
	player_marker.set_input_enabled(true)
	queue_redraw()


func _configure_tactical_grid() -> void:
	if area_data != null:
		area_data.apply_to_grid(tactical_grid)


func _axes_are_valid(axis_x: Vector2, axis_y: Vector2) -> bool:
	return (
		axis_x.is_finite() and axis_y.is_finite()
		and axis_x.length() >= 1.0 and axis_y.length() >= 1.0
		and absf(axis_x.normalized().cross(axis_y.normalized())) > 0.05
	)


func _on_movement_requested(direction: Vector2i) -> void:
	if player_marker.move_by(direction):
		print("Exploration Main Squad cell: ", player_marker.cell)
	get_viewport().set_input_as_handled()


func _draw() -> void:
	if not show_debug_grid or tactical_grid == null or projection == null:
		return
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell := Vector2i(x, y)
			var color := Color(0.2, 1.0, 0.4, 0.8)
			if not tactical_grid.is_walkable(cell):
				color = Color(1.0, 0.2, 0.2, 0.8)
			var text: String = "%d,%d" % [x, y]
			if area_data != null:
				var info: Dictionary = area_data.get_cell_data(cell)
				if String(info["terrain"]) == "UNKNOWN":
					color = Color(0.65, 0.65, 0.65, 0.8)
				var tags: PackedStringArray = info["tags"]
				if not tags.is_empty():
					text += "\n" + ",".join(tags)
			var outline: PackedVector2Array = projection.get_cell_outline(cell)
			var fill: Color = color
			fill.a = 0.12
			draw_colored_polygon(PackedVector2Array([
				outline[0], outline[1], outline[2], outline[3]
			]), fill)
			draw_polyline(outline, color, 2.0, true)
			if show_cell_coordinates:
				var center: Vector2 = projection.get_cell_center(cell)
				var lines: PackedStringArray = text.split("\n")
				for line_index in range(lines.size()):
					var line: String = lines[line_index]
					var width: float = ThemeDB.fallback_font.get_string_size(
						line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14
					).x
					var position_in_map: Vector2 = center + Vector2(-width * 0.5, 5 + line_index * 16)
					draw_string_outline(ThemeDB.fallback_font, position_in_map, line,
						HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, 3, Color.BLACK)
					draw_string(ThemeDB.fallback_font, position_in_map, line,
						HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color.WHITE)


func prepare_exploration_entry(context: ExplorationEntryContext) -> bool:
	if context == null or context.main_squad == null:
		push_error("Exploration entry requires an existing Main Squad.")
		return false
	var arrival: Vector2i = context.arrival_cell
	var size: Vector2i = area_data.grid_size if area_data != null else grid_size
	if arrival.x < 0 or arrival.y < 0 or arrival.x >= size.x or arrival.y >= size.y:
		push_error("Arrival cell outside destination grid: " + str(arrival))
		return false
	if area_data != null:
		if not area_data.validation_error().is_empty() or not area_data.is_cell_walkable(arrival):
			push_error("Destination area data invalid or arrival cell blocked.")
			return false
	if is_node_ready():
		if player_marker.squad != context.main_squad:
			push_error("Retained map has a different Main Squad.")
			return false
		if player_marker.cell != arrival:
			push_error("Retained map arrival differs from departure cell.")
			return false
	else:
		start_cell = arrival
	return true
