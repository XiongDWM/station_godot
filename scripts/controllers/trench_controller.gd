extends StaticBody3D

const LEFT_WALL_NAME := "LeftWall"
const RIGHT_WALL_NAME := "RightWall"
const BOTTOM_NAME := "Bottom"
const WALL_KEEP_END_RATIO := 0.1

var left_wall_visible := true
var right_wall_visible := true
var left_wall_opened := false
var right_wall_opened := false
var bottom_min_y := -0.5
var bottom_max_y := 0.5

func _ready() -> void:
	_apply_wall_visibility()

func set_side_walls(left_visible: bool, right_visible: bool) -> void:
	left_wall_visible = left_visible
	right_wall_visible = right_visible
	left_wall_opened = not left_visible
	right_wall_opened = not right_visible
	_apply_wall_visibility()

func set_bottom_span(min_y: float, max_y: float) -> void:
	bottom_min_y = clampf(min_y, -0.5, 0.5)
	bottom_max_y = clampf(max_y, -0.5, 0.5)
	if bottom_max_y < bottom_min_y:
		var old_min := bottom_min_y
		bottom_min_y = bottom_max_y
		bottom_max_y = old_min
	_apply_wall_visibility()

func get_serialized_state() -> Dictionary:
	return {
		"left_wall_visible": left_wall_visible,
		"right_wall_visible": right_wall_visible,
		"left_wall_opened": left_wall_opened,
		"right_wall_opened": right_wall_opened,
		"bottom_min_y": bottom_min_y,
		"bottom_max_y": bottom_max_y,
	}

func apply_serialized_state(state: Dictionary) -> void:
	left_wall_visible = bool(state.get("left_wall_visible", true))
	right_wall_visible = bool(state.get("right_wall_visible", true))
	left_wall_opened = bool(state.get("left_wall_opened", not left_wall_visible))
	right_wall_opened = bool(state.get("right_wall_opened", not right_wall_visible))
	bottom_min_y = float(state.get("bottom_min_y", -0.5))
	bottom_max_y = float(state.get("bottom_max_y", 0.5))
	_apply_wall_visibility()

func _apply_wall_visibility() -> void:
	_apply_side_wall(get_node_or_null(LEFT_WALL_NAME) as Node3D, left_wall_visible, left_wall_opened)
	_apply_side_wall(get_node_or_null(RIGHT_WALL_NAME) as Node3D, right_wall_visible, right_wall_opened)
	_apply_bottom_span()

func _apply_side_wall(wall: Node3D, visible_state: bool, opened_state: bool) -> void:
	if not wall:
		return
	if _uses_ceiling_tray_adaptation():
		wall.visible = true
		wall.scale.y = WALL_KEEP_END_RATIO if opened_state else 1.0
		return
	wall.visible = visible_state
	wall.scale.y = 1.0

func _apply_bottom_span() -> void:
	var bottom := get_node_or_null(BOTTOM_NAME) as Node3D
	if not bottom:
		return
	if not _uses_ceiling_tray_adaptation():
		bottom.visible = true
		bottom.position.y = 0.0
		bottom.scale.y = 1.0
		return
	var span := maxf(bottom_max_y - bottom_min_y, 0.001)
	bottom.visible = true
	bottom.position.y = (bottom_min_y + bottom_max_y) * 0.5
	bottom.scale.y = span

func _uses_ceiling_tray_adaptation() -> bool:
	return scene_file_path == "res://ceiling_tray_object.tscn"
