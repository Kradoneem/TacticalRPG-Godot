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
signal equipment_inventory_changed
signal unit_equipment_changed(unit: Unit)

var party: Array = []
var item_inventory: Dictionary = {}
var squads: Array = []
var equipment_inventory: Dictionary = {}

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

## Globally unique enemy squad ID -> defeat already processed.
## Session state only; disk save/load is still separate.
var defeated_enemy_squads: Dictionary = {}

func start_new_game() -> void:
	party = UnitDataFactory.create_chapter_one_party()

	equipment_inventory.clear()
	item_inventory.clear()
	squads.clear()
	exploration_room_states.clear()
	defeated_enemy_squads.clear()

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

	# Existing prototype stock, not final Chapter 1 balancing.
	item_inventory[&"potion"] = 1
	item_inventory[&"hi_potion"] = 1
	item_inventory[&"ether"] = 1
	item_inventory[&"elixir"] = 1

	equipment_inventory[&"iron_sword"] = 1
	equipment_inventory[&"wooden_shield"] = 1
	equipment_inventory[&"berserkers_ring"] = 1
	equipment_inventory[&"sages_ring"] = 1

	create_chapter_one_main_squad()
	item_inventory_changed.emit()
	equipment_inventory_changed.emit()

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

func get_equipment_quantity(equipment_id: StringName) -> int:
	return int(equipment_inventory.get(equipment_id, 0))


func add_equipment(
	equipment_id: StringName,
	amount: int = 1
) -> bool:
	var gear: Equipment = EquipmentData.get_equipment(equipment_id)

	if (
		amount <= 0
		or gear == null
		or not gear.is_valid_definition()
	):
		return false

	equipment_inventory[equipment_id] = (
		get_equipment_quantity(equipment_id) + amount
	)
	equipment_inventory_changed.emit()
	return true


func change_equipment(
	unit: Unit,
	slot: StringName,
	new_equipment_id: StringName = &""
) -> Dictionary:
	## Empty ID means unequip.
	## No await or signals during the stock-transfer transaction.

	if unit == null:
		return {"success": false, "message": "No unit selected."}

	var squad: Squad = get_squad_of(unit)

	if squad == null or squad.autonomy_mode == Squad.AutonomyMode.ENEMY:
		return {
			"success": false,
			"message": "Choose a member of a player squad."
		}

	if slot not in Equipment.SLOTS:
		return {"success": false, "message": "Unknown equipment slot."}

	var old_id: StringName = unit.get_equipment_id(slot)

	if old_id == new_equipment_id:
		return {
			"success": false,
			"message": "This slot already has that equipment."
		}

	var new_gear: Equipment = null

	if new_equipment_id != &"":
		new_gear = EquipmentData.get_equipment(new_equipment_id)

		if (
			new_gear == null
			or not new_gear.is_valid_definition()
			or StringName(new_gear.slot) != slot
		):
			return {
				"success": false,
				"message": "Equipment does not fit this slot."
			}

		if get_equipment_quantity(new_equipment_id) <= 0:
			return {
				"success": false,
				"message": "This equipment is not available."
			}

	if old_id != &"" and EquipmentData.get_equipment(old_id) == null:
		return {
			"success": false,
			"message": "Current equipment definition is missing."
		}

	if not unit.set_equipment(slot, new_equipment_id):
		return {
			"success": false,
			"message": "Equipment change was rejected."
		}

	if new_equipment_id != &"":
		var remaining: int = (
			get_equipment_quantity(new_equipment_id) - 1
		)

		if remaining == 0:
			equipment_inventory.erase(new_equipment_id)
		else:
			equipment_inventory[new_equipment_id] = remaining

	if old_id != &"":
		equipment_inventory[old_id] = get_equipment_quantity(old_id) + 1

	var message: String

	if new_gear == null:
		message = "%s unequipped %s." % [
			unit.display_name,
			String(slot)
		]
	else:
		message = "%s equipped %s." % [
			unit.display_name,
			new_gear.display_name
		]

	equipment_inventory_changed.emit()
	unit_equipment_changed.emit(unit)

	return {"success": true, "message": message}

