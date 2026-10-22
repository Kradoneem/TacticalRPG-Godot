extends SceneTree

var _failures: int = 0
var _state: Node
var _notifications: int = 0
var _nested_result: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		push_error(description)


func _on_chest_opened(chest_id: StringName) -> void:
	_notifications += 1

	_check(
		_state.is_chest_opened(chest_id),
		"Opened-state bestaat vóór chest_opened"
	)
	_check(
		_state.get_item_quantity(&"potion") == 2,
		"Loot bestaat vóór chest_opened"
	)

	_nested_result = _state.open_chest(chest_id)

func _run() -> void:
	_state = root.get_node("GameState")
	_state.start_new_game()

	var definition: ChestDefinition = ChestData.get_chest(
		ChestData.CORRIDOR_CHEST_ID
	)

	_check(
		definition != null and definition.validation_error().is_empty(),
		"Prototypechest geldig"
	)

	if definition == null:
		_finish()
		return

	_check(
		ChestData.get_chests_for_room("sewer_corridor").size() == 1,
		"Eén corridorchest"
	)
	_check(
		ChestData.get_chests_for_room("unknown").is_empty(),
		"Onbekende map heeft geen chests"
	)

	var gold_before: int = _state.gold
	var day_before: float = _state.day
	var gear_before: Dictionary = _state.equipment_inventory.duplicate(true)

	_state.chest_opened.connect(_on_chest_opened)

	var result: Dictionary = _state.open_chest(
		ChestData.CORRIDOR_CHEST_ID
	)

	_check(
		result.success
		and _state.get_item_quantity(&"potion") == 2
		and _notifications == 1,
		"Chest kent één Potion toe"
	)
	_check(
		not bool(_nested_result.get("success", true)),
		"Reentrant opening geweigerd"
	)

	result = _state.open_chest(ChestData.CORRIDOR_CHEST_ID)

	_check(
		not result.success
		and _state.get_item_quantity(&"potion") == 2
		and _notifications == 1,
		"Tweede opening geeft geen loot of signal"
	)

	result = _state.open_chest(&"missing")

	_check(
		not result.success and _state.opened_chests.size() == 1,
		"Onbekende chest muteert niets"
	)

	_check(
		_state.gold == gold_before
		and is_equal_approx(_state.day, day_before)
		and _state.equipment_inventory == gear_before,
		"Prototypechest verandert gold, dag en equipment niet"
	)

	var invalid := ChestDefinition.new()
	invalid.chest_id = &"invalid"
	invalid.room_id = "test"
	invalid.items[&"missing_item"] = 1

	_check(
		not invalid.validation_error().is_empty(),
		"Onbekende loot geweigerd"
	)

	invalid.items.clear()
	invalid.equipment[&"iron_sword"] = 1

	_check(
		invalid.validation_error().is_empty(),
		"Bestaand equipment ondersteund"
	)

	invalid.equipment[&"iron_sword"] = 0

	_check(
		not invalid.validation_error().is_empty(),
		"Nulhoeveelheid geweigerd"
	)

	_state.chest_opened.disconnect(_on_chest_opened)
	_state.start_new_game()

	_check(_state.opened_chests.is_empty(), "Nieuwe game reset opened-state")

	const MAX_INT: int = 9223372036854775807
	_state.item_inventory[&"potion"] = MAX_INT

	result = _state.open_chest(ChestData.CORRIDOR_CHEST_ID)

	_check(
		not result.success
		and not _state.is_chest_opened(ChestData.CORRIDOR_CHEST_ID)
		and _state.get_item_quantity(&"potion") == MAX_INT,
		"Overflow weigert de volledige opening"
	)

	# Load scripts using autoload names only after autoload initialization.
	var main_scene: PackedScene = load("res://scenes/core/main.tscn")
	var main: Node = main_scene.instantiate()
	root.add_child(main)
	current_scene = main

	await process_frame

	var manager: Node = root.get_node("SceneManager")
	var corridor: Variant = manager.change_game_scene(
		"res://scenes/exploration/sewer_corridor_test.tscn"
	)

	_check(corridor != null, "Echte corridor geladen")

	if corridor == null:
		_finish()
		return

	await process_frame

	_check(corridor._chests != null, "Corridor heeft chestcontroller")

	if corridor._chests == null:
		_finish()
		return

	result = corridor._chests.try_open_adjacent()
	_check(not result.success, "Niet-adjacent opening geweigerd")

	corridor.player_marker.move_to(Vector2i(0, 3))
	corridor._runtime.turns.refresh_notice()

	_check(corridor.can_open_chest(), "Chest bereikbaar buiten alert")

	# Runtime-loaded enum: no compile-time TacticalTurnController reference.
	var turn_script: Variant = load(
		"res://scripts/systems/tactical_turn_controller.gd"
	)
	var turns: Variant = corridor._runtime.turns
	var previous_state: int = int(turns.state)
	turns.state = turn_script.State.ALERT_PLAYER_MOVEMENT_SELECTION

	result = corridor._chests.try_open_adjacent()

	_check(
		not result.success
		and not _state.is_chest_opened(ChestData.CORRIDOR_CHEST_ID),
		"Alert weigert opening"
	)

	turns.state = previous_state

	result = corridor._chests.try_open_adjacent()

	_check(
		result.success
		and _state.get_item_quantity(&"potion") == 2,
		"Adjacent opening via echte corridor werkt"
	)

	result = corridor._chests.try_open_adjacent()
	_check(not result.success, "Controller kent geen dubbele loot toe")

	manager.change_game_scene("res://scenes/world/world_map_screen.tscn")

	var replacement: Variant = manager.change_game_scene(
		"res://scenes/exploration/sewer_corridor_test.tscn"
	)

	await process_frame

	_check(
		replacement != null
		and _state.is_chest_opened(ChestData.CORRIDOR_CHEST_ID),
		"Opened-state overleeft mapinstance-vervanging"
	)

	if replacement != null and replacement._chests != null:
		replacement.player_marker.move_to(Vector2i(0, 3))
		replacement._runtime.turns.refresh_notice()

		result = replacement._chests.try_open_adjacent()

		_check(
			not result.success and _state.get_item_quantity(&"potion") == 2,
			"Nieuwe mapinstance kent geen nieuwe loot toe"
		)

	_finish()

func _finish() -> void:
	print("[Chests] %d failure(s)" % _failures)
	quit(0 if _failures == 0 else 1)
