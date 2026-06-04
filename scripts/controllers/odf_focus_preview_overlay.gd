extends Control

const CABINET_PREVIEW_SCENE := preload("res://assets/models/cabinet/JIAOHUANJI.glb")
const RACK_PREVIEW_SCENE := preload("res://assets/models/new_rack/racks_without_door.glb")
const FIXED_ODF_TYPE_META_KEY := "fixed_odf_type"
const DEFAULT_BOX_SIZE := Vector3(1.0, 2.0, 0.5)
const MIN_TARGET_SIZE := Vector3(0.45, 0.9, 0.3)
const ROTATION_STEP_DEGREES := 90.0
const ZOOM_STEP := 0.2
const MIN_ZOOM := 0.6
const MAX_ZOOM := 2.2
const PAN_SCROLL_LIMIT := 1.0
const PAN_WORLD_FACTOR := 0.45
const DASH_LENGTH := 12.0
const DASH_GAP := 8.0
const CONNECTOR_COLOR := Color(0.95, 0.97, 1.0, 0.9)
const DRAG_ROTATION_SPEED := 0.35
const MAX_PITCH_DEGREES := 45.0
const PREVIEW_PANEL_SIZE := Vector2(272.0, 272.0)
const PREVIEW_PANEL_MIN_HEIGHT := 176.0
const PREVIEW_PANEL_BOTTOM_MARGIN := 36.0
const PREVIEW_VIEWPORT_DEFAULT_HEIGHT := 128.0
const PREVIEW_VIEWPORT_MIN_HEIGHT := 72.0
const PREVIEW_VIEWPORT_CHROME_HEIGHT := 152.0
const PREVIEW_PANEL_GAP := 16.0
const PREVIEW_PANEL_TOP := 18.0
const PREVIEW_BACKGROUND_COLOR := Color(0.58072674, 0.66129375, 0.87493426, 1.0)
const ODF_TYPE_CABINET := 0
const ODF_TYPE_RACK := 1
const CABINET_PREVIEW_COLOR := Color(0.26, 0.72, 0.88, 1.0)
const RACK_PREVIEW_COLOR := Color(0.55, 0.36, 0.22, 1.0)

var current_target: Node3D
var current_target_size := DEFAULT_BOX_SIZE
var preview_zoom := 1.0
var preview_yaw_degrees := 0.0
var preview_pitch_degrees := 0.0
var preview_pan_offset := Vector2.ZERO
var preview_camera_base_position := Vector3.ZERO
var preview_camera_target := Vector3.ZERO
var preview_camera_pan_edge := 1.0
var is_drag_rotating := false

var preview_panel: PanelContainer
var preview_viewport_container: SubViewportContainer
var preview_viewport: SubViewport
var preview_pivot: Node3D
var preview_mesh: MeshInstance3D
var preview_model_instance: Node3D
var preview_camera: Camera3D
var preview_pan_x_slider: HSlider
var preview_pan_y_slider: VSlider
var is_ui_built := false
var preview_layout_cache_valid := false
var preview_last_viewport_size := Vector2.ZERO
var preview_last_left_panel_rect := Rect2()
var connector_cache_valid := false
var connector_last_camera_position := Vector3.ZERO
var connector_last_camera_rotation := Vector3.ZERO
var connector_last_target_position := Vector3.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	visible = false
	set_process(false)
	set_process_input(false)

func _process(_delta: float) -> void:
	if not visible or not preview_panel or not preview_panel.visible:
		return
	if not is_instance_valid(current_target):
		hide_preview()
		return
	var layout_changed := _update_panel_layout()
	if layout_changed or _connector_state_changed():
		queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible or not preview_panel or not preview_panel.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _is_point_in_preview_viewport(event.position):
			is_drag_rotating = true
			get_viewport().set_input_as_handled()
			return
		if not event.pressed and is_drag_rotating:
			is_drag_rotating = false
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and is_drag_rotating:
		preview_yaw_degrees += event.relative.x * DRAG_ROTATION_SPEED
		_apply_preview_rotation()
		get_viewport().set_input_as_handled()
		return
	if is_drag_rotating and should_block_main_scene_input(event):
		get_viewport().set_input_as_handled()

