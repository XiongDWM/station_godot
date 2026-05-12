extends HTTPRequest

signal station_id_changed(station_id)
signal data_received(data)
signal save_completed(data)
signal request_failed(message, response_code)
var base_url :="https://192.168.0.252/api/stationLayout"
var current_station_id: int = -1
var _pending_action: String = ""

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
	if result != RESULT_SUCCESS or response_code != 200:
		var err_msg := "请求失败: %d" % response_code
		push_error(err_msg)
		emit_signal("request_failed", err_msg, response_code)
		return

	var json := JSON.new()
	var err = json.parse(body.get_string_from_utf8())
	if err != OK:
		push_error("JSON解析失败")
		emit_signal("request_failed", "JSON解析失败", response_code)
		return

	var parsed = json.data
	if _pending_action == "save":
		emit_signal("save_completed", parsed)
	else:
		var app_state = _get_app_state()
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("data"):
			if app_state and app_state.has_method("set_layout_data") and parsed["data"] is String:
				app_state.set_layout_data(current_station_id, parsed["data"])
			emit_signal("data_received", parsed["data"])
		else:
			if app_state and app_state.has_method("set_layout_data") and parsed is String:
				app_state.set_layout_data(current_station_id, parsed)
			emit_signal("data_received", parsed)
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