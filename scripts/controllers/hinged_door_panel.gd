extends MeshInstance3D

const OPEN_ANGLE_DEGREES := 90.0
const TWEEN_DURATION := 0.18

var is_open := false
var open_angle_sign := 1.0
var closed_transform: Transform3D
var pivot: Node3D = null
var door_tween: Tween = null
var has_closed_transform := false

func _ready() -> void:
	call_deferred("_ensure_pivot_and_capture")

func _ensure_pivot_and_capture() -> void:
	if pivot:
		return
	var parent_node := get_parent()
	if not parent_node:
		return
	var hinge_local := _get_hinge_pivot_local()
	var hinge_global := global_transform * hinge_local
	pivot = Node3D.new()
	pivot.name = "%s_hinge_pivot".format(name)
	parent_node.add_child(pivot)
	pivot.global_transform = Transform3D(global_transform.basis, hinge_global)
	var preserved_global := global_transform
	parent_node.remove_child(self)
	pivot.add_child(self)
	if owner:
		pivot.owner = owner
	global_transform = preserved_global
	_capture_closed_transform()

func toggle_open(viewer_position: Variant = null) -> void:
	if not pivot:
		_ensure_pivot_and_capture()
	if not has_closed_transform:
		_capture_closed_transform()
	if not is_open:
		open_angle_sign = _resolve_open_angle_sign(viewer_position)
	is_open = not is_open
	var target_deg := OPEN_ANGLE_DEGREES * open_angle_sign if is_open else 0.0
	if door_tween:
		door_tween.kill()
	door_tween = create_tween()
	door_tween.set_trans(Tween.TRANS_SINE)
	door_tween.set_ease(Tween.EASE_OUT)
	door_tween.tween_property(pivot, "rotation_degrees", Vector3(0.0, target_deg, 0.0), TWEEN_DURATION)

func get_serialized_state() -> Dictionary:
	if not has_closed_transform:
		_capture_closed_transform()
	return {
		"is_open": is_open,
		"open_angle_sign": open_angle_sign,
		"closed_transform": _transform_to_dict(closed_transform),
	}

func apply_serialized_state(state: Dictionary) -> void:
	if state.has("closed_transform"):
		closed_transform = _dict_to_transform(state.get("closed_transform", {}))
		has_closed_transform = true
	elif not has_closed_transform:
		_capture_closed_transform()
	is_open = bool(state.get("is_open", false))
	open_angle_sign = signf(float(state.get("open_angle_sign", 1.0)))
	if is_zero_approx(open_angle_sign):
		open_angle_sign = 1.0
	var target_deg := OPEN_ANGLE_DEGREES * open_angle_sign if is_open else 0.0
	if pivot:
		pivot.rotation_degrees = Vector3(0.0, target_deg, 0.0)

func rotate_placement(step_degrees: float) -> void:
	if pivot:
		pivot.rotate_object_local(Vector3.UP, deg_to_rad(step_degrees))
	if has_closed_transform:
		closed_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(step_degrees)) * closed_transform.basis, closed_transform.origin)
	else:
		closed_transform = pivot.global_transform if pivot else global_transform
		has_closed_transform = true

func refresh_diagonal_fit() -> void:
	return

func _get_hinge_pivot_local() -> Vector3:
	if mesh:
		var aabb := mesh.get_aabb()
		var panel_sign := float(get_meta("door_panel_default_sign", 1.0))
		var hinge_x := aabb.position.x if panel_sign >= 0.0 else aabb.position.x + aabb.size.x
		return Vector3(
			hinge_x,
			aabb.position.y,
			aabb.position.z + aabb.size.z * 0.5
		)
	return Vector3.ZERO

func _capture_closed_transform() -> void:
	if has_closed_transform:
		return
	closed_transform = pivot.global_transform if pivot else global_transform
	has_closed_transform = true

func _resolve_open_angle_sign(viewer_position: Variant) -> float:
	var viewer_global : Variant= _get_viewer_position(viewer_position)
	if viewer_global == null or not pivot:
		return float(get_meta("door_panel_default_sign", 1.0))
	var viewer_offset := (viewer_global as Vector3) - closed_transform.origin
	viewer_offset.y = 0.0
	if viewer_offset.length_squared() < 0.0001:
		return float(get_meta("door_panel_default_sign", 1.0))
	var positive_origin := _get_rotated_origin(OPEN_ANGLE_DEGREES)
	var negative_origin := _get_rotated_origin(-OPEN_ANGLE_DEGREES)
	var positive_delta := positive_origin - closed_transform.origin
	positive_delta.y = 0.0
	var negative_delta := negative_origin - closed_transform.origin
	negative_delta.y = 0.0
	return -1.0 if positive_delta.dot(viewer_offset) >= negative_delta.dot(viewer_offset) else 1.0

func _get_rotated_origin(angle_degrees: float) -> Vector3:
	if not pivot:
		return global_position
	var rotation_basis := Basis(Vector3.UP, deg_to_rad(angle_degrees))
	var panel_offset := global_position - pivot.global_position
	return pivot.global_position + rotation_basis * panel_offset

func _get_viewer_position(viewer_position: Variant) -> Variant:
	if viewer_position is Vector3:
		return viewer_position as Vector3
	var scene_root := get_tree().current_scene
	if not scene_root:
		return null
	var camera := scene_root.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if not camera:
		return null
	return camera.global_position

func _transform_to_dict(xform: Transform3D) -> Dictionary:
	return {
		"position": {"x": xform.origin.x, "y": xform.origin.y, "z": xform.origin.z},
		"basis": {
			"x": {"x": xform.basis.x.x, "y": xform.basis.x.y, "z": xform.basis.x.z},
			"y": {"x": xform.basis.y.x, "y": xform.basis.y.y, "z": xform.basis.y.z},
			"z": {"x": xform.basis.z.x, "y": xform.basis.z.y, "z": xform.basis.z.z}
		}
	}

func _dict_to_transform(data: Dictionary) -> Transform3D:
	return Transform3D(
		_dict_to_basis(data.get("basis", {})),
		_dict_to_vec3(data.get("position", {}))
	)

func _dict_to_vec3(data: Dictionary) -> Vector3:
	return Vector3(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("z", 0.0)))

func _dict_to_basis(data: Dictionary) -> Basis:
	return Basis(_dict_to_vec3(data.get("x", {})), _dict_to_vec3(data.get("y", {})), _dict_to_vec3(data.get("z", {})))
