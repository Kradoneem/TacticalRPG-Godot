class_name EncounterContext
extends RefCounted

## Shared participants and snapshots for one short battle transition.
## Never copies Units or Squads.

enum Initiator {
	PLAYER,
	ENEMY
}

const DEFAULT_MAXIMUM_ROUNDS: int = 2

var player_squad: Squad
var enemy_squad: Squad
var initiator: int
var active_strategy: StringName
var maximum_rounds: int

var result: EncounterResult

## Prevent a context created for an already defeated squad from rewarding it.
var enemy_was_alive_at_start: bool = false

## Reward snapshots made before the battle.
var defeat_xp: int = 0
var defeat_gold: int = 0
var defeat_items: Dictionary = {}


func _init(
	new_player_squad: Squad,
	new_enemy_squad: Squad,
	new_initiator: int,
	new_active_strategy: StringName,
	new_maximum_rounds: int = DEFAULT_MAXIMUM_ROUNDS
) -> void:
	player_squad = new_player_squad
	enemy_squad = new_enemy_squad
	initiator = new_initiator
	active_strategy = new_active_strategy
	maximum_rounds = maxi(1, new_maximum_rounds)

	result = EncounterResult.new()

	if enemy_squad == null:
		return

	result.enemy_squad_id = enemy_squad.squad_id
	result.enemy_squad_name = enemy_squad.display_name

	enemy_was_alive_at_start = enemy_squad.is_alive()
	defeat_gold = enemy_squad.defeat_gold
	defeat_items = enemy_squad.defeat_items.duplicate()

	# Migrated from Python BattleResultsScene.
	# Include the entire squad roster, including members defeated
	# during earlier short clashes with this same squad.
	for unit: Unit in enemy_squad.members:
		if unit == null:
			continue

		defeat_xp += (
			unit.max_hp
			+ unit.attack
			+ unit.defense
			+ unit.speed
			+ unit.wisdom
		)


func was_player_initiated() -> bool:
	return initiator == Initiator.PLAYER
