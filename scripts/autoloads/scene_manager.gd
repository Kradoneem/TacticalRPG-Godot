extends Node

## Main owns visual layers.
## Exploration maps may be retained outside the tree during this session.
## Battle presentations retain the currently active map inside the tree.

var _main: Node
var _current_game_scene: Node
var _overlay_stack: Array[Node] = []
var _active_game_presentation: Node

var _exploration_cache: Dictionary = {}


func register_main(main_node: Node) -> void:
	_clear_exploration_cache()
	_main = main_node


func _clear_exploration_cache() -> void:
	for cached_scene: Node in _exploration_cache.values():
		if (
			is_instance_valid(cached_scene)
			and cached_scene != _current_game_scene
		):
			cached_scene.free()

	_exploration_cache.clear()


func change_game_scene(scene_path: String) -> Node:
	if not is_instance_valid(_main):
		push_error("SceneManager has no registered Main node.")
		return null

	var packed_scene: PackedScene = load(scene_path) as PackedScene

	if packed_scene == null:
		push_error("Could not load game scene: %s" % scene_path)
		return null

	var next_scene: Node = packed_scene.instantiate()

	_remove_active_game_presentation()
	_clear_exploration_cache()

	if is_instance_valid(_current_game_scene):
		_current_game_scene.queue_free()

	_current_game_scene = next_scene
	_main.get_game_layer().add_child(next_scene)
	return next_scene


func travel_exploration(
	source: Node,
	exit_data: ExplorationExitData,
	departure_cell: Vector2i
) -> Node:
	if (
		not is_instance_valid(_main)
		or source != _current_game_scene
		or not is_instance_valid(source)
	):
		push_warning("Exploration travel requires the active map and Main.")
		return null

	if is_instance_valid(_active_game_presentation):
		push_warning("Cannot change exploration maps during presentation.")
		return null

	if exit_data == null or not exit_data.is_valid():
		push_error("Exploration travel received an invalid exit.")
		return null

	var source_path: String = source.scene_file_path
	var destination_path: String = exit_data.destination_scene

	if source_path.is_empty() or source_path == destination_path:
		push_error("Exploration travel requires two different scene paths.")
		return null

	var destination: Node = _exploration_cache.get(destination_path)
	var reused: bool = is_instance_valid(destination)

	if not reused:
		var packed_scene: PackedScene = load(destination_path) as PackedScene

		if packed_scene == null:
			push_error("Could not load exploration map: " + destination_path)
			return null

		destination = packed_scene.instantiate()

	if not destination.has_method("prepare_exploration_entry"):
		if not reused:
			destination.free()

		push_error("Destination lacks prepare_exploration_entry().")
		return null

	var saved_departures: Dictionary = destination.get_meta(
		"exploration_departures", {}
	)
	var arrival_cell: Vector2i = saved_departures.get(
		source_path, exit_data.arrival_cell
	)

	var context := ExplorationEntryContext.new(
		source_path,
		destination_path,
		departure_cell,
		arrival_cell,
		GameState.get_main_squad()
	)

	# Validate before removing the source.
	if not bool(destination.call("prepare_exploration_entry", context)):
		if not reused:
			destination.free()

		push_warning("Destination rejected exploration entry.")
		return null

	var departures: Dictionary = source.get_meta(
		"exploration_departures", {}
	)
	departures[destination_path] = departure_cell
	source.set_meta("exploration_departures", departures)

	# Retain the source instance, but stop processing and remove all its UI.
	source.set_meta("exploration_process_mode", int(source.process_mode))
	source.process_mode = Node.PROCESS_MODE_DISABLED
	source.get_parent().remove_child(source)
	_exploration_cache[source_path] = source

	_exploration_cache.erase(destination_path)
	_current_game_scene = destination
	_main.get_game_layer().add_child(destination)

	if reused:
		destination.process_mode = int(destination.get_meta(
			"exploration_process_mode", Node.PROCESS_MODE_INHERIT
		))

	if destination.has_method("on_exploration_entered"):
		destination.call("on_exploration_entered", context)

	print(
		"[Exploration] ",
		source_path.get_file(),
		" -> ",
		destination_path.get_file(),
		" | arrival: ",
		arrival_cell,
		" | reused: ",
		reused
	)

	return destination


func present_game_scene(
	scene_path: String,
	context: Variant = null
) -> Node:
	if not is_instance_valid(_main):
		push_error("SceneManager has no registered Main node.")
		return null

	if not is_instance_valid(_current_game_scene):
		push_error("Presentation requires an active game scene.")
		return null

	if is_instance_valid(_active_game_presentation):
		push_warning("SceneManager already has an active presentation.")
		return null

	var packed_scene: PackedScene = load(scene_path) as PackedScene

	if packed_scene == null:
		push_error("Could not load temporary game scene: " + scene_path)
		return null

	_current_game_scene.hide()

	var presentation: Node = packed_scene.instantiate()
	_active_game_presentation = presentation

	# Connect before configure: configure may eventually finish immediately.
	if presentation.has_signal("presentation_finished"):
		presentation.connect(
			"presentation_finished",
			_on_game_presentation_finished.bind(presentation)
		)

	_main.get_game_layer().add_child(presentation)

	if presentation.has_method("configure"):
		presentation.call("configure", context)

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
		push_warning("Dismissal requested by a non-active presentation.")
		return

	if is_instance_valid(_active_game_presentation):
		_active_game_presentation.queue_free()

	_active_game_presentation = null

	if not is_instance_valid(_current_game_scene):
		return

	_current_game_scene.show()

	if _current_game_scene.has_method("on_game_presentation_finished"):
		_current_game_scene.call_deferred(
			"on_game_presentation_finished", context
		)


func _remove_active_game_presentation() -> void:
	if is_instance_valid(_active_game_presentation):
		_active_game_presentation.queue_free()

	_active_game_presentation = null


func push_overlay(scene_path: String) -> Node:
	if not is_instance_valid(_main):
		push_error("SceneManager has no registered Main node.")
		return null

	var packed_scene: PackedScene = load(scene_path) as PackedScene

	if packed_scene == null:
		push_error("Could not load overlay scene: " + scene_path)
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
