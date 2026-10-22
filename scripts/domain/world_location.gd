class_name WorldLocation
extends Resource

enum Kind { CITY, PROTOTYPE_STUB }

@export var location_id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.CITY
@export var scene_path: String = ""
@export var map_position_ratio: Vector2 = Vector2(0.5, 0.5)
@export var is_prototype: bool = false


func validation_error() -> String:
	if location_id == &"":
		return "Locatie-ID ontbreekt."

	if display_name.strip_edges().is_empty():
		return "Locatienaam ontbreekt: %s" % location_id

	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return "Scene ontbreekt: %s" % scene_path

	if (
		not map_position_ratio.is_finite()
		or map_position_ratio.x < 0.0
		or map_position_ratio.x > 1.0
		or map_position_ratio.y < 0.0
		or map_position_ratio.y > 1.0
	):
		return "Kaartpositie buiten bereik: %s" % location_id

	return ""
