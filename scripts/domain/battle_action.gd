class_name BattleAction

extends RefCounted

## A readable result of one resolved battle action.
## BattleSession creates these objects.
## BattleScene presents them without owning combat logic.

enum Type {
	NONE,
	PHYSICAL_DAMAGE,
	SKILL_DAMAGE,
	HEALING
}

var action_type: Type = Type.NONE

var actor: Unit
var target: Unit

var skill: Skill
var applied_amount: int = 0

var message: String = ""


func configure_damage(
	new_actor: Unit,
	new_target: Unit,
	damage_amount: int,
	action_message: String,
	new_skill: Skill = null
) -> void:
	action_type = Type.PHYSICAL_DAMAGE

	if new_skill != null:
		action_type = Type.SKILL_DAMAGE

	actor = new_actor
	target = new_target
	skill = new_skill
	applied_amount = damage_amount
	message = action_message


func configure_healing(
	new_actor: Unit,
	new_target: Unit,
	healing_amount: int,
	action_message: String,
	new_skill: Skill
) -> void:
	action_type = Type.HEALING

	actor = new_actor
	target = new_target
	skill = new_skill
	applied_amount = healing_amount
	message = action_message


func is_valid() -> bool:
	return (
		action_type != Type.NONE
		and actor != null
		and target != null
		and applied_amount > 0
	)
