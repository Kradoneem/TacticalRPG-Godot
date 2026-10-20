extends SceneTree

var _failures: int = 0
var _updates: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _on_update(_quest_id: String, _objective_id: StringName) -> void:
	_updates += 1


func _make_squad(id: String) -> Squad:
	var squad := Squad.new(id, id, Squad.AutonomyMode.ENEMY)
	squad.add_member(Unit.new(id + "_unit", "Test enemy", 1, 10, 2, 1, 3, 0))
	return squad


func _run_tests() -> void:
	var state: Node = root.get_node("GameState")
	state.start_new_game()
	state.quest_objective_updated.connect(_on_update)

	for quest_id: String in QuestData.get_all_quest_ids():
		state.activate_quest(quest_id)

	_check(state.get_quest_log_ids().size() == 3, "Three prototype quests active")
	_check(_updates == 0, "Activation without achieved targets gives no update")

	var patrol: Squad = _make_squad("junction_patrol_rats")
	var stationary: Squad = _make_squad("junction_static_rats")
	var corridor: Squad = _make_squad("corridor_sewer_rats")

	state.exploration_room_states["sewer_junction"] = {
		"enemies": {
			&"patrol": {"squad": patrol},
			&"static": {"squad": stationary}
		}
	}
	state.exploration_room_states["sewer_corridor"] = {
		"enemies": {
			&"corridor": {"squad": corridor}
		}
	}

	# Synthetic gameplay-state fixtures, not rewards.
	patrol.members[0].hp = 0
	state.defeated_enemy_squads[patrol.squad_id] = true
	state.refresh_quest_objectives()

	_check(
		state.are_quest_objectives_achieved("test_junction_patrol"),
		"Specific patrol objective achieved"
	)
	_check(
		not state.are_quest_objectives_achieved("test_junction_clear"),
		"Other squad keeps junction objective open"
	)
	_check(_updates == 1, "Exactly one progress notification")

	state.refresh_quest_objectives()
	_check(_updates == 1, "Refresh does not replay achieved objectives")

	stationary.members[0].hp = 0
	state.refresh_quest_objectives()

	_check(
		state.are_quest_objectives_achieved("test_junction_clear"),
		"Junction objective achieved after all its squads defeated"
	)
	_check(
		not state.are_quest_objectives_achieved("test_sewer_slice_clear"),
		"Uncleared corridor keeps location objective open"
	)
	_check(_updates == 2, "Second objective produces one additional update")

	state.complete_quest("test_sewer_slice_clear")
	_check(
		state.get_quest_status("test_sewer_slice_clear") == "active",
		"Cannot complete a quest with unfinished objectives"
	)

	corridor.members[0].hp = 0
	state.refresh_quest_objectives()

	_check(
		state.are_quest_objectives_achieved("test_sewer_slice_clear"),
		"Explicit corridor and junction manifest is satisfied"
	)
	_check(_updates == 3, "All three updates emitted once")
	_check(
		state.get_quest_status("test_sewer_slice_clear") == "active",
		"All objectives achieved does not automatically complete quest"
	)

	var gold_before: int = int(state.gold)
	state.complete_quest("test_sewer_slice_clear")
	_check(
		state.get_quest_status("test_sewer_slice_clear") == "completed",
		"Explicit completion succeeds"
	)
	_check(int(state.gold) == gold_before, "Quest completion invents no rewards")

	state.activate_quest("test_junction_patrol")
	state.refresh_quest_objectives()
	_check(_updates == 3, "Repeated activation does not reset progress")

	state.start_new_game()
	_check(state.get_quest_log_ids().is_empty(), "New game resets quest log")
	_check(
		not state.is_quest_objective_achieved(
			"test_junction_patrol", &"clear_target"
		),
		"New game resets objective progress"
	)

	# Accepting a quest after its target has already been defeated.
	state.defeated_enemy_squads["junction_patrol_rats"] = true
	state.activate_quest("test_junction_patrol")
	_check(
		state.are_quest_objectives_achieved("test_junction_patrol"),
		"Previously satisfied target counts on acceptance"
	)

	print("Quest tests: %d failure(s)." % _failures)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("FAIL: " + description)
