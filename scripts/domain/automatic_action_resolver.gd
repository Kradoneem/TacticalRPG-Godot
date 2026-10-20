class_name AutomaticActionResolver
extends RefCounted

## Chooses existing automatic support actions.
## AbilityResolver owns shared validation, costs and execution.

const SUPPORT_HEAL_THRESHOLD: float = 0.6


static func try_resolve_support_action(
	acting_unit: Unit,
	owning_squad: Squad,
	active_strategy: StringName
) -> AutomaticActionResult:
	var result := AutomaticActionResult.new()

	if active_strategy != &"support":
		return result

	if (
		acting_unit == null
		or owning_squad == null
		or not acting_unit.is_alive()
		or not owning_squad.contains_member(acting_unit)
	):
		return result

	var heal_target: Unit = owning_squad.get_most_wounded_living_member()

	if heal_target == null or heal_target.max_hp <= 0:
		return result

	var target_health_ratio: float = (
		float(heal_target.hp) / float(heal_target.max_hp)
	)

	if target_health_ratio > SUPPORT_HEAL_THRESHOLD:
		return result

	for ability_id: StringName in acting_unit.get_all_learned_ability_ids():
		var ability: Skill = SkillData.get_skill(ability_id)

		if (
			ability == null
			or ability.effect_type != Skill.EffectType.HEAL
			or ability.target_type != Skill.TargetType.ALLY_SINGLE
		):
			continue

		var action: BattleAction = AbilityResolver.resolve(
			acting_unit,
			heal_target,
			ability,
			owning_squad
		)

		if action == null or not action.is_valid():
			continue

		# Preserve the existing AutomaticActionResult interface.
		# This conversion contains no second cost payment or effect.
		result.set_skill_result(
			action.actor,
			action.target,
			action.skill,
			action.applied_amount
		)
		return result

	return result
