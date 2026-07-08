extends RefCounted

class_name SelectionController

const OPERATION_BUTTON_SIZE := Vector2(32.0, 32.0)
const OPERATION_PANEL_SIZE := Vector2(100.0, 86.0)
const OPERATION_PANEL_GAP := 10.0
const OPERATION_PANEL_TOP_OFFSET := 18.0
const MOVE_BUTTON_NAME := "btn_move"
const SELECTION_FRAME_NAME := "SelectionFrame"
const MOVE_ORIGINAL_FRAME_NAME := "MoveOriginalFrame"
const SELECTION_FRAME_COLOR := Color(0.2, 1.0, 0.35, 1.0)
const MOVE_ORIGINAL_FRAME_COLOR := Color(0.25, 0.62, 1.0, 1.0)
const FRAME_PADDING := 0.035
const DASH_LENGTH := 0.16
const DASH_GAP := 0.09

var selected_object: Node3D = null
var selected_module_object: Node3D = null
var opened_cabinet: Node = null
var move_button: Button = null
var selection_frame: MeshInstance3D = null
var move_original_frame: MeshInstance3D = null
var move_mode_active := false
var move_target: Node3D = null
var move_original_transform := Transform3D.IDENTITY
var move_original_bounds := AABB()
var move_original_cell_offset := Vector3.ZERO
var last_root: Node3D = null
var last_operation_panel: Control = null
var selected_bounds_cache := AABB()
var selection_frame_target: Node3D = null
var selection_frame_dirty := false
var operation_icon_cache := {}

func initialize(operation_panel: Control, module_panel: Control) -> void:
	if operation_panel:
		_configure_operation_panel(operation_panel)
		operation_panel.visible = false
	_hide_module_panel(module_panel)

func bind_buttons(btn_rotate: Button, btn_delete: Button, target: Object, rotate_method: StringName, delete_method: StringName) -> void:
	if btn_rotate:
		btn_rotate.pressed.connect(Callable(target, rotate_method))
	if btn_delete:
		btn_delete.pressed.connect(Callable(target, delete_method))

func has_visible_panel(operation_panel: Control, module_panel: Control) -> bool:
	var preview_overlay := _get_preview_overlay(module_panel)
	return (operation_panel and operation_panel.visible) or (module_panel and module_panel.visible) or (preview_overlay and preview_overlay.visible)

func is_move_mode_active() -> bool:
	return move_mode_active

func handle_escape(root: Node, operation_panel: Control, module_panel: Control) -> bool:
	if move_mode_active:
		_cancel_move_mode(root as Node3D, operation_panel)
		root.get_viewport().set_input_as_handled()
		return true
	if operation_panel and operation_panel.visible:
		operation_panel.visible = false
		_clear_selection_frame()
		selected_object = null
		root.get_viewport().set_input_as_handled()
		return true
	if module_panel and module_panel.visible:
		_hide_module_panel(module_panel)
		selected_module_object = null
		opened_cabinet = null
		root.get_viewport().set_input_as_handled()
		return true
	var preview_overlay := _get_preview_overlay(module_panel)
	if preview_overlay and preview_overlay.visible:
		if module_panel and module_panel.has_method("close_for_current_target"):
			module_panel.call("close_for_current_target")
		else:
			preview_overlay.call("hide_preview")
		root.get_viewport().set_input_as_handled()
		return true
	return false

func handle_unhandled_input(root: Node, event: InputEvent, operation_panel: Control, module_panel: Control) -> bool:
	if event is InputEventKey and event.pressed and event.keycode == Key.KEY_ESCAPE:
		return handle_escape(root, operation_panel, module_panel)
	if move_mode_active and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_confirm_move_mode(root as Node3D, operation_panel)
			root.get_viewport().set_input_as_handled()
			return true
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_move_mode(root as Node3D, operation_panel)
			root.get_viewport().set_input_as_handled()
			return true
	return false

