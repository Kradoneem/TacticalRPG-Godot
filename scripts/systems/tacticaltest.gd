extends Node2D

const CombatResolver = preload("res://scripts/domain/combat_resolver.gd")
const EncounterContextData = preload(
	"res://scripts/domain/encounter_context.gd"
)
const StrategyPromptData = preload("res://scripts/ui/strategy_prompt.gd")

const VIEWPORT_SIZE: Vector2 = Vector2(1920.0, 1080.0)

const GRID_ORIGIN: Vector2 = Vector2(180.0, 180.0)
const GRID_SIZE: Vector2i = Vector2i(13, 6)
const CELL_SIZE: float = 120.0

## This is a strategic engagement radius, not weapon range.
## It represents noticing, approaching and committing before the
## enemy squad can force its own encounter.
const PLAYER_ENGAGE_RANGE: int = 3

const AutomaticActionResolverData = preload(
	"res://scripts/domain/automatic_action_resolver.gd"
)

const CombatCommandPromptData = preload(
	"res://scripts/ui/combat_command_prompt.gd"
)

const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle_scene.tscn"

enum EncounterState {
	EXPLORATION,
	STRATEGY_SELECTION,
	COMBAT_COMMAND,
	COMBAT
}


@onready var player_marker: TacticalPlayer = $PlayerMarker
@onready var enemy_marker: TacticalEnemy = $EnemyMarker

var tactical_grid: TacticalGrid
var test_enemy_squad: Squad
var strategy_prompt: StrategyPrompt
var combat_command_prompt: CombatCommandPrompt
var active_encounter: EncounterContext
var encounter_state: EncounterState = EncounterState.EXPLORATION


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

	corrupted_acolyte.learn_skill(&"patch_flesh")

	test_enemy_squad.add_member(sewer_beast)
	test_enemy_squad.add_member(corrupted_acolyte)

	var main_squad = GameState.get_main_squad()

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
		GRID_ORIGIN,
		CELL_SIZE,
		Vector2i(10, 1),
		2,
		test_enemy_squad
	)

	strategy_prompt = StrategyPromptData.new()
	add_child(strategy_prompt)
	strategy_prompt.strategy_selected.connect(_on_strategy_selected)

	combat_command_prompt = CombatCommandPromptData.new()
	add_child(combat_command_prompt)

	combat_command_prompt.command_selected.connect(
		_on_combat_command_selected
	)

	player_marker.cell_changed.connect(_on_player_cell_changed)
	enemy_marker.player_detected.connect(_on_enemy_detected)
	enemy_marker.player_lost.connect(_on_enemy_lost_player)

	enemy_marker.check_detection(player_marker.cell)
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


func _on_player_cell_changed(
	_previous_cell: Vector2i,
	new_cell: Vector2i
) -> void:
	enemy_marker.check_detection(new_cell)


func _unhandled_input(event: InputEvent) -> void:
	if encounter_state == EncounterState.EXPLORATION:
		if event.is_action_pressed("engage"):
			try_player_initiated_encounter()


func try_player_initiated_encounter() -> void:
	if enemy_marker.is_defeated():
		return

	var distance_to_enemy: int = enemy_marker.get_manhattan_distance_to(
		player_marker.cell
	)

	if distance_to_enemy > PLAYER_ENGAGE_RANGE:
		print(
			"Enemy squad is too far away to engage. "
			+ "Move within %d cells."
			% PLAYER_ENGAGE_RANGE
		)
		return

	encounter_state = EncounterState.STRATEGY_SELECTION
	player_marker.set_input_enabled(false)
	strategy_prompt.open_for_squad(player_marker.squad)


func _on_strategy_selected(strategy_id: StringName) -> void:
	start_encounter(
		EncounterContext.Initiator.PLAYER,
		strategy_id
	)

func _on_combat_command_selected(command_id: StringName) -> void:
	if encounter_state != EncounterState.COMBAT_COMMAND:
		return

	resolve_combat_round(command_id)


