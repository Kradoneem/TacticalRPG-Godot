extends Node

## Central scene coordinator.
## Main owns the visual layers; SceneManager decides what is loaded into them.

var _main: Node
var _current_game_scene: Node
var _overlay_stack: Array[Node] = []


func register_main(main_node: Node) -> void:
	_main = main_node


func change_game_scene(scene_path: String) -> Node:
	if _main == null:
		push_error("SceneManager has no registered Main node.")
		return null

	var packed_scene: PackedScene = load(scene_path) as PackedScene
	if packed_scene == null:
		push_error("Could not load game scene: %s" % scene_path)
		return null

	if is_instance_valid(_current_game_scene):
		_current_game_scene.queue_free()

	var next_scene: Node = packed_scene.instantiate()
	_current_game_scene = next_scene
	_main.get_game_layer().add_child(_current_game_scene)

	return _current_game_scene


func push_overlay(scene_path: String) -> Node:
	if _main == null:
		push_error("SceneManager has no registered Main node.")
		return null

	var packed_scene: PackedScene = load(scene_path) as PackedScene
	if packed_scene == null:
		push_error("Could not load overlay scene: %s" % scene_path)
		return null

	var overlay: Node = packed_scene.instantiate()
	_main.get_ui_layer().add_child(overlay)
	_overlay_stack.append(overlay)

	return overlay


func pop_overlay() -> void:
	if _overlay_stack.is_empty():
		return

	var top_overlay: Node = _overlay_stack.pop_back()
	if is_instance_valid(top_overlay):
		top_overlay.queue_free()


func clear_overlays() -> void:
	while not _overlay_stack.is_empty():
		pop_overlay()


func get_current_game_scene() -> Node:
	return _current_game_scene
