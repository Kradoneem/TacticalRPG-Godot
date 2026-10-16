extends Node

const START_SCENE_PATH: String = (
    "res://scenes/exploration/sewer_entrance_test.tscn"
)

@onready var game_layer: Node = $GameLayer
@onready var ui_layer: CanvasLayer = $UILayer


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


func get_game_layer() -> Node:
	return game_layer


func get_ui_layer() -> CanvasLayer:
	return ui_layer
