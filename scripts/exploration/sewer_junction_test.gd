extends "res://scripts/exploration/exploration_map.gd"

## Junction content.
## Shared runtime owns movement, alert turns and encounters.
## Projection and walkability come from the assigned area_data.

const SewerEnemyContent = preload(
	"res://scripts/content/sewer_enemy_content.gd"
)

@export var maintenance_exit_cells: Array[Vector2i] = [
	Vector2i(0, 7)
]

## First-visit fallback.
## SceneManager restores actual departures on return visits.
@export var maintenance_arrival_cell: Vector2i = Vector2i(3, 0)

@export_group("Enemy test content")

@export var static_enemy_enabled: bool = true
@export var static_enemy_cell: Vector2i = Vector2i(8, 2)

## Enable after the single STATIC test passes.
@export var patrol_enemy_enabled: bool = false
@export var patrol_cells: Array[Vector2i] = [
	Vector2i(6, 0),
	Vector2i(7, 0)
]

@onready var _background: Sprite2D = $Background
@onready var _map_camera: Camera2D = $MapCamera


func get_location_name() -> String:
	return "Sewer Junction"


func get_calibration_prefix() -> String:
	return "sewer_junction"


func get_exit_definitions() -> Array[ExplorationExitData]:
	return [
		ExplorationExitData.create(
			&"to_maintenance",
			"Terug naar maintenance",
			maintenance_exit_cells,
			"res://scenes/exploration/sewer_maintenance_test.tscn",
			maintenance_arrival_cell
		)
	]


func get_enemy_spawns() -> Array[TacticalEnemySpawn]:
	var spawns: Array[TacticalEnemySpawn] = []

	if static_enemy_enabled:
		spawns.append(
			TacticalEnemySpawn.new(
				&"junction_static_rats",
				static_enemy_cell,
				SewerEnemyContent.create_junction_static_rat_squad
			)
		)

	if patrol_enemy_enabled:
		if patrol_cells.size() < 2:
			push_error(
				"Junction PATROL requires at least two cells."
			)

			# Let the existing runtime validator reject configuration.
			# Do not silently convert an invalid patrol into STATIC.
			spawns.append(null)
			return spawns

		spawns.append(
			TacticalEnemySpawn.new(
				&"junction_patrol_rats",
				patrol_cells[0],
				SewerEnemyContent.create_junction_patrol_rat_squad,
				patrol_cells
			)
		)

	return spawns


func _ready() -> void:
	if area_data == null:
		push_error(
			"Junction requires an ExplorationAreaData Resource."
		)
		return

	super._ready()

	if (
		tactical_grid == null
		or projection == null
		or player_marker.squad == null
	):
		return

	if _background.texture == null:
		push_error("Junction requires a background texture.")
		return

	var bounds := Rect2(
		_background.position,
		_background.texture.get_size()
	)

	_map_camera.call(
		"configure",
		bounds,
		player_marker,
		_is_authoring
	)

	_hint.text = (
		"JUNCTION | MMB: inspecteren | Home: centreren"
		+ "\nGroen: begaanbaar | rood: blocked | grijs: UNKNOWN"
		+ "\nMaintenance-uitgang: "
		+ str(maintenance_exit_cells)
		+ " | Enter / Spatie: opties"
	)

	queue_redraw()


func _is_authoring() -> bool:
	# Authoring runs in its own scene.
	return false
