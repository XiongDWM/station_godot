extends Node3D

@export_group("operation_sensitivity")
@export var rotate_speed: float = 0.01
@export var pan_speed: float = 0.1
@export var zoom_speed: float = 1.0

@export_group("limits")
# 最小距离：防止摄像机钻入地下 (根据你的场景调整，比如 3.0 米)
@export var min_distance: float = 3.0
# 最大距离：脚本会在 _ready() 中自动根据初始位置计算，这里仅作备用

@onready var camera: Camera3D = $Camera3D

# 内部变量
var current_max_distance: float = 10.0

func _ready():
	# 计算摄像机到 Pivot 的当前距离，作为“最大限制”
	# 这样你在编辑器里把 Pivot 放在哪，那个位置就是“最远点”
	if camera:
		current_max_distance = camera.position.length()
		# 防止配置错误：如果最小距离比初始距离还大，强制修正
		if min_distance > current_max_distance:
			min_distance = current_max_distance

func _input(event):
	if not camera:
		return

	# 缩放 (滚轮)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			# 拉近 (距离变小)
			var new_distance = camera.position.length() - zoom_speed
			# 限制：不能小于 min_distance
			new_distance = max(new_distance, min_distance)
			_update_camera_distance(new_distance)

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			# 拉远 (距离变大)
			var new_distance = camera.position.length() + zoom_speed
			# 限制：不能大于初始化时的距离 (current_max_distance)
			new_distance = min(new_distance, current_max_distance)
			_update_camera_distance(new_distance)

	# 旋转 (Option/Alt + 右键)
	# 检测修饰键 (Command/Meta 对应 Mac 的 Option/Win 键)
	var is_mod_pressed = Input.is_key_pressed(KEY_ALT) or Input.is_key_pressed(KEY_META)

	if event is InputEventMouseMotion:
		# 旋转逻辑
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT and is_mod_pressed:
			# 绕 Y 轴旋转 Pivot
			rotate_y(-event.relative.x * rotate_speed)
			# 如果需要上下俯仰，可以取消下面的注释
			# rotate_x(-event.relative.y * rotate_speed)

		# 平移逻辑 (Option/Alt + 左键)
		elif event.button_mask & MOUSE_BUTTON_MASK_LEFT and is_mod_pressed:
			# 获取相对移动量
			var delta = event.relative * pan_speed
			# 沿着 Pivot 的局部坐标移动 (X 是水平，Z 是垂直)
			# 注意：这里假设你的 Pivot 是平放的。
			translate_object_local(Vector3(-delta.x, 0, delta.y))

# 封装一个函数专门处理摄像机位置更新
func _update_camera_distance(target_dist: float):
	if camera:
		var current_dir = camera.position.normalized()
		camera.position = current_dir * target_dist
