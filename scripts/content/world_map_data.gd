class_name WorldMapData
extends RefCounted

const WORLD_MAP_SCENE: String = (
	"res://scenes/world/world_map_screen.tscn"
)
const CITY_SCENE: String = "res://scenes/city/city_screen.tscn"
const STUB_SCENE: String = (
	"res://scenes/world/location_stub_screen.tscn"
)

const ALDENMOOR_ID: StringName = &"aldenmoor"
const PROTOTYPE_A_ID: StringName = &"prototype_a"
const PROTOTYPE_B_ID: StringName = &"prototype_b"

## Prototype: one flat cost per connection, via GameState.advance_day().
const TRAVEL_DAYS: float = 1.0


static func get_locations() -> Array[WorldLocation]:
	var results: Array[WorldLocation] = []

	results.append(_make(
		ALDENMOOR_ID,
		CityData.CITY_NAME,
		WorldLocation.Kind.CITY,
		CITY_SCENE,
		Vector2(0.50, 0.50),
		false
	))
	results.append(_make(
		PROTOTYPE_A_ID,
		"Prototype Location A",
		WorldLocation.Kind.PROTOTYPE_STUB,
		STUB_SCENE,
		Vector2(0.22, 0.28),
		true
	))
	results.append(_make(
		PROTOTYPE_B_ID,
		"Prototype Location B",
		WorldLocation.Kind.PROTOTYPE_STUB,
		STUB_SCENE,
		Vector2(0.78, 0.68),
		true
	))

	return results


static func get_location(location_id: StringName) -> WorldLocation:
	for location: WorldLocation in get_locations():
		if location.location_id == location_id:
			return location

	return null


## Hub topology: Aldenmoor <-> A and Aldenmoor <-> B. No A <-> B.
static func are_connected(a: StringName, b: StringName) -> bool:
	if a == b:
		return false

	return (
		(a == ALDENMOOR_ID and (b == PROTOTYPE_A_ID or b == PROTOTYPE_B_ID))
		or (b == ALDENMOOR_ID and (a == PROTOTYPE_A_ID or a == PROTOTYPE_B_ID))
	)


static func _make(
	location_id: StringName,
	display_name: String,
	kind: WorldLocation.Kind,
	scene_path: String,
	map_position_ratio: Vector2,
	is_prototype: bool
) -> WorldLocation:
	var location := WorldLocation.new()
	location.location_id = location_id
	location.display_name = display_name
	location.kind = kind
	location.scene_path = scene_path
	location.map_position_ratio = map_position_ratio
	location.is_prototype = is_prototype
	return location
