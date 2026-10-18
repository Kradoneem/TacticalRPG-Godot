extends "res://scripts/exploration/exploration_map.gd"

## Junction map content.
## Projection and walkability come from area_data.
## Only the maintenance connection is active in this milestone.

@export var maintenance_exit_cells: Array[Vector2i] = [
	Vector2i(0, 7)
]

## First-visit fallback.
## SceneManager restores the actual departure cell on return visits.
@export var maintenance_arrival_cell: Vector2i = Vector2i(3, 0)

@onready var _background: Sprite2D = $Background
@onready var _map_camera: Camera2D = $MapCamera


func get_location_name() -> String:
	return "Sewer Junction"


func get_calibration_prefix() -> String:
	return "sewer_junction"


func get_exit_definitions() -> Array[ExplorationExitData]:
	return [
		ExplorationExitData.create(
			&"to_maintenance",
			"Terug naar maintenance",
			maintenance_exit_cells,
			"res://scenes/exploration/sewer_maintenance_test.tscn",
			maintenance_arrival_cell
		)
	]


func _ready() -> void:
	if area_data == null:
		push_error(
			"Junction requires an ExplorationAreaData Resource."
		)
		return

	super._ready()

	if (
		tactical_grid == null
		or projection == null
		or player_marker.squad == null
	):
		return

	if _background.texture == null:
		push_error("Junction requires a background texture.")
		return

	var bounds := Rect2(
		_background.position,
		_background.texture.get_size()
	)

	_map_camera.call(
		"configure",
		bounds,
		player_marker,
		_is_authoring
	)

	_hint.text = (
		"JUNCTION | WASD: bewegen"
		+ " | MMB: inspecteren | Home: centreren"
		+ "\nGroen: begaanbaar | rood: blocked | grijs: UNKNOWN"
		+ "\nMaintenance-uitgang: "
		+ str(maintenance_exit_cells)
		+ " | Enter / Spatie: opties"
	)

	queue_redraw()


func _is_authoring() -> bool:
	# Authoring runs in its own scene.
	return false
