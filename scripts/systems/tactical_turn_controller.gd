class_name TacticalTurnController

extends Node

## Owns tactical turn state only.
## It does not resolve side-view battles and does not own Squad or Unit data.

const NOTICE_DISTANCE: int = 10


signal state_changed(new_state: int)
signal player_turn_started(
	movement_budget: int,
	initiative: int
)
signal enemy_turn_started(enemy_marker: TacticalEnemy)
signal adjacent_enemies_available(
	adjacent_enemies: Array[TacticalEnemy]
)

enum State {
	FREE_EXPLORATION,
	ALERT_PLAYER_TURN,
	TACTICAL_ACTION_MENU,
	BATTLE_TRANSITION,
	ALERT_ENEMY_TURNS
}


var player_marker: TacticalPlayer
var enemy_markers: Array[TacticalEnemy] = []

var state: State = State.FREE_EXPLORATION
var remaining_player_movement: int = 0

var _turn_order: Array[Node] = []
var _turn_index: int = -1


func configure(
	assigned_player_marker: TacticalPlayer,
	assigned_enemy_markers: Array[TacticalEnemy]
) -> void:
	player_marker = assigned_player_marker
	enemy_markers = assigned_enemy_markers

	if player_marker == null:
		push_error("TacticalTurnController requires a TacticalPlayer.")
		return

	player_marker.movement_requested.connect(
		_on_player_movement_requested
	)
	player_marker.cell_changed.connect(_on_player_cell_changed)

	player_marker.set_input_enabled(true)


func is_free_exploration() -> bool:
	return state == State.FREE_EXPLORATION

func _unhandled_input(event: InputEvent) -> void:
	if state != State.ALERT_PLAYER_TURN:
		return

	if not event.is_action_pressed("ui_accept"):
		return

	if _open_tactical_action_menu_if_possible():
		get_viewport().set_input_as_handled()
		return

	end_player_turn()
	get_viewport().set_input_as_handled()

func cancel_tactical_action_menu() -> void:
	if state != State.TACTICAL_ACTION_MENU:
		return

	state = State.ALERT_PLAYER_TURN
	player_marker.set_input_enabled(true)

	state_changed.emit(state)

	print("Main Squad cancelled its tactical action selection.")

func get_adjacent_enemies() -> Array[TacticalEnemy]:
	var adjacent_enemies: Array[TacticalEnemy] = []

	if player_marker == null:
		return adjacent_enemies

	for enemy_marker: TacticalEnemy in enemy_markers:
		if enemy_marker == null or enemy_marker.is_defeated():
			continue

		if enemy_marker.get_manhattan_distance_to(player_marker.cell) == 1:
			adjacent_enemies.append(enemy_marker)

	return adjacent_enemies


func begin_battle_transition() -> void:
	if state != State.TACTICAL_ACTION_MENU:
		return

	state = State.BATTLE_TRANSITION
	player_marker.set_input_enabled(false)
	state_changed.emit(state)


func resume_after_player_action() -> void:
	if state != State.BATTLE_TRANSITION:
		return

	remaining_player_movement = 0
	_advance_to_next_turn()


func _open_tactical_action_menu_if_possible() -> bool:
	var adjacent_enemies := get_adjacent_enemies()

	if adjacent_enemies.is_empty():
		return false

	state = State.TACTICAL_ACTION_MENU
	player_marker.set_input_enabled(false)

	state_changed.emit(state)
	adjacent_enemies_available.emit(adjacent_enemies)

	return true

func _on_player_movement_requested(direction: Vector2i) -> void:
	if player_marker == null:
		return

	var target_cell: Vector2i = player_marker.cell + direction

	if _is_enemy_occupying(target_cell):
		print("Main Squad cannot move onto an enemy squad token.")
		return

	if state == State.FREE_EXPLORATION:
		var moved_in_exploration := player_marker.move_by(direction)

		if moved_in_exploration:
			_check_for_enemy_notice()

		return

	if state != State.ALERT_PLAYER_TURN:
		return

	if remaining_player_movement <= 0:
		end_player_turn()
		return

	var moved_in_alert := player_marker.move_by(direction)

	if not moved_in_alert:
		return

	remaining_player_movement -= 1

	print(
		"Main Squad moved. Remaining movement: %d."
		% remaining_player_movement
	)

	if remaining_player_movement <= 0:
		end_player_turn()

