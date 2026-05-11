extends Node3D

@export var grid_map: GridMap
@export var btn_cube: Button
@export var btn_wall: Button
@export var preview_cube: MeshInstance3D
@export var preview_wall: MeshInstance3D
@export var block_scene: PackedScene
@export var wall_scene: PackedScene
@export var module_panel: Panel
@export var operation_panel: Control 
@export var btn_rotate: Button
@export var btn_delete: Button
@export var btn_save:Button
@export var http_request:HTTPRequest

var current_building = {
	"scene": null,
	"preview": null,
	"is_active": false
}
var layout_data_array=[]
var current_station_id: int = -1
# 当前右键选中的物体
var selected_object: Node3D = null
# 左键选中的物体 (用于 module_panel)
var selected_module_object: Node3D = null

func _get_app_state() -> Node:
	return get_node_or_null("/root/AppState")

func _ready():
	if preview_cube: preview_cube.visible = false
	if preview_wall: preview_wall.visible = false
	if operation_panel: operation_panel.visible = false 
	if module_panel: module_panel.visible = false
	
	if btn_cube: btn_cube.pressed.connect(_on_building_mode_selected.bind(block_scene, preview_cube))
	if btn_wall: btn_wall.pressed.connect(_on_building_mode_selected.bind(wall_scene, preview_wall))
	
	# 连接面板按钮的信号
	if btn_rotate: btn_rotate.pressed.connect(_on_rotate_selected_object)
	if btn_delete: btn_delete.pressed.connect(_on_delete_selected_object)
	if btn_save: btn_save.pressed.connect(save_layoutdata)

	# 从全局状态恢复 station_id
	var app_state = _get_app_state()
	if app_state and app_state.has_method("get_station_id"):
		current_station_id = app_state.get_station_id()

	# 连接 API 管理器信号
	if http_request:
		if http_request.has_signal("station_id_changed") and not http_request.station_id_changed.is_connected(_on_station_id_changed):
			http_request.station_id_changed.connect(_on_station_id_changed)
		if http_request.has_signal("data_received") and not http_request.data_received.is_connected(_on_layout_data_received):
			http_request.data_received.connect(_on_layout_data_received)
		if http_request.has_signal("save_completed") and not http_request.save_completed.is_connected(_on_layout_saved):
			http_request.save_completed.connect(_on_layout_saved)
		if http_request.has_signal("request_failed") and not http_request.request_failed.is_connected(_on_api_request_failed):
			http_request.request_failed.connect(_on_api_request_failed)

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

func handle_preview_logic(_delta):
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

func _input(event):
	# 如果按下了 ctrl 键，直接跳过所有点击逻辑（把操作权完全交给摄像机脚本）
	if Input.is_key_pressed(KEY_CTRL):
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
		# 如果点到的是 grid_map（地板），则不弹出 operation_panel
		if collider == grid_map:
			return
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
		
func save_layoutdata():
	layout_data_array.clear()
	
	for child in get_children():
		# 筛选条件：必须是 MeshInstance3D，且不是预览块，且不在 "preview" 组里
		if child is MeshInstance3D and not child.is_in_group("preview"):
			
			# 获取该物体的全局变换信息 (包含位置、旋转、缩放)
			var global_xform = child.global_transform
			
			var item_info = {
				"scene_path": child.scene_file_path, # 记录场景路径，用于重新实例化
				# 记录位置
				"position": {
					"x": global_xform.origin.x,
					"y": global_xform.origin.y,
					"z": global_xform.origin.z
				},
				# 记录旋转和缩放 (Basis 矩阵)
				"basis": {
					"x": {"x": global_xform.basis.x.x, "y": global_xform.basis.x.y, "z": global_xform.basis.x.z},
					"y": {"x": global_xform.basis.y.x, "y": global_xform.basis.y.y, "z": global_xform.basis.y.z},
					"z": {"x": global_xform.basis.z.x, "y": global_xform.basis.z.y, "z": global_xform.basis.z.z}
				}
			}
			layout_data_array.append(item_info)
	
	var json_string = JSON.stringify(layout_data_array, "  ") # "  " 是为了格式化缩进，方便调试
	print("布局数据:\n", json_string)
	var app_state = _get_app_state()
	if app_state and app_state.has_method("get_station_id"):
		current_station_id = app_state.get_station_id()
	if http_request and http_request.has_method("save_layout_data"):
		http_request.save_layout_data(json_string, current_station_id)
	return json_string

