class_name GameItem
extends Resource

## Shared item definition.
## Inventory quantities belong to GameState, not to this Resource.

@export var item_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var effects: Array[ItemEffect] = []
