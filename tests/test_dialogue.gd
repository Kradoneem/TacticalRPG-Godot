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
	var definition: DialogueDefinition = DialogueData.get_entrance_dialogue()
	var session := DialogueSession.new()

	_check(definition.validation_error().is_empty(), "Prototype definition is valid")
	_check(session.begin(definition), "Session starts")
	_check(
		session.get_current_line() == definition.lines[0],
		"Session reads the existing definition"
	)
	_check(not session.choose(&"careful"), "Cannot choose during opening lines")
	_check(session.get_result_choice_id() == &"", "Opening has no result")

	session.advance()
	_check(
		session.get_current_line() == definition.lines[1],
		"Second opening line appears"
	)

	session.advance()
	_check(session.phase == DialogueSession.Phase.CHOICE, "Choice phase follows opening")
	_check(session.get_choices().size() == 2, "Two choices are available")
	_check(not session.advance(), "Advance cannot skip the choice")
	_check(not session.choose(&"unknown"), "Unknown choice is rejected")

	_check(session.choose(&"careful"), "Valid choice selects its response")
	_check(
		session.phase == DialogueSession.Phase.RESPONSE,
		"Choice moves to response phase"
	)
	_check(not session.choose(&"curious"), "A second choice cannot overwrite the answer")
	_check(session.get_result_choice_id() == &"", "Result remains pending during response")

	session.advance()
	_check(session.phase == DialogueSession.Phase.FINISHED, "Response confirmation finishes")
	_check(session.get_result_choice_id() == &"careful", "Finished session exposes answer")
	_check(not session.advance(), "Finished session cannot advance again")

	var cancelled := DialogueSession.new()
	cancelled.begin(definition)
	cancelled.advance()
	cancelled.advance()
	cancelled.choose(&"curious")
	cancelled.cancel()

	_check(
		cancelled.phase == DialogueSession.Phase.CANCELLED,
		"Cancellation closes a pending response"
	)
	_check(cancelled.get_result_choice_id() == &"", "Cancellation discards pending result")

	var invalid := DialogueDefinition.new()
	_check(not DialogueSession.new().begin(invalid), "Invalid definition is rejected")

	# Runtime lookup avoids compile-time Autoload dependencies in --script.
	var state: Node = root.get_node_or_null("GameState")

	if state == null:
		_check(false, "GameState Autoload exists")
	else:
		state.call("start_new_game")

		_check(
			not bool(state.call("commit_dialogue_result", definition, &"unknown")),
			"Unknown answer cannot be committed"
		)

		_check(
			bool(state.call("commit_dialogue_result", definition, &"careful")),
			"Finished answer can be committed once"
		)

		_check(
			bool(state.call("has_flag", "dialogue/sewer_entrance_test/completed")),
			"Completion is stored in existing GameState flags"
		)

		_check(
			bool(state.call("has_flag", "dialogue/sewer_entrance_test/choice/careful")),
			"Chosen answer is stored"
		)

		_check(
			not bool(state.call("commit_dialogue_result", definition, &"curious")),
			"Repeated completion cannot replace the answer"
		)

		_check(
			not bool(state.call("has_flag", "dialogue/sewer_entrance_test/choice/curious")),
			"Other answer remains unset"
		)

		state.call("start_new_game")

		_check(
			not bool(state.call("has_flag", "dialogue/sewer_entrance_test/completed")),
			"New game resets conversation results"
		)

	print("Dialogue tests: %d failure(s)." % _failures)
	quit(0 if _failures == 0 else 1)
