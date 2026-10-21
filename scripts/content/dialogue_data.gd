class_name DialogueData
extends RefCounted

const ENTRANCE_DIALOGUE_ID: StringName = &"sewer_entrance_test"
const GUILD_SEWER_DIALOGUE_ID: StringName = &"guild_sewer_quest"


static func get_entrance_dialogue() -> DialogueDefinition:
	var dialogue := DialogueDefinition.new()
	dialogue.dialogue_id = ENTRANCE_DIALOGUE_ID

	dialogue.lines.append(DialogueLine.create(
		"Best Friend",
		"Voor we verdergaan: laten we afspreken hoe we dit aanpakken."
	))
	dialogue.lines.append(DialogueLine.create(
		"Best Friend",
		"Willen we voorzichtig vooruitgaan, of eerst ontdekken wat hier speelt?"
	))

	dialogue.choices.append(DialogueChoice.create(
		&"careful",
		"We blijven bij elkaar en gaan voorzichtig verder.",
		DialogueLine.create(
			"Best Friend",
			"Afgesproken. We laten elkaar niet achter."
		)
	))
	dialogue.choices.append(DialogueChoice.create(
		&"curious",
		"We onderzoeken wat hier aan de hand is.",
		DialogueLine.create(
			"Best Friend",
			"Dan kijken we goed rond. Maar samen."
		)
	))

	return dialogue


static func get_guild_sewer_quest_dialogue() -> DialogueDefinition:
	var dialogue := DialogueDefinition.new()
	dialogue.dialogue_id = GUILD_SEWER_DIALOGUE_ID
	dialogue.allow_replay = true

	dialogue.lines.append(DialogueLine.create(
		"Guild Clerk",
		"Voor deze prototypeopdracht moeten de corridor en junction "
		+ "in de sewer test-slice worden vrijgemaakt. Nemen jullie die aan?"
	))

	dialogue.choices.append(DialogueChoice.create(
		&"accept_sewer_contract",
		"Ja. We nemen de opdracht aan.",
		DialogueLine.create(
			"Guild Clerk",
			"Bevestig om de opdracht aan je Quest Log toe te voegen."
		)
	))
	dialogue.choices.append(DialogueChoice.create(
		&"ask_later",
		"Niet nu. We komen later terug.",
		DialogueLine.create(
			"Guild Clerk",
			"Prima. De opdracht blijft beschikbaar."
		)
	))

	return dialogue
