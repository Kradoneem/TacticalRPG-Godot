extends SceneTree

## Runs in a separate process.
## Tests data and consumption, not UI or tactical availability.

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var state: Node = root.get_node("GameState")
	state.start_new_game()

	var squad: Squad = state.get_main_squad()
	var target: Unit = squad.members[0]
	var ally: Unit = squad.members[1]

	_check(
		state.party[0] == target,
		"Party and Squad share the same Unit"
	)

	state.add_item(&"potion", 2)
	_check(
		state.get_item_quantity(&"potion") == 3,
		"Adding items increases quantity without duplicate entries"
	)

	target.hp = 1
	var result: Dictionary = state.use_item(&"potion", target)

	_check(bool(result.get("success", false)), "Potion succeeds")
	_check(
		target.hp == mini(target.max_hp, 21),
		"Potion restores capped HP on the shared Unit"
	)
	_check(
		state.get_item_quantity(&"potion") == 2,
		"One use subtracts one Potion"
	)

	target.hp = 0
	result = state.use_item(&"potion", target)

	_check(
		not bool(result.get("success", false)),
		"Defeated target is rejected"
	)
	_check(
		state.get_item_quantity(&"potion") == 2,
		"Rejected use does not consume stock"
	)

	target.hp = target.max_hp
	result = state.use_item(&"potion", target)

	_check(
		int(result.get("restored_hp", -1)) == 0,
		"Full-health use reports zero recovery"
	)
	_check(
		state.get_item_quantity(&"potion") == 1,
		"Full-health use retains Python consumption behavior"
	)

	state.use_item(&"potion", target)
	_check(
		not state.item_inventory.has(&"potion"),
		"Zero-quantity entry is removed"
	)

	result = state.use_item(&"potion", target)
	_check(
		not bool(result.get("success", false)),
		"Out-of-stock use is rejected"
	)

	ally.mp = 0
	state.use_item(&"ether", ally)
	_check(
		ally.mp == mini(ally.max_mp, 10),
		"Ether restores capped MP"
	)

	ally.hp = 1
	ally.mp = 0
	result = state.use_item(&"elixir", ally)

	_check(
		ally.hp == mini(ally.max_hp, 31),
		"Elixir applies HP effect"
	)
	_check(
		ally.mp == mini(ally.max_mp, 30),
		"Elixir applies MP effect"
	)
	_check(
		state.get_item_quantity(&"elixir") == 0,
		"Two-effect Elixir consumes one item"
	)

	_check(
		not state.add_item(&"unknown_item"),
		"Unknown IDs cannot enter inventory through add_item"
	)

	# Verify prevalidation without mutating shared catalog definitions.
	var malformed := GameItem.new()
	malformed.item_id = &"test_invalid"
	malformed.display_name = "Invalid Test Item"

	var valid_effect := ItemEffect.new()
	valid_effect.amount = 20
	malformed.effects.append(valid_effect)

	var invalid_effect := ItemEffect.new()
	invalid_effect.amount = 0
	malformed.effects.append(invalid_effect)

	ally.hp = 1
	result = ItemUseResolver.resolve(malformed, ally)

	_check(
		not bool(result.get("success", false)) and ally.hp == 1,
		"All effects are validated before any mutation"
	)

	print("Party item tests completed: %d failure(s)." % _failures)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures += 1
		push_error("FAIL: %s" % description)
