extends Node

const UnitDataFactory = preload("res://scripts/domain/unit_data.gd")
const SquadData = preload("res://scripts/domain/squad.gd")

## Global gameplay state, retained across scene changes.
## Room enemies do not belong to the player's squad roster.

signal gold_changed(new_amount: int)
signal day_advanced(new_day: float, reason: String)
signal flag_changed(flag_id: String, enabled: bool)
signal quest_status_changed(quest_id: String, new_status: String)
signal squads_changed
signal item_inventory_changed

var party: Array = []
var equipment_inventory: Array = []
var item_inventory: Dictionary = {}
var squads: Array = []

var chapter: int = 1
var day: float = 1.0
var gold: int = 100
var squad_cap: int = 2

var current_city: String = "Aldenmoor"
var current_location: String = "Aldenmoor"
var in_city: bool = true

var flags: Dictionary = {}
var quest_states: Dictionary = {}
var cleared_locations: Dictionary = {}

## Session persistence only: not disk save/load.
var exploration_room_states: Dictionary = {}

func start_new_game() -> void:
	party = UnitDataFactory.create_chapter_one_party()

	equipment_inventory.clear()
	item_inventory.clear()
	squads.clear()
	exploration_room_states.clear()

	chapter = 1
	day = 1.0
	gold = 100
	squad_cap = 2

	current_city = "Aldenmoor"
	current_location = "Aldenmoor"
	in_city = true

	flags.clear()
	quest_states.clear()
	cleared_locations.clear()

	# Python prototype stock, excluding Group Potion.
	item_inventory[&"potion"] = 1
	item_inventory[&"hi_potion"] = 1
	item_inventory[&"ether"] = 1
	item_inventory[&"elixir"] = 1

	create_chapter_one_main_squad()
	item_inventory_changed.emit()

	var main_squad = get_main_squad()

	if main_squad != null:
		print("New game ready: %s" % main_squad.get_summary())

func create_chapter_one_main_squad() -> void:
	if party.size() < 2:
		push_error(
            "GameState could not create the Main Squad: "
			+ "Chapter 1 needs at least two party members."
		)
		return

	var main_squad = SquadData.new(
		"main_squad",
		"Main Squad",
		SquadData.AutonomyMode.MAIN_SQUAD
	)

	main_squad.default_strategy = &"balanced"
	main_squad.add_member(party[0])
	main_squad.add_member(party[1])

	squads.append(main_squad)
	squads_changed.emit()


func get_main_squad():
	for squad in squads:
		if squad.autonomy_mode == SquadData.AutonomyMode.MAIN_SQUAD:
			return squad

	return null


func get_squad_of(unit: Unit):
	for squad in squads:
		if squad.contains_member(unit):
			return squad

	return null


func add_gold(amount: int) -> void:
	gold = maxi(0, gold + amount)
	gold_changed.emit(gold)


func advance_day(amount: float, reason: String) -> void:
	if amount <= 0.0:
		push_warning("GameState.advance_day received a non-positive amount.")
		return

	day += amount
	day_advanced.emit(day, reason)


func set_flag(flag_id: String, enabled: bool = true) -> void:
	flags[flag_id] = enabled
	flag_changed.emit(flag_id, enabled)


func has_flag(flag_id: String) -> bool:
	return flags.get(flag_id, false)


func mark_location_cleared(location_id: String) -> void:
	cleared_locations[location_id] = true


func is_location_cleared(location_id: String) -> bool:
	return cleared_locations.get(location_id, false)


func activate_quest(quest_id: String) -> void:
	set_quest_status(quest_id, "active")


func complete_quest(quest_id: String) -> void:
	set_quest_status(quest_id, "completed")


func get_quest_status(quest_id: String) -> String:
	return quest_states.get(quest_id, "inactive")


func set_quest_status(quest_id: String, new_status: String) -> void:
	quest_states[quest_id] = new_status
	quest_status_changed.emit(quest_id, new_status)

func get_item_quantity(item_id: StringName) -> int:
	return int(item_inventory.get(item_id, 0))


func add_item(item_id: StringName, amount: int = 1) -> bool:
	if amount <= 0:
		return false

	if ItemData.get_item(item_id) == null:
		push_warning("Cannot add unknown item: %s" % item_id)
		return false

	item_inventory[item_id] = get_item_quantity(item_id) + amount
	item_inventory_changed.emit()

	return true


func use_item(item_id: StringName, target: Unit) -> Dictionary:
	var quantity: int = get_item_quantity(item_id)

	if quantity <= 0:
		return {
			"success": false,
			"message": "This item is not in inventory."
		}

	var item: GameItem = ItemData.get_item(item_id)

	if item == null:
		return {
			"success": false,
			"message": "Unknown item."
		}

	if target == null:
		return {
			"success": false,
			"message": "No target selected."
		}

	var target_squad: Squad = get_squad_of(target)

	if (
		target_squad == null
		or target_squad.autonomy_mode == Squad.AutonomyMode.ENEMY
	):
		return {
			"success": false,
			"message": "Choose a member of a player squad."
		}

	var result: Dictionary = ItemUseResolver.resolve(item, target)

	if not bool(result.get("success", false)):
		return result

	# Synchronous: no await between validation, effects and consumption.
	# One use consumes one item, regardless of the number of effects.
	if quantity == 1:
		item_inventory.erase(item_id)
	else:
		item_inventory[item_id] = quantity - 1

	item_inventory_changed.emit()

	return result
