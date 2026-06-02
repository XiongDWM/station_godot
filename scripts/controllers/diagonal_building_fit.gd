extends RefCounted

class_name DiagonalBuildingFit

const DIAGONAL_WIDTH_SCALE := 1.41421356237
const ROTATION_STEP_DEGREES := 45.0

static func apply(mesh_node: Node3D, collision_node: Node3D, reference_basis: Basis) -> void:
	var diagonal := _is_diagonal_basis(reference_basis)
	_apply_scale(mesh_node, diagonal)
	_apply_scale(collision_node, diagonal)

static func apply_to_preview(preview_node: Node3D, reference_basis: Basis) -> void:
	_apply_scale(preview_node, _is_diagonal_basis(reference_basis))

static func _is_diagonal_basis(reference_basis: Basis) -> bool:
	var yaw_degrees := fposmod(rad_to_deg(reference_basis.get_euler().y), 180.0)
	var snapped_step := int(round(yaw_degrees / ROTATION_STEP_DEGREES)) % 4
	return snapped_step == 1 or snapped_step == 3

static func _apply_scale(target: Node3D, diagonal: bool) -> void:
	if not target:
		return
	var base_scale := _get_base_scale(target)
	var target_scale := base_scale
	if diagonal:
		target_scale.x = base_scale.x * DIAGONAL_WIDTH_SCALE
	target.scale = target_scale

static func _get_base_scale(target: Node3D) -> Vector3:
	if target.has_meta("diagonal_fit_base_scale"):
		return target.get_meta("diagonal_fit_base_scale") as Vector3
	var base_scale := target.scale
	target.set_meta("diagonal_fit_base_scale", base_scale)
	return base_scale