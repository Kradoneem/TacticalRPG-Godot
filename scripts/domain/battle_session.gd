class_name BattleSession

extends RefCounted

## Runtime coordinator for one short battle presentation.
##
## It receives shared Unit and Squad references through EncounterContext.
## It owns battle flow, but never copies persistent gameplay data.

const CombatResolverData = preload(
	"res://scripts/domain/combat_resolver.gd"
)

const DEFAULT_MAXIMUM_PROTAGONIST_TURNS: int = 2

enum Phase {
	START_ABILITY,
	PROTAGONIST_COMMAND,
	TARGET_SELECTION,
	MAIN_SQUAD_AUTOMATIC,
	ENEMY_SQUAD_AUTOMATIC,
	END_ABILITY,
	FINISHED
}

var encounter_context: EncounterContext
var phase: Phase = Phase.START_ABILITY

var protagonist_turns_completed: int = 0
var maximum_protagonist_turns: int

var _latest_log: Array[String] = []
var _selected_command_id: StringName = &""
var _main_squad_member_index: int = 0
var _enemy_squad_member_index: int = 0

func _init(
	new_encounter_context: EncounterContext,
	new_maximum_protagonist_turns: int = DEFAULT_MAXIMUM_PROTAGONIST_TURNS
) -> void:
	encounter_context = new_encounter_context
	maximum_protagonist_turns = maxi(1, new_maximum_protagonist_turns)


func begin_battle() -> void:
	_clear_log()

	if not is_valid():
		_add_log("Battle could not start: invalid encounter context.")
		phase = Phase.FINISHED
		return

	phase = Phase.START_ABILITY

	## Equipable start abilities are intentionally not implemented yet.
	## The state already exists, so adding them later does not alter battle flow.
	_add_log("Battle begins.")
	_add_log("No start ability is equipped.")

	phase = Phase.PROTAGONIST_COMMAND
	_add_log(
		"Protagonist turn %d of %d: choose a command."
		% [protagonist_turns_completed + 1, maximum_protagonist_turns]
	)


func is_valid() -> bool:
	return (
		encounter_context != null
		and encounter_context.player_squad != null
		and encounter_context.enemy_squad != null
	)


func get_player_squad() -> Squad:
	if not is_valid():
		return null

	return encounter_context.player_squad


func get_enemy_squad() -> Squad:
	if not is_valid():
		return null

	return encounter_context.enemy_squad


func get_protagonist() -> Unit:
	var player_squad := get_player_squad()

	if player_squad == null:
		return null

	return player_squad.get_leader()


func get_primary_enemy_target() -> Unit:
	var enemy_squad := get_enemy_squad()

	if enemy_squad == null:
		return null

	return enemy_squad.get_first_living_member()


func is_player_defeated() -> bool:
	var protagonist := get_protagonist()

	return protagonist == null or not protagonist.is_alive()


func is_enemy_defeated() -> bool:
	var enemy_squad := get_enemy_squad()

	return enemy_squad == null or not enemy_squad.is_alive()


func is_finished() -> bool:
	return phase == Phase.FINISHED


func can_accept_protagonist_command() -> bool:
	return (
		phase == Phase.PROTAGONIST_COMMAND
		and not is_player_defeated()
		and not is_enemy_defeated()
	)

func is_target_selection_active() -> bool:
	return (
		phase == Phase.TARGET_SELECTION
		and not _selected_command_id.is_empty()
	)
	
func get_selected_command_text() -> String:
	match _selected_command_id:
		&"basic_attack":
			return "Attack"

		&"focused_strike":
			return "Focused Strike"

		_:
			return "Unknown command"

func get_targetable_enemy_units() -> Array[Unit]:
	var targets: Array[Unit] = []
	var enemy_squad := get_enemy_squad()

	if enemy_squad == null:
		return targets

	for unit: Unit in enemy_squad.get_living_members():
		targets.append(unit)

	return targets


func get_initiator_text() -> String:
	if not is_valid():
		return "Unknown initiative"

	if encounter_context.was_player_initiated():
		return "Main Squad initiative"

	return "Enemy initiative"


func get_phase_text() -> String:
	match phase:
		Phase.START_ABILITY:
			return "Start ability"

		Phase.PROTAGONIST_COMMAND:
			return "Protagonist command"

		Phase.TARGET_SELECTION:
			return "Target selection"

		Phase.MAIN_SQUAD_AUTOMATIC:
			return "Main Squad automatic actions"

		Phase.ENEMY_SQUAD_AUTOMATIC:
			return "Enemy Squad automatic actions"

		Phase.END_ABILITY:
			return "End ability"

		Phase.FINISHED:
			return "Battle finished"

		_:
			return "Unknown phase"

