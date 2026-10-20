extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _make_squad(id: String, unit: Unit, mode: int) -> Squad:
	var squad := Squad.new(id, id, mode)
	squad.add_member(unit)
	return squad


func _make_session(actor: Unit, target: Unit) -> BattleSession:
	var allies: Squad = _make_squad(
		"test_player", actor, Squad.AutonomyMode.MAIN_SQUAD
	)
	var enemies: Squad = _make_squad(
		"test_enemy", target, Squad.AutonomyMode.ENEMY
	)

	var context := EncounterContext.new(
		allies, enemies, EncounterContext.Initiator.PLAYER, &"balanced"
	)
	var session := BattleSession.new(context)
	session.begin_battle()
	return session


func _finish_automatic_round(session: BattleSession) -> void:
	for step in range(20):
		if session.can_accept_protagonist_command() or session.is_finished():
			return
		session.resolve_next_automatic_action()


func _run_tests() -> void:
	var actor := Unit.new("hero", "Hero", 1, 100, 12, 3, 8, 5, 30)
	var target := Unit.new("enemy", "Enemy", 1, 1000, 1, 2, 3, 0)

	actor.learn_ability(&"focused_strike")
	actor.learn_ability(&"power_strike")
	actor.learn_ability(&"fireball")
	actor.learn_ability(&"heal")

	var session: BattleSession = _make_session(actor, target)

	_check(
		&"fireball" in session.get_protagonist_ability_ids(Skill.Category.SPELL),
		"Spell list reads known IDs"
	)

	session.begin_enemy_target_selection(&"fireball")
	_check(session.is_target_selection_active(), "Known Fireball selects target")
	_check(actor.mp == 30, "Selection pays no MP")

	session.cancel_target_selection()
	_check(session.can_accept_protagonist_command(), "Cancel restores command")
	_check(actor.mp == 30, "Cancel pays no MP")

	session.begin_enemy_target_selection(&"heal")
	_check(
		session.can_accept_protagonist_command(),
		"Menu blocks healing although shared resolver supports it"
	)

	actor.mp = 5
	session.begin_enemy_target_selection(&"fireball")
	_check(
		session.can_accept_protagonist_command(),
		"Insufficient MP does not spend a command"
	)

	actor.mp = 30
	session.begin_enemy_target_selection(&"fireball")
	var before_hp: int = target.hp
	var action: BattleAction = session.confirm_enemy_target(target.unit_id)

	_check(action != null, "Fireball resolves")
	_check(actor.mp == 24, "Fireball pays six MP once")
	_check(target.hp == before_hp - 17, "Python damage scaling: 14 + 5 - 2")

	var repeated: BattleAction = session.confirm_enemy_target(target.unit_id)
	_check(repeated == null and actor.mp == 24, "Repeated confirmation pays nothing")

	_finish_automatic_round(session)
	_check(
		session.current_round == 2 and session.can_accept_protagonist_command(),
		"Round two requests another protagonist command"
	)

	before_hp = target.hp
	session.begin_enemy_target_selection(&"focused_strike")
	action = session.confirm_enemy_target(target.unit_id)

	_check(action != null, "Focused Strike resolves")
	_check(target.hp == before_hp - 16, "Focused Strike preserves multiplier")

	_finish_automatic_round(session)
	_check(session.is_finished(), "Battle still ends after two rounds")

	# Shared resolver: HP costs and squad boundary.
	var hp_actor := Unit.new("hp_hero", "HP Hero", 1, 40, 12, 3, 8, 5)
	var hp_target := Unit.new("hp_enemy", "HP Enemy", 1, 100, 1, 2, 3, 0)
	hp_actor.learn_ability(&"power_strike")

	var own: Squad = _make_squad(
		"own", hp_actor, Squad.AutonomyMode.MAIN_SQUAD
	)
	var opposition: Squad = _make_squad(
		"opposition", hp_target, Squad.AutonomyMode.ENEMY
	)
	var power: Skill = SkillData.get_skill(&"power_strike")

	hp_actor.hp = 4
	action = AbilityResolver.resolve(hp_actor, hp_target, power, own, opposition)
	_check(action == null and hp_actor.hp == 4, "HP cost cannot defeat actor")

	hp_actor.hp = 5
	var outsider := Unit.new("outsider", "Outsider", 1, 100, 1, 2, 3, 0)
	action = AbilityResolver.resolve(hp_actor, outsider, power, own, opposition)
	_check(action == null and hp_actor.hp == 5, "Outside target rejected before costs")

	before_hp = hp_target.hp
	action = AbilityResolver.resolve(hp_actor, hp_target, power, own, opposition)
	_check(action != null and hp_actor.hp == 1, "HP cost paid once")
	_check(hp_target.hp == before_hp - 16, "Power Strike additive scaling")

	# Shared execution is not protagonist-only.
	var healer := Unit.new("healer", "Healer", 1, 40, 3, 3, 6, 10, 20)
	var patient := Unit.new("patient", "Patient", 1, 40, 3, 3, 6, 2)
	healer.learn_ability(&"mend")

	var support_squad := Squad.new(
		"support", "Support", Squad.AutonomyMode.AUTONOMOUS_ALLY
	)
	support_squad.add_member(healer)
	support_squad.add_member(patient)

	patient.hp = 10
	action = AbilityResolver.resolve(
		healer, patient, SkillData.get_skill(&"mend"), support_squad
	)
	_check(action != null, "Shared resolver performs ally healing")
	_check(patient.hp == 25 and healer.mp == 16, "Mend formula and MP preserved")

	patient.hp = 10
	healer.mp = 20
	var support_result: AutomaticActionResult = (
		AutomaticActionResolver.try_resolve_support_action(
			healer, support_squad, &"support"
		)
	)
	_check(support_result.was_performed, "Automatic support uses shared execution")
	_check(patient.hp == 25 and healer.mp == 16, "Automatic heal pays once")

	patient.hp = 30
	healer.mp = 20
	support_result = AutomaticActionResolver.try_resolve_support_action(
		healer, support_squad, &"support"
	)
	_check(
		not support_result.was_performed and healer.mp == 20,
		"Support threshold remains unchanged"
	)

	patient.hp = patient.max_hp
	action = AbilityResolver.resolve(
		healer, patient, SkillData.get_skill(&"mend"), support_squad
	)
	_check(action == null and healer.mp == 20, "Full target consumes no healing cost")

	# Ownership rechecked at target confirmation.
	var forget_actor := Unit.new("forget", "Forget", 1, 40, 12, 3, 8, 5, 30)
	forget_actor.learn_ability(&"fireball")
	var forget_session: BattleSession = _make_session(forget_actor, hp_target)
	forget_session.begin_enemy_target_selection(&"fireball")
	forget_actor.forget_ability(&"fireball")
	action = forget_session.confirm_enemy_target(hp_target.unit_id)
	_check(action == null and forget_actor.mp == 30, "Forgotten ability rejected")

	print("Ability command tests: %d failure(s)." % _failures)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("FAIL: " + description)
