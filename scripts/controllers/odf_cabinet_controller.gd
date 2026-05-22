extends StaticBody3D

const OPEN_NAME_HINTS := ["open", "door", "kai"]
const CLOSE_NAME_HINTS := ["close", "guan"]
const FALLBACK_MODEL_PATH := NodePath("object_odf")
const OPEN_ANIMATION_SCENE := preload("res://assets/models/jigui/CLOSE.fbx")
const CLOSE_ANIMATION_SCENE := preload("res://assets/models/jigui/OPEN.fbx")
const EXTERNAL_OPEN_ANIMATION_NAME := "open"
const EXTERNAL_CLOSE_ANIMATION_NAME := "close"
const FALLBACK_OPEN_ROTATION := Vector3(0.0, deg_to_rad(-80.0), 0.0)
const FALLBACK_ANIMATION_TIME := 0.35
const CABINET_ID_META_KEY := "module_cabinet_id"
const MODULE_CONFIG_META_KEY := "module_config"
const DEFAULT_ODF_TYPE := 0

var is_open := false
var animation_player: AnimationPlayer
var open_animation := "" 
var close_animation := ""
var pending_panel: Panel
var fallback_model: Node3D
var fallback_closed_rotation := Vector3.ZERO
var fallback_tween: Tween

func _ready() -> void:
	ensure_persistent_id()
	fallback_model = get_node_or_null(FALLBACK_MODEL_PATH) as Node3D
	if fallback_model:
		fallback_closed_rotation = fallback_model.rotation
	animation_player = _find_animation_player(self)
	if not animation_player:
		animation_player = AnimationPlayer.new()
		animation_player.name = "AnimationPlayer"
		(fallback_model if fallback_model else self).add_child(animation_player)
	_load_external_animation(OPEN_ANIMATION_SCENE, EXTERNAL_OPEN_ANIMATION_NAME, OPEN_NAME_HINTS)
	_load_external_animation(CLOSE_ANIMATION_SCENE, EXTERNAL_CLOSE_ANIMATION_NAME, CLOSE_NAME_HINTS)
	_detect_animations()
	_reset_to_closed_pose()

func ensure_persistent_id() -> String:
	if has_meta(CABINET_ID_META_KEY):
		return str(get_meta(CABINET_ID_META_KEY))
	var cabinet_id := _generate_sortable_cabinet_id()
	set_meta(CABINET_ID_META_KEY, cabinet_id)
	return cabinet_id

func get_persistent_id() -> String:
	return ensure_persistent_id()

func get_serialized_state() -> Dictionary:
	var state := {
		"cabinet_id": ensure_persistent_id(),
		"odf_type": DEFAULT_ODF_TYPE,
		"type": DEFAULT_ODF_TYPE,
	}
	if has_meta(MODULE_CONFIG_META_KEY):
		var module_config: Variant = get_meta(MODULE_CONFIG_META_KEY)
		if module_config is Dictionary:
			var serialized_config: Dictionary = (module_config as Dictionary).duplicate(true)
			var odf_type := _get_config_odf_type(serialized_config, DEFAULT_ODF_TYPE)
			serialized_config["odf_type"] = odf_type
			serialized_config["type"] = odf_type
			state["odf_type"] = odf_type
			state["type"] = odf_type
			state[MODULE_CONFIG_META_KEY] = serialized_config
	return state

func apply_serialized_state(state: Dictionary) -> void:
	var cabinet_id := str(state.get("cabinet_id", "")).strip_edges()
	if cabinet_id != "":
		set_meta(CABINET_ID_META_KEY, cabinet_id)
	if state.has(MODULE_CONFIG_META_KEY):
		var module_config: Variant = state.get(MODULE_CONFIG_META_KEY, {})
		if module_config is Dictionary:
			var restored_config: Dictionary = (module_config as Dictionary).duplicate(true)
			var odf_type := _get_config_odf_type(restored_config, int(state.get("odf_type", state.get("type", DEFAULT_ODF_TYPE))))
			restored_config["odf_type"] = odf_type
			restored_config["type"] = odf_type
			set_meta(MODULE_CONFIG_META_KEY, restored_config)
	elif state.has("odf_type") or state.has("type"):
		var odf_type := int(state.get("odf_type", state.get("type", DEFAULT_ODF_TYPE)))
		set_meta(MODULE_CONFIG_META_KEY, {"odf_type": odf_type, "type": odf_type})

