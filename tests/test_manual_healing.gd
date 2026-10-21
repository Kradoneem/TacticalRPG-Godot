extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("FAIL: " + description)


func _finish_automatic_round(session: BattleSession) -> void:
	for step in range(20):
		if session.can_accept_protagonist_command() or session.is_finished():
			return

		session.resolve_next_automatic_action()

	_check(false, "Automatic round finishes within the test step limit")


func _run_tests() -> void:
	var caster := Unit.new(
		"caster", "Caster", 1, 100, 3, 3, 8, 10, 30
	)
	var patient := Unit.new(
		"patient", "Patient", 1, 40, 3, 3, 6, 2
	)
	var defeated := Unit.new(
		"defeated", "Defeated", 1, 40, 3, 3, 6, 2
	)
	var enemy := Unit.new(
		"enemy", "Enemy", 1, 1000, 1, 2, 3, 0
	)

	caster.learn_ability(&"mend")
	patient.hp = 10
	defeated.hp = 0

	var allies := Squad.new(
		"allies", "Allies", Squad.AutonomyMode.MAIN_SQUAD
	)
	allies.add_member(caster)
	allies.add_member(patient)
	allies.add_member(defeated)

	var enemies := Squad.new(
		"enemies", "Enemies", Squad.AutonomyMode.ENEMY
	)
	enemies.add_member(enemy)

	var clock := GameplayClock.new()
	clock.reset(allies)

	var context := EncounterContext.new(
		allies,
		enemies,
		EncounterContext.Initiator.PLAYER,
		&"balanced"
	)
	var session := BattleSession.new(context, clock)
	session.begin_battle()

	_check(
		session.get_protagonist_command_reason(&"mend").is_empty(),
		"Known Mend is available when an ally is wounded"
	)

	session.begin_target_selection(&"mend")

	_check(session.is_target_selection_active(), "Healing opens target selection")
	_check(patient in session.get_selected_targets(), "Wounded ally is selectable")
	_check(caster not in session.get_selected_targets(), "Full-health caster is excluded")
	_check(defeated not in session.get_selected_targets(), "Defeated ally is excluded")
	_check(enemy not in session.get_selected_targets(), "Enemy is excluded")
	_check(caster.mp == 30, "Selection costs no MP")

	session.cancel_target_selection()

	_check(session.can_accept_protagonist_command(), "Cancel restores command selection")
	_check(caster.mp == 30 and patient.hp == 10, "Cancel changes no HP or MP")

	session.begin_target_selection(&"mend")
	var action: BattleAction = session.confirm_target(enemy.unit_id)

	_check(action == null and caster.mp == 30, "Invalid enemy target costs nothing")
	_check(session.is_target_selection_active(), "Invalid target allows another choice")

	action = session.confirm_target(patient.unit_id)

	_check(action != null, "Manual healing resolves")

	if action != null:
		_check(action.action_type == BattleAction.Type.HEALING, "Result is healing")
		_check(action.applied_amount == 15, "Existing Mend formula is preserved")
		_check(action.target == patient, "Result retains the shared target Unit")

	_check(patient.hp == 25, "Shared patient HP is restored")
	_check(caster.mp == 26, "Mend pays four MP once")
	_check(clock.current_tick == 0, "Healing adds no gameplay tick")

	var repeated: BattleAction = session.confirm_target(patient.unit_id)

	_check(
		repeated == null and caster.mp == 26 and patient.hp == 25,
		"Repeated confirmation performs no second heal"
	)

	_finish_automatic_round(session)

	_check(
		session.current_round == 2 and session.can_accept_protagonist_command(),
		"Round two requests a new protagonist command"
	)

	# The caster can target himself when wounded.
	caster.hp = 90
	session.begin_target_selection(&"mend")
	_check(caster in session.get_selected_targets(), "Wounded caster can heal himself")

	action = session.confirm_target(caster.unit_id)

	_check(action != null, "Self-healing resolves")

	if action != null:
		_check(action.applied_amount == 10, "Reported healing is capped to missing HP")

	_check(caster.hp == 100 and caster.mp == 22, "Self-healing pays once")

	_finish_automatic_round(session)

	_check(session.is_finished(), "Battle ends after two complete rounds")
	_check(clock.current_tick == 0, "Side-view rounds add no gameplay ticks")

	# New session: nobody requires healing.
	caster.hp = caster.max_hp
	patient.hp = patient.max_hp
	caster.mp = 30

	var full_session := BattleSession.new(context, clock)
	full_session.begin_battle()
	full_session.begin_target_selection(&"mend")

	_check(
		full_session.can_accept_protagonist_command(),
		"No wounded targets leaves command selection open"
	)
	_check(caster.mp == 30, "No-target selection costs nothing")

	# Insufficient MP does not consume the command.
	patient.hp = 10
	caster.mp = 3
	full_session.begin_target_selection(&"mend")

	_check(
		full_session.can_accept_protagonist_command() and caster.mp == 3,
		"Insufficient MP blocks healing without consuming the command"
	)

	# Revalidate the target between selection and confirmation.
	caster.mp = 30
	full_session.begin_target_selection(&"mend")
	patient.hp = patient.max_hp
	action = full_session.confirm_target(patient.unit_id)

	_check(
		action == null and caster.mp == 30,
		"Target healed after selection is rejected without cost"
	)
	full_session.cancel_target_selection()

	# Revalidate learned ability ownership at confirmation.
	patient.hp = 10
	full_session.begin_target_selection(&"mend")
	caster.forget_ability(&"mend")
	action = full_session.confirm_target(patient.unit_id)

	_check(
		action == null and caster.mp == 30 and patient.hp == 10,
		"Forgotten spell is rejected without costs or healing"
	)
	_check(
		full_session.can_accept_protagonist_command(),
		"Failed execution restores command selection"
	)

	print("Manual healing tests: %d failure(s)." % _failures)
	quit(0 if _failures == 0 else 1)
