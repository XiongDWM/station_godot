extends Node3D

const BuildingControllerScript = preload("res://scripts/controllers/building_controller.gd")
const LayoutSerializerScript = preload("res://scripts/serializers/layout_serializer.gd")
const LayoutFlowControllerScript = preload("res://scripts/controllers/layout_flow_controller.gd")
const SelectionControllerScript = preload("res://scripts/controllers/selection_controller.gd")
const UI_CJK_THEME := preload("res://themes/ui_cjk_theme.tres")
const UI_CJK_FONT := preload("res://assets/fonts/NotoSansSC-VF.ttf")
const TRENCH_SCENE_PATH := "res://trench_object.tscn"
const CEILING_TRAY_SCENE_PATH := "res://ceiling_tray_object.tscn"
const BUILD_VIEW_ORDER := [0, -1, 1]
const BUILD_VIEW_LABELS := {
	-1: "下层管线",
	0: "中层结构",
	1: "上层管线",
}
const GROUND_BASE_SIZE := Vector2(1600.0, 1600.0)
const GROUND_BASE_THICKNESS := 0.06
const GROUND_BASE_MARGIN := 0.0
const FIRST_PERSON_REVEAL_BASE_OFFSET := 0.28
const LAYER_GRID_COLOR := Color(0.08, 0.08, 0.08, 0.72)
const LAYER_GRID_DASH_LENGTH := 0.38
const LAYER_GRID_GAP_LENGTH := 0.24
const LAYER_GRID_ELEVATION := 0.02
const SAVE_NOTIFICATION_DURATION_MS := 2600
const VIEW_LAYER_Y := {
	-1: -1.0,
	0: 0.0,
	1: 2.3,
}

@export_group("Ground Base")
@export var ground_base_color: Color = Color(0.70, 0.74, 0.78, 1.0)
@export_range(0.0, 1.0, 0.01) var ground_base_specular: float = 0.02
@export_range(0.0, 1.0, 0.01) var ground_base_roughness: float = 0.92

@export_group("Rendering")
@export var scene_shadows_enabled: bool = true

@export var grid_map: GridMap
@export var btn_cube: Button
@export var btn_rack: Button
@export var btn_wall: Button
@export var preview_cube: MeshInstance3D
@export var preview_rack: MeshInstance3D
@export var preview_wall: MeshInstance3D
@export var block_scene: PackedScene
@export var rack_scene: PackedScene
@export var wall_scene: PackedScene
@export var module_panel: Panel
@export var operation_panel: Control 
@export var btn_rotate: Button
@export var btn_delete: Button
@export var btn_save:Button
@export var left_menu_panel: Control
@export var build_panel: Control
@export var http_request:HTTPRequest
@export var btn_door: Button
@export var door_scene: PackedScene
@export var floor_brick_scene: PackedScene
@export var preview_ac: MeshInstance3D
@export var btn_pipe: Button
@export var btn_view_layer: Button
@export var preview_pipe: MeshInstance3D
@export var pipe_scene: PackedScene
@export var runtime_pipe_button: Button
@export var trench_scene: PackedScene
@export var runtime_trench_button: Button
@export var runtime_view_layer_button: Button

var building_controller := BuildingControllerScript.new()
var layout_serializer := LayoutSerializerScript.new()
var layout_flow_controller := LayoutFlowControllerScript.new()
var selection_controller := SelectionControllerScript.new()
var active_build_view_layer := 0
var pipe_button_icon: Texture2D
var trench_button_icon: Texture2D
var layer_button_icons := {}
var scene_camera: Camera3D
var ground_base: MeshInstance3D
var layer_grid_overlay: MeshInstance3D
var runtime_preview_pipe: MeshInstance3D
var camera_mode_name := "orbit"
var side_view_hovered_layer := 999
var side_view_layer_planes := {}
var side_view_layer_materials := {}
var cached_grid_bounds := {}
var side_view_hover_cache_valid := false
var side_view_last_mouse_pos := Vector2.ZERO
var side_view_last_camera_position := Vector3.ZERO
var side_view_last_camera_rotation := Vector3.ZERO
var save_notification_panel: PanelContainer
var save_notification_label: Label
var save_notification_hide_at_msec := 0
var shadow_toggle_button: Button
var revealed_floor_cells := {}
var revealed_floor_overlays := {}

func _ready():
	# print("[MainScene._ready] btn_cube=", btn_cube, ", btn_wall=", btn_wall, ", preview_cube=", preview_cube, ", preview_wall=", preview_wall, ", block_scene=", block_scene, ", wall_scene=", wall_scene)
	_deactivate_hidden_prototypes()
	_configure_build_toolbar()
	_configure_shadow_toggle_button()
	_setup_ground_base()
	_setup_layer_grid_overlay()
	scene_camera = get_node_or_null("CameraPivot/Camera3D") as Camera3D
	_apply_scene_shadow_settings()
	_setup_side_view_layer_planes()
	building_controller.initialize(preview_cube, preview_wall, runtime_preview_pipe, preview_rack)
	building_controller.bind_buttons(btn_cube, btn_rack, btn_wall, btn_door, runtime_pipe_button, runtime_trench_button, block_scene, rack_scene, wall_scene, door_scene, pipe_scene, trench_scene, preview_cube, preview_rack, preview_wall, runtime_preview_pipe, self, &"_on_building_mode_selected")
	selection_controller.initialize(operation_panel, module_panel)
	selection_controller.bind_buttons(btn_rotate, btn_delete, self, &"_on_rotate_selected_object", &"_on_delete_selected_object")
	layout_flow_controller.setup(self, http_request, layout_serializer)
	layout_flow_controller.bind_save_button(btn_save)
	layout_flow_controller.bind_api_signals()
	layout_flow_controller.bootstrap()
	_apply_build_view_layer(active_build_view_layer)
	on_camera_mode_changed("orbit")

