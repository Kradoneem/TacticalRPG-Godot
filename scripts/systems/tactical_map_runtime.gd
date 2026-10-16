extends Node

## Shared tactical gameplay composition for projected maps.
## Does not know room-specific content, exits or calibration controls.

signal status_changed
signal presentation_active_changed(active: bool)

const EnemyTokenScript = preload(
    "res://scripts/exploration/projected_enemy.gd"
)
const CursorScript = preload(
    "res://scripts/exploration/projected_cursor.gd"
)
const EncounterControllerScript = preload(
    "res://scripts/systems/tactical_encounter_controller.gd"
)

var player: TacticalPlayer
var enemy_markers: Array[TacticalEnemy] = []
var cursor: TacticalCursor
var turns: TacticalTurnController
var encounters: EncounterControllerScript

var _room_id: String
var _room_state: Dictionary
var _tokens_by_id: Dictionary = {}
var _configured: bool = false
var _suspended: bool = false
var _party_defeated: bool = false


func configure(
	token_parent: Node2D,
	assigned_player: TacticalPlayer,
	grid: TacticalGrid,
	projection: TacticalGridProjection,
	assigned_room_id: String,
	spawns: Array[TacticalEnemySpawn]
) -> bool:
	if _configured:
		push_error("TacticalMapRuntime cannot be configured twice.")
		return false

	if (
		token_parent == null
		or assigned_player == null
		or assigned_player.squad == null
		or grid == null
		or projection == null
		or assigned_room_id.is_empty()
	):
		push_error("TacticalMapRuntime received incomplete configuration.")
		return false

	player = assigned_player
	_room_id = assigned_room_id

	if not _validate_spawns(grid, spawns):
		return false

	if not _prepare_room_state(spawns):
		return false

	if not _validate_saved_state(grid, spawns):
		return false

	for spawn: TacticalEnemySpawn in spawns:
		var saved: Dictionary = _room_state["enemies"][spawn.spawn_id]
		var saved_squad: Squad = saved["squad"]
		var saved_cell: Vector2i = saved["cell"]

		var token := EnemyTokenScript.new()
		token.projection = projection
		token.z_index = 10
		token_parent.add_child(token)

		token.configure(
			grid,
			Vector2.ZERO,
			42.0,
			saved_cell,
			TacticalTurnController.NOTICE_DISTANCE,
			saved_squad
		)

		token.restore_session_state(saved)

		enemy_markers.append(token)
		_tokens_by_id[spawn.spawn_id] = token

	var projected_cursor := CursorScript.new()
	projected_cursor.projection = projection
	projected_cursor.z_index = 20
	token_parent.add_child(projected_cursor)

	cursor = projected_cursor
	cursor.configure(Vector2.ZERO, 42.0)

	turns = TacticalTurnController.new()
	add_child(turns)
	turns.state_changed.connect(_on_turn_state_changed)
	turns.configure(player, enemy_markers, cursor)

	encounters = EncounterControllerScript.new()
	add_child(encounters)

	encounters.presentation_active_changed.connect(
		_on_presentation_active_changed
	)
	encounters.encounter_finished.connect(_on_encounter_finished)
	encounters.flow_changed.connect(_on_encounter_flow_changed)

	encounters.configure(player, enemy_markers, turns)

	_party_defeated = not player.squad.is_alive()
	_configured = true

	if _party_defeated:
		set_suspended(true)
	else:
		call_deferred("_refresh_entry_notice")

	print(
		"[TacticalMap] ",
		_room_id,
		" | enemy squad-tokens: ",
		enemy_markers.size()
	)

	return true


func _validate_spawns(
	grid: TacticalGrid,
	spawns: Array[TacticalEnemySpawn]
) -> bool:
	var known_ids: Dictionary = {}

	for spawn: TacticalEnemySpawn in spawns:
		if spawn == null:
			push_error("Map contains a null enemy spawn.")
			return false

		if spawn.spawn_id == &"" or known_ids.has(spawn.spawn_id):
			push_error("Enemy spawn IDs must be non-empty and unique.")
			return false

		known_ids[spawn.spawn_id] = true

		if not grid.is_walkable(spawn.start_cell):
			push_error(
                "Spawn '%s' starts outside the walkable grid."
				% str(spawn.spawn_id)
			)
			return false

		if not spawn.patrol_route.is_empty():
			if spawn.patrol_route.size() < 2:
				push_error("Patrol configuration requires two waypoints.")
				return false

			if spawn.patrol_route[0] != spawn.start_cell:
				push_error(
                    "Patrol start_cell must equal its first waypoint."
				)
				return false

			for waypoint: Vector2i in spawn.patrol_route:
				if not grid.is_walkable(waypoint):
					push_error("Patrol contains an invalid waypoint.")
					return false

	return true


