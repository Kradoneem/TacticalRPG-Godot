class_name TacticalTurnController

extends Node

## Owns tactical turn state, alert propagation and player movement commitment.
## It never owns Unit/Squad data and never resolves side-view battles.

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
	ALERT_PLAYER_MOVEMENT_SELECTION,
	TACTICAL_ACTION_MENU,
	BATTLE_TRANSITION,
	ALERT_ENEMY_TURNS
}


var player_marker: TacticalPlayer
var enemy_markers: Array[TacticalEnemy] = []
var tactical_cursor: TacticalCursor

var state: State = State.FREE_EXPLORATION

var remaining_player_movement: int = 0

var _turn_order: Array[Node] = []
var _turn_index: int = -1
var _reachable_player_cells: Array[Vector2i] = []


func configure(
	assigned_player_marker: TacticalPlayer,
	assigned_enemy_markers: Array[TacticalEnemy],
	assigned_cursor: TacticalCursor
) -> void:
	player_marker = assigned_player_marker
	enemy_markers = assigned_enemy_markers
	tactical_cursor = assigned_cursor

	if player_marker == null:
		push_error("TacticalTurnController requires a TacticalPlayer.")
		return

	if tactical_cursor == null:
		push_error("TacticalTurnController requires a TacticalCursor.")
		return

	player_marker.movement_requested.connect(
		_on_player_movement_requested
	)

	player_marker.set_input_enabled(true)
	tactical_cursor.end_selection()


func is_free_exploration() -> bool:
	return state == State.FREE_EXPLORATION


func _unhandled_input(event: InputEvent) -> void:
	if state != State.ALERT_PLAYER_MOVEMENT_SELECTION:
		return

	if event.is_action_pressed("move_up"):
		_move_cursor(Vector2i.UP)
	elif event.is_action_pressed("move_down"):
		_move_cursor(Vector2i.DOWN)
	elif event.is_action_pressed("move_left"):
		_move_cursor(Vector2i.LEFT)
	elif event.is_action_pressed("move_right"):
		_move_cursor(Vector2i.RIGHT)
	elif event.is_action_pressed("ui_accept"):
		_commit_selected_player_destination()
	elif event.is_action_pressed("ui_cancel"):
		_end_player_turn()

	get_viewport().set_input_as_handled()


func cancel_tactical_action_menu() -> void:
	if state != State.TACTICAL_ACTION_MENU:
		return

	_begin_player_movement_selection()


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
	tactical_cursor.end_selection()

	state_changed.emit(state)


func resume_after_player_action() -> void:
	if state != State.BATTLE_TRANSITION:
		return

	_advance_to_next_turn()


func _on_player_movement_requested(direction: Vector2i) -> void:
	if state != State.FREE_EXPLORATION:
		return

	var target_cell: Vector2i = player_marker.cell + direction

	if _is_enemy_occupying(target_cell):
		return

	if not player_marker.move_by(direction):
		return

	_advance_free_exploration_patrols()
	_refresh_alert_state()


func _advance_free_exploration_patrols() -> void:
	for enemy_marker: TacticalEnemy in enemy_markers:
		if (
			enemy_marker == null
			or enemy_marker.is_defeated()
			or enemy_marker.ai_mode != TacticalEnemy.AiMode.PATROL
		):
			continue

		var next_cell := enemy_marker.get_next_patrol_cell()

		if (
			next_cell == player_marker.cell
			or _is_enemy_occupying_by_other_enemy(
				next_cell,
				enemy_marker
			)
		):
			continue

		enemy_marker.advance_patrol()


func _refresh_alert_state() -> void:
	var alerted_enemies := _get_alerted_enemy_chain()

	for enemy_marker: TacticalEnemy in enemy_markers:
		if enemy_marker == null or enemy_marker.is_defeated():
			continue

		enemy_marker.set_alert(enemy_marker in alerted_enemies)

	if state == State.FREE_EXPLORATION and not alerted_enemies.is_empty():
		_begin_alert_state()
		return

	if (
		state != State.FREE_EXPLORATION
		and alerted_enemies.is_empty()
	):
		_end_alert_state()

func _get_alerted_enemy_chain() -> Array[TacticalEnemy]:
	var alerted_enemies: Array[TacticalEnemy] = []
	var pending_enemies: Array[TacticalEnemy] = []

	for enemy_marker: TacticalEnemy in enemy_markers:
		if enemy_marker == null or enemy_marker.is_defeated():
			continue

		if (
			enemy_marker.get_manhattan_distance_to(player_marker.cell)
			<= NOTICE_DISTANCE
		):
			alerted_enemies.append(enemy_marker)
			pending_enemies.append(enemy_marker)

	while not pending_enemies.is_empty():
		var alert_source: TacticalEnemy = pending_enemies.pop_front()

		for candidate_enemy: TacticalEnemy in enemy_markers:
			if (
				candidate_enemy == null
				or candidate_enemy.is_defeated()
				or candidate_enemy in alerted_enemies
			):
				continue

			if (
				candidate_enemy.get_manhattan_distance_to(
					alert_source.cell
				)
				<= NOTICE_DISTANCE
			):
				alerted_enemies.append(candidate_enemy)
				pending_enemies.append(candidate_enemy)

	return alerted_enemies

func _begin_alert_state() -> void:
	if state != State.FREE_EXPLORATION:
		return

	print("Alert tactical state started.")

	## Leave FREE_EXPLORATION before rebuilding the round.
	## _start_new_alert_round() refreshes alert status again.
	state = State.ALERT_ENEMY_TURNS
	player_marker.set_input_enabled(false)
	tactical_cursor.end_selection()

	state_changed.emit(state)

	_start_new_alert_round()

