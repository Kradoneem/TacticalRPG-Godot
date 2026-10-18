extends "res://scripts/exploration/exploration_map.gd"

## Junction content only.
## Grid and cells come from area_data.

@onready var _background: Sprite2D = $Background
@onready var _map_camera: Camera2D = $MapCamera


func get_location_name() -> String:
	return "Sewer Junction"


func get_calibration_prefix() -> String:
	return "sewer_junction"


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
		+ "\nKalibratie en celbewerking:"
		+ " losse Area Editor-scene via F6"
	)

	queue_redraw()


func _is_authoring() -> bool:
	# Authoring is a separate scene, never a gameplay state.
	return false
