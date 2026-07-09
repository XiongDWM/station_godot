extends RefCounted

class_name BuildingController
const CellLinePlacementScript := preload("res://scripts/controllers/cell_line_placement.gd")
const FLOOR_SCENE_PATH := "res://floor_brick.tscn"
const WALL_SCENE_PATH := "res://wall_object.tscn"
const DOOR_SCENE_PATH := "res://door_object.tscn"
const ODF_SCENE_PATH := "res://odf_object.tscn"
const RACK_SCENE_PATH := "res://rack_object.tscn"
const TRENCH_SCENE_PATH := "res://trench_object.tscn"
const CEILING_TRAY_SCENE_PATH := "res://ceiling_tray_object.tscn"
const PIPELINE_SCENE_PATH := "res://pipeline_object.tscn"
const PIPE_DEFAULT_RADIUS := 0.1
const COLLISION_BOX_SIZE_META := "collision_box_size"
const PIPE_PREVIEW_MIN_LENGTH := 0.2
const SURFACE_SNAP_MARGIN := 0.02
const MEZZANINE_AIR_WALL_RUNTIME_LAYERS := [-1, 1]
const CEILING_LIGHT_ENERGY := 1.45
const CEILING_LIGHT_COLOR := Color(1.0, 0.95, 0.86)
const PREVIEW_VALID_COLOR := Color(0.0, 0.654902, 0.0, 0.38431373)
const PREVIEW_INVALID_COLOR := Color(0.88, 0.12, 0.12, 0.48)
const DOOR_VARIANTS := [
	{"id": "single", "label": "单扇防火门", "scene_path": "res://fireproof_door_single.tscn"},
	{"id": "double", "label": "双扇防火门", "scene_path": "res://fireproof_door_double.tscn"},
]
const DOOR_PREVIEW_GROUP := "preview"

var current_building := {
	"scene": null,
	"preview": null,
	"is_active": false,
	"placement_mode": "point",
	"view_layer": 0,
	"story_level": 1,
	"floor_kind": "ground",
	"line_start_point": null,
	"wall_edge_index": 0,
	"wall_edge_manual": false,
	"wall_rotation_degrees": 0.0,
	"base_preview_yaw": 0.0,
	"point_cell_size": Vector3.ONE,
	"collision_size": Vector3.ZERO,
	"is_placeable": true,
	"surface_snap_target": null,
	"cell_line_dragging": false,
	"wall_line_dragging": false,
	"wall_line_anchor": null,
}
var preview_cache_valid := false
var preview_last_mouse_pos := Vector2.ZERO
var preview_last_camera_position := Vector3.ZERO
var preview_last_camera_rotation := Vector3.ZERO
var door_primary_scene: PackedScene = null
var door_alt_scene: PackedScene = null
var current_door_variant_index := 0
var door_preview_instance: Node3D = null
var max_story_level := StoryLevels.DEFAULT_BUILDING_STORY_COUNT

func initialize(preview_cube: MeshInstance3D, preview_wall: MeshInstance3D, preview_pipe: MeshInstance3D, preview_rack: MeshInstance3D = null, preview_floor: MeshInstance3D = null) -> void:
	_prepare_preview_material(preview_cube)
	_prepare_preview_material(preview_wall)
	_prepare_preview_material(preview_rack)
	_prepare_preview_material(preview_floor)
	if preview_cube:
		preview_cube.visible = false
	if preview_wall:
		preview_wall.visible = false
	if preview_pipe:
		preview_pipe.visible = false
	if preview_rack:
		preview_rack.visible = false
	if preview_floor:
		preview_floor.visible = false


func bind_buttons(btn_cube: Button, btn_rack: Button, btn_wall: Button, btn_door: Button, btn_floor: Button, btn_pipe: Button, btn_trench: Button, block_scene: PackedScene, rack_scene: PackedScene, wall_scene: PackedScene, door_scene: PackedScene, floor_scene: PackedScene, pipe_scene: PackedScene, trench_scene: PackedScene, preview_cube: MeshInstance3D, preview_rack: MeshInstance3D, preview_wall: MeshInstance3D, preview_floor: MeshInstance3D, preview_pipe: MeshInstance3D, target: Object, method: StringName) -> void:
	if btn_cube:
		btn_cube.pressed.connect(Callable(target, method).bind(block_scene, preview_cube, "point"))
	if btn_rack:
		btn_rack.pressed.connect(Callable(target, method).bind(rack_scene, preview_rack, "point"))
	if btn_wall:
		btn_wall.pressed.connect(Callable(target, method).bind(wall_scene, preview_wall, "point"))
	if btn_door:
		btn_door.pressed.connect(Callable(target, method).bind(door_scene, preview_wall, "point"))
	door_primary_scene = door_scene
	if btn_floor:
		btn_floor.pressed.connect(Callable(target, method).bind(floor_scene, preview_floor, "cell_line"))
	if btn_pipe:
		btn_pipe.pressed.connect(Callable(target, method).bind(pipe_scene, preview_pipe, "wall_line"))
	if btn_trench:
		btn_trench.pressed.connect(Callable(target, method).bind(trench_scene, preview_pipe, "line"))

func set_alternate_door_scene(scene: PackedScene) -> void:
	door_alt_scene = scene

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
		current_building["cell_line_dragging"] = false
		current_building["wall_line_dragging"] = false
		current_building["wall_line_anchor"] = null
		_invalidate_preview_cache()
		if normalized_mode == "cell_line":
			current_building["floor_kind"] = "ground"
			_configure_cell_line_preview(preview)
		if normalized_mode == "wall_line":
			_configure_wall_line_preview(preview)
		if scene and scene.resource_path == DOOR_SCENE_PATH:
			current_door_variant_index = 0
			_clear_door_preview_instance()
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
	if scene and scene.resource_path == PIPELINE_SCENE_PATH:
		return "wall_line"
	return placement_mode

func update_ui() -> void:
	var preview = current_building["preview"]
	if preview and preview is MeshInstance3D:
		var show_point_preview: bool = current_building["is_active"] and current_building["placement_mode"] == "point"
		if _is_active_door_building():
			show_point_preview = false
		preview.visible = show_point_preview
		_apply_preview_fit()

func get_door_variant_label() -> String:
	var variant := _get_door_variant_config()
	return str(variant.get("label", "门"))

func is_active_door_building() -> bool:
	return _is_active_door_building()

func is_active() -> bool:
	return current_building["is_active"]

func get_preview() -> MeshInstance3D:
	return current_building["preview"]

func get_placement_mode() -> String:
	return str(current_building.get("placement_mode", "point"))

func set_active_view_layer(layer: int) -> void:
	current_building["view_layer"] = layer
	_invalidate_preview_cache()
	if get_placement_mode() == "line" or get_placement_mode() == "wall_line":
		_reset_line_preview()

func set_max_story_level(count: int) -> void:
	max_story_level = StoryLevels.normalize_building_story_count(count)

func set_active_story_level(story_level: int) -> void:
	current_building["story_level"] = _normalize_story_level(story_level)
	_invalidate_preview_cache()
	if get_placement_mode() == "line" or get_placement_mode() == "wall_line":
		_reset_line_preview()

func get_active_story_level() -> int:
	return _normalize_story_level(current_building.get("story_level", 1))

func _normalize_story_level(value: Variant) -> int:
	return StoryLevels.normalize_story_level(value, max_story_level)

func get_floor_kind() -> String:
	return StoryLevels.normalize_floor_kind(current_building.get("floor_kind", "ground"))

func get_floor_kind_label() -> String:
	return StoryLevels.get_floor_kind_label(get_floor_kind())

func is_active_floor_building() -> bool:
	return _is_active_floor_building()

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
	current_building["cell_line_dragging"] = false
	current_building["wall_line_dragging"] = false
	current_building["wall_line_anchor"] = null
	_clear_door_preview_instance()
	_invalidate_preview_cache()
	_reset_line_preview()

func handle_preview_logic(root: Node3D, grid_map: GridMap) -> void:
	if not grid_map:
		return
	var camera = root.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if not camera:
		return
	var mouse_pos = root.get_viewport().get_mouse_position()
	if _should_skip_preview_update(camera, mouse_pos):
		return
	if get_placement_mode() == "cell_line":
		_handle_cell_line_preview_logic(root, grid_map)
		return
	if get_placement_mode() == "wall_line":
		_handle_wall_line_preview_logic(root, grid_map)
		return
	if get_placement_mode() == "line":
		_handle_line_preview_logic(root, grid_map)
		return
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
			var floor_point : Variant = _intersect_point_build_plane(camera, mouse_pos, grid_map)
			if floor_point == null:
				var preview_mesh = current_building["preview"] as MeshInstance3D
				if preview_mesh:
					preview_mesh.visible = false
				return
			cursor_point = floor_point as Vector3
		else:
			hit_result = result
			cursor_point = result.position
			if _uses_surface_snap() and result.get("collider") != grid_map and not _get_surface_snap_target_node(result.get("collider")):
				var floor_point : Variant = _intersect_point_build_plane(camera, mouse_pos, grid_map)
				if floor_point != null:
					cursor_point = floor_point as Vector3

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
		if _uses_edge_snap() and StoryLevels.is_mezzanine_runtime_layer(int(current_building.get("view_layer", 0))):
			final_pos.y = _get_mezzanine_air_wall_center_y(get_active_story_level(), grid_map, int(current_building.get("view_layer", 0)))
		else:
			final_pos.y = _get_story_floor_top_y(grid_map) + y_offset
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
	if _is_active_door_building():
		preview_mesh.visible = false
		_ensure_door_preview_instance(root)
		_sync_door_preview_instance(preview_mesh)
		_set_door_preview_validity(is_placeable)
	else:
		_clear_door_preview_instance()
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
	_update_line_preview(preview_mesh, start_vec, end_vec, grid_map)

