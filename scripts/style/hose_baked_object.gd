extends Node3D

## 稳定后的软管（单网格），作为 MainScene 子节点参与 layout 序列化

@export var tube_radius: float = 0.04
@export_range(4, 24, 1) var tube_sides: int = 8

var path_points: Array = []
var albedo_color: Color = Color(0.541, 0.541, 0.541, 1.0)

func setup_from_world_points(
	points: PackedVector3Array,
	radius: float = 0.04,
	sides: int = 8,
	color: Color = Color(0.541, 0.541, 0.541, 1.0)
) -> void:
	tube_radius = radius
	tube_sides = sides
	albedo_color = color
	path_points.clear()
	for point in points:
		path_points.append({"x": point.x, "y": point.y, "z": point.z})
	_rebuild_mesh()

func get_serialized_state() -> Dictionary:
	return {
		"path_points": path_points.duplicate(true),
		"tube_radius": tube_radius,
		"tube_sides": tube_sides,
		"albedo_color": {
			"r": albedo_color.r,
			"g": albedo_color.g,
			"b": albedo_color.b,
			"a": albedo_color.a,
		},
	}

func apply_serialized_state(state: Dictionary) -> void:
	path_points = []
	var raw_points :Variant= state.get("path_points", [])
	if raw_points is Array:
		for item in raw_points:
			if item is Dictionary:
				path_points.append({
					"x": float(item.get("x", 0.0)),
					"y": float(item.get("y", 0.0)),
					"z": float(item.get("z", 0.0)),
				})
	tube_radius = float(state.get("tube_radius", tube_radius))
	tube_sides = int(state.get("tube_sides", tube_sides))
	var color_data :Variant= state.get("albedo_color", {})
	if color_data is Dictionary:
		albedo_color = Color(
			float(color_data.get("r", albedo_color.r)),
			float(color_data.get("g", albedo_color.g)),
			float(color_data.get("b", albedo_color.b)),
			float(color_data.get("a", albedo_color.a))
		)
	_rebuild_mesh()

func finalize_serialized_state() -> void:
	_rebuild_mesh()

func _rebuild_mesh() -> void:
	var existing := get_node_or_null("HoseBakedMesh")
	if existing:
		existing.queue_free()

	var points := _points_to_packed()
	if points.size() < 2:
		return

	var mesh := _build_tube_mesh(points, tube_radius, tube_sides)
	if mesh == null:
		return

	var visual := MeshInstance3D.new()
	visual.name = "HoseBakedMesh"
	visual.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo_color
	mat.metallic = 0.6
	mat.roughness = 0.8
	visual.material_override = mat
	add_child(visual)

func _points_to_packed() -> PackedVector3Array:
	var points := PackedVector3Array()
	for item in path_points:
		if item is Dictionary:
			points.append(Vector3(
				float(item.get("x", 0.0)),
				float(item.get("y", 0.0)),
				float(item.get("z", 0.0))
			))
	return points

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
