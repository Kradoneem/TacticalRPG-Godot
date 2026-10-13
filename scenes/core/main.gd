extends Node

const TACTICAL_TEST_SCENE_PATH: String = "res://scenes/tactical/tacticaltest.tscn"

@onready var game_layer: Node = $GameLayer
@onready var ui_layer: CanvasLayer = $UILayer


func _ready() -> void:
	SceneManager.register_main(self)
	print("Main registered with SceneManager.")

	SceneManager.change_game_scene(TACTICAL_TEST_SCENE_PATH)


func get_game_layer() -> Node:
	return game_layer


func get_ui_layer() -> CanvasLayer:
	return ui_layer
