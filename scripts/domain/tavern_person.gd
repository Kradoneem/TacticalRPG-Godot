class_name TavernPerson
extends Resource

@export var person_id: StringName = &""
@export var display_name: String = ""
@export var position_ratio: Vector2 = Vector2(0.5, 0.5)
@export var dialogue: DialogueDefinition


func validation_error() -> String:
	if person_id == &"":
		return "Tavernpersoon heeft geen ID."

	if display_name.strip_edges().is_empty():
		return "Tavernpersoon heeft geen naam: %s" % person_id

	if (
		not position_ratio.is_finite()
		or position_ratio.x < 0.0
		or position_ratio.x > 1.0
		or position_ratio.y < 0.0
		or position_ratio.y > 1.0
	):
		return "Tavernpersoon staat buiten de afbeelding: %s" % person_id

	if dialogue == null:
		return "Dialogue ontbreekt: %s" % person_id

	if not dialogue.allow_replay:
		return "Taverndialogue moet herhaalbaar zijn: %s" % person_id

	return dialogue.validation_error()