func should_block_main_scene_input(event: InputEvent) -> bool:
	if not visible or not preview_panel or not preview_panel.visible:
		return false
	if is_drag_rotating and (event is InputEventMouseMotion or event is InputEventMouseButton):
		return true
	if event is InputEventMouseButton:
		return preview_panel.get_global_rect().has_point(event.position)
	if event is InputEventMouseMotion:
		return preview_panel.get_global_rect().has_point(event.position)
	return false

func _is_point_in_preview_viewport(point: Vector2) -> bool:
	return visible and preview_panel and preview_panel.visible and preview_viewport_container and preview_viewport_container.get_global_rect().has_point(point)

func show_for_target(target: Node3D) -> void:
	if not target:
		hide_preview()
		return
	if not is_ui_built:
		_build_ui()
		_update_panel_layout()
		preview_panel.visible = false
		_set_preview_input_enabled(false)
		is_ui_built = true
	current_target = target
	current_target_size = _find_box_size(target)
	preview_zoom = 1.0
	preview_yaw_degrees = 0.0
	preview_pitch_degrees = 0.0
	preview_pan_offset = Vector2.ZERO
	_reset_pan_sliders()
	_update_preview_mesh()
	_apply_preview_rotation()
	_apply_zoom()
	_update_panel_layout()
	preview_panel.visible = true
	visible = true
	_set_preview_input_enabled(true)
	preview_layout_cache_valid = false
	connector_cache_valid = false
	_request_preview_render()
	set_process(true)
	set_process_input(true)
	queue_redraw()

func hide_preview() -> void:
	current_target = null
	is_drag_rotating = false
	preview_layout_cache_valid = false
	connector_cache_valid = false
	if preview_panel:
		preview_panel.visible = false
	_set_preview_input_enabled(false)
	if preview_viewport:
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	visible = false
	set_process(false)
	set_process_input(false)
	queue_redraw()

func _build_ui() -> void:
	preview_panel = PanelContainer.new()
	preview_panel.name = "PreviewPanel"
	preview_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	preview_panel.custom_minimum_size = PREVIEW_PANEL_SIZE
	preview_panel.size = PREVIEW_PANEL_SIZE
	preview_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_panel.clip_contents = true
	add_child(preview_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	preview_panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	root_vbox.add_child(header_row)

	var title := Label.new()
	title.text = "局部三维预览"
	header_row.add_child(title)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_spacer)

	var close_button := _build_action_button("关闭", _on_close_pressed)
	close_button.custom_minimum_size = Vector2(64, 32)
	header_row.add_child(close_button)

	var hint := Label.new()
	hint.text = "默认展示机柜包围盒，可直接放大缩小和旋转"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(hint)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	root_vbox.add_child(toolbar)

	toolbar.add_child(_build_action_button("-", _on_zoom_out_pressed))
	toolbar.add_child(_build_action_button("+", _on_zoom_in_pressed))
	toolbar.add_child(_build_action_button("左转", _on_rotate_left_pressed))
	toolbar.add_child(_build_action_button("右转", _on_rotate_right_pressed))

	var preview_viewport_row := HBoxContainer.new()
	preview_viewport_row.add_theme_constant_override("separation", 6)
	preview_viewport_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_viewport_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(preview_viewport_row)

	preview_viewport_container = SubViewportContainer.new()
	preview_viewport_container.custom_minimum_size = Vector2(0, PREVIEW_VIEWPORT_DEFAULT_HEIGHT)
	preview_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_viewport_container.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_viewport_container.gui_input.connect(_on_preview_gui_input)
	preview_viewport_row.add_child(preview_viewport_container)

	preview_pan_y_slider = VSlider.new()
	preview_pan_y_slider.min_value = -PAN_SCROLL_LIMIT
	preview_pan_y_slider.max_value = PAN_SCROLL_LIMIT
	preview_pan_y_slider.step = 0.01
	preview_pan_y_slider.value = 0.0
	preview_pan_y_slider.custom_minimum_size = Vector2(18, PREVIEW_VIEWPORT_DEFAULT_HEIGHT)
	preview_pan_y_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_pan_y_slider.value_changed.connect(_on_pan_y_changed)
	preview_viewport_row.add_child(preview_pan_y_slider)

	preview_pan_x_slider = HSlider.new()
	preview_pan_x_slider.min_value = -PAN_SCROLL_LIMIT
	preview_pan_x_slider.max_value = PAN_SCROLL_LIMIT
	preview_pan_x_slider.step = 0.01
	preview_pan_x_slider.value = 0.0
	preview_pan_x_slider.custom_minimum_size = Vector2(0, 18)
	preview_pan_x_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_pan_x_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_pan_x_slider.value_changed.connect(_on_pan_x_changed)
	root_vbox.add_child(preview_pan_x_slider)

	preview_viewport = SubViewport.new()
	preview_viewport.disable_3d = false
	preview_viewport.own_world_3d = true
	preview_viewport.transparent_bg = false
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	preview_viewport.size = Vector2i(720, 720)
	preview_viewport.msaa_3d = Viewport.MSAA_4X
	preview_viewport_container.add_child(preview_viewport)

	var scene_root := Node3D.new()
	preview_viewport.add_child(scene_root)

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = PREVIEW_BACKGROUND_COLOR
	world_environment.environment = environment
	scene_root.add_child(world_environment)

	preview_pivot = Node3D.new()
	scene_root.add_child(preview_pivot)

	preview_mesh = MeshInstance3D.new()
	preview_pivot.add_child(preview_mesh)

	var _material := StandardMaterial3D.new()
	_material.albedo_color = CABINET_PREVIEW_COLOR
	_material.metallic = 0.2
	_material.roughness = 0.32
	preview_mesh.material_override = _material

	var light := DirectionalLight3D.new()
	light.transform = Transform3D(Basis.from_euler(Vector3(-0.9, 0.7, 0.0)), Vector3(2.5, 4.0, 3.0))
	light.light_energy = 2.0
	scene_root.add_child(light)

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-2.0, 2.2, 2.8)
	fill_light.light_energy = 0.85
	fill_light.omni_range = 10.0
	scene_root.add_child(fill_light)

	preview_camera = Camera3D.new()
	preview_camera.position = Vector3(2.8, 1.8, 4.2)
	preview_camera.look_at(Vector3(0, 0.8, 0), Vector3.UP)
	scene_root.add_child(preview_camera)

	_update_preview_mesh()
	_apply_zoom()

