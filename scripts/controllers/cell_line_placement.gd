extends RefCounted

class_name CellLinePlacement

static func get_dominant_axis_cells(grid_map: GridMap, start_point: Vector3, end_point: Vector3) -> Dictionary:
	if not grid_map:
		return {"axis": "x", "sign": 1, "cells": []}
	var start_cell := grid_map.local_to_map(grid_map.to_local(start_point))
	var end_cell := grid_map.local_to_map(grid_map.to_local(end_point))
	start_cell.y = 0
	end_cell.y = 0
	return get_dominant_axis_cells_from_cells(start_cell, end_cell)

static func get_dominant_axis_cells_from_cells(start_cell: Vector3i, end_cell: Vector3i) -> Dictionary:
	var delta_x := end_cell.x - start_cell.x
	var delta_z := end_cell.z - start_cell.z
	var cells: Array[Vector3i] = []
	if abs(delta_x) >= abs(delta_z):
		var sign_x := 1 if delta_x >= 0 else -1
		for x in range(start_cell.x, end_cell.x + sign_x, sign_x):
			cells.append(Vector3i(x, 0, start_cell.z))
		return {"axis": "x", "sign": sign_x, "cells": cells}
	var sign_z := 1 if delta_z >= 0 else -1
	for z in range(start_cell.z, end_cell.z + sign_z, sign_z):
		cells.append(Vector3i(start_cell.x, 0, z))
	return {"axis": "z", "sign": sign_z, "cells": cells}

static func get_dominant_axis_span(grid_map: GridMap, start_point: Vector3, end_point: Vector3) -> Dictionary:
	if not grid_map:
		return {}
	var start_cell := grid_map.local_to_map(grid_map.to_local(start_point))
	var end_cell := grid_map.local_to_map(grid_map.to_local(end_point))
	start_cell.y = 0
	end_cell.y = 0
	var delta_x := end_cell.x - start_cell.x
	var delta_z := end_cell.z - start_cell.z
	if abs(delta_x) >= abs(delta_z):
		return {
			"start_cell": Vector3i(mini(start_cell.x, end_cell.x), 0, start_cell.z),
			"end_cell": Vector3i(maxi(start_cell.x, end_cell.x), 0, start_cell.z),
		}
	return {
		"start_cell": Vector3i(start_cell.x, 0, mini(start_cell.z, end_cell.z)),
		"end_cell": Vector3i(start_cell.x, 0, maxi(start_cell.z, end_cell.z)),
	}

static func cell_center_world(grid_map: GridMap, cell: Vector3i, world_y: float) -> Vector3:
	var world_center := grid_map.to_global(grid_map.map_to_local(cell))
	world_center.y = world_y
	return world_center

static func unit_cell_key(story_level: int, layer: int, cell_x: int, cell_z: int) -> String:
	return "%d,%d,%d,%d" % [story_level, layer, cell_x, cell_z]

static func floor_cell_key(story_level: int, layer: int, cell_x: int, cell_z: int, floor_kind: String) -> String:
	return "%d,%d,%d,%d,%s" % [story_level, layer, cell_x, cell_z, floor_kind]