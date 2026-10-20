class_name AttackBuffData
extends Resource

## Content definition. No applied state.

@export var buff_id: StringName = &"attack_support"
@export var display_name: String = "Attack Support"
@export var attack_bonus: int = 3

@export var base_duration: int = 5
@export var reference_wisdom: int = 10
@export var wisdom_per_tick: int = 5


func is_valid_definition() -> bool:
	return (
		buff_id != &""
		and not display_name.strip_edges().is_empty()
		and attack_bonus > 0
		and base_duration > 0
		and wisdom_per_tick > 0
	)


func get_duration(caster_wisdom: int) -> int:
	# Full increments/decrements, rounded toward zero.
	var adjustment: int = int(
		float(caster_wisdom - reference_wisdom)
		/ float(wisdom_per_tick)
	)
	return maxi(1, base_duration + adjustment)