func _end_alert_state() -> void:
	print("No enemy squads remain alert. Free exploration resumed.")

	state = State.FREE_EXPLORATION
	_turn_order.clear()
	_turn_index = -1
	_reachable_player_cells.clear()

	tactical_cursor.end_selection()
	player_marker.set_input_enabled(true)

	state_changed.emit(state)


func _start_new_alert_round() -> void:
	_refresh_alert_state()

	if state == State.FREE_EXPLORATION:
		return

	_turn_order.clear()

	if player_marker != null:
		_turn_order.append(player_marker)

	for enemy_marker: TacticalEnemy in enemy_markers:
		if enemy_marker == null or enemy_marker.is_defeated():
			continue

		## Every living enemy gets a turn during global alert.
		_turn_order.append(enemy_marker)

	_turn_order.sort_custom(_sort_turn_actors)
	_turn_index = -1

	_advance_to_next_turn()


func _sort_turn_actors(
	left_actor: Node,
	right_actor: Node
) -> bool:
	var left_initiative := _get_actor_initiative(left_actor)
	var right_initiative := _get_actor_initiative(right_actor)

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
	remaining_player_movement = (
		player_marker.squad.get_alert_movement_budget()
	)

	player_marker.set_input_enabled(false)

	player_turn_started.emit(
		remaining_player_movement,
		player_marker.squad.get_alert_initiative()
	)

	_begin_player_movement_selection()


func _begin_player_movement_selection() -> void:
	state = State.ALERT_PLAYER_MOVEMENT_SELECTION

	_reachable_player_cells = _get_reachable_player_cells(
		player_marker.cell,
		remaining_player_movement
	)

	tactical_cursor.begin_selection(
		player_marker.cell,
		_reachable_player_cells
	)

	state_changed.emit(state)

func _get_reachable_player_cells(
	start_cell: Vector2i,
	movement_budget: int
) -> Array[Vector2i]:
	var reachable_cells: Array[Vector2i] = [start_cell]
	var distances: Dictionary = {start_cell: 0}
	var pending_cells: Array[Vector2i] = [start_cell]

	while not pending_cells.is_empty():
		var current_cell: Vector2i = pending_cells.pop_front()
		var current_distance: int = distances[current_cell]

		if current_distance >= movement_budget:
			continue

		for neighbor_cell: Vector2i in (
			player_marker.get_walkable_neighbor_cells(current_cell)
		):
			if (
				neighbor_cell != start_cell
				and _is_enemy_occupying(neighbor_cell)
			):
				continue

			if distances.has(neighbor_cell):
				continue

			distances[neighbor_cell] = current_distance + 1
			reachable_cells.append(neighbor_cell)
			pending_cells.append(neighbor_cell)

	return reachable_cells

func _move_cursor(direction: Vector2i) -> void:
	tactical_cursor.move_by(direction)


func _commit_selected_player_destination() -> void:
	var destination_cell := tactical_cursor.cell

	if not destination_cell in _reachable_player_cells:
		return

	tactical_cursor.end_selection()

	if destination_cell != player_marker.cell:
		player_marker.move_to(destination_cell)

	if _open_tactical_action_menu_if_possible():
		return

	_end_player_turn()


func _open_tactical_action_menu_if_possible() -> bool:
	var adjacent_enemies := get_adjacent_enemies()

	if adjacent_enemies.is_empty():
		return false

	state = State.TACTICAL_ACTION_MENU
	player_marker.set_input_enabled(false)

	state_changed.emit(state)
	adjacent_enemies_available.emit(adjacent_enemies)

	return true


func _end_player_turn() -> void:
	if (
		state != State.ALERT_PLAYER_MOVEMENT_SELECTION
		and state != State.TACTICAL_ACTION_MENU
	):
		return

	tactical_cursor.end_selection()
	remaining_player_movement = 0

	_refresh_alert_state()

	if state == State.FREE_EXPLORATION:
		return

	_advance_to_next_turn()


func _is_enemy_occupying(target_cell: Vector2i) -> bool:
	for enemy_marker: TacticalEnemy in enemy_markers:
		if enemy_marker == null or enemy_marker.is_defeated():
			continue

		if enemy_marker.cell == target_cell:
			return true

	return false


func _is_enemy_occupying_by_other_enemy(
	target_cell: Vector2i,
	excluded_enemy: TacticalEnemy
) -> bool:
	for enemy_marker: TacticalEnemy in enemy_markers:
		if (
			enemy_marker == null
			or enemy_marker == excluded_enemy
			or enemy_marker.is_defeated()
		):
			continue

		if enemy_marker.cell == target_cell:
			return true

	return false


func _begin_enemy_turn(active_enemy_marker: TacticalEnemy) -> void:
	state = State.ALERT_ENEMY_TURNS
	player_marker.set_input_enabled(false)
	tactical_cursor.end_selection()

	state_changed.emit(state)
	enemy_turn_started.emit(active_enemy_marker)

	if active_enemy_marker.ai_mode == TacticalEnemy.AiMode.PATROL:
		var next_cell := active_enemy_marker.get_next_patrol_cell()

		if (
			next_cell != player_marker.cell
			and not _is_enemy_occupying_by_other_enemy(
				next_cell,
				active_enemy_marker
			)
		):
			active_enemy_marker.advance_patrol()

	_refresh_alert_state()

	if state == State.FREE_EXPLORATION:
		return

	_advance_to_next_turn()
