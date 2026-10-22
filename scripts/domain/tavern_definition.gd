class_name TavernDefinition
extends Resource

@export var tavern_id: StringName = &""
@export var display_name: String = ""
@export var background: Texture2D
@export var persons: Array[TavernPerson] = []


func get_person(person_id: StringName) -> TavernPerson:
	for person: TavernPerson in persons:
		if person != null and person.person_id == person_id:
			return person

	return null


func validation_error() -> String:
	if tavern_id == &"":
		return "Tavern-ID ontbreekt."

	if display_name.strip_edges().is_empty():
		return "Tavernnaam ontbreekt."

	if persons.is_empty():
		return "Tavern heeft geen personen."

	var person_ids: Dictionary = {}
	var dialogue_ids: Dictionary = {}

	for person: TavernPerson in persons:
		if person == null:
			return "Lege tavernpersoon."

		var problem: String = person.validation_error()

		if not problem.is_empty():
			return problem

		if person_ids.has(person.person_id):
			return "Dubbel persoon-ID: %s" % person.person_id

		var dialogue_id: StringName = person.dialogue.dialogue_id

		if dialogue_ids.has(dialogue_id):
			return "Dubbel dialogue-ID: %s" % dialogue_id

		person_ids[person.person_id] = true
		dialogue_ids[dialogue_id] = true

	return ""
