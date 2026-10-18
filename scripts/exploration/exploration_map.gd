extends "res://scripts/exploration/projected_exploration_map.gd"

## Shared exploration composition; no authoring responsibility.

const MapRuntimeScript = preload("res://scripts/systems/tactical_map_runtime.gd")
const ExitControllerScript = preload("res://scripts/exploration/exploration_exit_controller.gd")

var _runtime: MapRuntimeScript
var _exits: ExitControllerScript
var _runtime_status: Label
var _exit_interaction_active: bool = false
var _combat_presentation_active: bool = false


func get_location_name() -> String:
	return "Exploration"


func get_calibration_prefix() -> String:
	# Existing runtime uses this stable map identifier.
	return "exploration"


func get_exit_definitions() -> Array[ExplorationExitData]:
	return []


func get_enemy_spawns() -> Array[TacticalEnemySpawn]:
	return []


func _ready() -> void:
	super._ready()
	if tactical_grid == null or projection == null or player_marker.squad == null:
		return
	GameState.current_location = get_location_name()
	GameState.in_city = false
	_build_runtime_status()
	if player_marker.movement_requested.is_connected(_on_movement_requested):
		player_marker.movement_requested.disconnect(_on_movement_requested)
	var runtime := MapRuntimeScript.new()
	add_child(runtime)
	if not runtime.configure(
		self, player_marker, tactical_grid, projection,
		get_calibration_prefix(), get_enemy_spawns()
	):
		runtime.queue_free()
		player_marker.set_input_enabled(false)
		_runtime_status.text = "Map configureren mislukt. Controleer Output."
		return
	_runtime = runtime
	_runtime.status_changed.connect(_update_runtime_status)
	_runtime.presentation_active_changed.connect(_on_combat_presentation_active_changed)
	_exits = ExitControllerScript.new()
	add_child(_exits)
	_exits.interaction_active_changed.connect(_on_exit_interaction_active_changed)
	_exits.travel_requested.connect(_on_exit_travel_requested)
	if not _exits.configure(player_marker, get_exit_definitions(), _can_interact_with_exit):
		_exits.queue_free()
		_exits = null
		push_error("Exploration exit configuration failed.")
	_update_runtime_status()


func _on_movement_requested(_direction: Vector2i) -> void:
	# Runtime turncontroller owns movement, not this composition node.
	pass


func _build_runtime_status() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 11
	add_child(layer)
	_runtime_status = Label.new()
	_runtime_status.position = Vector2(24.0, 930.0)
	_runtime_status.add_theme_font_size_override("font_size", 24)
	_runtime_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_runtime_status)


func _can_interact_with_exit() -> bool:
	return _runtime != null and not _combat_presentation_active and _runtime.can_open_door()


func _on_exit_interaction_active_changed(active: bool) -> void:
	_exit_interaction_active = active
	_apply_runtime_suspension()


func _apply_runtime_suspension() -> void:
	if _runtime != null:
		_runtime.set_suspended(_exit_interaction_active or _combat_presentation_active)


func _on_exit_travel_requested(exit_data: ExplorationExitData, departure_cell: Vector2i) -> void:
	_runtime.save_room_state()
	var destination: Node = SceneManager.travel_exploration(self, exit_data, departure_cell)
	if destination == null:
		_exits.recover_from_transition_error("Kamerwissel mislukt. Controleer Output.")


func on_exploration_entered(_context: ExplorationEntryContext) -> void:
	GameState.current_location = get_location_name()
	GameState.in_city = false
	if _exits != null:
		_exits.complete_transition()
	_apply_runtime_suspension()
	_update_runtime_status()


func _on_combat_presentation_active_changed(active: bool) -> void:
	_combat_presentation_active = active
	set_process_unhandled_input(not active)
	_apply_runtime_suspension()


func on_game_presentation_finished(context: Variant) -> void:
	GameState.current_location = get_location_name()
	GameState.in_city = false
	if not _combat_presentation_active or _runtime == null:
		push_warning("Exploration map received an unexpected presentation result.")
		return
	_on_combat_presentation_active_changed(false)
	_runtime.finish_battle(context)


func _update_runtime_status() -> void:
	if _runtime_status != null and _runtime != null:
		_runtime_status.text = _runtime.get_status_text()


func _process(_delta: float) -> void:
	if _runtime_status != null:
		_runtime_status.visible = not _exit_interaction_active and not _combat_presentation_active
