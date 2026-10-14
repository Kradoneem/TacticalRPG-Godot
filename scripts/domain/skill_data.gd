class_name SkillData

extends RefCounted

## Central ability definitions.
## Every call returns a fresh, immutable Skill definition.

static func get_skill(skill_id: StringName) -> Skill:
	match skill_id:
		## ---------------------------------------------------------
		## Current Chapter 1 prototype abilities
		## ---------------------------------------------------------

		&"focused_strike":
			return Skill.new(
				&"focused_strike",
				"Focused Strike",
				"A deliberate weapon technique that deals increased damage.",
				Skill.Category.SKILL,
				Skill.EffectType.PHYSICAL_DAMAGE,
				Skill.TargetType.ENEMY_SINGLE,
				0,
				0,
				Skill.ScalingType.ATTACK,
				[],
				0,
				{},
				1.5
			)

		&"mend":
			return Skill.new(
				&"mend",
				"Mend",
				"Restore health to one ally.",
				Skill.Category.SPELL,
				Skill.EffectType.HEAL,
				Skill.TargetType.ALLY_SINGLE,
				4,
				0,
				Skill.ScalingType.WISDOM,
				[],
				0,
				{},
				1.5
			)

		&"patch_flesh":
			return Skill.new(
				&"patch_flesh",
				"Patch Flesh",
				"Corrupted magic that restores an ally's damaged flesh.",
				Skill.Category.SPELL,
				Skill.EffectType.HEAL,
				Skill.TargetType.ALLY_SINGLE,
				3,
				0,
				Skill.ScalingType.WISDOM,
				[],
				0,
				{},
				1.25
			)

		## ---------------------------------------------------------
		## Migrated Python spells
		## ---------------------------------------------------------

		&"heal":
			return Skill.new(
				&"heal",
				"Heal",
				"Restores HP to one ally.",
				Skill.Category.SPELL,
				Skill.EffectType.HEAL,
				Skill.TargetType.ALLY_SINGLE,
				5,
				10,
				Skill.ScalingType.WISDOM
			)

		&"fireball":
			return Skill.new(
				&"fireball",
				"Fireball",
				"Hurls a ball of fire at one enemy.",
				Skill.Category.SPELL,
				Skill.EffectType.MAGIC_DAMAGE,
				Skill.TargetType.ENEMY_SINGLE,
				6,
				14,
				Skill.ScalingType.WISDOM,
				[&"fire"]
			)

		&"blizzard":
			return Skill.new(
				&"blizzard",
				"Blizzard",
				"Freezing shards strike one enemy.",
				Skill.Category.SPELL,
				Skill.EffectType.MAGIC_DAMAGE,
				Skill.TargetType.ENEMY_SINGLE,
				6,
				12,
				Skill.ScalingType.WISDOM,
				[&"ice"]
			)

		&"thunder":
			return Skill.new(
				&"thunder",
				"Thunder",
				"A bolt of lightning strikes one enemy.",
				Skill.Category.SPELL,
				Skill.EffectType.MAGIC_DAMAGE,
				Skill.TargetType.ENEMY_SINGLE,
				6,
				13,
				Skill.ScalingType.WISDOM,
				[&"thunder"]
			)

		&"dark_drain":
			return Skill.new(
				&"dark_drain",
				"Dark Drain",
				"Drains life from one enemy.",
				Skill.Category.SPELL,
				Skill.EffectType.DRAIN,
				Skill.TargetType.ENEMY_SINGLE,
				8,
				10,
				Skill.ScalingType.WISDOM,
				[&"dark"]
			)

		&"holy_light":
			return Skill.new(
				&"holy_light",
				"Holy Light",
				"A burst of light damages all enemies.",
				Skill.Category.SPELL,
				Skill.EffectType.MAGIC_DAMAGE,
				Skill.TargetType.ENEMY_ALL,
				10,
				8,
				Skill.ScalingType.WISDOM,
				[&"light"]
			)

		## ---------------------------------------------------------
		## Migrated Python skills
		## ---------------------------------------------------------

		&"power_strike":
			return Skill.new(
				&"power_strike",
				"Power Strike",
				"A heavy blow that deals extra damage.",
				Skill.Category.SKILL,
				Skill.EffectType.PHYSICAL_DAMAGE,
				Skill.TargetType.ENEMY_SINGLE,
				0,
				6,
				Skill.ScalingType.ATTACK,
				[],
				4
			)

		&"provoke":
			return Skill.new(
				&"provoke",
				"Provoke",
				"Taunts an enemy.",
				Skill.Category.SKILL,
				Skill.EffectType.DEBUFF,
				Skill.TargetType.ENEMY_SINGLE,
				0,
				0,
				Skill.ScalingType.FLAT
			)

		&"battle_cry":
			return Skill.new(
				&"battle_cry",
				"Battle Cry",
				"Rallies all allies.",
				Skill.Category.SKILL,
				Skill.EffectType.BUFF,
				Skill.TargetType.ALLY_ALL,
				4,
				0,
				Skill.ScalingType.FLAT
			)

		_:
			push_warning(
				"SkillData could not find ability: %s."
				% skill_id
			)
			return null

static func get_all_ability_ids() -> Array[StringName]:
	return [
		&"focused_strike",
		&"mend",
		&"patch_flesh",
		&"heal",
		&"fireball",
		&"blizzard",
		&"thunder",
		&"dark_drain",
		&"holy_light",
		&"power_strike",
		&"provoke",
		&"battle_cry"
	]

static func get_all_skill_ids() -> Array[StringName]:
	var skill_ids: Array[StringName] = []

	for ability_id: StringName in get_all_ability_ids():
		var ability := get_skill(ability_id)

		if ability != null and ability.is_skill():
			skill_ids.append(ability_id)

	return skill_ids

static func get_all_spell_ids() -> Array[StringName]:
	var spell_ids: Array[StringName] = []

	for ability_id: StringName in get_all_ability_ids():
		var ability := get_skill(ability_id)

		if ability != null and ability.is_spell():
			spell_ids.append(ability_id)

	return spell_ids
