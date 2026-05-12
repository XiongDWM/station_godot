extends RefCounted

class_name LayoutSerializer

func serialize_scene(root: Node, excluded_group: String = "preview") -> Array:
	var layout_items: Array = []
	for child in root.get_children():
		if child is MeshInstance3D and not child.is_in_group(excluded_group):
			layout_items.append(_serialize_mesh_instance(child))
	return layout_items

func serialize_scene_to_json(root: Node, excluded_group: String = "preview", indent: String = "  ") -> String:
	return JSON.stringify(serialize_scene(root, excluded_group), indent)

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

func _serialize_mesh_instance(node: MeshInstance3D) -> Dictionary:
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
		if child is MeshInstance3D and not child.is_in_group(excluded_group):
			child.queue_free()

func _instantiate_item(item: Dictionary, root: Node) -> void:
	var path = item.get("scene_path", "")
	if path == "" or not ResourceLoader.exists(path):
		return

	var scene = load(path) as PackedScene
	if not scene:
		return

	var new_instance = scene.instantiate()
	root.add_child(new_instance)

	var basis_matrix = _dict_to_basis(item.get("basis", {}))
	var pos = _dict_to_vec3(item.get("position", {}))
	new_instance.transform = Transform3D(basis_matrix, pos)

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