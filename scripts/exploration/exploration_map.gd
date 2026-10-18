extends "res://scripts/exploration/sewer_entrance_test.gd"

## Shared projected exploration map composition.
## Content subclasses provide location, exits and enemy spawn definitions.

const MapRuntimeScript = preload(
	"res://scripts/systems/tactical_map_runtime.gd"
)
const ExitControllerScript = preload(
	"res://scripts/exploration/exploration_exit_controller.gd"
)

var _runtime: MapRuntimeScript
var _exits: ExitControllerScript
var _runtime_status: Label

var _exit_interaction_active: bool = false
var _combat_presentation_active: bool = false


func get_location_name() -> String:
	return "Exploration"


func get_calibration_prefix() -> String:
	return "exploration"


func get_exit_definitions() -> Array[ExplorationExitData]:
	return []


func get_enemy_spawns() -> Array[TacticalEnemySpawn]:
	return []


func _ready() -> void:
	super._ready()

	if (
		tactical_grid == null
		or projection == null
		or player_marker.squad == null
	):
		return

	GameState.current_location = get_location_name()
	GameState.in_city = false

	_build_runtime_status()

	if player_marker.movement_requested.is_connected(_on_movement_requested):
		player_marker.movement_requested.disconnect(_on_movement_requested)

	var runtime := MapRuntimeScript.new()
	add_child(runtime)

	if not runtime.configure(
		self,
		player_marker,
		tactical_grid,
		projection,
		get_calibration_prefix(),
		get_enemy_spawns()
	):
		runtime.queue_free()
		player_marker.set_input_enabled(false)
		_runtime_status.text = "Map configureren mislukt. Controleer Output."
		return

	_runtime = runtime
	_runtime.status_changed.connect(_update_runtime_status)
	_runtime.presentation_active_changed.connect(
		_on_combat_presentation_active_changed
	)

	_exits = ExitControllerScript.new()
	add_child(_exits)

	_exits.interaction_active_changed.connect(
		_on_exit_interaction_active_changed
	)
	_exits.travel_requested.connect(_on_exit_travel_requested)

	if not _exits.configure(
		player_marker,
		get_exit_definitions(),
		_can_interact_with_exit
	):
		_exits.queue_free()
		_exits = null
		push_error("Exploration exit configuration failed.")

	_update_runtime_status()


func _on_movement_requested(_direction: Vector2i) -> void:
	# Movement ownership belongs exclusively to the tactical turncontroller.
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
	return (
		_runtime != null
		and not _calibrating
		and not _combat_presentation_active
		and _runtime.can_open_door()
	)


func _on_exit_interaction_active_changed(active: bool) -> void:
	_exit_interaction_active = active
	_apply_runtime_suspension()


func _apply_runtime_suspension() -> void:
	if _runtime != null:
		_runtime.set_suspended(
			_calibrating
			or _exit_interaction_active
			or _combat_presentation_active
		)


func _on_exit_travel_requested(
	exit_data: ExplorationExitData,
	departure_cell: Vector2i
) -> void:
	_runtime.save_room_state()

	var destination: Node = SceneManager.travel_exploration(
		self, exit_data, departure_cell
	)

	if destination == null:
		_exits.recover_from_transition_error(
			"Kamerwissel mislukt. Controleer Output."
		)


func on_exploration_entered(
	_context: ExplorationEntryContext
) -> void:
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


func _process(delta: float) -> void:
	super._process(delta)

	if _runtime_status != null:
		_runtime_status.visible = (
			not _calibrating
			and not _exit_interaction_active
			and not _combat_presentation_active
		)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey

	if not key_event.pressed or key_event.keycode != KEY_F2:
		return

	if (
		_runtime == null
		or _exit_interaction_active
		or _combat_presentation_active
		or not _runtime.can_calibrate()
	):
		get_viewport().set_input_as_handled()


func _begin_calibration() -> void:
	if (
		_runtime == null
		or _exit_interaction_active
		or _combat_presentation_active
		or not _runtime.can_calibrate()
	):
		return

	super._begin_calibration()
	_apply_runtime_suspension()


func _finish_calibration() -> void:
	super._finish_calibration()
	_apply_runtime_suspension()


func _refresh_projection_visuals() -> void:
	super._refresh_projection_visuals()

	if _runtime != null:
		_runtime.refresh_projection(projection)


func _save_calibration() -> void:
	if not _candidate_valid:
		return

	var directory: String = "res://assets/calibration"
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directory)
	)

	if directory_error != OK:
		_status.text = "Kalibratiemap aanmaken mislukt: " + error_string(directory_error)
		return

	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var base_path: String = (
		directory + "/" + get_calibration_prefix() + "_" + stamp
	)
	var path: String = base_path + ".tres"
	var suffix: int = 1

	while FileAccess.file_exists(path):
		path = base_path + "_" + str(suffix) + ".tres"
		suffix += 1

	var saved := GridProjectionData.new()
	saved.origin = projection.origin
	saved.axis_x = projection.axis_x
	saved.axis_y = projection.axis_y

	var save_error: Error = ResourceSaver.save(saved, path)

	if save_error != OK:
		_status.text = "Opslaan mislukt: " + error_string(save_error)
		return

	_finish_calibration()
	print("Grid calibration saved: ", path)

	_hint.text = (
		"Opgeslagen: " + path
		+ "\nNa F8: wijs dit bestand toe aan Grid Calibration "
		+ "en sla de scene op."
	)
