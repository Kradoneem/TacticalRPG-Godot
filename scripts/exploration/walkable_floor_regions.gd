class_name WalkableFloorRegions
extends Node2D

## Editor-authored floor regions.
## Direct Polygon2D children describe floor or blocked areas.
## They are authoring helpers, not physics collision objects.

const BLOCKED_GROUP: StringName = &"blocked_floor_region"


func _ready() -> void:
	# Keep authoring polygons visible in the editor, not in the game.
	hide()


func apply_to_grid(
	grid: TacticalGrid,
	projection: TacticalGridProjection,
	map_root: Node2D
) -> void:
	var floor_polygons: Array[PackedVector2Array] = []
	var blocked_polygons: Array[PackedVector2Array] = []

	for child: Node in get_children():
		if not child is Polygon2D:
			continue

		var region := child as Polygon2D

		if region.polygon.size() < 3:
			continue

		var points := PackedVector2Array()

		for point: Vector2 in region.polygon:
			points.append(map_root.to_local(region.to_global(point)))

		if region.is_in_group(BLOCKED_GROUP):
			blocked_polygons.append(points)
		else:
			floor_polygons.append(points)

	if floor_polygons.is_empty():
		push_warning(
			"WalkableFloor has no floor polygons; all cells are blocked."
		)

	var walkable_count: int = 0

	for row in range(grid.size.y):
		for column in range(grid.size.x):
			var cell := Vector2i(column, row)
			var walkable: bool = _cell_is_on_floor(
				cell,
				projection,
				floor_polygons,
				blocked_polygons
			)

			grid.set_blocked(cell, not walkable)

			if walkable:
				walkable_count += 1

	print(
		"[WalkableFloor] ",
		walkable_count,
		" / ",
		grid.size.x * grid.size.y,
		" cells walkable"
	)


func _cell_is_on_floor(
	cell: Vector2i,
	projection: TacticalGridProjection,
	floor_polygons: Array[PackedVector2Array],
	blocked_polygons: Array[PackedVector2Array]
) -> bool:
	var sample_offsets: Array[Vector2] = [
		Vector2(0.5, 0.5),
		Vector2(0.05, 0.05),
		Vector2(0.95, 0.05),
		Vector2(0.95, 0.95),
		Vector2(0.05, 0.95)
	]

	for sample_offset: Vector2 in sample_offsets:
		var point: Vector2 = projection.grid_to_map(
			Vector2(cell) + sample_offset
		)

		if not _point_in_any_polygon(point, floor_polygons):
			return false

		if _point_in_any_polygon(point, blocked_polygons):
			return false

	return true


func _point_in_any_polygon(
	point: Vector2,
	polygons: Array[PackedVector2Array]
) -> bool:
	for polygon: PackedVector2Array in polygons:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true

	return false
