class_name AbilityResolver
extends RefCounted

## Shared execution for manual and automatic abilities.
## Turn ownership and AI choice remain outside this resolver.

const CombatRules = preload("res://scripts/domain/combat_resolver.gd")


static func get_unavailable_reason(actor: Unit, ability: Skill) -> String:
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

	var buff_supported: bool = (
		ability.effect_type == Skill.EffectType.BUFF
		and ability.target_type == Skill.TargetType.ALLY_SINGLE
		and ability.attack_buff != null
		and ability.attack_buff.is_valid_definition()
	)

	if not damage_supported and not healing_supported and not buff_supported:
		return "This ability effect or target type is not implemented yet."

	if ability.scaling_type not in [
		Skill.ScalingType.ATTACK,
		Skill.ScalingType.WISDOM,
		Skill.ScalingType.FLAT
	]:
		return "Unsupported ability scaling."

	if not ability.item_costs.is_empty():
		return "Ingredient costs are not implemented yet."

	if ability.mp_cost < 0 or ability.hp_cost < 0:
		return "Ability costs cannot be negative."

	if actor.mp < ability.mp_cost:
		return "Not enough MP: %d required." % ability.mp_cost

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

			# Full HP blocks healing, not buffs.
			if (
				ability.effect_type == Skill.EffectType.HEAL
				and target.hp >= target.max_hp
			):
				return "This target needs no healing."

		_:
			return "This target type is not implemented yet."

	return ""


static func resolve(
	actor: Unit,
	target: Unit,
	ability: Skill,
	owning_squad: Squad,
	opposing_squad: Squad = null,
	clock: GameplayClock = null
) -> BattleAction:
	if not get_unavailable_reason(actor, ability).is_empty():
		return null

	if not get_target_error(
		actor, target, ability, owning_squad, opposing_squad
	).is_empty():
		return null

	if ability.effect_type == Skill.EffectType.BUFF:
		if clock == null:
			return null

		# Duration snapshots caster Wisdom before applying the effect.
		var duration: int = ability.attack_buff.get_duration(actor.wisdom)

		if not target.apply_attack_buff(
			ability.attack_buff, actor.wisdom, clock
		):
			return null

		actor.mp -= ability.mp_cost
		actor.hp -= ability.hp_cost

		var buff_action := BattleAction.new()
		buff_action.configure_buff(
			actor,
			target,
			ability.attack_buff.attack_bonus,
			"%s uses %s on %s: ATK +%d for %d ticks." % [
				actor.display_name,
				ability.display_name,
				target.display_name,
				ability.attack_buff.attack_bonus,
				duration
			],
			ability
		)
		return buff_action

	var amount: int = (
		CombatRules.calculate_skill_healing(actor, ability)
		if ability.effect_type == Skill.EffectType.HEAL
		else CombatRules.calculate_skill_damage(actor, target, ability)
	)

	if amount <= 0:
		return null

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
