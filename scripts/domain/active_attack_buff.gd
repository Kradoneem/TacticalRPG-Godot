class_name ActiveAttackBuff
extends RefCounted

## Snapshot of one application, retaining the session clock.
## No copied Units, no UI and no real-time Timer.

var buff_id: StringName
var display_name: String
var attack_bonus: int
var expires_at_tick: int

var _clock: GameplayClock


func _init(
	definition: AttackBuffData,
	caster_wisdom: int,
	clock: GameplayClock
) -> void:
	buff_id = definition.buff_id
	display_name = definition.display_name
	attack_bonus = definition.attack_bonus
	_clock = clock

	expires_at_tick = (
		clock.current_tick + definition.get_duration(caster_wisdom)
	)


func is_active() -> bool:
	return _clock != null and _clock.current_tick < expires_at_tick


func get_remaining_ticks() -> int:
	if _clock == null:
		return 0

	return maxi(0, expires_at_tick - _clock.current_tick)