func _deactivate_hidden_prototypes() -> void:
	for child in get_children():
		if not child is Node3D:
			continue
		var prototype_root := child as Node3D
		if prototype_root.scene_file_path == "":
			continue
		if prototype_root.visible:
			continue
		if prototype_root.has_meta("build_view_layer"):
			continue
		_set_node_collision_enabled_recursive(prototype_root, false)

func _set_node_collision_enabled_recursive(node: Node, enabled: bool) -> void:
	if node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		collision_object.input_ray_pickable = enabled
		collision_object.collision_layer = 1 if enabled else 0
		collision_object.collision_mask = 1 if enabled else 0
		for owner_id in collision_object.get_shape_owners():
			collision_object.shape_owner_set_disabled(owner_id, not enabled)
	for child in node.get_children():
		_set_node_collision_enabled_recursive(child, enabled)

func _on_building_mode_selected(scene: PackedScene, preview: MeshInstance3D, placement_mode: String = "point"):
	# print("[MainScene._on_building_mode_selected] scene=", scene, ", preview=", preview)
	_configure_runtime_line_preview(scene, preview)
	building_controller.set_building_mode(scene, preview, operation_panel, module_panel, placement_mode)

func _process(_delta):
	_update_ground_base_position()
	_update_save_notification_visibility()
	selection_controller.update_runtime_visuals(self, grid_map, operation_panel)
	if camera_mode_name == "side":
		_update_side_view_layer_hover()
	if selection_controller.is_move_mode_active():
		return
	if selection_controller.has_visible_panel(operation_panel, module_panel):
		return
	if building_controller.is_active() and building_controller.get_preview():
		building_controller.handle_preview_logic(self, grid_map)

func _unhandled_input(event):
	if selection_controller.handle_unhandled_input(self, event, operation_panel, module_panel):
		return
	if building_controller.handle_unhandled_input(self, event):
		return
	if camera_mode_name == "first_person" and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		if _toggle_first_person_floor_reveal_at_cursor():
			get_viewport().set_input_as_handled()
			return
	if camera_mode_name == "side" and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		if side_view_hovered_layer != 999:
			var camera_pivot := get_node_or_null("CameraPivot")
			if camera_pivot and camera_pivot.has_method("exit_side_view_to_orbit"):
				camera_pivot.call("exit_side_view_to_orbit", side_view_hovered_layer)
				get_viewport().set_input_as_handled()
				return
	if Input.is_key_pressed(KEY_CTRL):
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if building_controller.is_active():
				building_controller.place_current_building(self, grid_map)
				return
			if active_build_view_layer == 0:
				selection_controller.handle_left_click_module(self, block_scene, module_panel)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if selection_controller.toggle_panels_on_right_click(operation_panel, module_panel):
				return
			selection_controller.handle_right_click_operation(self, grid_map, preview_cube, preview_wall, runtime_preview_pipe, operation_panel)

func refresh_build_view_state() -> void:
	_apply_build_view_layer(active_build_view_layer)

func show_save_notification(success: bool, message: String) -> void:
	_ensure_save_notification()
	if not save_notification_panel or not save_notification_label:
		return
	save_notification_label.text = message
	var style := save_notification_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.bg_color = Color(0.08, 0.42, 0.24, 0.94) if success else Color(0.55, 0.12, 0.12, 0.94)
	save_notification_panel.visible = true
	save_notification_hide_at_msec = Time.get_ticks_msec() + SAVE_NOTIFICATION_DURATION_MS

func _ensure_save_notification() -> void:
	if save_notification_panel and save_notification_label:
		return
	var canvas_layer := get_node_or_null("CanvasLayer") as CanvasLayer
	if not canvas_layer:
		return
	save_notification_panel = PanelContainer.new()
	save_notification_panel.name = "SaveNotification"
	save_notification_panel.visible = false
	save_notification_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	save_notification_panel.theme = UI_CJK_THEME
	save_notification_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	save_notification_panel.offset_left = -360.0
	save_notification_panel.offset_top = 18.0
	save_notification_panel.offset_right = -18.0
	save_notification_panel.offset_bottom = 74.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.42, 0.24, 0.94)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16.0
	style.content_margin_top = 10.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 10.0
	save_notification_panel.add_theme_stylebox_override("panel", style)
	save_notification_label = Label.new()
	save_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_notification_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	save_notification_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_notification_label.add_theme_font_override("font", UI_CJK_FONT)
	save_notification_label.add_theme_color_override("font_color", Color.WHITE)
	save_notification_label.add_theme_font_size_override("font_size", 16)
	save_notification_panel.add_child(save_notification_label)
	canvas_layer.add_child(save_notification_panel)

func _update_save_notification_visibility() -> void:
	if save_notification_panel and save_notification_panel.visible and Time.get_ticks_msec() >= save_notification_hide_at_msec:
		save_notification_panel.visible = false

func _configure_shadow_toggle_button() -> void:
	if shadow_toggle_button:
		return
	var canvas_layer := get_node_or_null("CanvasLayer") as CanvasLayer
	if not canvas_layer:
		return
	shadow_toggle_button = Button.new()
	shadow_toggle_button.name = "ShadowToggleButton"
	shadow_toggle_button.toggle_mode = true
	shadow_toggle_button.button_pressed = scene_shadows_enabled
	shadow_toggle_button.custom_minimum_size = Vector2(118, 38)
	shadow_toggle_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	shadow_toggle_button.offset_left = 18.0
	shadow_toggle_button.offset_top = -56.0
	shadow_toggle_button.offset_right = 136.0
	shadow_toggle_button.offset_bottom = -18.0
	shadow_toggle_button.tooltip_text = "切换光影/性能模式"
	if left_menu_panel:
		shadow_toggle_button.theme = left_menu_panel.theme
	shadow_toggle_button.pressed.connect(_on_shadow_toggle_pressed)
	canvas_layer.add_child(shadow_toggle_button)
	_update_shadow_toggle_button()

func _on_shadow_toggle_pressed() -> void:
	if not shadow_toggle_button:
		return
	scene_shadows_enabled = shadow_toggle_button.button_pressed
	_apply_scene_shadow_settings()
	_update_shadow_toggle_button()

