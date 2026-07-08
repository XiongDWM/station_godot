extends RefCounted

class_name LayoutSerializer

func serialize_scene(root: Node, excluded_group: String = "preview") -> Array:
	var layout_items: Array = []
	for child in root.get_children():
		if _is_serializable_scene_root(child, excluded_group):
			layout_items.append(_serialize_node3d(child as Node3D))
	return layout_items

func serialize_scene_to_json(root: Node, excluded_group: String = "preview", indent: String = "  ") -> String:
	return JSON.stringify(serialize_scene(root, excluded_group), indent)

func validate_layout_json(json_string: String) -> Dictionary:
	var normalized := json_string.strip_edges()
	if normalized == "":
		return {"ok": false, "message": "layout 为空字符串"}

	var json := JSON.new()
	var parse_result = json.parse(normalized)
	if parse_result != OK:
		return {"ok": false, "message": "layout JSON 解析失败"}

	if not json.data is Array:
		return {"ok": false, "message": "layout 根节点不是数组"}

	var items := json.data as Array
	for index in items.size():
		var item = items[index]
		if typeof(item) != TYPE_DICTIONARY:
			return {"ok": false, "message": "layout[%d] 不是对象" % index}
		var item_dict := item as Dictionary
		var scene_path := str(item_dict.get("scene_path", "")).strip_edges()
		if scene_path == "":
			return {"ok": false, "message": "layout[%d].scene_path 为空" % index}
		if not item_dict.has("position"):
			return {"ok": false, "message": "layout[%d] 缺少 position" % index}
		if not item_dict.has("basis"):
			return {"ok": false, "message": "layout[%d] 缺少 basis" % index}

	return {"ok": true, "count": items.size(), "message": "layout 校验通过"}

func deserialize_json_to_scene(json_string: String, root: Node, excluded_group: String = "preview") -> bool:
	var json := JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("JSON 解析失败")
		return false

	if json.data is Array:
		deserialize_items_to_scene(json.data, root, excluded_group)
		return true

	push_error("布局数据格式错误")
	return false

func deserialize_items_to_scene(data: Array, root: Node, excluded_group: String = "preview") -> void:
	_clear_scene(root, excluded_group)
	for item in data:
		_instantiate_item(item, root)
	call_deferred("_finalize_deserialized_nodes", root)

func _finalize_deserialized_nodes(root: Node) -> void:
	for child in root.get_children():
		if child.has_method("finalize_serialized_state"):
			child.call("finalize_serialized_state")

func _serialize_node3d(node: Node3D) -> Dictionary:
	var global_xform = node.global_transform
	var item := {
		"scene_path": node.scene_file_path,
		"position": {
			"x": global_xform.origin.x,
			"y": global_xform.origin.y,
			"z": global_xform.origin.z
		},
		"basis": {
			"x": {"x": global_xform.basis.x.x, "y": global_xform.basis.x.y, "z": global_xform.basis.x.z},
			"y": {"x": global_xform.basis.y.x, "y": global_xform.basis.y.y, "z": global_xform.basis.y.z},
			"z": {"x": global_xform.basis.z.x, "y": global_xform.basis.z.y, "z": global_xform.basis.z.z}
		}
	}
	if node.has_method("get_persistent_id"):
		var cabinet_id := str(node.call("get_persistent_id")).strip_edges()
		if cabinet_id != "":
			item["cabinet_id"] = cabinet_id
	elif node.has_meta("module_cabinet_id"):
		var meta_cabinet_id := str(node.get_meta("module_cabinet_id")).strip_edges()
		if meta_cabinet_id != "":
			item["cabinet_id"] = meta_cabinet_id
	if node.has_method("get_serialized_state"):
		item["custom_state"] = node.call("get_serialized_state")
		var odf_type := _extract_odf_type(item["custom_state"])
		if odf_type >= 0:
			item["odf_type"] = odf_type
			item["type"] = odf_type
	if node.has_meta("build_view_layer"):
		item["build_view_layer"] = int(node.get_meta("build_view_layer"))
	if bool(node.get_meta("cell_line_unit", false)):
		item["cell_line_unit"] = true
		item["floor_cell_x"] = int(node.get_meta("floor_cell_x", 0))
		item["floor_cell_z"] = int(node.get_meta("floor_cell_z", 0))
	return item

