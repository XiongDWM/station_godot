extends RefCounted

class_name BuildingController

var current_building := {
	"scene": null,
	"preview": null,
	"is_active": false,
}

func initialize(preview_cube: MeshInstance3D, preview_wall: MeshInstance3D) -> void:
	if preview_cube:
		preview_cube.visible = false
	if preview_wall:
		preview_wall.visible = false

func bind_buttons(btn_cube: Button, btn_wall: Button, block_scene: PackedScene, wall_scene: PackedScene, preview_cube: MeshInstance3D, preview_wall: MeshInstance3D, target: Object, method: StringName) -> void:
	if btn_cube:
		btn_cube.pressed.connect(Callable(target, method).bind(block_scene, preview_cube))
	if btn_wall:
		btn_wall.pressed.connect(Callable(target, method).bind(wall_scene, preview_wall))

func set_building_mode(scene: PackedScene, preview: MeshInstance3D, operation_panel: Control, module_panel: Control) -> void:
	if current_building["scene"] == scene and current_building["is_active"]:
		current_building["is_active"] = false
		print("退出建造模式")
	else:
		current_building["scene"] = scene
		current_building["preview"] = preview
		current_building["is_active"] = true
		if operation_panel:
			operation_panel.visible = false
		if module_panel:
			module_panel.visible = false
		print("进入建造模式: ", scene.resource_path)
	update_ui()

func update_ui() -> void:
	var preview = current_building["preview"]
	if preview and preview is MeshInstance3D:
		preview.visible = current_building["is_active"]

func is_active() -> bool:
	return current_building["is_active"]

func get_preview() -> MeshInstance3D:
	return current_building["preview"]

func handle_preview_logic(root: Node3D, grid_map: GridMap) -> void:
	if not grid_map:
		return
	var camera = root.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if not camera:
		return
	var mouse_pos = root.get_viewport().get_mouse_position()
	var space_state = root.get_world_3d().direct_space_state
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 100.0
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)

	if result:
		var cell_size = grid_map.cell_size
		var hit_pos = result.position
		var local_pos = grid_map.to_local(hit_pos)

		var preview_mesh = current_building["preview"] as MeshInstance3D
		if not preview_mesh or not preview_mesh.mesh:
			return
		var preview_size = preview_mesh.mesh.get_aabb().size
		var size_after_scale = preview_size * preview_mesh.global_transform.basis.get_scale()
		var y_offset = size_after_scale.y / 2

		var map_coord = Vector3i(
			floor(local_pos.x / cell_size.x),
			floor(local_pos.y / cell_size.y),
			floor(local_pos.z / cell_size.z)
		)
		var final_pos = grid_map.map_to_local(map_coord)
		final_pos.y = hit_pos.y + y_offset

		preview_mesh.global_position = final_pos
		preview_mesh.visible = true
	else:
		var preview_mesh = current_building["preview"] as MeshInstance3D
		if preview_mesh:
			preview_mesh.visible = false

func handle_unhandled_input(root: Node, event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and event.keycode == Key.KEY_ESCAPE and current_building["is_active"]:
		current_building["is_active"] = false
		update_ui()
		print("退出建造")
		root.get_viewport().set_input_as_handled()
		return true

	if event is InputEventKey and event.pressed == false and current_building["is_active"] and current_building["preview"]:
		var preview_mesh = current_building["preview"] as Node3D
		if event.keycode == Key.KEY_LEFT:
			preview_mesh.rotate_y(deg_to_rad(45))
			root.get_viewport().set_input_as_handled()
			return true
		if event.keycode == Key.KEY_RIGHT:
			preview_mesh.rotate_y(deg_to_rad(-45))
			root.get_viewport().set_input_as_handled()
			return true

	return false

func place_current_building(root: Node3D) -> void:
	var scene_to_spawn = current_building["scene"] as PackedScene
	var preview_node = current_building["preview"] as Node3D
	if not scene_to_spawn or not preview_node:
		return
	var new_building = scene_to_spawn.instantiate()
	root.add_child(new_building)
	new_building.global_transform = preview_node.global_transform
	print("放置了: ", scene_to_spawn.resource_path)