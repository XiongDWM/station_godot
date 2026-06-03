extends RefCounted

class_name BuildingController
const WALL_SCENE_PATH := "res://wall_object.tscn"
const DOOR_SCENE_PATH := "res://door_object.tscn"
const ODF_SCENE_PATH := "res://odf_object.tscn"
const RACK_SCENE_PATH := "res://rack_object.tscn"
const PIPE_PREVIEW_MIN_LENGTH := 0.2
const SURFACE_SNAP_MARGIN := 0.02
const PREVIEW_VALID_COLOR := Color(0.0, 0.654902, 0.0, 0.38431373)
const PREVIEW_INVALID_COLOR := Color(0.88, 0.12, 0.12, 0.48)
const PIPE_LAYER_Y := {
	-1: -1.0,
	0: 0.0,
	1: 2.0,
}

var current_building := {
	"scene": null,
	"preview": null,
	"is_active": false,
	"placement_mode": "point",
	"view_layer": 0,
	"line_start_point": null,
	"wall_edge_index": 0,
	"wall_edge_manual": false,
	"wall_rotation_degrees": 0.0,
	"base_preview_yaw": 0.0,
	"point_cell_size": Vector3.ONE,
	"collision_size": Vector3.ZERO,
	"is_placeable": true,
	"surface_snap_target": null,
}

func initialize(preview_cube: MeshInstance3D, preview_wall: MeshInstance3D, preview_pipe: MeshInstance3D, preview_rack: MeshInstance3D = null) -> void:
	_prepare_preview_material(preview_cube)
	_prepare_preview_material(preview_wall)
	_prepare_preview_material(preview_rack)
	if preview_cube:
		preview_cube.visible = false
	if preview_wall:
		preview_wall.visible = false
	if preview_pipe:
		preview_pipe.visible = false
	if preview_rack:
		preview_rack.visible = false


func bind_buttons(btn_cube: Button, btn_rack: Button, btn_wall: Button, btn_door: Button, btn_pipe: Button, block_scene: PackedScene, rack_scene: PackedScene, wall_scene: PackedScene, door_scene: PackedScene, pipe_scene: PackedScene, preview_cube: MeshInstance3D, preview_rack: MeshInstance3D, preview_wall: MeshInstance3D, preview_pipe: MeshInstance3D, target: Object, method: StringName) -> void:
	if btn_cube:
		btn_cube.pressed.connect(Callable(target, method).bind(block_scene, preview_cube, "point"))
	if btn_rack:
		btn_rack.pressed.connect(Callable(target, method).bind(rack_scene, preview_rack, "point"))
	if btn_wall:
		btn_wall.pressed.connect(Callable(target, method).bind(wall_scene, preview_wall, "point"))
	if btn_door:
		btn_door.pressed.connect(Callable(target, method).bind(door_scene, preview_wall, "point"))
	if btn_pipe:
		btn_pipe.pressed.connect(Callable(target, method).bind(pipe_scene, preview_pipe, "line"))

func set_building_mode(scene: PackedScene, preview: MeshInstance3D, operation_panel: Control, module_panel: Control, placement_mode: String = "point") -> void:
	var normalized_mode := _normalize_placement_mode(scene, placement_mode)
	if current_building["scene"] == scene and current_building["is_active"] and current_building["placement_mode"] == normalized_mode:
		cancel_build_mode()
		print("退出建造模式")
	else:
		_reset_line_preview()
		current_building["scene"] = scene
		current_building["preview"] = preview
		current_building["is_active"] = true
		current_building["placement_mode"] = normalized_mode
		current_building["wall_edge_index"] = 0
		current_building["wall_edge_manual"] = false
		current_building["wall_rotation_degrees"] = 0.0
		current_building["base_preview_yaw"] = preview.rotation.y if preview else 0.0
		current_building["point_cell_size"] = Vector3.ONE
		current_building["collision_size"] = _get_scene_collision_box_size(scene)
		current_building["is_placeable"] = true
		current_building["surface_snap_target"] = null
		if operation_panel:
			operation_panel.visible = false
		if module_panel:
			if module_panel.has_method("close_for_current_target"):
				module_panel.call("close_for_current_target")
			else:
				module_panel.visible = false
		print("进入建造模式: ", scene.resource_path)
	_apply_preview_fit()
	update_ui()

