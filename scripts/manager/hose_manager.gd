extends Node3D

const DEFAULT_HOSE_BAKED_SCENE := preload("res://hose_baked_object.tscn")

@export var hose_section_scene: PackedScene
@export var hose_baked_scene: PackedScene
## 节中心间距 = 单节长度 × 此比例；越小越密（性能敏感，建议 0.6~0.85）
@export var section_spacing_ratio: float = 0.75
## 固定节间距（米）；>0 时覆盖 section_spacing_ratio
@export var section_length: float = 0.0
## 单节轴向长度；<=0 时从 hose 场景碰撞体自动读取
@export var mesh_length: float = 0.0
## >1 时沿轴向拉长网格，消除物理模拟后的接缝空隙
@export var length_overlap: float = 1.5
@export var ghost_visual_scale: float = 4.0

@export_group("performance")
## 单根软管最多模拟节数；超长时自动加大节间距（15 格≈15m，96 节约 16cm/节）
@export_range(16, 256, 1) var max_segments_per_hose: int = 96
## 拖拽预览最多显示节数，避免鼠标移动时卡顿
@export_range(8, 128, 1) var max_ghost_preview_segments: int = 32
## 稳定后合并为单根圆管网格，删除逐节刚体
@export var bake_single_mesh_on_freeze: bool = true
@export var baked_tube_radius: float = 0.04
@export_range(4, 24, 1) var baked_tube_sides: int = 8

@export_group("physics_sag")
## 下垂程度：0≈硬管拉直，1≈软绳；皮套/半硬塑料建议 0.1~0.25
@export_range(0.0, 1.0, 0.01) var hose_sag_amount: float = 0.08
## 抗弯刚度：0=很软，1=半刚性；越大越不容易弯成 U 形
@export_range(0.0, 1.0, 0.01) var hose_bend_stiffness: float = 0.9
## 下落/收束速度：越大越快到达平衡（与 section_mass 几乎无关；质量只影响惯性/碰撞）
@export_range(0.1, 5.0, 0.1) var hose_settle_speed: float = 2.0
## 单节质量（kg）；主要影响惯性与碰撞，不改变重力加速度
@export var section_mass: float = 0.06
## 碰撞半径放大系数，略大于可视半径可减少穿模
@export_range(1.0, 2.0, 0.05) var collision_radius_scale: float = 1.25

@export_group("settle_freeze")
## 模拟稳定后自动 freeze，停止物理计算
@export var auto_freeze_when_settled: bool = true
## 判定稳定的线速度/角速度阈值（m/s、rad/s）
@export var settle_velocity_threshold: float = 0.025
@export var settle_angular_threshold: float = 0.35
## 连续多少物理帧低于阈值后 freeze
@export var settle_stable_frames: int = 24
## freeze 后删除关节，进一步降低开销
@export var remove_joints_on_freeze: bool = true

# ================= 内部状态变量 =================
var is_build_mode: bool = false
var ghost_container: Node3D = null
var ghost_sections: Array[Node3D] = []
var is_dragging: bool = false
var start_anchor_body: PhysicsBody3D = null
var start_anchor_point: Vector3 = Vector3.ZERO
var _resolved_mesh_length: float = -1.0
var _active_hose_assemblies: Array[Dictionary] = []
var _cached_bake_material: StandardMaterial3D = null

const SOLID_COLLISION_LAYER := 1
const HOSE_COLLISION_LAYER := 1 << 10

# ================= UI 触发入口 =================
func toggle_build_mode() -> void:
	if is_build_mode:
		cancel_build_mode()
		print("退出软管建造模式")
	else:
		is_build_mode = true
		print("进入软管建造模式")

func cancel_build_mode() -> void:
	_cancel_dragging()
	is_build_mode = false

func is_active() -> bool:
	return is_build_mode

