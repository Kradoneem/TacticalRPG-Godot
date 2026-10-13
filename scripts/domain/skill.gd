class_name Skill

extends RefCounted

## Immutable definition of one combat skill.
## Units store skill IDs; SkillData provides the definitions.

enum EffectType {
	PHYSICAL_DAMAGE,
	HEAL
}


enum TargetType {
	ENEMY_SINGLE,
	ALLY_SINGLE
}


var skill_id: StringName
var display_name: String
var description: String

var effect_type: int
var target_type: int

var mp_cost: int
var power: float


func _init(
	new_skill_id: StringName,
	new_display_name: String,
	new_description: String,
	new_effect_type: int,
	new_target_type: int,
	new_mp_cost: int,
	new_power: float
) -> void:
	skill_id = new_skill_id
	display_name = new_display_name
	description = new_description

	effect_type = new_effect_type
	target_type = new_target_type

	mp_cost = new_mp_cost
	power = new_power
