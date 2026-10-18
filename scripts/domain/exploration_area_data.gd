class_name ExplorationAreaData
extends TacticalGridProjection

## Authored map data, never active squad/turn/savegame state.
## Inherits origin/axis_x/axis_y from TacticalGridProjection.
## Keys in cells are "x,y" strings; omitted cells use the declared defaults.
## New areas fail closed. The migration fixture explicitly preserves old FLOOR data.

@export var grid_size: Vector2i = Vector2i(17, 9)
@export_file("*.png", "*.webp", "*.jpg") var background_path: String = ""
@export var default_terrain: StringName = &"UNKNOWN"
@export var default_walkable: bool = false
@export var cells: Dictionary = {}


func contains(cell: Vector2i) -> bool:
	return (
		cell.x >= 0 and cell.y >= 0
		and cell.x < grid_size.x and cell.y < grid_size.y
	)


func cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func get_cell_data(cell: Vector2i) -> Dictionary:
	var fallback: Dictionary = {
		"terrain": String(default_terrain),
		"walkable": default_walkable,
		"tags": PackedStringArray(),
		"content_id": ""
	}
	if not contains(cell):
		fallback["terrain"] = "UNKNOWN"
		fallback["walkable"] = false
		return fallback
	if not cells.has(cell_key(cell)):
		return fallback
	return (cells[cell_key(cell)] as Dictionary).duplicate(true)


func set_cell_data(
	cell: Vector2i,
	terrain: String,
	walkable: bool,
	tags: PackedStringArray,
	content_id: String
) -> void:
	if not contains(cell):
		return
	var normalized: String = terrain.strip_edges().to_upper()
	if normalized.is_empty():
		normalized = "UNKNOWN"
	var clean_tags := PackedStringArray()
	for tag: String in tags:
		var clean: String = tag.strip_edges().to_upper()
		if not clean.is_empty() and not clean_tags.has(clean):
			clean_tags.append(clean)
	cells[cell_key(cell)] = {
		"terrain": normalized,
		"walkable": walkable and normalized != "UNKNOWN",
		"tags": clean_tags,
		"content_id": content_id.strip_edges()
	}
	emit_changed()


func is_cell_walkable(cell: Vector2i) -> bool:
	if not contains(cell):
		return false
	var info: Dictionary = get_cell_data(cell)
	return String(info["terrain"]) != "UNKNOWN" and bool(info["walkable"])


func cells_with_tag(tag: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var wanted: String = tag.strip_edges().to_upper()
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell := Vector2i(x, y)
			var tags: PackedStringArray = get_cell_data(cell).get("tags", PackedStringArray())
			if tags.has(wanted):
				result.append(cell)
	return result


func validation_error() -> String:
	if grid_size.x <= 0 or grid_size.y <= 0:
		return "Gridafmetingen moeten positief zijn."
	if not origin.is_finite() or not axis_x.is_finite() or not axis_y.is_finite():
		return "Projectie bevat niet-eindige waarden."
	if axis_x.length() < 1.0 or axis_y.length() < 1.0:
		return "Gridassen zijn te kort."
	if absf(axis_x.normalized().cross(axis_y.normalized())) <= 0.05:
		return "Gridassen zijn bijna parallel."
	if String(default_terrain).strip_edges().is_empty():
		return "Default terrain ontbreekt."
	for key: Variant in cells:
		if not key is String:
			return "Celkeys moeten strings zijn."
		var parts: PackedStringArray = String(key).split(",")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			return "Ongeldige celkey: " + String(key)
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		if not contains(cell) or cell_key(cell) != String(key):
			return "Celkey buiten grid of niet canoniek: " + String(key)
		if not cells[key] is Dictionary:
			return "Celdata is geen Dictionary: " + String(key)
		var info: Dictionary = cells[key]
		if not info.get("terrain") is String:
			return "Terrain ontbreekt bij " + String(key)
		if String(info["terrain"]).strip_edges().is_empty():
			return "Terrain is leeg bij " + String(key)
		if not info.get("walkable") is bool:
			return "Walkable ontbreekt bij " + String(key)
		if not info.get("tags") is PackedStringArray:
			return "Tags ontbreken bij " + String(key)
		if not info.get("content_id") is String:
			return "Content ID ontbreekt bij " + String(key)
	return ""


func apply_to_grid(grid: TacticalGrid) -> void:
	var valid: bool = validation_error().is_empty() and grid.size == grid_size
	for y in range(grid.size.y):
		for x in range(grid.size.x):
			var cell := Vector2i(x, y)
			grid.set_blocked(cell, not valid or not is_cell_walkable(cell))
	if not valid:
		push_error("Area data invalid or grid size mismatch; grid blocked.")
