extends SceneTree

var _failures: int = 0
var _day_signals: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, description: String) -> void:
	if not value:
		_failures += 1
		push_error(description)


func _on_day_advanced(_new_day: float, _reason: String) -> void:
	_day_signals += 1


func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.start_new_game()
	state.day_advanced.connect(_on_day_advanced)

	for location: WorldLocation in WorldMapData.get_locations():
		_check(
			location.validation_error().is_empty(),
			"Locatie geldig: %s" % location.location_id
		)

	var aldenmoor: WorldLocation = WorldMapData.get_location(
		WorldMapData.ALDENMOOR_ID
	)

	_check(
		aldenmoor.display_name == CityData.CITY_NAME
		and not aldenmoor.is_prototype,
		"Aldenmoor deelt naam met CityData en is geen prototype"
	)

	_check(
		WorldMapData.get_location(WorldMapData.PROTOTYPE_A_ID).is_prototype
		and WorldMapData.get_location(WorldMapData.PROTOTYPE_B_ID).is_prototype,
		"Prototypelocaties gemarkeerd"
	)

	_check(
		state.world_location_id == WorldMapData.ALDENMOOR_ID
		and is_equal_approx(state.day, 1.0),
		"Start in Aldenmoor op dag 1"
	)

	var result: Dictionary = state.travel_to_location(
		WorldMapData.PROTOTYPE_A_ID
	)

	_check(
		result.success
		and state.world_location_id == WorldMapData.PROTOTYPE_A_ID
		and is_equal_approx(state.day, 2.0)
		and _day_signals == 1,
		"Reis naar A: locatie, +1 dag, één day_advanced"
	)

	result = state.travel_to_location(WorldMapData.PROTOTYPE_A_ID)

	_check(
		not result.success
		and is_equal_approx(state.day, 2.0)
		and _day_signals == 1,
		"Reis naar huidige locatie muteert niets"
	)

	result = state.travel_to_location(WorldMapData.PROTOTYPE_B_ID)

	_check(
		not result.success
		and state.world_location_id == WorldMapData.PROTOTYPE_A_ID
		and is_equal_approx(state.day, 2.0)
		and _day_signals == 1,
		"A naar B (niet verbonden) muteert niets"
	)

	result = state.travel_to_location(&"does_not_exist")

	_check(
		not result.success
		and is_equal_approx(state.day, 2.0)
		and _day_signals == 1,
		"Onbekende locatie muteert niets"
	)

	result = state.travel_to_location(WorldMapData.ALDENMOOR_ID)

	_check(
		result.success
		and state.world_location_id == WorldMapData.ALDENMOOR_ID
		and is_equal_approx(state.day, 3.0)
		and _day_signals == 2,
		"Terugreis kost opnieuw een dag"
	)

	print("[WorldTravel] %d failure(s)" % _failures)
	quit(0 if _failures == 0 else 1)