## 保存前：强制结算未稳定软管，并烘焙为可序列化节点
func prepare_for_serialize() -> void:
	_cancel_dragging()
	var pending: Array[Dictionary] = _active_hose_assemblies.duplicate()
	_active_hose_assemblies.clear()
	for assembly in pending:
		if _is_hose_assembly_alive(assembly):
			_freeze_hose_assembly(assembly)

## 加载布局前：清掉 HoseManager 下临时模拟节
func clear_all_hoses() -> void:
	_cancel_dragging()
	_active_hose_assemblies.clear()
	for child in get_children():
		child.queue_free()

func start_building_hose(anchor_body: PhysicsBody3D, anchor_point: Vector3) -> void:
	if is_dragging:
		return

	start_anchor_body = anchor_body
	start_anchor_point = anchor_point
	ghost_container = Node3D.new()
	ghost_container.name = "HoseGhostPreview"
	add_child(ghost_container)
	ghost_sections.clear()
	is_dragging = true
	_update_ghost_preview(start_anchor_point, start_anchor_point)

# ================= 核心输入与拖拽逻辑 =================
func _unhandled_input(event):
	if not is_build_mode:
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_build_mode()
		print("退出软管建造模式")
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and is_dragging and ghost_container:
		_update_ghost_follow(event.position)
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var anchor := _pick_hose_anchor(event.position)
		if not is_dragging:
			if not anchor.is_empty():
				start_building_hose(anchor["body"], anchor["point"])
		else:
			if not anchor.is_empty() and anchor["point"].distance_to(start_anchor_point) > 0.01:
				_spawn_hose(start_anchor_body, start_anchor_point, anchor["body"], anchor["point"])
			_cancel_dragging()
		get_viewport().set_input_as_handled()

func _update_ghost_follow(mouse_pos: Vector2) -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera or not ghost_container:
		return

	var hit := _raycast(mouse_pos)
	var point: Vector3
	if not hit.is_empty():
		point = hit.position
	else:
		var ray_origin := camera.project_ray_origin(mouse_pos)
		var ray_dir := camera.project_ray_normal(mouse_pos)
		point = ray_origin + ray_dir * max(1.0, start_anchor_point.distance_to(ray_origin))

	var anchor := _pick_hose_anchor(mouse_pos)
	if not anchor.is_empty():
		point = anchor["point"]
	_update_ghost_preview(start_anchor_point, point)

func _compute_hose_layout(from_point: Vector3, to_point: Vector3, segment_cap: int = 0) -> Dictionary:
	var delta := to_point - from_point
	var distance := delta.length()
	if distance < 0.001:
		return {}
	var direction := delta / distance
	var section_mesh_length := _resolve_section_mesh_length()
	var spacing := _get_section_spacing(section_mesh_length)
	var segment_count := maxi(1, int(ceil(distance / spacing)))
	if segment_cap > 0:
		segment_count = mini(segment_count, segment_cap)
	var step := distance / float(segment_count)
	var y_scale := (step / section_mesh_length) * length_overlap
	return {
		"from_point": from_point,
		"direction": direction,
		"segment_count": segment_count,
		"step": step,
		"y_scale": y_scale,
		"distance": distance,
	}

func _update_ghost_preview(from_point: Vector3, to_point: Vector3) -> void:
	if not ghost_container:
		return
	var cap := max_ghost_preview_segments if max_ghost_preview_segments > 0 else 0
	var layout := _compute_hose_layout(from_point, to_point, cap)
	if layout.is_empty():
		_clear_ghost_sections()
		return
	var direction: Vector3 = layout["direction"]
	var segment_count: int = layout["segment_count"]
	var step: float = layout["step"]
	var y_scale: float = layout["y_scale"]
	_ensure_ghost_section_count(segment_count)
	for i in range(segment_count):
		var p0 := from_point + direction * (step * float(i))
		var p1 := from_point + direction * (step * float(i + 1))
		var center := (p0 + p1) * 0.5
		_place_section_at(ghost_sections[i], center, direction, y_scale)

