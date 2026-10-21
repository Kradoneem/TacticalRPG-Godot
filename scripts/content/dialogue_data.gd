class_name DialogueData
extends RefCounted

## Technical prototype content, not definitive Chapter 1 dialogue.

const ENTRANCE_DIALOGUE_ID: StringName = &"sewer_entrance_test"


static func get_entrance_dialogue() -> DialogueDefinition:
	var dialogue := DialogueDefinition.new()
	dialogue.dialogue_id = ENTRANCE_DIALOGUE_ID

	dialogue.lines.append(
		DialogueLine.create(
			"Best Friend",
			"Voor we verdergaan: laten we afspreken hoe we dit aanpakken."
		)
	)

	dialogue.lines.append(
		DialogueLine.create(
			"Best Friend",
			"Willen we voorzichtig vooruitgaan, of eerst ontdekken wat hier speelt?"
		)
	)

	dialogue.choices.append(
		DialogueChoice.create(
			&"careful",
			"We blijven bij elkaar en gaan voorzichtig verder.",
			DialogueLine.create(
				"Best Friend",
				"Afgesproken. We laten elkaar niet achter."
			)
		)
	)

	dialogue.choices.append(
		DialogueChoice.create(
			&"curious",
			"We onderzoeken wat hier aan de hand is.",
			DialogueLine.create(
				"Best Friend",
				"Dan kijken we goed rond. Maar samen."
			)
		)
	)

	return dialogue