func update_runtime_visuals(root: Node3D, grid_map: GridMap, operation_panel: Control = null) -> void:
	if move_mode_active:
		_update_move_preview(root, grid_map)
		return
	if selected_object and is_instance_valid(selected_object):
		_show_selection_frame(root, selected_object)
		if operation_panel and operation_panel.visible:
			var camera := root.get_node_or_null("CameraPivot/Camera3D") as Camera3D
			if camera:
				_position_operation_panel(selected_object, operation_panel, camera)
	else:
		_clear_selection_frame()

func handle_left_click_module(root: Node3D, block_scene: PackedScene, module_panel: Panel, allow_module_pick: bool = true) -> bool:
	if not block_scene:
		push_warning("SelectionController.handle_left_click_module: block_scene is not assigned.")
		return false
	var camera = root.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if not camera:
		return false
	var mouse_pos = root.get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = root.get_world_3d().direct_space_state.intersect_ray(query)

	if result:
		var collider = result.collider as Node3D
		var toggle_target := _find_toggle_open_target(collider)
		if toggle_target:
			toggle_target.call("toggle_open", camera.global_position)
			root.get_viewport().set_input_as_handled()
			return true
		var cabinet_target := _find_cabinet_panel_target(collider)
		if cabinet_target:
			selected_module_object = collider
			_close_opened_cabinet(cabinet_target)
			opened_cabinet = cabinet_target
			_hide_module_panel(module_panel)
			cabinet_target.call("open_with_panel", module_panel)
			root.get_viewport().set_input_as_handled()
			return true
		if allow_module_pick and collider and collider.scene_file_path == block_scene.resource_path:
			selected_module_object = collider
			_close_opened_cabinet(null)
			show_module_panel(collider, module_panel)
			root.get_viewport().set_input_as_handled()
			return true
	return false

func _close_opened_cabinet(except_cabinet: Node) -> void:
	if opened_cabinet and opened_cabinet != except_cabinet and opened_cabinet.has_method("close_cabinet"):
		opened_cabinet.call("close_cabinet")
	if opened_cabinet != except_cabinet:
		opened_cabinet = null

func _find_toggle_open_target(node: Node) -> Node:
	var door_wrapper := _find_door_wrapper(node)
	if door_wrapper and door_wrapper.has_method("toggle_open"):
		return door_wrapper
	var current := node
	while current:
		if current.has_method("toggle_open") and _is_runtime_interactable(current):
			return current
		current = current.get_parent()
	return null

func _find_cabinet_panel_target(node: Node) -> Node:
	var current := node
	while current:
		if current.has_method("open_with_panel") and _is_runtime_interactable(current):
			return current
		current = current.get_parent()
	return null

func _is_runtime_interactable(node: Node) -> bool:
	if not node is Node3D:
		return false
	var node_3d := node as Node3D
	if not node_3d.is_visible_in_tree():
		return false
	if node_3d.has_meta("door_variant_id"):
		return true
	if node_3d is StaticBody3D:
		var body_script: Variant = (node_3d as StaticBody3D).get_script()
		if body_script and str(body_script.resource_path).ends_with("imported_door_wrapper.gd"):
			return node_3d.has_meta("build_view_layer")
	return node_3d.has_meta("build_view_layer")

func _find_door_wrapper(node: Node) -> Node3D:
	var current := node
	while current:
		if current is StaticBody3D:
			var body_script: Variant = (current as StaticBody3D).get_script()
			if body_script and str(body_script.resource_path).ends_with("imported_door_wrapper.gd"):
				return current as Node3D
		if current is Node3D and current.has_meta("door_variant_id"):
			return current as Node3D
		current = current.get_parent()
	return null

func _find_operation_target(node: Node) -> Node3D:
	var door_wrapper := _find_door_wrapper(node)
	if door_wrapper:
		return door_wrapper
	var current := node
	while current:
		if current.has_meta("cell_line_unit") and current.get_parent() is Node3D and current.get_parent().has_meta("cell_line_unit"):
			return current.get_parent() as Node3D
		if current is Node3D and _is_runtime_interactable(current):
			return current as Node3D
		current = current.get_parent()
	return null