func _ensure_ghost_section_count(count: int) -> void:
	while ghost_sections.size() < count:
		var section_root: Node3D = hose_section_scene.instantiate()
		ghost_container.add_child(section_root)
		_configure_ghost_section(section_root)
		ghost_sections.append(section_root)
	while ghost_sections.size() > count:
		var extra: Node3D = ghost_sections.pop_back() as Node3D
		if is_instance_valid(extra):
			extra.queue_free()

func _configure_ghost_section(section_root: Node3D) -> void:
	var body := _get_section_body(section_root)
	if body:
		body.freeze = true
		if body is RigidBody3D:
			(body as RigidBody3D).gravity_scale = 0.0
		body.collision_layer = 0
		body.collision_mask = 0
		_hide_ghost_connect_parts(section_root)
	_set_ghost_transparency_recursive(section_root, 0.45)

func _hide_ghost_connect_parts(section_root: Node3D) -> void:
	var body := _get_section_body(section_root)
	if not body:
		return
	for child in body.get_children():
		if child is MeshInstance3D and child.name != "mid_part":
			(child as MeshInstance3D).visible = false

func _clear_ghost_sections() -> void:
	for section in ghost_sections:
		if is_instance_valid(section):
			section.queue_free()
	ghost_sections.clear()

# ================= 锚点拾取：任意物理体，优先 Dummy 出入点 =================
func _pick_hose_anchor(mouse_pos: Vector2) -> Dictionary:
	var result := _raycast(mouse_pos)
	if result.is_empty() or not result.collider:
		return {}

	var body := _find_physics_body(result.collider)
	if body == null:
		return {}

	var dummy := _find_nearest_dummy(body, result.position)
	var point: Vector3 = dummy.global_position if dummy else result.position
	return {"body": body, "point": point}

func _raycast(mouse_pos: Vector2) -> Dictionary:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return {}
	var space_state = get_world_3d().direct_space_state
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 200.0
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space_state.intersect_ray(query)

func _find_physics_body(node: Node) -> PhysicsBody3D:
	var current := node
	while current:
		if current is PhysicsBody3D:
			return current as PhysicsBody3D
		current = current.get_parent()
	return null

func _find_nearest_dummy(root: Node, hit_point: Vector3) -> Node3D:
	var dummies: Array[Node3D] = []
	_collect_dummies(root, dummies)
	if dummies.is_empty():
		return null

	var nearest: Node3D = null
	var nearest_dist := INF
	for dummy in dummies:
		var dist := dummy.global_position.distance_squared_to(hit_point)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = dummy
	return nearest

func _collect_dummies(node: Node, out: Array[Node3D]) -> void:
	if node is Node3D and String(node.name).to_lower().contains("dummy"):
		out.append(node as Node3D)
	for child in node.get_children():
		_collect_dummies(child, out)

func _get_section_body(section_root: Node) -> PhysicsBody3D:
	if section_root is PhysicsBody3D:
		return section_root as PhysicsBody3D
	var named := section_root.get_node_or_null("hose_section")
	if named is PhysicsBody3D:
		return named as PhysicsBody3D
	for child in section_root.get_children():
		if child is PhysicsBody3D:
			return child as PhysicsBody3D
	return null

func _resolve_section_mesh_length() -> float:
	if _resolved_mesh_length > 0.0:
		return _resolved_mesh_length
	if mesh_length > 0.0:
		_resolved_mesh_length = mesh_length
		return _resolved_mesh_length
	if not hose_section_scene:
		_resolved_mesh_length = 0.016
		return _resolved_mesh_length
	var sample := hose_section_scene.instantiate()
	var body := _get_section_body(sample)
	if body:
		for child in body.get_children():
			if child is CollisionShape3D:
				var shape := (child as CollisionShape3D).shape
				if shape is CylinderShape3D:
					_resolved_mesh_length = maxf((shape as CylinderShape3D).height, 0.001)
					sample.queue_free()
					return _resolved_mesh_length
		var combined := AABB()
		var has_bounds := false
		for child in body.get_children():
			if child is MeshInstance3D and (child as MeshInstance3D).mesh:
				var local_aabb := (child as MeshInstance3D).get_aabb()
				var merged := local_aabb
				if has_bounds:
					combined = combined.merge(merged)
				else:
					combined = merged
					has_bounds = true
		if has_bounds:
			_resolved_mesh_length = maxf(combined.size.y, 0.001)
			sample.queue_free()
			return _resolved_mesh_length
	sample.queue_free()
	_resolved_mesh_length = 0.016
	return _resolved_mesh_length