func _normalize_placement_mode(scene: PackedScene, placement_mode: String) -> String:
	if scene and scene.resource_path == WALL_SCENE_PATH:
		return "point"
	return placement_mode

func update_ui() -> void:
	var preview = current_building["preview"]
	if preview and preview is MeshInstance3D:
		preview.visible = current_building["is_active"] and current_building["placement_mode"] == "point"
		_apply_preview_fit()

func is_active() -> bool:
	return current_building["is_active"]

func get_preview() -> MeshInstance3D:
	return current_building["preview"]

func get_placement_mode() -> String:
	return str(current_building.get("placement_mode", "point"))

func set_active_view_layer(layer: int) -> void:
	current_building["view_layer"] = layer
	if get_placement_mode() == "line":
		_reset_line_preview()

func cancel_build_mode() -> void:
	var preview = current_building.get("preview") as MeshInstance3D
	if preview:
		preview.visible = false
	current_building["is_active"] = false
	current_building["scene"] = null
	current_building["preview"] = null
	current_building["placement_mode"] = "point"
	current_building["wall_edge_index"] = 0
	current_building["wall_edge_manual"] = false
	current_building["wall_rotation_degrees"] = 0.0
	current_building["base_preview_yaw"] = 0.0
	current_building["point_cell_size"] = Vector3.ONE
	current_building["collision_size"] = Vector3.ZERO
	current_building["is_placeable"] = true
	current_building["surface_snap_target"] = null
	_reset_line_preview()

func handle_preview_logic(root: Node3D, grid_map: GridMap) -> void:
	if get_placement_mode() == "line":
		_handle_line_preview_logic(root, grid_map)
		return
	if not grid_map:
		return
	var camera = root.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if not camera:
		return
	var mouse_pos = root.get_viewport().get_mouse_position()
	var cursor_point: Vector3
	var hit_result := {}
	if _uses_edge_snap():
		var floor_point : Variant = _intersect_point_build_plane(camera, mouse_pos, grid_map)
		if floor_point == null:
			var preview_mesh = current_building["preview"] as MeshInstance3D
			if preview_mesh:
				preview_mesh.visible = false
			return
		cursor_point = floor_point
	else:
		var space_state = root.get_world_3d().direct_space_state
		var from = camera.project_ray_origin(mouse_pos)
		var to = from + camera.project_ray_normal(mouse_pos) * 100.0
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result := space_state.intersect_ray(query)
		if result.is_empty():
			var preview_mesh = current_building["preview"] as MeshInstance3D
			if preview_mesh:
				preview_mesh.visible = false
			return
		hit_result = result
		cursor_point = result.position

	var cell_size = grid_map.cell_size
	var hit_pos = cursor_point
	var local_pos = grid_map.to_local(hit_pos)
	current_building["point_cell_size"] = cell_size

	var preview_mesh = current_building["preview"] as MeshInstance3D
	if not preview_mesh or not preview_mesh.mesh:
		return
	var size_after_scale = _get_current_building_size(preview_mesh)
	var y_offset = size_after_scale.y / 2
	current_building["surface_snap_target"] = null

	var final_pos: Vector3
	var surface_snap_points: Array[Vector3] = []
	if _uses_surface_snap() and _try_get_surface_snap_position(hit_result, preview_mesh, size_after_scale, grid_map, surface_snap_points):
		final_pos = surface_snap_points[0]
	else:
		var map_coord = Vector3i(
			floor(local_pos.x / cell_size.x),
			floor(local_pos.y / cell_size.y),
			floor(local_pos.z / cell_size.z)
		)
		final_pos = grid_map.map_to_local(map_coord)
		final_pos.y = _get_floor_top_y(grid_map) + y_offset
		if not _uses_edge_snap():
			_apply_point_preview_orientation(preview_mesh)
		if _uses_edge_snap():
			var edge_index := _resolve_wall_edge_index(local_pos, final_pos, cell_size)
			current_building["wall_edge_index"] = edge_index
			if not _should_center_wall_on_cell():
				final_pos += _get_wall_edge_offset(cell_size, edge_index, size_after_scale.z)

	preview_mesh.global_position = final_pos
	if _uses_edge_snap():
		_apply_wall_preview_orientation(preview_mesh)
	var is_placeable := _is_preview_placeable(root, preview_mesh)
	current_building["is_placeable"] = is_placeable
	_set_preview_validity(preview_mesh, is_placeable)
	preview_mesh.visible = true
	_apply_preview_fit()

