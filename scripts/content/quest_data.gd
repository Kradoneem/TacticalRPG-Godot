class_name QuestData
extends RefCounted
const GUILD_SEWER_QUEST_ID: String = "guild_sewer_investigation"

## Prototype quests for validating existing sewer gameplay.
## Not final Chapter 1 narrative or reward content.

static var _catalog: Dictionary = {}


static func get_quest(quest_id: String) -> QuestDefinition:
	_ensure_catalog()
	return _catalog.get(quest_id) as QuestDefinition


static func get_all_quest_ids() -> Array[String]:
	_ensure_catalog()

	var ids: Array[String] = []

	for quest_id in _catalog:
		ids.append(String(quest_id))

	return ids


static func _ensure_catalog() -> void:
	if not _catalog.is_empty():
		return

	_register(
		"test_junction_patrol",
		"[TEST] Junction patrol",
		"Validate a quest targeting one independent enemy squad.",
		QuestObjective.Kind.SQUAD_DEFEATED,
		"junction_patrol_rats",
		"Defeat the Junction PATROL squad."
	)

	_register(
		"test_junction_clear",
		"[TEST] Clear junction",
		"Validate a quest targeting all enemies on one map.",
		QuestObjective.Kind.MAP_CLEARED,
		"sewer_junction",
		"Clear the Sewer Junction map."
	)

	_register(
		"test_sewer_slice_clear",
		"[TEST] Clear sewer test slice",
		"Validate a location objective with an explicit combatmap list. "
		+ "This is not the complete Chapter 1 dungeon.",
		QuestObjective.Kind.LOCATION_CLEARED,
		LocationData.SEWER_TEST_SLICE,
		"Clear corridor and junction."
	)

	_register(
		GUILD_SEWER_QUEST_ID,
		"[PROTOTYPE] Sewer investigation",
		"Guild opdracht voor de bestaande sewer test-slice; "
		+ "geen definitieve Chapter 1-opdracht.",
		QuestObjective.Kind.LOCATION_CLEARED,
		LocationData.SEWER_TEST_SLICE,
		"Clear corridor and junction."
	)

static func _register(
	quest_id: String,
	title: String,
	description: String,
	kind: QuestObjective.Kind,
	target_id: String,
	objective_description: String
) -> void:
	var objective := QuestObjective.new()
	objective.objective_id = &"clear_target"
	objective.description = objective_description
	objective.kind = kind
	objective.target_id = target_id

	var quest := QuestDefinition.new()
	quest.quest_id = StringName(quest_id)
	quest.title = title
	quest.description = description
	quest.objectives.append(objective)

	if not quest.is_valid_definition():
		push_error("Invalid quest definition: " + quest_id)
		return

	_catalog[quest_id] = quest