func handle_right_click_operation(root: Node3D, grid_map: GridMap, preview_cube: MeshInstance3D, preview_wall: MeshInstance3D, preview_pipe: MeshInstance3D, operation_panel: Control) -> void:
	var camera = root.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if not camera:
		return
	var mouse_pos = root.get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var exclude_array: Array = []
	if preview_cube:
		exclude_array.append(preview_cube)
	if preview_wall:
		exclude_array.append(preview_wall)
	if preview_pipe:
		exclude_array.append(preview_pipe)
	query.exclude = exclude_array
	var result = root.get_world_3d().direct_space_state.intersect_ray(query)

	if result:
		var collider = result.collider as Node3D
		if collider == grid_map:
			return
		var operation_target := _find_operation_target(collider)
		if not operation_target:
			return
		selected_object = operation_target
		last_root = root
		last_operation_panel = operation_panel
		_refresh_selected_bounds(operation_target)
		selection_frame_dirty = true
		_show_selection_frame(root, operation_target)
		show_operation_panel(operation_target, operation_panel, camera)

func toggle_panels_on_right_click(operation_panel: Control, module_panel: Control) -> bool:
	if operation_panel and operation_panel.visible:
		operation_panel.visible = false
		if not move_mode_active:
			_clear_selection_frame()
		selected_object = null
		return true
	if module_panel and module_panel.visible:
		_hide_module_panel(module_panel)
		selected_module_object = null
		opened_cabinet = null
		return true
	var preview_overlay := _get_preview_overlay(module_panel)
	if preview_overlay and preview_overlay.visible:
		preview_overlay.call("hide_preview")
		selected_module_object = null
		opened_cabinet = null
		return true
	return false

func show_module_panel(target: Node3D, module_panel: Panel) -> void:
	if not module_panel or not target:
		return
	if module_panel.has_method("open_for_target"):
		module_panel.call("open_for_target", target)
	module_panel.visible = true

func _hide_module_panel(module_panel: Control) -> void:
	if not module_panel:
		return
	if module_panel.has_method("close_for_current_target"):
		module_panel.call("close_for_current_target")
	else:
		module_panel.visible = false
		_hide_preview_overlay(module_panel)

func _get_preview_overlay(module_panel: Control) -> Control:
	if not module_panel or not module_panel.get_tree() or not module_panel.get_tree().current_scene:
		return null
	return module_panel.get_tree().current_scene.get_node_or_null("CanvasLayer/OdfFocusPreviewOverlay") as Control

func _hide_preview_overlay(module_panel: Control) -> void:
	var preview_overlay := _get_preview_overlay(module_panel)
	if preview_overlay and preview_overlay.has_method("hide_preview"):
		preview_overlay.call("hide_preview")

func show_operation_panel(target: Node3D, operation_panel: Control, camera: Camera3D) -> void:
	if not operation_panel or not target or not camera:
		return
	_configure_operation_panel(operation_panel)
	operation_panel.visible = true
	_position_operation_panel(target, operation_panel, camera)

func _position_operation_panel(target: Node3D, operation_panel: Control, camera: Camera3D) -> void:
	var anchor_pos := _get_operation_anchor_position(target)
	var screen_pos = camera.unproject_position(anchor_pos)
	operation_panel.position = screen_pos - Vector2(operation_panel.size.x * 0.5, operation_panel.size.y + OPERATION_PANEL_TOP_OFFSET)
	operation_panel.position.x = clampf(operation_panel.position.x, 8.0, maxf(8.0, camera.get_viewport().get_visible_rect().size.x - operation_panel.size.x - 8.0))
	operation_panel.position.y = clampf(operation_panel.position.y, 8.0, maxf(8.0, camera.get_viewport().get_visible_rect().size.y - operation_panel.size.y - 8.0))

