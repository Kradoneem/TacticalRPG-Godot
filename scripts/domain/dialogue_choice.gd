class_name DialogueChoice
extends Resource

## One answer and its immediate response.
## Rewards and gameplay formulas do not belong here.

@export var choice_id: StringName = &""
@export_multiline var text: String = ""
@export var response: DialogueLine


static func create(
	id: StringName,
	answer_text: String,
	answer_response: DialogueLine
) -> DialogueChoice:
	var choice := DialogueChoice.new()
	choice.choice_id = id
	choice.text = answer_text
	choice.response = answer_response
	return choice
