extends Node

## Transitional corridor composition:
## builds room tokens and connects shared gameplay controllers.
## Encounter selection and battle presentation live in the shared controller.

const EnemyTokenScript = preload(
    "res://scripts/exploration/projected_enemy.gd"
)
const CursorScript = preload(
    "res://scripts/exploration/projected_cursor.gd"
)
const TurnsScript = preload(
    "res://scripts/systems/tactical_turn_controller.gd"
)
const EncounterControllerScript = preload(
    "res://scripts/systems/tactical_encounter_controller.gd"
)
const SewerEnemyContent = preload(
    "res://scripts/content/sewer_enemy_content.gd"
)

const ROOM_ID: String = "sewer_corridor"

var map_root: Node2D
var player: TacticalPlayer
var rats: TacticalEnemy
var cursor: TacticalCursor
var turns: TurnsScript
var encounters: EncounterControllerScript

var _room_state: Dictionary
var _suspended: bool = false
var _party_defeated: bool = false


func configure(
	assigned_map: Node2D,
	assigned_player: TacticalPlayer,
	grid: TacticalGrid,
	projection: TacticalGridProjection,
	rat_start_cell: Vector2i
) -> bool:
	map_root = assigned_map
	player = assigned_player

	if not grid.is_walkable(rat_start_cell):
		push_error(
            "Rat Start Cell is outside the corridor grid: %s"
			% str(rat_start_cell)
		)
		return false

	_initialize_room_state(rat_start_cell)

	var saved_rat_cell: Vector2i = _room_state["cell"]
	var rat_squad: Squad = _room_state["squad"]

	if not grid.is_walkable(saved_rat_cell):
		push_error("Saved rat cell is outside the corridor grid.")
		return false

	if saved_rat_cell == player.cell and rat_squad.is_alive():
		push_error(
            "Main Squad and Rat Squad cannot share an arrival cell."
		)
		return false

	var projected_rats := EnemyTokenScript.new()
	projected_rats.projection = projection
	projected_rats.z_index = 10
	map_root.add_child(projected_rats)
	rats = projected_rats

	rats.configure(
		grid,
		Vector2.ZERO,
		42.0,
		saved_rat_cell,
		10,
		rat_squad
	)

	if not rat_squad.is_alive():
		rats.set_defeated()
		rats.hide()

	var projected_cursor := CursorScript.new()
	projected_cursor.projection = projection
	projected_cursor.z_index = 20
	map_root.add_child(projected_cursor)
	cursor = projected_cursor
	cursor.configure(Vector2.ZERO, 42.0)

	turns = TurnsScript.new()
	add_child(turns)

	turns.state_changed.connect(_on_turn_state_changed)

	var enemies: Array[TacticalEnemy] = [rats]
	turns.configure(player, enemies, cursor)

	encounters = EncounterControllerScript.new()
	add_child(encounters)

	encounters.presentation_active_changed.connect(
		_on_presentation_active_changed
	)
	encounters.encounter_finished.connect(_on_encounter_finished)
	encounters.flow_changed.connect(_on_encounter_flow_changed)

	encounters.configure(player, enemies, turns)

	_party_defeated = not player.squad.is_alive()

	if _party_defeated:
		set_suspended(true)
	else:
		call_deferred("_refresh_entry_notice")

	print("Corridor rat state: ", rat_squad.get_summary())

	for rat: Unit in rat_squad.members:
		print(rat.get_summary())

	return true


func _initialize_room_state(rat_start_cell: Vector2i) -> void:
	if not GameState.exploration_room_states.has(ROOM_ID):
		GameState.exploration_room_states[ROOM_ID] = {
			"squad": SewerEnemyContent.create_corridor_rat_squad(),
			"cell": rat_start_cell
		}

	# Keep the same dictionary and Squad references across room changes.
	_room_state = GameState.exploration_room_states[ROOM_ID]


func _refresh_entry_notice() -> void:
	if _suspended or _party_defeated:
		return

	turns.refresh_notice()
	map_root.call("_update_exit_hint")


func _on_turn_state_changed(_new_state: int) -> void:
	map_root.call("_update_exit_hint")


func _on_encounter_flow_changed() -> void:
	map_root.call("_update_exit_hint")


func can_calibrate() -> bool:
	return (
		not _party_defeated
		and not encounters.is_busy()
		and turns.is_free_exploration()
	)


func can_open_door() -> bool:
	if _party_defeated or encounters.is_busy():
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
	if rats != null:
		_room_state["cell"] = rats.cell


func refresh_projection(projection: TacticalGridProjection) -> void:
	if rats != null:
		rats.position = projection.get_cell_center(rats.cell)
		rats.refresh_visual()

	if cursor != null:
		cursor.position = projection.get_cell_center(cursor.cell)
		cursor.queue_redraw()


func get_status_text() -> String:
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
	map_root.call("set_combat_presentation_active", active)


func finish_battle(context: Variant) -> void:
	# Existing room-links forwards the SceneManager callback here.
	encounters.finish_battle(context)


func _on_encounter_finished(_context: EncounterContext) -> void:
	save_room_state()

	_party_defeated = not player.squad.is_alive()
	set_suspended(false)

	if _party_defeated:
		cursor.end_selection()
	else:
		turns.resume_after_player_action()

	map_root.call("_update_exit_hint")

	for rat: Unit in rats.squad.members:
		print(rat.get_summary())
