extends Node

signal station_id_changed(station_id)

var _station_id: int = -1

func set_station_id(station_id: int) -> void:
	if _station_id == station_id:
		return
	_station_id = station_id
	emit_signal("station_id_changed", _station_id)

func get_station_id() -> int:
	return _station_id
