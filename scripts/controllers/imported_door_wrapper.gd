extends StaticBody3D

const DEFAULT_FRAME_NAMES := ["box001"]
const DEFAULT_SINGLE_PANEL_NAMES := ["dummy001", "box004"]
const DEFAULT_DOUBLE_PANEL_NAMES := ["dummy001", "dummy002", "box003", "box004"]
const OPEN_ANGLE_DEGREES := 90.0
const PANEL_COLLISION_WIDTH := 0.6
const SOLID_COLLISION_LAYER := 1
const PICK_COLLISION_LAYER := 2
const HOST_WALL_SCENE := "res://wall_object.tscn"

class PanelHinge:
	var panel_root: Node3D
	var reference_mesh: MeshInstance3D
	var pivot: Node3D
	var panel_physics: StaticBody3D
	var closed_pivot_transform: Transform3D
	var hinge_edge_local := Vector3.ZERO
	var default_sign := 1.0
	var is_open := false
	var open_angle_sign := 1.0
	var tween: Tween

@export var door_variant_id := "single"
@export var panel_collision_width := PANEL_COLLISION_WIDTH
@export var panel_node_names: PackedStringArray = PackedStringArray()
@export var frame_node_names: PackedStringArray = PackedStringArray()

var is_open := false
var closed_transform: Transform3D
var has_closed_transform := false
var panel_hinges: Array[PanelHinge] = []
var _variant_setup_done := false
var _host_wall: StaticBody3D = null
var _pending_serialized_state: Dictionary = {}

@onready var model_root: Node3D = $Model
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	input_ray_pickable = true
	collision_layer = 1
	collision_mask = 1
	set_meta("door_variant_id", door_variant_id)
	if not Engine.is_editor_hint():
		call_deferred("_ensure_variant_setup")

func finalize_after_placement() -> void:
	_setup_variant(true)

func _ensure_variant_setup() -> void:
	if _variant_setup_done:
		return
	_setup_variant(false)

func _setup_variant(force_rebuild: bool) -> void:
	if _variant_setup_done and not force_rebuild:
		return
	_clear_panel_hinges()
	if not model_root:
		push_warning("Door missing Model node: %s" % name)
		return
	if door_variant_id == "single":
		_apply_logical_length_scale()
	_apply_diagonal_fit_to_model()
	_build_panel_hinges()
	if not _pending_serialized_state.is_empty():
		_apply_saved_state(_pending_serialized_state)
		_pending_serialized_state = {}
	_refresh_door_physics_state()
	if panel_hinges.is_empty():
		var mesh_names := _collect_mesh_label_list(model_root)
		push_warning("Door has no hinge panels. Expected dummy001/box004. Found meshes: %s" % ", ".join(mesh_names))
	_variant_setup_done = not panel_hinges.is_empty() or force_rebuild

func toggle_open(viewer_position: Variant = null) -> void:
	if panel_hinges.is_empty():
		_setup_variant(true)
	if panel_hinges.is_empty():
		return
	for hinge in panel_hinges:
		_toggle_panel_hinge(hinge, viewer_position)
	is_open = panel_hinges[0].is_open if not panel_hinges.is_empty() else false
	_refresh_door_physics_state()

func get_serialized_state() -> Dictionary:
	if panel_hinges.is_empty():
		_setup_variant(false)
	if not has_closed_transform:
		_capture_closed_transform()
	var panel_states: Array = []
	for hinge in panel_hinges:
		panel_states.append({
			"is_open": hinge.is_open,
			"open_angle_sign": hinge.open_angle_sign,
			"closed_pivot": _transform_to_dict(hinge.closed_pivot_transform),
		})
	var state := {
		"door_variant_id": door_variant_id,
		"is_open": is_open,
		"closed_transform": _transform_to_dict(closed_transform),
		"panel_states": panel_states,
	}
	var host_wall := _resolve_host_wall()
	if host_wall:
		var wall_pos := host_wall.global_position
		state["host_wall_position"] = {"x": wall_pos.x, "y": wall_pos.y, "z": wall_pos.z}
	return state

func apply_serialized_state(state: Dictionary) -> void:
	_pending_serialized_state = state.duplicate(true)
	if _variant_setup_done and not panel_hinges.is_empty():
		_apply_saved_state(_pending_serialized_state)
		_pending_serialized_state = {}

func finalize_serialized_state() -> void:
	if not _variant_setup_done:
		_setup_variant(false)
	elif not _pending_serialized_state.is_empty():
		_apply_saved_state(_pending_serialized_state)
		_pending_serialized_state = {}
	_host_wall = null
	_refresh_door_physics_state()

