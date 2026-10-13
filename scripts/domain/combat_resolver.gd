extends RefCounted

## Central location for combat formulas.
## Units store their state; this resolver determines predictable outcomes.

static func calculate_physical_damage(
	attacker: Unit,
	defender: Unit
) -> int:
	var raw_damage: int = attacker.attack - defender.defense

	return maxi(1, raw_damage)


static func calculate_skill_damage(
	attacker: Unit,
	defender: Unit,
	skill: Skill
) -> int:
	if skill == null:
		return 0

	if skill.effect_type != Skill.EffectType.PHYSICAL_DAMAGE:
		return 0

	var scaled_attack: int = roundi(attacker.attack * skill.power)
	var raw_damage: int = scaled_attack - defender.defense

	return maxi(1, raw_damage)


static func calculate_skill_healing(
	caster: Unit,
	skill: Skill
) -> int:
	if skill == null:
		return 0

	if skill.effect_type != Skill.EffectType.HEAL:
		return 0

	return maxi(1, roundi(caster.wisdom * skill.power))
