extends Node3D

# 导出你的各种资源
@export var grid_map: GridMap
@export var button_cube: Button
@export var button_wall: Button

@export var preview_cube: MeshInstance3D
@export var preview_wall: MeshInstance3D

@export var block_scene: PackedScene
@export var wall_scene: PackedScene
@export var floor_brick: PackedScene

# 核心改动：用一个字典来记录当前选中的建筑信息
var current_building = {
	"scene": null,          # 当前要生成的场景
	"preview": null,        # 当前显示的预览方块
	"is_active": false      # 是否处于建造模式
}

func _ready():
	# 初始化时默认隐藏所有预览
	if preview_cube: preview_cube.visible = false
	if preview_wall: preview_wall.visible = false

	# 统一连接按钮信号，并传入不同的参数来区分模式
	if button_cube: 
		button_cube.pressed.connect(_on_building_mode_selected.bind(block_scene, preview_cube))
	if button_wall: 
		button_wall.pressed.connect(_on_building_mode_selected.bind(wall_scene, preview_wall))

# 处理按钮点击，进入指定模式
func _on_building_mode_selected(scene: PackedScene, preview: MeshInstance3D):
	# 如果点击的是当前已经在建造的模式，则视为退出
	if current_building["scene"] == scene and current_building["is_active"]:
		current_building["is_active"] = false
		print("退出建造模式")
	else:
		# 否则切换为新的模式
		current_building["scene"] = scene
		current_building["preview"] = preview
		current_building["is_active"] = true
		print("进入建造模式: ", scene.resource_path)
	
	update_ui()

func update_ui():
	# 统一控制预览方块的显示与隐藏
	if preview_cube: preview_cube.visible = (current_building["is_active"] and current_building["preview"] == preview_cube)
	if preview_wall: preview_wall.visible = (current_building["is_active"] and current_building["preview"] == preview_wall)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == Key.KEY_ESCAPE:
		if current_building["is_active"]:
			current_building["is_active"] = false
			update_ui()
			get_viewport().set_input_as_handled()

func _process(delta):
	# 如果没在建造模式，直接返回
	if not current_building["is_active"] or not current_building["preview"]:
		return
		
	if not grid_map: return

	var camera = $Camera3D 
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
		
		# 统一更新当前预览方块的位置
		preview_mesh.global_position = final_pos
		preview_mesh.visible = true
	else:
		if current_building["preview"]:
			current_building["preview"].visible = false
		
func _input(event):
	# 统一处理左键放置
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if current_building["is_active"]:
			place_current_building()

# 核心改动：抽象出来的通用放置函数
func place_current_building():
	var scene_to_spawn = current_building["scene"]
	var preview_node = current_building["preview"]

	if not scene_to_spawn or not preview_node:
		return

	var new_building = scene_to_spawn.instantiate()
	add_child(new_building)
	# 直接使用当前预览方块的位置
	new_building.global_position = preview_node.global_position
	print("放置了: ", scene_to_spawn.resource_path)