func _try_handle_floor_kind_hotkeys(root: Node, event: InputEvent) -> bool:
	if not _is_active_floor_building():
		return false
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	var direction := 0
	if event.keycode == Key.KEY_UP:
		direction = -1
	elif event.keycode == Key.KEY_DOWN:
		direction = 1
	else:
		return false
	_cycle_floor_kind(direction)
	_invalidate_preview_cache()
	if root.has_method("ensure_floor_build_view_for_kind"):
		root.call("ensure_floor_build_view_for_kind", get_floor_kind())
	if root.has_method("update_floor_build_tooltip"):
		root.call("update_floor_build_tooltip", get_floor_kind_label(), get_active_story_level())
	print("切换地板类型: ", get_floor_kind_label())
	root.get_viewport().set_input_as_handled()
	return true

func handle_unhandled_input(root: Node, event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and event.keycode == Key.KEY_ESCAPE and current_building["is_active"]:
		cancel_build_mode()
		update_ui()
		print("退出建造")
		root.get_viewport().set_input_as_handled()
		return true

	if _try_handle_floor_kind_hotkeys(root, event):
		return true

	if get_placement_mode() == "cell_line":
		return _handle_cell_line_input(root, event)

	if get_placement_mode() == "wall_line":
		return _handle_wall_line_input(root, event)

	if get_placement_mode() == "line":
		return false

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == Key.KEY_TAB and current_building["is_active"]:
		if _is_active_door_building():
			current_door_variant_index = (current_door_variant_index + 1) % DOOR_VARIANTS.size()
			_rebuild_door_preview_instance(root)
			var preview_mesh := current_building.get("preview") as Node3D
			if preview_mesh:
				_sync_door_preview_instance(preview_mesh)
			_invalidate_preview_cache()
			if root.has_method("update_door_build_tooltip"):
				root.call("update_door_build_tooltip", get_door_variant_label())
			print("切换门样式: ", get_door_variant_label())
			root.get_viewport().set_input_as_handled()
			return true

	if event is InputEventKey and event.pressed == false and current_building["is_active"] and current_building["preview"]:
		var preview_mesh = current_building["preview"] as Node3D
		if _uses_edge_snap():
			if event.keycode == Key.KEY_UP:
				_cycle_wall_edge(-1)
				_apply_wall_preview_orientation(preview_mesh)
				_apply_preview_fit()
				_invalidate_preview_cache()
				root.get_viewport().set_input_as_handled()
				return true
			if event.keycode == Key.KEY_DOWN:
				_cycle_wall_edge(1)
				_apply_wall_preview_orientation(preview_mesh)
				_apply_preview_fit()
				_invalidate_preview_cache()
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
			_invalidate_preview_cache()
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
			_invalidate_preview_cache()
			root.get_viewport().set_input_as_handled()
			return true

	return false

func place_current_building(root: Node3D, grid_map: GridMap) -> void:
	if get_placement_mode() == "cell_line" or get_placement_mode() == "wall_line":
		return
	if get_placement_mode() == "line":
		_place_or_update_line_building(root, grid_map)
		return
	var scene_to_spawn = current_building["scene"] as PackedScene
	var preview_node = current_building["preview"] as Node3D
	if not scene_to_spawn or not preview_node:
		return
	if not bool(current_building.get("is_placeable", true)):
		return
	if _is_active_door_building():
		_place_door_building(root, grid_map, preview_node)
		return
	var new_building = scene_to_spawn.instantiate()
	if new_building is Node and _uses_edge_snap():
		(new_building as Node).set_meta("logical_length_scale", _get_wall_length_scale(grid_map.cell_size))
		if scene_to_spawn.resource_path == WALL_SCENE_PATH:
			var view_layer := int(current_building.get("view_layer", 0))
			if StoryLevels.is_mezzanine_runtime_layer(view_layer):
				(new_building as Node).set_meta("air_wall", true)
				(new_building as Node).set_meta("air_wall_height", StoryLevels.MEZZANINE_WALL_HEIGHT)
				_tag_mezzanine_wall_edge_meta(new_building as Node, grid_map, preview_node)
			else:
				(new_building as Node).set_meta("floor_thickness_extension", grid_map.cell_size.y)
	root.add_child(new_building)
	new_building.global_transform = preview_node.global_transform
	if new_building is Node:
		(new_building as Node).set_meta("build_view_layer", int(current_building.get("view_layer", 0)))
		(new_building as Node).set_meta("story_level", get_active_story_level())
		if new_building.has_method("refresh_diagonal_fit"):
			new_building.call("refresh_diagonal_fit")
	if new_building is Node3D and root.has_method("register_runtime_layer_node"):
		root.call("register_runtime_layer_node", new_building as Node3D)
	_invalidate_preview_cache()
	print("放置了: ", scene_to_spawn.resource_path)

func _invalidate_preview_cache() -> void:
	preview_cache_valid = false

func _should_skip_preview_update(camera: Camera3D, mouse_pos: Vector2) -> bool:
	var camera_position := camera.global_position
	var camera_rotation := camera.global_rotation
	if preview_cache_valid and mouse_pos == preview_last_mouse_pos and camera_position.distance_squared_to(preview_last_camera_position) < 0.000001 and camera_rotation.distance_squared_to(preview_last_camera_rotation) < 0.000001:
		return true
	preview_cache_valid = true
	preview_last_mouse_pos = mouse_pos
	preview_last_camera_position = camera_position
	preview_last_camera_rotation = camera_rotation
	return false

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
	var plane_y := _get_layer_plane_y(grid_map)
	if int(current_building.get("view_layer", 0)) == 1 and _uses_edge_snap():
		plane_y = StoryLevels.get_mezzanine_floor_y(get_active_story_level(), _get_l1_floor_top_y(grid_map))
	elif int(current_building.get("view_layer", 0)) == -1 and _uses_edge_snap():
		plane_y = StoryLevels.get_lower_mezzanine_floor_y(get_active_story_level(), _get_l1_floor_top_y(grid_map))
	var plane := Plane(Vector3.UP, plane_y)
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
	snap_position.y = _get_story_floor_top_y(grid_map) + half_size.y
	preview.rotation.y = snapped_yaw
	out_points.clear()
	out_points.append(snap_position)
	return true

func _get_floor_top_y(grid_map: GridMap) -> float:
	if not grid_map:
		push_error("GridMap is null when calculating floor top Y")
		return 0.0
	return grid_map.global_position.y + grid_map.cell_size.y

func _get_l1_floor_top_y(grid_map: GridMap) -> float:
	if not grid_map:
		push_error("GridMap is null when calculating L1 floor top Y")
		return 0.0
	return grid_map.global_position.y - StoryLevels.get_story_base(get_active_story_level()) + grid_map.cell_size.y

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
	if material and preview_mesh.material_override != material:
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
	if bool(node_3d.get_meta("cell_line_unit", false)):
		return false
	if node_3d.scene_file_path == DOOR_SCENE_PATH or _is_placed_door_scene_path(node_3d.scene_file_path):
		return false
	return _get_node_collision_box_size(node_3d) != Vector3.ZERO

func _get_node_collision_box_size(node: Node) -> Vector3:
	if node.has_meta(COLLISION_BOX_SIZE_META):
		return node.get_meta(COLLISION_BOX_SIZE_META) as Vector3
	var collision_shape := _find_collision_shape(node)
	if collision_shape and collision_shape.shape is BoxShape3D:
		var size := (collision_shape.shape as BoxShape3D).size
		node.set_meta(COLLISION_BOX_SIZE_META, size)
		return size
	node.set_meta(COLLISION_BOX_SIZE_META, Vector3.ZERO)
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
		if current is Node3D and (_is_wall_or_door_scene_path((current as Node3D).scene_file_path)):
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

func _handle_cell_line_input(root: Node, event: InputEvent) -> bool:
	if not current_building["is_active"]:
		return false
	var root_3d := root as Node3D
	if not root_3d:
		return false
	var grid_map := root.get_node_or_null("GridMap") as GridMap
	if not grid_map:
		return false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var cursor_points: Array[Vector3] = []
			if not _try_get_cell_line_cursor_position(root_3d, grid_map, cursor_points):
				return false
			if mouse_event.pressed:
				current_building["line_start_point"] = cursor_points[0]
				current_building["cell_line_dragging"] = true
				_invalidate_preview_cache()
				root.get_viewport().set_input_as_handled()
				return true
			if bool(current_building.get("cell_line_dragging", false)):
				var start_point: Variant = current_building.get("line_start_point")
				if start_point != null:
					_place_cell_line_units(root_3d, grid_map, current_building["scene"] as PackedScene, start_point as Vector3, cursor_points[0])
				_reset_line_preview()
				current_building["cell_line_dragging"] = false
				root.get_viewport().set_input_as_handled()
				return true
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed and bool(current_building.get("cell_line_dragging", false)):
			_reset_line_preview()
			current_building["cell_line_dragging"] = false
			root.get_viewport().set_input_as_handled()
			return true
	return false

func _handle_cell_line_preview_logic(root: Node3D, grid_map: GridMap) -> void:
	var preview_mesh := current_building["preview"] as MeshInstance3D
	if not preview_mesh:
		return
	var cursor_points: Array[Vector3] = []
	if not _try_get_cell_line_cursor_position(root, grid_map, cursor_points):
		preview_mesh.visible = false
		return
	var start_point: Variant = current_building.get("line_start_point")
	var start_vec := cursor_points[0] if start_point == null else start_point as Vector3
	_update_cell_line_preview(preview_mesh, grid_map, start_vec, cursor_points[0])

func _try_get_cell_line_cursor_position(root: Node3D, grid_map: GridMap, out_points: Array[Vector3]) -> bool:
	var camera = root.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if not camera:
		return false
	var mouse_pos = root.get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	var plane := Plane(Vector3.UP, _get_floor_kind_y(grid_map, get_floor_kind()))
	var hit: Variant = plane.intersects_ray(ray_origin, ray_direction)
	if hit == null:
		return false
	var cell := grid_map.local_to_map(grid_map.to_local(hit as Vector3))
	cell.y = 0
	out_points.clear()
	out_points.append(CellLinePlacementScript.cell_center_world(grid_map, cell, _get_floor_kind_y(grid_map, get_floor_kind())))
	return true

func _update_cell_line_preview(preview_mesh: MeshInstance3D, grid_map: GridMap, start_point: Vector3, end_point: Vector3) -> void:
	_configure_cell_line_preview(preview_mesh)
	var span := CellLinePlacementScript.get_dominant_axis_span(grid_map, start_point, end_point)
	if span.is_empty():
		preview_mesh.visible = false
		return
	var start_cell := span.get("start_cell", Vector3i.ZERO) as Vector3i
	var end_cell := span.get("end_cell", Vector3i.ZERO) as Vector3i
	var floor_y := _get_floor_kind_y(grid_map, get_floor_kind())
	var start_world := CellLinePlacementScript.cell_center_world(grid_map, start_cell, floor_y)
	var end_world := CellLinePlacementScript.cell_center_world(grid_map, end_cell, floor_y)
	var thickness := grid_map.cell_size.y if get_floor_kind() == "ceiling" else 0.024
	preview_mesh.global_position = (start_world + end_world) * 0.5 + Vector3.UP * (thickness * 0.5)
	preview_mesh.rotation = Vector3(PI if get_floor_kind() == "ceiling" else 0.0, 0.0, 0.0)
	preview_mesh.scale = Vector3(
		(end_cell.x - start_cell.x + 1) * grid_map.cell_size.x,
		thickness,
		(end_cell.z - start_cell.z + 1) * grid_map.cell_size.z
	)
	preview_mesh.visible = true

func _configure_cell_line_preview(preview_mesh: MeshInstance3D) -> void:
	if not preview_mesh:
		return
	if not bool(preview_mesh.get_meta("cell_line_preview_mesh_ready", false)):
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3.ONE
		preview_mesh.mesh = box_mesh
		preview_mesh.set_meta("cell_line_preview_mesh_ready", true)
	var material := preview_mesh.get_meta("cell_line_preview_material", null) as Material
	if not material:
		var preview_material := StandardMaterial3D.new()
		preview_material.albedo_color = PREVIEW_VALID_COLOR
		preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		preview_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		preview_mesh.set_meta("cell_line_preview_material", preview_material)
		material = preview_material
	preview_mesh.material_override = material

func _handle_wall_line_input(root: Node, event: InputEvent) -> bool:
	if not current_building["is_active"]:
		return false
	var root_3d := root as Node3D
	if not root_3d:
		return false
	var grid_map := root.get_node_or_null("GridMap") as GridMap
	if not grid_map:
		return false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var cursor_points: Array[Vector3] = []
			if not _try_get_wall_line_cursor_position(root_3d, grid_map, cursor_points):
				return false
			if mouse_event.pressed:
				current_building["line_start_point"] = cursor_points[0]
				current_building["wall_line_dragging"] = true
				_invalidate_preview_cache()
				root.get_viewport().set_input_as_handled()
				return true
			if bool(current_building.get("wall_line_dragging", false)):
				var start_point: Variant = current_building.get("line_start_point")
				if start_point != null:
					_place_wall_line_pipe(root_3d, start_point as Vector3, cursor_points[0])
				_reset_line_preview()
				current_building["wall_line_dragging"] = false
				current_building["wall_line_anchor"] = null
				root.get_viewport().set_input_as_handled()
				return true
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed and bool(current_building.get("wall_line_dragging", false)):
			_reset_line_preview()
			current_building["wall_line_dragging"] = false
			current_building["wall_line_anchor"] = null
			root.get_viewport().set_input_as_handled()
			return true
	return false

func _handle_wall_line_preview_logic(root: Node3D, grid_map: GridMap) -> void:
	var preview_mesh := current_building["preview"] as MeshInstance3D
	if not preview_mesh:
		return
	var cursor_points: Array[Vector3] = []
	if not _try_get_wall_line_cursor_position(root, grid_map, cursor_points):
		preview_mesh.visible = false
		return
	var start_point: Variant = current_building.get("line_start_point")
	if start_point == null:
		preview_mesh.visible = false
		return
	var anchor: Variant = current_building.get("wall_line_anchor")
	if anchor == null:
		preview_mesh.visible = false
		return
	_update_wall_line_preview(preview_mesh, start_point as Vector3, cursor_points[0], anchor as Dictionary)

func _try_get_wall_line_cursor_position(root: Node3D, grid_map: GridMap, out_points: Array[Vector3]) -> bool:
	var anchor_data := _resolve_wall_line_anchor(root, grid_map)
	if anchor_data.is_empty():
		return false
	if not bool(current_building.get("wall_line_dragging", false)):
		current_building["wall_line_anchor"] = anchor_data
	var projected: Variant = _project_wall_line_point_from_camera(root, grid_map, anchor_data)
	if projected == null:
		return false
	out_points.clear()
	out_points.append(projected)
	return true

func _resolve_wall_line_anchor(root: Node3D, grid_map: GridMap) -> Dictionary:
	if bool(current_building.get("wall_line_dragging", false)):
		var existing: Variant = current_building.get("wall_line_anchor")
		if existing is Dictionary:
			return existing as Dictionary
	var wall_hit := _raycast_wall_surface(root)
	if not wall_hit.is_empty():
		return _wall_hit_to_anchor(wall_hit)
	return _try_build_wall_line_anchor_from_grid(root, grid_map)

func _try_build_wall_line_anchor_from_grid(root: Node3D, grid_map: GridMap) -> Dictionary:
	var camera := root.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if not camera or not grid_map:
		return {}
	var floor_point : Variant = _intersect_point_build_plane(camera, root.get_viewport().get_mouse_position(), grid_map)
	if floor_point == null:
		return {}
	var local_pos := grid_map.to_local(floor_point as Vector3)
	var cell_size := grid_map.cell_size
	var map_coord := Vector3i(
		floori(local_pos.x / cell_size.x),
		0,
		floori(local_pos.z / cell_size.z)
	)
	var cell_center := grid_map.map_to_local(map_coord)
	var edge_index := _resolve_wall_edge_index(local_pos, cell_center, cell_size)
	var edge_offset := _get_wall_edge_offset(cell_size, edge_index, PIPE_DEFAULT_RADIUS * 2.0)
	var surface_global := grid_map.to_global(cell_center + edge_offset)
	return {
		"surface_x": surface_global.x,
		"surface_z": surface_global.z,
		"normal": _wall_edge_index_to_normal(edge_index),
	}

func _wall_edge_index_to_normal(edge_index: int) -> Vector3:
	match posmod(edge_index, 4):
		0:
			return Vector3.RIGHT
		1:
			return Vector3.BACK
		2:
			return Vector3.LEFT
		_:
			return Vector3.FORWARD

func _raycast_wall_surface(root: Node3D) -> Dictionary:
	var camera := root.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if not camera:
		return {}
	var mouse_pos := root.get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * 100.0
	var space_state := root.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return {}
	if _get_surface_snap_target_node(result.get("collider")) == null:
		return {}
	return result

func _wall_hit_to_anchor(wall_hit: Dictionary) -> Dictionary:
	var hit_position: Vector3 = wall_hit.get("position", Vector3.ZERO)
	var hit_normal: Vector3 = wall_hit.get("normal", Vector3.UP)
	var horizontal_normal := Vector3(hit_normal.x, 0.0, hit_normal.z)
	if horizontal_normal.length_squared() < 0.0001:
		horizontal_normal = Vector3.FORWARD
	else:
		horizontal_normal = horizontal_normal.normalized()
	return {
		"surface_x": hit_position.x,
		"surface_z": hit_position.z,
		"normal": horizontal_normal,
	}

func _anchor_to_wall_pipe_point(anchor: Dictionary, grid_map: GridMap, hit_position: Vector3) -> Vector3:
	var horizontal_normal: Vector3 = anchor.get("normal", Vector3.FORWARD)
	var surface_x := float(anchor.get("surface_x", hit_position.x))
	var surface_z := float(anchor.get("surface_z", hit_position.z))
	var snapped_y := _snap_wall_line_y(hit_position.y, grid_map)
	var surface_point := Vector3(surface_x, snapped_y, surface_z)
	return surface_point + horizontal_normal * PIPE_DEFAULT_RADIUS

func _project_wall_line_point_from_camera(root: Node3D, grid_map: GridMap, anchor: Dictionary) -> Variant:
	var camera := root.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if not camera:
		return null
	var horizontal_normal: Vector3 = anchor.get("normal", Vector3.FORWARD)
	var surface_x := float(anchor.get("surface_x", 0.0))
	var surface_z := float(anchor.get("surface_z", 0.0))
	var anchor_point := Vector3(surface_x, 0.0, surface_z)
	var plane := Plane(horizontal_normal, anchor_point)
	var mouse_pos := root.get_viewport().get_mouse_position()
	var hit: Variant = plane.intersects_ray(camera.project_ray_origin(mouse_pos), camera.project_ray_normal(mouse_pos))
	if hit == null:
		return null
	var snapped_y := _snap_wall_line_y((hit as Vector3).y, grid_map)
	return Vector3(surface_x, snapped_y, surface_z) + horizontal_normal * PIPE_DEFAULT_RADIUS

func _snap_wall_line_y(y: float, grid_map: GridMap) -> float:
	var layer := int(current_building.get("view_layer", 0))
	if layer == 1:
		var floor_y := StoryLevels.get_mezzanine_floor_y(get_active_story_level(), _get_l1_floor_top_y(grid_map))
		var ceiling_y := StoryLevels.get_mezzanine_ceiling_y(get_active_story_level(), _get_l1_floor_top_y(grid_map))
		var step := maxf(grid_map.cell_size.y, 0.1)
		return clampf(floor_y + round((y - floor_y) / step) * step, floor_y, ceiling_y)
	if layer == -1:
		var floor_y := StoryLevels.get_lower_mezzanine_floor_y(get_active_story_level(), _get_l1_floor_top_y(grid_map))
		var ceiling_y := StoryLevels.get_lower_mezzanine_ceiling_y(get_active_story_level(), _get_l1_floor_top_y(grid_map))
		var step := maxf(grid_map.cell_size.y, 0.1)
		return clampf(floor_y + round((y - floor_y) / step) * step, floor_y, ceiling_y)
	var base_y := _get_story_floor_top_y(grid_map)
	var step := maxf(grid_map.cell_size.y, 0.25)
	return base_y + round((y - base_y) / step) * step

func _update_wall_line_preview(preview_mesh: MeshInstance3D, start_point: Vector3, end_point: Vector3, anchor: Dictionary) -> void:
	_configure_wall_line_preview(preview_mesh)
	_apply_vertical_wall_pipe_segment(preview_mesh, start_point, end_point, anchor.get("normal", Vector3.FORWARD) as Vector3)
	preview_mesh.visible = true

func _configure_wall_line_preview(preview_mesh: MeshInstance3D) -> void:
	if not preview_mesh:
		return
	_prepare_preview_material(preview_mesh)
	if preview_mesh.mesh == null or not (preview_mesh.mesh is CylinderMesh):
		var cylinder_mesh := CylinderMesh.new()
		cylinder_mesh.top_radius = PIPE_DEFAULT_RADIUS
		cylinder_mesh.bottom_radius = PIPE_DEFAULT_RADIUS
		cylinder_mesh.height = 1.0
		preview_mesh.mesh = cylinder_mesh

func _apply_vertical_wall_pipe_segment(target: Node3D, start_point: Vector3, end_point: Vector3, wall_normal: Vector3) -> void:
	var y0 := minf(start_point.y, end_point.y)
	var y1 := maxf(start_point.y, end_point.y)
	var segment_length := maxf(y1 - y0, PIPE_PREVIEW_MIN_LENGTH)
	var center_y := (y0 + y1) * 0.5
	var horizontal_normal := Vector3(wall_normal.x, 0.0, wall_normal.z)
	if horizontal_normal.length_squared() < 0.0001:
		horizontal_normal = Vector3.FORWARD
	else:
		horizontal_normal = horizontal_normal.normalized()
	var anchor_x := start_point.x - horizontal_normal.x * PIPE_DEFAULT_RADIUS
	var anchor_z := start_point.z - horizontal_normal.z * PIPE_DEFAULT_RADIUS
	target.global_position = Vector3(anchor_x, center_y, anchor_z) + horizontal_normal * PIPE_DEFAULT_RADIUS
	target.global_rotation = Vector3.ZERO
	target.scale = Vector3(1.0, segment_length, 1.0)

func _place_wall_line_pipe(root: Node3D, start_point: Vector3, end_point: Vector3) -> void:
	var scene_to_spawn := current_building["scene"] as PackedScene
	if not scene_to_spawn:
		return
	if start_point.distance_to(end_point) < 0.05:
		return
	var anchor: Variant = current_building.get("wall_line_anchor")
	if not anchor is Dictionary:
		return
	var new_building := scene_to_spawn.instantiate()
	root.add_child(new_building)
	if new_building is Node3D:
		_apply_vertical_wall_pipe_segment(new_building as Node3D, start_point, end_point, anchor.get("normal", Vector3.FORWARD))
	if new_building is Node:
		(new_building as Node).set_meta("build_view_layer", int(current_building.get("view_layer", 0)))
		(new_building as Node).set_meta("story_level", get_active_story_level())
		(new_building as Node).set_meta("wall_line_pipe", true)
	if new_building is Node3D and root.has_method("register_runtime_layer_node"):
		root.call("register_runtime_layer_node", new_building as Node3D)
	print("放置了: ", scene_to_spawn.resource_path)

func _place_cell_line_units(root: Node3D, grid_map: GridMap, scene_to_spawn: PackedScene, start_point: Vector3, end_point: Vector3) -> void:
	if not grid_map or not scene_to_spawn:
		return
	var unit_cells := CellLinePlacementScript.get_dominant_axis_cells(grid_map, start_point, end_point)
	var cells := unit_cells.get("cells", []) as Array
	var story_level := get_active_story_level()
	var floor_kind := get_floor_kind()
	var layer := StoryLevels.get_floor_build_view_layer(floor_kind)
	var floor_y := _get_floor_kind_y(grid_map, floor_kind)
	var placed_count := 0
	var placed_cells: Array[Vector3i] = []
	var existing_cell_keys := _get_existing_cell_line_unit_keys(root, scene_to_spawn.resource_path, story_level, layer, floor_kind)
	for cell in cells:
		var cell_vec := cell as Vector3i
		var cell_key := CellLinePlacementScript.floor_cell_key(story_level, layer, cell_vec.x, cell_vec.z, floor_kind)
		if existing_cell_keys.has(cell_key):
			continue
		var new_unit := scene_to_spawn.instantiate()
		root.add_child(new_unit)
		if new_unit is Node3D:
			var unit_node := new_unit as Node3D
			_sync_floor_unit_with_grid_map(unit_node, grid_map, floor_kind)
			var world_pos := CellLinePlacementScript.cell_center_world(grid_map, cell_vec, floor_y)
			if floor_kind == "ceiling":
				world_pos.y += grid_map.cell_size.y * 0.5
			unit_node.global_transform = Transform3D(Basis.IDENTITY, world_pos)
			unit_node.set_meta("cell_line_unit", true)
			unit_node.set_meta("floor_cell_x", cell_vec.x)
			unit_node.set_meta("floor_cell_z", cell_vec.z)
			unit_node.set_meta("floor_kind", floor_kind)
			unit_node.set_meta("story_level", story_level)
			unit_node.set_meta("revealable", StoryLevels.is_revealable_floor_kind(floor_kind))
			_ensure_floor_unit_selection_body(unit_node, grid_map, story_level, layer, floor_kind, cell_vec)
			if floor_kind == "ceiling":
				_ensure_ceiling_light(unit_node, grid_map)
			if root.has_method("register_built_floor_unit"):
				root.call("register_built_floor_unit", cell_vec, unit_node, story_level, floor_kind)
			placed_cells.append(cell_vec)
		if new_unit is Node:
			(new_unit as Node).set_meta("build_view_layer", layer)
			(new_unit as Node).set_meta("story_level", story_level)
			(new_unit as Node).set_meta("floor_kind", floor_kind)
		if new_unit is Node3D and root.has_method("register_runtime_layer_node"):
			root.call("register_runtime_layer_node", new_unit as Node3D)
		placed_count += 1
		existing_cell_keys[cell_key] = true
	if not placed_cells.is_empty():
		if root.has_method("register_built_floor_cells"):
			root.call("register_built_floor_cells", placed_cells, story_level, floor_kind)
		elif root.has_method("register_built_floor_cell"):
			for placed_cell in placed_cells:
				root.call("register_built_floor_cell", placed_cell, story_level, floor_kind)
	if placed_count > 0:
		print("连续铺设%s(L%d): %d" % [get_floor_kind_label(), story_level, placed_count])

func _find_existing_cell_line_unit(root: Node3D, scene_path: String, cell: Vector3i, story_level: int, layer: int, floor_kind: String) -> Node3D:
	for child in root.get_children():
		if not child is Node3D:
			continue
		var node := child as Node3D
		if node.scene_file_path != scene_path:
			continue
		if int(node.get_meta("story_level", 1)) != story_level:
			continue
		if int(node.get_meta("build_view_layer", 0)) != layer:
			continue
		if str(node.get_meta("floor_kind", "ground")) != floor_kind:
			continue
		if int(node.get_meta("floor_cell_x", 999999)) == cell.x and int(node.get_meta("floor_cell_z", 999999)) == cell.z:
			return node
	return null

func _get_existing_cell_line_unit_keys(root: Node3D, scene_path: String, story_level: int, layer: int, floor_kind: String) -> Dictionary:
	var keys := {}
	for child in root.get_children():
		if not child is Node3D:
			continue
		var node := child as Node3D
		if node.scene_file_path != scene_path:
			continue
		if int(node.get_meta("story_level", 1)) != story_level:
			continue
		if int(node.get_meta("build_view_layer", 0)) != layer:
			continue
		if str(node.get_meta("floor_kind", "ground")) != floor_kind:
			continue
		var cell_x := int(node.get_meta("floor_cell_x", 999999))
		var cell_z := int(node.get_meta("floor_cell_z", 999999))
		if cell_x == 999999 or cell_z == 999999:
			continue
		keys[CellLinePlacementScript.floor_cell_key(story_level, layer, cell_x, cell_z, floor_kind)] = true
	return keys

func _sync_floor_unit_with_grid_map(unit_node: Node3D, grid_map: GridMap, floor_kind: String = "ground") -> void:
	if not unit_node or not grid_map:
		return
	unit_node.scale = Vector3.ONE
	var mesh_instance := _find_mesh_instance(unit_node)
	if not mesh_instance:
		return
	if floor_kind == "ceiling":
		var ceiling_mesh := BoxMesh.new()
		ceiling_mesh.size = Vector3(grid_map.cell_size.x * 0.98, grid_map.cell_size.y, grid_map.cell_size.z * 0.98)
		var ceiling_material: StandardMaterial3D = null
		if grid_map.mesh_library:
			var grid_mesh := grid_map.mesh_library.get_item_mesh(0)
			if grid_mesh and grid_mesh.material:
				ceiling_material = grid_mesh.material.duplicate() as StandardMaterial3D
		if ceiling_material == null:
			ceiling_material = StandardMaterial3D.new()
			ceiling_material.albedo_color = Color(0.82, 0.86, 0.9, 1.0)
		ceiling_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		ceiling_mesh.material = ceiling_material
		mesh_instance.mesh = ceiling_mesh
		mesh_instance.transform = Transform3D.IDENTITY
		mesh_instance.rotation.x = PI
		return
	if not grid_map.mesh_library:
		return
	var grid_mesh := grid_map.mesh_library.get_item_mesh(0)
	if not grid_mesh:
		return
	mesh_instance.mesh = grid_mesh
	mesh_instance.transform = grid_map.mesh_library.get_item_mesh_transform(0)
	mesh_instance.rotation = Vector3.ZERO

func _get_mezzanine_air_wall_center_y(story_level: int, grid_map: GridMap, view_layer: int) -> float:
	var floor_top_y := _get_l1_floor_top_y(grid_map)
	var floor_y := StoryLevels.get_mezzanine_floor_y(story_level, floor_top_y)
	if view_layer == -1:
		floor_y = StoryLevels.get_lower_mezzanine_floor_y(story_level, floor_top_y)
	return floor_y + StoryLevels.MEZZANINE_WALL_HEIGHT * 0.5

func ensure_mezzanine_perimeter_air_walls(root: Node3D, grid_map: GridMap, story_level: int) -> void:
	if not root or not grid_map:
		return
	var normalized_story := _normalize_story_level(story_level)
	var ground_cells := collect_l1_ground_reference_cells(root, grid_map)
	_remove_stale_mezzanine_air_walls(root, normalized_story, ground_cells)
	if ground_cells.is_empty():
		return
	var wall_scene := load(WALL_SCENE_PATH) as PackedScene
	if not wall_scene:
		return
	var cell_size := grid_map.cell_size
	var wall_thickness := 0.2
	for runtime_layer in MEZZANINE_AIR_WALL_RUNTIME_LAYERS:
		var wall_center_y := _get_mezzanine_air_wall_center_y(normalized_story, grid_map, runtime_layer)
		for cell_key in ground_cells.keys():
			var cell := ground_cells[cell_key] as Vector2i
			for edge_index in range(4):
				if not _is_ground_perimeter_edge(ground_cells, cell.x, cell.y, edge_index):
					continue
				if _find_mezzanine_air_wall(root, normalized_story, runtime_layer, cell.x, cell.y, edge_index):
					continue
				_spawn_mezzanine_air_wall(
					root,
					grid_map,
					wall_scene,
					normalized_story,
					runtime_layer,
					cell,
					edge_index,
					cell_size,
					wall_thickness,
					wall_center_y
				)

func collect_l1_ground_reference_cells(root: Node3D, grid_map: GridMap) -> Dictionary:
	var cells := _collect_ground_floor_cells(root, 1)
	if not grid_map:
		return cells
	for cell in grid_map.get_used_cells():
		var cell_vec := cell as Vector3i
		if cell_vec.y != 0:
			continue
		if grid_map.get_cell_item(cell_vec) < 0:
			continue
		var key := "%d,%d" % [cell_vec.x, cell_vec.z]
		if not cells.has(key):
			cells[key] = Vector2i(cell_vec.x, cell_vec.z)
	return cells

func refresh_all_story_mezzanine_air_walls(root: Node3D, grid_map: GridMap, max_story: int) -> void:
	if not root or not grid_map or collect_l1_ground_reference_cells(root, grid_map).is_empty():
		return
	for story_level in range(1, maxi(max_story, 1) + 1):
		ensure_mezzanine_perimeter_air_walls(root, grid_map, story_level)

func sync_all_story_ground_floors_from_l1(root: Node3D, grid_map: GridMap, floor_scene: PackedScene, max_story: int) -> int:
	if not root or not grid_map or not floor_scene:
		return 0
	var reference_cells := collect_l1_ground_reference_cells(root, grid_map)
	if reference_cells.is_empty():
		return 0
	var changed := 0
	for target_story in range(2, maxi(max_story, 1) + 1):
		changed += _sync_story_ground_floor_cells(root, grid_map, floor_scene, reference_cells, target_story)
	return changed

func _sync_story_ground_floor_cells(root: Node3D, grid_map: GridMap, floor_scene: PackedScene, reference_cells: Dictionary, target_story: int) -> int:
	var scene_path := floor_scene.resource_path
	var layer := StoryLevels.get_floor_build_view_layer("ground")
	var changed := 0
	var remove_nodes: Array[Node3D] = []
	for child in root.get_children():
		if not child is Node3D:
			continue
		var node := child as Node3D
		if not bool(node.get_meta("cell_line_unit", false)):
			continue
		if StoryLevels.normalize_floor_kind(node.get_meta("floor_kind", "ground")) != "ground":
			continue
		if _normalize_story_level(node.get_meta("story_level", 1)) != target_story:
			continue
		var cell_x := int(node.get_meta("floor_cell_x", 0))
		var cell_z := int(node.get_meta("floor_cell_z", 0))
		if not reference_cells.has("%d,%d" % [cell_x, cell_z]):
			remove_nodes.append(node)
	for node in remove_nodes:
		var cell := Vector3i(int(node.get_meta("floor_cell_x", 0)), 0, int(node.get_meta("floor_cell_z", 0)))
		if root.has_method("unregister_built_floor_cell"):
			root.call("unregister_built_floor_cell", cell, target_story, "ground", true)
		node.queue_free()
		changed += 1
	var placed_cells: Array[Vector3i] = []
	for cell_key in reference_cells.keys():
		var cell := reference_cells[cell_key] as Vector2i
		var cell_vec := Vector3i(cell.x, 0, cell.y)
		if _find_existing_cell_line_unit(root, scene_path, cell_vec, target_story, layer, "ground"):
			continue
		var new_unit := floor_scene.instantiate()
		if not new_unit is Node3D:
			if new_unit:
				new_unit.queue_free()
			continue
		var unit_node := new_unit as Node3D
		root.add_child(unit_node)
		unit_node.set_meta("story_level", target_story)
		unit_node.set_meta("floor_kind", "ground")
		restore_floor_unit(unit_node, grid_map, layer, cell_vec)
		if root.has_method("register_built_floor_unit"):
			root.call("register_built_floor_unit", cell_vec, unit_node, target_story, "ground")
		if new_unit is Node3D and root.has_method("register_runtime_layer_node"):
			root.call("register_runtime_layer_node", new_unit as Node3D)
		placed_cells.append(cell_vec)
		changed += 1
	if not placed_cells.is_empty() and root.has_method("register_built_floor_cells"):
		root.call("register_built_floor_cells", placed_cells, target_story, "ground", true)
	return changed

func _tag_mezzanine_wall_edge_meta(wall_node: Node, grid_map: GridMap, preview_node: Node3D) -> void:
	if not wall_node or not grid_map or not preview_node:
		return
	var local_pos := grid_map.to_local(preview_node.global_position)
	var cell := grid_map.local_to_map(local_pos)
	cell.y = 0
	var cell_center := grid_map.map_to_local(cell)
	var edge_index := int(current_building.get("wall_edge_index", _resolve_wall_edge_index(local_pos, cell_center, grid_map.cell_size)))
	wall_node.set_meta("mezzanine_edge_cell_x", cell.x)
	wall_node.set_meta("mezzanine_edge_cell_z", cell.z)
	wall_node.set_meta("mezzanine_edge_index", edge_index)

func _collect_ground_floor_cells(root: Node3D, story_level: int) -> Dictionary:
	var cells := {}
	for child in root.get_children():
		if not child is Node3D:
			continue
		var node := child as Node3D
		if not bool(node.get_meta("cell_line_unit", false)):
			continue
		if StoryLevels.normalize_floor_kind(node.get_meta("floor_kind", "ground")) != "ground":
			continue
		if _normalize_story_level(node.get_meta("story_level", 1)) != story_level:
			continue
		var cell_x := int(node.get_meta("floor_cell_x", 0))
		var cell_z := int(node.get_meta("floor_cell_z", 0))
		cells["%d,%d" % [cell_x, cell_z]] = Vector2i(cell_x, cell_z)
	return cells

func _is_ground_perimeter_edge(cells: Dictionary, cell_x: int, cell_z: int, edge_index: int) -> bool:
	var neighbor_key := ""
	match posmod(edge_index, 4):
		0:
			neighbor_key = "%d,%d" % [cell_x + 1, cell_z]
		1:
			neighbor_key = "%d,%d" % [cell_x, cell_z + 1]
		2:
			neighbor_key = "%d,%d" % [cell_x - 1, cell_z]
		_:
			neighbor_key = "%d,%d" % [cell_x, cell_z - 1]
	return not cells.has(neighbor_key)

func _find_mezzanine_air_wall(root: Node3D, story_level: int, view_layer: int, cell_x: int, cell_z: int, edge_index: int) -> Node3D:
	for child in root.get_children():
		if not child is Node3D:
			continue
		var node := child as Node3D
		if node.scene_file_path != WALL_SCENE_PATH:
			continue
		if not bool(node.get_meta("air_wall", false)):
			continue
		if _normalize_story_level(node.get_meta("story_level", 1)) != story_level:
			continue
		if int(node.get_meta("build_view_layer", 0)) != view_layer:
			continue
		if int(node.get_meta("mezzanine_edge_cell_x", -999999)) != cell_x:
			continue
		if int(node.get_meta("mezzanine_edge_cell_z", -999999)) != cell_z:
			continue
		if int(node.get_meta("mezzanine_edge_index", -1)) != edge_index:
			continue
		return node
	return null

func _remove_stale_mezzanine_air_walls(root: Node3D, story_level: int, ground_cells: Dictionary) -> void:
	for child in root.get_children():
		if not child is Node3D:
			continue
		var node := child as Node3D
		if not bool(node.get_meta("auto_mezzanine_air_wall", false)):
			continue
		if _normalize_story_level(node.get_meta("story_level", 1)) != story_level:
			continue
		var cell_x := int(node.get_meta("mezzanine_edge_cell_x", 0))
		var cell_z := int(node.get_meta("mezzanine_edge_cell_z", 0))
		var edge_index := int(node.get_meta("mezzanine_edge_index", 0))
		if not _is_ground_perimeter_edge(ground_cells, cell_x, cell_z, edge_index):
			node.queue_free()

func _spawn_mezzanine_air_wall(
	root: Node3D,
	grid_map: GridMap,
	wall_scene: PackedScene,
	story_level: int,
	view_layer: int,
	cell: Vector2i,
	edge_index: int,
	cell_size: Vector3,
	wall_thickness: float,
	wall_center_y: float
) -> void:
	var new_wall := wall_scene.instantiate()
	if not new_wall is Node3D:
		if new_wall:
			new_wall.queue_free()
		return
	var wall_node := new_wall as Node3D
	root.add_child(wall_node)
	var local_pos := grid_map.map_to_local(Vector3i(cell.x, 0, cell.y))
	local_pos += _get_wall_edge_offset(cell_size, edge_index, wall_thickness)
	var world_pos := grid_map.to_global(local_pos)
	world_pos.y = wall_center_y
	var base_yaw := _get_wall_edge_base_yaw(edge_index)
	wall_node.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(base_yaw)), world_pos)
	if wall_node is Node:
		wall_node.set_meta("air_wall", true)
		wall_node.set_meta("auto_mezzanine_air_wall", true)
		wall_node.set_meta("air_wall_height", StoryLevels.MEZZANINE_WALL_HEIGHT)
		wall_node.set_meta("build_view_layer", view_layer)
		wall_node.set_meta("story_level", story_level)
		wall_node.set_meta("mezzanine_edge_cell_x", cell.x)
		wall_node.set_meta("mezzanine_edge_cell_z", cell.y)
		wall_node.set_meta("mezzanine_edge_index", edge_index)
		wall_node.set_meta("logical_length_scale", _get_wall_length_scale(cell_size))
	if wall_node.has_method("refresh_diagonal_fit"):
		wall_node.call("refresh_diagonal_fit")
	if root.has_method("register_runtime_layer_node"):
		root.call("register_runtime_layer_node", wall_node)