func _build_action_button(label_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(48, 32)
	button.text = label_text
	button.pressed.connect(callback)
	return button

func _on_zoom_out_pressed() -> void:
	preview_zoom = maxf(MIN_ZOOM, preview_zoom - ZOOM_STEP)
	_apply_zoom()
	_request_preview_render()

func _on_zoom_in_pressed() -> void:
	preview_zoom = minf(MAX_ZOOM, preview_zoom + ZOOM_STEP)
	_apply_zoom()
	_request_preview_render()

func _on_rotate_left_pressed() -> void:
	preview_yaw_degrees -= ROTATION_STEP_DEGREES
	_apply_preview_rotation()
	_request_preview_render()

func _on_rotate_right_pressed() -> void:
	preview_yaw_degrees += ROTATION_STEP_DEGREES
	_apply_preview_rotation()
	_request_preview_render()

func _on_close_pressed() -> void:
	close_preview_only()

func close_preview_only() -> void:
	hide_preview()
	var module_panel := _get_bound_module_panel()
	if module_panel and module_panel.has_method("close_cabinet_if_panels_closed"):
		module_panel.call("close_cabinet_if_panels_closed")

func _apply_zoom() -> void:
	if preview_pivot:
		preview_pivot.scale = Vector3.ONE * preview_zoom
	_apply_camera_framing()

func _on_pan_x_changed(value: float) -> void:
	preview_pan_offset.x = value
	_apply_camera_framing()
	_request_preview_render()

func _on_pan_y_changed(value: float) -> void:
	preview_pan_offset.y = value
	_apply_camera_framing()
	_request_preview_render()

func _reset_pan_sliders() -> void:
	if preview_pan_x_slider:
		preview_pan_x_slider.value = 0.0
	if preview_pan_y_slider:
		preview_pan_y_slider.value = 0.0

func _apply_preview_rotation() -> void:
	if preview_pivot:
		preview_pivot.rotation_degrees = Vector3(preview_pitch_degrees, preview_yaw_degrees, 0.0)
	_request_preview_render()

func _update_preview_mesh() -> void:
	if not preview_mesh or not preview_camera:
		return
	var display_size: Vector3 = Vector3(
		maxf(current_target_size.x, MIN_TARGET_SIZE.x),
		maxf(current_target_size.y, MIN_TARGET_SIZE.y),
		maxf(current_target_size.z, MIN_TARGET_SIZE.z)
	)
	_clear_preview_model()
	var preview_scene := _get_preview_scene()
	if preview_scene:
		preview_model_instance = preview_scene.instantiate() as Node3D
		if preview_model_instance:
			preview_pivot.add_child(preview_model_instance)
			display_size = _fit_preview_model(preview_model_instance, display_size)
			preview_mesh.visible = false
		else:
			_show_fallback_box(display_size)
	else:
		_show_fallback_box(display_size)

	var max_edge: float = maxf(display_size.x, maxf(display_size.y, display_size.z))

	preview_camera.fov = 34.0
	preview_camera_base_position = Vector3(
		max_edge * 0.88 + 0.28,
		display_size.y * 0.52 + max_edge * 0.22,
		max_edge * 1.28 + 0.38
	)
	preview_camera_target = Vector3(0.0, display_size.y * 0.46, 0.0)
	preview_camera_pan_edge = max_edge
	_apply_camera_framing()

func _apply_camera_framing() -> void:
	if not preview_camera:
		return
	var pan_range: float = preview_camera_pan_edge * maxf(preview_zoom - 1.0, 0.0) * PAN_WORLD_FACTOR
	var pan_offset := Vector3(preview_pan_offset.x * pan_range, -preview_pan_offset.y * pan_range, 0.0)
	preview_camera.position = preview_camera_base_position + pan_offset
	preview_camera.look_at(preview_camera_target + pan_offset, Vector3.UP)
	_request_preview_render()

func _request_preview_render() -> void:
	if preview_viewport and visible:
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _clear_preview_model() -> void:
	if preview_model_instance:
		preview_model_instance.queue_free()
		preview_model_instance = null

func _get_preview_scene() -> PackedScene:
	return RACK_PREVIEW_SCENE if _get_current_odf_type() == ODF_TYPE_RACK else CABINET_PREVIEW_SCENE

func _show_fallback_box(display_size: Vector3) -> void:
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = display_size
	preview_mesh.mesh = box_mesh
	preview_mesh.position = Vector3(0.0, display_size.y * 0.5, 0.0)
	preview_mesh.visible = true
	_apply_preview_material()

func _fit_preview_model(model: Node3D, target_size: Vector3) -> Vector3:
	var bounds: AABB = _get_model_bounds(model)
	if bounds.size == Vector3.ZERO:
		return target_size
	var scale_ratio: float = minf(
		target_size.x / maxf(bounds.size.x, 0.001),
		minf(target_size.y / maxf(bounds.size.y, 0.001), target_size.z / maxf(bounds.size.z, 0.001))
	)
	var center := bounds.get_center()
	model.scale = Vector3.ONE * scale_ratio
	model.position = Vector3(-center.x * scale_ratio, -bounds.position.y * scale_ratio, -center.z * scale_ratio)
	return bounds.size * scale_ratio

func _get_model_bounds(node: Node3D) -> AABB:
	var state := {
		"has_bounds": false,
		"bounds": AABB(),
	}
	_collect_model_bounds(node, node.global_transform.affine_inverse(), state)
	return state["bounds"] if bool(state["has_bounds"]) else AABB()

func _collect_model_bounds(node: Node, root_inverse: Transform3D, state: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			var local_bounds := _transform_aabb(root_inverse * mesh_instance.global_transform, mesh_instance.mesh.get_aabb())
			if bool(state["has_bounds"]):
				state["bounds"] = (state["bounds"] as AABB).merge(local_bounds)
			else:
				state["bounds"] = local_bounds
				state["has_bounds"] = true
	for child in node.get_children():
		_collect_model_bounds(child, root_inverse, state)

func _transform_aabb(transform: Transform3D, source: AABB) -> AABB:
	var result := AABB(transform * source.position, Vector3.ZERO)
	for x in [0.0, source.size.x]:
		for y in [0.0, source.size.y]:
			for z in [0.0, source.size.z]:
				result = result.expand(transform * (source.position + Vector3(x, y, z)))
	return result

func _apply_preview_material() -> void:
	if not preview_mesh:
		return
	var material := preview_mesh.material_override as StandardMaterial3D
	if not material:
		material = StandardMaterial3D.new()
		preview_mesh.material_override = material
	material.albedo_color = RACK_PREVIEW_COLOR if _get_current_odf_type() == ODF_TYPE_RACK else CABINET_PREVIEW_COLOR
	material.metallic = 0.2
	material.roughness = 0.32

func _get_current_odf_type() -> int:
	if current_target and current_target.has_meta(FIXED_ODF_TYPE_META_KEY):
		return _normalize_odf_type(current_target.get_meta(FIXED_ODF_TYPE_META_KEY))
	if current_target and current_target.has_meta("module_config"):
		var config: Variant = current_target.get_meta("module_config")
		if config is Dictionary:
			return _normalize_odf_type((config as Dictionary).get("odf_type", (config as Dictionary).get("type", ODF_TYPE_CABINET)))
	return ODF_TYPE_CABINET

func _normalize_odf_type(value: Variant) -> int:
	if value is String:
		var text := (value as String).strip_edges().to_lower()
		if text == "rack" or text == "机架" or text == "1":
			return ODF_TYPE_RACK
		return ODF_TYPE_CABINET
	return int(value)

func _on_preview_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_drag_rotating = event.pressed
		preview_viewport_container.accept_event()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and is_drag_rotating:
		preview_yaw_degrees += event.relative.x * DRAG_ROTATION_SPEED
		_apply_preview_rotation()
		_request_preview_render()
		preview_viewport_container.accept_event()
		get_viewport().set_input_as_handled()

func _find_box_size(node: Node) -> Vector3:
	var mesh_size: Vector3 = _find_mesh_size(node)
	if mesh_size != Vector3.ZERO:
		return mesh_size
	if node is CollisionShape3D:
		var collision_shape: CollisionShape3D = node as CollisionShape3D
		if collision_shape.shape is BoxShape3D:
			return (collision_shape.shape as BoxShape3D).size
	for child in node.get_children():
		var child_size: Vector3 = _find_box_size(child)
		if child_size != DEFAULT_BOX_SIZE or child is CollisionShape3D:
			return child_size
	return DEFAULT_BOX_SIZE

func _find_mesh_size(node: Node) -> Vector3:
	var bounds_size: Vector3 = Vector3.ZERO
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh:
			bounds_size = mesh_instance.mesh.get_aabb().size.abs()

	for child in node.get_children():
		var child_size: Vector3 = _find_mesh_size(child)
		bounds_size = Vector3(
			maxf(bounds_size.x, child_size.x),
			maxf(bounds_size.y, child_size.y),
			maxf(bounds_size.z, child_size.z)
		)

	return bounds_size

func _draw() -> void:
	if not visible or not preview_panel or not is_instance_valid(current_target):
		return
	var world_camera: Camera3D = _get_world_camera()
	if not world_camera:
		return
	var target_point: Vector3 = current_target.global_position + Vector3(0.0, current_target_size.y * 0.5, 0.0)
	if world_camera.is_position_behind(target_point):
		return

	var transform_inverse: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var start: Vector2 = transform_inverse * world_camera.unproject_position(target_point)
	var end: Vector2 = transform_inverse * (preview_panel.global_position + Vector2(0.0, preview_panel.size.y * 0.5))
	_draw_dashed_line(start, end, CONNECTOR_COLOR, 2.5)

func _draw_dashed_line(start: Vector2, end: Vector2, color: Color, width: float) -> void:
	var segment := end - start
	var total_length := segment.length()
	if total_length <= 0.001:
		return
	var direction := segment / total_length
	var offset := 0.0
	while offset < total_length:
		var dash_end := minf(offset + DASH_LENGTH, total_length)
		draw_line(start + direction * offset, start + direction * dash_end, color, width, true)
		offset += DASH_LENGTH + DASH_GAP

func _get_world_camera() -> Camera3D:
	var scene_root := get_tree().current_scene
	if not scene_root:
		return null
	return scene_root.get_node_or_null("CameraPivot/Camera3D") as Camera3D

func _update_panel_layout() -> bool:
	if not preview_panel:
		return false
	var viewport_size := get_viewport_rect().size
	var scene_root := get_tree().current_scene
	if not scene_root:
		return false
	var left_panel := scene_root.get_node_or_null("CanvasLayer/Panel") as Control
	var left_panel_rect := left_panel.get_global_rect() if left_panel else Rect2()
	if preview_layout_cache_valid and viewport_size == preview_last_viewport_size and left_panel_rect == preview_last_left_panel_rect:
		return false
	preview_layout_cache_valid = true
	preview_last_viewport_size = viewport_size
	preview_last_left_panel_rect = left_panel_rect
	var panel_size := _apply_responsive_preview_size(viewport_size)
	if left_panel:
		preview_panel.global_position = Vector2(left_panel_rect.position.x + left_panel_rect.size.x + PREVIEW_PANEL_GAP, PREVIEW_PANEL_TOP)
	else:
		preview_panel.position = Vector2(96.0, PREVIEW_PANEL_TOP)
	preview_panel.global_position.y = clampf(
		preview_panel.global_position.y,
		PREVIEW_PANEL_TOP,
		maxf(PREVIEW_PANEL_TOP, viewport_size.y - panel_size.y - PREVIEW_PANEL_BOTTOM_MARGIN)
	)
	return true

func _connector_state_changed() -> bool:
	if not is_instance_valid(current_target):
		return false
	var world_camera := _get_world_camera()
	if not world_camera:
		return false
	var target_position := current_target.global_position
	if connector_cache_valid and world_camera.global_position.distance_squared_to(connector_last_camera_position) < 0.000001 and world_camera.global_rotation.distance_squared_to(connector_last_camera_rotation) < 0.000001 and target_position.distance_squared_to(connector_last_target_position) < 0.000001:
		return false
	connector_cache_valid = true
	connector_last_camera_position = world_camera.global_position
	connector_last_camera_rotation = world_camera.global_rotation
	connector_last_target_position = target_position
	return true

func _apply_responsive_preview_size(viewport_size: Vector2 = Vector2.ZERO) -> Vector2:
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport_rect().size
	var available_height := maxf(0.0, viewport_size.y - PREVIEW_PANEL_TOP - PREVIEW_PANEL_BOTTOM_MARGIN)
	var panel_height := minf(PREVIEW_PANEL_SIZE.y, available_height)
	if panel_height <= 0.0:
		panel_height = PREVIEW_PANEL_SIZE.y
	elif available_height >= PREVIEW_PANEL_MIN_HEIGHT:
		panel_height = maxf(PREVIEW_PANEL_MIN_HEIGHT, panel_height)
	var viewport_height := maxf(0.0, panel_height - PREVIEW_VIEWPORT_CHROME_HEIGHT)
	if available_height >= PREVIEW_PANEL_MIN_HEIGHT:
		viewport_height = maxf(PREVIEW_VIEWPORT_MIN_HEIGHT, viewport_height)
		panel_height = maxf(panel_height, PREVIEW_VIEWPORT_CHROME_HEIGHT + viewport_height)
	else:
		panel_height = minf(panel_height, available_height)
	var panel_size := Vector2(PREVIEW_PANEL_SIZE.x, panel_height)
	preview_panel.custom_minimum_size = panel_size
	preview_panel.size = panel_size
	if preview_viewport_container:
		preview_viewport_container.custom_minimum_size = Vector2(0.0, viewport_height)
	if preview_pan_y_slider:
		preview_pan_y_slider.custom_minimum_size = Vector2(18.0, viewport_height)
	return panel_size

func _set_preview_input_enabled(enabled: bool) -> void:
	var filter := Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if preview_panel:
		preview_panel.mouse_filter = filter
	if preview_viewport_container:
		preview_viewport_container.mouse_filter = filter
	if preview_pan_x_slider:
		preview_pan_x_slider.mouse_filter = filter
	if preview_pan_y_slider:
		preview_pan_y_slider.mouse_filter = filter

func _get_bound_module_panel() -> Control:
	var scene_root := get_tree().current_scene
	if not scene_root:
		return null
	return scene_root.get_node_or_null("CanvasLayer/ModulePanel") as Control

func _close_bound_module_panel() -> void:
	var module_panel := _get_bound_module_panel()
	if not module_panel:
		hide_preview()
		return
	if module_panel and module_panel.has_method("close_for_current_target"):
		module_panel.call("close_for_current_target")
	elif module_panel:
		module_panel.visible = false
		hide_preview()
	else:
		hide_preview()