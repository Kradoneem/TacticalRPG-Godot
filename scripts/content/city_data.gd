class_name CityData
extends RefCounted

const CITY_NAME: String = "Aldenmoor"
const SEWER_ENTRANCE_SCENE: String = (
	"res://scenes/exploration/sewer_entrance_test.tscn"
)
const SEWER_ARRIVAL_CELL: Vector2i = Vector2i(3, 3)


static func get_destinations() -> Array[CityDestination]:
	var results: Array[CityDestination] = []

	results.append(_make(
		&"adventurers_guild",
		"Adventurer's Guild",
		Vector2(0.30, 0.35),
		CityDestination.Kind.GUILD
	))
	results.append(_make(
		&"shop",
		"Shop",
		Vector2(0.65, 0.40),
		CityDestination.Kind.SHOP
	))
	results.append(_make(
		&"tavern",
		"Tavern",
		Vector2(0.45, 0.60),
		CityDestination.Kind.TAVERN
	))
	results.append(_make(
		&"castle",
		"Castle",
		Vector2(0.80, 0.22),
		CityDestination.Kind.CASTLE
	))
	results.append(_make(
		&"home",
		"Home",
		Vector2(0.20, 0.73),
		CityDestination.Kind.HOME
	))
	results.append(_make(
		&"sewers",
		"Sewers",
		Vector2(0.72, 0.78),
		CityDestination.Kind.SEWERS
	))

	return results


static func get_destination(
	destination_id: StringName
) -> CityDestination:
	for destination: CityDestination in get_destinations():
		if destination.destination_id == destination_id:
			return destination

	return null


static func _make(
	destination_id: StringName,
	display_name: String,
	position_ratio: Vector2,
	kind: CityDestination.Kind
) -> CityDestination:
	var destination := CityDestination.new()
	destination.destination_id = destination_id
	destination.display_name = display_name
	destination.position_ratio = position_ratio
	destination.kind = kind
	return destination
