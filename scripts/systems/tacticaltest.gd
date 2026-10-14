extends Node2D

const EncounterContextData = preload(
	"res://scripts/domain/encounter_context.gd"
)
const StrategyPromptData = preload(
	"res://scripts/ui/strategy_prompt.gd"
)

const VIEWPORT_SIZE: Vector2 = Vector2(1920.0, 1080.0)

const GRID_ORIGIN: Vector2 = Vector2(180.0, 180.0)
const GRID_SIZE: Vector2i = Vector2i(13, 6)
const CELL_SIZE: float = 120.0

## This is a strategic engagement radius, not weapon range.
## It represents noticing, approaching and committing before the
## enemy squad can force its own encounter.
const PLAYER_ENGAGE_RANGE: int = 3

const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle_scene.tscn"

const TacticalTurnControllerData = preload(
	"res://scripts/systems/tactical_turn_controller.gd"
)

const TacticalActionPromptData = preload(
	"res://scripts/ui/tactical_action_prompt.gd"
)

enum EncounterState {
	EXPLORATION,
	TACTICAL_ACTION_SELECTION,
	STRATEGY_SELECTION,
	BATTLE_TRANSITION
}


@onready var player_marker: TacticalPlayer = $PlayerMarker
@onready var enemy_marker: TacticalEnemy = $EnemyMarker

var tactical_grid: TacticalGrid
var test_enemy_squad: Squad
var strategy_prompt: StrategyPrompt
var active_encounter: EncounterContext
var encounter_state: EncounterState = EncounterState.EXPLORATION
var turn_controller
var tactical_action_prompt: TacticalActionPrompt
var selected_enemy_marker: TacticalEnemy

func _ready() -> void:
	tactical_grid = TacticalGrid.new(GRID_SIZE)
	configure_test_map()

	test_enemy_squad = Squad.new(
		"corrupted_sewer_pack",
		"Corrupted Sewer Pack",
		Squad.AutonomyMode.ENEMY
	)

	test_enemy_squad.default_strategy = &"support"

	var sewer_beast := Unit.new(
		"corrupted_sewer_beast",
		"Corrupted Sewer Beast",
		1,
		30,
		10,
		3,
		5,
		0
	)

	var corrupted_acolyte := Unit.new(
		"corrupted_acolyte",
		"Corrupted Acolyte",
		1,
		18,
		4,
		2,
		6,
		8,
		12
	)

	corrupted_acolyte.learn_ability(&"patch_flesh")

	test_enemy_squad.add_member(sewer_beast)
	test_enemy_squad.add_member(corrupted_acolyte)

	var main_squad: Squad = GameState.get_main_squad()

	if main_squad == null:
		push_error("TacticalTest could not find a Main Squad in GameState.")
		return

	player_marker.configure(
		tactical_grid,
		GRID_ORIGIN,
		CELL_SIZE,
		Vector2i(2, 1),
		main_squad
	)

	enemy_marker.configure(
		tactical_grid,
		GRID_ORIGIN,
		CELL_SIZE,
		Vector2i(12, 5),
		10,
		test_enemy_squad
	)

	enemy_marker.configure_patrol([
		Vector2i(12, 5),
		Vector2i(11, 5),
		Vector2i(10, 5),
		Vector2i(9, 5),
		Vector2i(10, 5),
		Vector2i(11, 5)
	])

	strategy_prompt = StrategyPromptData.new()
	add_child(strategy_prompt)
	strategy_prompt.strategy_selected.connect(_on_strategy_selected)
	tactical_action_prompt = TacticalActionPromptData.new()
	add_child(tactical_action_prompt)
	tactical_action_prompt.attack_selected.connect(
		_on_tactical_attack_selected
	)
	tactical_action_prompt.cancelled.connect(
		_on_tactical_action_cancelled
	)
	var test_enemy_markers: Array[TacticalEnemy] = [
		enemy_marker
	]

	turn_controller = TacticalTurnControllerData.new()
	add_child(turn_controller)

	turn_controller.configure(
		player_marker,
		test_enemy_markers
	)
	
	turn_controller.adjacent_enemies_available.connect(
		_on_adjacent_enemies_available
	)
	
	queue_redraw()

func configure_test_map() -> void:
	# The blue canal occupies rows 2 and 3.
	# A narrow bridge is left open in columns 6 and 7.
	for column in range(GRID_SIZE.x):
		tactical_grid.set_blocked(Vector2i(column, 2))
		tactical_grid.set_blocked(Vector2i(column, 3))

	for bridge_column in range(6, 8):
		tactical_grid.set_blocked(
			Vector2i(bridge_column, 2),
			false
		)
		tactical_grid.set_blocked(
			Vector2i(bridge_column, 3),
			false
		)

