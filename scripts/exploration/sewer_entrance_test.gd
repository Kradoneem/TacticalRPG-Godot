extends Node2D

## Small calibration scene, not a replacement for tacticaltest.
## Background, debug grid and token share the same map coordinates.

const GridProjectionData = preload(
	"res://scripts/systems/tactical_grid_projection.gd"
)

@export var grid_size: Vector2i = Vector2i(5, 4)
@export var start_cell: Vector2i = Vector2i(1, 1)
@export var grid_origin: Vector2 = Vector2(840.0, 355.0)
@export var grid_axis_x: Vector2 = Vector2(100.0, 57.0)
@export var grid_axis_y: Vector2 = Vector2(-64.0, 65.0)
@export var show_debug_grid: bool = true

@onready var player_marker: TacticalPlayer = $PlayerMarker

var tactical_grid: TacticalGrid
var projection: GridProjectionData


func _ready() -> void:
	player_marker.set_input_enabled(false)

	if grid_size.x <= 0 or grid_size.y <= 0:
		push_error("Entrance test requires a positive grid size.")
		return

	if is_zero_approx(grid_axis_x.cross(grid_axis_y)):
		push_error("Entrance grid axes must not be parallel or zero.")
		return

	tactical_grid = TacticalGrid.new(grid_size)

	if not tactical_grid.is_walkable(start_cell):
		push_error("Entrance start cell is outside the walkable test zone.")
		return

	projection = GridProjectionData.new()
	projection.origin = grid_origin
	projection.axis_x = grid_axis_x
	projection.axis_y = grid_axis_y

	# F6 skips main.gd, so initialize only when no Main Squad exists.
	# Do not reset an existing game or duplicate its units.
	if GameState.get_main_squad() == null:
		GameState.start_new_game()

	var main_squad: Squad = GameState.get_main_squad()

	if main_squad == null:
		push_error("Entrance test could not find a Main Squad.")
		return

	player_marker.configure(
		tactical_grid,
		Vector2.ZERO,
		42.0,
		start_cell,
		main_squad,
		projection
	)

	player_marker.movement_requested.connect(_on_movement_requested)
	player_marker.set_input_enabled(true)

	queue_redraw()


func _on_movement_requested(direction: Vector2i) -> void:
	# This calibration scene has no enemies or alert state.
	# Reuse TacticalPlayer's existing validation and movement methods.
	if player_marker.move_by(direction):
		print("Entrance Main Squad cell: ", player_marker.cell)

	get_viewport().set_input_as_handled()


func _draw() -> void:
	if not show_debug_grid or projection == null or tactical_grid == null:
		return

	for row in range(grid_size.y):
		for column in range(grid_size.x):
			var cell := Vector2i(column, row)
			var outline: PackedVector2Array = projection.get_cell_outline(cell)

			draw_polyline(
				outline,
				Color(0.2, 1.0, 0.8, 0.65),
				2.0,
				true
			)

			draw_circle(
				projection.get_cell_center(cell),
				3.0,
				Color(0.2, 1.0, 0.8, 0.9)
			)
