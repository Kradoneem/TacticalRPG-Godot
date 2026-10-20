class_name QuestDefinition
extends Resource

## Shared catalog definition. Progress belongs to GameState.

@export var quest_id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var objectives: Array[QuestObjective] = []


func is_valid_definition() -> bool:
	if (
		quest_id == &""
		or title.strip_edges().is_empty()
		or objectives.is_empty()
	):
		return false

	var known_ids: Dictionary = {}

	for objective: QuestObjective in objectives:
		if objective == null or not objective.is_valid_definition():
			return false

		if known_ids.has(objective.objective_id):
			return false

		known_ids[objective.objective_id] = true

	return true
