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


func _run_tests() -> void:
	var actor := Unit.new("caster", "Caster", 1, 40, 12, 4, 8, 10, 40)
	var ally := Unit.new("ally", "Ally", 1, 40, 8, 4, 7, 5)
	var enemy := Unit.new("enemy", "Enemy", 1, 1000, 1, 2, 3, 0)

	var own := Squad.new("own", "Own", Squad.AutonomyMode.MAIN_SQUAD)
	own.add_member(actor)
	own.add_member(ally)

	var opposing := Squad.new("enemy_squad", "Enemy", Squad.AutonomyMode.ENEMY)
	opposing.add_member(enemy)

	var clock := GameplayClock.new()
	clock.reset(own)

	var definition := AttackBuffData.new()
	_check(definition.get_duration(5) == 4, "Wisdom 5: four ticks")
	_check(definition.get_duration(10) == 5, "Wisdom 10: five ticks")
	_check(definition.get_duration(15) == 6, "Wisdom 15: six ticks")
	_check(definition.get_duration(-100) == 1, "Duration minimum one")

	actor.learn_ability(&"attack_support")
	var ability: Skill = SkillData.get_skill(&"attack_support")
	var base_attack: int = ally.base_attack

	var action: BattleAction = AbilityResolver.resolve(
		actor, ally, ability, own, opposing, clock
	)
	_check(action != null and action.action_type == BattleAction.Type.BUFF,
		"Shared resolver applies buff")
	_check(actor.mp == 36, "Four MP paid")
	_check(ally.attack == 11 and ally.base_attack == base_attack,
		"Temporary bonus does not mutate base Attack")

	for index in range(4):
		clock.complete_tactical_round()

	_check(ally.attack == 11, "Buff active before expiry tick")
	clock.complete_tactical_round()
	_check(ally.attack == 8, "Buff expires on fifth tick")

	action = AbilityResolver.resolve(actor, ally, ability, own, opposing, clock)
	clock.complete_tactical_round()
	action = AbilityResolver.resolve(actor, ally, ability, own, opposing, clock)

	_check(ally.attack == 11, "Reapplication does not stack")

	for index in range(4):
		clock.complete_tactical_round()

	_check(ally.attack == 11, "Reapplication restarts duration")
	clock.complete_tactical_round()
	_check(ally.attack == 8, "Refreshed buff expires")

	var mp_before: int = actor.mp
	action = AbilityResolver.resolve(actor, enemy, ability, own, opposing, clock)
	_check(action == null and actor.mp == mp_before,
		"Enemy cannot be buffed as an ally")

	action = AbilityResolver.resolve(actor, ally, ability, own, opposing)
	_check(action == null and actor.mp == mp_before,
		"Missing buff clock consumes no MP")

	# Movement quota remains frozen even when speed changes mid-interval.
	clock.reset(own)
	var quota: int = clock.exploration_quota
	clock.record_exploration_step()
	actor.speed = 100
	ally.speed = 100

	_check(clock.exploration_quota == quota, "Quota frozen during tick")

	for index in range(quota - 1):
		clock.record_exploration_step()

	_check(clock.current_tick == 1, "Movement quota advances exactly one tick")
	_check(clock.exploration_steps == 0, "New tick resets steps")
	_check(clock.exploration_quota == own.get_alert_movement_budget(),
		"New tick snapshots updated movement")

	# BattleSession target selection uses the existing global clock.
	var state: Node = root.get_node("GameState")
	state.start_new_game()

	var context := EncounterContext.new(
		own, opposing, EncounterContext.Initiator.PLAYER, &"balanced"
	)
	var session := BattleSession.new(context)
	session.begin_battle()

	var tick_before: int = state.gameplay_clock.current_tick
	mp_before = actor.mp

	session.begin_target_selection(&"attack_support")
	_check(ally in session.get_selected_targets(), "Ally is selectable")
	_check(enemy not in session.get_selected_targets(), "Enemy is not selectable")

	session.cancel_target_selection()
	_check(actor.mp == mp_before, "Cancel costs nothing")

	session.begin_target_selection(&"attack_support")
	action = session.confirm_target(ally.unit_id)
	_check(action != null, "Buff command resolves")

	var repeated: BattleAction = session.confirm_target(ally.unit_id)
	_check(repeated == null, "Repeated confirmation cannot cast again")
	_check(state.gameplay_clock.current_tick == tick_before,
		"Side-view buff action does not advance clock")

	print("Attack buff/clock tests: %d failure(s)." % _failures)
	quit(0 if _failures == 0 else 1)