func _get_section_spacing(section_mesh_length: float) -> float:
	if section_length > 0.0:
		return maxf(0.002, section_length)
	return maxf(0.002, section_mesh_length * clampf(section_spacing_ratio, 0.2, 0.95))

func _basis_y_aligned(direction: Vector3) -> Basis:
	var y_axis := direction.normalized()
	var x_axis := y_axis.cross(Vector3.UP)
	if x_axis.length_squared() < 0.001:
		x_axis = y_axis.cross(Vector3.RIGHT)
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)

func _place_section_at(section_root: Node3D, center: Vector3, direction: Vector3, y_scale: float = 1.0) -> void:
	var body := _get_section_body(section_root)
	var basis := _basis_y_aligned(direction)
	# 非均匀缩放烘焙进 basis，保证可视长度盖住节间距
	basis = Basis(basis.x, basis.y * y_scale, basis.z)
	var xform := Transform3D(basis, center)
	if body:
		body.global_transform = xform
	else:
		section_root.global_transform = xform

# ================= 生成软管并连接 =================
func _spawn_hose(from_body: PhysicsBody3D, from_point: Vector3, to_body: PhysicsBody3D, to_point: Vector3) -> void:
	var cap := max_segments_per_hose if max_segments_per_hose > 0 else 0
	var layout := _compute_hose_layout(from_point, to_point, cap)
	if layout.is_empty():
		return

	var hose_root := Node3D.new()
	hose_root.name = "Hose"
	add_child(hose_root)

	var direction: Vector3 = layout["direction"]
	var segment_count: int = layout["segment_count"]
	var step: float = layout["step"]
	var y_scale: float = layout["y_scale"]
	var previous_body: PhysicsBody3D = from_body
	var section_bodies: Array[PhysicsBody3D] = []
	var joints: Array[Joint3D] = []

	for i in range(segment_count):
		var p0 := from_point + direction * (step * float(i))
		var p1 := from_point + direction * (step * float(i + 1))
		var center := (p0 + p1) * 0.5

		var section_root: Node3D = hose_section_scene.instantiate()
		hose_root.add_child(section_root)
		var section_body := _get_section_body(section_root)
		if section_body == null:
			section_root.queue_free()
			continue

		_configure_section_body(section_body)
		_place_section_at(section_root, center, direction, y_scale)
		section_body.freeze = false
		section_bodies.append(section_body)

		joints.append(_create_hose_joint(hose_root, previous_body, section_body, p0))
		previous_body = section_body

	joints.append(_create_hose_joint(hose_root, previous_body, to_body, to_point))
	_apply_hose_collision_exceptions(section_bodies)

	if auto_freeze_when_settled and not section_bodies.is_empty():
		_active_hose_assemblies.append({
			"root": hose_root,
			"sections": section_bodies,
			"joints": joints,
			"stable_frames": 0,
		})

func _apply_hose_collision_exceptions(section_bodies: Array[PhysicsBody3D]) -> void:
	# 仅相邻节之间互斥，避免关节处抖动；不与锚点机柜互斥，否则整根软管会穿过机柜
	for i in range(1, section_bodies.size()):
		_add_collision_exception_pair(section_bodies[i], section_bodies[i - 1])

