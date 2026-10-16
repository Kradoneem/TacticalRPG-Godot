extends RefCounted

## Explicit sewer enemy content.
## Factories create fresh gameplay objects only when room state is absent.


static func create_corridor_rat_squad() -> Squad:
	var squad := Squad.new(
		"corridor_sewer_rats",
		"Sewer Rats",
		Squad.AutonomyMode.ENEMY
	)

	squad.default_strategy = &"balanced"

	for index in range(3):
		var rat := Unit.new(
			"corridor_sewer_rat_%d" % (index + 1),
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
