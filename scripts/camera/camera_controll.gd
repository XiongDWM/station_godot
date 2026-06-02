extends Node3D

@export_group("operation_sensitivity")
@export var rotate_speed: float = 0.006
@export var pan_speed: float = 0.05
@export var zoom_speed: float = 1.0
@export var pitch_speed: float = 0.005
@export var zoom_dolly_factor: float = 0.85
@export var max_zoom_dolly_distance: float = 8.0 # camera pivot can move at most this distance when zooming in or 

@export_group("limits")
@export var min_distance: float = 0.02
@export var default_distance: float = 12.0
@export var min_pitch_deg: float = -75.0
@export var max_pitch_deg: float = -10.0
@export var min_camera_world_y: float = 0.0

@onready var camera: Camera3D = $Camera3D

var current_max_distance: float = 10.0
var current_pitch: float = 0.0
var zoom_direction: Vector3 = Vector3.FORWARD
var current_zoom_dolly_distance: float = 0.0

func _ready():
	if camera:
		if camera.position.length() <= 0.001:
			camera.position = Vector3(0.0, 0.0, default_distance)
		zoom_direction = camera.position.normalized()
		current_max_distance = camera.position.length()
		var effective_min_distance := _get_effective_min_distance()
		if effective_min_distance > current_max_distance:
			min_distance = current_max_distance
		current_pitch = rotation.x
		_enforce_camera_limits()

func _input(event):
	if not camera:
		return
	if _is_preview_consuming_input(event):
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_camera(-zoom_speed)

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_camera(zoom_speed)

	var is_mod_pressed = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)

	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT and is_mod_pressed:
			_rotate_camera(event.relative)
		elif event.button_mask & MOUSE_BUTTON_MASK_LEFT and is_mod_pressed:
			_pan_camera(event.relative)

func _rotate_camera(relative: Vector2) -> void:
	rotate_y(-relative.x * rotate_speed)
	current_pitch = clamp(
		current_pitch - relative.y * pitch_speed,
		deg_to_rad(min_pitch_deg),
		deg_to_rad(max_pitch_deg)
	)
	rotation.x = current_pitch
	_enforce_camera_limits()

func _pan_camera(relative: Vector2) -> void:
	var right := global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	if right.is_zero_approx() or forward.is_zero_approx():
		return

	var pan_delta := (-right * relative.x + forward * relative.y) * pan_speed
	global_position += pan_delta
	_enforce_camera_limits()

func _update_camera_distance(target_dist: float):
	if camera:
		var current_length := camera.position.length()
		if current_length > 0.001:
			zoom_direction = camera.position / current_length
		camera.position = zoom_direction * max(target_dist, _get_effective_min_distance())
		_enforce_camera_limits()

func _zoom_camera(zoom_step: float) -> void:
	if not camera:
		return

	var remaining_zoom_step: float = zoom_step
	if remaining_zoom_step > 0.0 and current_zoom_dolly_distance > 0.0:
		var retract_amount: float = minf(remaining_zoom_step * zoom_dolly_factor, current_zoom_dolly_distance)
		_apply_dolly(-retract_amount)
		remaining_zoom_step -= retract_amount / maxf(zoom_dolly_factor, 0.001)

	var current_distance: float = camera.position.length()
	var clamped_distance: float = clamp(
		current_distance + remaining_zoom_step,
		_get_effective_min_distance(),
		current_max_distance
	)
	var applied_distance_change: float = clamped_distance - current_distance
	_update_camera_distance(clamped_distance)

	var remaining_zoom: float = remaining_zoom_step - applied_distance_change
	if remaining_zoom < -0.001:
		var dolly_in_amount: float = minf(-remaining_zoom * zoom_dolly_factor, maxf(max_zoom_dolly_distance - current_zoom_dolly_distance, 0.0))
		_apply_dolly(dolly_in_amount)

func _apply_dolly(amount: float) -> void:
	if is_zero_approx(amount):
		return
	var forward := -camera.global_transform.basis.z
	if forward.is_zero_approx():
		return
	global_position += forward.normalized() * amount
	current_zoom_dolly_distance = clampf(current_zoom_dolly_distance + amount, 0.0, max_zoom_dolly_distance)
	_enforce_camera_limits()

func _get_effective_min_distance() -> float:
	return maxf(min_distance, 0.05)

func _enforce_camera_limits() -> void:
	if not camera:
		return
	if global_position.y < min_camera_world_y:
		global_position.y = min_camera_world_y
	var camera_world_y := camera.global_position.y
	if camera_world_y < min_camera_world_y:
		global_position.y += min_camera_world_y - camera_world_y

func _is_preview_consuming_input(event: InputEvent) -> bool:
	var scene_root := get_tree().current_scene
	if not scene_root:
		return false
	var preview_overlay := scene_root.get_node_or_null("CanvasLayer/OdfFocusPreviewOverlay")
	if preview_overlay and preview_overlay.has_method("should_block_main_scene_input"):
		return bool(preview_overlay.call("should_block_main_scene_input", event))
	return false