func open_combat_command_prompt() -> void:
	var protagonist: Unit = player_marker.get_leader()

	if protagonist == null or not protagonist.is_alive():
		finish_player_defeat()
		return

	encounter_state = EncounterState.COMBAT_COMMAND
	combat_command_prompt.open_for_unit(protagonist)

func _on_enemy_detected(enemy_cell: Vector2i) -> void:
	if encounter_state != EncounterState.EXPLORATION:
		return

	start_encounter(
		EncounterContext.Initiator.ENEMY,
		player_marker.squad.default_strategy
	)

	print(
		"%s triggered combat at %s."
		% [enemy_marker.squad.display_name, enemy_cell]
	)

func start_encounter(
	initiator: int,
	encounter_strategy: StringName
) -> void:
	active_encounter = EncounterContextData.new(
		player_marker.squad,
		enemy_marker.squad,
		initiator,
		encounter_strategy
	)

	player_marker.set_input_enabled(false)
	enemy_marker.set_alert(true)

	if active_encounter.was_player_initiated():
		print(
			"Main Squad initiated combat using %s strategy."
			% active_encounter.active_strategy
		)
	else:
		print(
			"Enemy initiated combat. Main Squad retains %s strategy."
			% active_encounter.active_strategy
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
			"TacticalTest received no EncounterContext from the battle presentation."
		)
		return

	if returned_context != active_encounter:
		push_warning(
			"TacticalTest received a battle result for an unexpected encounter."
		)
		return

	var enemy_was_defeated := (
		returned_context.enemy_squad != null
		and not returned_context.enemy_squad.is_alive()
	)

	active_encounter = null
	encounter_state = EncounterState.EXPLORATION

	player_marker.set_input_enabled(true)

	if enemy_was_defeated:
		enemy_marker.set_defeated()

		print(
			"%s was defeated and is no longer available for encounters."
			% enemy_marker.squad.display_name
		)
	else:
		enemy_marker.set_alert(false)

	player_marker.refresh_visual()
	enemy_marker.refresh_visual()

	print("Battle presentation closed. Exploration resumed.")

func resolve_combat_round(command_id: StringName) -> void:
	if active_encounter == null:
		push_warning("No active encounter exists.")
		return

	var protagonist: Unit = player_marker.get_leader()

	if protagonist == null or not protagonist.is_alive():
		finish_player_defeat()
		return

	print("--- Combat round begins ---")

	var enemy_target: Unit = enemy_marker.squad.get_first_living_member()

	if enemy_target == null:
		finish_player_victory()
		return

	var action_was_resolved: bool = resolve_protagonist_action(
		protagonist,
		enemy_target,
		command_id
	)

	if not action_was_resolved:
		open_combat_command_prompt()
		return

	if not enemy_marker.squad.is_alive():
		finish_player_victory()
		return

	resolve_main_squad_automatic_turn()

	if not enemy_marker.squad.is_alive():
		finish_player_victory()
		return

	resolve_enemy_squad_automatic_turn(protagonist)

	if not protagonist.is_alive():
		finish_player_defeat()
		return

	player_marker.refresh_visual()
	enemy_marker.refresh_visual()

	print("--- Combat round ends ---")

	open_combat_command_prompt()

func resolve_protagonist_action(
	protagonist: Unit,
	enemy_target: Unit,
	command_id: StringName
) -> bool:
	match command_id:
		&"basic_attack":
			resolve_basic_attack(
				protagonist,
				enemy_target,
				"Manual action"
			)

			return true

		&"focused_strike":
			return resolve_damage_skill(
				protagonist,
				enemy_target,
				&"focused_strike",
				"Manual skill"
			)

		_:
			push_warning("Unknown protagonist command: %s" % command_id)
			return false