func _update_shadow_toggle_button() -> void:
	if not shadow_toggle_button:
		return
	shadow_toggle_button.button_pressed = scene_shadows_enabled
	shadow_toggle_button.text = "光影 开" if scene_shadows_enabled else "光影 关"

func _on_rotate_selected_object():
	selection_controller.rotate_selected_object()

func _on_delete_selected_object():
	selection_controller.delete_selected_object(operation_panel)

func _configure_build_toolbar() -> void:
	_configure_pipe_preview()
	_configure_runtime_pipe_button()
	_configure_runtime_trench_button()
	_configure_view_layer_button()
	pipe_button_icon = _build_pipe_icon()
	trench_button_icon = _build_trench_icon()
	for layer in BUILD_VIEW_ORDER:
		layer_button_icons[layer] = _build_layer_view_icon(layer)
	if runtime_pipe_button:
		runtime_pipe_button.tooltip_text = "绘制管线"
		runtime_pipe_button.icon = pipe_button_icon
		runtime_pipe_button.expand_icon = true
	if runtime_trench_button:
		runtime_trench_button.tooltip_text = "绘制沟槽"
		runtime_trench_button.icon = trench_button_icon
		runtime_trench_button.expand_icon = true
	if btn_rack:
		btn_rack.tooltip_text = "创建机架"
	if btn_wall:
		btn_wall.tooltip_text = "墙体"
	if btn_door:
		btn_door.tooltip_text = "单门"

func _configure_view_layer_button() -> void:
	if not runtime_view_layer_button:
		return
	if left_menu_panel:
		runtime_view_layer_button.theme = left_menu_panel.theme
	runtime_view_layer_button.custom_minimum_size = Vector2(96, 52)
	runtime_view_layer_button.expand_icon = true
	runtime_view_layer_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	runtime_view_layer_button.tooltip_text = "视图层"
	runtime_view_layer_button.text = ""
	if not runtime_view_layer_button.pressed.is_connected(_on_view_layer_pressed):
		runtime_view_layer_button.pressed.connect(_on_view_layer_pressed)

func _configure_runtime_pipe_button() -> void:
	if not runtime_pipe_button:
		return
	if build_panel:
		runtime_pipe_button.theme = build_panel.theme
	runtime_pipe_button.text = ""

func _configure_runtime_trench_button() -> void:
	if not runtime_trench_button:
		return
	if build_panel:
		runtime_trench_button.theme = build_panel.theme
	runtime_trench_button.text = ""

func _configure_pipe_preview() -> void:
	if runtime_preview_pipe:
		runtime_preview_pipe.mesh = _build_pipe_preview_mesh()
		return
	runtime_preview_pipe = MeshInstance3D.new()
	runtime_preview_pipe.name = "PreviewPipe"
	runtime_preview_pipe.mesh = _build_pipe_preview_mesh()
	runtime_preview_pipe.visible = false
	runtime_preview_pipe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(runtime_preview_pipe)

func _configure_runtime_line_preview(scene: PackedScene, preview: MeshInstance3D) -> void:
	if preview != runtime_preview_pipe or not scene:
		return
	if scene.resource_path == TRENCH_SCENE_PATH and active_build_view_layer == 1:
		preview.mesh = _build_ceiling_tray_preview_mesh()
	elif scene.resource_path == TRENCH_SCENE_PATH:
		preview.mesh = _build_trench_preview_mesh()
	else:
		preview.mesh = _build_pipe_preview_mesh()

func _on_view_layer_pressed() -> void:
	var current_index := BUILD_VIEW_ORDER.find(active_build_view_layer)
	if current_index < 0:
		current_index = 0
	var next_index := (current_index + 1) % BUILD_VIEW_ORDER.size()
	_apply_build_view_layer(BUILD_VIEW_ORDER[next_index])

func _apply_build_view_layer(layer: int) -> void:
	active_build_view_layer = layer
	building_controller.set_active_view_layer(layer)
	_update_build_toolbar_for_layer(layer)
	_apply_scene_layer_visibility()
	_update_layer_plane_visuals(layer)
	_enforce_build_mode_for_active_layer()

func _update_build_toolbar_for_layer(layer: int) -> void:
	var pipeline_layer := layer != 0
	if btn_wall:
		btn_wall.visible = not pipeline_layer
	if btn_door:
		btn_door.visible = not pipeline_layer
	if btn_pipe:
		btn_pipe.visible = not pipeline_layer
	if btn_view_layer:
		btn_view_layer.visible = not pipeline_layer
	if runtime_pipe_button:
		runtime_pipe_button.visible = pipeline_layer
	if runtime_trench_button:
		runtime_trench_button.visible = pipeline_layer
	if runtime_view_layer_button:
		runtime_view_layer_button.visible = true
		runtime_view_layer_button.tooltip_text = "视图层: %s" % BUILD_VIEW_LABELS.get(layer, "中层结构")
		runtime_view_layer_button.icon = layer_button_icons.get(layer, null)
		runtime_view_layer_button.expand_icon = true

func _enforce_build_mode_for_active_layer() -> void:
	var placement_mode :Variant= building_controller.get_placement_mode()
	if active_build_view_layer == 0 and placement_mode == "line":
		building_controller.cancel_build_mode()
	elif active_build_view_layer != 0 and placement_mode == "point" and building_controller.is_active():
		building_controller.cancel_build_mode()

func _apply_scene_layer_visibility() -> void:
	for child in get_children():
		if not child is Node3D:
			continue
		var node := child as Node3D
		if node.scene_file_path == "" or not node.has_meta("build_view_layer"):
			continue
		var layer := int(node.get_meta("build_view_layer", 0))
		node.visible = camera_mode_name == "side" or layer == active_build_view_layer

