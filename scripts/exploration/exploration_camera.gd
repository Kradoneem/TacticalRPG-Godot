extends Camera2D

## Camera presentation only.
## Manual inspection ends after a real target-cell change.
## Calibration never automatically recenters the camera.

@export_range(0.0, 20.0, 0.5) var follow_speed: float = 8.0

var _bounds: Rect2
var _target: TacticalPlayer
var _calibration_check: Callable
var _configured: bool = false
var _following: bool = true
var _dragging: bool = false


func configure(
	assigned_bounds: Rect2,
	assigned_target: TacticalPlayer,
	assigned_calibration_check: Callable
) -> void:
	if is_instance_valid(_target):
		if _target.cell_changed.is_connected(_on_target_cell_changed):
			_target.cell_changed.disconnect(_on_target_cell_changed)

	_bounds = assigned_bounds
	_target = assigned_target
	_calibration_check = assigned_calibration_check

	zoom = Vector2.ONE
	offset = Vector2.ZERO
	position_smoothing_enabled = false
	rotation_smoothing_enabled = false

	_configured = true
	_following = true
	_dragging = false

	_target.cell_changed.connect(_on_target_cell_changed)

	position = _target.position
	_clamp_position()
	make_current()


func _is_calibrating() -> bool:
	return (
		_calibration_check.is_valid()
		and bool(_calibration_check.call())
	)


func _on_target_cell_changed(
	previous_cell: Vector2i,
	new_cell: Vector2i
) -> void:
	if previous_cell == new_cell or _is_calibrating():
		return

	# Actual movement, not a blocked WASD attempt, resumes following.
	_dragging = false
	_following = true


func _process(delta: float) -> void:
	if not _configured:
		return

	if _dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		_dragging = false

	if (
		_following
		and not _dragging
		and not _is_calibrating()
		and is_instance_valid(_target)
	):
		if follow_speed <= 0.0:
			position = _target.position
		else:
			var weight: float = 1.0 - exp(-follow_speed * delta)
			position = position.lerp(_target.position, weight)

	_clamp_position()


func _input(event: InputEvent) -> void:
	if not _configured:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton

		if mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mouse_event.pressed

			if _dragging:
				_following = false

			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		var current_point: Vector2 = get_viewport().get_mouse_position()
		var previous_point: Vector2 = current_point - motion.relative

		var screen_to_map: Transform2D = (
			(get_parent() as Node2D)
			.get_global_transform_with_canvas()
			.affine_inverse()
		)

		position += (
			screen_to_map * previous_point
			- screen_to_map * current_point
		)

		_clamp_position()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey

		if not key_event.pressed or key_event.echo:
			return

		match key_event.keycode:
			KEY_HOME:
				focus_target()
				get_viewport().set_input_as_handled()

			KEY_END:
				_following = false
				position = _bounds.get_center()
				_clamp_position()
				get_viewport().set_input_as_handled()


func focus_target() -> void:
	if not is_instance_valid(_target):
		return

	_dragging = false
	_following = true
	position = _target.position
	_clamp_position()


func _clamp_position() -> void:
	var half_view: Vector2 = get_viewport_rect().size / zoom * 0.5

	position.x = _clamp_axis(
		position.x,
		_bounds.position.x,
		_bounds.end.x,
		half_view.x
	)

	position.y = _clamp_axis(
		position.y,
		_bounds.position.y,
		_bounds.end.y,
		half_view.y
	)


func _clamp_axis(
	value: float,
	minimum: float,
	maximum: float,
	half_view_size: float
) -> float:
	if maximum - minimum <= half_view_size * 2.0:
		return (minimum + maximum) * 0.5

	return clampf(
		value,
		minimum + half_view_size,
		maximum - half_view_size
	)