func _clear_scene(root: Node, excluded_group: String) -> void:
	for child in root.get_children():
		if _is_serializable_scene_root(child, excluded_group):
			child.queue_free()

func _instantiate_item(item: Dictionary, root: Node) -> void:
	var path = item.get("scene_path", "")
	if path == "":
		return

	var scene = load(path) as PackedScene
	if not scene:
		push_warning("反序列化失败，无法加载场景: %s" % path)
		return

	var new_instance = scene.instantiate()
	if not new_instance:
		push_warning("反序列化失败，无法实例化场景: %s" % path)
		return
	root.add_child(new_instance)
	if not new_instance is Node3D:
		push_warning("反序列化失败，场景根节点不是 Node3D: %s" % path)
		return

	var basis_matrix = _dict_to_basis(item.get("basis", {}))
	var pos = _dict_to_vec3(item.get("position", {}))
	(new_instance as Node3D).global_transform = Transform3D(basis_matrix, pos)
	var cabinet_id := str(item.get("cabinet_id", "")).strip_edges()
	if cabinet_id != "":
		new_instance.set_meta("module_cabinet_id", cabinet_id)
	new_instance.set_meta("build_view_layer", int(item.get("build_view_layer", 0)))
	if bool(item.get("cell_line_unit", false)):
		new_instance.set_meta("cell_line_unit", true)
		new_instance.set_meta("floor_cell_x", int(item.get("floor_cell_x", 0)))
		new_instance.set_meta("floor_cell_z", int(item.get("floor_cell_z", 0)))
	if (item.has("odf_type") or item.has("type")) and item.has("custom_state") and item["custom_state"] is Dictionary:
		var custom_state := (item["custom_state"] as Dictionary).duplicate(true)
		var odf_type := int(item.get("odf_type", item.get("type", 0)))
		custom_state["odf_type"] = odf_type
		custom_state["type"] = odf_type
		if custom_state.has("module_config") and custom_state["module_config"] is Dictionary:
			var module_config := (custom_state["module_config"] as Dictionary).duplicate(true)
			module_config["odf_type"] = odf_type
			module_config["type"] = odf_type
			custom_state["module_config"] = module_config
		item["custom_state"] = custom_state
	if item.has("custom_state") and new_instance.has_method("apply_serialized_state"):
		new_instance.call("apply_serialized_state", item.get("custom_state", {}))

func _is_serializable_scene_root(node: Node, excluded_group: String) -> bool:
	if not node is Node3D:
		return false
	if node.is_queued_for_deletion():
		return false
	if node.is_in_group(excluded_group):
		return false
	if node.scene_file_path == "":
		return false
	return true

func _extract_odf_type(custom_state: Variant) -> int:
	if not custom_state is Dictionary:
		return -1
	var state := custom_state as Dictionary
	if state.has("odf_type") or state.has("type"):
		return int(state.get("odf_type", state.get("type", 0)))
	if state.has("module_config") and state["module_config"] is Dictionary:
		var module_config := state["module_config"] as Dictionary
		if module_config.has("odf_type") or module_config.has("type"):
			return int(module_config.get("odf_type", module_config.get("type", 0)))
	return -1

func _dict_to_vec3(v: Dictionary) -> Vector3:
	return Vector3(
		float(v.get("x", 0.0)),
		float(v.get("y", 0.0)),
		float(v.get("z", 0.0))
	)

func _dict_to_basis(b: Dictionary) -> Basis:
	return Basis(
		_dict_to_vec3(b.get("x", {})),
		_dict_to_vec3(b.get("y", {})),
		_dict_to_vec3(b.get("z", {}))
	)