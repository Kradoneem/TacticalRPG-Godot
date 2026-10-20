class_name AbilityResolver
extends RefCounted

## Shared ability execution for player-selected and automatic actions.
## Knows no UI, protagonist rules, strategy or turn order.

const CombatRules = preload("res://scripts/domain/combat_resolver.gd")


static func get_unavailable_reason(actor: Unit, ability: Skill) -> String:
	## Actor/definition/cost validation without selecting a target.
	if actor == null or not actor.is_alive():
		return "The actor cannot act."

	if ability == null:
		return "Ability definition is missing."

	if not actor.knows_ability(ability.skill_id):
		return "This ability is not known."

	var damage_supported: bool = (
		ability.effect_type in [
			Skill.EffectType.PHYSICAL_DAMAGE,
			Skill.EffectType.MAGIC_DAMAGE
		]
		and ability.target_type == Skill.TargetType.ENEMY_SINGLE
	)

	var healing_supported: bool = (
		ability.effect_type == Skill.EffectType.HEAL
		and ability.target_type == Skill.TargetType.ALLY_SINGLE
	)

	if not damage_supported and not healing_supported:
		return "This ability effect or target type is not implemented yet."

	if ability.scaling_type not in [
		Skill.ScalingType.ATTACK,
		Skill.ScalingType.WISDOM,
		Skill.ScalingType.FLAT
	]:
		return "Unsupported ability scaling."

	# Python ingredients are component types, not ordinary item IDs.
	# Do not silently reinterpret that data as the current inventory.
	if not ability.item_costs.is_empty():
		return "Ingredient costs are not implemented yet."

	if ability.mp_cost < 0 or ability.hp_cost < 0:
		return "Ability costs cannot be negative."

	if actor.mp < ability.mp_cost:
		return "Not enough MP: %d required." % ability.mp_cost

	# Existing Python rule: paying HP cannot defeat the actor.
	if ability.hp_cost > 0 and actor.hp <= ability.hp_cost:
		return "Not enough HP: more than %d required." % ability.hp_cost

	return ""


static func get_target_error(
	actor: Unit,
	target: Unit,
	ability: Skill,
	owning_squad: Squad,
	opposing_squad: Squad = null
) -> String:
	if actor == null or ability == null:
		return "Actor or ability is missing."

	if owning_squad == null or not owning_squad.contains_member(actor):
		return "The actor does not belong to this squad."

	if target == null or not target.is_alive():
		return "The target is no longer available."

	match ability.target_type:
		Skill.TargetType.ENEMY_SINGLE:
			if (
				opposing_squad == null
				or opposing_squad == owning_squad
				or not opposing_squad.contains_member(target)
			):
				return "Choose a member of the opposing squad."

		Skill.TargetType.ALLY_SINGLE:
			if not owning_squad.contains_member(target):
				return "Choose a member of the actor's squad."

			if target.hp >= target.max_hp:
				return "This target needs no healing."

		_:
			return "This target type is not implemented yet."

	return ""


static func resolve(
	actor: Unit,
	target: Unit,
	ability: Skill,
	owning_squad: Squad,
	opposing_squad: Squad = null
) -> BattleAction:
	if not get_unavailable_reason(actor, ability).is_empty():
		return null

	if not get_target_error(
		actor, target, ability, owning_squad, opposing_squad
	).is_empty():
		return null

	var amount: int

	if ability.effect_type == Skill.EffectType.HEAL:
		amount = CombatRules.calculate_skill_healing(actor, ability)
	else:
		amount = CombatRules.calculate_skill_damage(actor, target, ability)

	if amount <= 0:
		return null

	# Synchronous transaction: validate everything before any mutation.
	# No await or external signals between costs and effect.
	actor.mp -= ability.mp_cost
	actor.hp -= ability.hp_cost

	var action := BattleAction.new()

	if ability.effect_type == Skill.EffectType.HEAL:
		var applied_healing: int = target.heal(amount)

		action.configure_healing(
			actor,
			target,
			applied_healing,
			"%s uses %s on %s and restores %d HP." % [
				actor.display_name,
				ability.display_name,
				target.display_name,
				applied_healing
			],
			ability
		)
	else:
		target.take_damage(amount)

		action.configure_damage(
			actor,
			target,
			amount,
			"%s uses %s on %s for %d damage." % [
				actor.display_name,
				ability.display_name,
				target.display_name,
				amount
			],
			ability
		)

	return action
