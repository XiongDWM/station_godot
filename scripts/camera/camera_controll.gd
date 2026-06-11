extends Node3D

enum CameraMode {
	ORBIT,
	FIRST_PERSON,
	SIDE,
}

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
@export var max_orbit_distance: float = 22.0
@export var min_pitch_deg: float = -75.0
@export var max_pitch_deg: float = -10.0
@export var min_camera_world_y: float = 0.0

@export_group("first_person")
@export var first_person_height: float = 1.7
@export var first_person_enter_dolly_distance: float = 0.0
@export var first_person_enter_pause_ms: int = 180
@export var first_person_move_speed: float = 4.0
@export var first_person_collision_margin: float = 0.18
@export var first_person_min_pitch_deg: float = -80.0
@export var first_person_max_pitch_deg: float = 80.0

@export_group("side_view")
@export var side_view_distance: float = 16.0
@export var side_view_enter_zoom_buffer: float = 4.5
@export var side_view_min_pitch_deg: float = -89.0
@export var side_view_max_pitch_deg: float = 89.0

@onready var camera: Camera3D = $Camera3D

var current_mode: int = CameraMode.ORBIT
var current_max_distance: float = 10.0
var current_pitch: float = 0.0
var zoom_direction: Vector3 = Vector3.FORWARD
var current_zoom_dolly_distance: float = 0.0
var desired_camera_local_position: Vector3 = Vector3.ZERO
var stored_orbit_pitch: float = 0.0
var stored_orbit_yaw: float = 0.0
var stored_orbit_distance: float = 0.0
var stored_orbit_dolly: float = 0.0
var first_person_zoom_limit_reached_at_msec: int = -1
var side_view_zoom_buffer_progress: float = 0.0

func _ready():
	if camera:
		if camera.position.length() <= 0.001:
			camera.position = Vector3(0.0, 0.0, default_distance)
		desired_camera_local_position = camera.position
		zoom_direction = camera.position.normalized()
		current_max_distance = maxf(camera.position.length(), max_orbit_distance)
		var effective_min_distance := _get_effective_min_distance()
		if effective_min_distance > current_max_distance:
			min_distance = current_max_distance
		current_pitch = rotation.x
		_enforce_camera_limits()
	_notify_scene_mode_changed()

func _process(delta: float) -> void:
	if current_mode == CameraMode.FIRST_PERSON:
		_update_first_person_movement(delta)

func _input(event):
	if not camera:
		return
	if _is_preview_consuming_input(event):
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_handle_zoom_input(-zoom_speed)

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_handle_zoom_input(zoom_speed)

	var is_mod_pressed = Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_META) or Input.is_key_pressed(KEY_CTRL)

	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT and is_mod_pressed:
			_rotate_active_camera(event.relative)
		elif event.button_mask & MOUSE_BUTTON_MASK_LEFT and is_mod_pressed:
			_pan_active_camera(event.relative)

func _handle_zoom_input(zoom_step: float) -> void:
	match current_mode:
		CameraMode.ORBIT:
			var zoom_changed := _zoom_camera(zoom_step)
			if not zoom_changed and zoom_step < 0.0:
				side_view_zoom_buffer_progress = 0.0
				var now := Time.get_ticks_msec()
				if first_person_zoom_limit_reached_at_msec >= 0 and now - first_person_zoom_limit_reached_at_msec >= first_person_enter_pause_ms:
					first_person_zoom_limit_reached_at_msec = -1
					_enter_first_person_mode()
				else:
					first_person_zoom_limit_reached_at_msec = now
			elif not zoom_changed and zoom_step > 0.0:
				first_person_zoom_limit_reached_at_msec = -1
				side_view_zoom_buffer_progress += zoom_step
				if side_view_zoom_buffer_progress >= maxf(side_view_enter_zoom_buffer, zoom_speed):
					side_view_zoom_buffer_progress = 0.0
					_enter_side_view_mode()
			else:
				first_person_zoom_limit_reached_at_msec = -1
				side_view_zoom_buffer_progress = 0.0
		CameraMode.FIRST_PERSON:
			if zoom_step > 0.0:
				_exit_first_person_mode()
		CameraMode.SIDE:
			if zoom_step < 0.0:
				_request_side_view_exit(0)

func _rotate_active_camera(relative: Vector2) -> void:
	match current_mode:
		CameraMode.FIRST_PERSON:
			_rotate_first_person(relative)
		CameraMode.SIDE:
			_rotate_side_view(relative)
		_:
			_rotate_camera(relative)

func _pan_active_camera(relative: Vector2) -> void:
	if current_mode == CameraMode.FIRST_PERSON:
		return
	_pan_camera(relative)