func clone_story_floors_from_reference(root: Node3D, grid_map: GridMap, floor_scene: PackedScene, source_story: int, target_story: int) -> int:
	if not root or not grid_map or not floor_scene:
		return 0
	var source_story_level := _normalize_story_level(source_story)
	var target_story_level := _normalize_story_level(target_story)
	if source_story_level == target_story_level:
		return 0
	var scene_path := floor_scene.resource_path
	var templates: Array[Node3D] = []
	for child in root.get_children():
		if not child is Node3D:
			continue
		var node := child as Node3D
		if not bool(node.get_meta("cell_line_unit", false)):
			continue
		if _normalize_story_level(node.get_meta("story_level", 1)) != source_story_level:
			continue
		if StoryLevels.normalize_floor_kind(node.get_meta("floor_kind", "ground")) == "mezzanine_floor":
			continue
		if StoryLevels.normalize_floor_kind(node.get_meta("floor_kind", "ground")) != "ground":
			continue
		templates.append(node)
	if templates.is_empty():
		return 0
	var cloned := 0
	var placed_cells_by_kind := {}
	for source_unit in templates:
		var floor_kind := StoryLevels.normalize_floor_kind(source_unit.get_meta("floor_kind", "ground"))
		var cell := Vector3i(int(source_unit.get_meta("floor_cell_x", 0)), 0, int(source_unit.get_meta("floor_cell_z", 0)))
		var layer := int(source_unit.get_meta("build_view_layer", StoryLevels.get_floor_build_view_layer(floor_kind)))
		if _find_existing_cell_line_unit(root, scene_path, cell, target_story_level, layer, floor_kind):
			continue
		var new_unit := floor_scene.instantiate()
		if not new_unit is Node3D:
			new_unit.queue_free()
			continue
		var unit_node := new_unit as Node3D
		root.add_child(unit_node)
		unit_node.set_meta("story_level", target_story_level)
		unit_node.set_meta("floor_kind", floor_kind)
		restore_floor_unit(unit_node, grid_map, layer, cell)
		if root.has_method("register_built_floor_unit"):
			root.call("register_built_floor_unit", cell, unit_node, target_story_level, floor_kind)
		if root.has_method("register_runtime_layer_node"):
			root.call("register_runtime_layer_node", unit_node)
		if not placed_cells_by_kind.has(floor_kind):
			placed_cells_by_kind[floor_kind] = [] as Array[Vector3i]
		(placed_cells_by_kind[floor_kind] as Array).append(cell)
		cloned += 1
	for floor_kind in placed_cells_by_kind.keys():
		var cells: Array = placed_cells_by_kind[floor_kind]
		if root.has_method("register_built_floor_cells"):
			root.call("register_built_floor_cells", cells, target_story_level, str(floor_kind))
	return cloned