func _apply_saved_state(state: Dictionary) -> void:
	door_variant_id = str(state.get("door_variant_id", door_variant_id))
	set_meta("door_variant_id", door_variant_id)
	if state.has("closed_transform"):
		closed_transform = _dict_to_transform(state.get("closed_transform", {}))
		has_closed_transform = true
	if state.has("host_wall_position") and state["host_wall_position"] is Dictionary:
		set_meta("host_wall_position", (state["host_wall_position"] as Dictionary).duplicate(true))
	is_open = bool(state.get("is_open", false))
	var panel_states :Variant= state.get("panel_states", [])
	for index in panel_hinges.size():
		if index >= panel_states.size():
			break
		var panel_state :Variant= panel_states[index]
		if not panel_state is Dictionary:
			continue
		var hinge := panel_hinges[index]
		hinge.is_open = bool(panel_state.get("is_open", false))
		hinge.open_angle_sign = signf(float(panel_state.get("open_angle_sign", 1.0)))
		if panel_state.has("closed_pivot"):
			hinge.closed_pivot_transform = _dict_to_transform(panel_state.get("closed_pivot", {}))
		if hinge.pivot:
			var target_deg := OPEN_ANGLE_DEGREES * hinge.open_angle_sign if hinge.is_open else 0.0
			hinge.pivot.global_transform = _compute_hinge_transform(hinge, target_deg)
	is_open = panel_hinges[0].is_open if not panel_hinges.is_empty() else is_open
	_apply_diagonal_fit_to_model()

func rotate_placement(step_degrees: float) -> void:
	var rotation_basis := Basis(Vector3.UP, deg_to_rad(step_degrees))
	global_transform = Transform3D(rotation_basis * global_transform.basis, global_transform.origin)
	if has_closed_transform:
		closed_transform = Transform3D(rotation_basis * closed_transform.basis, closed_transform.origin)
	else:
		closed_transform = global_transform
		has_closed_transform = true
	for hinge in panel_hinges:
		if hinge.pivot:
			hinge.pivot.global_transform = Transform3D(rotation_basis * hinge.pivot.global_transform.basis, hinge.pivot.global_transform.origin)
			hinge.closed_pivot_transform = hinge.pivot.global_transform
	_apply_diagonal_fit_to_model()
	_refresh_door_physics_state()

func refresh_diagonal_fit() -> void:
	_apply_diagonal_fit_to_model()
	_refresh_door_physics_state()

func _apply_diagonal_fit_to_model() -> void:
	if door_variant_id != "single" or not model_root:
		return
	var logical_length_scale := float(get_meta("logical_length_scale", 1.0))
	model_root.set_meta("diagonal_fit_base_scale", Vector3(logical_length_scale, 1.0, 1.0))
	var reference_basis := closed_transform.basis if has_closed_transform else global_transform.basis
	DiagonalBuildingFit.apply_to_preview(model_root, reference_basis)

func _apply_logical_length_scale() -> void:
	if model_root:
		model_root.set_meta("diagonal_fit_base_scale", Vector3(float(get_meta("logical_length_scale", 1.0)), 1.0, 1.0))

func _build_panel_hinges() -> void:
	var panel_roots: Array[Node3D] = []
	_collect_panel_roots(model_root, panel_roots)
	if panel_roots.is_empty():
		for mesh_instance in _collect_mesh_instances(model_root):
			if _mesh_is_frame(mesh_instance):
				continue
			if _mesh_is_panel(mesh_instance):
				panel_roots.append(mesh_instance)
	if panel_roots.is_empty():
		for mesh_instance in _collect_mesh_instances(model_root):
			if not _mesh_is_frame(mesh_instance):
				panel_roots.append(mesh_instance)
	for panel_root in panel_roots:
		if _is_node_already_hinged(panel_root):
			continue
		_create_panel_hinge(panel_root)

func _collect_panel_roots(node: Node, out_roots: Array[Node3D]) -> void:
	if node is Node3D and node != model_root:
		if _node_is_frame(node as Node3D):
			return
		if _node_is_panel(node as Node3D):
			if not _is_node_already_hinged(node as Node3D):
				out_roots.append(node as Node3D)
			return
	for child in node.get_children():
		if str(child.name).ends_with("_hinge_pivot"):
			continue
		_collect_panel_roots(child, out_roots)

