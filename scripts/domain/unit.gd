class_name Unit

extends RefCounted

## Persistent gameplay data for one character or creature.
## Tactical tokens display this data, but do not own it.

var unit_id: String
var display_name: String

var level: int
var experience: int = 0

var max_hp: int
var hp: int

var max_mp: int
var mp: int

var attack: int
var defense: int
var speed: int
var wisdom: int

var equipment: Dictionary = {}
var learned_skills: Array[StringName] = []
var learned_spells: Array[StringName] = []


func _init(
	new_unit_id: String,
	new_display_name: String,
	starting_level: int,
	starting_max_hp: int,
	starting_attack: int,
	starting_defense: int,
	starting_speed: int,
	starting_wisdom: int,
	starting_max_mp: int = 0
) -> void:
	unit_id = new_unit_id
	display_name = new_display_name

	level = starting_level
	max_hp = starting_max_hp
	hp = max_hp

	max_mp = starting_max_mp
	mp = max_mp

	attack = starting_attack
	defense = starting_defense
	speed = starting_speed
	wisdom = starting_wisdom


func is_alive() -> bool:
	return hp > 0


func take_damage(amount: int) -> int:
	var applied_damage: int = maxi(0, amount)
	hp = maxi(0, hp - applied_damage)

	return applied_damage


func heal(amount: int) -> int:
	var previous_hp: int = hp
	hp = mini(max_hp, hp + maxi(0, amount))

	return hp - previous_hp


func spend_mp(amount: int) -> bool:
	var mp_cost: int = maxi(0, amount)

	if mp < mp_cost:
		return false

	mp -= mp_cost
	return true


func restore_mp(amount: int) -> int:
	var previous_mp: int = mp
	mp = mini(max_mp, mp + maxi(0, amount))

	return mp - previous_mp

func learn_ability(ability_id: StringName) -> bool:
	var ability := SkillData.get_skill(ability_id)

	if ability == null:
		return false

	if knows_ability(ability_id):
		return false

	if ability.is_spell():
		learned_spells.append(ability_id)
	else:
		learned_skills.append(ability_id)

	return true


func forget_ability(ability_id: StringName) -> void:
	learned_skills.erase(ability_id)
	learned_spells.erase(ability_id)


func knows_ability(ability_id: StringName) -> bool:
	return (
		ability_id in learned_skills
		or ability_id in learned_spells
	)


## Compatibility method for existing callers.
## New game code should use learn_ability().
func learn_skill(skill_id: StringName) -> void:
	learn_ability(skill_id)


## Compatibility method for existing callers.
## New game code should use learn_ability().
func learn_spell(spell_id: StringName) -> void:
	learn_ability(spell_id)


func forget_skill(skill_id: StringName) -> void:
	learned_skills.erase(skill_id)


func forget_spell(spell_id: StringName) -> void:
	learned_spells.erase(spell_id)


func knows_skill(skill_id: StringName) -> bool:
	return skill_id in learned_skills


func knows_spell(spell_id: StringName) -> bool:
	return spell_id in learned_spells


func get_learned_skill_ids() -> Array[StringName]:
	return learned_skills.duplicate()


func get_learned_spell_ids() -> Array[StringName]:
	return learned_spells.duplicate()


func get_all_learned_ability_ids() -> Array[StringName]:
	var ability_ids: Array[StringName] = []

	ability_ids.append_array(learned_skills)
	ability_ids.append_array(learned_spells)

	return ability_ids


func gain_experience(amount: int) -> int:
	if amount <= 0:
		return 0

	experience += amount

	var levels_gained: int = 0

	while experience >= get_experience_to_next_level():
		experience -= get_experience_to_next_level()
		level_up()
		levels_gained += 1

	return levels_gained


func get_experience_to_next_level() -> int:
	return level * 100


func level_up() -> void:
	level += 1

	attack += 1
	defense += 1
	speed += 1
	wisdom += 1

	max_hp += 5
	hp = max_hp


func get_summary() -> String:
	return "%s | Lv.%d | HP %d/%d | MP %d/%d" % [
		display_name,
		level,
		hp,
		max_hp,
		mp,
		max_mp
	]
