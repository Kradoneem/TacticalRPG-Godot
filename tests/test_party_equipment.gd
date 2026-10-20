extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var state: Node = root.get_node("GameState")
	state.start_new_game()

	var squad: Squad = state.get_main_squad()
	var hero: Unit = squad.members[0]
	var friend: Unit = squad.members[1]
	var original_attack: int = hero.attack
	var original_defense: int = hero.defense
	var original_max_hp: int = hero.max_hp
	var known_abilities: Array[StringName] = hero.get_all_learned_ability_ids()

	var result: Dictionary = state.change_equipment(
		hero, &"weapon", &"iron_sword"
	)

	_check(bool(result["success"]), "Sword equips")
	_check(hero.attack == original_attack + 5, "Sword adds Attack")
	_check(hero.base_attack == original_attack, "Base Attack stays unchanged")
	_check(
		state.get_equipment_quantity(&"iron_sword") == 0,
		"Equipped sword leaves available stock"
	)

	result = state.change_equipment(friend, &"weapon", &"iron_sword")
	_check(
		not bool(result["success"]),
		"Same owned sword cannot equip on a second unit"
	)

	result = state.change_equipment(hero, &"weapon", &"iron_sword")
	_check(
		not bool(result["success"]) and hero.attack == original_attack + 5,
		"Repeated same equip does not stack bonuses"
	)

	result = state.change_equipment(hero, &"armor", &"sages_ring")
	_check(
		not bool(result["success"]),
		"Wrong slot is rejected"
	)
	_check(
		state.get_equipment_quantity(&"sages_ring") == 1,
		"Rejected change preserves stock"
	)

	state.change_equipment(hero, &"accessory", &"berserkers_ring")
	_check(hero.attack == original_attack + 9, "Different slots combine bonuses")

	state.change_equipment(hero, &"accessory", &"sages_ring")
	_check(hero.attack == original_attack + 5, "Replacing ring removes old bonus")
	_check(hero.wisdom == hero.base_wisdom + 4, "New ring adds Wisdom")
	_check(
		state.get_equipment_quantity(&"berserkers_ring") == 1,
		"Replaced ring returns to inventory"
	)

	hero.hp = maxi(1, original_max_hp / 2)
	var before_hp: int = hero.hp

	state.change_equipment(hero, &"armor", &"wooden_shield")
	_check(
		hero.max_hp == original_max_hp + 5,
		"Shield increases effective maximum HP"
	)
	_check(
		hero.defense == original_defense + 3,
		"Shield adds Defense"
	)
	_check(
		hero.hp == maxi(
			1,
			floori(float(before_hp) * float(hero.max_hp) / float(original_max_hp))
		),
		"Shield preserves HP ratio rounded down"
	)

	state.change_equipment(hero, &"armor")
	_check(hero.max_hp == original_max_hp, "Unequip restores maximum HP")
	_check(hero.hp <= before_hp, "Equip/unequip does not heal")

	hero.hp = 0
	state.change_equipment(hero, &"armor", &"wooden_shield")
	_check(hero.hp == 0, "HP gear does not revive")
	state.change_equipment(hero, &"armor")

	state.change_equipment(hero, &"weapon")
	_check(hero.attack == original_attack, "Unequip restores Attack")
	_check(
		state.get_equipment_quantity(&"iron_sword") == 1,
		"Unequipped sword returns to inventory"
	)

	state.change_equipment(hero, &"weapon", &"iron_sword")
	hero.level_up()
	_check(
		hero.attack == original_attack + 1 + 5,
		"Level-up changes base stats while retaining gear bonus"
	)
	state.change_equipment(hero, &"weapon")
	_check(
		hero.attack == original_attack + 1,
		"Unequip after level-up retains progression"
	)

	_check(
		hero.get_all_learned_ability_ids() == known_abilities,
		"Equipment does not alter learned abilities"
	)
	_check(state.party[0] == hero, "Shared Unit identity is preserved")

	hero.hp = 1
	result = state.use_item(&"potion", hero)
	_check(
		bool(result["success"]) and hero.hp == mini(hero.max_hp, 21),
		"Recovery items still work with effective stat properties"
	)

	print("Equipment tests completed: %d failure(s)." % _failures)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures += 1
		push_error("FAIL: %s" % description)