func _add_collision_exception_pair(body_a: PhysicsBody3D, body_b: PhysicsBody3D) -> void:
	if not body_a or not body_b or body_a == body_b:
		return
	body_a.add_collision_exception_with(body_b)
	body_b.add_collision_exception_with(body_a)

func _create_hose_joint(parent: Node, body_a: PhysicsBody3D, body_b: PhysicsBody3D, joint_position: Vector3) -> Joint3D:
	var joint: Joint3D
	if hose_bend_stiffness >= 0.995:
		joint = PinJoint3D.new()
	else:
		var cone := ConeTwistJoint3D.new()
		var swing_deg := lerpf(42.0, 4.0, hose_bend_stiffness)
		var twist_deg := lerpf(24.0, 4.0, hose_bend_stiffness)
		cone.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(swing_deg))
		cone.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(twist_deg))
		cone.set_param(ConeTwistJoint3D.PARAM_BIAS, lerpf(0.82, 0.97, hose_bend_stiffness))
		cone.set_param(ConeTwistJoint3D.PARAM_RELAXATION, lerpf(8.0, 18.0, hose_bend_stiffness) * hose_settle_speed)
		cone.set_param(ConeTwistJoint3D.PARAM_SOFTNESS, lerpf(0.6, 0.08, hose_bend_stiffness))
		joint = cone
	parent.add_child(joint)
	joint.global_position = joint_position
	joint.node_a = body_a.get_path()
	joint.node_b = body_b.get_path()
	if joint is PinJoint3D:
		_configure_pin_joint(joint as PinJoint3D)
	return joint

func _physics_process(_delta: float) -> void:
	if not auto_freeze_when_settled or _active_hose_assemblies.is_empty():
		return

	var next_assemblies: Array[Dictionary] = []
	for assembly in _active_hose_assemblies:
		if not _is_hose_assembly_alive(assembly):
			continue
		if _is_hose_assembly_settled(assembly):
			assembly["stable_frames"] = int(assembly.get("stable_frames", 0)) + 1
			if assembly["stable_frames"] >= settle_stable_frames:
				_freeze_hose_assembly(assembly)
				continue
		else:
			assembly["stable_frames"] = 0
		next_assemblies.append(assembly)
	_active_hose_assemblies = next_assemblies

func _is_hose_assembly_alive(assembly: Dictionary) -> bool:
	var root: Node = assembly.get("root")
	return is_instance_valid(root)

func _is_hose_assembly_settled(assembly: Dictionary) -> bool:
	var vel_threshold_sq := settle_velocity_threshold * settle_velocity_threshold
	var simulating := 0
	for section in assembly.get("sections", []):
		if not is_instance_valid(section) or not section is RigidBody3D:
			continue
		var rigid := section as RigidBody3D
		if rigid.freeze:
			continue
		simulating += 1
		if rigid.linear_velocity.length_squared() > vel_threshold_sq:
			return false
		if rigid.angular_velocity.length() > settle_angular_threshold:
			return false
	return simulating == 0

func _freeze_hose_assembly(assembly: Dictionary) -> void:
	if remove_joints_on_freeze:
		for joint in assembly.get("joints", []):
			if is_instance_valid(joint):
				joint.queue_free()

	var sections: Array = assembly.get("sections", [])
	if bake_single_mesh_on_freeze and sections.size() >= 2:
		_bake_hose_to_single_mesh(assembly)
		return

	for section in sections:
		if not is_instance_valid(section) or not section is RigidBody3D:
			continue
		var rigid := section as RigidBody3D
		rigid.linear_velocity = Vector3.ZERO
		rigid.angular_velocity = Vector3.ZERO
		rigid.freeze = true
		rigid.sleeping = true

