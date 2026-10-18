extends Camera2D

## Camera presentation only.
## Does not move tokens or change grid coordinates.
## Bounds are expressed in this camera parent's local coordinates.

var _bounds: Rect2
var _target: Node2D
var _calibration_check: Callable
var _configured: bool = false
var _following: bool = false
var _dragging: bool = false


func configure(
	assigned_bounds: Rect2,
	assigned_target: Node2D,
	assigned_calibration_check: Callable
) -> void:
	_bounds = assigned_bounds
	_target = assigned_target
	_calibration_check = assigned_calibration_check

	# One map pixel per viewport unit.
	# Actual monitor pixels also depend on window stretching.
	zoom = Vector2.ONE
	offset = Vector2.ZERO
	position_smoothing_enabled = false
	rotation_smoothing_enabled = false

	_configured = true
	_following = false

	position = _bounds.get_center()
	_clamp_position()
	make_current()


func _is_calibrating() -> bool:
	return (
		_calibration_check.is_valid()
		and bool(_calibration_check.call())
	)


func _process(_delta: float) -> void:
	if not _configured:
		return

	if _dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		_dragging = false

	if (
		_following
		and not _is_calibrating()
		and is_instance_valid(_target)
	):
		position = _target.position

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
		var previous_screen_point: Vector2 = (
			get_viewport().get_mouse_position()
			- (event as InputEventMouseMotion).relative
		)
		var current_screen_point: Vector2 = (
			get_viewport().get_mouse_position()
		)

		# Convert viewport movement into map-local movement.
		# This also respects canvas stretching.
		var screen_to_map: Transform2D = (
			(get_parent() as Node2D)
			.get_global_transform_with_canvas()
			.affine_inverse()
		)

		position += (
			screen_to_map * previous_screen_point
			- screen_to_map * current_screen_point
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

	position = _target.position

	# During calibration, Home only centers once.
	# Camera following must not interfere with floor-point selection.
	_following = not _is_calibrating()

	_clamp_position()


func _clamp_position() -> void:
	var half_view: Vector2 = (
		get_viewport_rect().size / zoom * 0.5
	)

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
