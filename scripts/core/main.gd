extends Node

const START_SCENE_PATH: String = "res://scenes/city/city_screen.tscn"

const PartyMenuControllerScript = preload(
	"res://scripts/ui/party_menu_controller.gd"
)

@export var enable_test_quests: bool = false

@onready var game_layer: Node = $GameLayer
@onready var ui_layer: CanvasLayer = $UILayer

var party_menu_controller: PartyMenuControllerScript
var dialogue_controller: DialogueController
var _quest_banner: QuestUpdateBanner
var _dialogue_request_source: Node


func _ready() -> void:
	GameState.start_new_game()
	SceneManager.register_main(self)

	party_menu_controller = PartyMenuControllerScript.new()
	party_menu_controller.name = "PartyMenuController"
	add_child(party_menu_controller)
	party_menu_controller.configure(game_layer)

	dialogue_controller = DialogueController.new()
	dialogue_controller.name = "DialogueController"
	add_child(dialogue_controller)
	dialogue_controller.configure(
		game_layer,
		party_menu_controller,
		GameState
	)
	dialogue_controller.finished.connect(_on_dialogue_finished)
	dialogue_controller.cancelled.connect(_on_dialogue_cancelled)

	_quest_banner = QuestUpdateBanner.new()
	_quest_banner.name = "QuestUpdateBanner"
	add_child(_quest_banner)
	_quest_banner.configure(_can_show_quest_updates)

	SceneManager.change_game_scene(START_SCENE_PATH)

	if enable_test_quests:
		for quest_id: String in QuestData.get_all_quest_ids():
			if quest_id != QuestData.GUILD_SEWER_QUEST_ID:
				GameState.activate_quest(quest_id)


func request_dialogue(
	source: Node,
	definition: DialogueDefinition
) -> bool:
	if (
		dialogue_controller == null
		or dialogue_controller.is_active()
		or not is_instance_valid(source)
		or source != SceneManager.get_current_game_scene()
	):
		return false

	_dialogue_request_source = source

	if not dialogue_controller.start_dialogue(definition):
		_dialogue_request_source = null
		return false

	return true


func _on_dialogue_finished(
	dialogue_id: StringName,
	choice_id: StringName,
	committed: bool
) -> void:
	var source: Node = _dialogue_request_source
	_dialogue_request_source = null

	if (
		is_instance_valid(source)
		and source == SceneManager.get_current_game_scene()
		and source.has_method("on_dialogue_finished")
	):
		source.call(
			"on_dialogue_finished",
			dialogue_id,
			choice_id,
			committed
		)


func _on_dialogue_cancelled(_dialogue_id: StringName) -> void:
	_dialogue_request_source = null


func _can_show_quest_updates() -> bool:
	if (
		not game_layer.can_process()
		or party_menu_controller == null
		or party_menu_controller.is_open()
		or dialogue_controller == null
		or dialogue_controller.is_active()
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
