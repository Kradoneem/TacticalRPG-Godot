extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("FAIL: " + description)


func _run_tests() -> void:
	var state: Node = root.get_node_or_null("GameState")

	if state == null:
		_check(false, "GameState exists")
		quit(1)
		return

	state.call("start_new_game")

	var quest_id: String = QuestData.GUILD_SEWER_QUEST_ID
	var definition: DialogueDefinition = (
		DialogueData.get_guild_sewer_quest_dialogue()
	)
	var quest: QuestDefinition = QuestData.get_quest(quest_id)

	_check(
		quest != null and quest.is_valid_definition(),
		"Guild quest definition is valid"
	)
	_check(
		String(state.call("get_quest_status", quest_id)) == "inactive",
		"New game does not auto-accept Guild quest"
	)
	_check(definition.allow_replay, "Guild dialogue allows replay")

	# Build the screen before invoking handlers that refresh its UI.
	var city_script: Script = load("res://scripts/city/city_screen.gd")
	var city: Node = city_script.new()
	root.add_child(city)

	if not city.is_node_ready():
		await city.ready

	_check(city.is_node_ready(), "City screen is ready before result handling")

	var session := DialogueSession.new()
	_check(session.begin(definition), "Guild session starts")
	session.advance()
	_check(session.choose(&"ask_later"), "Later answer is valid")
	session.advance()

	var later_committed: bool = bool(state.call(
		"commit_dialogue_result",
		definition,
		session.get_result_choice_id()
	))

	_check(later_committed, "Later answer commits")
	_check(
		String(state.call("get_quest_status", quest_id)) == "inactive",
		"Later grants no quest"
	)

	city.call(
		"on_dialogue_finished",
		DialogueData.GUILD_SEWER_DIALOGUE_ID,
		&"ask_later",
		later_committed
	)

	_check(
		String(state.call("get_quest_status", quest_id)) == "inactive",
		"City ignores later answer for quest activation"
	)

	session = DialogueSession.new()
	session.begin(definition)
	session.advance()
	session.choose(&"accept_sewer_contract")
	session.cancel()

	_check(
		session.get_result_choice_id() == &"",
		"Cancellation discards pending acceptance"
	)

	city.call(
		"on_dialogue_finished",
		DialogueData.GUILD_SEWER_DIALOGUE_ID,
		&"accept_sewer_contract",
		false
	)

	_check(
		String(state.call("get_quest_status", quest_id)) == "inactive",
		"Uncommitted answer grants no quest"
	)

	session = DialogueSession.new()
	session.begin(definition)
	session.advance()
	session.choose(&"accept_sewer_contract")
	session.advance()

	var acceptance_committed: bool = bool(state.call(
		"commit_dialogue_result",
		definition,
		session.get_result_choice_id()
	))

	_check(acceptance_committed, "Replay commits acceptance")

	city.call(
		"on_dialogue_finished",
		DialogueData.GUILD_SEWER_DIALOGUE_ID,
		&"accept_sewer_contract",
		acceptance_committed
	)

	_check(
		String(state.call("get_quest_status", quest_id)) == "active",
		"Real city result handler activates the quest"
	)
	_check(
		not bool(state.call(
			"has_flag",
			"dialogue/guild_sewer_quest/choice/ask_later"
		)),
		"Replay clears the previous current answer"
	)

	city.call(
		"on_dialogue_finished",
		DialogueData.GUILD_SEWER_DIALOGUE_ID,
		&"accept_sewer_contract",
		true
	)

	_check(
		String(state.call("get_quest_status", quest_id)) == "active",
		"Repeated activation retains the active quest"
	)

	for destination: CityDestination in CityData.get_destinations():
		_check(
			destination.is_valid_definition(),
			"Valid city destination: " + String(destination.destination_id)
		)

	city.free()
	state.call("start_new_game")

	_check(
		String(state.call("get_quest_status", quest_id)) == "inactive",
		"New game resets the quest"
	)

	print("Guild quest tests: %d failure(s)." % _failures)
	quit(0 if _failures == 0 else 1)