func _update_layer_plane_visuals(layer: int) -> void:
	if grid_map:
		grid_map.visible = layer == 0 or camera_mode_name == "side"
	if ground_base:
		ground_base.visible = _should_show_ground_base(layer)
	if not layer_grid_overlay:
		return
	layer_grid_overlay.visible = layer != 0 and camera_mode_name != "side"
	if layer != 0:
		layer_grid_overlay.position.y = _get_view_layer_plane_y(layer) + LAYER_GRID_ELEVATION
	_update_side_view_layer_plane_visibility()

func _setup_ground_base() -> void:
	if ground_base:
		return
	var ground_mesh := _build_ground_base_mesh()
	if not ground_mesh:
		return
	ground_base = MeshInstance3D.new()
	ground_base.name = "GroundBase"
	ground_base.mesh = ground_mesh
	ground_base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(ground_base)
	_update_ground_base_position()
	_apply_scene_shadow_settings()

func _apply_scene_shadow_settings() -> void:
	var shadow_mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if scene_shadows_enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if ground_base:
		ground_base.cast_shadow = shadow_mode
	if grid_map and grid_map.mesh_library:
		var library := grid_map.mesh_library
		if library.has_method("set_item_mesh_cast_shadow"):
			for item_id in library.get_item_list():
				library.call("set_item_mesh_cast_shadow", item_id, shadow_mode)
	for child in get_children():
		if child is DirectionalLight3D:
			(child as DirectionalLight3D).shadow_enabled = scene_shadows_enabled
		elif child is OmniLight3D:
			(child as OmniLight3D).shadow_enabled = false
	_update_shadow_toggle_button()

