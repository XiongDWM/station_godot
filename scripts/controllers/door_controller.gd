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

func get_serialized_state() -> Dictionary:
	if not has_closed_transform:
		_capture_closed_transform()
	return {
		"is_open": is_open,
		"closed_transform": _transform_to_dict(closed_transform)
	}

func apply_serialized_state(state: Dictionary) -> void:
	if state.has("closed_transform"):
		closed_transform = _dict_to_transform(state.get("closed_transform", {}))
		has_closed_transform = true
	elif not has_closed_transform:
		_capture_closed_transform()

	is_open = bool(state.get("is_open", false))
	var target_angle := deg_to_rad(OPEN_ANGLE_DEGREES if is_open else 0.0)
	global_transform = _get_transform_around_handle_axis(target_angle)

func _capture_closed_transform() -> void:
	if has_closed_transform:
		return
	closed_transform = global_transform
	has_closed_transform = true

func _get_transform_around_handle_axis(angle: float) -> Transform3D:
	var pivot_global := closed_transform * HANDLE_PIVOT_LOCAL
	var axis_global := closed_transform.basis.y.normalized()
	var rotation_basis := Basis(axis_global, angle)
	var rotated_origin := pivot_global + rotation_basis * (closed_transform.origin - pivot_global)
	var rotated_basis := rotation_basis * closed_transform.basis
	return Transform3D(rotated_basis, rotated_origin)

func _transform_to_dict(transform: Transform3D) -> Dictionary:
	return {
		"position": {
			"x": transform.origin.x,
			"y": transform.origin.y,
			"z": transform.origin.z
		},
		"basis": {
			"x": {"x": transform.basis.x.x, "y": transform.basis.x.y, "z": transform.basis.x.z},
			"y": {"x": transform.basis.y.x, "y": transform.basis.y.y, "z": transform.basis.y.z},
			"z": {"x": transform.basis.z.x, "y": transform.basis.z.y, "z": transform.basis.z.z}
		}
	}

func _dict_to_transform(data: Dictionary) -> Transform3D:
	return Transform3D(
		_dict_to_basis(data.get("basis", {})),
		_dict_to_vec3(data.get("position", {}))
	)

func _dict_to_vec3(data: Dictionary) -> Vector3:
	return Vector3(
		float(data.get("x", 0.0)),
		float(data.get("y", 0.0)),
		float(data.get("z", 0.0))
	)

func _dict_to_basis(data: Dictionary) -> Basis:
	return Basis(
		_dict_to_vec3(data.get("x", {})),
		_dict_to_vec3(data.get("y", {})),
		_dict_to_vec3(data.get("z", {}))
	)