func _configure_operation_panel(operation_panel: Control) -> void:
	operation_panel.custom_minimum_size = OPERATION_PANEL_SIZE
	operation_panel.size = OPERATION_PANEL_SIZE
	operation_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var rotate_button := operation_panel.get_node_or_null("btn_rotate") as Button
	var delete_button := operation_panel.get_node_or_null("btn_delete") as Button
	move_button = operation_panel.get_node_or_null(MOVE_BUTTON_NAME) as Button
	if not move_button:
		move_button = Button.new()
		move_button.name = MOVE_BUTTON_NAME
		operation_panel.add_child(move_button)
	if not move_button.pressed.is_connected(_on_move_button_pressed):
		move_button.pressed.connect(_on_move_button_pressed)
	_configure_operation_button(move_button, "move", Color(0.14, 0.34, 0.62, 0.95), Color(0.42, 0.68, 1.0, 1.0), "移动")
	if rotate_button:
		_configure_operation_button(rotate_button, "rotate", Color(0.16, 0.28, 0.40, 0.95), Color(0.68, 0.86, 1.0, 1.0), "旋转")
	if delete_button:
		_configure_operation_button(delete_button, "delete", Color(0.60, 0.08, 0.08, 0.96), Color(1.0, 0.74, 0.74, 1.0), "删除")
	_layout_operation_buttons(rotate_button, move_button, delete_button)

func _configure_operation_button(button: Button, icon_name: String, bg_color: Color, border_color: Color, tooltip: String) -> void:
	button.text = ""
	button.icon = _get_operation_icon(icon_name)
	button.expand_icon = true
	button.tooltip_text = tooltip
	button.custom_minimum_size = OPERATION_BUTTON_SIZE
	button.size = OPERATION_BUTTON_SIZE
	button.scale = Vector2.ONE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _make_operation_button_style(bg_color, border_color, 0.0))
	button.add_theme_stylebox_override("hover", _make_operation_button_style(bg_color.lightened(0.12), border_color, 0.0))
	button.add_theme_stylebox_override("pressed", _make_operation_button_style(bg_color.darkened(0.12), border_color, 1.0))