func resolve_damage_skill(
	attacker: Unit,
	defender: Unit,
	skill_id: StringName,
	action_label: String
) -> bool:
	if not attacker.knows_skill(skill_id):
		print(
			"%s does not know %s."
			% [attacker.display_name, skill_id]
		)

		return false

	var skill: Skill = SkillData.get_skill(skill_id)

	if skill == null:
		return false

	if not attacker.spend_mp(skill.mp_cost):
		print(
			"%s lacks MP for %s."
			% [attacker.display_name, skill.display_name]
		)

		return false

	var damage: int = CombatResolver.calculate_skill_damage(
		attacker,
		defender,
		skill
	)

	defender.take_damage(damage)

	print(
		"%s — %s used %s and dealt %d damage to %s. "
		+ "Target HP: %d/%d"
		% [
			action_label,
			attacker.display_name,
			skill.display_name,
			damage,
			defender.display_name,
			defender.hp,
			defender.max_hp
		]
	)

	return true

func resolve_main_squad_automatic_turn() -> void:
	var protagonist: Unit = player_marker.get_leader()

	print(
		"Automatic Main Squad turn. Active strategy: %s."
		% active_encounter.active_strategy
	)

	for unit: Unit in player_marker.squad.get_living_members():
		if unit == protagonist:
			continue

		var support_result: AutomaticActionResult = (
			AutomaticActionResolverData.try_resolve_support_action(
				unit,
				player_marker.squad,
				active_encounter.active_strategy
			)
		)

		if support_result.was_performed:
			print_automatic_skill_result(support_result)
			continue

		var enemy_target: Unit = enemy_marker.squad.get_first_living_member()

		if enemy_target == null:
			return

		resolve_basic_attack(unit, enemy_target, "Automatic ally action")

		if not enemy_marker.squad.is_alive():
			return

func resolve_enemy_squad_automatic_turn(protagonist: Unit) -> void:
	print(
		"Automatic Enemy Squad turn. Active strategy: %s."
		% enemy_marker.squad.default_strategy
	)

	for enemy_unit: Unit in enemy_marker.squad.get_living_members():
		if not protagonist.is_alive():
			return

		var support_result: AutomaticActionResult = (
			AutomaticActionResolverData.try_resolve_support_action(
				enemy_unit,
				enemy_marker.squad,
				enemy_marker.squad.default_strategy
			)
		)

		if support_result.was_performed:
			print_automatic_skill_result(support_result)
			continue

		resolve_basic_attack(
			enemy_unit,
			protagonist,
			"Automatic enemy action"
		)

func print_automatic_skill_result(
	action_result: AutomaticActionResult
) -> void:
	var message := (
		"Automatic support action — %s used %s on %s "
		+ "for %d HP. Target HP: %d/%d. MP: %d/%d"
	) % [
		action_result.actor.display_name,
		action_result.skill.display_name,
		action_result.target.display_name,
		action_result.applied_amount,
		action_result.target.hp,
		action_result.target.max_hp,
		action_result.actor.mp,
		action_result.actor.max_mp
	]

	print(message)

func resolve_basic_attack(
	attacker: Unit,
	defender: Unit,
	action_label: String
) -> void:
	var damage: int = CombatResolver.calculate_physical_damage(
		attacker,
		defender
	)

	defender.take_damage(damage)

	print(
		"%s — %s dealt %d damage to %s. Target HP: %d/%d"
		% [
			action_label,
			attacker.display_name,
			damage,
			defender.display_name,
			defender.hp,
			defender.max_hp
		]
	)


func finish_player_victory() -> void:
	enemy_marker.set_defeated()
	enemy_marker.refresh_visual()
	player_marker.refresh_visual()

	encounter_state = EncounterState.EXPLORATION
	active_encounter = null
	player_marker.set_input_enabled(true)

	print("%s was defeated." % enemy_marker.squad.display_name)
	print("Exploration resumed.")


func finish_player_defeat() -> void:
	player_marker.set_input_enabled(false)
	active_encounter = null

	print("The protagonist was defeated. Restart with F5.")

func _on_enemy_lost_player() -> void:
	print("The player left the enemy detection range.")


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
