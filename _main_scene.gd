extends Node3D

@export var grid_map: GridMap
@export var button_cube: Button
@export var button_wall: Button
@export var preview_cube: MeshInstance3D
@export var preview_wall: MeshInstance3D
@export var block_scene: PackedScene
@export var wall_scene: PackedScene
@export var module_panel: Panel
@export var operation_panel: Control 
@export var btn_rotate: Button
@export var btn_delete: Button

var current_building = {
	"scene": null,
	"preview": null,
	"is_active": false
}

# 当前右键选中的物体
var selected_object: Node3D = null
# 左键选中的物体 (用于 module_panel)
var selected_module_object: Node3D = null

func _ready():
	if preview_cube: preview_cube.visible = false
	if preview_wall: preview_wall.visible = false
	if operation_panel: operation_panel.visible = false 
	if module_panel: module_panel.visible = false
	
	if button_cube: button_cube.pressed.connect(_on_building_mode_selected.bind(block_scene, preview_cube))
	if button_wall: button_wall.pressed.connect(_on_building_mode_selected.bind(wall_scene, preview_wall))
	
	# 连接面板按钮的信号
	if btn_rotate: btn_rotate.pressed.connect(_on_rotate_selected_object)
	if btn_delete: btn_delete.pressed.connect(_on_delete_selected_object)

func _on_building_mode_selected(scene: PackedScene, preview: MeshInstance3D):
	if current_building["scene"] == scene and current_building["is_active"]:
		current_building["is_active"] = false
		print("退出建造模式")
	else:
		current_building["scene"] = scene
		current_building["preview"] = preview
		current_building["is_active"] = true
		# 进入建造模式时，隐藏所有面板
		if operation_panel: operation_panel.visible = false
		if module_panel: module_panel.visible = false
		print("进入建造模式: ", scene.resource_path)
	update_ui()

func update_ui():
	if preview_cube: preview_cube.visible = (current_building["is_active"] and current_building["preview"] == preview_cube)
	if preview_wall: preview_wall.visible = (current_building["is_active"] and current_building["preview"] == preview_wall)

func _process(delta):
	# 如果打开了任意面板，暂停预览块的逻辑
	if (operation_panel and operation_panel.visible) or (module_panel and module_panel.visible):
		return

	# 1. 处理建造模式下的预览块逻辑
	if current_building["is_active"] and current_building["preview"]:
		handle_preview_logic(delta)

func handle_preview_logic(delta):
	if not grid_map: return
	var camera = $CameraPivot/Camera3D
	if not camera: return
	var mouse_pos = get_viewport().get_mouse_position()
	var space_state = get_world_3d().direct_space_state
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 100.0
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		var cell_size = grid_map.cell_size
		var hit_pos = result.position
		var local_pos = grid_map.to_local(hit_pos)
		
		var preview_mesh = current_building["preview"]
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
		if current_building["preview"]:
			current_building["preview"].visible = false

func _unhandled_input(event):
	# 专门处理 ESC 键
	if event is InputEventKey and event.pressed and event.keycode == Key.KEY_ESCAPE:
		if current_building["is_active"]:
			current_building["is_active"] = false
			update_ui()
			print("退出建造")
			get_viewport().set_input_as_handled()
			return

		if operation_panel and operation_panel.visible:
			operation_panel.visible = false
			selected_object = null
			get_viewport().set_input_as_handled()
			return
		# 关闭 module_panel
		if module_panel and module_panel.visible:
			module_panel.visible = false
			selected_module_object = null
			get_viewport().set_input_as_handled()
			return

	# 旋转预览块
	if event is InputEventKey and event.pressed == false:
		if current_building["is_active"] and current_building["preview"]:
			if event.keycode == Key.KEY_LEFT:
				current_building["preview"].rotate_y(deg_to_rad(45))
				get_viewport().set_input_as_handled()
			if event.keycode == Key.KEY_RIGHT:
				current_building["preview"].rotate_y(deg_to_rad(-45))
				get_viewport().set_input_as_handled()

func place_current_building():
	var scene_to_spawn = current_building["scene"]
	var preview_node = current_building["preview"]
	if not scene_to_spawn or not preview_node:
		return
	var new_building = scene_to_spawn.instantiate()
	add_child(new_building)
	new_building.global_transform = preview_node.global_transform
	print("放置了: ", scene_to_spawn.resource_path)

# ------------------- 核心修改区域 -------------------

func _input(event):
	# 如果按下了 Alt 键，直接跳过所有点击逻辑（把操作权完全交给摄像机脚本）
	if Input.is_key_pressed(KEY_ALT):
		return

	if event is InputEventMouseButton and event.pressed:
		# 左键逻辑
		if event.button_index == MOUSE_BUTTON_LEFT:
			if current_building["is_active"]:
				place_current_building()
				return # 建造模式下左键只负责放置

			# 【新增】非建造模式下，左键点击弹出 module_panel
			handle_left_click_module()

		# 右键逻辑
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# 如果面板已经打开，右键视为关闭面板
			if operation_panel and operation_panel.visible:
				operation_panel.visible = false
				selected_object = null
				return
			if module_panel and module_panel.visible:
				module_panel.visible = false
				selected_module_object = null
				return

			# 发射射线检测是否点到了物体
			handle_right_click_operation()

# 处理左键点击 Block 弹出 Module 面板
func handle_left_click_module():
	var mouse_pos = get_viewport().get_mouse_position()
	var camera = $CameraPivot/Camera3D
	if not camera: return

	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	var query = PhysicsRayQueryParameters3D.create(from, to)
	
	var space_state = get_world_3d().direct_space_state
	var result = space_state.intersect_ray(query)

	if result:
		var collider = result.collider
		# 判断点击的物体是不是 block_scene 实例化出来的
		# 通过对比场景资源路径来判断
		if collider.scene_file_path == block_scene.resource_path:
			selected_module_object = collider
			show_module_panel(collider)

# 处理右键点击弹出 Operation 面板
func handle_right_click_operation():
	var mouse_pos = get_viewport().get_mouse_position()
	var camera = $CameraPivot/Camera3D
	if not camera: return

	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	var query = PhysicsRayQueryParameters3D.create(from, to)
	
	# 排除掉预览块
	var exclude_array = []
	if preview_cube: exclude_array.append(preview_cube)
	if preview_wall: exclude_array.append(preview_wall)
	query.exclude = exclude_array

	var space_state = get_world_3d().direct_space_state
	var result = space_state.intersect_ray(query)

	if result:
		var collider = result.collider
		selected_object = collider
		show_operation_panel(collider)

# 显示 module_panel 并跟随物体
func show_module_panel(target: Node3D):
	if not module_panel or not target: return
	module_panel.visible = true

# 显示 operation_panel 并跟随物体
func show_operation_panel(target: Node3D):
	if not operation_panel or not target: return
	operation_panel.visible = true
	var screen_pos = $CameraPivot/Camera3D.unproject_position(target.global_position)
	operation_panel.position = screen_pos - operation_panel.size / 2

# 面板按钮的回调
func _on_rotate_selected_object():
	if selected_object:
		selected_object.rotate_y(deg_to_rad(-45))

func _on_delete_selected_object():
	if selected_object:
		selected_object.queue_free()
		operation_panel.visible = false
		selected_object = null
