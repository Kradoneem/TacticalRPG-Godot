class_name EncounterContext

extends RefCounted

## Stores information that applies only to one battle transition.
## A temporary player-selected strategy never overwrites a squad's
## persistent default strategy.

enum Initiator {
	PLAYER,
	ENEMY
}


var player_squad: Squad
var enemy_squad: Squad
var initiator: int
var active_strategy: StringName


func _init(
	new_player_squad: Squad,
	new_enemy_squad: Squad,
	new_initiator: int,
	new_active_strategy: StringName
) -> void:
	player_squad = new_player_squad
	enemy_squad = new_enemy_squad
	initiator = new_initiator
	active_strategy = new_active_strategy


func was_player_initiated() -> bool:
	return initiator == Initiator.PLAYER
