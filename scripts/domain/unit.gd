class_name Unit
extends RefCounted

## Persistent gameplay data shared by tactical and battle.
## Effective stats are base stats plus currently equipped bonuses.

var unit_id: String
var display_name: String

var level: int
var experience: int = 0

var base_max_hp: int = 0
var base_attack: int = 0
var base_defense: int = 0
var base_speed: int = 0
var base_wisdom: int = 0

var hp: int
var max_mp: int
var mp: int

## Existing callers still read/write effective stat properties.
## New progression code changes base stats explicitly.
var max_hp: int:
	get:
		return base_max_hp + get_equipment_bonus(&"max_hp")
	set(value):
		base_max_hp = value - get_equipment_bonus(&"max_hp")

var attack: int:
	get:
		return (
			base_attack
			+ get_equipment_bonus(&"attack")
			+ get_attack_buff_bonus()
		)
	set(value):
		base_attack = (
			value
			- get_equipment_bonus(&"attack")
			- get_attack_buff_bonus()
		)

var defense: int:
	get:
		return base_defense + get_equipment_bonus(&"defense")
	set(value):
		base_defense = value - get_equipment_bonus(&"defense")

var speed: int:
	get:
		return base_speed + get_equipment_bonus(&"speed")
	set(value):
		base_speed = value - get_equipment_bonus(&"speed")

var wisdom: int:
	get:
		return base_wisdom + get_equipment_bonus(&"wisdom")
	set(value):
		base_wisdom = value - get_equipment_bonus(&"wisdom")

## Slot -> equipment ID. Mutation goes through set_equipment().
var _equipment: Dictionary = {}

var equipment: Dictionary:
	get:
		return _equipment.duplicate()

var learned_skills: Array[StringName] = []
var learned_spells: Array[StringName] = []
var _attack_buffs: Dictionary = {}


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

	base_max_hp = starting_max_hp
	base_attack = starting_attack
	base_defense = starting_defense
	base_speed = starting_speed
	base_wisdom = starting_wisdom

	hp = max_hp
	max_mp = starting_max_mp
	mp = max_mp


func get_equipment_id(slot: StringName) -> StringName:
	return StringName(_equipment.get(slot, &""))


func get_equipment_bonus(stat: StringName) -> int:
	var total: int = 0

	for equipment_id in _equipment.values():
		var gear: Equipment = EquipmentData.get_equipment(
			StringName(equipment_id)
		)

		if gear != null:
			total += gear.get_bonus(stat)

	return total


func set_equipment(
	slot: StringName,
	equipment_id: StringName
) -> bool:
	## Only changes Unit data.
	## GameState owns stock validation and transfers.

	if slot not in Equipment.SLOTS:
		return false

	if equipment_id != &"":
		var gear: Equipment = EquipmentData.get_equipment(equipment_id)

		if (
			gear == null
			or not gear.is_valid_definition()
			or StringName(gear.slot) != slot
		):
			return false

	var old_id: StringName = get_equipment_id(slot)

	if old_id == equipment_id:
		return false

	var old_max_hp: int = max_hp
	var old_hp: int = hp

	if equipment_id == &"":
		_equipment.erase(slot)
	else:
		_equipment[slot] = equipment_id

	if max_hp <= 0:
		if old_id == &"":
			_equipment.erase(slot)
		else:
			_equipment[slot] = old_id
		return false

	_preserve_health_ratio(old_hp, old_max_hp)
	return true

func _preserve_health_ratio(old_hp: int, old_max_hp: int) -> void:
	if old_hp <= 0:
		hp = 0
		return

	if old_max_hp <= 0:
		hp = clampi(old_hp, 1, max_hp)
		return

	hp = clampi(
		floori(float(old_hp) * float(max_hp) / float(old_max_hp)),
		1,
		max_hp
	)


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


## Compatibility methods. New code uses learn_ability().
func learn_skill(skill_id: StringName) -> void:
	learn_ability(skill_id)


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

	base_attack += 1
	base_defense += 1
	base_speed += 1
	base_wisdom += 1
	base_max_hp += 5

	# Existing progression behavior: level-up restores HP.
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

func apply_attack_buff(
	definition: AttackBuffData,
	caster_wisdom: int,
	clock: GameplayClock
) -> bool:
	if (
		definition == null
		or not definition.is_valid_definition()
		or clock == null
		or not is_alive()
	):
		return false

	# Same buff ID replaces bonus and restarts duration, across casters.
	_attack_buffs[definition.buff_id] = ActiveAttackBuff.new(
		definition, caster_wisdom, clock
	)
	return true


func get_attack_buff_bonus() -> int:
	var total: int = 0

	# Lazy removal also works for Units on unloaded/retained maps.
	for buff_id in _attack_buffs.keys():
		var buff: ActiveAttackBuff = _attack_buffs[buff_id]

		if not buff.is_active():
			_attack_buffs.erase(buff_id)
			continue

		total += buff.attack_bonus

	return total


func get_attack_buff_summary() -> String:
	var lines: Array[String] = []

	for buff_id in _attack_buffs.keys():
		var buff: ActiveAttackBuff = _attack_buffs[buff_id]

		if not buff.is_active():
			_attack_buffs.erase(buff_id)
			continue

		lines.append("%s: ATK +%d (%d ticks)" % [
			buff.display_name,
			buff.attack_bonus,
			buff.get_remaining_ticks()
		])

	return ", ".join(lines)
