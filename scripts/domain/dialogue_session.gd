class_name DialogueSession
extends RefCounted

## Runtime progress only.
## Does not access GameState, SceneTree or presentation nodes.

enum Phase {
	OPENING,
	CHOICE,
	RESPONSE,
	FINISHED,
	CANCELLED
}

var definition: DialogueDefinition
var phase: Phase = Phase.CANCELLED

var _line_index: int = 0
var _selected_choice: DialogueChoice


func begin(new_definition: DialogueDefinition) -> bool:
	if (
		new_definition == null
		or not new_definition.validation_error().is_empty()
	):
		return false

	definition = new_definition
	_line_index = 0
	_selected_choice = null
	phase = Phase.OPENING
	return true


func get_current_line() -> DialogueLine:
	if definition == null:
		return null

	if phase == Phase.OPENING:
		return definition.lines[_line_index]

	if phase == Phase.RESPONSE and _selected_choice != null:
		return _selected_choice.response

	return null


func get_choices() -> Array[DialogueChoice]:
	var result: Array[DialogueChoice] = []

	if definition != null and phase == Phase.CHOICE:
		result.append_array(definition.choices)

	return result


func advance() -> bool:
	match phase:
		Phase.OPENING:
			_line_index += 1

			if _line_index >= definition.lines.size():
				phase = Phase.CHOICE

			return true

		Phase.RESPONSE:
			phase = Phase.FINISHED
			return true

		_:
			return false


func choose(choice_id: StringName) -> bool:
	if phase != Phase.CHOICE:
		return false

	for choice: DialogueChoice in definition.choices:
		if choice.choice_id == choice_id:
			_selected_choice = choice
			phase = Phase.RESPONSE
			return true

	return false


func cancel() -> void:
	if phase in [Phase.FINISHED, Phase.CANCELLED]:
		return

	_selected_choice = null
	phase = Phase.CANCELLED


func get_result_choice_id() -> StringName:
	if phase != Phase.FINISHED or _selected_choice == null:
		return &""

	return _selected_choice.choice_id