func settle_encounter(context: EncounterContext) -> EncounterResult:
	## Called only after BattleSession is finished.
	## No await: validation, claiming and application stay together.

	if context == null:
		return null

	var result: EncounterResult = context.result

	if result.settled:
		return result

	if context.player_squad == null or context.enemy_squad == null:
		result.add_special_message("Encounter result has missing participants.")
		result.settled = true
		return result

	result.enemy_squad_defeated = not context.enemy_squad.is_alive()

	var claimable: bool = (
		result.enemy_squad_defeated
		and context.enemy_was_alive_at_start
		and not context.enemy_squad.is_empty()
		and not context.enemy_squad.squad_id.is_empty()
		and not defeated_enemy_squads.has(context.enemy_squad.squad_id)
	)

	if not claimable:
		result.settled = true
		return result

	var reward_error: String = _validate_encounter_rewards(context)

	if not reward_error.is_empty():
		result.add_special_message(
			"Rewards were not applied: " + reward_error
		)
		result.settled = true
		push_error(reward_error)
		return result

	# Claim before any notifications can call back into settlement.
	defeated_enemy_squads[context.enemy_squad.squad_id] = true
	result.defeat_rewards_claimed = true
	result.settled = true

	for unit: Unit in context.player_squad.members:
		var alive_before: bool = unit.is_alive()
		var level_before: int = unit.level
		var xp_before: int = unit.experience
		var stats_before: Dictionary = _capture_result_stats(unit)

		var xp_gained: int = context.defeat_xp if alive_before else 0
		var levels_gained: int = unit.gain_experience(xp_gained)

		result.unit_results.append({
			"unit_id": unit.unit_id,
			"name": unit.display_name,
			"alive": alive_before,
			"xp_gained": xp_gained,
			"xp_before": xp_before,
			"xp_after": unit.experience,
			"xp_needed": unit.get_experience_to_next_level(),
			"level_before": level_before,
			"level_after": unit.level,
			"levels_gained": levels_gained,
			"stats_before": stats_before,
			"stats_after": _capture_result_stats(unit)
		})

	# Commit inventory data before emitting signals.
	var previous_gold: int = gold
	gold += context.defeat_gold
	result.gold_gained = gold - previous_gold

	for raw_id in context.defeat_items:
		var item_id := StringName(raw_id)
		var amount: int = int(context.defeat_items[raw_id])

		item_inventory[item_id] = get_item_quantity(item_id) + amount
		result.items_gained[item_id] = amount

	if result.gold_gained != 0:
		gold_changed.emit(gold)

	if not result.items_gained.is_empty():
		item_inventory_changed.emit()

	return result


func _validate_encounter_rewards(context: EncounterContext) -> String:
	if context.defeat_xp < 0 or context.defeat_gold < 0:
		return "XP and gold rewards cannot be negative."

	var seen_ids: Dictionary = {}

	for raw_id in context.defeat_items:
		if not raw_id is String and not raw_id is StringName:
			return "Reward item IDs must be strings."

		var item_id := StringName(raw_id)

		if seen_ids.has(item_id):
			return "Duplicate reward item ID."

		seen_ids[item_id] = true

		if ItemData.get_item(item_id) == null:
			return "Unknown reward item: %s." % item_id

		var amount: Variant = context.defeat_items[raw_id]

		if not amount is int or int(amount) <= 0:
			return "Item reward quantities must be positive integers."

	return ""


func _capture_result_stats(unit: Unit) -> Dictionary:
	return {
		"max_hp": unit.max_hp,
		"attack": unit.attack,
		"defense": unit.defense,
		"speed": unit.speed,
		"wisdom": unit.wisdom
	}


func is_enemy_squad_defeated(squad_id: String) -> bool:
	return bool(defeated_enemy_squads.get(squad_id, false))


func is_map_cleared(room_id: String) -> bool:
	## Queries actual saved gameplay state.
	## Unknown and enemy-free maps do not imply combat completion.

	if not exploration_room_states.has(room_id):
		return false

	var room: Dictionary = exploration_room_states[room_id]
	var enemies: Dictionary = room.get("enemies", {})

	if enemies.is_empty():
		return false

	for enemy_state: Dictionary in enemies.values():
		var enemy_squad: Squad = enemy_state.get("squad")

		if (
			enemy_squad == null
			or enemy_squad.is_empty()
			or enemy_squad.is_alive()
		):
			return false

	return true


func are_location_maps_cleared(required_map_ids: Array[String]) -> bool:
	## A future location/quest definition supplies the full explicit list.
	## Never infer location completion from only the visited maps.

	if required_map_ids.is_empty():
		return false

	for room_id: String in required_map_ids:
		if not is_map_cleared(room_id):
			return false

	return true
