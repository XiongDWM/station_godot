extends Button

const PORT_SHAPE_CIRCLE := 0
const PORT_SHAPE_SQUARE := 1

const BODY_COLOR := Color(0.78, 0.82, 0.82, 1.0)
const BODY_HOVER_COLOR := Color(0.86, 0.9, 0.9, 1.0)
const BODY_PRESSED_COLOR := Color(0.66, 0.7, 0.7, 1.0)
const SOCKET_COLOR := Color(0.015, 0.018, 0.02, 1.0)
const BORDER_COLOR := Color(0.9, 0.93, 0.93, 1.0)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.35)
const OCCUPIED_COLOR := Color(0.9, 0.16, 0.12, 1.0)

var port_shape := PORT_SHAPE_SQUARE
var is_occupied := false
var is_hovered := false

func _ready() -> void:
	mouse_entered.connect(func() -> void:
		is_hovered = true
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		is_hovered = false
		queue_redraw()
	)

func set_optical_visual(shape: int, occupied: bool) -> void:
	port_shape = shape
	is_occupied = occupied
	queue_redraw()

func _draw() -> void:
	if port_shape == PORT_SHAPE_CIRCLE:
		_draw_fc_port()
	else:
		_draw_sc_port()

func _get_body_color() -> Color:
	if button_pressed:
		return BODY_PRESSED_COLOR
	if is_hovered:
		return BODY_HOVER_COLOR
	return BODY_COLOR

func _draw_sc_port() -> void:
	var inset := 3.0
	var outer := Rect2(Vector2(inset, inset), size - Vector2(inset * 2.0, inset * 2.0))
	var inner := Rect2(outer.position + Vector2(5.0, 5.0), outer.size - Vector2(10.0, 10.0))
	draw_rect(outer.grow(1.0), SHADOW_COLOR, true)
	draw_rect(outer, _get_body_color(), true)
	draw_rect(outer, OCCUPIED_COLOR if is_occupied else BORDER_COLOR, false, 2.0)
	draw_rect(inner, SOCKET_COLOR, true)
	draw_rect(inner, Color(0.48, 0.52, 0.52, 1.0), false, 1.0)
	draw_line(inner.position + Vector2(2.0, 2.0), inner.position + Vector2(inner.size.x - 2.0, 2.0), Color(1.0, 1.0, 1.0, 0.28), 1.0)
	var key_slot := Rect2(Vector2(outer.position.x + outer.size.x * 0.5 - 2.0, outer.position.y + 1.0), Vector2(4.0, 3.0))
	draw_rect(key_slot, Color(0.32, 0.35, 0.35, 1.0), true)

func _draw_fc_port() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.38
	draw_circle(center + Vector2(1.0, 2.0), radius, SHADOW_COLOR)
	draw_circle(center, radius, _get_body_color())
	draw_arc(center, radius, 0.0, TAU, 48, OCCUPIED_COLOR if is_occupied else BORDER_COLOR, 2.0, true)
	draw_circle(center, radius * 0.52, SOCKET_COLOR)
	draw_arc(center, radius * 0.52, 0.0, TAU, 40, Color(0.48, 0.52, 0.52, 1.0), 1.0, true)
	draw_circle(center, radius * 0.22, Color(0.02, 0.025, 0.028, 1.0))
	draw_circle(center + Vector2(-radius * 0.58, 0.0), 1.2, Color(0.45, 0.48, 0.48, 1.0))
	draw_circle(center + Vector2(radius * 0.58, 0.0), 1.2, Color(0.45, 0.48, 0.48, 1.0))