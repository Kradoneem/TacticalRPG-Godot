extends "res://scripts/exploration/projected_exploration_map.gd"

## Entrance-specific content adapter.
## Dialogue progress and UI do not belong to this map.

@export var enable_test_dialogue: bool = true
@export var dialogue_cells: Array[Vector2i] = [
	Vector2i(3, 3),
	Vector2i(4, 3)
]


func _ready() -> void:
	super._ready()

	if _hint != null and enable_test_dialogue:
		_hint.text += (
			"\nPrototypegesprek: Enter/Spatie op cel (3,3) of (4,3)."
		)


func on_exploration_entered(_context: ExplorationEntryContext) -> void:
	GameState.current_location = "Sewer Entrance"
	GameState.in_city = false

	var exit_adapter: Node = get_node_or_null("ExitInteractions")

	if exit_adapter != null and exit_adapter.has_method("resume_exploration"):
		exit_adapter.call("resume_exploration")


func can_open_party_menu() -> bool:
	if (
		not can_process()
		or tactical_grid == null
		or player_marker.squad == null
		or not player_marker.squad.is_alive()
	):
		return false

	var exit_adapter: Node = get_node_or_null("ExitInteractions")

	if (
		exit_adapter != null
		and bool(exit_adapter.get("_interaction_active"))
	):
		return false

	return true


func _unhandled_input(event: InputEvent) -> void:
	if (
		not enable_test_dialogue
		or not can_open_party_menu()
		or player_marker.cell not in dialogue_cells
		or not event is InputEventKey
	):
		return

	if not event.is_pressed() or event.is_echo():
		return

	if (
		event.keycode != KEY_ENTER
		and event.keycode != KEY_KP_ENTER
		and event.keycode != KEY_SPACE
	):
		return

	get_viewport().set_input_as_handled()

	if GameState.has_flag("dialogue/sewer_entrance_test/completed"):
		print("[Dialogue] Entrance conversation already completed.")
		return

	# Main is the existing composition root, not another Autoload.
	var main: Node = get_tree().current_scene

	if main == null or not main.has_method("request_dialogue"):
		push_warning("Run via Main (F5) to test the dialogue integration.")
		return

	main.call(
		"request_dialogue",
		self,
		DialogueData.get_entrance_dialogue()
	)
