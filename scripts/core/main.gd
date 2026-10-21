extends Node

const START_SCENE_PATH: String = (
	"res://scenes/exploration/sewer_entrance_test.tscn"
)

const PartyMenuControllerScript = preload(
	"res://scripts/ui/party_menu_controller.gd"
)

## Prototype content toggle. Disable for a game without the test quests.
@export var enable_test_quests: bool = true

@onready var game_layer: Node = $GameLayer
@onready var ui_layer: CanvasLayer = $UILayer

var party_menu_controller: PartyMenuControllerScript
var dialogue_controller: DialogueController
var _quest_banner: QuestUpdateBanner


func _ready() -> void:
	GameState.start_new_game()
	SceneManager.register_main(self)

	print("Main registered with SceneManager.")
	print(
		"New game started with %d party members."
		% GameState.party.size()
	)

	for unit: Unit in GameState.party:
		print(unit.get_summary())

	SceneManager.change_game_scene(START_SCENE_PATH)

	# One central controller outside GameLayer.
	party_menu_controller = PartyMenuControllerScript.new()
	party_menu_controller.name = "PartyMenuController"
	add_child(party_menu_controller)
	party_menu_controller.configure(game_layer)

	# Dialogue remains active while GameLayer is disabled.
	dialogue_controller = DialogueController.new()
	dialogue_controller.name = "DialogueController"
	add_child(dialogue_controller)
	dialogue_controller.configure(
		game_layer,
		party_menu_controller,
		GameState
	)
	dialogue_controller.finished.connect(_on_dialogue_finished)

	# One persistent banner, also outside GameLayer.
	_quest_banner = QuestUpdateBanner.new()
	_quest_banner.name = "QuestUpdateBanner"
	add_child(_quest_banner)
	_quest_banner.configure(_can_show_quest_updates)

	if enable_test_quests:
		for quest_id: String in QuestData.get_all_quest_ids():
			GameState.activate_quest(quest_id)


func request_dialogue(
	source: Node,
	definition: DialogueDefinition
) -> bool:
	if (
		dialogue_controller == null
		or not is_instance_valid(source)
		or source != SceneManager.get_current_game_scene()
	):
		return false

	return dialogue_controller.start_dialogue(definition)


func _on_dialogue_finished(
	dialogue_id: StringName,
	committed: bool
) -> void:
	print(
		"[Dialogue] %s | result committed: %s"
		% [dialogue_id, committed]
	)

	if dialogue_id == DialogueData.ENTRANCE_DIALOGUE_ID:
		print(
			"[Dialogue] careful: %s | curious: %s" % [
				GameState.has_flag(
					"dialogue/sewer_entrance_test/choice/careful"
				),
				GameState.has_flag(
					"dialogue/sewer_entrance_test/choice/curious"
				)
			]
		)


func _can_show_quest_updates() -> bool:
	if (
		not game_layer.can_process()
		or party_menu_controller == null
		or party_menu_controller.is_open()
		or (
			dialogue_controller != null
			and dialogue_controller.is_active()
		)
		or not SceneManager.can_open_party_menu()
	):
		return false

	var scene: Node = SceneManager.get_current_game_scene()

	if (
		not is_instance_valid(scene)
		or not scene.can_process()
		or not scene.has_method("can_show_quest_updates")
	):
		return false

	return bool(scene.call("can_show_quest_updates"))


func get_game_layer() -> Node:
	return game_layer


func get_ui_layer() -> CanvasLayer:
	return ui_layer
