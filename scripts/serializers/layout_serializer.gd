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

func _serialize_node3d(node: Node3D) -> Dictionary:
	var global_xform = node.global_transform
	return {
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

func _is_serializable_scene_root(node: Node, excluded_group: String) -> bool:
	if not node is Node3D:
		return false
	if node.is_in_group(excluded_group):
		return false
	if node.scene_file_path == "":
		return false
	return true

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