func _on_player_cell_changed(
	_previous_cell: Vector2i,
	_new_cell: Vector2i
) -> void:
	if state == State.FREE_EXPLORATION:
		_check_for_enemy_notice()


func _check_for_enemy_notice() -> void:
	if player_marker == null:
		return

	var noticed_enemy: TacticalEnemy = null

	for enemy_marker: TacticalEnemy in enemy_markers:
		if enemy_marker == null or enemy_marker.is_defeated():
			continue

		var distance_to_player: int = (
			enemy_marker.get_manhattan_distance_to(player_marker.cell)
		)

		if distance_to_player <= NOTICE_DISTANCE:
			enemy_marker.set_alert(true)

			if noticed_enemy == null:
				noticed_enemy = enemy_marker

	if noticed_enemy != null and state == State.FREE_EXPLORATION:
		print(
			"%s noticed the Main Squad at %d tiles."
			% [
				noticed_enemy.squad.display_name,
				noticed_enemy.get_manhattan_distance_to(
					player_marker.cell
				)
			]
		)

		_begin_alert_state()


func _begin_alert_state() -> void:
	if state != State.FREE_EXPLORATION:
		return

	print("Alert tactical state started.")

	_start_new_alert_round()


func _start_new_alert_round() -> void:
	_turn_order.clear()

	if player_marker != null:
		_turn_order.append(player_marker)

	for enemy_marker: TacticalEnemy in enemy_markers:
		if enemy_marker == null or enemy_marker.is_defeated():
			continue

		_turn_order.append(enemy_marker)

	_turn_order.sort_custom(_sort_turn_actors)
	_turn_index = -1

	_advance_to_next_turn()


func _sort_turn_actors(
	left_actor: Node,
	right_actor: Node
) -> bool:
	var left_initiative: int = _get_actor_initiative(left_actor)
	var right_initiative: int = _get_actor_initiative(right_actor)

	if left_initiative == right_initiative:
		return left_actor == player_marker

	return left_initiative > right_initiative


func _get_actor_initiative(actor: Node) -> int:
	if actor is TacticalPlayer:
		return player_marker.squad.get_alert_initiative()

	if actor is TacticalEnemy:
		var enemy_marker := actor as TacticalEnemy
		return enemy_marker.squad.get_alert_initiative()

	return 0


func _advance_to_next_turn() -> void:
	_turn_index += 1

	if _turn_index >= _turn_order.size():
		_start_new_alert_round()
		return

	var active_actor: Node = _turn_order[_turn_index]

	if active_actor == player_marker:
		_begin_player_turn()
		return

	if active_actor is TacticalEnemy:
		_begin_enemy_turn(active_actor as TacticalEnemy)
		return

	_advance_to_next_turn()

func _begin_player_turn() -> void:
	state = State.ALERT_PLAYER_TURN
	remaining_player_movement = (
		player_marker.squad.get_alert_movement_budget()
	)

	player_marker.set_input_enabled(true)

	state_changed.emit(state)
	player_turn_started.emit(
		remaining_player_movement,
		player_marker.squad.get_alert_initiative()
	)

	print(
		"Main Squad turn — movement: %d, initiative: %d."
		% [
			remaining_player_movement,
			player_marker.squad.get_alert_initiative()
		]
	)

func end_player_turn() -> void:
	if state != State.ALERT_PLAYER_TURN:
		return

	print("Main Squad ended its turn.")

	remaining_player_movement = 0
	player_marker.set_input_enabled(false)

	_advance_to_next_turn()

func _is_enemy_occupying(target_cell: Vector2i) -> bool:
	for enemy_marker: TacticalEnemy in enemy_markers:
		if enemy_marker == null or enemy_marker.is_defeated():
			continue

		if enemy_marker.cell == target_cell:
			return true

	return false

func _begin_enemy_turn(enemy_marker: TacticalEnemy) -> void:
	state = State.ALERT_ENEMY_TURNS
	player_marker.set_input_enabled(false)

	state_changed.emit(state)
	enemy_turn_started.emit(enemy_marker)

	print(
		"%s turn — STATIC. Initiative: %d."
		% [
			enemy_marker.squad.display_name,
			enemy_marker.squad.get_alert_initiative()
		]
	)

	## PATROL is deliberately added in the next milestone.
	## STATIC consumes its turn without changing its grid-anchor.
	_check_for_enemy_notice()

	_advance_to_next_turn()
