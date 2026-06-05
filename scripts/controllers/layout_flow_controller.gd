extends RefCounted

class_name LayoutFlowController

var root: Node3D = null
var http_request: HTTPRequest = null
var layout_serializer = null
var current_station_id: int = -1
var save_request_pending := false

func setup(target_root: Node3D, request_node: HTTPRequest, serializer) -> void:
	root = target_root
	http_request = request_node
	layout_serializer = serializer

func bind_save_button(btn_save: Button) -> void:
	if btn_save and not btn_save.pressed.is_connected(save_layoutdata):
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
	_ensure_layout_node_ids()
	var layout_data_array = layout_serializer.serialize_scene(root)
	var json_string = JSON.stringify(layout_data_array, "  ")
	print("布局数据:\n", json_string)
	var app_state = _get_app_state()
	if app_state and app_state.has_method("get_station_id"):
		current_station_id = app_state.get_station_id()
	_cache_layout_data(json_string)
	if not http_request or not http_request.has_method("save_layout_data"):
		_show_save_notification(false, "保存失败: API 未就绪")
		return json_string
	if current_station_id <= 0:
		_show_save_notification(false, "保存失败: station_id 获取失败")
		return json_string
	save_request_pending = true
	http_request.save_layout_data(json_string, current_station_id)
	return json_string

func _ensure_layout_node_ids() -> void:
	if not root:
		return
	for child in root.get_children():
		if not child is Node3D:
			continue
		var node := child as Node3D
		if node.scene_file_path == "" or node.is_in_group("preview"):
			continue
		if node.has_method("ensure_persistent_id"):
			node.call("ensure_persistent_id")
		elif node.has_meta("module_config") and not node.has_meta("module_cabinet_id"):
			node.set_meta("module_cabinet_id", _generate_fallback_cabinet_id())

func _generate_fallback_cabinet_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var timestamp_ms := int(Time.get_unix_time_from_system() * 1000.0)
	return "cab_%013d_%08x%08x" % [timestamp_ms, rng.randi(), rng.randi()]

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
	if not save_request_pending:
		return
	save_request_pending = false
	var success := _is_success_response(data)
	_show_save_notification(success, _get_save_response_message(data, success))

func _on_api_request_failed(message: String, response_code: int) -> void:
	push_error("API 请求失败: %s (%d)" % [message, response_code])
	if save_request_pending:
		save_request_pending = false
		_show_save_notification(false, "保存失败: %s" % message)

func _is_success_response(data) -> bool:
	if data is Dictionary:
		return int((data as Dictionary).get("code", 0)) == 200
	return false

func _get_save_response_message(data, success: bool) -> String:
	var fallback := "保存成功" if success else "保存失败"
	if data is Dictionary:
		var response := data as Dictionary
		var detail := str(response.get("list", response.get("msg", ""))).strip_edges()
		if detail != "":
			return "%s: %s" % [fallback, detail]
	return fallback

func _show_save_notification(success: bool, message: String) -> void:
	if root and root.has_method("show_save_notification"):
		root.call("show_save_notification", success, message)

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
		if root.has_method("restore_built_floor_cells_from_layout"):
			root.call("restore_built_floor_cells_from_layout")
		if root.has_method("rebuild_runtime_scene_indexes"):
			root.call("rebuild_runtime_scene_indexes")
		if root.has_method("refresh_build_view_state"):
			root.call("refresh_build_view_state")

func _has_valid_layout_data(data) -> bool:
	match typeof(data):
		TYPE_STRING:
			return str(data).strip_edges() != ""
		TYPE_ARRAY:
			return (data as Array).size() > 0
		_:
			return false