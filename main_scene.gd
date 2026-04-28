extends Node3D

@export var preview_cube: MeshInstance3D
@export var grid_map: GridMap
@export var button_cube: Button
@export var block_scene:PackedScene=preload("res://odf_object.tscn")

var is_building_mode = false # 当前是否处于“建造模式”


func _ready():
	if button_cube:
		button_cube.pressed.connect(_on_button_pressed)
	
	# 初始化预览方块
	if preview_cube:
		preview_cube.visible = false

func _on_button_pressed():
	# 切换模式
	is_building_mode = !is_building_mode
	update_ui()

func update_ui():
	# 统一更新界面状态
	if is_building_mode:
		print("进入建造模式")
		if preview_cube:
			preview_cube.visible = true # 进入模式时显示预览
	else:
		print("退出建造模式")
		if preview_cube:
			preview_cube.visible = false

func _unhandled_input(event):
	# 监听键盘按下事件
	if event is InputEventKey and event.pressed:
		# 如果按下了 Esc 键
		if event.keycode == Key.KEY_ESCAPE:
			if is_building_mode:
				is_building_mode = false
				update_ui()
				# 告诉系统这个事件我已经处理过了，不需要再传递给其他控件
				get_viewport().set_input_as_handled()

func _process(delta):
	# 如果没在建造模式，直接返回
	if not is_building_mode:
		return
		
	# 1. 安全检查
	if not preview_cube or not grid_map:
		return

	var camera = $Camera3D 
	if not camera:
		return

	var mouse_pos = get_viewport().get_mouse_position()
	
	# 2. 发射射线
	var space_state = get_world_3d().direct_space_state
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 100.0
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_pos = result.position
		
		# --- 3. 修正后的转换逻辑 ---
		
		# A. 获取 GridMap 的单元格大小 (直接从 grid_map 获取)
		var cell_size = grid_map.cell_size 
		
		# B. 将世界坐标转换为 GridMap 的局部坐标
		var local_pos = grid_map.to_local(hit_pos)
		var map_pos=grid_map.local_to_map(local_pos)
		var cell_center_world=grid_map.map_to_local(map_pos)
		
		# 预览方块尺寸
		var preview_cube_size=preview_cube.mesh.get_aabb().size
		var size_after_scale= preview_cube_size*preview_cube.global_transform.basis.get_scale()
		var y_offset=size_after_scale.y/2
		
		
		
		# C. 手动计算网格坐标 (除以格子大小并向下取整)
		var map_coord = Vector3i(
			floor(local_pos.x / (cell_size.x)),
			floor(local_pos.y / cell_size.y),
			floor(local_pos.z / cell_size.z)
		)
		
		# --- 4. 转回世界坐标并更新预览 ---
		var final_pos = grid_map.map_to_local(map_coord)
		var final_y= hit_pos.y+y_offset
		final_pos.y=final_y
		
		
		preview_cube.global_position = final_pos
		preview_cube.visible = true
	else:
		preview_cube.visible = false
		
func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_building_mode:
			place_block()

func place_block():
	# 1. 安全检查：确保有预览方块，且资源加载了
	if not preview_cube or not block_scene:
		return

	# 2. 实例话子场景
	var new_block = block_scene.instantiate()
	
	# 3. 设置位置：直接使用预览方块当前的坐标
	new_block.global_transform.origin = preview_cube.global_position
	
	# 4. 加入场景树：让它显示出来并生效
	add_child(new_block)
	
	print("方块已放置！")
