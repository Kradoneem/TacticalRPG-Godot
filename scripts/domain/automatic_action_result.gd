class_name AutomaticActionResult

extends RefCounted

## Describes one resolved automatic action.
## The result contains no UI logic, so any scene can present it differently.

var was_performed: bool = false

var actor: Unit
var target: Unit
var skill: Skill

var applied_amount: int = 0


func set_skill_result(
	new_actor: Unit,
	new_target: Unit,
	new_skill: Skill,
	new_applied_amount: int
) -> void:
	was_performed = true

	actor = new_actor
	target = new_target
	skill = new_skill

	applied_amount = new_applied_amount
