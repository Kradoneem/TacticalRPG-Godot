extends "res://scripts/exploration/exploration_map.gd"

## Junction camera/calibration milestone.
## The current rectangular grid is a calibration placeholder,
## not a validated walkable floor layout.

@onready var _background: Sprite2D = $Background
@onready var _map_camera: Camera2D = $MapCamera


func get_location_name() -> String:
	return "Sewer Junction"


func get_calibration_prefix() -> String:
	return "sewer_junction"


func _ready() -> void:
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

	var texture_size: Vector2 = _background.texture.get_size()

	# Background remains at scale 1 with centered=false.
	var bounds := Rect2(_background.position, texture_size)

	_map_camera.call(
		"configure",
		bounds,
		player_marker,
		_is_junction_calibrating
	)

	_set_camera_hint()

	print(
		"[Junction] Background: ",
		texture_size,
		" | camera zoom: ",
		_map_camera.zoom,
		" | grid not yet validated"
	)


func _is_junction_calibrating() -> bool:
	return _calibrating


func _set_camera_hint() -> void:
	if _hint == null:
		return

	_hint.text = (
		"JUNCTION TEST | middelste muisknop: kaart slepen"
		+ " | Home: squad volgen | End: kaart centreren"
		+ "\nF2: grid kalibreren | WASD: testbeweging"
		+ "\nLet op: vloer/collision en startcel zijn nog niet gevalideerd."
	)


func _begin_calibration() -> void:
	super._begin_calibration()

	if _calibrating:
		_hint.text = (
			"KALIBRATIE | middelste muisknop: kaart slepen"
			+ "\nLinkermuisknop: O, X en Y kiezen/slepen"
			+ "\nKies punten op dezelfde vlakke vloer. Escape: annuleren."
		)


func _finish_calibration() -> void:
	super._finish_calibration()
	_set_camera_hint()