func _handle_line_preview_logic(root: Node3D, grid_map: GridMap) -> void:
	var preview_mesh := current_building["preview"] as MeshInstance3D
	if not preview_mesh:
		return
	var cursor_points: Array[Vector3] = []
	if not _try_get_line_cursor_position(root, grid_map, cursor_points):
		preview_mesh.visible = false
		return
	var start_point: Variant = current_building.get("line_start_point")
	if start_point == null:
		preview_mesh.visible = false
		return
	var start_vec := start_point as Vector3
	var end_vec := cursor_points[0]
	if start_vec.distance_to(end_vec) < 0.05:
		end_vec.x += PIPE_PREVIEW_MIN_LENGTH
	_update_line_preview(preview_mesh, start_vec, end_vec)

func handle_unhandled_input(root: Node, event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and event.keycode == Key.KEY_ESCAPE and current_building["is_active"]:
		cancel_build_mode()
		update_ui()
		print("退出建造")
		root.get_viewport().set_input_as_handled()
		return true

	if get_placement_mode() == "line":
		return false

	if event is InputEventKey and event.pressed == false and current_building["is_active"] and current_building["preview"]:
		var preview_mesh = current_building["preview"] as Node3D
		if _uses_edge_snap():
			if event.keycode == Key.KEY_UP:
				_cycle_wall_edge(-1)
				_apply_wall_preview_orientation(preview_mesh)
				_apply_preview_fit()
				root.get_viewport().set_input_as_handled()
				return true
			if event.keycode == Key.KEY_DOWN:
				_cycle_wall_edge(1)
				_apply_wall_preview_orientation(preview_mesh)
				_apply_preview_fit()
				root.get_viewport().set_input_as_handled()
				return true
		if event.keycode == Key.KEY_LEFT:
			if _uses_edge_snap():
				current_building["wall_rotation_degrees"] = float(current_building.get("wall_rotation_degrees", 0.0)) + 45.0
				_apply_wall_preview_orientation(preview_mesh)
			else:
				current_building["wall_rotation_degrees"] = float(current_building.get("wall_rotation_degrees", 0.0)) + 90.0
				_apply_point_preview_orientation(preview_mesh)
			_apply_preview_fit()
			root.get_viewport().set_input_as_handled()
			return true
		if event.keycode == Key.KEY_RIGHT:
			if _uses_edge_snap():
				current_building["wall_rotation_degrees"] = float(current_building.get("wall_rotation_degrees", 0.0)) - 45.0
				_apply_wall_preview_orientation(preview_mesh)
			else:
				current_building["wall_rotation_degrees"] = float(current_building.get("wall_rotation_degrees", 0.0)) - 90.0
				_apply_point_preview_orientation(preview_mesh)
			_apply_preview_fit()
			root.get_viewport().set_input_as_handled()
			return true

	return false

func place_current_building(root: Node3D, grid_map: GridMap) -> void:
	if get_placement_mode() == "line":
		_place_or_update_line_building(root, grid_map)
		return
	var scene_to_spawn = current_building["scene"] as PackedScene
	var preview_node = current_building["preview"] as Node3D
	if not scene_to_spawn or not preview_node:
		return
	if not bool(current_building.get("is_placeable", true)):
		return
	var new_building = scene_to_spawn.instantiate()
	if new_building is Node and _uses_edge_snap():
		(new_building as Node).set_meta("logical_length_scale", _get_wall_length_scale(grid_map.cell_size))
	root.add_child(new_building)
	new_building.global_transform = preview_node.global_transform
	if new_building is Node:
		(new_building as Node).set_meta("build_view_layer", int(current_building.get("view_layer", 0)))
		if new_building.has_method("refresh_diagonal_fit"):
			new_building.call("refresh_diagonal_fit")
	print("放置了: ", scene_to_spawn.resource_path)

func _apply_preview_fit() -> void:
	var preview = current_building["preview"] as Node3D
	if not preview or get_placement_mode() != "point" or not _should_apply_preview_fit():
		return
	if _uses_edge_snap():
		var point_cell_size = current_building.get("point_cell_size", Vector3.ONE) as Vector3
		preview.set_meta("diagonal_fit_base_scale", Vector3(_get_wall_length_scale(point_cell_size), 1.0, 1.0))
	else:
		preview.set_meta("diagonal_fit_base_scale", Vector3.ONE)
	DiagonalBuildingFit.apply_to_preview(preview, preview.global_transform.basis)

func _should_apply_preview_fit() -> bool:
	var scene := current_building["scene"] as PackedScene
	if not scene:
		return false
	return scene.resource_path == "res://wall_object.tscn" or scene.resource_path == "res://door_object.tscn"

func _uses_edge_snap() -> bool:
	var scene := current_building["scene"] as PackedScene
	if not scene:
		return false
	return scene.resource_path == WALL_SCENE_PATH or scene.resource_path == DOOR_SCENE_PATH

func _uses_surface_snap() -> bool:
	var scene := current_building["scene"] as PackedScene
	if not scene:
		return false
	return scene.resource_path == ODF_SCENE_PATH or scene.resource_path == RACK_SCENE_PATH

func _cycle_wall_edge(step: int) -> void:
	var current_index := int(current_building.get("wall_edge_index", 0))
	current_building["wall_edge_index"] = posmod(current_index + step, 4)
	current_building["wall_edge_manual"] = true

func _apply_wall_preview_orientation(preview: Node3D) -> void:
	if not preview:
		return
	var edge_index := int(current_building.get("wall_edge_index", 0))
	var rotation_offset := float(current_building.get("wall_rotation_degrees", 0.0))
	var base_yaw := _get_wall_edge_base_yaw(edge_index)
	preview.rotation = Vector3(0.0, deg_to_rad(base_yaw + rotation_offset), 0.0)

func _apply_point_preview_orientation(preview: Node3D) -> void:
	if not preview:
		return
	var base_yaw := float(current_building.get("base_preview_yaw", 0.0))
	var rotation_offset := deg_to_rad(float(current_building.get("wall_rotation_degrees", 0.0)))
	preview.rotation.y = base_yaw + rotation_offset

func _get_wall_edge_base_yaw(edge_index: int) -> float:
	match posmod(edge_index, 4):
		0:
			return 90.0
		1:
			return 0.0
		2:
			return 90.0
		_:
			return 0.0

func _resolve_wall_edge_index(local_pos: Vector3, cell_center: Vector3, cell_size: Vector3) -> int:
	if bool(current_building.get("wall_edge_manual", false)):
		return int(current_building.get("wall_edge_index", 0))
	var local_center := Vector3(cell_center.x, local_pos.y, cell_center.z)
	var offset := local_pos - local_center
	var half_x := maxf(cell_size.x * 0.5, 0.001)
	var half_z := maxf(cell_size.z * 0.5, 0.001)
	var normalized_x := offset.x / half_x
	var normalized_z := offset.z / half_z
	if absf(normalized_x) >= absf(normalized_z):
		return 0 if normalized_x >= 0.0 else 2
	return 1 if normalized_z >= 0.0 else 3

func _get_wall_edge_offset(cell_size: Vector3, edge_index: int, thickness: float) -> Vector3:
	var inset_x := maxf(cell_size.x * 0.5 - thickness * 0.5, 0.0)
	var inset_z := maxf(cell_size.z * 0.5 - thickness * 0.5, 0.0)
	match posmod(edge_index, 4):
		0:
			return Vector3(inset_x, 0.0, 0.0)
		1:
			return Vector3(0.0, 0.0, inset_z)
		2:
			return Vector3(-inset_x, 0.0, 0.0)
		_:
			return Vector3(0.0, 0.0, -inset_z)

func _get_wall_length_scale(cell_size: Vector3) -> float:
	return maxf(cell_size.x, cell_size.z)

func _intersect_point_build_plane(camera: Camera3D, mouse_pos: Vector2, grid_map: GridMap) -> Variant:
	if not camera or not grid_map:
		return null
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	var plane := Plane(Vector3.UP, grid_map.global_position.y)
	return plane.intersects_ray(ray_origin, ray_direction)

func _get_current_building_size(preview_mesh: MeshInstance3D) -> Vector3:
	if not preview_mesh:
		return Vector3.ZERO
	var collision_size := current_building.get("collision_size", Vector3.ZERO) as Vector3
	if collision_size != Vector3.ZERO:
		var preview_scale := preview_mesh.global_transform.basis.get_scale().abs()
		return Vector3(
			collision_size.x * preview_scale.x,
			collision_size.y * preview_scale.y,
			collision_size.z * preview_scale.z
		)
	if not preview_mesh.mesh:
		return Vector3.ZERO
	var preview_size := preview_mesh.mesh.get_aabb().size
	return preview_size * preview_mesh.global_transform.basis.get_scale()

func _get_scene_collision_box_size(scene: PackedScene) -> Vector3:
	if not scene:
		return Vector3.ZERO
	var instance := scene.instantiate()
	if not instance:
		return Vector3.ZERO
	var collision_shape := _find_collision_shape(instance)
	var size := Vector3.ZERO
	if collision_shape and collision_shape.shape is BoxShape3D:
		size = (collision_shape.shape as BoxShape3D).size
	instance.free()
	return size

func _find_collision_shape(node: Node) -> CollisionShape3D:
	if node is CollisionShape3D:
		return node as CollisionShape3D
	for child in node.get_children():
		var found := _find_collision_shape(child)
		if found:
			return found
	return null

func _try_get_surface_snap_position(hit_result: Dictionary, preview: Node3D, size_after_scale: Vector3, grid_map: GridMap, out_points: Array[Vector3]) -> bool:
	if hit_result.is_empty() or not preview or not grid_map:
		return false
	var snap_target := _get_surface_snap_target_node(hit_result.get("collider"))
	if not snap_target:
		return false
	current_building["surface_snap_target"] = snap_target
	var hit_normal: Vector3 = hit_result.get("normal", Vector3.ZERO)
	var horizontal_normal := Vector3(hit_normal.x, 0.0, hit_normal.z)
	if horizontal_normal.length_squared() < 0.0001:
		return false
	horizontal_normal = horizontal_normal.normalized()
	var hit_position: Vector3 = hit_result.get("position", Vector3.ZERO)
	var half_size := size_after_scale * 0.5
	var manual_offset := deg_to_rad(float(current_building.get("wall_rotation_degrees", 0.0)))
	var snapped_yaw := _get_surface_snap_yaw(horizontal_normal, preview.rotation.y - manual_offset, half_size)
	snapped_yaw += manual_offset
	var preview_basis := Basis(Vector3.UP, snapped_yaw).orthonormalized()
	var support_extent := absf(horizontal_normal.dot(preview_basis.x)) * half_size.x + absf(horizontal_normal.dot(preview_basis.z)) * half_size.z
	var snap_position := hit_position + horizontal_normal * (support_extent + SURFACE_SNAP_MARGIN)
	snap_position.y = _get_floor_top_y(grid_map) + half_size.y
	preview.rotation.y = snapped_yaw
	out_points.clear()
	out_points.append(snap_position)
	return true

func _get_floor_top_y(grid_map: GridMap) -> float:
	if not grid_map:
		push_error("GridMap is null when calculating floor top Y")
		return 0.0
	return grid_map.global_position.y + grid_map.cell_size.y

func _prepare_preview_material(preview_mesh: MeshInstance3D) -> void:
	if not preview_mesh:
		return
	var existing_valid :Variant= preview_mesh.get_meta("preview_valid_material", null)
	if existing_valid is StandardMaterial3D:
		return
	var source_material: Material = preview_mesh.material_override
	if source_material == null and preview_mesh.mesh is PrimitiveMesh:
		source_material = (preview_mesh.mesh as PrimitiveMesh).material
	var valid_material := StandardMaterial3D.new()
	if source_material is StandardMaterial3D:
		valid_material = (source_material as StandardMaterial3D).duplicate(true)
	valid_material.albedo_color = PREVIEW_VALID_COLOR
	valid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var invalid_material := valid_material.duplicate(true) as StandardMaterial3D
	invalid_material.albedo_color = PREVIEW_INVALID_COLOR
	preview_mesh.set_meta("preview_valid_material", valid_material)
	preview_mesh.set_meta("preview_invalid_material", invalid_material)
	preview_mesh.material_override = valid_material

func _set_preview_validity(preview_mesh: MeshInstance3D, is_valid: bool) -> void:
	if not preview_mesh:
		return
	var material_key := "preview_valid_material" if is_valid else "preview_invalid_material"
	var material := preview_mesh.get_meta(material_key, null) as Material
	if material:
		preview_mesh.material_override = material

func _is_preview_placeable(root: Node3D, preview_mesh: MeshInstance3D) -> bool:
	if not root or not preview_mesh or not _should_block_overlap_for_current_scene():
		return true
	var preview_volume := _build_upright_overlap_volume(preview_mesh.global_position, preview_mesh.global_transform.basis, _get_current_building_size(preview_mesh))
	var ignored_target := current_building.get("surface_snap_target", null) as Node
	var current_scene := current_building["scene"] as PackedScene
	for child in root.get_children():
		if not _is_overlap_candidate(child):
			continue
		if ignored_target and child == ignored_target:
			continue
		if current_scene and current_scene.resource_path == WALL_SCENE_PATH and (child as Node3D).scene_file_path == WALL_SCENE_PATH:
			continue
		var child_node := child as Node3D
		var child_size := _get_node_collision_box_size(child_node)
		if child_size == Vector3.ZERO:
			continue
		var child_volume := _build_upright_overlap_volume(child_node.global_position, child_node.global_transform.basis, child_size)
		if _overlap_volumes_intersect(preview_volume, child_volume):
			return false
	return true

func _should_block_overlap_for_current_scene() -> bool:
	if get_placement_mode() != "point":
		return false
	var scene := current_building["scene"] as PackedScene
	if not scene:
		return false
	if scene.resource_path == DOOR_SCENE_PATH:
		return false
	return current_building.get("collision_size", Vector3.ZERO) != Vector3.ZERO

func _is_overlap_candidate(node: Node) -> bool:
	if not (node is Node3D):
		return false
	var node_3d := node as Node3D
	if not node_3d.visible:
		return false
	if node_3d.scene_file_path.is_empty():
		return false
	if node_3d.scene_file_path == DOOR_SCENE_PATH:
		return false
	return _get_node_collision_box_size(node_3d) != Vector3.ZERO

func _get_node_collision_box_size(node: Node) -> Vector3:
	var collision_shape := _find_collision_shape(node)
	if collision_shape and collision_shape.shape is BoxShape3D:
		return (collision_shape.shape as BoxShape3D).size
	return Vector3.ZERO

func _build_upright_overlap_volume(center: Vector3, basis: Basis, size: Vector3) -> Dictionary:
	var half := size.abs() * 0.5
	var axis_x := Vector2(basis.x.x, basis.x.z)
	if axis_x.length_squared() < 0.0001:
		axis_x = Vector2.RIGHT
	else:
		axis_x = axis_x.normalized()
	var axis_z := Vector2(basis.z.x, basis.z.z)
	if axis_z.length_squared() < 0.0001:
		axis_z = Vector2(0.0, 1.0)
	else:
		axis_z = axis_z.normalized()
	return {
		"center": Vector2(center.x, center.z),
		"axes": [axis_x, axis_z],
		"half_extents": Vector2(half.x, half.z),
		"min_y": center.y - half.y,
		"max_y": center.y + half.y,
	}

func _overlap_volumes_intersect(first: Dictionary, second: Dictionary) -> bool:
	if float(first.get("max_y", 0.0)) <= float(second.get("min_y", 0.0)):
		return false
	if float(first.get("min_y", 0.0)) >= float(second.get("max_y", 0.0)):
		return false
	var axes: Array[Vector2] = []
	for axis in first.get("axes", []):
		axes.append(axis)
	for axis in second.get("axes", []):
		axes.append(axis)
	for axis in axes:
		var normalized_axis := axis.normalized()
		if normalized_axis.length_squared() < 0.0001:
			continue
		var first_projection := _project_overlap_volume(first, normalized_axis)
		var second_projection := _project_overlap_volume(second, normalized_axis)
		if first_projection.y <= second_projection.x or second_projection.y <= first_projection.x:
			return false
	return true

func _project_overlap_volume(volume: Dictionary, axis: Vector2) -> Vector2:
	var center := volume.get("center", Vector2.ZERO) as Vector2
	var projected_center := center.dot(axis)
	var axes :Variant= volume.get("axes", [])
	var half_extents := volume.get("half_extents", Vector2.ZERO) as Vector2
	var radius := 0.0
	if axes.size() >= 2:
		radius = absf((axes[0] as Vector2).dot(axis)) * half_extents.x + absf((axes[1] as Vector2).dot(axis)) * half_extents.y
	return Vector2(projected_center - radius, projected_center + radius)


func _get_surface_snap_target_node(collider: Variant) -> Node3D:
	var target := collider as Node
	if not target:
		return null
	var current: Node = target
	while current:
		if current is Node3D and (current.scene_file_path == WALL_SCENE_PATH or current.scene_file_path == DOOR_SCENE_PATH):
			return current as Node3D
		current = current.get_parent()
	return null

func _get_surface_snap_yaw(surface_normal: Vector3, current_yaw: float, half_size: Vector3) -> float:
	if is_equal_approx(half_size.x, half_size.z):
		return current_yaw
	var facing_yaw := atan2(surface_normal.x, surface_normal.z)
	var candidates := [
		wrapf(facing_yaw, -PI, PI),
		wrapf(facing_yaw + PI, -PI, PI),
		wrapf(facing_yaw + PI * 0.5, -PI, PI),
		wrapf(facing_yaw - PI * 0.5, -PI, PI),
	]
	var best_yaw :Variant= candidates[0]
	var best_extent := -INF
	var best_delta := INF
	for candidate in candidates:
		var candidate_basis := Basis(Vector3.UP, candidate).orthonormalized()
		var extent := absf(surface_normal.dot(candidate_basis.x)) * half_size.x + absf(surface_normal.dot(candidate_basis.z)) * half_size.z
		var delta := absf(wrapf(candidate - current_yaw, -PI, PI))
		if extent > best_extent + 0.0001 or (is_equal_approx(extent, best_extent) and delta < best_delta):
			best_extent = extent
			best_delta = delta
			best_yaw = candidate
	return best_yaw

func _should_center_wall_on_cell() -> bool:
	var rotation_offset := float(current_building.get("wall_rotation_degrees", 0.0))
	var normalized := fposmod(rotation_offset, 90.0)
	return not is_zero_approx(normalized)

func _place_or_update_line_building(root: Node3D, grid_map: GridMap) -> void:
	var scene_to_spawn = current_building["scene"] as PackedScene
	if not scene_to_spawn:
		return
	var cursor_points: Array[Vector3] = []
	if not _try_get_line_cursor_position(root, grid_map, cursor_points):
		return
	var point := cursor_points[0]
	var start_point: Variant = current_building.get("line_start_point")
	if start_point == null:
		current_building["line_start_point"] = point
		return
	var start_vec := start_point as Vector3
	if start_vec.distance_to(point) < 0.05:
		return
	var new_building = scene_to_spawn.instantiate()
	root.add_child(new_building)
	if new_building is Node3D:
		_apply_line_segment(new_building as Node3D, start_vec, point)
	if new_building is Node:
		(new_building as Node).set_meta("build_view_layer", int(current_building.get("view_layer", 0)))
	current_building["line_start_point"] = null
	_reset_line_preview()
	print("放置了: ", scene_to_spawn.resource_path)

func _try_get_line_cursor_position(root: Node3D, grid_map: GridMap, out_points: Array[Vector3]) -> bool:
	var camera = root.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if not camera:
		return false
	var mouse_pos = root.get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	var plane_y := _get_current_layer_plane_y()
	var plane := Plane(Vector3.UP, plane_y)
	var hit: Variant = plane.intersects_ray(ray_origin, ray_direction)
	if hit == null:
		return false
	out_points.clear()
	out_points.append(_snap_line_point(hit as Vector3, grid_map))
	return true

func _snap_line_point(point: Vector3, grid_map: GridMap) -> Vector3:
	if not grid_map:
		return point
	var step_x := maxf(0.25, grid_map.cell_size.x * 0.5)
	var step_z := maxf(0.25, grid_map.cell_size.z * 0.5)
	return Vector3(
		round(point.x / step_x) * step_x,
		_get_current_layer_plane_y(),
		round(point.z / step_z) * step_z
	)

func _get_current_layer_plane_y() -> float:
	var layer := int(current_building.get("view_layer", 0))
	return float(PIPE_LAYER_Y.get(layer, PIPE_LAYER_Y[0]))

func _update_line_preview(preview_mesh: MeshInstance3D, start_point: Vector3, end_point: Vector3) -> void:
	_apply_line_segment(preview_mesh, start_point, end_point)
	preview_mesh.visible = true

func _apply_line_segment(target: Node3D, start_point: Vector3, end_point: Vector3) -> void:
	var plane_y := _get_current_layer_plane_y()
	var flat_start := Vector3(start_point.x, plane_y, start_point.z)
	var flat_end := Vector3(end_point.x, plane_y, end_point.z)
	var flat_segment := flat_end - flat_start
	var length := maxf(flat_segment.length(), PIPE_PREVIEW_MIN_LENGTH)
	var midpoint := flat_start + flat_segment * 0.5
	midpoint.y = plane_y
	var direction := flat_segment.normalized() if flat_segment.length() > 0.001 else Vector3.RIGHT
	target.global_position = midpoint
	target.look_at(midpoint + direction, Vector3.UP, true)
	target.rotate_object_local(Vector3.RIGHT, deg_to_rad(-90.0))
	target.scale = Vector3(1.0, length, 1.0)

func _reset_line_preview() -> void:
	current_building["line_start_point"] = null
	var preview = current_building.get("preview") as MeshInstance3D
	if preview:
		preview.visible = false
