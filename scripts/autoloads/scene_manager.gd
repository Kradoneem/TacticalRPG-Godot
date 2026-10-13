extends Node

## Central scene coordinator.
## Main owns the visual layers; SceneManager decides what is loaded into them.
##
## A regular game-scene change replaces the current scene.
## A temporary game presentation, such as BattleScene, hides the current
## game scene but keeps it alive so its tactical state is retained.

var _main: Node
var _current_game_scene: Node
var _overlay_stack: Array[Node] = []

var _active_game_presentation: Node


func register_main(main_node: Node) -> void:
	_main = main_node


func change_game_scene(scene_path: String) -> Node:
	if _main == null:
		push_error("SceneManager has no registered Main node.")
		return null

	_remove_active_game_presentation()

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


func present_game_scene(
	scene_path: String,
	context: Variant = null
) -> Node:
	if _main == null:
		push_error("SceneManager has no registered Main node.")
		return null

	if not is_instance_valid(_current_game_scene):
		push_error(
			"SceneManager cannot present a temporary scene without "
			+ "an active game scene."
		)
		return null

	if is_instance_valid(_active_game_presentation):
		push_warning(
			"SceneManager already has an active temporary game presentation."
		)
		return null

	var packed_scene: PackedScene = load(scene_path) as PackedScene

	if packed_scene == null:
		push_error("Could not load temporary game scene: %s" % scene_path)
		return null

	_current_game_scene.hide()

	var presentation: Node = packed_scene.instantiate()
	_active_game_presentation = presentation
	_main.get_game_layer().add_child(presentation)

	if presentation.has_method("configure"):
		presentation.call("configure", context)

	if presentation.has_signal("presentation_finished"):
		presentation.connect(
			"presentation_finished",
			_on_game_presentation_finished.bind(presentation)
		)

	return presentation


func _on_game_presentation_finished(
	context: Variant,
	presentation: Node
) -> void:
	dismiss_game_presentation(presentation, context)


func dismiss_game_presentation(
	presentation: Node,
	context: Variant = null
) -> void:
	if presentation != _active_game_presentation:
		push_warning(
			"SceneManager received a dismissal request from a non-active "
			+ "game presentation."
		)
		return

	if is_instance_valid(_active_game_presentation):
		_active_game_presentation.queue_free()

	_active_game_presentation = null

	if not is_instance_valid(_current_game_scene):
		return

	_current_game_scene.show()

	if _current_game_scene.has_method("on_game_presentation_finished"):
		_current_game_scene.call_deferred(
			"on_game_presentation_finished",
			context
		)


func _remove_active_game_presentation() -> void:
	if not is_instance_valid(_active_game_presentation):
		_active_game_presentation = null
		return

	_active_game_presentation.queue_free()
	_active_game_presentation = null


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
