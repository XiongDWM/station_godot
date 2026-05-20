extends HTTPRequest

signal station_id_changed(station_id)
signal data_received(data)
signal save_completed(data)
signal request_failed(message, response_code)
var base_url :="https://192.168.0.252/api/stationLayout"
var current_station_id: int = -1
var _pending_action: String = ""

func _ready() -> void:
	if not request_completed.is_connected(_on_request_completed):
		request_completed.connect(_on_request_completed)

func _get_app_state() -> Node:
	return get_node_or_null("/root/AppState")

func bootstrap_layout(refresh_from_server: bool = true) -> bool:
	var app_state = _get_app_state()
	if app_state and app_state.has_method("refresh_station_id_from_web_storage"):
		app_state.refresh_station_id_from_web_storage()

	var station_id := current_station_id
	if app_state and app_state.has_method("get_station_id"):
		station_id = app_state.get_station_id()

	if station_id <= 0:
		push_warning("没有有效的 station_id 可用于加载布局")
		return false

	fetch_room_layout(station_id, refresh_from_server)
	return true

func fetch_room_layout(room_id: int, refresh_from_server: bool = false) -> void:
	var endpoint := "%s/findById" % [base_url]
	var headers := ["Content-Type: application/json"]
	var payload := {"id": room_id}
	var json_body := JSON.stringify(payload)
	current_station_id = room_id
	var app_state = _get_app_state()
	if app_state and app_state.has_method("set_station_id"):
		app_state.set_station_id(room_id)
	emit_signal("station_id_changed", room_id)

	if app_state and app_state.has_method("get_layout_data"):
		var cached_layout = app_state.get_layout_data(room_id)
		if cached_layout != "":
			print("命中布局缓存，station_id:", room_id)
			emit_signal("data_received", cached_layout)
			if not refresh_from_server:
				return

	print("正在请求:", endpoint, " body:", json_body)
	_pending_action = "fetch"
	request(endpoint, headers, HTTPClient.METHOD_POST, json_body)

func _on_request_completed(result, response_code, _headers, body):
	print("HTTP 请求完成，结果:", result, " 响应码:", response_code)
	if result != RESULT_SUCCESS or response_code != 200:
		var err_msg := "请求失败: %d" % response_code
		push_error(err_msg)
		emit_signal("request_failed", err_msg, response_code)
		return

	var json := JSON.new()
	var err = json.parse(body.get_string_from_utf8())
	print("HTTP 响应 JSON 解析结果:", err)
	if err != OK:
		push_error("JSON解析失败")
		emit_signal("request_failed", "JSON解析失败", response_code)
		return

	var parsed = json.data
	print("后端返回对象:\n", JSON.stringify(parsed, "  "))
	if _pending_action == "save":
		emit_signal("save_completed", parsed)
	else:
		var app_state = _get_app_state()
		var layout_json := _extract_layout_json(parsed)
		print("提取到的 layout 字符串:\n", layout_json)
		if _has_valid_layout_payload(layout_json):
			if app_state and app_state.has_method("set_layout_data"):
				app_state.set_layout_data(current_station_id, layout_json)
			emit_signal("data_received", layout_json)
		else:
			print("机房", current_station_id, "暂无可加载布局")
	_pending_action = ""

func save_layout_data(layout_data_string: String, station: int) -> void:
	if station <= 0:
		push_warning("station_id 获取失败")
		return
	if layout_data_string == "":
		push_warning("布局为空，跳过保存")
		return
	var endpoint := "%s/saveOrUpdate" % [base_url]
	var headers := ["Content-Type: application/json"]
	var payload := {
		"station": station,
		"layout": layout_data_string
	}
	print("正在保存布局:", endpoint, " body:", layout_data_string)
	var json_body := JSON.stringify(payload)
	current_station_id = station
	_pending_action = "save"
	var app_state = _get_app_state()
	if app_state and app_state.has_method("set_station_id"):
		app_state.set_station_id(station)
	emit_signal("station_id_changed", station)
	request(endpoint, headers, HTTPClient.METHOD_POST, json_body)

func get_current_station_id() -> int:
	return current_station_id

func _has_valid_layout_payload(data) -> bool:
	match typeof(data):
		TYPE_STRING:
			return str(data).strip_edges() != ""
		TYPE_ARRAY:
			return (data as Array).size() > 0
		_:
			return false

func _extract_layout_json(payload) -> String:
	return _find_layout_value(payload)

func _find_layout_value(value) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			var dict_value := value as Dictionary
			if dict_value.has("layout"):
				return str(dict_value["layout"]).strip_edges()
			for nested_value in dict_value.values():
				var nested_layout := _find_layout_value(nested_value)
				if nested_layout != "":
					return nested_layout
		TYPE_ARRAY:
			for nested_value in value:
				var nested_layout := _find_layout_value(nested_value)
				if nested_layout != "":
					return nested_layout
	return ""