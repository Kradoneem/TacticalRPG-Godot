extends "res://scripts/systems/tactical_enemy.gd"

## Projected tactical token with an explicit session-state interface.
## Squad references are shared, never duplicated.

var projection: TacticalGridProjection


func get_cell_center(target_cell: Vector2i) -> Vector2:
	if projection != null:
		return projection.get_cell_center(target_cell)

	return super.get_cell_center(target_cell)


func capture_session_state() -> Dictionary:
	var saved_route: Array[Vector2i] = []
	saved_route.assign(_patrol_route)

	return {
		"squad": squad,
		"cell": cell,
		"ai_mode": int(ai_mode),
		"patrol_route": saved_route,
		"patrol_index": _patrol_index
	}


func restore_session_state(saved_state: Dictionary) -> void:
	var saved_route: Array[Vector2i] = []
	saved_route.assign(saved_state.get("patrol_route", []))

	var saved_ai: int = int(
		saved_state.get("ai_mode", AiMode.STATIC)
	)

	if saved_ai == AiMode.PATROL and saved_route.size() >= 2:
		configure_patrol(saved_route)

		if ai_mode == AiMode.PATROL:
			_patrol_index = posmod(
				int(saved_state.get("patrol_index", 0)),
				_patrol_route.size()
			)
	else:
		ai_mode = AiMode.STATIC
		_patrol_route.clear()
		_patrol_index = 0

	# configure_patrol may temporarily put the token at waypoint zero.
	# Restore the saved logical position afterwards.
	cell = saved_state["cell"]
	position = get_cell_center(cell)

	if not squad.is_alive():
		set_defeated()
		hide()

	queue_redraw()