func get_latest_log_text(
	maximum_lines: int = -1
) -> String:
	var lines_to_show: Array[String] = []

	if maximum_lines > 0 and _latest_log.size() > maximum_lines:
		var start_index := _latest_log.size() - maximum_lines

		for line_index in range(start_index, _latest_log.size()):
			lines_to_show.append(_latest_log[line_index])
	else:
		lines_to_show.append_array(_latest_log)

	return "\n".join(lines_to_show)

func begin_enemy_target_selection(command_id: StringName) -> void:
	_clear_log()

	if not can_accept_protagonist_command():
		_add_log("A protagonist command cannot be selected right now.")
		return

	if command_id != &"basic_attack" and command_id != &"focused_strike":
		_add_log("Unknown command: %s." % command_id)
		return

	if get_targetable_enemy_units().is_empty():
		_finish_battle()
		return

	_selected_command_id = command_id
	phase = Phase.TARGET_SELECTION

	_add_log(
		"Choose a target for %s."
		% get_selected_command_text()
	)
	
func cancel_target_selection() -> void:
	if not is_target_selection_active():
		return

	_selected_command_id = &""
	phase = Phase.PROTAGONIST_COMMAND

	_clear_log()
	_add_log("Target selection cancelled. Choose a command.")

func confirm_enemy_target(target_unit_id: String) -> BattleAction:
	if not is_target_selection_active():
		_add_log("No target selection is currently active.")
		return null

	var protagonist := get_protagonist()
	var enemy_target := _find_living_enemy_by_id(target_unit_id)

	if protagonist == null or enemy_target == null:
		_selected_command_id = &""
		phase = Phase.PROTAGONIST_COMMAND

		_clear_log()
		_add_log("That target is no longer available.")
		return null

	var selected_command := _selected_command_id

	_clear_log()

	var resolved_action := _resolve_protagonist_command(
		protagonist,
		enemy_target,
		selected_command
	)

	if resolved_action == null:
		_selected_command_id = &""
		phase = Phase.PROTAGONIST_COMMAND
		_add_log("Command was not resolved. Choose another command.")
		return null

	_selected_command_id = &""
	protagonist_turns_completed += 1

	if _finish_if_required():
		return resolved_action

	## BattleScene now gets time to show this action and its HP change.
	_main_squad_member_index = 0
	_enemy_squad_member_index = 0

	phase = Phase.MAIN_SQUAD_AUTOMATIC

	return resolved_action

func _find_living_enemy_by_id(target_unit_id: String) -> Unit:
	for unit: Unit in get_targetable_enemy_units():
		if unit.unit_id == target_unit_id:
			return unit

	return null

func _resolve_protagonist_command(
	protagonist: Unit,
	enemy_target: Unit,
	command_id: StringName
) -> BattleAction:
	match command_id:
		&"basic_attack":
			var damage := CombatResolverData.calculate_physical_damage(
				protagonist,
				enemy_target
			)

			enemy_target.take_damage(damage)

			var action := BattleAction.new()
			action.configure_damage(
				protagonist,
				enemy_target,
				damage,
				"%s attacks %s for %d damage."
				% [
					protagonist.display_name,
					enemy_target.display_name,
					damage
				]
			)

			_add_log(action.message)
			return action

		&"focused_strike":
			return _resolve_damage_skill(
				protagonist,
				enemy_target,
				&"focused_strike",
				"Focused Strike"
			)

		_:
			_add_log("Unknown command: %s." % command_id)
			return null

func _resolve_damage_skill(
	attacker: Unit,
	defender: Unit,
	skill_id: StringName,
	action_name: String
) -> BattleAction:
	if not attacker.knows_skill(skill_id):
		_add_log(
			"%s does not know %s."
			% [attacker.display_name, action_name]
		)
		return null

	var skill := SkillData.get_skill(skill_id)

	if skill == null:
		_add_log("Skill data could not be found: %s." % skill_id)
		return null

	if not attacker.spend_mp(skill.mp_cost):
		_add_log(
			"%s lacks MP for %s."
			% [attacker.display_name, skill.display_name]
		)
		return null

	var damage := CombatResolverData.calculate_skill_damage(
		attacker,
		defender,
		skill
	)

	defender.take_damage(damage)

	var action := BattleAction.new()
	action.configure_damage(
		attacker,
		defender,
		damage,
		"%s uses %s on %s for %d damage."
		% [
			attacker.display_name,
			skill.display_name,
			defender.display_name,
			damage
		],
		skill
	)

	_add_log(action.message)
	return action