func _get_operation_icon(icon_name: String) -> Texture2D:
	var icon_size := maxi(18, int(OPERATION_BUTTON_SIZE.x) - 10)
	var cache_key := "%s_%d" % [icon_name, icon_size]
	if operation_icon_cache.has(cache_key):
		return operation_icon_cache[cache_key]
	var image := Image.create(icon_size, icon_size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var color := Color.WHITE
	var thickness := maxf(2.0, float(icon_size) * 0.12)
	if icon_name == "move":
		_draw_move_icon(image, color, thickness)
	elif icon_name == "delete":
		_draw_delete_icon(image, color, thickness)
	else:
		_draw_rotate_icon(image, color, thickness)
	var texture := ImageTexture.create_from_image(image)
	operation_icon_cache[cache_key] = texture
	return texture

func _draw_move_icon(image: Image, color: Color, thickness: float) -> void:
	var size := image.get_width()
	var center := Vector2(size * 0.5, size * 0.5)
	var end_padding := size * 0.16
	var head := size * 0.18
	var points := [
		Vector2(center.x, end_padding),
		Vector2(size - end_padding, center.y),
		Vector2(center.x, size - end_padding),
		Vector2(end_padding, center.y),
	]
	for point in points:
		_draw_icon_line(image, center, point, color, thickness)
		var direction : Vector2 = (point - center).normalized()
		var side : Vector2 = Vector2(-direction.y, direction.x)
		_draw_icon_line(image, point, point - direction * head + side * head * 0.55, color, thickness)
		_draw_icon_line(image, point, point - direction * head - side * head * 0.55, color, thickness)

func _draw_delete_icon(image: Image, color: Color, thickness: float) -> void:
	var size := image.get_width()
	var padding := size * 0.20
	_draw_icon_line(image, Vector2(padding, padding), Vector2(size - padding, size - padding), color, thickness)
	_draw_icon_line(image, Vector2(size - padding, padding), Vector2(padding, size - padding), color, thickness)

func _draw_rotate_icon(image: Image, color: Color, thickness: float) -> void:
	var size := image.get_width()
	var center := Vector2(size * 0.5, size * 0.52)
	var radius := size * 0.32
	var start_angle := deg_to_rad(-155.0)
	var end_angle := deg_to_rad(130.0)
	var previous := center + Vector2(cos(start_angle), sin(start_angle)) * radius
	for step in range(1, 30):
		var t := float(step) / 29.0
		var angle := lerpf(start_angle, end_angle, t)
		var current := center + Vector2(cos(angle), sin(angle)) * radius
		_draw_icon_line(image, previous, current, color, thickness)
		previous = current
	var arrow_tip := center + Vector2(cos(end_angle), sin(end_angle)) * radius
	var tangent := Vector2(-sin(end_angle), cos(end_angle)).normalized()
	var radial := Vector2(cos(end_angle), sin(end_angle)).normalized()
	var head := size * 0.20
	_draw_icon_line(image, arrow_tip, arrow_tip - tangent * head - radial * head * 0.42, color, thickness)
	_draw_icon_line(image, arrow_tip, arrow_tip - tangent * head + radial * head * 0.42, color, thickness)

func _draw_icon_line(image: Image, start: Vector2, end: Vector2, color: Color, thickness: float) -> void:
	var min_x := clampi(int(floor(minf(start.x, end.x) - thickness)), 0, image.get_width() - 1)
	var max_x := clampi(int(ceil(maxf(start.x, end.x) + thickness)), 0, image.get_width() - 1)
	var min_y := clampi(int(floor(minf(start.y, end.y) - thickness)), 0, image.get_height() - 1)
	var max_y := clampi(int(ceil(maxf(start.y, end.y) + thickness)), 0, image.get_height() - 1)
	var segment := end - start
	var segment_length_sq := segment.length_squared()
	if segment_length_sq <= 0.001:
		return
	var radius := thickness * 0.5
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var point := Vector2(float(x) + 0.5, float(y) + 0.5)
			var projected := clampf((point - start).dot(segment) / segment_length_sq, 0.0, 1.0)
			var closest := start + segment * projected
			if point.distance_to(closest) <= radius:
				image.set_pixel(x, y, color)

func _layout_operation_buttons(rotate_button: Button, center_button: Button, delete_button: Button) -> void:
	var center_x := (OPERATION_PANEL_SIZE.x - OPERATION_BUTTON_SIZE.x) * 0.5
	if center_button:
		center_button.position = Vector2(center_x, 0.0)
	if rotate_button:
		rotate_button.position = Vector2(center_x - OPERATION_BUTTON_SIZE.x * 0.5 - OPERATION_PANEL_GAP, OPERATION_BUTTON_SIZE.y + 4.0)
	if delete_button:
		delete_button.position = Vector2(center_x + OPERATION_BUTTON_SIZE.x * 0.5 + OPERATION_PANEL_GAP, OPERATION_BUTTON_SIZE.y + 4.0)

func _make_operation_button_style(bg_color: Color, border_color: Color, content_shift_y: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 3.0)
	style.content_margin_top = content_shift_y
	return style

func _get_operation_anchor_position(target: Node3D) -> Vector3:
	var bounds := _get_cached_bounds(target)
	if bounds.size != Vector3.ZERO:
		var center := bounds.get_center()
		return Vector3(center.x, bounds.position.y + bounds.size.y, center.z)
	return target.global_position + Vector3.UP * 1.6

func _get_cached_bounds(target: Node3D) -> AABB:
	if target == selected_object and selected_bounds_cache.size != Vector3.ZERO:
		return selected_bounds_cache
	return _get_node_visual_bounds(target)

func _refresh_selected_bounds(target: Node3D) -> void:
	if target and is_instance_valid(target):
		selected_bounds_cache = _get_node_visual_bounds(target)
	else:
		selected_bounds_cache = AABB()

func _get_node_visual_bounds(node: Node3D) -> AABB:
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
			var bounds := _transform_aabb(mesh_instance.global_transform, mesh_instance.mesh.get_aabb())
			if bool(state["has_bounds"]):
				state["bounds"] = (state["bounds"] as AABB).merge(bounds)
			else:
				state["bounds"] = bounds
				state["has_bounds"] = true
	for child in node.get_children():
		_collect_visual_bounds(child, state)

func _transform_aabb(transform: Transform3D, source: AABB) -> AABB:
	var result := AABB(transform * source.position, Vector3.ZERO)
	for x in [0.0, source.size.x]:
		for y in [0.0, source.size.y]:
			for z in [0.0, source.size.z]:
				result = result.expand(transform * (source.position + Vector3(x, y, z)))
	return result

func _on_move_button_pressed() -> void:
	start_move_selected_object()

func start_move_selected_object() -> void:
	if selected_object and is_instance_valid(selected_object) and last_root:
		_begin_move_mode(last_root, last_operation_panel)

func _begin_move_mode(root: Node3D, operation_panel: Control) -> void:
	if not selected_object or not is_instance_valid(selected_object):
		return
	move_mode_active = true
	move_target = selected_object
	move_original_transform = move_target.global_transform
	move_original_bounds = _get_cached_bounds(move_target)
	move_original_cell_offset = _get_move_original_cell_offset(root, move_target)
	if operation_panel:
		operation_panel.visible = false
	_clear_selection_frame()
	_show_move_original_frame(root)

func _confirm_move_mode(root: Node3D, operation_panel: Control) -> void:
	if not move_mode_active:
		return
	move_mode_active = false
	_clear_move_original_frame()
	if move_target and is_instance_valid(move_target):
		selected_object = move_target
		_refresh_selected_bounds(move_target)
		if root and root.has_method("refresh_runtime_layer_node"):
			root.call("refresh_runtime_layer_node", move_target)
		selection_frame_dirty = true
		_show_selection_frame(root, move_target)
		var camera := root.get_node_or_null("CameraPivot/Camera3D") as Camera3D
		if camera:
			show_operation_panel(move_target, operation_panel, camera)
	move_target = null

func _cancel_move_mode(root: Node3D, operation_panel: Control) -> void:
	if not move_mode_active:
		return
	if move_target and is_instance_valid(move_target):
		move_target.global_transform = move_original_transform
		selected_object = move_target
		_refresh_selected_bounds(move_target)
		if root and root.has_method("refresh_runtime_layer_node"):
			root.call("refresh_runtime_layer_node", move_target)
		selection_frame_dirty = true
	move_mode_active = false
	_clear_move_original_frame()
	if selected_object and is_instance_valid(selected_object):
		_show_selection_frame(root, selected_object)
		var camera := root.get_node_or_null("CameraPivot/Camera3D") as Camera3D
		if camera:
			show_operation_panel(selected_object, operation_panel, camera)
	move_target = null

func _update_move_preview(root: Node3D, grid_map: GridMap) -> void:
	if not move_target or not is_instance_valid(move_target) or not grid_map:
		return
	var camera := root.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if not camera:
		return
	var mouse_pos := root.get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	var plane := Plane(Vector3.UP, grid_map.global_position.y)
	var hit: Variant = plane.intersects_ray(ray_origin, ray_direction)
	if hit == null:
		return
	var local_pos := grid_map.to_local(hit as Vector3)
	var cell := grid_map.local_to_map(local_pos)
	cell.y = 0
	var snapped := grid_map.to_global(grid_map.map_to_local(cell)) + move_original_cell_offset
	var next_transform := move_original_transform
	next_transform.origin = Vector3(snapped.x, move_original_transform.origin.y, snapped.z)
	move_target.global_transform = next_transform

func _get_move_original_cell_offset(root: Node3D, target: Node3D) -> Vector3:
	var grid_map := root.get_node_or_null("GridMap") as GridMap
	if not grid_map:
		return Vector3.ZERO
	var original_local := grid_map.to_local(target.global_position)
	var original_cell := grid_map.local_to_map(original_local)
	var original_cell_center := grid_map.to_global(grid_map.map_to_local(original_cell))
	var offset := target.global_position - original_cell_center
	return Vector3(offset.x, 0.0, offset.z)

func _show_selection_frame(root: Node3D, target: Node3D) -> void:
	if not root or not target or not is_instance_valid(target):
		return
	if not selection_frame:
		selection_frame = _create_frame_instance(SELECTION_FRAME_NAME, SELECTION_FRAME_COLOR)
		root.add_child(selection_frame)
	if selection_frame_target != target or selection_frame_dirty or not selection_frame.mesh:
		if selected_bounds_cache.size == Vector3.ZERO:
			_refresh_selected_bounds(target)
		selection_frame.mesh = _build_box_frame_mesh(_get_cached_bounds(target), false, SELECTION_FRAME_COLOR)
		selection_frame_target = target
		selection_frame_dirty = false
	selection_frame.visible = true

func _show_move_original_frame(root: Node3D) -> void:
	if not root:
		return
	if not move_original_frame:
		move_original_frame = _create_frame_instance(MOVE_ORIGINAL_FRAME_NAME, MOVE_ORIGINAL_FRAME_COLOR)
		root.add_child(move_original_frame)
	move_original_frame.mesh = _build_box_frame_mesh(move_original_bounds, true, MOVE_ORIGINAL_FRAME_COLOR)
	move_original_frame.visible = true

func _clear_selection_frame() -> void:
	if selection_frame:
		selection_frame.visible = false
	selection_frame_target = null
	selection_frame_dirty = false

func _clear_move_original_frame() -> void:
	if move_original_frame:
		move_original_frame.visible = false

func _create_frame_instance(frame_name: String, color: Color) -> MeshInstance3D:
	var frame := MeshInstance3D.new()
	frame.name = frame_name
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.vertex_color_use_as_albedo = true
	frame.material_override = material
	return frame

func _build_box_frame_mesh(bounds: AABB, dashed: bool, color: Color) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if bounds.size == Vector3.ZERO:
		return mesh
	bounds = bounds.grow(FRAME_PADDING)
	var min_pos := bounds.position
	var max_pos := bounds.position + bounds.size
	var corners := [
		Vector3(min_pos.x, min_pos.y, min_pos.z),
		Vector3(max_pos.x, min_pos.y, min_pos.z),
		Vector3(max_pos.x, min_pos.y, max_pos.z),
		Vector3(min_pos.x, min_pos.y, max_pos.z),
		Vector3(min_pos.x, max_pos.y, min_pos.z),
		Vector3(max_pos.x, max_pos.y, min_pos.z),
		Vector3(max_pos.x, max_pos.y, max_pos.z),
		Vector3(min_pos.x, max_pos.y, max_pos.z),
	]
	var edge_indices := [
		Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 0),
		Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7), Vector2i(7, 4),
		Vector2i(0, 4), Vector2i(1, 5), Vector2i(2, 6), Vector2i(3, 7),
	]
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for edge in edge_indices:
		_add_frame_edge(vertices, colors, corners[edge.x], corners[edge.y], dashed, color)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh

