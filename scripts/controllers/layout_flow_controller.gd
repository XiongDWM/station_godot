extends RefCounted

class_name LayoutFlowController

var root: Node3D = null
var http_request: HTTPRequest = null
var layout_serializer = null
var current_station_id: int = -1

func setup(target_root: Node3D, request_node: HTTPRequest, serializer) -> void:
	root = target_root
	http_request = request_node
	layout_serializer = serializer

func bind_save_button(btn_save: Button) -> void:
	if btn_save:
		btn_save.pressed.connect(save_layoutdata)

func bind_api_signals() -> void:
	if not http_request:
		return
	if http_request.has_signal("station_id_changed") and not http_request.station_id_changed.is_connected(_on_station_id_changed):
		http_request.station_id_changed.connect(_on_station_id_changed)
	if http_request.has_signal("data_received") and not http_request.data_received.is_connected(_on_layout_data_received):
		http_request.data_received.connect(_on_layout_data_received)
	if http_request.has_signal("save_completed") and not http_request.save_completed.is_connected(_on_layout_saved):
		http_request.save_completed.connect(_on_layout_saved)
	if http_request.has_signal("request_failed") and not http_request.request_failed.is_connected(_on_api_request_failed):
		http_request.request_failed.connect(_on_api_request_failed)

func bootstrap() -> void:
	if http_request and http_request.has_method("bootstrap_layout"):
		if not http_request.bootstrap_layout(true):
			_try_load_cached_layout()
	else:
		var app_state = _get_app_state()
		if app_state and app_state.has_method("get_station_id"):
			current_station_id = app_state.get_station_id()
		_try_load_cached_layout()

func save_layoutdata() -> String:
	if not root or not layout_serializer:
		return ""
	var layout_data_array = layout_serializer.serialize_scene(root)
	var json_string = JSON.stringify(layout_data_array, "  ")
	print("布局数据:\n", json_string)
	var app_state = _get_app_state()
	if app_state and app_state.has_method("get_station_id"):
		current_station_id = app_state.get_station_id()
	_cache_layout_data(json_string)
	if http_request and http_request.has_method("save_layout_data"):
		http_request.save_layout_data(json_string, current_station_id)
	return json_string

func _get_app_state() -> Node:
	if not root:
		return null
	return root.get_node_or_null("/root/AppState")

func _on_station_id_changed(station_id: int) -> void:
	current_station_id = station_id
	var app_state = _get_app_state()
	if app_state and app_state.has_method("set_station_id"):
		app_state.set_station_id(station_id)
	print("当前 station_id:", current_station_id)
	_try_load_cached_layout()

func _on_layout_data_received(data) -> void:
	if not layout_serializer or not root:
		return
	var layout_json := str(data).strip_edges()
	if not _has_valid_layout_data(layout_json):
		push_warning("收到的 layout 为空，跳过加载")
		return
	if not layout_serializer.has_method("validate_layout_json"):
		push_warning("layout_serializer 缺少 validate_layout_json，跳过校验")
		print("待加载的 layout 原文:\n", layout_json)
		return
	var validation_result = layout_serializer.call("validate_layout_json", layout_json)
	if not validation_result.get("ok", false):
		push_warning("layout 校验失败: %s" % validation_result.get("message", "未知错误"))
		print("待加载的 layout 原文:\n", layout_json)
		return
	print("layout 校验通过，数量:", validation_result.get("count", 0))
	_cache_layout_data(layout_json)
	load_layoutdata(layout_json)

func _on_layout_saved(data) -> void:
	print("保存成功:", data)

func _on_api_request_failed(message: String, response_code: int) -> void:
	push_error("API 请求失败: %s (%d)" % [message, response_code])

func _cache_layout_data(layout_json: String) -> void:
	var app_state = _get_app_state()
	if current_station_id <= 0:
		return
	if app_state and app_state.has_method("set_layout_data"):
		app_state.set_layout_data(current_station_id, layout_json)

func _try_load_cached_layout() -> void:
	var app_state = _get_app_state()
	if current_station_id <= 0:
		return
	if app_state and app_state.has_method("get_layout_data"):
		var cached_layout = app_state.get_layout_data(current_station_id)
		if _has_valid_layout_data(cached_layout):
			load_layoutdata(cached_layout)

func load_layoutdata(json_string: String) -> void:
	if layout_serializer and root and _has_valid_layout_data(json_string):
		layout_serializer.deserialize_json_to_scene(json_string, root)

func _has_valid_layout_data(data) -> bool:
	match typeof(data):
		TYPE_STRING:
			return str(data).strip_edges() != ""
		TYPE_ARRAY:
			return (data as Array).size() > 0
		_:
			return false