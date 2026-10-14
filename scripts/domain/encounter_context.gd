class_name EncounterContext

extends RefCounted

## Stores information that applies only to one battle transition.
## A temporary player-selected strategy never overwrites a squad's
## persistent default strategy.
##
## maximum_rounds is a transition snapshot. Tactical rules decide its value
## before the battle presentation starts; BattleSession only executes it.

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


func was_player_initiated() -> bool:
	return initiator == Initiator.PLAYER
