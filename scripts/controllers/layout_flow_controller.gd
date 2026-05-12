extends RefCounted

class_name LayoutFlowController

var root: Node3D = null
var http_request: HTTPRequest = null
var layout_serializer: LayoutSerializer = null
var current_station_id: int = -1

func setup(target_root: Node3D, request_node: HTTPRequest, serializer: LayoutSerializer) -> void:
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
	if typeof(data) == TYPE_STRING:
		_cache_layout_data(data)
		load_layoutdata(data)
		return

	if typeof(data) == TYPE_DICTIONARY and data.has("layout"):
		var layout_string = str(data["layout"])
		_cache_layout_data(layout_string)
		load_layoutdata(layout_string)
		return

	if typeof(data) == TYPE_ARRAY:
		_cache_layout_data(JSON.stringify(data, "  "))
		layout_serializer.deserialize_items_to_scene(data, root)

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
		if cached_layout != "":
			load_layoutdata(cached_layout)

func load_layoutdata(json_string: String) -> void:
	if layout_serializer and root:
		layout_serializer.deserialize_json_to_scene(json_string, root)