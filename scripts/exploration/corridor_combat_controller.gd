extends Node

const EnemyTokenScript = preload(
    "res://scripts/exploration/projected_enemy.gd"
)
const CursorScript = preload(
    "res://scripts/exploration/projected_cursor.gd"
)
const TurnsScript = preload(
    "res://scripts/exploration/corridor_turn_controller.gd"
)

const ROOM_ID: String = "sewer_corridor"
const BATTLE_SCENE_PATH: String = (
    "res://scenes/battle/battle_scene.tscn"
)

var map_root: Node2D
var player: TacticalPlayer
var rats: TacticalEnemy
var cursor: TacticalCursor
var turns: TurnsScript

var strategy_prompt: StrategyPrompt
var attack_prompt: TacticalActionPrompt
var active_encounter: EncounterContext

var _room_state: Dictionary
var _strategy_open: bool = false
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
		push_error("Main Squad and Rat Squad cannot share an arrival cell.")
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

	attack_prompt = TacticalActionPrompt.new()
	add_child(attack_prompt)
	attack_prompt.attack_selected.connect(_on_attack_selected)
	attack_prompt.cancelled.connect(_on_attack_cancelled)

	strategy_prompt = StrategyPrompt.new()
	add_child(strategy_prompt)
	strategy_prompt.strategy_selected.connect(_on_strategy_selected)

	turns = TurnsScript.new()
	add_child(turns)
	turns.adjacent_enemies_available.connect(_on_adjacent_enemies)
	turns.state_changed.connect(_on_turn_state_changed)

	var enemies: Array[TacticalEnemy] = [rats]
	turns.configure(player, enemies, cursor)

	_party_defeated = not player.squad.is_alive()

	if _party_defeated:
		set_suspended(true)
	else:
		# Entrance configure_return runs before the deferred refresh.
		call_deferred("_refresh_entry_notice")

	print("Corridor rat state: ", rat_squad.get_summary())

	for rat: Unit in rat_squad.members:
		print(rat.get_summary())

	return true


func _initialize_room_state(rat_start_cell: Vector2i) -> void:
	if not GameState.exploration_room_states.has(ROOM_ID):
		var squad := Squad.new(
			"corridor_sewer_rats",
			"Sewer Rats",
			Squad.AutonomyMode.ENEMY
		)

		squad.default_strategy = &"balanced"

		for index in range(3):
			var rat := Unit.new(
				"corridor_sewer_rat_%d" % (index + 1),
				"Sewer Rat %d" % (index + 1),
				1,
				22,
				7,
				2,
				6,
				0,
				0
			)

			squad.add_member(rat)

		GameState.exploration_room_states[ROOM_ID] = {
			"squad": squad,
			"cell": rat_start_cell
		}

	_room_state = GameState.exploration_room_states[ROOM_ID]


func _refresh_entry_notice() -> void:
	if _suspended or _party_defeated:
		return

	turns.refresh_notice()
	map_root.call("_update_exit_hint")


func _on_turn_state_changed(_new_state: int) -> void:
	map_root.call("_update_exit_hint")


func can_calibrate() -> bool:
	return (
		not _party_defeated
		and not _strategy_open
		and active_encounter == null
		and turns.is_free_exploration()
	)


func can_open_door() -> bool:
	if _party_defeated or _strategy_open or active_encounter != null:
		return false

	if turns.is_free_exploration():
		return true

	# Enter must not activate a door while selecting a different end cell.
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

	if _strategy_open or active_encounter != null:
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


func _on_adjacent_enemies(targets: Array[TacticalEnemy]) -> void:
	attack_prompt.open_for_targets(targets)


func _on_attack_cancelled() -> void:
	turns.cancel_tactical_action_menu()


func _on_attack_selected(target: TacticalEnemy) -> void:
	if target != rats or rats.is_defeated():
		return

	turns.begin_battle_transition()
	_strategy_open = true
	strategy_prompt.open_for_squad(player.squad)

func _on_strategy_selected(strategy_id: StringName) -> void:
	print("[Encounter] 1: strategy confirmed: ", strategy_id)

	_strategy_open = false

	if player == null or player.squad == null:
		push_error("[Encounter] Main Squad reference is missing.")
		return

	if rats == null or rats.squad == null:
		push_error("[Encounter] Enemy Squad reference is missing.")
		return

	print(
		"[Encounter] 2: shared squads available: ",
		player.squad.display_name,
		" versus ",
		rats.squad.display_name,
		" | enemy members: ",
		rats.squad.members.size()
	)

	active_encounter = EncounterContext.new(
		player.squad,
		rats.squad,
		EncounterContext.Initiator.PLAYER,
		strategy_id
	)

	print("[Encounter] 3: EncounterContext created.")

	set_suspended(true)
	map_root.call("set_combat_presentation_active", true)

	print(
		"[Encounter] 4: requesting battle presentation: ",
		BATTLE_SCENE_PATH
	)

	var presentation: Node = SceneManager.present_game_scene(
		BATTLE_SCENE_PATH,
		active_encounter
	)

	if presentation == null:
		active_encounter = null
		map_root.call("set_combat_presentation_active", false)
		set_suspended(false)
		turns.resume_after_player_action()

		push_error(
            "[Encounter] Battle presentation returned null. "
			+ "Check the preceding Godot errors."
		)
		return

	print(
		"[Encounter] 5: presentation returned: ",
		presentation.get_path()
	)

	if presentation is BattleScene:
		var battle := presentation as BattleScene

		print(
			"[Encounter] 6: BattleScene received our context: ",
			battle.encounter_context == active_encounter,
			" | BattleSession exists: ",
			battle.battle_session != null,
			" | visible in tree: ",
			battle.is_visible_in_tree()
		)
	else:
		push_error(
            "[Encounter] Loaded node is not a BattleScene."
		)

func finish_battle(context: Variant) -> void:
	if active_encounter == null or context != active_encounter:
		push_warning("Corridor received an unexpected EncounterContext.")
		return

	if not rats.squad.is_alive():
		rats.set_defeated()
		rats.hide()

	player.refresh_visual()
	rats.refresh_visual()
	save_room_state()

	_party_defeated = not player.squad.is_alive()
	active_encounter = null

	set_suspended(false)

	if _party_defeated:
		cursor.end_selection()
	else:
		turns.resume_after_player_action()

	map_root.call("_update_exit_hint")

	for rat: Unit in rats.squad.members:
		print(rat.get_summary())
