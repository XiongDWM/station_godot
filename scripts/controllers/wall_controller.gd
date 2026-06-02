extends StaticBody3D

@onready var wall_mesh: MeshInstance3D = $wall
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	refresh_diagonal_fit()

func rotate_placement(step_degrees: float) -> void:
	rotate_y(deg_to_rad(step_degrees))
	refresh_diagonal_fit()

func refresh_diagonal_fit() -> void:
	_apply_logical_length_scale()
	DiagonalBuildingFit.apply(wall_mesh, collision_shape, global_transform.basis)

func _apply_logical_length_scale() -> void:
	var logical_length_scale := float(get_meta("logical_length_scale", 1.0))
	var base_scale := Vector3(logical_length_scale, 1.0, 1.0)
	wall_mesh.set_meta("diagonal_fit_base_scale", base_scale)
	collision_shape.set_meta("diagonal_fit_base_scale", base_scale)