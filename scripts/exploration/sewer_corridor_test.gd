extends "res://scripts/exploration/sewer_entrance_test.gd"

## Corridor calibration and the existing entrance-return contract.
## Exit UI and tactical composition belong to corridor_room_links.gd.

const ENTRANCE_SCENE_PATH: String = (
	"res://scenes/exploration/sewer_entrance_test.tscn"
)

@export var entrance_cells: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(0, 1),
	Vector2i(0, 2)
]

var _entrance_return_cell: Vector2i
var _has_return_context: bool = false
var _incoming_squad: Squad


func _ready() -> void:
	super._ready()

	if tactical_grid == null or projection == null:
		return

	if player_marker.squad == null:
		return

	GameState.current_location = "Sewer Corridor"
	GameState.in_city = false

	print("Corridor arrival cell: ", player_marker.cell)


func configure_return(departure_cell: Vector2i) -> void:
	# Compatibility with the currently implemented entrance transition.
	# This cell belongs to the entrance, not to the corridor.
	_entrance_return_cell = departure_cell
	_incoming_squad = GameState.get_main_squad()
	_has_return_context = true

	if player_marker.squad != _incoming_squad:
		push_error("Corridor did not receive the existing Main Squad.")


func _return_to_entrance() -> void:
	if (
		not _has_return_context
		or SceneManager.get_current_game_scene() != self
	):
		_recover_from_return_error(
			"Start met F5 en betreed de corridor vanuit de entrance."
		)
		return

	var next_entrance: Node = SceneManager.change_game_scene(
		ENTRANCE_SCENE_PATH
	)

	if next_entrance == null:
		_recover_from_return_error(
			"Entrance laden mislukt. Controleer Output."
		)
		return

	var marker: TacticalPlayer = (
		next_entrance.get_node("PlayerMarker") as TacticalPlayer
	)

	if marker.squad != _incoming_squad:
		push_error("Corridor return unexpectedly replaced the Main Squad.")

	if not marker.move_to(_entrance_return_cell):
		push_error(
			"Could not return to entrance cell: %s"
			% str(_entrance_return_cell)
		)

	print(
		"Returned to entrance cell ",
		marker.cell,
		" with the same Main Squad: ",
		marker.squad == _incoming_squad
	)


func _recover_from_return_error(message: String) -> void:
	# The tactical map adapter overrides this to release its own locks.
	player_marker.set_input_enabled(not _calibrating)
	push_warning(message)


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

	var base_path: String = directory + "/sewer_corridor_" + stamp
	var path: String = base_path + ".tres"
	var suffix: int = 1

	# Never overwrite a previous calibration.
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

	print("Corridor grid calibration saved: ", path)

	_finish_calibration()

	_hint.text = (
		"Opgeslagen: " + path
		+ "\nNa F8: wijs dit bestand toe aan "
		+ "SewerCorridorTest > Grid Calibration en sla de scene op."
	)
