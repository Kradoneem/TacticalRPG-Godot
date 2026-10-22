class_name CityDestination
extends Resource

enum Kind {
	GUILD,
	SHOP,
	TAVERN,
	CASTLE,
	HOME,
	SEWERS,
	WORLD_MAP
}

@export var destination_id: StringName = &""
@export var display_name: String = ""
@export var position_ratio: Vector2 = Vector2.ZERO
@export var kind: Kind = Kind.GUILD


func is_valid_definition() -> bool:
	return (
		destination_id != &""
		and not display_name.strip_edges().is_empty()
		and position_ratio.is_finite()
		and position_ratio.x >= 0.0
		and position_ratio.x <= 1.0
		and position_ratio.y >= 0.0
		and position_ratio.y <= 1.0
	)