func restore_floor_unit(unit_node: Node3D, grid_map: GridMap, layer: int, cell: Vector3i) -> void:
	if not unit_node or not grid_map:
		return
	var story_level := _normalize_story_level(unit_node.get_meta("story_level", 1))
	var floor_kind := StoryLevels.normalize_floor_kind(unit_node.get_meta("floor_kind", "ground"))
	_sync_floor_unit_with_grid_map(unit_node, grid_map, floor_kind)
	var world_pos := CellLinePlacementScript.cell_center_world(grid_map, cell, _get_floor_kind_y_for_story(grid_map, story_level, floor_kind))
	if floor_kind == "ceiling":
		world_pos.y += grid_map.cell_size.y * 0.5
	unit_node.global_transform = Transform3D(Basis.IDENTITY, world_pos)
	unit_node.set_meta("build_view_layer", layer)
	unit_node.set_meta("story_level", story_level)
	unit_node.set_meta("floor_kind", floor_kind)
	unit_node.set_meta("cell_line_unit", true)
	unit_node.set_meta("floor_cell_x", cell.x)
	unit_node.set_meta("floor_cell_z", cell.z)
	unit_node.set_meta("revealable", StoryLevels.is_revealable_floor_kind(floor_kind))
	_ensure_floor_unit_selection_body(unit_node, grid_map, story_level, layer, floor_kind, cell)
	if floor_kind == "ceiling":
		_ensure_ceiling_light(unit_node, grid_map)

