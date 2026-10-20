extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _make_enemy(id: String) -> Squad:
	var enemy := Squad.new(id, "Test Enemy", Squad.AutonomyMode.ENEMY)
	enemy.add_member(Unit.new(
		id + "_unit", "Test Unit", 1, 20, 5, 2, 3, 1
	))
	return enemy


func _run_tests() -> void:
	var state: Node = root.get_node("GameState")
	state.start_new_game()

	var main: Squad = state.get_main_squad()
	var hero: Unit = main.members[0]
	var friend: Unit = main.members[1]

	var enemy: Squad = _make_enemy("test_results_enemy")
	var ongoing := EncounterContext.new(
		main, enemy, EncounterContext.Initiator.PLAYER, &"balanced"
	)

	var result: EncounterResult = state.settle_encounter(ongoing)
	_check(not result.should_show(), "Living enemy: no ordinary results")
	_check(hero.experience == 0, "No rewards for an unfinished clash")

	var special := EncounterContext.new(
		main, enemy, EncounterContext.Initiator.PLAYER, &"balanced"
	)
	special.result.add_special_message("Test-only exceptional outcome.")
	result = state.settle_encounter(special)
	_check(result.should_show(), "Special outcome can show results")
	_check(
		not result.defeat_rewards_claimed and result.gold_gained == 0,
		"Special outcome does not grant defeat rewards"
	)

	# Synthetic fixtures only: these are not actual sewer rewarddata.
	enemy.defeat_gold = 7
	enemy.defeat_items = {&"potion": 2}

	var victory := EncounterContext.new(
		main, enemy, EncounterContext.Initiator.PLAYER, &"balanced"
	)

	var gold_before: int = int(state.gold)
	var potions_before: int = state.get_item_quantity(&"potion")
	friend.hp = 0
	enemy.members[0].hp = 0

	result = state.settle_encounter(victory)

	# Python formula: 20 + 5 + 2 + 3 + 1 = 31.
	_check(result.should_show(), "Squad defeat shows results")
	_check(hero.experience == 31, "Living participant receives full Python XP")
	_check(friend.experience == 0, "Defeated participant receives no XP")
	_check(friend.hp == 0, "XP settlement does not revive defeated member")
	_check(int(state.gold) == gold_before + 7, "Explicit gold is applied")
	_check(
		state.get_item_quantity(&"potion") == potions_before + 2,
		"Explicit item quantities are applied"
	)
	_check(
		state.is_enemy_squad_defeated(enemy.squad_id),
		"Defeat identity is queryable"
	)

	state.settle_encounter(victory)
	_check(hero.experience == 31, "Same context cannot duplicate XP")
	_check(int(state.gold) == gold_before + 7, "Same context cannot duplicate gold")

	# Another context for the same globally unique squad ID.
	var repeated := EncounterContext.new(
		main, enemy, EncounterContext.Initiator.PLAYER, &"balanced"
	)
	result = state.settle_encounter(repeated)
	_check(not result.should_show(), "Previously processed defeat is not replayed")

	state.exploration_room_states["test_map_a"] = {
		"enemies": {&"spawn_a": {"squad": enemy}}
	}
	_check(state.is_map_cleared("test_map_a"), "Defeated map is cleared")
	_check(not state.is_map_cleared("unknown_map"), "Unknown map is not cleared")

	state.exploration_room_states["empty_test_map"] = {"enemies": {}}
	_check(
		not state.is_map_cleared("empty_test_map"),
		"Empty map does not imply combat completion"
	)

	var enemy_b: Squad = _make_enemy("test_results_enemy_b")
	state.exploration_room_states["test_map_b"] = {
		"enemies": {&"spawn_b": {"squad": enemy_b}}
	}

	var required_maps: Array[String] = ["test_map_a", "test_map_b"]
	_check(
		not state.are_location_maps_cleared(required_maps),
		"Location requires every explicitly listed map"
	)

	enemy_b.members[0].hp = 0
	_check(
		state.are_location_maps_cleared(required_maps),
		"All required maps can satisfy a future quest condition"
	)

	var empty_manifest: Array[String] = []
	_check(
		not state.are_location_maps_cleared(empty_manifest),
		"Empty location manifest is not cleared"
	)

	state.start_new_game()
	_check(
		not state.is_enemy_squad_defeated("test_results_enemy"),
		"New game clears defeat ledger"
	)

	print("Encounter result tests: %d failure(s)." % _failures)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures += 1
		push_error("FAIL: %s" % description)
