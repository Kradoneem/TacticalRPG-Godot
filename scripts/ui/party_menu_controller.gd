extends Node

## Central owner and access gate for the existing PartyMenu.
## Lives under Main, outside GameLayer.
## Does not own menu navigation or gameplay Squad/Unit data.

const PartyMenuScript = preload(
	"res://scripts/ui/party_menu.gd"
)

var _game_layer: Node
var _menu: PartyMenu
var _configured: bool = false

var _gameplay_locked: bool = false
var _previous_game_process_mode: int = Node.PROCESS_MODE_INHERIT

## Future modal systems, such as dialogue, own their own reason IDs.
var _blockers: Dictionary = {}


func configure(game_layer: Node) -> void:
	if _configured:
		push_error("PartyMenuController cannot be configured twice.")
		return

	if game_layer == null:
		push_error("PartyMenuController requires GameLayer.")
		return

	_game_layer = game_layer

	_menu = PartyMenuScript.new()
	_menu.name = "PartyMenu"
	add_child(_menu)

	_menu.closed.connect(_on_menu_closed)

	_configured = true


func set_blocked(reason: StringName, blocked: bool) -> void:
	if reason == &"":
		push_error("Party blockers require a non-empty reason.")
		return

	if blocked:
		_blockers[reason] = true

		if is_open():
			_menu.close()

	else:
		_blockers.erase(reason)


func is_open() -> bool:
	return _menu != null and _menu.is_open()


func can_open() -> bool:
	if not _configured or is_open() or not _blockers.is_empty():
		return false

	if not is_instance_valid(_game_layer):
		return false

	if _game_layer.process_mode == Node.PROCESS_MODE_DISABLED:
		return false

	if not SceneManager.can_open_party_menu():
		return false

	var active_scene: Node = SceneManager.get_current_game_scene()

	if not is_instance_valid(active_scene):
		return false

	# Party is generally available.
	# Scenes with combat or interaction restrictions supply this contract.
	if active_scene.has_method("can_open_party_menu"):
		return bool(active_scene.call("can_open_party_menu"))

	return true


func open_menu() -> void:
	if not can_open():
		return

	_previous_game_process_mode = int(_game_layer.process_mode)
	_gameplay_locked = true

	# Stops world processing and input, including map camera and exits.
	# The menu lives outside GameLayer and remains active.
	_game_layer.process_mode = Node.PROCESS_MODE_DISABLED

	_menu.open_for_squads(GameState.squads)

	# The existing menu rejects opening if no player squads are available.
	if not _menu.is_open():
		_restore_gameplay()


func _on_menu_closed() -> void:
	_restore_gameplay()


func _restore_gameplay() -> void:
	if not _gameplay_locked:
		return

	if is_instance_valid(_game_layer):
		_game_layer.process_mode = _previous_game_process_mode

	_gameplay_locked = false


func _unhandled_input(event: InputEvent) -> void:
	if not _configured or is_open():
		return

	if not event is InputEventKey:
		return

	if not event.is_pressed() or event.is_echo():
		return

	if not event.is_action_pressed("ui_cancel"):
		return

	if not can_open():
		return

	open_menu()
	get_viewport().set_input_as_handled()