func _build_ground_base_mesh() -> PlaneMesh:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(GROUND_BASE_SIZE.x + GROUND_BASE_MARGIN * 2.0, GROUND_BASE_SIZE.y + GROUND_BASE_MARGIN * 2.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = ground_base_color
	material.metallic = 0.0
	material.metallic_specular = ground_base_specular
	material.roughness = ground_base_roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = material
	return mesh

func _get_ground_base_position() -> Vector3:
	var bounds := _get_grid_bounds()
	var center_x := float(bounds.get("center_x", 0.0))
	var center_z := float(bounds.get("center_z", 0.0))
	var base_y := -GROUND_BASE_THICKNESS
	if grid_map:
		if camera_mode_name == "first_person" and not revealed_floor_cells.is_empty():
			base_y = _get_view_layer_plane_y(-1) - grid_map.cell_size.y - FIRST_PERSON_REVEAL_BASE_OFFSET
		else:
			base_y -= grid_map.cell_size.y * 0.5 + 0.02
	if scene_camera:
		center_x = scene_camera.global_position.x
		center_z = scene_camera.global_position.z
	return Vector3(
		center_x,
		base_y,
		center_z
	)

func _update_ground_base_position() -> void:
	if not ground_base:
		return
	var next_position := _get_ground_base_position()
	if ground_base.position.distance_squared_to(next_position) < 0.0001:
		return
	ground_base.position = next_position

func _get_grid_bounds() -> Dictionary:
	if not cached_grid_bounds.is_empty():
		return cached_grid_bounds
	if not grid_map:
		return {}
	var used_cells := grid_map.get_used_cells()
	if used_cells.is_empty():
		return {}
	var min_x := used_cells[0].x
	var max_x := used_cells[0].x
	var min_z := used_cells[0].z
	var max_z := used_cells[0].z
	for cell in used_cells:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_z = mini(min_z, cell.z)
		max_z = maxi(max_z, cell.z)
	var min_center := grid_map.map_to_local(Vector3i(min_x, 0, min_z))
	var max_center := grid_map.map_to_local(Vector3i(max_x, 0, max_z))
	var cell_size := grid_map.cell_size
	var x_start := min_center.x - cell_size.x * 0.5
	var x_end := max_center.x + cell_size.x * 0.5
	var z_start := min_center.z - cell_size.z * 0.5
	var z_end := max_center.z + cell_size.z * 0.5
	cached_grid_bounds = {
		"center_x": (x_start + x_end) * 0.5,
		"center_z": (z_start + z_end) * 0.5,
		"width": x_end - x_start,
		"depth": z_end - z_start,
	}
	return cached_grid_bounds

func _get_view_layer_plane_y(layer: int) -> float:
	return float(VIEW_LAYER_Y.get(layer, VIEW_LAYER_Y[0]))

func _setup_layer_grid_overlay() -> void:
	if layer_grid_overlay:
		return
	layer_grid_overlay = MeshInstance3D.new()
	layer_grid_overlay.name = "LayerGridOverlay"
	layer_grid_overlay.visible = false
	layer_grid_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layer_grid_overlay.mesh = _build_layer_grid_mesh()
	if layer_grid_overlay.mesh:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.vertex_color_use_as_albedo = true
		layer_grid_overlay.material_override = material
	add_child(layer_grid_overlay)

func _setup_side_view_layer_planes() -> void:
	if not side_view_layer_planes.is_empty():
		return
	var bounds := _get_grid_bounds()
	if bounds.is_empty():
		return
	var side_grid_mesh := _build_layer_grid_mesh()
	if not side_grid_mesh:
		return
	for layer in BUILD_VIEW_ORDER:
		if layer == 0:
			continue
		var plane := MeshInstance3D.new()
		plane.name = "SideViewLayerPlane_%d" % layer
		plane.mesh = side_grid_mesh
		plane.position = Vector3(0.0, _get_view_layer_plane_y(layer) + LAYER_GRID_ELEVATION, 0.0)
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
		plane.material_override = material
		plane.visible = false
		side_view_layer_planes[layer] = plane
		side_view_layer_materials[layer] = material
		add_child(plane)

func _update_side_view_layer_plane_visibility() -> void:
	if camera_mode_name != "side":
		for layer in side_view_layer_planes.keys():
			var hidden_plane := side_view_layer_planes[layer] as MeshInstance3D
			if hidden_plane:
				hidden_plane.visible = false
		return
	for layer in side_view_layer_planes.keys():
		var plane := side_view_layer_planes[layer] as MeshInstance3D
		if plane:
			plane.visible = camera_mode_name == "side"

func _update_side_view_layer_hover() -> void:
	if camera_mode_name != "side":
		side_view_hover_cache_valid = false
		side_view_hovered_layer = 999
		_update_side_view_layer_plane_materials()
		return
	if not scene_camera or not grid_map:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var camera_position := scene_camera.global_position
	var camera_rotation := scene_camera.global_rotation
	if side_view_hover_cache_valid and mouse_pos == side_view_last_mouse_pos and camera_position.distance_squared_to(side_view_last_camera_position) < 0.000001 and camera_rotation.distance_squared_to(side_view_last_camera_rotation) < 0.000001:
		return
	side_view_hover_cache_valid = true
	side_view_last_mouse_pos = mouse_pos
	side_view_last_camera_position = camera_position
	side_view_last_camera_rotation = camera_rotation
	var ray_origin := scene_camera.project_ray_origin(mouse_pos)
	var ray_direction := scene_camera.project_ray_normal(mouse_pos)
	var hovered_layer := 999
	var best_distance := INF
	for layer in side_view_layer_planes.keys():
		var plane_y := _get_view_layer_plane_y(layer)
		var plane := Plane(Vector3.UP, plane_y)
		var hit : Variant = plane.intersects_ray(ray_origin, ray_direction)
		if hit == null:
			continue
		var point : Vector3 = hit as Vector3
		if not _is_point_inside_grid_bounds(point):
			continue
		var distance := ray_origin.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			hovered_layer = layer
	if side_view_hovered_layer == hovered_layer:
		return
	side_view_hovered_layer = hovered_layer
	_update_side_view_layer_plane_materials()

func _update_side_view_layer_plane_materials() -> void:
	for layer in side_view_layer_materials.keys():
		var material := side_view_layer_materials[layer] as StandardMaterial3D
		if not material:
			continue
		if camera_mode_name == "side" and layer == side_view_hovered_layer:
			material.albedo_color = Color(0.58, 0.86, 1.0, 0.82)
		elif camera_mode_name == "side":
			material.albedo_color = Color(1.0, 1.0, 1.0, 0.55)
		else:
			material.albedo_color = Color(1.0, 1.0, 1.0, 0.0)

func _is_point_inside_grid_bounds(point: Vector3) -> bool:
	var bounds := _get_grid_bounds()
	if bounds.is_empty():
		return false
	var half_width := float(bounds.get("width", 0.0)) * 0.5
	var half_depth := float(bounds.get("depth", 0.0)) * 0.5
	var center_x := float(bounds.get("center_x", 0.0))
	var center_z := float(bounds.get("center_z", 0.0))
	return point.x >= center_x - half_width and point.x <= center_x + half_width and point.z >= center_z - half_depth and point.z <= center_z + half_depth

func on_camera_mode_changed(mode_name: String) -> void:
	camera_mode_name = mode_name
	side_view_hover_cache_valid = false
	if camera_mode_name != "side":
		side_view_hovered_layer = 999
	_apply_scene_layer_visibility()
	_update_layer_plane_visuals(active_build_view_layer)
	_update_side_view_layer_plane_materials()

func request_side_view_enter_layer(layer: int) -> void:
	_apply_build_view_layer(layer)

func get_default_first_person_position(fallback: Vector3) -> Vector3:
	var bounds := _get_grid_bounds()
	if bounds.is_empty() or not grid_map:
		return Vector3(fallback.x, 1.0, fallback.z)
	var cell_size := grid_map.cell_size
	var clamped_x := clampf(fallback.x, float(bounds.get("center_x", 0.0)) - float(bounds.get("width", 0.0)) * 0.5 + cell_size.x, float(bounds.get("center_x", 0.0)) + float(bounds.get("width", 0.0)) * 0.5 - cell_size.x)
	var clamped_z := clampf(fallback.z, float(bounds.get("center_z", 0.0)) - float(bounds.get("depth", 0.0)) * 0.5 + cell_size.z, float(bounds.get("center_z", 0.0)) + float(bounds.get("depth", 0.0)) * 0.5 - cell_size.z)
	return Vector3(clamped_x, 1.0, clamped_z)

func get_default_side_view_focus_position(fallback: Vector3) -> Vector3:
	var bounds := _get_grid_bounds()
	if bounds.is_empty():
		return Vector3(fallback.x, 0.5, fallback.z)
	return Vector3(float(bounds.get("center_x", 0.0)), 0.5, float(bounds.get("center_z", 0.0)))

func _should_show_ground_base(layer: int) -> bool:
	_ensure_revealed_floor_state()
	if camera_mode_name == "side":
		return true
	return layer == 0

func _toggle_first_person_floor_reveal_at_cursor() -> bool:
	_ensure_revealed_floor_state()
	if camera_mode_name != "first_person" or not grid_map or not scene_camera:
		return false
	var hit_result := _get_camera_cursor_hit(scene_camera)
	var sample_local: Vector3
	if hit_result.is_empty():
		var fallback_point :Variant= _intersect_cursor_with_floor_plane(scene_camera)
		if fallback_point == null:
			return false
		sample_local = grid_map.to_local(fallback_point as Vector3)
	else:
		var collider :Variant= hit_result.get("collider", null)
		if collider != grid_map:
			var fallback_point :Variant= _intersect_cursor_with_floor_plane(scene_camera)
			if fallback_point == null:
				return false
			sample_local = grid_map.to_local(fallback_point as Vector3)
		else:
			var hit_position := hit_result.get("position", Vector3.ZERO) as Vector3
			var hit_normal := hit_result.get("normal", Vector3.UP) as Vector3
			sample_local = grid_map.to_local(hit_position - hit_normal.normalized() * 0.02)
	var floor_cell := grid_map.local_to_map(sample_local)
	floor_cell.y = 0
	return _toggle_floor_cell_reveal(floor_cell)

func _get_camera_cursor_hit(camera: Camera3D) -> Dictionary:
	if not camera:
		return {}
	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	return get_world_3d().direct_space_state.intersect_ray(query)

func _intersect_cursor_with_floor_plane(camera: Camera3D) -> Variant:
	if not camera or not grid_map:
		return null
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	var floor_plane := Plane(Vector3.UP, grid_map.global_position.y)
	return floor_plane.intersects_ray(ray_origin, ray_direction)

func _toggle_floor_cell_reveal(cell: Vector3i) -> bool:
	_ensure_revealed_floor_state()
	if not grid_map:
		return false
	var cell_key := "%d,%d,%d" % [cell.x, cell.y, cell.z]
	if revealed_floor_cells.has(cell_key):
		var saved := revealed_floor_cells[cell_key] as Dictionary
		grid_map.set_cell_item(cell, int(saved.get("item", -1)), int(saved.get("orientation", 0)))
		revealed_floor_cells.erase(cell_key)
		_remove_revealed_floor_overlay(cell_key)
		_refresh_underfloor_visibility()
		_update_layer_plane_visuals(active_build_view_layer)
		return true
	var item := grid_map.get_cell_item(cell)
	if item < 0:
		return false
	var orientation := grid_map.get_cell_item_orientation(cell)
	revealed_floor_cells[cell_key] = {
		"item": item,
		"orientation": orientation,
	}
	grid_map.set_cell_item(cell, -1)
	_ensure_revealed_floor_overlay(cell, cell_key)
	_refresh_underfloor_visibility()
	_update_layer_plane_visuals(active_build_view_layer)
	return true


func _refresh_underfloor_visibility() -> void:
	_ensure_revealed_floor_state()
	if not grid_map:
		return
	for child in get_children():
		if not child is Node3D:
			continue
		var node := child as Node3D
		if not node.has_meta("build_view_layer"):
			continue
		if int(node.get_meta("build_view_layer", 0)) != -1:
			continue
		node.visible = _node_overlaps_any_revealed_floor_cell(node)

func _node_overlaps_any_revealed_floor_cell(node: Node3D) -> bool:
	_ensure_revealed_floor_state()
	for cell_key in revealed_floor_cells.keys():
		if _node_overlaps_floor_cell(node, _cell_key_to_vec3i(cell_key)):
			return true
	return false

func _node_overlaps_floor_cell(node: Node3D, cell: Vector3i) -> bool:
	var node_bounds := _get_node_world_xz_bounds(node)
	if node_bounds.is_empty():
		return false
	var cell_bounds := _get_floor_cell_world_xz_bounds(cell)
	return float(node_bounds.get("min_x", 0.0)) <= float(cell_bounds.get("max_x", 0.0)) \
		and float(node_bounds.get("max_x", 0.0)) >= float(cell_bounds.get("min_x", 0.0)) \
		and float(node_bounds.get("min_z", 0.0)) <= float(cell_bounds.get("max_z", 0.0)) \
		and float(node_bounds.get("max_z", 0.0)) >= float(cell_bounds.get("min_z", 0.0))

func _get_floor_cell_world_xz_bounds(cell: Vector3i) -> Dictionary:
	var cell_center_global := grid_map.to_global(grid_map.map_to_local(cell))
	var half_x := grid_map.cell_size.x * 0.5
	var half_z := grid_map.cell_size.z * 0.5
	return {
		"min_x": cell_center_global.x - half_x,
		"max_x": cell_center_global.x + half_x,
		"min_z": cell_center_global.z - half_z,
		"max_z": cell_center_global.z + half_z,
	}

func _get_node_world_xz_bounds(node: Node3D) -> Dictionary:
	var bounds := {
		"min_x": INF,
		"max_x": -INF,
		"min_z": INF,
		"max_z": -INF,
	}
	if not _append_node_world_xz_bounds(node, bounds):
		return {}
	return bounds

func _append_node_world_xz_bounds(node: Node, bounds: Dictionary) -> bool:
	var has_bounds := false
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			var local_aabb := mesh_instance.mesh.get_aabb()
			for corner in _get_aabb_corners(local_aabb):
				var world_corner := mesh_instance.to_global(corner)
				bounds["min_x"] = minf(float(bounds.get("min_x", INF)), world_corner.x)
				bounds["max_x"] = maxf(float(bounds.get("max_x", -INF)), world_corner.x)
				bounds["min_z"] = minf(float(bounds.get("min_z", INF)), world_corner.z)
				bounds["max_z"] = maxf(float(bounds.get("max_z", -INF)), world_corner.z)
			has_bounds = true
	for child in node.get_children():
		has_bounds = _append_node_world_xz_bounds(child, bounds) or has_bounds
	return has_bounds

func _get_aabb_corners(aabb: AABB) -> Array[Vector3]:
	var position := aabb.position
	var size := aabb.size
	return [
		position,
		position + Vector3(size.x, 0.0, 0.0),
		position + Vector3(0.0, 0.0, size.z),
		position + Vector3(size.x, 0.0, size.z),
		position + Vector3(0.0, size.y, 0.0),
		position + Vector3(size.x, size.y, 0.0),
		position + Vector3(0.0, size.y, size.z),
		position + size,
	]

func _cell_key_to_vec3i(cell_key: String) -> Vector3i:
	var parts := cell_key.split(",")
	if parts.size() != 3:
		return Vector3i.ZERO
	return Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))

