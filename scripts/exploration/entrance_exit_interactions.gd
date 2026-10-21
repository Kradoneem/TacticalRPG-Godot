extends Node

## Entrance connection content and movement-lock adapter.

const ExitControllerScript = preload(
	"res://scripts/exploration/exploration_exit_controller.gd"
)

const CITY_SCENE_PATH: String = (
	"res://scenes/city/city_screen.tscn"
)
const CORRIDOR_SCENE_PATH: String = (
	"res://scenes/exploration/sewer_corridor_test.tscn"
)

@export var city_cells: Array[Vector2i] = [
	Vector2i(0, 2),
	Vector2i(0, 3)
]

@export var corridor_cells: Array[Vector2i] = [
	Vector2i(6, 0),
	Vector2i(7, 0)
]

@onready var entrance: Node2D = get_parent() as Node2D
@onready var player_marker: TacticalPlayer = (
	get_parent().get_node("PlayerMarker") as TacticalPlayer
)

var _exits: ExitControllerScript
var _interaction_active: bool = false


func _ready() -> void:
	call_deferred("_initialize_exits")


func _initialize_exits() -> void:
	if player_marker.squad == null:
		push_error("Entrance exits require a configured Main Squad.")
		return

	var definitions: Array[ExplorationExitData] = [
		ExplorationExitData.create(
			&"to_city",
			"Terug naar de stad",
			city_cells,
			CITY_SCENE_PATH,
			Vector2i.ZERO
		),
		ExplorationExitData.create(
			&"to_corridor",
			"Door naar de corridor",
			corridor_cells,
			CORRIDOR_SCENE_PATH,
			Vector2i(0, 1)
		)
	]

	_exits = ExitControllerScript.new()
	add_child(_exits)

	_exits.interaction_active_changed.connect(
		_on_interaction_active_changed
	)
	_exits.travel_requested.connect(_on_travel_requested)

	if not _exits.configure(player_marker, definitions, _can_interact):
		_exits.queue_free()
		_exits = null
		push_error("Entrance exit configuration failed.")


func _can_interact() -> bool:
	return (
		not bool(entrance.get("_calibrating"))
		and player_marker.squad != null
		and player_marker.squad.is_alive()
	)


func _on_interaction_active_changed(active: bool) -> void:
	_interaction_active = active
	player_marker.set_input_enabled(not active and _can_interact())


func _input(event: InputEvent) -> void:
	if not _interaction_active:
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey

		if key_event.pressed and key_event.keycode == KEY_F2:
			get_viewport().set_input_as_handled()


func _on_travel_requested(
	exit_data: ExplorationExitData,
	departure_cell: Vector2i
) -> void:
	if exit_data.exit_id == &"to_city":
		call_deferred("_return_to_city")
		return

	var destination: Node = SceneManager.travel_exploration(
		entrance,
		exit_data,
		departure_cell
	)

	if destination == null:
		_exits.recover_from_transition_error(
			"Kamerwissel mislukt. Controleer Output."
		)

func resume_exploration() -> void:
	if _exits != null:
		_exits.complete_transition()

func _return_to_city() -> void:
	if not SceneManager.return_to_city(entrance):
		_exits.recover_from_transition_error(
			"Terugkeer naar de stad mislukte. Controleer Output."
		)
		return

	# The entrance is now detached and cannot receive world input.
	# Clear the pending exit interaction before its later re-entry.
	resume_exploration()