func _is_node_already_hinged(node: Node) -> bool:
	var parent_node := node.get_parent()
	return parent_node is Node3D and str(parent_node.name).ends_with("_hinge_pivot")

func _is_mesh_already_hinged(mesh_instance: MeshInstance3D) -> bool:
	return _is_node_already_hinged(mesh_instance)

func _create_panel_hinge(panel_root: Node3D) -> void:
	var reference_mesh := _find_first_mesh_in_subtree(panel_root)
	if not reference_mesh:
		push_warning("Door panel has no mesh: %s" % panel_root.name)
		return
	var hinge := PanelHinge.new()
	hinge.panel_root = panel_root
	hinge.reference_mesh = reference_mesh
	hinge.default_sign = 1.0
	var parent_node := panel_root.get_parent()
	if not parent_node:
		return
	var hinge_local := _get_hinge_pivot_local(panel_root, reference_mesh)
	hinge.hinge_edge_local = hinge_local
	var hinge_global := panel_root.global_transform * hinge_local
	hinge.pivot = Node3D.new()
	hinge.pivot.name = "%s_hinge_pivot" % panel_root.name
	parent_node.add_child(hinge.pivot)
	hinge.pivot.global_transform = Transform3D(panel_root.global_transform.basis, hinge_global)
	var preserved_global := panel_root.global_transform
	parent_node.remove_child(panel_root)
	hinge.pivot.add_child(panel_root)
	panel_root.global_transform = preserved_global
	hinge.closed_pivot_transform = hinge.pivot.global_transform
	hinge.default_sign = _detect_default_open_sign(hinge)
	panel_hinges.append(hinge)
	_attach_panel_physics(hinge)

func _attach_panel_physics(hinge: PanelHinge) -> void:
	if not hinge.panel_root:
		return
	_remove_panel_physics(hinge)
	var local_bounds := _compute_panel_local_aabb(hinge.panel_root)
	if local_bounds.size.length_squared() < 0.0001:
		return
	var box_size := local_bounds.size
	if box_size.x <= box_size.z:
		box_size.x = panel_collision_width
	else:
		box_size.z = panel_collision_width
	var panel_body := StaticBody3D.new()
	panel_body.name = "PanelPhysics"
	panel_body.collision_layer = SOLID_COLLISION_LAYER
	panel_body.collision_mask = SOLID_COLLISION_LAYER
	panel_body.input_ray_pickable = false
	var shape_node := CollisionShape3D.new()
	shape_node.name = "PanelCollision"
	var box := BoxShape3D.new()
	box.size = box_size
	shape_node.shape = box
	shape_node.position = local_bounds.get_center()
	panel_body.add_child(shape_node)
	hinge.panel_root.add_child(panel_body)
	hinge.panel_physics = panel_body

func _remove_panel_physics(hinge: PanelHinge) -> void:
	if hinge.panel_physics and is_instance_valid(hinge.panel_physics):
		hinge.panel_physics.queue_free()
	hinge.panel_physics = null
	var existing := hinge.panel_root.get_node_or_null("PanelPhysics") if hinge.panel_root else null
	if existing:
		existing.queue_free()

func _refresh_all_panel_physics() -> void:
	for hinge in panel_hinges:
		_attach_panel_physics(hinge)

func _detect_default_open_sign(hinge: PanelHinge) -> float:
	var free_closed := _get_free_edge_global(hinge, 0.0)
	var frame_pos := _get_frame_reference_position()
	var score_positive := _score_open_sign(hinge, 1.0, free_closed, Vector3.ZERO, frame_pos)
	var score_negative := _score_open_sign(hinge, -1.0, free_closed, Vector3.ZERO, frame_pos)
	return 1.0 if score_positive >= score_negative else -1.0

