extends SceneTree

var _failures: int = 0
var _talk_count: int = 0
var _result_count: int = 0
var _requested_dialogue: DialogueDefinition


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, description: String) -> void:
	if not value:
		_failures += 1
		push_error(description)


func _on_talk_requested(definition: DialogueDefinition) -> void:
	_talk_count += 1
	_requested_dialogue = definition


func _on_dialogue_result(
	person_id: StringName,
	choice_id: StringName,
	committed: bool
) -> void:
	if person_id == &"barkeeper" and choice_id == &"ask" and committed:
		_result_count += 1


func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.start_new_game()

	var tavern: TavernDefinition = TavernData.get_tavern_for_destination(
		CityData.CITY_NAME,
		&"tavern"
	)

	_check(tavern != null, "Aldenmoor-tavern aanwezig")

	if tavern == null:
		_finish()
		return

	_check(tavern.validation_error().is_empty(), "Taverncontent geldig")
	_check(tavern.persons.size() == 2, "Twee prototypepersonen")
	_check(
		TavernData.get_tavern_for_destination("Other City", &"tavern") == null,
		"Andere stad krijgt geen Aldenmoor-tavern"
	)
	_check(
		TavernData.get_tavern_for_destination(CityData.CITY_NAME, &"shop") == null,
		"Andere bestemming krijgt geen tavern"
	)
	_check(tavern.get_person(&"missing") == null, "Onbekende persoon veilig")

	var person_ids: Dictionary = {}
	var dialogue_ids: Dictionary = {}

	for person: TavernPerson in tavern.persons:
		_check(person.validation_error().is_empty(), "Persoon geldig")
		_check(not person_ids.has(person.person_id), "Uniek persoon-ID")
		_check(
			not dialogue_ids.has(person.dialogue.dialogue_id),
			"Uniek dialogue-ID"
		)
		_check(person.dialogue.allow_replay, "Dialogue herhaalbaar")

		person_ids[person.person_id] = true
		dialogue_ids[person.dialogue.dialogue_id] = true

	var invalid := TavernDefinition.new()
	invalid.tavern_id = &"invalid"
	invalid.display_name = "Invalid"
	invalid.persons.append(tavern.persons[0])
	invalid.persons.append(tavern.persons[0])

	_check(
		not invalid.validation_error().is_empty(),
		"Dubbele persoon geweigerd"
	)

	var gold_before: int = state.gold
	var day_before: float = state.day
	var world_before: StringName = state.world_location_id
	var items_before: Dictionary = state.item_inventory.duplicate(true)
	var gear_before: Dictionary = state.equipment_inventory.duplicate(true)

	var barkeeper: TavernPerson = tavern.get_person(&"barkeeper")

	var committed: bool = state.commit_dialogue_result(
		barkeeper.dialogue,
		&"ask"
	)

	var prefix: String = (
		"dialogue/%s/choice/" % barkeeper.dialogue.dialogue_id
	)

	_check(committed and state.has_flag(prefix + "ask"), "Eerste keuze opgeslagen")

	committed = state.commit_dialogue_result(
		barkeeper.dialogue,
		&"leave"
	)

	_check(
		committed
		and state.has_flag(prefix + "leave")
		and not state.has_flag(prefix + "ask"),
		"Herhaling vervangt de vorige keuze"
	)

	_check(
		state.gold == gold_before
		and is_equal_approx(state.day, day_before)
		and state.world_location_id == world_before
		and state.item_inventory == items_before
		and state.equipment_inventory == gear_before,
		"Dialogue heeft geen gold-, tijd-, locatie- of inventoryeffect"
	)

	# Runtime load: CityScreen refers to the GameState autoload by name,
	# which does not exist yet while this script itself is compiled.
	var city_scene: PackedScene = load("res://scenes/city/city_screen.tscn")
	var city: Variant = city_scene.instantiate()
	root.add_child(city)
	
	# Content/UI test without requesting a real dialogue from Main.
	city._tavern_screen.talk_requested.connect(_on_talk_requested)
	city._tavern_screen.dialogue_result.connect(_on_dialogue_result)

	city._on_destination_selected(&"tavern")

	_check(city._tavern_screen.is_open(), "City opent Tavern")
	_check(city._sub_screen_open(), "Subscreen-helper ziet Tavern")
	_check(not city._locations_layer.visible, "City-labels verborgen")
	_check(not city.can_enter_sewers(), "Sewer-entry geblokkeerd")
	_check(not city.can_open_world_map(), "World map geblokkeerd")
	_check(city.can_open_party_menu(), "Party lokaal beschikbaar")

	city._on_destination_selected(&"shop")
	city._on_destination_selected(&"adventurers_guild")

	_check(
		not city._shop_screen.is_open() and not city._viewing_guild,
		"City-bestemmingen reageren niet achter Tavern"
	)

	city._tavern_screen._talk_to_person(&"barkeeper")

	_check(
		_talk_count == 1 and _requested_dialogue == barkeeper.dialogue,
		"Persoonselectie emit de juiste dialogue"
	)

	city.on_dialogue_finished(
		barkeeper.dialogue.dialogue_id,
		&"ask",
		true
	)

	_check(
		_result_count == 1 and city._tavern_screen.is_open(),
		"City routeert dialogue-resultaat terug naar Tavern"
	)

	city._tavern_screen._close()

	_check(
		not city._sub_screen_open() and city._locations_layer.visible,
		"Back to city sluit Tavern en herstelt city-labels"
	)

	city._on_destination_selected(&"tavern")
	_check(city._tavern_screen.is_open(), "Tweede tavernbezoek werkt")

	city._tavern_screen._close()
	city.free()

	_finish()


func _finish() -> void:
	print("[Tavern] %d failure(s)" % _failures)
	quit(0 if _failures == 0 else 1)
