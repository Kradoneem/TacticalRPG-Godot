extends "res://scripts/systems/tactical_turn_controller.gd"

var input_suspended: bool = false


func refresh_notice() -> void:
	if player_marker == null or tactical_cursor == null:
		return

	_refresh_alert_state()


func set_input_suspended(suspended: bool) -> void:
	input_suspended = suspended

	player_marker.set_input_enabled(
		not suspended and is_free_exploration()
	)


func _unhandled_input(event: InputEvent) -> void:
	if input_suspended:
		return

	super._unhandled_input(event)


func _on_player_movement_requested(direction: Vector2i) -> void:
	if input_suspended:
		return

	super._on_player_movement_requested(direction)


func resume_after_player_action() -> void:
	if state != State.BATTLE_TRANSITION:
		return

	# A defeated final enemy must stop alert before its old turn is visited.
	_refresh_alert_state()

	if is_free_exploration():
		return

	super.resume_after_player_action()


func _begin_enemy_turn(active_enemy_marker: TacticalEnemy) -> void:
	# Defeated actors can still be present in the current round snapshot.
	if active_enemy_marker.is_defeated():
		_advance_to_next_turn()
		return

	super._begin_enemy_turn(active_enemy_marker)