func _bake_hose_to_single_mesh(assembly: Dictionary) -> void:
	var hose_root: Node3D = assembly.get("root")
	if not is_instance_valid(hose_root):
		return

	var points := _collect_hose_path_points(assembly.get("sections", []))
	if points.size() < 2:
		hose_root.queue_free()
		return

	var scene_root := get_parent()
	var baked_scene := hose_baked_scene if hose_baked_scene else DEFAULT_HOSE_BAKED_SCENE
	var baked: Node3D = null
	if baked_scene:
		baked = baked_scene.instantiate() as Node3D
	if baked == null:
		# 兜底：仍挂在临时 root 下（不会进 layout）
		var mesh := _build_tube_mesh(points, baked_tube_radius, baked_tube_sides)
		if mesh == null:
			hose_root.queue_free()
			return
		for child in hose_root.get_children():
			child.queue_free()
		var visual := MeshInstance3D.new()
		visual.name = "HoseBakedMesh"
		visual.mesh = mesh
		visual.material_override = _get_bake_material()
		hose_root.add_child(visual)
		return

	if scene_root:
		scene_root.add_child(baked)
	else:
		add_child(baked)

	var mat := _get_bake_material()
	var color := Color(0.541, 0.541, 0.541, 1.0)
	if mat:
		color = mat.albedo_color
	if baked.has_method("setup_from_world_points"):
		baked.call("setup_from_world_points", points, baked_tube_radius, baked_tube_sides, color)
	baked.set_meta("build_view_layer", 0)
	hose_root.queue_free()

func _collect_hose_path_points(sections: Array) -> PackedVector3Array:
	var points := PackedVector3Array()
	for section in sections:
		if is_instance_valid(section) and section is Node3D:
			points.append((section as Node3D).global_position)
	return points

func _get_bake_material() -> StandardMaterial3D:
	if _cached_bake_material:
		return _cached_bake_material
	_cached_bake_material = StandardMaterial3D.new()
	_cached_bake_material.albedo_color = Color(0.541, 0.541, 0.541)
	_cached_bake_material.metallic = 0.6
	_cached_bake_material.roughness = 0.8
	if hose_section_scene:
		var sample := hose_section_scene.instantiate()
		var body := _get_section_body(sample)
		if body:
			var mid := body.get_node_or_null("mid_part") as MeshInstance3D
			if mid and mid.mesh and mid.mesh.get_surface_count() > 0:
				var src := mid.mesh.surface_get_material(0)
				if src is StandardMaterial3D:
					_cached_bake_material = (src as StandardMaterial3D).duplicate()
		sample.queue_free()
	return _cached_bake_material

func _build_tube_mesh(path: PackedVector3Array, radius: float, sides: int) -> ArrayMesh:
	if path.size() < 2 or sides < 3 or radius <= 0.0:
		return null

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var ring_count := path.size()
	var rings: Array[PackedVector3Array] = []
	rings.resize(ring_count)

	for i in ring_count:
		var tangent := _get_path_tangent(path, i)
		var frame := _build_ring_frame(tangent)
		var binormal: Vector3 = frame[0]
		var normal: Vector3 = frame[1]
		var ring := PackedVector3Array()
		ring.resize(sides)
		for s in sides:
			var angle := TAU * float(s) / float(sides)
			var offset := binormal * cos(angle) * radius + normal * sin(angle) * radius
			ring[s] = path[i] + offset
		rings[i] = ring

	for i in ring_count - 1:
		var r0: PackedVector3Array = rings[i]
		var r1: PackedVector3Array = rings[i + 1]
		for s in sides:
			var sn := (s + 1) % sides
			_add_tube_quad(st, r0[s], r1[s], r1[sn], r0[sn])

	_add_tube_cap(st, rings[0], path[0], -_get_path_tangent(path, 0))
	_add_tube_cap(st, rings[ring_count - 1], path[ring_count - 1], _get_path_tangent(path, ring_count - 1))

	st.generate_normals()
	return st.commit()

func _get_path_tangent(path: PackedVector3Array, index: int) -> Vector3:
	if path.size() < 2:
		return Vector3.UP
	if index <= 0:
		return (path[1] - path[0]).normalized()
	if index >= path.size() - 1:
		return (path[index] - path[index - 1]).normalized()
	return (path[index + 1] - path[index - 1]).normalized()

