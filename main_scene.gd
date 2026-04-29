extends Node3D

@export var preview_cube: MeshInstance3D
@export var grid_map: GridMap
@export var button_cube: Button
@export var preview_wall:MeshInstance3D
@export var button_wall:Button
@export var block_scene:PackedScene=preload("res://odf_object.tscn")
@export var wall_scene:PackedScene=preload("res://wall_object.tscn")
@export var floor_brick:PackedScene=preload("res://floor_brick.tscn")

var is_building_facility_mode = false # 是否处于建造设备模式
var is_building_env_mode = false # 是否处于建造墙体模式


func _ready():
	if button_cube: button_cube.pressed.connect(_on_button_pressed)
	
	# 初始化预览方块
	if preview_cube: preview_cube.visible = false
	if preview_wall: preview_wall.visible = false
func _on_button_pressed():
	# 切换模式
	is_building_facility_mode = !is_building_facility_mode
	update_ui()

func update_ui():
	if is_building_facility_mode:
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
			if is_building_facility_mode:
				is_building_facility_mode = false
				update_ui()
				# 告诉系统这个事件我已经处理过了，不需要再传递给其他控件
				get_viewport().set_input_as_handled()

func _process(delta):
	# 如果没在建造模式，直接返回
	if not is_building_facility_mode:
		return
		
	# 安全检查
	if not preview_cube or not grid_map:
		return

	var camera = $Camera3D 
	if not camera:
		return

	var mouse_pos = get_viewport().get_mouse_position()
	
	# 发射射线
	var space_state = get_world_3d().direct_space_state
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 100.0
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		# grid_map单元格大小, 不是grid_map单元格上方块的大小，是设置map的单元格大小
		var cell_size = grid_map.cell_size
		# 射线打到方块的位置的方法
		var hit_pos = result.position
		# 将世界坐标转换为 GridMap 的局部坐标
		var local_pos = grid_map.to_local(hit_pos)
		var map_pos=grid_map.local_to_map(local_pos)
		var cell_center_world=grid_map.map_to_local(map_pos)
		
		# 预览方块尺寸
		var preview_cube_size=preview_cube.mesh.get_aabb().size
		# 乘以一个缩放比例，因为可能是transform搞得缩放
		var size_after_scale= preview_cube_size*preview_cube.global_transform.basis.get_scale()
		var y_offset=size_after_scale.y/2
		
		# 手动计算网格坐标 (除以格子大小并向下取整)
		var map_coord = Vector3i(
			floor(local_pos.x / (cell_size.x)),
			floor(local_pos.y / cell_size.y),
			floor(local_pos.z / cell_size.z)
		)
		var final_pos = grid_map.map_to_local(map_coord)
		# 计算预览方块偏移后中心的高度，结果是一定在地板表面上，然后重新set进去
		var final_y= hit_pos.y+y_offset
		final_pos.y=final_y
		
		preview_cube.global_position = final_pos
		preview_cube.visible = true
	else:
		preview_cube.visible = false
		
func _input(event):
	# 需要添加校验，因为点击其他空白位置会直接投射到gridmap的方块上建一个方块
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_building_facility_mode: return
		place_block()

func place_block():
	if  !preview_cube or !block_scene:return
	if !is_inside_tree(): return
	# 实例化场景 然后加入场景树 
	var new_block = block_scene.instantiate()
	add_child(new_block)	
	# 直接使用预览方块当前的坐标做为实例位置
	new_block.global_transform.origin = preview_cube.global_position
	print("放置")
	
# 同上 放置墙的方法，能不能抽象出来呢
func place_wall():
	if  !preview_wall or !wall_scene:return
	if !is_inside_tree(): return 
	var new_wall = wall_scene.instantiate()
	add_child(new_wall)	
	new_wall.global_transform.origin = preview_wall.global_position
