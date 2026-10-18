extends "res://scripts/exploration/sewer_corridor_test.gd"

## Corridor content and composition.
## TacticalMapRuntime owns turns/encounters.
## ExplorationExitController owns exit input and menu UI.

const MapRuntimeScript = preload(
	"res://scripts/systems/tactical_map_runtime.gd"
)
const ExitControllerScript = preload(
	"res://scripts/exploration/exploration_exit_controller.gd"
)
const SewerEnemyContent = preload(
	"res://scripts/content/sewer_enemy_content.gd"
)

const MAINTENANCE_SCENE_PATH: String = (
	"res://scenes/exploration/sewer_maintenance_test.tscn"
)

@export var maintenance_cells: Array[Vector2i] = [
	Vector2i(11, 0)
]

@export var rat_start_cell: Vector2i = Vector2i(11, 3)

var _runtime: MapRuntimeScript
var _exits: ExitControllerScript
var _runtime_status: Label

var _exit_interaction_active: bool = false
var _maintenance_active: bool = false
var _combat_presentation_active: bool = false


func _ready() -> void:
	super._ready()

	if (
		tactical_grid == null
		or projection == null
		or player_marker.squad == null
	):
		return

	_build_runtime_status()

	# The inherited calibration map connects direct movement.
	# Disconnect it before giving movement ownership to the turncontroller.
	if player_marker.movement_requested.is_connected(
		_on_movement_requested
	):
		player_marker.movement_requested.disconnect(
			_on_movement_requested
		)

	var runtime := MapRuntimeScript.new()
	add_child(runtime)

	var spawns: Array[TacticalEnemySpawn] = [
		TacticalEnemySpawn.new(
			&"corridor_sewer_rats",
			rat_start_cell,
			SewerEnemyContent.create_corridor_rat_squad
		)
	]

	if not runtime.configure(
		self,
		player_marker,
		tactical_grid,
		projection,
		"sewer_corridor",
		spawns
	):
		runtime.queue_free()
		player_marker.set_input_enabled(false)
		_runtime_status.text = (
			"Tactical map configureren mislukt. Controleer Output."
		)
		return

	_runtime = runtime
	_runtime.status_changed.connect(_update_runtime_status)
	_runtime.presentation_active_changed.connect(
		set_combat_presentation_active
	)

	_configure_exits()
	_update_runtime_status()


func _on_movement_requested(_direction: Vector2i) -> void:
	# The shared turncontroller is the exclusive movement owner.
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


func _configure_exits() -> void:
	var definitions: Array[ExplorationExitData] = [
		ExplorationExitData.create(
			&"to_entrance",
			"Terug naar de entrance",
			entrance_cells,
			ENTRANCE_SCENE_PATH
		),
		ExplorationExitData.create(
			&"to_maintenance",
			"Naar de maintenance room",
			maintenance_cells,
			MAINTENANCE_SCENE_PATH
		)
	]

	_exits = ExitControllerScript.new()
	add_child(_exits)

	_exits.interaction_active_changed.connect(
		_on_exit_interaction_active_changed
	)
	_exits.travel_requested.connect(_on_exit_travel_requested)

	if not _exits.configure(
		player_marker,
		definitions,
		_can_interact_with_exit
	):
		_exits.queue_free()
		_exits = null
		push_error("Corridor exit configuration failed.")


func _can_interact_with_exit() -> bool:
	if (
		_runtime == null
		or _calibrating
		or _maintenance_active
		or _combat_presentation_active
	):
		return false

	return _runtime.can_open_door()


func _on_exit_interaction_active_changed(active: bool) -> void:
	_exit_interaction_active = active
	_apply_runtime_suspension()
	_update_runtime_status()


func _apply_runtime_suspension() -> void:
	if _runtime == null:
		return

	_runtime.set_suspended(
		_calibrating
		or _exit_interaction_active
		or _maintenance_active
		or _combat_presentation_active
	)


func _update_runtime_status() -> void:
	if _runtime_status == null or _runtime == null:
		return

	_runtime_status.text = _runtime.get_status_text()


func _process(delta: float) -> void:
	super._process(delta)

	if _runtime_status != null and _runtime != null:
		_runtime_status.visible = (
			not _calibrating
			and not _exit_interaction_active
			and not _maintenance_active
			and not _combat_presentation_active
		)


func _input(event: InputEvent) -> void:
	# ExitController handles Enter/Space and the menu.
	# This adapter only protects the inherited calibration flow.
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey

	if not key_event.pressed or key_event.keycode != KEY_F2:
		return

	if (
		_runtime == null
		or _exit_interaction_active
		or _maintenance_active
		or _combat_presentation_active
	):
		get_viewport().set_input_as_handled()
		return

	if not _runtime.can_calibrate():
		get_viewport().set_input_as_handled()


func _on_exit_travel_requested(
	exit_data: ExplorationExitData,
	_departure_cell: Vector2i
) -> void:
	_runtime.save_room_state()

	match exit_data.exit_id:
		&"to_entrance":
			_return_to_entrance()

		&"to_maintenance":
			_present_maintenance()

		_:
			_recover_from_return_error(
				"Onbekende corridor-uitgang: " + str(exit_data.exit_id)
			)


func _present_maintenance() -> void:
	if SceneManager.get_current_game_scene() != self:
		_recover_from_return_error(
			"Gebruik F5 en betreed de corridor vanuit de entrance."
		)
		return

	_maintenance_active = true
	_apply_runtime_suspension()
	set_process_unhandled_input(false)

	var maintenance: Node = SceneManager.present_game_scene(
		MAINTENANCE_SCENE_PATH
	)

	if maintenance == null:
		_maintenance_active = false
		set_process_unhandled_input(true)

		_recover_from_return_error(
			"Maintenance laden mislukt. Controleer Output."
		)


func _recover_from_return_error(message: String) -> void:
	if _exits != null:
		_exits.recover_from_transition_error(message)
	else:
		_exit_interaction_active = false
		_apply_runtime_suspension()
		push_warning(message)

	_update_runtime_status()


func set_combat_presentation_active(active: bool) -> void:
	_combat_presentation_active = active
	set_process_unhandled_input(not active)
	_apply_runtime_suspension()


func on_game_presentation_finished(context: Variant) -> void:
	GameState.current_location = "Sewer Corridor"
	GameState.in_city = false

	if _combat_presentation_active:
		set_combat_presentation_active(false)
		_runtime.finish_battle(context)
		return

	if not _maintenance_active:
		push_warning(
			"Corridor received an unexpected presentation result."
		)
		return

	_maintenance_active = false
	set_process_unhandled_input(true)

	# Clearing the controller's pending request emits the release signal.
	# That signal releases only the exit lock, without starting a new turn.
	if _exits != null:
		_exits.complete_transition()
	else:
		_exit_interaction_active = false
		_apply_runtime_suspension()

	_update_runtime_status()

	print(
		"Returned from maintenance to the same corridor cell: ",
		player_marker.cell
	)


func _begin_calibration() -> void:
	if (
		_runtime == null
		or _exit_interaction_active
		or _maintenance_active
		or _combat_presentation_active
	):
		return

	if not _runtime.can_calibrate():
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