func _find_first_mesh_in_subtree(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_first_mesh_in_subtree(child)
		if found:
			return found
	return null

func _toggle_panel_hinge(hinge: PanelHinge, viewer_position: Variant) -> void:
	if not hinge.pivot:
		return
	if not hinge.is_open:
		hinge.open_angle_sign = _resolve_panel_open_sign(hinge, viewer_position)
	hinge.is_open = not hinge.is_open
	var open_offset := OPEN_ANGLE_DEGREES * hinge.open_angle_sign if hinge.is_open else 0.0
	var target_transform := _compute_hinge_transform(hinge, open_offset)
	if hinge.tween:
		hinge.tween.kill()
	hinge.tween = create_tween()
	hinge.tween.set_trans(Tween.TRANS_SINE)
	hinge.tween.set_ease(Tween.EASE_OUT)
	hinge.tween.tween_property(hinge.pivot, "global_transform", target_transform, 0.18)

func _compute_hinge_transform(hinge: PanelHinge, angle_deg: float) -> Transform3D:
	var closed := hinge.closed_pivot_transform
	var axis := closed.basis.z.normalized()
	var rotated_basis := Basis(axis, deg_to_rad(angle_deg)) * closed.basis
	return Transform3D(rotated_basis, closed.origin)

func _resolve_panel_open_sign(hinge: PanelHinge, viewer_position: Variant) -> float:
	var viewer_global :Variant= _get_viewer_position(viewer_position)
	if not hinge.panel_root:
		return hinge.default_sign
	var free_closed := _get_free_edge_global(hinge, 0.0)
	var viewer_dir := Vector3.ZERO
	if viewer_global is Vector3:
		viewer_dir = (viewer_global as Vector3) - free_closed
		viewer_dir.y = 0.0
	var frame_pos := _get_frame_reference_position()
	var score_positive := _score_open_sign(hinge, 1.0, free_closed, viewer_dir, frame_pos)
	var score_negative := _score_open_sign(hinge, -1.0, free_closed, viewer_dir, frame_pos)
	if viewer_dir.length_squared() < 0.0001:
		return hinge.default_sign
	return 1.0 if score_positive >= score_negative else -1.0

func _score_open_sign(hinge: PanelHinge, open_sign: float, free_closed: Vector3, viewer_dir: Vector3, frame_pos: Vector3) -> float:
	var free_open := _get_free_edge_global(hinge, OPEN_ANGLE_DEGREES * open_sign)
	var delta := free_open - free_closed
	delta.y = 0.0
	var score := (free_open.distance_squared_to(frame_pos) - free_closed.distance_squared_to(frame_pos)) * 3.0
	if viewer_dir.length_squared() > 0.0001:
		score += delta.normalized().dot(viewer_dir.normalized()) * 2.0
	return score

func _get_frame_reference_position() -> Vector3:
	var frame_mesh := _find_frame_mesh()
	if frame_mesh:
		return frame_mesh.global_position
	return global_position

func _get_free_edge_local(hinge: PanelHinge) -> Vector3:
	var bounds := _compute_panel_local_aabb(hinge.panel_root)
	if bounds.size.length_squared() < 0.0001:
		return hinge.hinge_edge_local
	var y_mid := bounds.position.y + bounds.size.y * 0.5
	var z_mid := bounds.position.z + bounds.size.z * 0.5
	if hinge.hinge_edge_local.length_squared() < 0.0001:
		return _pick_free_edge_local(hinge.panel_root, bounds, y_mid, z_mid)
	var x_min := bounds.position.x
	var x_max := bounds.position.x + bounds.size.x
	if absf(hinge.hinge_edge_local.x - x_max) <= absf(hinge.hinge_edge_local.x - x_min):
		return Vector3(x_min, y_mid, z_mid)
	return Vector3(x_max, y_mid, z_mid)

func _pick_free_edge_local(panel_root: Node3D, bounds: AABB, y_mid: float, z_mid: float) -> Vector3:
	var x_min := bounds.position.x
	var x_max := bounds.position.x + bounds.size.x
	var left_edge := Vector3(x_min, y_mid, z_mid)
	var right_edge := Vector3(x_max, y_mid, z_mid)
	var frame_mesh := _find_frame_mesh()
	if not frame_mesh:
		return right_edge
	var frame_pos := frame_mesh.global_position
	var left_global: Vector3 = panel_root.global_transform * left_edge
	var right_global: Vector3 = panel_root.global_transform * right_edge
	if left_global.distance_squared_to(frame_pos) >= right_global.distance_squared_to(frame_pos):
		return left_edge
	return right_edge

func _get_free_edge_global(hinge: PanelHinge, angle_deg: float) -> Vector3:
	if not hinge.pivot or not hinge.panel_root:
		return global_position
	var closed := hinge.closed_pivot_transform
	var hinge_global := closed.origin
	var free_global_closed := hinge.panel_root.global_transform * _get_free_edge_local(hinge)
	var arm := free_global_closed - hinge_global
	if is_zero_approx(angle_deg):
		return free_global_closed
	var axis := closed.basis.z.normalized()
	return hinge_global + Basis(axis, deg_to_rad(angle_deg)) * arm

func _get_hinge_pivot_local(panel_root: Node3D, reference_mesh: MeshInstance3D) -> Vector3:
	var hinge_marker := _find_panel_hinge_marker(panel_root)
	if hinge_marker:
		if hinge_marker == panel_root:
			return Vector3.ZERO
		return panel_root.global_transform.affine_inverse() * hinge_marker.global_position
	var bounds := _compute_panel_local_aabb(panel_root)
	if bounds.size.length_squared() < 0.0001:
		return _get_hinge_pivot_local_from_mesh(reference_mesh)
	var x_min := bounds.position.x
	var x_max := bounds.position.x + bounds.size.x
	var y_base := bounds.position.y
	var z_mid := bounds.position.z + bounds.size.z * 0.5
	var left_edge := Vector3(x_min, y_base, z_mid)
	var right_edge := Vector3(x_max, y_base, z_mid)
	return _pick_hinge_edge_closest_to_frame(panel_root, left_edge, right_edge)

func _find_panel_hinge_marker(panel_root: Node3D) -> Node3D:
	var part_name := _normalize_part_name(panel_root.name)
	if part_name.begins_with("dummy"):
		return panel_root
	for node in _collect_named_nodes(panel_root):
		if node is Node3D:
			var node_name := _normalize_part_name(node.name)
			if node_name.begins_with("dummy"):
				return node as Node3D
	return null

func _pick_hinge_edge_closest_to_frame(panel_root: Node3D, left_edge: Vector3, right_edge: Vector3) -> Vector3:
	var frame_mesh := _find_frame_mesh()
	if not frame_mesh:
		return right_edge
	var frame_pos := frame_mesh.global_position
	var left_global: Vector3 = panel_root.global_transform * left_edge
	var right_global: Vector3 = panel_root.global_transform * right_edge
	if left_global.distance_squared_to(frame_pos) <= right_global.distance_squared_to(frame_pos):
		return left_edge
	return right_edge

func _get_hinge_pivot_local_from_mesh(mesh_instance: MeshInstance3D) -> Vector3:
	if not mesh_instance.mesh:
		return Vector3.ZERO
	var aabb := mesh_instance.mesh.get_aabb()
	return Vector3(
		aabb.position.x + aabb.size.x,
		aabb.position.y,
		aabb.position.z + aabb.size.z * 0.5
	)

func _compute_panel_local_aabb(panel_root: Node3D) -> AABB:
	var panel_inv := panel_root.global_transform.affine_inverse()
	var bounds := AABB()
	var has_bounds := false
	for mesh_instance in _collect_mesh_instances(panel_root):
		if not mesh_instance.mesh:
			continue
		var mesh_bounds := mesh_instance.mesh.get_aabb()
		for x in [0.0, mesh_bounds.size.x]:
			for y in [0.0, mesh_bounds.size.y]:
				for z in [0.0, mesh_bounds.size.z]:
					var corner_global := mesh_instance.global_transform * (mesh_bounds.position + Vector3(x, y, z))
					var corner_local: Vector3 = panel_inv * corner_global
					if has_bounds:
						bounds = bounds.expand(corner_local)
					else:
						bounds = AABB(corner_local, Vector3.ZERO)
						has_bounds = true
	return bounds if has_bounds else AABB()

func _find_frame_mesh() -> MeshInstance3D:
	for mesh_instance in _collect_mesh_instances(model_root):
		if _mesh_is_frame(mesh_instance):
			return mesh_instance
	return null

func _clear_panel_hinges() -> void:
	for hinge in panel_hinges:
		if hinge.tween:
			hinge.tween.kill()
		_remove_panel_physics(hinge)
		_restore_mesh_from_hinge(hinge)
	panel_hinges.clear()

func _restore_mesh_from_hinge(hinge: PanelHinge) -> void:
	var panel_root := hinge.panel_root
	var pivot := hinge.pivot
	if not pivot or not is_instance_valid(pivot):
		return
	if panel_root and is_instance_valid(panel_root) and panel_root.get_parent() == pivot:
		var restore_parent := pivot.get_parent()
		if restore_parent:
			var preserved_global := panel_root.global_transform
			pivot.remove_child(panel_root)
			restore_parent.add_child(panel_root)
			panel_root.global_transform = preserved_global
	pivot.queue_free()

func _refresh_door_physics_state() -> void:
	if _is_door_open_for_collision():
		_apply_open_door_physics()
	else:
		_apply_closed_door_physics()

func _is_door_open_for_collision() -> bool:
	for hinge in panel_hinges:
		if hinge.is_open:
			return true
	return is_open

func _apply_open_door_physics() -> void:
	collision_layer = PICK_COLLISION_LAYER
	collision_mask = 0
	input_ray_pickable = true
	if collision_shape:
		collision_shape.disabled = false
		_apply_collision_bounds(_compute_local_model_aabb())
	_set_all_panel_physics_solid(false)
	_set_host_wall_blocking(false)

func _apply_closed_door_physics() -> void:
	collision_layer = SOLID_COLLISION_LAYER
	collision_mask = SOLID_COLLISION_LAYER
	input_ray_pickable = true
	_fit_collision_to_model()
	_set_all_panel_physics_solid(true)
	_set_host_wall_blocking(true)

func _set_all_panel_physics_solid(solid: bool) -> void:
	for hinge in panel_hinges:
		if not hinge.panel_physics or not is_instance_valid(hinge.panel_physics):
			continue
		hinge.panel_physics.collision_layer = SOLID_COLLISION_LAYER if solid else 0
		hinge.panel_physics.collision_mask = SOLID_COLLISION_LAYER if solid else 0
		for child in hinge.panel_physics.get_children():
			if child is CollisionShape3D:
				(child as CollisionShape3D).disabled = not solid

func _fit_collision_to_model() -> void:
	if not collision_shape:
		return
	var local_bounds := _compute_frame_local_aabb()
	if local_bounds.size.length_squared() < 0.0001:
		local_bounds = _compute_non_panel_local_aabb()
	if local_bounds.size.length_squared() < 0.0001:
		local_bounds = _compute_local_model_aabb()
	_apply_collision_bounds(local_bounds)

func _apply_collision_bounds(local_bounds: AABB) -> void:
	if not collision_shape:
		return
	if local_bounds.size.length_squared() < 0.0001:
		var fallback := BoxShape3D.new()
		fallback.size = Vector3(1.0, 2.0, 0.2)
		collision_shape.shape = fallback
		collision_shape.position = Vector3(0.0, 1.0, 0.0)
		return
	var box := BoxShape3D.new()
	box.size = local_bounds.size
	collision_shape.shape = box
	collision_shape.position = local_bounds.get_center()

func _resolve_host_wall() -> StaticBody3D:
	if _host_wall and is_instance_valid(_host_wall):
		return _host_wall
	if has_meta("host_wall_path"):
		var scene_root := get_tree().current_scene
		if scene_root:
			_host_wall = scene_root.get_node_or_null(get_meta("host_wall_path")) as StaticBody3D
	if not _host_wall and has_meta("host_wall_position") and get_meta("host_wall_position") is Dictionary:
		_host_wall = _find_host_wall_by_position(_dict_to_vec3(get_meta("host_wall_position")))
	if not _host_wall:
		_host_wall = _find_overlapping_host_wall()
	return _host_wall

func _find_host_wall_by_position(target: Vector3) -> StaticBody3D:
	var scene_root := get_tree().current_scene
	if not scene_root:
		return null
	var best: StaticBody3D = null
	var best_distance_sq := INF
	const MAX_MATCH_DISTANCE_SQ := 0.75 * 0.75
	for child in scene_root.get_children():
		if not child is StaticBody3D:
			continue
		var body := child as StaticBody3D
		if body.scene_file_path != HOST_WALL_SCENE:
			continue
		var distance_sq := body.global_position.distance_squared_to(target)
		if distance_sq <= MAX_MATCH_DISTANCE_SQ and distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best = body
	return best

func _set_host_wall_blocking(blocking: bool) -> void:
	var wall := _resolve_host_wall()
	if not wall:
		return
	var shape := wall.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape:
		shape.disabled = not blocking
		return
	wall.collision_layer = SOLID_COLLISION_LAYER if blocking else 0
	wall.collision_mask = SOLID_COLLISION_LAYER if blocking else 0

func _find_overlapping_host_wall() -> StaticBody3D:
	var scene_root := get_tree().current_scene
	if not scene_root:
		return null
	var door_aabb := _compute_world_model_aabb().grow(0.12)
	var best: StaticBody3D = null
	var best_overlap := 0.0
	for child in scene_root.get_children():
		if not child is StaticBody3D:
			continue
		var body := child as StaticBody3D
		if body == self or body.scene_file_path != HOST_WALL_SCENE:
			continue
		var wall_aabb := _get_static_body_world_aabb(body)
		if wall_aabb.size.length_squared() < 0.0001:
			continue
		var overlap := door_aabb.intersection(wall_aabb)
		var overlap_score := overlap.size.length_squared()
		if overlap_score > best_overlap:
			best_overlap = overlap_score
			best = body
	return best if best_overlap > 0.0001 else null

func _get_static_body_world_aabb(body: StaticBody3D) -> AABB:
	var shape_node := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node and shape_node.shape is BoxShape3D:
		var box := shape_node.shape as BoxShape3D
		var local := AABB(-box.size * 0.5, box.size)
		var result := AABB()
		var has_point := false
		for x in [0.0, local.size.x]:
			for y in [0.0, local.size.y]:
				for z in [0.0, local.size.z]:
					var world_point := shape_node.global_transform * (local.position + Vector3(x, y, z))
					if has_point:
						result = result.expand(world_point)
					else:
						result = AABB(world_point, Vector3.ZERO)
						has_point = true
		return result if has_point else AABB()
	return AABB(body.global_position, Vector3.ZERO).grow(0.5)

func _compute_world_model_aabb() -> AABB:
	var local_bounds := _compute_local_model_aabb()
	if local_bounds.size.length_squared() < 0.0001:
		return AABB(global_position - Vector3(0.5, 1.0, 0.1), Vector3(1.0, 2.0, 0.2))
	var result := AABB()
	var has_point := false
	for x in [0.0, local_bounds.size.x]:
		for y in [0.0, local_bounds.size.y]:
			for z in [0.0, local_bounds.size.z]:
				var world_point := global_transform * (local_bounds.position + Vector3(x, y, z))
				if has_point:
					result = result.expand(world_point)
				else:
					result = AABB(world_point, Vector3.ZERO)
					has_point = true
	return result

func _compute_frame_local_aabb() -> AABB:
	var bounds := AABB()
	var has_bounds := false
	for mesh_instance in _collect_mesh_instances(model_root):
		if not mesh_instance.mesh or not _mesh_is_frame(mesh_instance):
			continue
		var mesh_bounds := _transform_aabb_to_local(mesh_instance.mesh.get_aabb(), mesh_instance.global_transform, global_transform)
		if has_bounds:
			bounds = bounds.merge(mesh_bounds)
		else:
			bounds = mesh_bounds
			has_bounds = true
	return bounds if has_bounds else AABB()

func _compute_non_panel_local_aabb() -> AABB:
	var bounds := AABB()
	var has_bounds := false
	for mesh_instance in _collect_mesh_instances(self):
		if not mesh_instance.mesh or _mesh_is_panel(mesh_instance) or _is_mesh_under_panel_hinge(mesh_instance):
			continue
		var mesh_bounds := _transform_aabb_to_local(mesh_instance.mesh.get_aabb(), mesh_instance.global_transform, global_transform)
		if has_bounds:
			bounds = bounds.merge(mesh_bounds)
		else:
			bounds = mesh_bounds
			has_bounds = true
	return bounds if has_bounds else AABB()

func _is_mesh_under_panel_hinge(mesh_instance: MeshInstance3D) -> bool:
	var current := mesh_instance.get_parent()
	while current and current != self:
		if str(current.name).ends_with("_hinge_pivot"):
			return true
		current = current.get_parent()
	return false

func _compute_local_model_aabb() -> AABB:
	var bounds := AABB()
	var has_bounds := false
	for mesh_instance in _collect_mesh_instances(self):
		if not mesh_instance.mesh:
			continue
		var mesh_bounds := _transform_aabb_to_local(mesh_instance.mesh.get_aabb(), mesh_instance.global_transform, global_transform)
		if has_bounds:
			bounds = bounds.merge(mesh_bounds)
		else:
			bounds = mesh_bounds
			has_bounds = true
	return bounds if has_bounds else AABB()

func _transform_aabb_to_local(source: AABB, source_xform: Transform3D, reference_xform: Transform3D) -> AABB:
	var reference_inv := reference_xform.affine_inverse()
	var result := AABB(reference_inv * source_xform * source.position, Vector3.ZERO)
	for x in [0.0, source.size.x]:
		for y in [0.0, source.size.y]:
			for z in [0.0, source.size.z]:
				var corner := reference_inv * source_xform * (source.position + Vector3(x, y, z))
				result = result.expand(corner)
	return result

func _collect_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances_recursive(node, meshes)
	return meshes

func _collect_mesh_instances_recursive(node: Node, out_meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		out_meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		if child is Node3D and str(child.name).ends_with("_hinge_pivot"):
			_collect_mesh_instances_recursive(child, out_meshes)
			continue
		_collect_mesh_instances_recursive(child, out_meshes)

func _collect_mesh_label_list(node: Node) -> Array[String]:
	var labels: Array[String] = []
	for child in _collect_named_nodes(node):
		labels.append("%s(%s)" % [child.name, _node_part_label(child)])
	return labels

func _collect_named_nodes(node: Node) -> Array[Node]:
	var nodes: Array[Node] = []
	_collect_named_nodes_recursive(node, nodes)
	return nodes

func _collect_named_nodes_recursive(node: Node, out_nodes: Array[Node]) -> void:
	if node != model_root and node != self and node is Node3D:
		out_nodes.append(node)
	for child in node.get_children():
		if str(child.name).ends_with("_hinge_pivot"):
			continue
		_collect_named_nodes_recursive(child, out_nodes)

func _node_part_label(node: Node) -> String:
	if node is MeshInstance3D:
		return _mesh_part_name(node as MeshInstance3D)
	return _normalize_part_name(node.name)

func _node_part_names(node: Node) -> Array[String]:
	var names: Array[String] = []
	var current: Node = node
	while current and current != model_root and current != self:
		names.append(_normalize_part_name(current.name))
		if current is MeshInstance3D:
			var mesh_instance := current as MeshInstance3D
			if mesh_instance.mesh and mesh_instance.mesh.resource_name.strip_edges() != "":
				names.append(_normalize_part_name(mesh_instance.mesh.resource_name))
		current = current.get_parent()
	return names

func _node_is_frame(node: Node3D) -> bool:
	for part_name in _node_part_names(node):
		if _name_matches_part(part_name, _get_frame_names()):
			return true
	return false

func _node_is_panel(node: Node3D) -> bool:
	for part_name in _node_part_names(node):
		if _name_matches_part(part_name, _get_panel_names()):
			return true
	return false

func _mesh_part_name(mesh_instance: MeshInstance3D) -> String:
	var normalized := _normalize_part_name(mesh_instance.name)
	if mesh_instance.mesh and mesh_instance.mesh.resource_name.strip_edges() != "":
		var mesh_name := _normalize_part_name(mesh_instance.mesh.resource_name)
		if mesh_name.begins_with("box") or mesh_name.begins_with("dummy"):
			return mesh_name
	return normalized

func _get_panel_names() -> PackedStringArray:
	if not panel_node_names.is_empty():
		return panel_node_names
	if door_variant_id == "double":
		return PackedStringArray(DEFAULT_DOUBLE_PANEL_NAMES)
	return PackedStringArray(DEFAULT_SINGLE_PANEL_NAMES)

func _get_frame_names() -> PackedStringArray:
	if not frame_node_names.is_empty():
		return frame_node_names
	return PackedStringArray(DEFAULT_FRAME_NAMES)

func _normalize_part_name(node_name: String) -> String:
	var normalized := node_name.to_lower().strip_edges()
	var cut := normalized.find("_")
	if cut > 0:
		normalized = normalized.substr(0, cut)
	return normalized

func _name_matches_part(node_name: String, candidates: PackedStringArray) -> bool:
	var normalized := _normalize_part_name(node_name)
	for candidate in candidates:
		var target := _normalize_part_name(candidate)
		if normalized == target or normalized.ends_with(target) or normalized.find(target) >= 0:
			return true
	return false

func _mesh_is_frame(mesh_instance: MeshInstance3D) -> bool:
	return _node_is_frame(mesh_instance) or _name_matches_part(_mesh_part_name(mesh_instance), _get_frame_names())

func _mesh_is_panel(mesh_instance: MeshInstance3D) -> bool:
	return _node_is_panel(mesh_instance) or _name_matches_part(_mesh_part_name(mesh_instance), _get_panel_names())

func _capture_closed_transform() -> void:
	if has_closed_transform:
		return
	closed_transform = global_transform
	has_closed_transform = true

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
			"z": {"x": xform.basis.z.x, "y": xform.basis.z.y, "z": xform.basis.z.z},
		},
	}

func _dict_to_transform(data: Dictionary) -> Transform3D:
	return Transform3D(_dict_to_basis(data.get("basis", {})), _dict_to_vec3(data.get("position", {})))

func _dict_to_vec3(data: Dictionary) -> Vector3:
	return Vector3(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("z", 0.0)))

func _dict_to_basis(data: Dictionary) -> Basis:
	return Basis(_dict_to_vec3(data.get("x", {})), _dict_to_vec3(data.get("y", {})), _dict_to_vec3(data.get("z", {})))