func set_station_id(station_id: int) -> void:
	current_station_id = station_id
	var app_state = _get_app_state()
	if app_state and app_state.has_method("set_station_id"):
		app_state.set_station_id(station_id)

func get_station_id() -> int:
	var app_state = _get_app_state()
	if app_state and app_state.has_method("get_station_id"):
		return app_state.get_station_id()
	return current_station_id

func _on_station_id_changed(station_id: int) -> void:
	current_station_id = station_id
	var app_state = _get_app_state()
	if app_state and app_state.has_method("set_station_id"):
		app_state.set_station_id(station_id)
	print("当前 station_id:", current_station_id)

func _on_layout_data_received(data) -> void:
	# 兼容字符串布局与已解析结构
	if typeof(data) == TYPE_STRING:
		load_layoutdata(data)
		return

	if typeof(data) == TYPE_DICTIONARY and data.has("layout"):
		load_layoutdata(str(data["layout"]))
		return

	if typeof(data) == TYPE_ARRAY:
		_rebuild_layout_from_items(data)

func _on_layout_saved(data) -> void:
	print("保存成功:", data)

func _on_api_request_failed(message: String, response_code: int) -> void:
	push_error("API 请求失败: %s (%d)" % [message, response_code])

func _rebuild_layout_from_items(data: Array) -> void:
	for child in get_children():
		if child is MeshInstance3D and not child.is_in_group("preview"):
			child.queue_free()

	for item in data:
		var path = item["scene_path"]
		if ResourceLoader.exists(path):
			var scene = load(path) as PackedScene
			if scene:
				var new_instance = scene.instantiate()
				add_child(new_instance)

				var b = item["basis"]
				var basis_matirix = Basis(
					Vector3(b["x"]["x"], b["x"]["y"], b["x"]["z"]),
					Vector3(b["y"]["x"], b["y"]["y"], b["y"]["z"]),
					Vector3(b["z"]["x"], b["z"]["y"], b["z"]["z"])
				)

				var p = item["position"]
				var pos = Vector3(p["x"], p["y"], p["z"])
				new_instance.transform = Transform3D(basis_matirix, pos)

# 这是一个辅助函数，演示如何从 JSON 字符串恢复数据
# 实际使用时，你是从服务器获取这个字符串，然后调用这个函数
func load_layoutdata(json_string: String):
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("JSON 解析失败")
		return
		
	var data = json.data # 这就是 layout_data_array
	
	for child in get_children():
		if child is MeshInstance3D and not child.is_in_group("preview"):
			child.queue_free()
	
	# 3. 重建物体
	for item in data:
		var path = item["scene_path"]
		if ResourceLoader.exists(path):
			var scene = load(path) as PackedScene
			if scene:
				var new_instance = scene.instantiate()
				add_child(new_instance)
				
				# 重建 Transform3D
				# 先还原 Basis (旋转+缩放)
				var b = item["basis"]
				var basis_matirix = Basis(
					Vector3(b["x"]["x"], b["x"]["y"], b["x"]["z"]),
					Vector3(b["y"]["x"], b["y"]["y"], b["y"]["z"]),
					Vector3(b["z"]["x"], b["z"]["y"], b["z"]["z"])
				)
				# 再还原位置
				var p = item["position"]
				var pos = Vector3(p["x"], p["y"], p["z"])
				
				# 应用变换
				new_instance.transform = Transform3D(basis_matirix, pos)