func _ensure_revealed_floor_overlay(cell: Vector3i, cell_key: String) -> void:
	_ensure_revealed_floor_state()
	if revealed_floor_overlays.has(cell_key) or not grid_map:
		return
	var overlay_root := Node3D.new()
	overlay_root.name = "RevealedFloorOverlay_%s" % cell_key.replace(",", "_")
	var cell_center_global := grid_map.to_global(grid_map.map_to_local(cell))
	overlay_root.global_position = Vector3(cell_center_global.x, _get_view_layer_plane_y(-1), cell_center_global.z)

	var grid_overlay := MeshInstance3D.new()
	grid_overlay.mesh = _build_single_cell_grid_mesh()
	grid_overlay.position.y = LAYER_GRID_ELEVATION
	var grid_material := StandardMaterial3D.new()
	grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid_material.vertex_color_use_as_albedo = true
	grid_overlay.material_override = grid_material
	overlay_root.add_child(grid_overlay)

	revealed_floor_overlays[cell_key] = overlay_root
	add_child(overlay_root)

func _remove_revealed_floor_overlay(cell_key: String) -> void:
	_ensure_revealed_floor_state()
	if not revealed_floor_overlays.has(cell_key):
		return
	var overlay_root := revealed_floor_overlays[cell_key] as Node3D
	if overlay_root:
		overlay_root.queue_free()
	revealed_floor_overlays.erase(cell_key)

