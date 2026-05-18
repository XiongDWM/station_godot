extends PanelContainer

const INSERT_LINE_COLOR := Color(0.15, 0.55, 0.95, 0.95)
const INSERT_LINE_THICKNESS := 4
const SLOT_OUTLINE_COLOR := Color(0.92, 0.26, 0.26, 0.95)
const SLOT_OUTLINE_THICKNESS := 2.0
const SLOT_OUTLINE_DASH := 10.0
const SLOT_OUTLINE_GAP := 6.0

var controller: Control
var face_index := 0
var slot_index := 0
var card_index := -1
var slot_layout := 0
var drag_enabled := true
var draw_dashed_outline := true
var insert_indicator: ColorRect

func _ready() -> void:
	insert_indicator = ColorRect.new()
	insert_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	insert_indicator.color = INSERT_LINE_COLOR
	insert_indicator.visible = false
	add_child(insert_indicator)
	move_child(insert_indicator, get_child_count() - 1)
	queue_redraw()

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not drag_enabled:
		return null
	if controller and controller.has_method("is_card_locked") and controller.call("is_card_locked", face_index, slot_index, card_index):
		return null
	if controller and controller.has_method("build_card_drag_payload"):
		var payload: Variant = controller.call("build_card_drag_payload", face_index, slot_index, card_index, slot_layout)
		var preview: Control = duplicate() as Control
		if preview:
			preview.modulate = Color(1, 1, 1, 0.75)
			set_drag_preview(preview)
		return payload
	return null

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not drag_enabled:
		_clear_insert_indicator()
		return false
	var can_drop: bool = controller and controller.has_method("can_drop_card_payload") and controller.call("can_drop_card_payload", data, face_index, slot_index, slot_layout)
	if can_drop:
		_update_insert_indicator(at_position)
	else:
		_clear_insert_indicator()
	return can_drop

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if controller and controller.has_method("drop_card_payload"):
		controller.call("drop_card_payload", data, slot_index, card_index, slot_layout, _is_before_position(at_position))
	_clear_insert_indicator()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_clear_insert_indicator()
	elif what == NOTIFICATION_RESIZED:
		queue_redraw()

func _exit_tree() -> void:
	_clear_insert_indicator()

func _update_insert_indicator(at_position: Vector2) -> void:
	if not insert_indicator:
		return
	insert_indicator.visible = true
	if slot_layout == 0:
		insert_indicator.anchor_left = 0.0
		insert_indicator.anchor_right = 1.0
		insert_indicator.offset_left = 0.0
		insert_indicator.offset_right = 0.0
		if _is_before_position(at_position):
			insert_indicator.anchor_top = 0.0
			insert_indicator.anchor_bottom = 0.0
			insert_indicator.offset_top = 0.0
			insert_indicator.offset_bottom = INSERT_LINE_THICKNESS
		else:
			insert_indicator.anchor_top = 1.0
			insert_indicator.anchor_bottom = 1.0
			insert_indicator.offset_top = -INSERT_LINE_THICKNESS
			insert_indicator.offset_bottom = 0.0
	else:
		insert_indicator.anchor_top = 0.0
		insert_indicator.anchor_bottom = 1.0
		insert_indicator.offset_top = 0.0
		insert_indicator.offset_bottom = 0.0
		if _is_before_position(at_position):
			insert_indicator.anchor_left = 0.0
			insert_indicator.anchor_right = 0.0
			insert_indicator.offset_left = 0.0
			insert_indicator.offset_right = INSERT_LINE_THICKNESS
		else:
			insert_indicator.anchor_left = 1.0
			insert_indicator.anchor_right = 1.0
			insert_indicator.offset_left = -INSERT_LINE_THICKNESS
			insert_indicator.offset_right = 0.0

func _clear_insert_indicator() -> void:
	if insert_indicator:
		insert_indicator.visible = false

func _is_before_position(at_position: Vector2) -> bool:
	return at_position.y < size.y * 0.5 if slot_layout == 0 else at_position.x < size.x * 0.5

func _draw() -> void:
	if not draw_dashed_outline:
		return
	var inset: float = SLOT_OUTLINE_THICKNESS * 0.5
	var rect: Rect2 = Rect2(Vector2(inset, inset), size - Vector2(inset * 2.0, inset * 2.0))
	_draw_dashed_edge(rect.position, Vector2(rect.end.x, rect.position.y))
	_draw_dashed_edge(Vector2(rect.end.x, rect.position.y), rect.end)
	_draw_dashed_edge(rect.end, Vector2(rect.position.x, rect.end.y))
	_draw_dashed_edge(Vector2(rect.position.x, rect.end.y), rect.position)

func _draw_dashed_edge(from: Vector2, to: Vector2) -> void:
	var delta: Vector2 = to - from
	var edge_length: float = delta.length()
	if edge_length <= 0.0:
		return
	var direction: Vector2 = delta / edge_length
	var offset: float = 0.0
	while offset < edge_length:
		var segment_end: float = minf(offset + SLOT_OUTLINE_DASH, edge_length)
		draw_line(from + direction * offset, from + direction * segment_end, SLOT_OUTLINE_COLOR, SLOT_OUTLINE_THICKNESS)
		offset += SLOT_OUTLINE_DASH + SLOT_OUTLINE_GAP
