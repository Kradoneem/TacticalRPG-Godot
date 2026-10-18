extends "res://scripts/exploration/projected_exploration_map.gd"

## Entrance-specific adapter. Calibration UI no longer lives in this area.


func on_exploration_entered(_context: ExplorationEntryContext) -> void:
	GameState.current_location = "Sewer Entrance"
	GameState.in_city = false
	var exit_adapter: Node = get_node_or_null("ExitInteractions")
	if exit_adapter != null and exit_adapter.has_method("resume_exploration"):
		exit_adapter.call("resume_exploration")
