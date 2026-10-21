class_name DialogueLine
extends Resource

## Definition only. No runtime progress or gameplay state.

@export var speaker: String = ""
@export_multiline var text: String = ""


static func create(
	speaker_name: String,
	line_text: String
) -> DialogueLine:
	var line := DialogueLine.new()
	line.speaker = speaker_name
	line.text = line_text
	return line
