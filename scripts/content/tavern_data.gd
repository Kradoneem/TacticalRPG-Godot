class_name TavernData
extends RefCounted

const ALDENMOOR_TAVERN_ID: StringName = &"aldenmoor_tavern"

static var _catalog: Dictionary = {}


static func get_tavern(tavern_id: StringName) -> TavernDefinition:
	_ensure_catalog()
	return _catalog.get(tavern_id) as TavernDefinition


static func get_tavern_for_destination(
	city: String,
	destination_id: StringName
) -> TavernDefinition:
	if city == CityData.CITY_NAME and destination_id == &"tavern":
		return get_tavern(ALDENMOOR_TAVERN_ID)

	return null


static func _ensure_catalog() -> void:
	if not _catalog.is_empty():
		return

	var tavern := TavernDefinition.new()
	tavern.tavern_id = ALDENMOOR_TAVERN_ID
	tavern.display_name = "Aldenmoor — Tavern"

	# No interior asset yet; TavernScreen uses its color placeholder.
	tavern.persons.append(_make_person(
		&"barkeeper",
		"Barkeeper",
		Vector2(0.32, 0.42),
		&"aldenmoor_tavern_barkeeper",
		"Prototypegesprek: de barkeeper is aanspreekbaar.",
		"Wat kan ik hier doen?",
		"Dit prototype ondersteunt gesprekken. Rusten en bestellen ontbreken."
	))

	tavern.persons.append(_make_person(
		&"patron",
		"Patron",
		Vector2(0.70, 0.62),
		&"aldenmoor_tavern_patron",
		"Prototypegesprek: deze bezoeker heeft nog geen verhaalcontent.",
		"Heb je iets te vertellen?",
		"Nog niet. Dit gesprek test personenselectie en herhaalbare dialogue."
	))

	_catalog[tavern.tavern_id] = tavern


static func _make_person(
	person_id: StringName,
	display_name: String,
	position_ratio: Vector2,
	dialogue_id: StringName,
	opening_text: String,
	question_text: String,
	response_text: String
) -> TavernPerson:
	var definition := DialogueDefinition.new()
	definition.dialogue_id = dialogue_id
	definition.allow_replay = true

	definition.lines.append(DialogueLine.create(
		display_name,
		opening_text
	))

	definition.choices.append(DialogueChoice.create(
		&"ask",
		question_text,
		DialogueLine.create(display_name, response_text)
	))

	definition.choices.append(DialogueChoice.create(
		&"leave",
		"Tot ziens.",
		DialogueLine.create(display_name, "Tot ziens.")
	))

	var person := TavernPerson.new()
	person.person_id = person_id
	person.display_name = display_name
	person.position_ratio = position_ratio
	person.dialogue = definition

	return person
