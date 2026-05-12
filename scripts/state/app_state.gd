extends Node

signal station_id_changed(station_id)

const WEB_STORAGE_STATION_KEY := "godot_selected_room_id"

var _station_id: int = -1
var _layout_cache := {}

func _ready() -> void:
	refresh_station_id_from_web_storage()

func _can_use_web_storage() -> bool:
	return OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge")

func refresh_station_id_from_web_storage() -> int:
	if not _can_use_web_storage():
		push_warning("没有找到 JavaScriptBridge，无法使用 Web Storage 功能。")
		return _station_id
	var station_id_value = JavaScriptBridge.eval("window.localStorage.getItem('%s')" % WEB_STORAGE_STATION_KEY, true)
	push_warning("从 Web Storage 获取 station_id: %s" % str(station_id_value))
	if station_id_value == null:
		return _station_id
	var station_id_text = str(station_id_value).strip_edges()
	if station_id_text == "" or not station_id_text.is_valid_int():
		push_warning("从 Web Storage 获取的 station_id 无效: %s" % station_id_text)
		return _station_id
	set_station_id(int(station_id_text))
	return _station_id

func _sync_station_id_to_web_storage() -> void:
	if not _can_use_web_storage() or _station_id <= 0:
		return
	JavaScriptBridge.eval("window.localStorage.setItem('%s', '%s')" % [WEB_STORAGE_STATION_KEY, str(_station_id)], true)

func set_station_id(station_id: int) -> void:
	if _station_id == station_id:
		return
	_station_id = station_id
	_sync_station_id_to_web_storage()
	emit_signal("station_id_changed", _station_id)

func get_station_id() -> int:
	return _station_id

func set_layout_data(station_id: int, layout_json: String) -> void:
	if station_id <= 0 or layout_json == "":
		return
	_layout_cache[station_id] = layout_json

func get_layout_data(station_id: int) -> String:
	if _layout_cache.has(station_id):
		return _layout_cache[station_id]
	return ""

func has_layout_data(station_id: int) -> bool:
	return _layout_cache.has(station_id)

func clear_layout_data(station_id: int) -> void:
	if _layout_cache.has(station_id):
		_layout_cache.erase(station_id)