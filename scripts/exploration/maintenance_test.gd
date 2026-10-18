extends "res://scripts/exploration/sewer_entrance_test.gd"

## Maintenance content and temporary-return adapter.
## Calibration/free movement are inherited.
## Exit UI/input use the shared controller.

signal presentation_finished(context: Variant)

const ExitControllerScript = preload(
	"res://scripts/exploration/exploration_exit_controller.gd"
)

const CORRIDOR_SCENE_PATH: String = (
	"res://scenes/exploration/sewer_corridor_test.tscn"
)

@export var return_cells: Array[Vector2i] = [
	Vector2i(0, 1)
]

var _exits: ExitControllerScript
var _can_return: bool = false
var _exit_interaction_active: bool = false
var _returning: bool = false


func _ready() -> void:
	super._ready()

	if (
		tactical_grid == null
		or projection == null
		or player_marker.squad == null
	):
		return

	GameState.current_location = "Sewer Maintenance"
	GameState.in_city = false

	var definitions: Array[ExplorationExitData] = [
		ExplorationExitData.create(
			&"to_corridor",
			"Terug naar de corridor",
			return_cells,
			CORRIDOR_SCENE_PATH
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
		push_error("Maintenance exit configuration failed.")


func configure(_context: Variant = null) -> void:
	# SceneManager calls this after adding the temporary scene.
	_can_return = true


func _can_interact_with_exit() -> bool:
	return (
		not _calibrating
		and not _returning
		and player_marker.squad != null
		and player_marker.squad.is_alive()
	)


func _on_exit_interaction_active_changed(active: bool) -> void:
	_exit_interaction_active = active

	player_marker.set_input_enabled(
		not active and _can_interact_with_exit()
	)


func _input(event: InputEvent) -> void:
	# Do not start calibration underneath an exit menu.
	if not _exit_interaction_active and not _returning:
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey

		if key_event.pressed and key_event.keycode == KEY_F2:
			get_viewport().set_input_as_handled()


func _on_exit_travel_requested(
	exit_data: ExplorationExitData,
	_departure_cell: Vector2i
) -> void:
	if exit_data.exit_id != &"to_corridor":
		_exits.recover_from_transition_error(
			"Onbekende maintenance-uitgang: " + str(exit_data.exit_id)
		)
		return

	if not _can_return:
		_exits.recover_from_transition_error(
			"Gebruik F5 en betreed maintenance vanuit de corridor."
		)
		return

	# This request is already deferred by the shared exitcontroller.
	_returning = true
	_finish_presentation()


func _finish_presentation() -> void:
	_can_return = false

	set_process_input(false)
	set_process_unhandled_input(false)
	player_marker.set_input_enabled(false)
	_exits.set_process_input(false)

	# The retained corridor resumes; do not load a new corridor instance.
	presentation_finished.emit(null)


func _on_movement_requested(direction: Vector2i) -> void:
	if _calibrating or _exit_interaction_active or _returning:
		return

	if player_marker.move_by(direction):
		print(
			"Maintenance Main Squad cell: ",
			player_marker.cell
		)

	get_viewport().set_input_as_handled()


func _begin_calibration() -> void:
	if _exit_interaction_active or _returning:
		return

	super._begin_calibration()


func _save_calibration() -> void:
	if not _candidate_valid:
		return

	var directory: String = "res://assets/calibration"

	var directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directory)
	)

	if directory_error != OK:
		_status.text = (
			"Kalibratiemap aanmaken mislukt: "
			+ error_string(directory_error)
		)
		return

	var stamp: String = (
		Time.get_datetime_string_from_system().replace(":", "-")
	)

	var base_path: String = directory + "/sewer_maintenance_" + stamp
	var path: String = base_path + ".tres"
	var suffix: int = 1

	# Always export to a new filename.
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

	print("Maintenance grid calibration saved: ", path)

	_finish_calibration()

	_hint.text = (
		"Opgeslagen: " + path
		+ "\nNa F8: wijs dit bestand toe aan "
		+ "SewerMaintenanceTest > Grid Calibration "
		+ "en sla de scene op."
	)
