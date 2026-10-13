class_name UnitData

extends RefCounted

## Factories for predefined units and starting parties.
## Each factory creates fresh Unit instances for a new game.

static func create_chapter_one_party() -> Array[Unit]:
	var protagonist := Unit.new(
		"protagonist",
		"Protagonist",
		1,
		40,
		12,
		4,
		8,
		5
	)

	protagonist.learn_skill(&"focused_strike")

	var best_friend := Unit.new(
		"best_friend",
		"Best Friend",
		1,
		28,
		8,
		5,
		7,
		10,
		20
	)

	best_friend.learn_skill(&"mend")

	return [
		protagonist,
		best_friend
	]
