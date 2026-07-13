extends RefCounted

class_name DiagonalBuildingFit

const ROTATION_STEP_DEGREES := 45.0
const DEFAULT_MESH_UNIT_LENGTH := 1.0

static func apply(mesh_node: Node3D, collision_node: Node3D, reference_basis: Basis) -> void:
	var diagonal := is_diagonal_basis(reference_basis)
	_apply_scale(mesh_node, diagonal)
	_apply_scale(collision_node, diagonal)

static func apply_to_preview(preview_node: Node3D, reference_basis: Basis) -> void:
	_apply_scale(preview_node, is_diagonal_basis(reference_basis))

static func is_diagonal_basis(reference_basis: Basis) -> bool:
	return is_diagonal_yaw_degrees(get_basis_yaw_degrees(reference_basis))

static func is_diagonal_yaw_degrees(yaw_degrees: float) -> bool:
	var normalized := fposmod(yaw_degrees, 180.0)
	var snapped_step := int(round(normalized / ROTATION_STEP_DEGREES)) % 4
	return snapped_step == 1 or snapped_step == 3

static func get_basis_yaw_degrees(reference_basis: Basis) -> float:
	var forward := Vector3(-reference_basis.z.x, 0.0, -reference_basis.z.z)
	if forward.length_squared() < 0.0001:
		forward = Vector3(reference_basis.x.x, 0.0, reference_basis.x.z)
	if forward.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg(atan2(forward.x, forward.z))

static func get_axis_length(cell_size: Vector2) -> float:
	return maxf(cell_size.x, cell_size.y)

static func get_diagonal_length(cell_size: Vector2) -> float:
	return cell_size.length()

static func _apply_scale(target: Node3D, diagonal: bool) -> void:
	if not target:
		return
	var base_scale := _get_base_scale(target)
	var target_scale := base_scale
	var cell_size := _resolve_cell_size(target)
	var mesh_unit := _resolve_mesh_unit_length(target)
	if cell_size != Vector2.ZERO and mesh_unit > 0.001:
		var world_length := get_diagonal_length(cell_size) if diagonal else get_axis_length(cell_size)
		target_scale.x = world_length / mesh_unit
	else:
		target_scale.x = base_scale.x
	target.scale = target_scale

static func _resolve_cell_size(target: Node3D) -> Vector2:
	if target.has_meta("diagonal_fit_cell_size"):
		return target.get_meta("diagonal_fit_cell_size") as Vector2
	var parent := target.get_parent()
	if parent is Node and parent.has_meta("diagonal_fit_cell_size"):
		return parent.get_meta("diagonal_fit_cell_size") as Vector2
	return Vector2.ZERO

static func _resolve_mesh_unit_length(target: Node3D) -> float:
	if target.has_meta("diagonal_fit_mesh_unit_length"):
		return maxf(float(target.get_meta("diagonal_fit_mesh_unit_length")), 0.001)
	if target is MeshInstance3D and target.mesh:
		return maxf(target.mesh.get_aabb().size.x, 0.001)
	return DEFAULT_MESH_UNIT_LENGTH

static func _get_base_scale(target: Node3D) -> Vector3:
	if target.has_meta("diagonal_fit_base_scale"):
		return target.get_meta("diagonal_fit_base_scale") as Vector3
	return Vector3.ONE
