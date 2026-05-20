extends StaticBody3D

const OPEN_ANGLE_DEGREES := -45.0
const HANDLE_PIVOT_LOCAL := Vector3(-0.5, 0.0, 0.0)
const TWEEN_DURATION := 0.18

var is_open := false
var closed_transform: Transform3D
var door_tween: Tween
var has_closed_transform := false

func _ready() -> void:
	_capture_closed_transform.call_deferred()

func toggle_open() -> void:
	if not has_closed_transform:
		_capture_closed_transform()
	is_open = not is_open
	var target_angle := deg_to_rad(OPEN_ANGLE_DEGREES if is_open else 0.0)
	var target_transform := _get_transform_around_handle_axis(target_angle)
	if door_tween:
		door_tween.kill()
	door_tween = create_tween()
	door_tween.set_trans(Tween.TRANS_SINE)
	door_tween.set_ease(Tween.EASE_OUT)
	door_tween.tween_property(self, "global_transform", target_transform, TWEEN_DURATION)

func _capture_closed_transform() -> void:
	closed_transform = global_transform
	has_closed_transform = true

func _get_transform_around_handle_axis(angle: float) -> Transform3D:
	var pivot_global := closed_transform * HANDLE_PIVOT_LOCAL
	var axis_global := closed_transform.basis.y.normalized()
	var rotation_basis := Basis(axis_global, angle)
	var rotated_origin := pivot_global + rotation_basis * (closed_transform.origin - pivot_global)
	var rotated_basis := rotation_basis * closed_transform.basis
	return Transform3D(rotated_basis, rotated_origin)
