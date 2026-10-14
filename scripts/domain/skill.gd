class_name Skill

extends RefCounted

## Immutable definition of one skill or spell.
## Units store only stable skill IDs in learned_skills and learned_spells.
## SkillData owns these definitions.

enum Category {
	SKILL,
	SPELL
}


enum EffectType {
	PHYSICAL_DAMAGE,
	HEAL,
	MAGIC_DAMAGE,
	DRAIN,
	BUFF,
	DEBUFF
}


enum TargetType {
	ENEMY_SINGLE,
	ALLY_SINGLE,
	ENEMY_ALL,
	ALLY_ALL,
	SELF
}


enum ScalingType {
	ATTACK,
	WISDOM,
	FLAT
}


var skill_id: StringName
var display_name: String
var description: String

var category: Category
var effect_type: EffectType
var target_type: TargetType
var scaling_type: ScalingType

var elements: Array[StringName] = []

var mp_cost: int
var hp_cost: int
var item_costs: Dictionary = {}

## Base value for flat, wisdom and attack scaling.
var base_value: int

## Temporary compatibility with the current prototype combat formulas.
## This will disappear when CombatResolver is migrated to ScalingType.
var power: float


func _init(
	new_skill_id: StringName,
	new_display_name: String,
	new_description: String,
	new_category: Category,
	new_effect_type: EffectType,
	new_target_type: TargetType,
	new_mp_cost: int,
	new_base_value: int,
	new_scaling_type: ScalingType = ScalingType.FLAT,
	new_elements: Array[StringName] = [],
	new_hp_cost: int = 0,
	new_item_costs: Dictionary = {},
	new_power: float = 1.0
) -> void:
	skill_id = new_skill_id
	display_name = new_display_name
	description = new_description

	category = new_category
	effect_type = new_effect_type
	target_type = new_target_type
	scaling_type = new_scaling_type

	elements = new_elements.duplicate()
	mp_cost = maxi(0, new_mp_cost)
	hp_cost = maxi(0, new_hp_cost)
	item_costs = new_item_costs.duplicate()

	base_value = new_base_value
	power = new_power


func is_spell() -> bool:
	return category == Category.SPELL


func is_skill() -> bool:
	return category == Category.SKILL


func uses_single_target() -> bool:
	return (
		target_type == TargetType.ENEMY_SINGLE
		or target_type == TargetType.ALLY_SINGLE
	)


func uses_all_targets() -> bool:
	return (
		target_type == TargetType.ENEMY_ALL
		or target_type == TargetType.ALLY_ALL
	)
