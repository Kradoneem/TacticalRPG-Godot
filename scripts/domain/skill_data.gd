class_name SkillData

extends RefCounted

## Central skill definitions.
## Each call returns a fresh, immutable Skill definition.

static func get_skill(skill_id: StringName) -> Skill:
	match skill_id:
		&"focused_strike":
			return Skill.new(
				&"focused_strike",
				"Focused Strike",
				"A deliberate weapon technique that deals increased damage.",
				Skill.EffectType.PHYSICAL_DAMAGE,
				Skill.TargetType.ENEMY_SINGLE,
				0,
				1.5
			)

		&"mend":
			return Skill.new(
				&"mend",
				"Mend",
				"Restore health to one ally.",
				Skill.EffectType.HEAL,
				Skill.TargetType.ALLY_SINGLE,
				4,
				1.5
			)

		&"patch_flesh":
			return Skill.new(
				&"patch_flesh",
				"Patch Flesh",
				"Corrupted magic that restores an ally's damaged flesh.",
				Skill.EffectType.HEAL,
				Skill.TargetType.ALLY_SINGLE,
				3,
				1.25
			)

		_:
			push_warning("SkillData could not find skill: %s" % skill_id)
			return null
