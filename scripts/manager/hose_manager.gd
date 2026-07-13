extends Node3D

@export var hose_section_scene: PackedScene
@export var section_length: float = 0.016

# ================= 内部状态变量 =================
var ghost_instance: Node3D = null            # 当前正在拖拽的 Ghost
var is_dragging: bool = false                # 是否处于拖拽状态
var start_dummy: Node3D = null               # 记录起点 Dummy

# ================= UI 触发入口 =================
# 当点击 UI 上的软管创建按钮时，调用此函数
func start_building_hose(start_point: Node3D):
    if is_dragging: return # 防止重复点击
    
    start_dummy = start_point
    # 直接复用单截软管场景作为指示器
    ghost_instance = hose_section_scene.instantiate() 
    add_child(ghost_instance)
    
    # 【关键】关闭 Ghost 的物理碰撞，防止干扰射线检测
    ghost_instance.collision_layer = 0
    ghost_instance.collision_mask = 0
    
    # 【新增】设置 Ghost 为半透明效果
    _set_ghost_transparency(0.5) 
    
    is_dragging = true

# ================= 核心输入与拖拽逻辑 =================
func _unhandled_input(event):
    if not is_dragging: return
    
    # 1. 鼠标移动：让指示器跟随鼠标在 3D 空间中移动
    if event is InputEventMouseMotion:
        var camera = get_viewport().get_camera_3d()
        if camera:
            var ray_origin = camera.project_ray_origin(event.position)
            var ray_dir = camera.project_ray_normal(event.position)
            ghost_instance.global_position = ray_origin + ray_dir * 5.0

    # 2. 鼠标左键点击：确认放置
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var target_dummy = _get_target_rack_dummy(event.position)
        
        if target_dummy and target_dummy != start_dummy:
            _spawn_hose(start_dummy, target_dummy)
        
        # 无论是否成功放置，都结束拖拽状态
        _cancel_dragging()

# ================= 射线检测目标 Rack =================
func _get_target_rack_dummy(mouse_pos: Vector2) -> Node3D:
    var camera = get_viewport().get_camera_3d()
    if not camera: return null
    
    var space_state = get_world_3d().direct_space_state
    var ray_origin = camera.project_ray_origin(mouse_pos)
    var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 100.0
    
    var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
    var result = space_state.intersect_ray(query)
    
    if result and result.collider:
        var hit_node = result.collider
        if hit_node.name.to_lower().contains("dummy"):
            return hit_node
        elif hit_node.has_node("dummy"):
            return hit_node.get_node("dummy")
            
    return null

# ================= 生成软管并连接 =================
func _spawn_hose(from_dummy: Node3D, to_dummy: Node3D):
    var previous_node = from_dummy
    
    # 【核心】根据两点间的实际距离，动态计算需要的节数
    var distance = from_dummy.global_position.distance_to(to_dummy.global_position)
    var actual_segment_count = max(1, int(distance / section_length))
    
    for i in range(actual_segment_count):
        var section = hose_section_scene.instantiate()
        add_child(section)
        
        # 计算每截软管的初始位置（在起点和终点之间线性插值）
        var t = float(i + 1) / (actual_segment_count + 1)
        section.global_position = from_dummy.global_position.lerp(to_dummy.global_position, t)
        
        # 创建 PinJoint3D 连接上一节和当前节
        var joint = PinJoint3D.new()
        add_child(joint)
        joint.node_a = previous_node.get_path()
        joint.node_b = section.get_path()
        joint.softness = 0.5 # 增加柔软度
        
        previous_node = section # 更新上一节
        
    # 最后，把软管的最后一截连到终点的 Dummy 上
    var final_joint = PinJoint3D.new()
    add_child(final_joint)
    final_joint.node_a = previous_node.get_path()
    final_joint.node_b = to_dummy.get_path()
    final_joint.softness = 0.5

# ================= 取消拖拽 =================
func _cancel_dragging():
    if ghost_instance:
        ghost_instance.queue_free()
        ghost_instance = null
    is_dragging = false
    start_dummy = null

# ================= 半透明处理函数 =================
func _set_ghost_transparency(alpha: float):
    # 遍历 Ghost 节点下的所有子节点
    for child in ghost_instance.get_children():
        # 找到模型节点（MeshInstance3D）
        if child is MeshInstance3D:
            # 获取当前材质（优先使用 override，否则使用表面材质）
            var mat = child.material_override
            if mat == null and child.get_surface_material_count() > 0:
                mat = child.get_surface_material(0)
            
            # 如果找到了材质，复制一份并修改透明度
            # 注意：必须使用 duplicate()，否则会把整个场景里的模型都变透明！
            if mat:
                var transparent_mat = mat.duplicate()
                transparent_mat.albedo_color = Color(1, 1, 1, alpha)
                transparent_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                child.material_override = transparent_mat
