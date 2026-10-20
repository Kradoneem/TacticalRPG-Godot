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
	if attacker == null or defender == null or skill == null:
		return 0

	if skill.effect_type not in [
		Skill.EffectType.PHYSICAL_DAMAGE,
		Skill.EffectType.MAGIC_DAMAGE
	]:
		return 0

	var effective_value: int = skill.base_value

	# Preserve multiplier-based prototype abilities such as Focused Strike.
	# Existing migrated Python abilities have power == 1.0 and use
	# additive base-value scaling.
	if skill.power != 1.0:
		match skill.scaling_type:
			Skill.ScalingType.ATTACK:
				effective_value += roundi(attacker.attack * skill.power)
			Skill.ScalingType.WISDOM:
				effective_value += roundi(attacker.wisdom * skill.power)
	else:
		match skill.scaling_type:
			Skill.ScalingType.ATTACK:
				effective_value += attacker.attack
			Skill.ScalingType.WISDOM:
				effective_value += attacker.wisdom
			Skill.ScalingType.FLAT:
				pass

	# Python applied defense to physical and magical damage.
	# Godot Unit.take_damage expects damage already calculated.
	# Elemental multipliers are not implemented yet.
	return maxi(1, effective_value - defender.defense)

static func calculate_skill_healing(
	caster: Unit,
	skill: Skill
) -> int:
	if skill == null:
		return 0

	if skill.effect_type != Skill.EffectType.HEAL:
		return 0

	return maxi(1, roundi(caster.wisdom * skill.power))