func _build_ring_frame(tangent: Vector3) -> Array:
	var up_hint := Vector3.UP
	if absf(tangent.dot(up_hint)) > 0.95:
		up_hint = Vector3.RIGHT
	var binormal := tangent.cross(up_hint).normalized()
	var normal := binormal.cross(tangent).normalized()
	return [binormal, normal]

func _add_tube_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)

func _add_tube_cap(st: SurfaceTool, ring: PackedVector3Array, center: Vector3, outward: Vector3) -> void:
	if ring.is_empty():
		return
	var normal := outward.normalized()
	for i in ring.size():
		var j := (i + 1) % ring.size()
		st.set_normal(normal)
		st.add_vertex(center)
		st.set_normal(normal)
		st.add_vertex(ring[i])
		st.set_normal(normal)
		st.add_vertex(ring[j])

func _get_hose_gravity_scale() -> float:
	return hose_sag_amount * 0.18

func _get_hose_damp_scale() -> float:
	return 1.0 / maxf(hose_settle_speed, 0.01)

func _configure_section_body(body: PhysicsBody3D) -> void:
	body.freeze = true
	# 与场景里 layer 1 的静态体（地面、机柜、墙等）发生碰撞
	body.collision_layer = SOLID_COLLISION_LAYER
	body.collision_mask = SOLID_COLLISION_LAYER
	_inflate_section_collision(body)
	if body is RigidBody3D:
		var rigid := body as RigidBody3D
		var damp_scale := _get_hose_damp_scale()
		rigid.gravity_scale = _get_hose_gravity_scale()
		rigid.linear_damp = lerpf(2.5, 6.5, hose_bend_stiffness) * damp_scale
		rigid.angular_damp = lerpf(3.0, 8.0, hose_bend_stiffness) * damp_scale
		rigid.mass = section_mass
		rigid.continuous_cd = true
		rigid.max_contacts_reported = 8
		rigid.contact_monitor = false

func _inflate_section_collision(body: PhysicsBody3D) -> void:
	if collision_radius_scale <= 1.0:
		return
	for child in body.get_children():
		if child is CollisionShape3D:
			var col := child as CollisionShape3D
			if col.shape is CylinderShape3D:
				var cyl := (col.shape as CylinderShape3D).duplicate()
				cyl.radius *= collision_radius_scale
				col.shape = cyl

func _configure_pin_joint(joint: PinJoint3D) -> void:
	var damp_scale := _get_hose_damp_scale()
	joint.set_param(PinJoint3D.PARAM_BIAS, lerpf(0.88, 0.98, hose_bend_stiffness))
	joint.set_param(PinJoint3D.PARAM_DAMPING, lerpf(1.5, 3.5, hose_bend_stiffness) * damp_scale)

# ================= 取消拖拽 =================
func _cancel_dragging() -> void:
	_clear_ghost_sections()
	if ghost_container:
		ghost_container.queue_free()
		ghost_container = null
	is_dragging = false
	start_anchor_body = null
	start_anchor_point = Vector3.ZERO

# ================= 半透明处理函数 =================
func _set_ghost_transparency_recursive(node: Node, alpha: float) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var mat = mesh_node.material_override
		if mat == null and mesh_node.get_surface_override_material_count() > 0:
			mat = mesh_node.get_surface_override_material(0)
		if mat == null and mesh_node.mesh and mesh_node.mesh.get_surface_count() > 0:
			mat = mesh_node.mesh.surface_get_material(0)
		if mat:
			var transparent_mat = mat.duplicate()
			transparent_mat.albedo_color = Color(0.3, 0.85, 1.0, alpha)
			transparent_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh_node.material_override = transparent_mat
	for child in node.get_children():
		_set_ghost_transparency_recursive(child, alpha)
