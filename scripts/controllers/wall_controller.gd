extends StaticBody3D

const DEFAULT_WALL_HEIGHT := 2.5
const AIR_WALL_COLOR := Color(0.55, 0.78, 0.95, 0.22)

@onready var wall_mesh: MeshInstance3D = $wall
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	refresh_diagonal_fit()

func finalize_serialized_state() -> void:
	refresh_diagonal_fit()

func rotate_placement(step_degrees: float) -> void:
	rotate_y(deg_to_rad(step_degrees))
	refresh_diagonal_fit()

func refresh_diagonal_fit() -> void:
	_apply_logical_length_scale()
	_apply_air_wall_visuals()
	DiagonalBuildingFit.apply(wall_mesh, collision_shape, global_transform.basis)

func _apply_logical_length_scale() -> void:
	var logical_length_scale := float(get_meta("logical_length_scale", 1.0))
	var is_air_wall := bool(get_meta("air_wall", false))
	var target_height := DEFAULT_WALL_HEIGHT
	var mesh_y_offset := 0.0
	if is_air_wall:
		target_height = maxf(float(get_meta("air_wall_height", StoryLevels.MEZZANINE_WALL_HEIGHT)), 0.01)
	else:
		var floor_thickness_extension := maxf(float(get_meta("floor_thickness_extension", 0.0)), 0.0)
		target_height = DEFAULT_WALL_HEIGHT + floor_thickness_extension
		mesh_y_offset = -floor_thickness_extension * 0.5
	var height_scale := target_height / DEFAULT_WALL_HEIGHT
	var base_scale := Vector3(logical_length_scale, height_scale, 1.0)
	wall_mesh.set_meta("diagonal_fit_base_scale", base_scale)
	collision_shape.set_meta("diagonal_fit_base_scale", base_scale)
	wall_mesh.position.y = mesh_y_offset
	collision_shape.position.y = mesh_y_offset

func _apply_air_wall_visuals() -> void:
	if not bool(get_meta("air_wall", false)):
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = AIR_WALL_COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wall_mesh.material_override = material