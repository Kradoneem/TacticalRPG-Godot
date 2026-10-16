extends Node

## Shared player-initiated encounter flow for tactical maps.
## Does not create enemies, manage room persistence or own movement rules.

signal presentation_active_changed(active: bool)
signal encounter_finished(context: EncounterContext)
signal flow_changed

const BATTLE_SCENE_PATH: String = (
    "res://scenes/battle/battle_scene.tscn"
)

var player: TacticalPlayer
var enemy_markers: Array[TacticalEnemy] = []
var turn_controller: TacticalTurnController

var active_encounter: EncounterContext

var _attack_prompt: TacticalActionPrompt
var _strategy_prompt: StrategyPrompt
var _selected_target: TacticalEnemy
var _strategy_open: bool = false
var _configured: bool = false


func configure(
	assigned_player: TacticalPlayer,
	assigned_enemies: Array[TacticalEnemy],
	assigned_turn_controller: TacticalTurnController
) -> void:
	if _configured:
		push_error("Tactical encounter controller was configured twice.")
		return

	if assigned_player == null or assigned_turn_controller == null:
		push_error(
            "Tactical encounter controller requires a player and turns."
		)
		return

	player = assigned_player
	enemy_markers = assigned_enemies
	turn_controller = assigned_turn_controller

	_attack_prompt = TacticalActionPrompt.new()
	add_child(_attack_prompt)
	_attack_prompt.attack_selected.connect(_on_attack_selected)
	_attack_prompt.cancelled.connect(_on_attack_cancelled)

	_strategy_prompt = StrategyPrompt.new()
	add_child(_strategy_prompt)
	_strategy_prompt.strategy_selected.connect(
		_on_strategy_selected
	)

	turn_controller.adjacent_enemies_available.connect(
		_on_adjacent_enemies
	)

	_configured = true


func is_busy() -> bool:
	return _strategy_open or active_encounter != null


func _on_adjacent_enemies(targets: Array[TacticalEnemy]) -> void:
	if is_busy():
		return

	_attack_prompt.open_for_targets(targets)


func _on_attack_cancelled() -> void:
	turn_controller.cancel_tactical_action_menu()
	flow_changed.emit()


func _on_attack_selected(target: TacticalEnemy) -> void:
	if is_busy():
		return

	if not is_instance_valid(target):
		return

	if target not in enemy_markers or target.is_defeated():
		return

	if target.squad == null or not target.squad.is_alive():
		return

	if target.get_manhattan_distance_to(player.cell) != 1:
		push_warning("Encounter target is no longer adjacent.")
		turn_controller.cancel_tactical_action_menu()
		return

	_selected_target = target

	turn_controller.begin_battle_transition()

	_strategy_open = true
	_strategy_prompt.open_for_squad(player.squad)
	flow_changed.emit()


func _on_strategy_selected(strategy_id: StringName) -> void:
	if not _strategy_open:
		return

	_strategy_open = false

	if player == null or player.squad == null:
		_recover_from_start_error("Main Squad reference is missing.")
		return

	if not is_instance_valid(_selected_target):
		_recover_from_start_error("Enemy token reference is missing.")
		return

	if _selected_target.squad == null:
		_recover_from_start_error("Enemy Squad reference is missing.")
		return

	active_encounter = EncounterContext.new(
		player.squad,
		_selected_target.squad,
		EncounterContext.Initiator.PLAYER,
		strategy_id
	)

	print(
		"[Encounter] ",
		player.squad.display_name,
		" versus ",
		_selected_target.squad.display_name,
		" | strategy: ",
		strategy_id,
		" | enemy members: ",
		_selected_target.squad.members.size()
	)

	# The owning map suspends tactical input through this signal.
	presentation_active_changed.emit(true)
	flow_changed.emit()

	# Do not add a new scene during a Button/input callback.
	call_deferred("_present_battle")


func _present_battle() -> void:
	if active_encounter == null:
		return

	var presentation: Node = SceneManager.present_game_scene(
		BATTLE_SCENE_PATH,
		active_encounter
	)

	if presentation == null:
		_recover_from_start_error(
            "Battle presentation could not be loaded."
		)
		return

	if presentation is BattleScene:
		var battle := presentation as BattleScene

		print(
			"[Encounter] BattleScene received shared context: ",
			battle.encounter_context == active_encounter,
			" | BattleSession exists: ",
			battle.battle_session != null
		)


func _recover_from_start_error(message: String) -> void:
	active_encounter = null
	_selected_target = null
	_strategy_open = false

	presentation_active_changed.emit(false)
	turn_controller.resume_after_player_action()
	flow_changed.emit()

	push_error("[Encounter] " + message)


func finish_battle(context: Variant) -> void:
	if active_encounter == null or context != active_encounter:
		push_warning("Unexpected EncounterContext returned to tactical map.")
		return

	var returned_context: EncounterContext = active_encounter

	if is_instance_valid(_selected_target):
		if not _selected_target.squad.is_alive():
			_selected_target.set_defeated()
			_selected_target.hide()

		_selected_target.refresh_visual()

	player.refresh_visual()

	active_encounter = null
	_selected_target = null

	# The owning map persists room state and resumes its turn flow.
	presentation_active_changed.emit(false)
	encounter_finished.emit(returned_context)
	flow_changed.emit()
