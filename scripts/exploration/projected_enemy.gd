extends "res://scripts/systems/tactical_enemy.gd"

## Logical cells, AI and Squad ownership remain with TacticalEnemy.
var projection: TacticalGridProjection


func get_cell_center(target_cell: Vector2i) -> Vector2:
	if projection != null:
		return projection.get_cell_center(target_cell)

	return super.get_cell_center(target_cell)