func _ensure_revealed_floor_state() -> void:
	if typeof(revealed_floor_cells) != TYPE_DICTIONARY:
		revealed_floor_cells = {}
	if typeof(revealed_floor_overlays) != TYPE_DICTIONARY:
		revealed_floor_overlays = {}

func _build_single_cell_grid_mesh() -> ArrayMesh:
	if not grid_map:
		return null
	var half_x := grid_map.cell_size.x * 0.5
	var half_z := grid_map.cell_size.z * 0.5
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	_append_dashed_line(vertices, colors, Vector3(-half_x, 0.0, -half_z), Vector3(half_x, 0.0, -half_z), LAYER_GRID_COLOR)
	_append_dashed_line(vertices, colors, Vector3(half_x, 0.0, -half_z), Vector3(half_x, 0.0, half_z), LAYER_GRID_COLOR)
	_append_dashed_line(vertices, colors, Vector3(half_x, 0.0, half_z), Vector3(-half_x, 0.0, half_z), LAYER_GRID_COLOR)
	_append_dashed_line(vertices, colors, Vector3(-half_x, 0.0, half_z), Vector3(-half_x, 0.0, -half_z), LAYER_GRID_COLOR)
	if vertices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh

func _build_layer_grid_mesh() -> ArrayMesh:
	if not grid_map:
		return null
	var bounds := _get_grid_bounds()
	if bounds.is_empty():
		return null
	var cell_size := grid_map.cell_size
	var x_start := float(bounds.get("center_x", 0.0)) - float(bounds.get("width", 0.0)) * 0.5
	var x_end := float(bounds.get("center_x", 0.0)) + float(bounds.get("width", 0.0)) * 0.5
	var z_start := float(bounds.get("center_z", 0.0)) - float(bounds.get("depth", 0.0)) * 0.5
	var z_end := float(bounds.get("center_z", 0.0)) + float(bounds.get("depth", 0.0)) * 0.5
	var width_steps := int(round((x_end - x_start) / cell_size.x))
	var depth_steps := int(round((z_end - z_start) / cell_size.z))
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for x_index in range(width_steps + 1):
		var x := x_start + x_index * cell_size.x
		_append_dashed_line(vertices, colors, Vector3(x, 0.0, z_start), Vector3(x, 0.0, z_end), LAYER_GRID_COLOR)
	for z_index in range(depth_steps + 1):
		var z := z_start + z_index * cell_size.z
		_append_dashed_line(vertices, colors, Vector3(x_start, 0.0, z), Vector3(x_end, 0.0, z), LAYER_GRID_COLOR)
	if vertices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh

func _append_dashed_line(vertices: PackedVector3Array, colors: PackedColorArray, start: Vector3, finish: Vector3, color: Color) -> void:
	var direction := finish - start
	var total_length := direction.length()
	if total_length <= 0.001:
		return
	var normal := direction / total_length
	var cursor := 0.0
	while cursor < total_length:
		var segment_end := minf(cursor + LAYER_GRID_DASH_LENGTH, total_length)
		vertices.append(start + normal * cursor)
		vertices.append(start + normal * segment_end)
		colors.append(color)
		colors.append(color)
		cursor = segment_end + LAYER_GRID_GAP_LENGTH

func _build_pipe_icon() -> Texture2D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for x in range(10, 54):
		for y in range(26, 38):
			var dx := minf(float(x - 10), float(53 - x))
			var edge_alpha := clampf(dx / 6.0, 0.35, 1.0)
			image.set_pixel(x, y, Color(0.18, 0.82, 0.92, edge_alpha))
	for x in range(14, 50):
		image.set_pixel(x, 27, Color(0.82, 0.98, 1.0, 0.8))
		image.set_pixel(x, 36, Color(0.04, 0.36, 0.44, 0.6))
	return ImageTexture.create_from_image(image)

func _build_trench_icon() -> Texture2D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for x in range(12, 22):
		for y in range(16, 48):
			image.set_pixel(x, y, Color(0.55, 0.57, 0.6, 0.96))
	for x in range(42, 52):
		for y in range(16, 48):
			image.set_pixel(x, y, Color(0.55, 0.57, 0.6, 0.96))
	for x in range(12, 52):
		for y in range(38, 50):
			image.set_pixel(x, y, Color(0.46, 0.48, 0.5, 0.98))
	for x in range(14, 50):
		image.set_pixel(x, 38, Color(0.82, 0.84, 0.87, 0.86))
	for y in range(17, 47):
		image.set_pixel(13, y, Color(0.84, 0.86, 0.9, 0.82))
		image.set_pixel(50, y, Color(0.28, 0.3, 0.34, 0.72))
	return ImageTexture.create_from_image(image)

func _build_pipe_preview_mesh() -> CylinderMesh:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.18, 0.82, 0.92, 0.72)
	material.metallic = 0.18
	material.roughness = 0.28
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.1
	mesh.bottom_radius = 0.1
	mesh.height = 1.0
	mesh.material = material
	return mesh

func _build_trench_preview_mesh() -> BoxMesh:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.58, 0.6, 0.62, 0.72)
	material.metallic = 0.05
	material.roughness = 0.86
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 1.0, 1.0)
	mesh.material = material
	return mesh

