class_name DialogueDefinition
extends Resource

## Minimal contract: opening lines, one choice, one response.
## More complex branching is deliberately outside this milestone.

@export var dialogue_id: StringName = &""
@export var lines: Array[DialogueLine] = []
@export var choices: Array[DialogueChoice] = []


func validation_error() -> String:
	if dialogue_id == &"":
		return "Dialogue requires an ID."

	if lines.is_empty():
		return "Dialogue requires at least one opening line."

	for line: DialogueLine in lines:
		if line == null or line.text.strip_edges().is_empty():
			return "Dialogue contains an empty opening line."

	if choices.size() < 2:
		return "This dialogue requires at least two choices."

	var seen_ids: Dictionary = {}

	for choice: DialogueChoice in choices:
		if choice == null or choice.choice_id == &"":
			return "Dialogue contains a choice without an ID."

		if seen_ids.has(choice.choice_id):
			return "Dialogue choice IDs must be unique."

		seen_ids[choice.choice_id] = true

		if choice.text.strip_edges().is_empty():
			return "Dialogue contains an empty answer."

		if (
			choice.response == null
			or choice.response.text.strip_edges().is_empty()
		):
			return "Dialogue choice requires a response."

	return ""
