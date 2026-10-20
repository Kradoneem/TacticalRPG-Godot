class_name Equipment
extends Resource

## Shared equipment definition. No ownership or quantity here.

const SLOTS: Array[StringName] = [
	&"weapon",
	&"armor",
	&"accessory"
]

const STATS: Array[StringName] = [
	&"attack",
	&"defense",
	&"speed",
	&"wisdom",
	&"max_hp"
]

@export var equipment_id: StringName = &""
@export var display_name: String = ""
@export_enum("weapon", "armor", "accessory") var slot: String = "weapon"
@export_multiline var description: String = ""

## Stat name -> additive bonus.
@export var bonuses: Dictionary = {}


func get_bonus(stat: StringName) -> int:
	return int(bonuses.get(stat, 0))


func is_valid_definition() -> bool:
	if equipment_id == &"" or display_name.is_empty():
		return false

	if StringName(slot) not in SLOTS:
		return false

	for stat in bonuses:
		if StringName(stat) not in STATS:
			return false

		if not bonuses[stat] is int:
			return false

	return true


func get_bonus_summary() -> String:
	var parts: Array[String] = []

	for stat: StringName in STATS:
		var bonus: int = get_bonus(stat)

		if bonus != 0:
			parts.append(
				"%s %+d" % [String(stat).to_upper(), bonus]
			)

	if parts.is_empty():
		return "No stat bonuses."

	return "  •  ".join(parts)
