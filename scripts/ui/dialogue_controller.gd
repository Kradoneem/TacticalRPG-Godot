class_name DialogueController
extends Node

## Owned by Main, outside GameLayer.
## Reuses the existing GameLayer process-mode lock and Party blocker.

signal finished(dialogue_id: StringName, committed: bool)
signal cancelled(dialogue_id: StringName)

const PARTY_BLOCK_REASON: StringName = &"dialogue"

var _game_layer: Node
var _party_controller: Node
var _state: Node
var _panel: DialoguePanel
var _session: DialogueSession

var _active: bool = false
var _previous_process_mode: int = Node.PROCESS_MODE_INHERIT


func configure(
	game_layer: Node,
	party_controller: Node,
	state: Node
) -> void:
	_game_layer = game_layer
	_party_controller = party_controller
	_state = state

	_panel = DialoguePanel.new()
	add_child(_panel)

	_panel.advance_requested.connect(_on_advance_requested)
	_panel.choice_requested.connect(_on_choice_requested)
	_panel.cancel_requested.connect(_on_cancel_requested)


func is_active() -> bool:
	return _active


func start_dialogue(definition: DialogueDefinition) -> bool:
	if (
		_active
		or definition == null
		or not is_instance_valid(_game_layer)
		or not is_instance_valid(_party_controller)
		or not is_instance_valid(_state)
		or not is_instance_valid(_panel)
		or not _panel.is_node_ready()
	):
		return false

	if not definition.validation_error().is_empty():
		push_error(definition.validation_error())
		return false

	var completion_flag: String = (
		"dialogue/%s/completed" % definition.dialogue_id
	)

	if bool(_state.call("has_flag", completion_flag)):
		return false

	# Party's existing gate also checks active scenes and modal contexts.
	if not bool(_party_controller.call("can_open")):
		return false

	var session := DialogueSession.new()

	if not session.begin(definition):
		return false

	_session = session
	_previous_process_mode = int(_game_layer.process_mode)
	_active = true

	_party_controller.call("set_blocked", PARTY_BLOCK_REASON, true)
	_game_layer.process_mode = Node.PROCESS_MODE_DISABLED
	_panel.show_session(_session)
	return true


func _on_advance_requested() -> void:
	if not _active or not _session.advance():
		return

	if _session.phase == DialogueSession.Phase.FINISHED:
		var dialogue_id: StringName = _session.definition.dialogue_id
		var committed: bool = bool(
			_state.call(
				"commit_dialogue_result",
				_session.definition,
				_session.get_result_choice_id()
			)
		)

		_restore_gameplay()
		finished.emit(dialogue_id, committed)
		return

	_panel.show_session(_session)


func _on_choice_requested(choice_id: StringName) -> void:
	if not _active or not _session.choose(choice_id):
		return

	_panel.show_session(_session)


func _on_cancel_requested() -> void:
	if not _active:
		return

	var dialogue_id: StringName = _session.definition.dialogue_id
	_session.cancel()
	_restore_gameplay()
	cancelled.emit(dialogue_id)


func _restore_gameplay() -> void:
	if not _active:
		return

	_active = false

	if is_instance_valid(_panel):
		_panel.close_panel()

	if is_instance_valid(_game_layer):
		_game_layer.process_mode = _previous_process_mode

	if is_instance_valid(_party_controller):
		_party_controller.call("set_blocked", PARTY_BLOCK_REASON, false)

	_session = null


func _exit_tree() -> void:
	# Also release our own lock if this controller is removed unexpectedly.
	_restore_gameplay()