func _prepare_room_state(
	spawns: Array[TacticalEnemySpawn]
) -> bool:
	var saved_room: Dictionary = (
		GameState.exploration_room_states.get(_room_id, {})
	)

	var saved_enemies: Dictionary = saved_room.get("enemies", {})

	for spawn: TacticalEnemySpawn in spawns:
		if saved_enemies.has(spawn.spawn_id):
			continue

		var squad: Squad = spawn.create_squad()

		if squad == null or squad.is_empty():
			push_error(
                "Spawn '%s' did not create a populated Squad."
				% str(spawn.spawn_id)
			)
			return false

		var route: Array[Vector2i] = []
		route.assign(spawn.patrol_route)

		saved_enemies[spawn.spawn_id] = {
			"squad": squad,
			"cell": spawn.start_cell,
			"ai_mode": (
				TacticalEnemy.AiMode.STATIC
				if route.is_empty()
				else TacticalEnemy.AiMode.PATROL
			),
			"patrol_route": route,
			"patrol_index": 0
		}

	saved_room["enemies"] = saved_enemies

	GameState.exploration_room_states[_room_id] = saved_room
	_room_state = saved_room

	return true


func _validate_saved_state(
	grid: TacticalGrid,
	spawns: Array[TacticalEnemySpawn]
) -> bool:
	var occupied_cells: Dictionary = {}
	occupied_cells[player.cell] = true

	var registered_squads: Array[Squad] = [player.squad]

	for spawn: TacticalEnemySpawn in spawns:
		var saved: Dictionary = _room_state["enemies"][spawn.spawn_id]
		var squad: Squad = saved.get("squad")
		var saved_cell: Vector2i = saved["cell"]

		if squad == null:
			push_error("Saved enemy state has no Squad.")
			return false

		if squad in registered_squads:
			push_error("Each tactical token must have its own Squad.")
			return false

		registered_squads.append(squad)

		if not grid.is_walkable(saved_cell):
			push_error("Saved enemy position is outside the walkable grid.")
			return false

		if not squad.is_alive():
			continue

		if occupied_cells.has(saved_cell):
			push_error("Living tactical squad-tokens cannot share a cell.")
			return false

		occupied_cells[saved_cell] = true

	return true


func _refresh_entry_notice() -> void:
	if _suspended or _party_defeated:
		return

	turns.refresh_notice()
	status_changed.emit()


func _on_turn_state_changed(_new_state: int) -> void:
	status_changed.emit()


func _on_encounter_flow_changed() -> void:
	status_changed.emit()


func can_calibrate() -> bool:
	return (
		_configured
		and not _party_defeated
		and not encounters.is_busy()
		and turns.is_free_exploration()
	)


func can_open_door() -> bool:
	if not _configured or _party_defeated or encounters.is_busy():
		return false

	if turns.is_free_exploration():
		return true

	return (
		turns.state
		== TacticalTurnController.State.ALERT_PLAYER_MOVEMENT_SELECTION
		and cursor.cell == player.cell
	)


func set_suspended(suspended: bool) -> void:
	_suspended = suspended

	if turns != null:
		turns.set_input_suspended(
			suspended or _party_defeated
		)


func save_room_state() -> void:
	if not _configured:
		return

	var saved_enemies: Dictionary = _room_state["enemies"]

	for spawn_id: StringName in _tokens_by_id:
		var token = _tokens_by_id[spawn_id]

		if is_instance_valid(token):
			saved_enemies[spawn_id] = token.capture_session_state()


func refresh_projection(
	projection: TacticalGridProjection
) -> void:
	for token: TacticalEnemy in enemy_markers:
		if is_instance_valid(token):
			token.position = projection.get_cell_center(token.cell)
			token.refresh_visual()

	if cursor != null:
		cursor.position = projection.get_cell_center(cursor.cell)
		cursor.queue_redraw()


func get_status_text() -> String:
	if not _configured:
		return "Tactical map configureren mislukt. Controleer Output."

	if _party_defeated:
		return "Main Squad verslagen — herstart deze test met F5."

	if encounters.is_busy():
		return ""

	if turns.state == (
		TacticalTurnController.State.ALERT_PLAYER_MOVEMENT_SELECTION
	):
		return (
            "ALERT | WASD: eindcel | Enter: bevestigen"
			+ " | Escape: beurt overslaan"
		)

	if turns.is_free_exploration():
		return "Exploration | WASD: bewegen"

	return ""


func _on_presentation_active_changed(active: bool) -> void:
	set_suspended(active)
	presentation_active_changed.emit(active)


func finish_battle(context: Variant) -> void:
	encounters.finish_battle(context)


func _on_encounter_finished(_context: EncounterContext) -> void:
	save_room_state()

	_party_defeated = not player.squad.is_alive()
	set_suspended(false)

	if _party_defeated:
		cursor.end_selection()
	else:
		turns.resume_after_player_action()

	status_changed.emit()
