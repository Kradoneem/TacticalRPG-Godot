class_name AutomaticActionResolver

extends RefCounted

const CombatResolverData = preload(
	"res://scripts/domain/combat_resolver.gd"
)

## Support units only spend their turn healing when an ally has
## reached this percentage of maximum HP or lower.
const SUPPORT_HEAL_THRESHOLD: float = 0.6


static func try_resolve_support_action(
	acting_unit: Unit,
	owning_squad: Squad,
	active_strategy: StringName
) -> AutomaticActionResult:
	var result := AutomaticActionResult.new()

	if active_strategy != &"support":
		return result

	if acting_unit == null or owning_squad == null:
		return result

	if not acting_unit.is_alive():
		return result

	var heal_target: Unit = owning_squad.get_most_wounded_living_member()

	if heal_target == null:
		return result

	var target_health_ratio: float = (
		float(heal_target.hp)
		/ float(heal_target.max_hp)
	)

	if target_health_ratio > SUPPORT_HEAL_THRESHOLD:
		return result

	for skill_id: StringName in acting_unit.learned_skills:
		var skill: Skill = SkillData.get_skill(skill_id)

		if skill == null:
			continue

		if skill.effect_type != Skill.EffectType.HEAL:
			continue

		if skill.target_type != Skill.TargetType.ALLY_SINGLE:
			continue

		if not acting_unit.spend_mp(skill.mp_cost):
			continue

		var healing: int = CombatResolverData.calculate_skill_healing(
			acting_unit,
			skill
		)

		var applied_healing: int = heal_target.heal(healing)

		if applied_healing <= 0:
			return result

		result.set_skill_result(
			acting_unit,
			heal_target,
			skill,
			applied_healing
		)

		return result

	return result
