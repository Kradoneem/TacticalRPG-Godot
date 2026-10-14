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

func submit_protagonist_command(command_id: StringName) -> void:
	_clear_log()

	if not can_accept_protagonist_command():
		_add_log("A protagonist command cannot be accepted right now.")
		return

	var protagonist := get_protagonist()
	var enemy_target := get_primary_enemy_target()

	if protagonist == null or enemy_target == null:
		_finish_battle()
		return

	var command_was_resolved := _resolve_protagonist_command(
		protagonist,
		enemy_target,
		command_id
	)

	if not command_was_resolved:
		_add_log("Command was not resolved. Choose another action.")
		return

	protagonist_turns_completed += 1

	if _finish_if_required():
		return

	phase = Phase.MAIN_SQUAD_AUTOMATIC
	_resolve_main_squad_automatic_actions()

	if _finish_if_required():
		return

	phase = Phase.ENEMY_SQUAD_AUTOMATIC
	_resolve_enemy_squad_automatic_actions()

	if _finish_if_required():
		return

	if protagonist_turns_completed >= maximum_protagonist_turns:
		_finish_battle()
		return

	phase = Phase.PROTAGONIST_COMMAND
	_add_log(
		"Protagonist turn %d of %d: choose a command."
		% [protagonist_turns_completed + 1, maximum_protagonist_turns]
	)


func _resolve_protagonist_command(
	protagonist: Unit,
	enemy_target: Unit,
	command_id: StringName
) -> bool:
	match command_id:
		&"basic_attack":
			var damage := CombatResolverData.calculate_physical_damage(
				protagonist,
				enemy_target
			)

			enemy_target.take_damage(damage)

			_add_log(
				"%s attacks %s for %d damage."
				% [
					protagonist.display_name,
					enemy_target.display_name,
					damage
				]
			)

			return true

		&"focused_strike":
			return _resolve_damage_skill(
				protagonist,
				enemy_target,
				&"focused_strike",
				"Focused Strike"
			)

		_:
			_add_log("Unknown command: %s." % command_id)
			return false


func _resolve_damage_skill(
	attacker: Unit,
	defender: Unit,
	skill_id: StringName,
	action_name: String
) -> bool:
	if not attacker.knows_skill(skill_id):
		_add_log("%s does not know %s." % [
			attacker.display_name,
			action_name
		])
		return false

	var skill := SkillData.get_skill(skill_id)

	if skill == null:
		_add_log("Skill data could not be found: %s." % skill_id)
		return false

	if not attacker.spend_mp(skill.mp_cost):
		_add_log(
			"%s lacks MP for %s."
			% [attacker.display_name, skill.display_name]
		)
		return false

	var damage := CombatResolverData.calculate_skill_damage(
		attacker,
		defender,
		skill
	)

	defender.take_damage(damage)

	_add_log(
		"%s uses %s on %s for %d damage."
		% [
			attacker.display_name,
			skill.display_name,
			defender.display_name,
			damage
		]
	)

	return true


func _resolve_main_squad_automatic_actions() -> void:
	var player_squad := get_player_squad()
	var protagonist := get_protagonist()

	if player_squad == null:
		return

	for unit: Unit in player_squad.get_living_members():
		if unit == protagonist:
			continue

		var support_result := (
			AutomaticActionResolver.try_resolve_support_action(
				unit,
				player_squad,
				encounter_context.active_strategy
			)
		)

		if support_result.was_performed:
			_add_log(
				"%s uses %s on %s and restores %d HP."
				% [
					support_result.actor.display_name,
					support_result.skill.display_name,
					support_result.target.display_name,
					support_result.applied_amount
				]
			)
			continue

		var enemy_target := get_primary_enemy_target()

		if enemy_target == null:
			return

		var damage := CombatResolverData.calculate_physical_damage(
			unit,
			enemy_target
		)

		enemy_target.take_damage(damage)

		_add_log(
			"%s attacks %s for %d damage."
			% [
				unit.display_name,
				enemy_target.display_name,
				damage
			]
		)

		if is_enemy_defeated():
			return


func _resolve_enemy_squad_automatic_actions() -> void:
	var enemy_squad := get_enemy_squad()
	var protagonist := get_protagonist()

	if enemy_squad == null or protagonist == null:
		return

	for enemy_unit: Unit in enemy_squad.get_living_members():
		if not protagonist.is_alive():
			return

		var support_result := (
			AutomaticActionResolver.try_resolve_support_action(
				enemy_unit,
				enemy_squad,
				enemy_squad.default_strategy
			)
		)

		if support_result.was_performed:
			_add_log(
				"%s uses %s on %s and restores %d HP."
				% [
					support_result.actor.display_name,
					support_result.skill.display_name,
					support_result.target.display_name,
					support_result.applied_amount
				]
			)
			continue

		var damage := CombatResolverData.calculate_physical_damage(
			enemy_unit,
			protagonist
		)

		protagonist.take_damage(damage)

		_add_log(
			"%s attacks %s for %d damage."
			% [
				enemy_unit.display_name,
				protagonist.display_name,
				damage
			]
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
