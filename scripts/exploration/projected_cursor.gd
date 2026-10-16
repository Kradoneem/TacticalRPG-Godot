extends "res://scripts/systems/tactical_cursor.gd"

var projection: TacticalGridProjection


func get_cell_center(target_cell: Vector2i) -> Vector2:
	if projection != null:
		return projection.get_cell_center(target_cell)

	return super.get_cell_center(target_cell)


func _draw() -> void:
	if not _visible:
		return

	if projection == null:
		super._draw()
		return

	var outline: PackedVector2Array = (
		projection.get_cell_outline(cell)
	)

	# Drawing coordinates are local to this cursor node.
	for index in range(outline.size()):
		outline[index] -= position

	draw_polyline(outline, Color("#ffe183"), 4.0, true)
	draw_circle(Vector2.ZERO, 7.0, Color("#fff6bc"))