func _get_config_odf_type(config: Dictionary, fallback_type: int) -> int:
	return int(config.get("odf_type", config.get("type", fallback_type)))

func _generate_sortable_cabinet_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var timestamp_ms := int(Time.get_unix_time_from_system() * 1000.0)
	return "cab_%013d_%08x%08x" % [timestamp_ms, rng.randi(), rng.randi()]

func open_with_panel(module_panel: Panel) -> void:
	pending_panel = module_panel
	if is_open:
		_show_pending_panel()
		return
	is_open = true
	if animation_player and open_animation != "":
		animation_player.play(open_animation)
		var finished_animation: StringName = await animation_player.animation_finished
		if not is_open or String(finished_animation) != open_animation:
			pending_panel = null
			return
	else:
		await _play_fallback_tween(true)
		if not is_open:
			pending_panel = null
			return
	_show_pending_panel()

func close_cabinet() -> void:
	if not is_open:
		return
	is_open = false
	pending_panel = null
	if animation_player and close_animation != "":
		animation_player.play(close_animation)
	elif animation_player and open_animation != "":
		animation_player.play_backwards(open_animation)
	else:
		_play_fallback_tween(false)

func _show_pending_panel() -> void:
	if not pending_panel:
		return
	if pending_panel.has_method("open_for_target"):
		pending_panel.call("open_for_target", self)
	pending_panel.visible = true
	pending_panel = null

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _load_external_animation(scene: PackedScene, target_name: String, hints: Array) -> void:
	if not animation_player:
		return
	if not scene:
		return
	var instance := scene.instantiate()
	var source_player := _find_animation_player(instance)
	if not source_player:
		instance.free()
		return
	var animations := source_player.get_animation_list()
	if animations.is_empty():
		instance.free()
		return
	var source_name := _find_animation_by_hints(animations, hints)
	if source_name == "":
		source_name = animations[0]
	var source_animation := source_player.get_animation(source_name)
	var library := animation_player.get_animation_library("")
	if not library:
		library = AnimationLibrary.new()
		animation_player.add_animation_library("", library)
	if library.has_animation(target_name):
		library.remove_animation(target_name)
	library.add_animation(target_name, source_animation.duplicate(true))
	instance.free()

func _detect_animations() -> void:
	if not animation_player:
		return
	var animations := animation_player.get_animation_list()
	if animations.is_empty():
		return
	open_animation = EXTERNAL_OPEN_ANIMATION_NAME if animations.has(EXTERNAL_OPEN_ANIMATION_NAME) else _find_animation_by_hints(animations, OPEN_NAME_HINTS)
	close_animation = EXTERNAL_CLOSE_ANIMATION_NAME if animations.has(EXTERNAL_CLOSE_ANIMATION_NAME) else _find_animation_by_hints(animations, CLOSE_NAME_HINTS)
	if open_animation == "":
		open_animation = animations[0]

func _find_animation_by_hints(animations: PackedStringArray, hints: Array) -> String:
	for animation_name in animations:
		var lower_name := String(animation_name).to_lower()
		for hint in hints:
			if lower_name.contains(String(hint).to_lower()):
				return animation_name
	return ""

func _reset_to_closed_pose() -> void:
	if animation_player and close_animation != "":
		var close_clip := animation_player.get_animation(close_animation)
		animation_player.play(close_animation)
		animation_player.seek(close_clip.length if close_clip else 0.0, true)
		animation_player.stop(false)
	elif animation_player and open_animation != "":
		animation_player.play(open_animation)
		animation_player.seek(0.0, true)
		animation_player.stop(false)
	elif fallback_model:
		fallback_model.rotation = fallback_closed_rotation
	is_open = false

func _play_fallback_tween(open: bool) -> Signal:
	if fallback_tween:
		fallback_tween.kill()
	fallback_tween = create_tween()
	if fallback_model:
		var target_rotation := fallback_closed_rotation + (FALLBACK_OPEN_ROTATION if open else Vector3.ZERO)
		fallback_tween.tween_property(fallback_model, "rotation", target_rotation, FALLBACK_ANIMATION_TIME)
	else:
		fallback_tween.tween_interval(0.01)
	return fallback_tween.finished
