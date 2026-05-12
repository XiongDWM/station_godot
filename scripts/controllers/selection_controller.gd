extends RefCounted

class_name SelectionController

var selected_object: Node3D = null
var selected_module_object: Node3D = null

func initialize(operation_panel: Control, module_panel: Control) -> void:
	if operation_panel:
		operation_panel.visible = false
	if module_panel:
		module_panel.visible = false

func bind_buttons(btn_rotate: Button, btn_delete: Button, target: Object, rotate_method: StringName, delete_method: StringName) -> void:
	if btn_rotate:
		btn_rotate.pressed.connect(Callable(target, rotate_method))
	if btn_delete:
		btn_delete.pressed.connect(Callable(target, delete_method))

func has_visible_panel(operation_panel: Control, module_panel: Control) -> bool:
	return (operation_panel and operation_panel.visible) or (module_panel and module_panel.visible)

func handle_escape(root: Node, operation_panel: Control, module_panel: Control) -> bool:
	if operation_panel and operation_panel.visible:
		operation_panel.visible = false
		selected_object = null
		root.get_viewport().set_input_as_handled()
		return true
	if module_panel and module_panel.visible:
		module_panel.visible = false
		selected_module_object = null
		root.get_viewport().set_input_as_handled()
		return true
	return false

func handle_unhandled_input(root: Node, event: InputEvent, operation_panel: Control, module_panel: Control) -> bool:
	if event is InputEventKey and event.pressed and event.keycode == Key.KEY_ESCAPE:
		return handle_escape(root, operation_panel, module_panel)
	return false

func handle_left_click_module(root: Node3D, block_scene: PackedScene, module_panel: Panel) -> void:
	if not block_scene:
		push_warning("SelectionController.handle_left_click_module: block_scene is not assigned.")
		return
	var camera = root.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if not camera:
		return
	var mouse_pos = root.get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = root.get_world_3d().direct_space_state.intersect_ray(query)

	if result:
		var collider = result.collider as Node3D
		if collider and collider.scene_file_path == block_scene.resource_path:
			selected_module_object = collider
			show_module_panel(collider, module_panel)

func handle_right_click_operation(root: Node3D, grid_map: GridMap, preview_cube: MeshInstance3D, preview_wall: MeshInstance3D, operation_panel: Control) -> void:
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
	query.exclude = exclude_array
	var result = root.get_world_3d().direct_space_state.intersect_ray(query)

	if result:
		var collider = result.collider as Node3D
		if collider == grid_map:
			return
		selected_object = collider
		show_operation_panel(collider, operation_panel, camera)

func toggle_panels_on_right_click(operation_panel: Control, module_panel: Control) -> bool:
	if operation_panel and operation_panel.visible:
		operation_panel.visible = false
		selected_object = null
		return true
	if module_panel and module_panel.visible:
		module_panel.visible = false
		selected_module_object = null
		return true
	return false

func show_module_panel(target: Node3D, module_panel: Panel) -> void:
	if not module_panel or not target:
		return
	module_panel.visible = true

func show_operation_panel(target: Node3D, operation_panel: Control, camera: Camera3D) -> void:
	if not operation_panel or not target or not camera:
		return
	operation_panel.visible = true
	var screen_pos = camera.unproject_position(target.global_position)
	operation_panel.position = screen_pos - operation_panel.size / 2

func rotate_selected_object() -> void:
	if selected_object:
		selected_object.rotate_y(deg_to_rad(-45))

func delete_selected_object(operation_panel: Control) -> void:
	if selected_object:
		selected_object.queue_free()
		if operation_panel:
			operation_panel.visible = false
		selected_object = null