func _ensure_ceiling_light(unit_node: Node3D, grid_map: GridMap) -> void:
	if not unit_node or not grid_map:
		return
	var light := unit_node.get_node_or_null("CeilingLight") as OmniLight3D
	if not light:
		light = OmniLight3D.new()
		light.name = "CeilingLight"
		light.light_color = CEILING_LIGHT_COLOR
		var cell_span := maxf(maxf(grid_map.cell_size.x, grid_map.cell_size.z), 1.0)
		light.omni_range = maxf(cell_span * 2.35, 2.6)
		light.omni_attenuation = 0.72
		light.shadow_enabled = false
		light.position = Vector3(0.0, -grid_map.cell_size.y * 0.52, 0.0)
		unit_node.add_child(light)
	var cell_span := maxf(maxf(grid_map.cell_size.x, grid_map.cell_size.z), 1.0)
	light.omni_range = maxf(cell_span * 2.35, 2.6)
	light.omni_attenuation = 0.72
	light.position = Vector3(0.0, -grid_map.cell_size.y * 0.52, 0.0)
	light.set_meta("ceiling_light", true)
	light.set_meta("ceiling_light_energy", CEILING_LIGHT_ENERGY)
	if light.get_tree() and light.get_tree().current_scene and light.get_tree().current_scene.has_method("_update_indoor_lighting_for_camera"):
		if light.get_tree().current_scene.get("camera_mode_name") == "first_person":
			light.light_energy = CEILING_LIGHT_ENERGY
		else:
			light.light_energy = 0.0
	else:
		light.light_energy = 0.0

