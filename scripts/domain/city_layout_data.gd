class_name CityLayoutData
extends Resource

## Presentation data only. No building behavior or gameplay state.

@export var background: Texture2D
@export var label_positions: Dictionary = {}


func validation_error() -> String:
	if background == null:
		return "Layout heeft geen background."

	for raw_id: Variant in label_positions:
		if not raw_id is String and not raw_id is StringName:
			return "Bestemming-ID moet String of StringName zijn."

		var destination_id := StringName(raw_id)

		if CityData.get_destination(destination_id) == null:
			return "Onbekende bestemming: %s" % destination_id

		var value: Variant = label_positions[raw_id]

		if not value is Vector2:
			return "Labelpositie moet Vector2 zijn."

		var position_ratio: Vector2 = value

		if (
			not position_ratio.is_finite()
			or position_ratio.x < 0.0
			or position_ratio.x > 1.0
			or position_ratio.y < 0.0
			or position_ratio.y > 1.0
		):
			return "Labelpositie buiten afbeelding: %s" % destination_id

	return ""


func get_label_position(destination_id: StringName) -> Vector2:
	if label_positions.has(destination_id):
		return label_positions[destination_id]

	# Also accept String keys from manually authored Resources.
	if label_positions.has(String(destination_id)):
		return label_positions[String(destination_id)]

	var destination: CityDestination = CityData.get_destination(
		destination_id
	)

	if destination == null:
		return Vector2.ZERO

	return destination.position_ratio


static func get_image_rect(
	container_size: Vector2,
	texture: Texture2D
) -> Rect2:
	if (
		texture == null
		or container_size.x <= 0.0
		or container_size.y <= 0.0
	):
		return Rect2(Vector2.ZERO, container_size)

	var texture_size: Vector2 = texture.get_size()

	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2(Vector2.ZERO, container_size)

	var image_scale: float = minf(
		container_size.x / texture_size.x,
		container_size.y / texture_size.y
	)

	var image_size: Vector2 = texture_size * image_scale

	return Rect2(
		(container_size - image_size) * 0.5,
		image_size
	)
