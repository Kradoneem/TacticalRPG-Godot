class_name EncounterResult
extends RefCounted

## Outcome of one short encounter.
## Reward application and screen visibility are separate decisions.

var enemy_squad_id: String = ""
var enemy_squad_name: String = ""
var enemy_squad_defeated: bool = false

## True only when this encounter claimed this squad's defeat rewards.
var defeat_rewards_claimed: bool = false

var gold_gained: int = 0
var items_gained: Dictionary = {}

## Display snapshots, not replacement gameplay Units.
var unit_results: Array[Dictionary] = []

## Future content adds messages after processing its own gameplay changes.
var special_messages: Array[String] = []

## Settlement is synchronous and may happen only once per context.
var settled: bool = false


func add_special_message(message: String) -> void:
	var clean_message: String = message.strip_edges()

	if not clean_message.is_empty():
		special_messages.append(clean_message)


func should_show() -> bool:
	return (
		defeat_rewards_claimed
		or not special_messages.is_empty()
	)