func _ensure_floor_unit_selection_body(unit_node: Node3D, grid_map: GridMap, story_level: int, layer: int, floor_kind: String, cell: Vector3i) -> void:
	if not unit_node or not grid_map:
		return
	var body := unit_node.get_node_or_null("FloorSelectionBody") as StaticBody3D
	if not body:
		body = StaticBody3D.new()
		body.name = "FloorSelectionBody"
		unit_node.add_child(body)
	body.set_meta("build_view_layer", layer)
	body.set_meta("story_level", story_level)
	body.set_meta("floor_kind", floor_kind)
	body.set_meta("cell_line_unit", true)
	body.set_meta("floor_cell_x", cell.x)
	body.set_meta("floor_cell_z", cell.z)
	body.set_meta("revealable", StoryLevels.is_revealable_floor_kind(floor_kind))
	body.input_ray_pickable = true
	body.collision_layer = 1
	body.collision_mask = 1
	var collision_shape := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		body.add_child(collision_shape)
	var shape := BoxShape3D.new()
	shape.size = Vector3(grid_map.cell_size.x * 0.94, maxf(grid_map.cell_size.y, 0.08), grid_map.cell_size.z * 0.94)
	collision_shape.shape = shape
	if floor_kind == "ceiling":
		body.position = Vector3(0.0, -grid_map.cell_size.y * 0.42, 0.0)
	else:
		body.position = Vector3.ZERO

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found:
			return found
	return null

func _get_node_visual_bounds(node: Node) -> AABB:
	var state := {
		"has_bounds": false,
		"bounds": AABB(),
	}
	_collect_visual_bounds(node, state)
	return state["bounds"] if bool(state["has_bounds"]) else AABB()

