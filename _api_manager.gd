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

func fetch_room_layout(room_id: int) -> void:
	var endpoint := "%s/findById" % [base_url]
	var headers := ["Content-Type: application/json"]
	var payload := {"id": room_id}
	var json_body := JSON.stringify(payload)
	print("正在请求:", endpoint, " body:", json_body)
	current_station_id = room_id
	_pending_action = "fetch"
	var app_state = _get_app_state()
	if app_state and app_state.has_method("set_station_id"):
		app_state.set_station_id(room_id)
	emit_signal("station_id_changed", room_id)
	request(endpoint, headers, HTTPClient.METHOD_POST, json_body)

func _on_request_completed(result, response_code, _headers, body):
	if result != RESULT_SUCCESS or response_code != 200:
		var err_msg := "请求失败: %d" % response_code
		push_error(err_msg)
		emit_signal("request_failed", err_msg, response_code)
		return

	# 解析 JSON
	var json := JSON.new()
	var err = json.parse(body.get_string_from_utf8())
	if err != OK:
		push_error("JSON解析失败")
		emit_signal("request_failed", "JSON解析失败", response_code)
		return
	
	# 根据当前请求类型发出不同信号
	var parsed = json.data
	if _pending_action == "save":
		emit_signal("save_completed", parsed)
	else:
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("data"):
			emit_signal("data_received", parsed["data"])
		else:
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
