extends Node3D

@export_group("operation_sensitivity")
@export var rotate_speed: float = 0.01
@export var pan_speed: float = 0.1
@export var zoom_speed: float = 1.0

@export_group("limits")
@export var min_distance: float = 3.0

@onready var camera: Camera3D = $Camera3D

var current_max_distance: float = 10.0

func _ready():
	if camera:
		current_max_distance = camera.position.length()
		if min_distance > current_max_distance:
			min_distance = current_max_distance

func _input(event):
	if not camera:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			var new_distance = camera.position.length() - zoom_speed
			new_distance = max(new_distance, min_distance)
			_update_camera_distance(new_distance)

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			var new_distance = camera.position.length() + zoom_speed
			new_distance = min(new_distance, current_max_distance)
			_update_camera_distance(new_distance)

	var is_mod_pressed = Input.is_key_pressed(KEY_ALT) or Input.is_key_pressed(KEY_META)

	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT and is_mod_pressed:
			rotate_y(-event.relative.x * rotate_speed)
		elif event.button_mask & MOUSE_BUTTON_MASK_LEFT and is_mod_pressed:
			var delta = event.relative * pan_speed
			translate_object_local(Vector3(-delta.x, 0, delta.y))

func _update_camera_distance(target_dist: float):
	if camera:
		var current_dir = camera.position.normalized()
		camera.position = current_dir * target_dist