func _collect_visual_bounds(node: Node, state: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			var bounds := _transform_visual_aabb(mesh_instance.global_transform, mesh_instance.mesh.get_aabb())
			if bool(state["has_bounds"]):
				state["bounds"] = (state["bounds"] as AABB).merge(bounds)
			else:
				state["bounds"] = bounds
				state["has_bounds"] = true
	for child in node.get_children():
		_collect_visual_bounds(child, state)

func _transform_visual_aabb(transform: Transform3D, source: AABB) -> AABB:
	var result := AABB(transform * source.position, Vector3.ZERO)
	for x in [0.0, source.size.x]:
		for y in [0.0, source.size.y]:
			for z in [0.0, source.size.z]:
				result = result.expand(transform * (source.position + Vector3(x, y, z)))
	return result

func _place_or_update_line_building(root: Node3D, grid_map: GridMap) -> void:
	var scene_to_spawn = _get_effective_line_scene(current_building["scene"] as PackedScene)
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
	if _is_trench_family_scene(scene_to_spawn):
		_place_trench_units(root, grid_map, scene_to_spawn, start_vec, point)
		current_building["line_start_point"] = null
		_reset_line_preview()
		print("放置了: ", scene_to_spawn.resource_path)
		return
	var new_building = scene_to_spawn.instantiate()
	root.add_child(new_building)
	if new_building is Node3D:
		_apply_line_segment(new_building as Node3D, start_vec, point, grid_map)
	if new_building is Node:
		(new_building as Node).set_meta("build_view_layer", int(current_building.get("view_layer", 0)))
		(new_building as Node).set_meta("story_level", get_active_story_level())
	if new_building is Node3D and root.has_method("register_runtime_layer_node"):
		root.call("register_runtime_layer_node", new_building as Node3D)
	current_building["line_start_point"] = null
	_reset_line_preview()
	print("放置了: ", scene_to_spawn.resource_path)

func _try_attach_hinges_to_door(node: Node) -> void:
	if not node:
		return
	# Load the hinge script once
	var hinge_script := load("res://scripts/controllers/hinged_door_panel.gd")
	# Attach to MeshInstance3D children that look like door panels
	for child in node.get_children():
		if child is MeshInstance3D:
			var lname := child.name.to_lower()
			if lname.find("door") != -1 or lname.find("panel") != -1 or lname.find("leaf") != -1:
				child.set_script(hinge_script)
				# ensure the mesh can be interacted with at runtime
				child.set_meta("build_view_layer", int(current_building.get("view_layer", 0)))
				if child is CollisionObject3D:
					(child as CollisionObject3D).input_ray_pickable = true
				else:
					# try to add a simple StaticBody pickable child if needed
					var body = child.get_node_or_null("_door_pick_body") as StaticBody3D
					if not body:
						body = StaticBody3D.new()
						body.name = "_door_pick_body"
						child.add_child(body)
						body.owner = child.owner
						body.input_ray_pickable = true
		# recurse
		_try_attach_hinges_to_door(child)

func _is_active_door_building() -> bool:
	if not current_building["is_active"]:
		return false
	var scene := current_building["scene"] as PackedScene
	return scene != null and scene.resource_path == DOOR_SCENE_PATH

func _get_door_variant_config() -> Dictionary:
	if DOOR_VARIANTS.is_empty():
		return {}
	var index := clampi(current_door_variant_index, 0, DOOR_VARIANTS.size() - 1)
	return DOOR_VARIANTS[index]

func _get_door_variant_scene() -> PackedScene:
	var variant := _get_door_variant_config()
	var scene_path := str(variant.get("scene_path", ""))
	if scene_path == "":
		return null
	return load(scene_path) as PackedScene

func _is_door_scene_path(scene_path: String) -> bool:
	if scene_path == DOOR_SCENE_PATH:
		return true
	for variant in DOOR_VARIANTS:
		if scene_path == str(variant.get("scene_path", "")):
			return true
	return false

func _is_placed_door_scene_path(scene_path: String) -> bool:
	for variant in DOOR_VARIANTS:
		if scene_path == str(variant.get("scene_path", "")):
			return true
	return false

func _is_wall_or_door_scene_path(scene_path: String) -> bool:
	return scene_path == WALL_SCENE_PATH or _is_placed_door_scene_path(scene_path)

func _clear_door_preview_instance() -> void:
	if door_preview_instance and is_instance_valid(door_preview_instance):
		door_preview_instance.queue_free()
	door_preview_instance = null

func _ensure_door_preview_instance(root: Node3D) -> void:
	if door_preview_instance and is_instance_valid(door_preview_instance):
		return
	_rebuild_door_preview_instance(root)

func _rebuild_door_preview_instance(root: Node3D) -> void:
	_clear_door_preview_instance()
	var scene := _get_door_variant_scene()
	if not scene or not root:
		return
	var instance := scene.instantiate()
	if not instance is Node3D:
		instance.queue_free()
		return
	door_preview_instance = instance as Node3D
	root.add_child(door_preview_instance)
	if not door_preview_instance.is_in_group(DOOR_PREVIEW_GROUP):
		door_preview_instance.add_to_group(DOOR_PREVIEW_GROUP)
	_disable_door_preview_physics(door_preview_instance)
	_set_door_preview_validity(bool(current_building.get("is_placeable", true)))

func _sync_door_preview_instance(preview_mesh: Node3D) -> void:
	if not door_preview_instance or not preview_mesh:
		return
	door_preview_instance.global_transform = preview_mesh.global_transform
	if door_preview_instance.has_method("refresh_diagonal_fit"):
		door_preview_instance.call("refresh_diagonal_fit")

func _disable_door_preview_physics(node: Node) -> void:
	if node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
		collision_object.input_ray_pickable = false
	for child in node.get_children():
		_disable_door_preview_physics(child)

func _set_door_preview_validity(is_valid: bool) -> void:
	if not door_preview_instance:
		return
	var color := PREVIEW_VALID_COLOR if is_valid else PREVIEW_INVALID_COLOR
	_apply_preview_tint_recursive(door_preview_instance, color)

func _apply_preview_tint_recursive(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh_instance.material_override = material
	for child in node.get_children():
		_apply_preview_tint_recursive(child, color)

func _place_door_building(root: Node3D, grid_map: GridMap, preview_node: Node3D) -> void:
	var scene_to_spawn := _get_door_variant_scene()
	if not scene_to_spawn or not preview_node:
		return
	var new_building := scene_to_spawn.instantiate()
	if not new_building:
		return
	if new_building is Node:
		var variant := _get_door_variant_config()
		(new_building as Node).set_meta("build_view_layer", int(current_building.get("view_layer", 0)))
		(new_building as Node).set_meta("story_level", get_active_story_level())
		(new_building as Node).set_meta("door_variant_id", str(variant.get("id", "single")))
		(new_building as Node).set_meta("logical_length_scale", _get_wall_length_scale(grid_map.cell_size))
	root.add_child(new_building)
	if new_building is Node3D:
		(new_building as Node3D).global_transform = preview_node.global_transform
	var snap_target := current_building.get("surface_snap_target", null) as Node
	if snap_target and new_building is Node:
		(new_building as Node).set_meta("host_wall_path", snap_target.get_path())
	if new_building.has_method("finalize_after_placement"):
		new_building.call_deferred("finalize_after_placement")
	elif new_building.has_method("refresh_diagonal_fit"):
		new_building.call("refresh_diagonal_fit")
	if new_building is Node3D and root.has_method("register_runtime_layer_node"):
		root.call("register_runtime_layer_node", new_building as Node3D)
	_invalidate_preview_cache()
	print("放置了: ", scene_to_spawn.resource_path, " (", get_door_variant_label(), ")")

func _place_trench_units(root: Node3D, grid_map: GridMap, scene_to_spawn: PackedScene, start_point: Vector3, end_point: Vector3) -> void:
	if not grid_map:
		return
	var unit_cells := CellLinePlacementScript.get_dominant_axis_cells(grid_map, start_point, end_point)
	var axis := str(unit_cells.get("axis", "x"))
	var cells := unit_cells.get("cells", []) as Array
	var axis_sign := int(unit_cells.get("sign", 1))
	for cell in cells:
		var cell_vec := cell as Vector3i
		if _find_existing_trench_unit(root, cell_vec, axis, int(current_building.get("view_layer", 0)), get_active_story_level()):
			continue
		var new_unit := scene_to_spawn.instantiate()
		root.add_child(new_unit)
		if new_unit is Node3D:
			var unit_node := new_unit as Node3D
			var center := _trench_cell_to_world(grid_map, cell_vec)
			var direction := Vector3.RIGHT * float(axis_sign) if axis == "x" else Vector3.BACK * float(axis_sign)
			var length := grid_map.cell_size.x if axis == "x" else grid_map.cell_size.z
			_apply_line_segment(unit_node, center - direction * length * 0.5, center + direction * length * 0.5, grid_map)
			unit_node.set_meta("trench_unit", true)
			unit_node.set_meta("trench_axis", axis)
			unit_node.set_meta("trench_sign", axis_sign)
			unit_node.set_meta("trench_cell_x", cell_vec.x)
			unit_node.set_meta("trench_cell_z", cell_vec.z)
		if new_unit is Node:
			(new_unit as Node).set_meta("build_view_layer", int(current_building.get("view_layer", 0)))
			(new_unit as Node).set_meta("story_level", get_active_story_level())
		if new_unit is Node3D and root.has_method("register_runtime_layer_node"):
			root.call("register_runtime_layer_node", new_unit as Node3D)
	_refresh_trench_wall_visibility(root)

func _get_trench_unit_cells(grid_map: GridMap, start_point: Vector3, end_point: Vector3) -> Dictionary:
	return CellLinePlacementScript.get_dominant_axis_cells(grid_map, start_point, end_point)

func _trench_cell_to_world(grid_map: GridMap, cell: Vector3i) -> Vector3:
	return CellLinePlacementScript.cell_center_world(grid_map, cell, _get_current_layer_plane_y(grid_map))

func _find_existing_trench_unit(root: Node3D, cell: Vector3i, axis: String, layer: int, story_level: int) -> Node3D:
	for child in root.get_children():
		if not child is Node3D:
			continue
		var node := child as Node3D
		if not _is_trench_family_path(node.scene_file_path):
			continue
		if not bool(node.get_meta("trench_unit", false)):
			continue
		if int(node.get_meta("story_level", 1)) != story_level:
			continue
		if int(node.get_meta("build_view_layer", 0)) != layer:
			continue
		if str(node.get_meta("trench_axis", "")) != axis:
			continue
		if int(node.get_meta("trench_cell_x", 0)) == cell.x and int(node.get_meta("trench_cell_z", 0)) == cell.z:
			return node
	return null

func _refresh_trench_wall_visibility(root: Node3D) -> void:
	var x_cells := {}
	var z_cells := {}
	var trench_units: Array[Node3D] = []
	for child in root.get_children():
		if not child is Node3D:
			continue
		var node := child as Node3D
		if not _is_trench_family_path(node.scene_file_path) or not bool(node.get_meta("trench_unit", false)):
			continue
		trench_units.append(node)
		var story := int(node.get_meta("story_level", 1))
		var layer := int(node.get_meta("build_view_layer", 0))
		var key := _trench_cell_key(story, layer, int(node.get_meta("trench_cell_x", 0)), int(node.get_meta("trench_cell_z", 0)))
		if str(node.get_meta("trench_axis", "")) == "x":
			x_cells[key] = true
		elif str(node.get_meta("trench_axis", "")) == "z":
			z_cells[key] = true
	for node in trench_units:
		var story := int(node.get_meta("story_level", 1))
		var layer := int(node.get_meta("build_view_layer", 0))
		var cell_x := int(node.get_meta("trench_cell_x", 0))
		var cell_z := int(node.get_meta("trench_cell_z", 0))
		var axis := str(node.get_meta("trench_axis", ""))
		var axis_sign := int(node.get_meta("trench_sign", 1))
		var left_visible := true
		var right_visible := true
		if axis == "x":
			var has_crossing_z := z_cells.has(_trench_cell_key(story, layer, cell_x, cell_z))
			var open_plus_z := has_crossing_z and z_cells.has(_trench_cell_key(story, layer, cell_x, cell_z + 1))
			var open_minus_z := has_crossing_z and z_cells.has(_trench_cell_key(story, layer, cell_x, cell_z - 1))
			if axis_sign >= 0:
				left_visible = not open_plus_z
				right_visible = not open_minus_z
			else:
				left_visible = not open_minus_z
				right_visible = not open_plus_z
		elif axis == "z":
			var has_crossing_x := x_cells.has(_trench_cell_key(story, layer, cell_x, cell_z))
			var open_plus_x := has_crossing_x and x_cells.has(_trench_cell_key(story, layer, cell_x + 1, cell_z))
			var open_minus_x := has_crossing_x and x_cells.has(_trench_cell_key(story, layer, cell_x - 1, cell_z))
			if axis_sign >= 0:
				left_visible = not open_minus_x
				right_visible = not open_plus_x
			else:
				left_visible = not open_plus_x
				right_visible = not open_minus_x
		if node.has_method("set_side_walls"):
			node.call("set_side_walls", left_visible, right_visible)
		if node.scene_file_path == CEILING_TRAY_SCENE_PATH and node.has_method("set_bottom_span"):
			var span := _get_tray_bottom_span(story, layer, cell_x, cell_z, axis, axis_sign, x_cells, z_cells)
			node.call("set_bottom_span", float(span.x), float(span.y))

func _trench_cell_key(story_level: int, layer: int, cell_x: int, cell_z: int) -> String:
	return CellLinePlacementScript.unit_cell_key(story_level, layer, cell_x, cell_z)

func _get_tray_bottom_span(story_level: int, layer: int, cell_x: int, cell_z: int, axis: String, axis_sign: int, x_cells: Dictionary, z_cells: Dictionary) -> Vector2:
	var has_local_minus := false
	var has_local_plus := false
	if axis == "x":
		has_local_minus = x_cells.has(_trench_cell_key(story_level, layer, cell_x - axis_sign, cell_z))
		has_local_plus = x_cells.has(_trench_cell_key(story_level, layer, cell_x + axis_sign, cell_z))
	elif axis == "z":
		has_local_minus = z_cells.has(_trench_cell_key(story_level, layer, cell_x, cell_z - axis_sign))
		has_local_plus = z_cells.has(_trench_cell_key(story_level, layer, cell_x, cell_z + axis_sign))
	if has_local_minus and not has_local_plus:
		return Vector2(0.0, 0.5)
	if has_local_plus and not has_local_minus:
		return Vector2(-0.5, 0.0)
	return Vector2(-0.5, 0.5)

func _get_effective_line_scene(scene: PackedScene) -> PackedScene:
	if scene and scene.resource_path == TRENCH_SCENE_PATH and int(current_building.get("view_layer", 0)) == 1:
		return load(CEILING_TRAY_SCENE_PATH) as PackedScene
	return scene

func _is_trench_family_scene(scene: PackedScene) -> bool:
	return scene and _is_trench_family_path(scene.resource_path)

func _is_trench_family_path(scene_path: String) -> bool:
	return scene_path == TRENCH_SCENE_PATH or scene_path == CEILING_TRAY_SCENE_PATH

func _try_get_line_cursor_position(root: Node3D, grid_map: GridMap, out_points: Array[Vector3]) -> bool:
	var camera = root.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if not camera:
		return false
	var mouse_pos = root.get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	var plane_y := _get_current_layer_plane_y(grid_map)
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
	var plane_y := _get_current_layer_plane_y(grid_map)
	var scene := current_building.get("scene") as PackedScene
	if scene and scene.resource_path == TRENCH_SCENE_PATH:
		var cell := grid_map.local_to_map(grid_map.to_local(point))
		cell.y = 0
		var snapped_point := grid_map.to_global(grid_map.map_to_local(cell))
		snapped_point.y = _get_current_layer_plane_y(grid_map)
		return snapped_point
	var step_x := maxf(0.25, grid_map.cell_size.x * 0.5)
	var step_z := maxf(0.25, grid_map.cell_size.z * 0.5)
	return Vector3(
		round(point.x / step_x) * step_x,
		plane_y,
		round(point.z / step_z) * step_z
	)

func _get_layer_plane_y(grid_map: GridMap, layer: int = -1) -> float:
	if layer < 0:
		layer = int(current_building.get("view_layer", 0))
	var story_level := get_active_story_level()
	if not grid_map:
		return StoryLevels.get_view_layer_y(story_level, layer)
	match layer:
		1:
			return StoryLevels.get_mezzanine_trench_y(story_level, _get_l1_floor_top_y(grid_map))
		-1:
			return _get_story_floor_top_y(grid_map) + float(StoryLevels.VIEW_LAYER_OFFSET.get(-1, -1.0))
		_:
			return _get_story_floor_top_y(grid_map)

func _get_current_layer_plane_y(grid_map: GridMap = null) -> float:
	if grid_map:
		return _get_layer_plane_y(grid_map)
	var layer := int(current_building.get("view_layer", 0))
	var story_level := get_active_story_level()
	return StoryLevels.get_view_layer_y(story_level, layer)

func _get_story_floor_top_y(grid_map: GridMap) -> float:
	return _get_floor_top_y(grid_map)

func _get_floor_kind_y(grid_map: GridMap, floor_kind: String) -> float:
	return _get_floor_kind_y_for_story(grid_map, get_active_story_level(), floor_kind)

func _get_floor_kind_y_for_story(grid_map: GridMap, story_level: int, floor_kind: String) -> float:
	return StoryLevels.get_floor_kind_y(story_level, floor_kind, _get_l1_floor_top_y(grid_map))

func _is_active_floor_building() -> bool:
	if not current_building["is_active"]:
		return false
	var scene := current_building["scene"] as PackedScene
	return scene != null and scene.resource_path == FLOOR_SCENE_PATH

func _cycle_floor_kind(direction: int) -> void:
	current_building["floor_kind"] = StoryLevels.cycle_floor_kind(get_floor_kind(), direction)

func _update_line_preview(preview_mesh: MeshInstance3D, start_point: Vector3, end_point: Vector3, grid_map: GridMap = null) -> void:
	_apply_line_segment(preview_mesh, start_point, end_point, grid_map)
	preview_mesh.visible = true

func _apply_line_segment(target: Node3D, start_point: Vector3, end_point: Vector3, grid_map: GridMap = null) -> void:
	var plane_y := _get_current_layer_plane_y(grid_map)
	var flat_start := Vector3(start_point.x, plane_y, start_point.z)
	var flat_end := Vector3(end_point.x, plane_y, end_point.z)
	var flat_segment := flat_end - flat_start
	var length := maxf(flat_segment.length(), PIPE_PREVIEW_MIN_LENGTH)
	var midpoint := flat_start + flat_segment * 0.5
	midpoint.y = plane_y + _get_line_vertical_offset()
	var direction := flat_segment.normalized() if flat_segment.length() > 0.001 else Vector3.RIGHT
	target.global_position = midpoint
	target.look_at(midpoint + direction, Vector3.UP, true)
	target.rotate_object_local(Vector3.RIGHT, deg_to_rad(-90.0))
	target.scale = Vector3(1.0, length, 1.0)

func _get_line_vertical_offset() -> float:
	var scene := _get_effective_line_scene(current_building.get("scene") as PackedScene)
	if scene and scene.resource_path == CEILING_TRAY_SCENE_PATH:
		return 0.055
	if scene and scene.resource_path == TRENCH_SCENE_PATH:
		return 0.45
	return 0.0

func _reset_line_preview() -> void:
	current_building["line_start_point"] = null
	current_building["wall_line_dragging"] = false
	current_building["wall_line_anchor"] = null
	var preview = current_building.get("preview") as MeshInstance3D
	if preview:
		preview.visible = false
