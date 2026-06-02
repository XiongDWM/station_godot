extends Node3D

const BuildingControllerScript = preload("res://scripts/controllers/building_controller.gd")
const LayoutSerializerScript = preload("res://scripts/serializers/layout_serializer.gd")
const LayoutFlowControllerScript = preload("res://scripts/controllers/layout_flow_controller.gd")
const SelectionControllerScript = preload("res://scripts/controllers/selection_controller.gd")
const BUILD_VIEW_ORDER := [0, -1, 1]
const BUILD_VIEW_LABELS := {
	-1: "下层管线",
	0: "中层结构",
	1: "上层管线",
}
const GROUND_BASE_SIZE := Vector2(1600.0, 1600.0)
const GROUND_BASE_THICKNESS := 0.06
const GROUND_BASE_MARGIN := 0.0
const LAYER_GRID_COLOR := Color(0.08, 0.08, 0.08, 0.72)
const LAYER_GRID_DASH_LENGTH := 0.38
const LAYER_GRID_GAP_LENGTH := 0.24
const LAYER_GRID_ELEVATION := 0.02

@export_group("Ground Base")
@export var ground_base_color: Color = Color(0.70, 0.74, 0.78, 1.0)
@export_range(0.0, 1.0, 0.01) var ground_base_specular: float = 0.02
@export_range(0.0, 1.0, 0.01) var ground_base_roughness: float = 0.92

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
@export var runtime_view_layer_button: Button

var building_controller := BuildingControllerScript.new()
var layout_serializer := LayoutSerializerScript.new()
var layout_flow_controller := LayoutFlowControllerScript.new()
var selection_controller := SelectionControllerScript.new()
var active_build_view_layer := 0
var pipe_button_icon: Texture2D
var layer_button_icons := {}
var scene_camera: Camera3D
var ground_base: MeshInstance3D
var layer_grid_overlay: MeshInstance3D
var runtime_preview_pipe: MeshInstance3D

func _ready():
	# print("[MainScene._ready] btn_cube=", btn_cube, ", btn_wall=", btn_wall, ", preview_cube=", preview_cube, ", preview_wall=", preview_wall, ", block_scene=", block_scene, ", wall_scene=", wall_scene)
	_configure_build_toolbar()
	_setup_ground_base()
	_setup_layer_grid_overlay()
	scene_camera = get_node_or_null("CameraPivot/Camera3D") as Camera3D
	building_controller.initialize(preview_cube, preview_wall, runtime_preview_pipe, preview_rack)
	building_controller.bind_buttons(btn_cube, btn_rack, btn_wall, btn_door, runtime_pipe_button, block_scene, rack_scene, wall_scene, door_scene, pipe_scene, preview_cube, preview_rack, preview_wall, runtime_preview_pipe, self, &"_on_building_mode_selected")
	selection_controller.initialize(operation_panel, module_panel)
	selection_controller.bind_buttons(btn_rotate, btn_delete, self, &"_on_rotate_selected_object", &"_on_delete_selected_object")
	layout_flow_controller.setup(self, http_request, layout_serializer)
	layout_flow_controller.bind_save_button(btn_save)
	layout_flow_controller.bind_api_signals()
	layout_flow_controller.bootstrap()
	_apply_build_view_layer(active_build_view_layer)

func _on_building_mode_selected(scene: PackedScene, preview: MeshInstance3D, placement_mode: String = "point"):
	# print("[MainScene._on_building_mode_selected] scene=", scene, ", preview=", preview)
	building_controller.set_building_mode(scene, preview, operation_panel, module_panel, placement_mode)

func _process(_delta):
	_update_ground_base_position()
	if selection_controller.has_visible_panel(operation_panel, module_panel):
		return
	if building_controller.is_active() and building_controller.get_preview():
		building_controller.handle_preview_logic(self, grid_map)

func _unhandled_input(event):
	if building_controller.handle_unhandled_input(self, event):
		return
	if selection_controller.handle_unhandled_input(self, event, operation_panel, module_panel):
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

func _on_rotate_selected_object():
	selection_controller.rotate_selected_object()

func _on_delete_selected_object():
	selection_controller.delete_selected_object(operation_panel)

func _configure_build_toolbar() -> void:
	_configure_pipe_preview()
	_configure_runtime_pipe_button()
	_configure_view_layer_button()
	pipe_button_icon = _build_pipe_icon()
	for layer in BUILD_VIEW_ORDER:
		layer_button_icons[layer] = _build_layer_view_icon(layer)
	if runtime_pipe_button:
		runtime_pipe_button.tooltip_text = "绘制管线"
		runtime_pipe_button.icon = pipe_button_icon
		runtime_pipe_button.expand_icon = true
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

func _configure_pipe_preview() -> void:
	if runtime_preview_pipe:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.18, 0.82, 0.92, 0.72)
	material.metallic = 0.18
	material.roughness = 0.28
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.1
	mesh.bottom_radius = 0.1
	mesh.height = 1.0
	mesh.material = material
	runtime_preview_pipe = MeshInstance3D.new()
	runtime_preview_pipe.name = "PreviewPipe"
	runtime_preview_pipe.mesh = mesh
	runtime_preview_pipe.visible = false
	runtime_preview_pipe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(runtime_preview_pipe)

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
	if runtime_view_layer_button:
		runtime_view_layer_button.visible = true
		runtime_view_layer_button.tooltip_text = "视图层: %s" % BUILD_VIEW_LABELS.get(layer, "中层结构")
		runtime_view_layer_button.icon = layer_button_icons.get(layer, null)
		runtime_view_layer_button.expand_icon = true

func _enforce_build_mode_for_active_layer() -> void:
	var placement_mode := building_controller.get_placement_mode()
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
		node.visible = layer == active_build_view_layer

func _update_layer_plane_visuals(layer: int) -> void:
	if grid_map:
		grid_map.visible = layer == 0
	if ground_base:
		ground_base.visible = layer == 0
	if not layer_grid_overlay:
		return
	layer_grid_overlay.visible = layer != 0
	if layer != 0:
		layer_grid_overlay.position.y = _get_view_layer_plane_y(layer) + LAYER_GRID_ELEVATION

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
	if scene_camera:
		center_x = scene_camera.global_position.x
		center_z = scene_camera.global_position.z
	return Vector3(
		center_x,
		0.0,
		center_z
	)

func _update_ground_base_position() -> void:
	if not ground_base:
		return
	ground_base.position = _get_ground_base_position()

func _get_grid_bounds() -> Dictionary:
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
	return {
		"center_x": (x_start + x_end) * 0.5,
		"center_z": (z_start + z_end) * 0.5,
		"width": x_end - x_start,
		"depth": z_end - z_start,
	}

func _get_view_layer_plane_y(layer: int) -> float:
	match layer:
		-1:
			return -1.0
		1:
			return 2.0
		_:
			return 0.0

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