func _unhandled_input(_event: InputEvent) -> void:
	pass

func _on_adjacent_enemies_available(
	adjacent_enemies: Array[TacticalEnemy]
) -> void:
	if adjacent_enemies.is_empty():
		return

	encounter_state = EncounterState.TACTICAL_ACTION_SELECTION
	tactical_action_prompt.open_for_targets(adjacent_enemies)


func _on_tactical_attack_selected(
	selected_target_marker: TacticalEnemy
) -> void:
	if (
		selected_target_marker == null
		or selected_target_marker.is_defeated()
	):
		return

	selected_enemy_marker = selected_target_marker
	encounter_state = EncounterState.STRATEGY_SELECTION

	turn_controller.begin_battle_transition()
	strategy_prompt.open_for_squad(player_marker.squad)

func _on_tactical_action_cancelled() -> void:
	encounter_state = EncounterState.EXPLORATION
	turn_controller.cancel_tactical_action_menu()

func _on_strategy_selected(strategy_id: StringName) -> void:
	if selected_enemy_marker == null:
		push_warning(
			"Strategy was selected without a tactical enemy target."
		)
		return

	encounter_state = EncounterState.BATTLE_TRANSITION

	start_encounter(
		EncounterContext.Initiator.PLAYER,
		strategy_id
	)

func start_encounter(
	initiator: int,
	encounter_strategy: StringName
) -> void:
	if selected_enemy_marker == null:
		push_error("Cannot start an encounter without a selected enemy squad.")
		return

	active_encounter = EncounterContextData.new(
		player_marker.squad,
		selected_enemy_marker.squad,
		initiator,
		encounter_strategy
	)

	player_marker.set_input_enabled(false)
	selected_enemy_marker.set_alert(true)

	print(
		"Main Squad initiated combat against %s using %s strategy."
		% [
			selected_enemy_marker.squad.display_name,
			active_encounter.active_strategy
		]
	)

	SceneManager.present_game_scene(
		BATTLE_SCENE_PATH,
		active_encounter
	)

func on_game_presentation_finished(
	returned_context: EncounterContext
) -> void:
	if returned_context == null:
		push_warning(
			"TacticalTest received no EncounterContext from battle."
		)
		return

	if returned_context != active_encounter:
		push_warning(
			"TacticalTest received a result for an unexpected encounter."
		)
		return

	if selected_enemy_marker == null:
		push_warning(
			"TacticalTest lost the selected enemy marker during battle."
		)
		return

	var enemy_was_defeated := (
		returned_context.enemy_squad != null
		and not returned_context.enemy_squad.is_alive()
	)

	if enemy_was_defeated:
		selected_enemy_marker.set_defeated()

		print(
			"%s was defeated and remains individually removed from combat."
			% selected_enemy_marker.squad.display_name
		)
	else:
		selected_enemy_marker.set_alert(true)

	player_marker.refresh_visual()
	selected_enemy_marker.refresh_visual()

	active_encounter = null
	selected_enemy_marker = null
	encounter_state = EncounterState.EXPLORATION

	turn_controller.resume_after_player_action()

	print("Battle presentation closed. Tactical alert resumed.")

func _draw() -> void:
	# Temporary background: this will later be a prerendered tactical map.
	draw_rect(
		Rect2(Vector2.ZERO, VIEWPORT_SIZE),
		Color("#18242c")
	)

	# Temporary walkable area.
	draw_rect(
		Rect2(GRID_ORIGIN, Vector2(1560.0, 720.0)),
		Color("#304a4f")
	)

	# Temporary water channel.
	draw_rect(
		Rect2(0.0, 460.0, 1800.0, 180.0),
		Color("#163b56")
	)

	# Temporary bridge that corresponds to the two walkable cells.
	draw_rect(
		Rect2(900.0, 420.0, 240.0, 240.0),
		Color("#796044")
	)

	draw_grid()


func draw_grid() -> void:
	var grid_pixel_size := Vector2(GRID_SIZE.x, GRID_SIZE.y) * CELL_SIZE
	var grid_color := Color("#719499", 0.45)

	for column in range(GRID_SIZE.x + 1):
		var x := GRID_ORIGIN.x + column * CELL_SIZE

		draw_line(
			Vector2(x, GRID_ORIGIN.y),
			Vector2(x, GRID_ORIGIN.y + grid_pixel_size.y),
			grid_color,
			2.0
		)

	for row in range(GRID_SIZE.y + 1):
		var y := GRID_ORIGIN.y + row * CELL_SIZE

		draw_line(
			Vector2(GRID_ORIGIN.x, y),
			Vector2(GRID_ORIGIN.x + grid_pixel_size.x, y),
			grid_color,
			2.0
		)