func _add_frame_edge(vertices: PackedVector3Array, colors: PackedColorArray, start: Vector3, end: Vector3, dashed: bool, color: Color) -> void:
	if not dashed:
		vertices.append(start)
		vertices.append(end)
		colors.append(color)
		colors.append(color)
		return
	var edge := end - start
	var length := edge.length()
	if length <= 0.001:
		return
	var direction := edge / length
	var offset := 0.0
	while offset < length:
		var dash_end := minf(offset + DASH_LENGTH, length)
		vertices.append(start + direction * offset)
		vertices.append(start + direction * dash_end)
		colors.append(color)
		colors.append(color)
		offset += DASH_LENGTH + DASH_GAP

func rotate_selected_object() -> void:
	if selected_object:
		if selected_object.has_method("rotate_placement"):
			selected_object.call("rotate_placement", -45.0)
		else:
			selected_object.rotate_y(deg_to_rad(-45))
		_refresh_selected_bounds(selected_object)
		if last_root and last_root.has_method("refresh_runtime_layer_node"):
			last_root.call("refresh_runtime_layer_node", selected_object)
		selection_frame_dirty = true
		if last_root:
			_show_selection_frame(last_root, selected_object)

func delete_selected_object(operation_panel: Control, root: Node = null) -> void:
	if selected_object:
		if root and selected_object.has_meta("cell_line_unit") and root.has_method("unregister_built_floor_cell"):
			var cell := Vector3i(int(selected_object.get_meta("floor_cell_x", 0)), 0, int(selected_object.get_meta("floor_cell_z", 0)))
			root.call("unregister_built_floor_cell", cell)
		if root and root.has_method("unregister_runtime_layer_node"):
			root.call("unregister_runtime_layer_node", selected_object)
		selected_object.queue_free()
		if operation_panel:
			operation_panel.visible = false
		_clear_selection_frame()
		_clear_move_original_frame()
		move_mode_active = false
		move_target = null
		selected_object = null
