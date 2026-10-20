class_name LocationData
extends RefCounted

## Explicit combat-clear manifests.
## This test slice is NOT the complete Chapter 1 sewer dungeon.

const SEWER_TEST_SLICE: String = "sewer_test_slice"


static func get_required_map_ids(location_id: String) -> Array[String]:
	var maps: Array[String] = []

	match location_id:
		SEWER_TEST_SLICE:
			maps.assign([
				"sewer_corridor",
				"sewer_junction"
			])

	return maps
