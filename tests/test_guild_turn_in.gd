extends SceneTree

var _failures: int = 0
var _completion_signals: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		push_error(description)


func _on_quest_status_changed(
	quest_id: String,
	new_status: String
) -> void:
	if (
		quest_id == QuestData.GUILD_SEWER_QUEST_ID
		and new_status == "completed"
	):
		_completion_signals += 1


func _run() -> void:
	# Runtime load avoids compiling autoload-dependent scene scripts
	# before the autoloads exist.
	var packed: PackedScene = load("res://scenes/core/main.tscn")

	if packed == null:
		_check(false, "Main scene geladen")
		_finish()
		return

	var main: Variant = packed.instantiate()
	root.add_child(main)
	current_scene = main

	await process_frame

	var state: Node = root.get_node("GameState")
	var manager: Node = root.get_node("SceneManager")
	var city: Variant = manager.get_current_game_scene()
	var controller: Variant = main.dialogue_controller
	var quest_id: String = QuestData.GUILD_SEWER_QUEST_ID

	state.quest_status_changed.connect(_on_quest_status_changed)

	var definition: DialogueDefinition = (
		DialogueData.get_guild_sewer_turn_in_dialogue()
	)

	_check(
		definition.allow_replay
		and definition.validation_error().is_empty(),
		"Inlevergesprek geldig en herhaalbaar"
	)

	city._show_guild()
	city._on_talk_to_guild_clerk()

	_check(controller.is_active(), "Inactive quest opent acceptatiegesprek")

	if not controller.is_active():
		_finish()
		return

	controller._on_advance_requested()
	controller._on_choice_requested(&"accept_sewer_contract")

	_check(
		state.get_quest_status(quest_id) == "inactive",
		"Keuze alleen accepteert nog niet"
	)

	controller._on_advance_requested()

	_check(
		state.get_quest_status(quest_id) == "active",
		"Reactiebevestiging accepteert de opdracht"
	)

	await process_frame

	city._on_talk_to_guild_clerk()

	_check(
		not controller.is_active()
		and state.get_quest_status(quest_id) == "active",
		"Onvoltooide opdracht opent geen inlevergesprek"
	)
	_check(
		city._status.text.contains("nog niet klaar"),
		"Clerk toont voortgangsmelding"
	)

	# Even an incorrectly delivered completion callback cannot bypass
	# GameState's objective validation.
	city.on_dialogue_finished(
		DialogueData.GUILD_SEWER_TURN_IN_DIALOGUE_ID,
		&"turn_in_sewer_contract",
		true
	)

	_check(
		state.get_quest_status(quest_id) == "active",
		"Onbehaalde objectives blokkeren completion opnieuw"
	)

	var quest: QuestDefinition = QuestData.get_quest(quest_id)
	var achieved: Dictionary = {}

	# Explicit fixture using the actual quest definition.
	for objective: QuestObjective in quest.objectives:
		achieved[objective.objective_id] = true

	state.quest_objective_states[quest_id] = achieved
	city._build_guild_panel()

	_check(
		city._guild_buttons[0].text == "Turn in sewer contract",
		"Behaalde objectives tonen inleveroptie"
	)

	var gold_before: int = state.gold
	var day_before: float = state.day
	var items_before: Dictionary = state.item_inventory.duplicate(true)
	var gear_before: Dictionary = state.equipment_inventory.duplicate(true)

	city._on_talk_to_guild_clerk()

	_check(controller.is_active(), "Inlevergesprek start")

	if not controller.is_active():
		_finish()
		return

	controller._on_advance_requested()
	controller._on_choice_requested(&"turn_in_sewer_contract")

	_check(
		state.get_quest_status(quest_id) == "active",
		"Keuze vóór reactiebevestiging voltooit niets"
	)

	controller._on_cancel_requested()

	_check(
		not controller.is_active()
		and state.get_quest_status(quest_id) == "active",
		"Annuleren behoudt active quest"
	)
	_check(
		not state.has_flag(
			"dialogue/guild_sewer_turn_in/choice/turn_in_sewer_contract"
		),
		"Annuleren commit geen inleverkeuzeflag"
	)
	_check(
		main._dialogue_request_source == null,
		"Main wist de geannuleerde aanvraag"
	)

	await process_frame

	city._on_talk_to_guild_clerk()
	controller._on_advance_requested()
	controller._on_choice_requested(&"turn_in_later")
	controller._on_advance_requested()

	_check(
		state.get_quest_status(quest_id) == "active"
		and _completion_signals == 0,
		"Later afronden levert de opdracht niet in"
	)

	await process_frame

	city._on_talk_to_guild_clerk()
	controller._on_advance_requested()
	controller._on_choice_requested(&"turn_in_sewer_contract")
	controller._on_advance_requested()

	_check(
		state.get_quest_status(quest_id) == "completed"
		and _completion_signals == 1,
		"Reactiebevestiging voltooit de quest eenmaal"
	)
	_check(
		city._guild_buttons[0].disabled,
		"Completed quest heeft geen tweede inleveroptie"
	)
	_check(
		not controller.is_active()
		and city.can_process()
		and main._dialogue_request_source == null,
		"Dialogue herstelt city en wist de aanvraag"
	)

	city._on_talk_to_guild_clerk()

	_check(
		not controller.is_active(),
		"Completed quest start geen nieuw inlevergesprek"
	)

	city.on_dialogue_finished(
		DialogueData.GUILD_SEWER_TURN_IN_DIALOGUE_ID,
		&"turn_in_sewer_contract",
		true
	)

	_check(
		_completion_signals == 1
		and state.get_quest_status(quest_id) == "completed",
		"Herhaald callback voltooit niet opnieuw"
	)

	_check(
		state.gold == gold_before
		and is_equal_approx(state.day, day_before)
		and state.item_inventory == items_before
		and state.equipment_inventory == gear_before,
		"Inlevering kent geen rewards of tijdskosten toe"
	)

	state.quest_status_changed.disconnect(_on_quest_status_changed)
	state.start_new_game()

	_check(
		state.get_quest_status(quest_id) == "inactive",
		"Nieuwe game reset de ingeleverde quest"
	)

	_finish()


func _finish() -> void:
	print("[GuildTurnIn] %d failure(s)" % _failures)
	quit(0 if _failures == 0 else 1)