func resolve_next_automatic_action() -> BattleAction:
	if phase == Phase.MAIN_SQUAD_AUTOMATIC:
		var main_squad_action := (
			_resolve_next_main_squad_automatic_action()
		)

		if main_squad_action != null:
			_finish_if_required()
			return main_squad_action

		if _finish_if_required():
			return null

		phase = Phase.ENEMY_SQUAD_AUTOMATIC
		_enemy_squad_member_index = 0

		return resolve_next_automatic_action()

	if phase == Phase.ENEMY_SQUAD_AUTOMATIC:
		var enemy_squad_action := (
			_resolve_next_enemy_squad_automatic_action()
		)

		if enemy_squad_action != null:
			_finish_if_required()
			return enemy_squad_action

		if _finish_if_required():
			return null

		_finish_automatic_round()
		return null

	return null

func _resolve_next_main_squad_automatic_action() -> BattleAction:
	var player_squad := get_player_squad()
	var protagonist := get_protagonist()

	if player_squad == null:
		return null

	while _main_squad_member_index < player_squad.members.size():
		var unit: Unit = player_squad.members[_main_squad_member_index]
		_main_squad_member_index += 1

		if unit == null or not unit.is_alive() or unit == protagonist:
			continue

		return _resolve_automatic_unit_action(
			unit,
			player_squad,
			encounter_context.active_strategy,
			get_primary_enemy_target()
		)

	return null

func _resolve_next_enemy_squad_automatic_action() -> BattleAction:
	var enemy_squad := get_enemy_squad()
	var protagonist := get_protagonist()

	if enemy_squad == null or protagonist == null:
		return null

	while _enemy_squad_member_index < enemy_squad.members.size():
		var enemy_unit: Unit = enemy_squad.members[
			_enemy_squad_member_index
		]
		_enemy_squad_member_index += 1

		if enemy_unit == null or not enemy_unit.is_alive():
			continue

		if not protagonist.is_alive():
			return null

		return _resolve_automatic_unit_action(
			enemy_unit,
			enemy_squad,
			enemy_squad.default_strategy,
			protagonist
		)

	return null

func _resolve_automatic_unit_action(
	acting_unit: Unit,
	owning_squad: Squad,
	active_strategy: StringName,
	attack_target: Unit
) -> BattleAction:
	var support_result := (
		AutomaticActionResolver.try_resolve_support_action(
			acting_unit,
			owning_squad,
			active_strategy
		)
	)

	if support_result.was_performed:
		var healing_action := BattleAction.new()
		healing_action.configure_healing(
			support_result.actor,
			support_result.target,
			support_result.applied_amount,
			"%s uses %s on %s and restores %d HP."
			% [
				support_result.actor.display_name,
				support_result.skill.display_name,
				support_result.target.display_name,
				support_result.applied_amount
			],
			support_result.skill
		)

		_add_log(healing_action.message)
		return healing_action

	if attack_target == null or not attack_target.is_alive():
		return null

	var damage := CombatResolverData.calculate_physical_damage(
		acting_unit,
		attack_target
	)

	attack_target.take_damage(damage)

	var attack_action := BattleAction.new()
	attack_action.configure_damage(
		acting_unit,
		attack_target,
		damage,
		"%s attacks %s for %d damage."
		% [
			acting_unit.display_name,
			attack_target.display_name,
			damage
		]
	)

	_add_log(attack_action.message)
	return attack_action

func _finish_automatic_round() -> void:
	if protagonist_turns_completed >= maximum_protagonist_turns:
		_finish_battle()
		return

	phase = Phase.PROTAGONIST_COMMAND
	_add_log(
		"Protagonist turn %d of %d: choose a command."
		% [protagonist_turns_completed + 1, maximum_protagonist_turns]
	)

func _finish_if_required() -> bool:
	if is_enemy_defeated():
		_add_log("Enemy Squad was defeated.")
		phase = Phase.FINISHED
		return true

	if is_player_defeated():
		_add_log("The protagonist was defeated.")
		phase = Phase.FINISHED
		return true

	return false


func _finish_battle() -> void:
	phase = Phase.END_ABILITY

	## Equipable end abilities will be added later.
	_add_log("No end ability is equipped.")

	phase = Phase.FINISHED

	if not is_enemy_defeated() and not is_player_defeated():
		_add_log(
			"Battle window ended after %d protagonist turns."
			% protagonist_turns_completed
		)


func _clear_log() -> void:
	_latest_log.clear()


func _add_log(message: String) -> void:
	_latest_log.append(message)
