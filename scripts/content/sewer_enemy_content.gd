extends RefCounted

## Explicit sewer enemy content.
## Factories create fresh gameplay objects only when room state is absent.
## Junction test squads reuse the existing corridor rat stats.


static func create_corridor_rat_squad() -> Squad:
	return _create_rat_squad(
		"corridor_sewer_rats",
		"Sewer Rats",
		"corridor_sewer_rat"
	)


static func create_junction_static_rat_squad() -> Squad:
	return _create_rat_squad(
		"junction_static_rats",
		"Junction Rats — STATIC",
		"junction_static_rat"
	)


static func create_junction_patrol_rat_squad() -> Squad:
	return _create_rat_squad(
		"junction_patrol_rats",
		"Junction Rats — PATROL",
		"junction_patrol_rat"
	)


static func _create_rat_squad(
	assigned_squad_id: String,
	assigned_display_name: String,
	unit_id_prefix: String
) -> Squad:
	var squad := Squad.new(
		assigned_squad_id,
		assigned_display_name,
		Squad.AutonomyMode.ENEMY
	)

	squad.default_strategy = &"balanced"

	for index in range(3):
		var rat := Unit.new(
			"%s_%d" % [unit_id_prefix, index + 1],
			"Sewer Rat %d" % (index + 1),
			1,
			22,
			7,
			2,
			6,
			0,
			0
		)

		squad.add_member(rat)

	return squad