func _rotate_camera(relative: Vector2) -> void:
	rotate_y(-relative.x * rotate_speed)
	current_pitch = clamp(
		current_pitch - relative.y * pitch_speed,
		deg_to_rad(min_pitch_deg),
		deg_to_rad(max_pitch_deg)
	)
	rotation.x = current_pitch
	_enforce_camera_limits()

func _rotate_first_person(relative: Vector2) -> void:
	rotate_y(-relative.x * rotate_speed)
	current_pitch = clamp(
		current_pitch - relative.y * pitch_speed,
		deg_to_rad(first_person_min_pitch_deg),
		deg_to_rad(first_person_max_pitch_deg)
	)
	rotation.x = current_pitch
	global_position.y = first_person_height

func _rotate_side_view(relative: Vector2) -> void:
	rotate_y(-relative.x * rotate_speed)
	current_pitch = clamp(
		current_pitch - relative.y * pitch_speed,
		deg_to_rad(side_view_min_pitch_deg),
		deg_to_rad(side_view_max_pitch_deg)
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
	_enforce_min_camera_height()

func _update_camera_distance(target_dist: float):
	if camera:
		var current_length := camera.position.length()
		if current_length > 0.001:
			zoom_direction = camera.position / current_length
		desired_camera_local_position = zoom_direction * max(target_dist, _get_effective_min_distance())
		_apply_camera_collision_to_desired_position()
		_enforce_camera_limits()

func _zoom_camera(zoom_step: float) -> bool:
	if not camera:
		return false
	var changed := false

	var remaining_zoom_step: float = zoom_step
	if remaining_zoom_step > 0.0 and current_zoom_dolly_distance > 0.0:
		var retract_amount: float = minf(remaining_zoom_step * zoom_dolly_factor, current_zoom_dolly_distance)
		changed = _apply_dolly(-retract_amount) or changed
		remaining_zoom_step -= retract_amount / maxf(zoom_dolly_factor, 0.001)

	var current_distance: float = camera.position.length()
	var clamped_distance: float = clamp(
		current_distance + remaining_zoom_step,
		_get_effective_min_distance(),
		current_max_distance
	)
	var applied_distance_change: float = clamped_distance - current_distance
	changed = changed or not is_zero_approx(applied_distance_change)
	_update_camera_distance(clamped_distance)

	var remaining_zoom: float = remaining_zoom_step - applied_distance_change
	if remaining_zoom < -0.001:
		var allowed_dolly_distance := maxf(minf(first_person_enter_dolly_distance, max_zoom_dolly_distance), 0.0)
		var dolly_in_amount: float = minf(-remaining_zoom * zoom_dolly_factor, maxf(allowed_dolly_distance - current_zoom_dolly_distance, 0.0))
		changed = _apply_dolly(dolly_in_amount) or changed
	return changed


func _apply_dolly(amount: float) -> bool:
	if is_zero_approx(amount):
		return false
	var forward := -camera.global_transform.basis.z
	if forward.is_zero_approx():
		return false
	var previous_position := global_position
	global_position += forward.normalized() * amount
	current_zoom_dolly_distance = clampf(current_zoom_dolly_distance + amount, 0.0, max_zoom_dolly_distance)
	_enforce_camera_limits()
	return previous_position.distance_to(global_position) > 0.0001

func _get_effective_min_distance() -> float:
	return maxf(min_distance, 0.05)

func _enforce_camera_limits() -> void:
	if not camera:
		return
	_enforce_min_camera_height()
	if current_mode != CameraMode.FIRST_PERSON:
		_apply_camera_collision_to_desired_position()

func _enforce_min_camera_height() -> void:
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

func _update_first_person_movement(delta: float) -> void:
	var movement_input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		movement_input.y += 1.0
	if Input.is_key_pressed(KEY_S):
		movement_input.y -= 1.0
	if Input.is_key_pressed(KEY_D):
		movement_input.x += 1.0
	if Input.is_key_pressed(KEY_A):
		movement_input.x -= 1.0
	if movement_input.is_zero_approx():
		return
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	if forward.is_zero_approx() or right.is_zero_approx():
		return
	var move_direction := (right * movement_input.x + forward * movement_input.y).normalized()
	var target_position := global_position + move_direction * first_person_move_speed * delta
	target_position.y = first_person_height
	global_position = _move_first_person_with_collision(global_position, target_position)
	global_position.y = first_person_height

func _move_first_person_with_collision(from_position: Vector3, to_position: Vector3) -> Vector3:
	var scene_root := get_tree().current_scene
	if not scene_root:
		return to_position
	var world : World3D = scene_root.get_world_3d()
	if not world:
		return to_position
	var direction := to_position - from_position
	if direction.length() <= 0.0001:
		return from_position
	var query := PhysicsRayQueryParameters3D.create(from_position, to_position)
	var result := world.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return to_position
	return result.position - direction.normalized() * first_person_collision_margin

func _apply_camera_collision_to_desired_position() -> void:
	if not camera:
		return
	if current_mode == CameraMode.FIRST_PERSON:
		camera.position = Vector3.ZERO
		return
	camera.position = desired_camera_local_position

func _enter_first_person_mode() -> void:
	_store_orbit_state()
	current_mode = CameraMode.FIRST_PERSON
	first_person_zoom_limit_reached_at_msec = -1
	side_view_zoom_buffer_progress = 0.0
	current_zoom_dolly_distance = 0.0
	current_pitch = 0.0
	rotation.x = 0.0
	global_position = _get_default_first_person_position(global_position)
	global_position.y = first_person_height
	desired_camera_local_position = Vector3.ZERO
	camera.position = Vector3.ZERO
	_notify_scene_mode_changed()

func _exit_first_person_mode() -> void:
	current_mode = CameraMode.ORBIT
	first_person_zoom_limit_reached_at_msec = -1
	side_view_zoom_buffer_progress = 0.0
	current_pitch = stored_orbit_pitch
	rotation.x = current_pitch
	rotation.y = stored_orbit_yaw
	current_zoom_dolly_distance = 0.0
	desired_camera_local_position = Vector3(0.0, 0.0, maxf(stored_orbit_distance, 1.5))
	zoom_direction = desired_camera_local_position.normalized()
	_apply_camera_collision_to_desired_position()
	_notify_scene_mode_changed()

func _enter_side_view_mode() -> void:
	_store_orbit_state()
	current_mode = CameraMode.SIDE
	first_person_zoom_limit_reached_at_msec = -1
	side_view_zoom_buffer_progress = 0.0
	current_pitch = clamp(0.0, deg_to_rad(side_view_min_pitch_deg), deg_to_rad(side_view_max_pitch_deg))
	rotation.x = current_pitch
	global_position = _get_default_side_view_focus_position(global_position)
	current_zoom_dolly_distance = 0.0
	desired_camera_local_position = Vector3(0.0, 0.0, side_view_distance)
	zoom_direction = desired_camera_local_position.normalized()
	_apply_camera_collision_to_desired_position()
	_notify_scene_mode_changed()

func exit_side_view_to_orbit(target_layer: int = 0) -> void:
	var scene_root := get_tree().current_scene
	if scene_root and scene_root.has_method("request_side_view_enter_layer"):
		scene_root.call("request_side_view_enter_layer", target_layer)
	current_mode = CameraMode.ORBIT
	first_person_zoom_limit_reached_at_msec = -1
	side_view_zoom_buffer_progress = 0.0
	current_pitch = stored_orbit_pitch
	rotation.x = current_pitch
	rotation.y = stored_orbit_yaw
	desired_camera_local_position = Vector3(0.0, 0.0, maxf(stored_orbit_distance, 1.5))
	zoom_direction = desired_camera_local_position.normalized()
	current_zoom_dolly_distance = 0.0
	_apply_camera_collision_to_desired_position()
	_notify_scene_mode_changed()

func _request_side_view_exit(target_layer: int) -> void:
	exit_side_view_to_orbit(target_layer)

func _store_orbit_state() -> void:
	stored_orbit_pitch = current_pitch
	stored_orbit_yaw = rotation.y
	stored_orbit_distance = desired_camera_local_position.length() if desired_camera_local_position.length() > 0.001 else maxf(camera.position.length(), 1.5)
	stored_orbit_dolly = current_zoom_dolly_distance

func _get_default_first_person_position(fallback: Vector3) -> Vector3:
	var scene_root := get_tree().current_scene
	if scene_root and scene_root.has_method("get_default_first_person_position"):
		return scene_root.call("get_default_first_person_position", fallback)
	return Vector3(fallback.x, first_person_height, fallback.z)

func _get_default_side_view_focus_position(fallback: Vector3) -> Vector3:
	var scene_root := get_tree().current_scene
	if scene_root and scene_root.has_method("get_default_side_view_focus_position"):
		return scene_root.call("get_default_side_view_focus_position", fallback)
	return Vector3(fallback.x, 0.5, fallback.z)

func _notify_scene_mode_changed() -> void:
	var scene_root := get_tree().current_scene
	if scene_root and scene_root.has_method("on_camera_mode_changed"):
		scene_root.call("on_camera_mode_changed", get_camera_mode_name())

func get_camera_mode_name() -> String:
	match current_mode:
		CameraMode.FIRST_PERSON:
			return "first_person"
		CameraMode.SIDE:
			return "side"
		_:
			return "orbit"
