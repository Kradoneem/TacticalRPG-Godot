class_name Squad

extends RefCounted

## A Squad is the tactical actor on the map.
## Individual Units remain members of a squad and do not receive
## their own tactical-grid position.

const MAX_MEMBERS: int = 4


enum AutonomyMode {
	MAIN_SQUAD,
	AUTONOMOUS_ALLY,
	ENEMY
}


var squad_id: String
var display_name: String
var members: Array[Unit] = []

var autonomy_mode: int
var default_strategy: StringName = &"balanced"

## Explicit enemy content. No gold/loot values are invented by resolution.
var defeat_gold: int = 0
var defeat_items: Dictionary = {}


func _init(
	new_squad_id: String,
	new_display_name: String,
	new_autonomy_mode: int = AutonomyMode.AUTONOMOUS_ALLY
) -> void:
	squad_id = new_squad_id
	display_name = new_display_name
	autonomy_mode = new_autonomy_mode


func add_member(unit: Unit) -> bool:
	if unit == null:
		return false

	if unit in members:
		return true

	if members.size() >= MAX_MEMBERS:
		return false

	members.append(unit)
	return true


func remove_member(unit: Unit) -> bool:
	var member_index: int = members.find(unit)

	if member_index == -1:
		return false

	members.remove_at(member_index)
	return true


func contains_member(unit: Unit) -> bool:
	return unit in members


func is_empty() -> bool:
	return members.is_empty()


func is_alive() -> bool:
	for unit: Unit in members:
		if unit.is_alive():
			return true

	return false


func get_leader() -> Unit:
	if members.is_empty():
		return null

	return members[0]


func get_living_members() -> Array[Unit]:
	var living_members: Array[Unit] = []

	for unit: Unit in members:
		if unit.is_alive():
			living_members.append(unit)

	return living_members

func get_first_living_member() -> Unit:
	for unit: Unit in members:
		if unit.is_alive():
			return unit

	return null

func get_most_wounded_living_member() -> Unit:
	var most_wounded_unit: Unit = null
	var lowest_health_ratio: float = 2.0

	for unit: Unit in members:
		if not unit.is_alive():
			continue

		if unit.max_hp <= 0:
			continue

		var health_ratio: float = float(unit.hp) / float(unit.max_hp)

		if health_ratio < lowest_health_ratio:
			lowest_health_ratio = health_ratio
			most_wounded_unit = unit

	return most_wounded_unit

func get_total_hp() -> int:
	var total_hp: int = 0

	for unit: Unit in members:
		total_hp += unit.hp

	return total_hp


func get_total_max_hp() -> int:
	var total_max_hp: int = 0

	for unit: Unit in members:
		total_max_hp += unit.max_hp

	return total_max_hp


func get_health_ratio() -> float:
	var total_max_hp: int = get_total_max_hp()

	if total_max_hp <= 0:
		return 0.0

	return float(get_total_hp()) / float(total_max_hp)


func get_average_speed() -> float:
	var living_members: Array[Unit] = get_living_members()

	if living_members.is_empty():
		return 0.0

	var total_speed: int = 0

	for unit: Unit in living_members:
		total_speed += unit.speed

	return float(total_speed) / float(living_members.size())

func get_slowest_living_member_speed() -> int:
	var living_members: Array[Unit] = get_living_members()

	if living_members.is_empty():
		return 0

	var slowest_speed: int = living_members[0].speed

	for unit: Unit in living_members:
		slowest_speed = mini(slowest_speed, unit.speed)

	return slowest_speed


func get_alert_movement_budget() -> int:
	var living_member_count: int = get_living_members().size()
	var formation_lightness_bonus: int = MAX_MEMBERS - living_member_count
	var base_movement: int = floori(
		float(get_slowest_living_member_speed()) / 3.0
	)

	return clampi(
		base_movement + formation_lightness_bonus,
		2,
		5
	)


func get_alert_initiative() -> int:
	var living_member_count: int = get_living_members().size()
	var formation_lightness_bonus: int = (
		MAX_MEMBERS - living_member_count
	) * 2

	return roundi(get_average_speed()) + formation_lightness_bonus

func get_summary() -> String:
	var member_names: Array[String] = []

	for unit: Unit in members:
		member_names.append(unit.display_name)

	return "%s | %d/%d members | Strategy: %s | Members: %s" % [
		display_name,
		members.size(),
		MAX_MEMBERS,
		default_strategy,
		", ".join(member_names)
	]