func _build_ceiling_tray_preview_mesh() -> BoxMesh:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.78, 0.8, 0.82, 0.72)
	material.metallic = 0.85
	material.metallic_specular = 0.75
	material.roughness = 0.24
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.52, 1.0, 0.11)
	mesh.material = material
	return mesh

func _build_layer_view_icon(active_layer: int) -> Texture2D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	_draw_layer_icon_frame(image, active_layer)
	_draw_layer_parallelogram(image, Rect2i(8, 41, 41, 9), 10, active_layer == -1, true)
	_draw_layer_parallelogram(image, Rect2i(10, 28, 41, 9), 10, active_layer == 0, false)
	_draw_layer_parallelogram(image, Rect2i(12, 15, 41, 9), 10, active_layer == 1, false)
	_draw_layer_badge(image, active_layer)
	return ImageTexture.create_from_image(image)

func _draw_layer_icon_frame(image: Image, active_layer: int) -> void:
	var frame_color := Color(0.11, 0.16, 0.22, 0.96)
	var inner_color := Color(0.9, 0.95, 1.0, 0.08)
	if active_layer == 0:
		inner_color = Color(0.58, 0.74, 0.96, 0.14)
	elif active_layer == -1:
		inner_color = Color(0.82, 0.88, 0.96, 0.16)
	else:
		inner_color = Color(0.64, 0.78, 0.98, 0.18)
	for y in range(4, 60):
		for x in range(4, 60):
			image.set_pixel(x, y, inner_color)
	for x in range(4, 60):
		image.set_pixel(x, 4, frame_color)
		image.set_pixel(x, 59, frame_color)
	for y in range(4, 60):
		image.set_pixel(4, y, frame_color)
		image.set_pixel(59, y, frame_color)

func _draw_layer_badge(image: Image, active_layer: int) -> void:
	var badge_rect := Rect2i(43, 7, 14, 14)
	var badge_color := Color(0.09, 0.14, 0.18, 0.96)
	var text_color := Color(0.98, 0.99, 1.0, 0.95)
	for y in range(badge_rect.position.y, badge_rect.position.y + badge_rect.size.y):
		for x in range(badge_rect.position.x, badge_rect.position.x + badge_rect.size.x):
			image.set_pixel(x, y, badge_color)
	for x in range(badge_rect.position.x, badge_rect.position.x + badge_rect.size.x):
		image.set_pixel(x, badge_rect.position.y, text_color)
		image.set_pixel(x, badge_rect.position.y + badge_rect.size.y - 1, text_color)
	for y in range(badge_rect.position.y, badge_rect.position.y + badge_rect.size.y):
		image.set_pixel(badge_rect.position.x, y, text_color)
		image.set_pixel(badge_rect.position.x + badge_rect.size.x - 1, y, text_color)
	match active_layer:
		-1:
			_draw_minus_glyph(image, Vector2i(49, 14), text_color)
		0:
			_draw_zero_glyph(image, Vector2i(50, 14), text_color)
		1:
			_draw_one_glyph(image, Vector2i(50, 14), text_color)

func _draw_minus_glyph(image: Image, center: Vector2i, color: Color) -> void:
	for x in range(center.x - 3, center.x + 3):
		image.set_pixel(x, center.y, color)
		image.set_pixel(x, center.y + 1, color)

func _draw_zero_glyph(image: Image, center: Vector2i, color: Color) -> void:
	for y in range(center.y - 3, center.y + 4):
		for x in range(center.x - 2, center.x + 3):
			var is_border := x == center.x - 2 or x == center.x + 2 or y == center.y - 3 or y == center.y + 3
			if is_border:
				image.set_pixel(x, y, color)

func _draw_one_glyph(image: Image, center: Vector2i, color: Color) -> void:
	for y in range(center.y - 3, center.y + 4):
		image.set_pixel(center.x, y, color)
		image.set_pixel(center.x + 1, y, color)
	for x in range(center.x - 2, center.x + 4):
		image.set_pixel(x, center.y + 3, color)

func _draw_layer_parallelogram(image: Image, rect: Rect2i, skew: int, is_active: bool, dashed_midline: bool) -> void:
	var fill_color := Color(0.36, 0.46, 0.56, 0.58)
	var stroke_color := Color(0.88, 0.93, 0.98, 0.9)
	var shine_color := Color(1.0, 1.0, 1.0, 0.0)
	if is_active:
		fill_color = Color(0.2, 0.62, 0.94, 0.96)
		stroke_color = Color(0.98, 1.0, 1.0, 1.0)
		shine_color = Color(0.92, 0.98, 1.0, 0.28)
	for local_y in range(rect.size.y):
		var x_start := rect.position.x + int(round(float(rect.size.y - local_y - 1) / float(rect.size.y) * skew))
		var x_end := x_start + rect.size.x
		for x in range(x_start, x_end):
			image.set_pixel(x, rect.position.y + local_y, fill_color)
			if local_y <= 1 and shine_color.a > 0.0:
				image.set_pixel(x, rect.position.y + local_y, shine_color)
	for local_y in [0, rect.size.y - 1]:
		var x_start := rect.position.x + int(round(float(rect.size.y - local_y - 1) / float(rect.size.y) * skew))
		for x in range(x_start, x_start + rect.size.x):
			image.set_pixel(x, rect.position.y + local_y, stroke_color)
	for local_y in range(rect.size.y):
		var left_x := rect.position.x + int(round(float(rect.size.y - local_y - 1) / float(rect.size.y) * skew))
		var right_x := left_x + rect.size.x - 1
		image.set_pixel(left_x, rect.position.y + local_y, stroke_color)
		image.set_pixel(right_x, rect.position.y + local_y, stroke_color)
	if dashed_midline:
		var mid_y := rect.position.y + rect.size.y / 2
		var x_start := rect.position.x + skew / 2 + 2
		for x in range(x_start, x_start + rect.size.x - 8):
			if ((x - x_start) / 3) % 2 == 0:
				image.set_pixel(x, mid_y, Color(1.0, 1.0, 1.0, 0.86))
