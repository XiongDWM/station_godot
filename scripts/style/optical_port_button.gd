extends Button

const PORT_SHAPE_CIRCLE := 0
const PORT_SHAPE_SQUARE := 1
const PORT_STATUS_EMPTY := 0
const PORT_STATUS_NORMAL := 1
const PORT_STATUS_HIGH_LOSS := 2
const PORT_STATUS_BROKEN_CORE := 3
const PORT_STATUS_FREE_CORE := 4

const BODY_COLOR := Color(0.78, 0.82, 0.82, 1.0)
const BODY_HOVER_COLOR := Color(0.86, 0.9, 0.9, 1.0)
const BODY_PRESSED_COLOR := Color(0.66, 0.7, 0.7, 1.0)
const SOCKET_COLOR := Color(0.015, 0.018, 0.02, 1.0)
const BORDER_COLOR := Color(0.9, 0.93, 0.93, 1.0)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.35)
const IDLE_OVERLAY_COLOR := Color(0.24, 0.57, 0.92, 0.0)
const NORMAL_OVERLAY_COLOR := Color(0.16, 0.72, 0.29, 0.24)
const HIGH_LOSS_OVERLAY_COLOR := Color(0.94, 0.76, 0.18, 0.28)
const BROKEN_CORE_OVERLAY_COLOR := Color(0.9, 0.16, 0.12, 0.28)
const BAD_PORT_OVERLAY_COLOR := Color(0.9, 0.16, 0.12, 0.38)
const BAD_PORT_MARK_COLOR := Color(0.98, 0.96, 0.96, 0.96)

var port_shape := PORT_SHAPE_SQUARE
var port_status := PORT_STATUS_EMPTY
var is_bad_port := false
var is_hovered_bool := false

func _ready() -> void:
	mouse_entered.connect(func() -> void:
		is_hovered_bool = true
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		is_hovered_bool = false
		queue_redraw()
	)

func set_optical_visual(shape: int, status: int, bad_port: bool) -> void:
	port_shape = shape
	port_status = status
	is_bad_port = bad_port
	queue_redraw()

func _draw() -> void:
	if port_shape == PORT_SHAPE_CIRCLE:
		_draw_fc_port()
	else:
		_draw_sc_port()

func _get_body_color() -> Color:
	if button_pressed:
		return BODY_PRESSED_COLOR
	if is_hovered_bool:
		return BODY_HOVER_COLOR
	return BODY_COLOR

func _get_overlay_color() -> Color:
	if is_bad_port:
		return BAD_PORT_OVERLAY_COLOR
	match port_status:
		PORT_STATUS_FREE_CORE:
			return Color(0.24, 0.57, 0.92, 0.22)
		PORT_STATUS_NORMAL:
			return NORMAL_OVERLAY_COLOR
		PORT_STATUS_HIGH_LOSS:
			return HIGH_LOSS_OVERLAY_COLOR
		PORT_STATUS_BROKEN_CORE:
			return BROKEN_CORE_OVERLAY_COLOR
		_:
			return IDLE_OVERLAY_COLOR

func _get_inner_overlay_color() -> Color:
	var overlay := _get_overlay_color()
	overlay.a *= 0.72
	return overlay

func _get_border_color() -> Color:
	return Color(0.9, 0.16, 0.12, 0.95) if is_bad_port else BORDER_COLOR

func _draw_occupied_square_overlay(outer: Rect2, inner: Rect2) -> void:
	if _get_overlay_color().a <= 0.0:
		return
	draw_rect(outer, _get_overlay_color(), true)
	draw_rect(inner, _get_inner_overlay_color(), true)

func _draw_occupied_circle_overlay(center: Vector2, radius: float) -> void:
	if _get_overlay_color().a <= 0.0:
		return
	draw_circle(center, radius, _get_overlay_color())
	draw_circle(center, radius * 0.52, _get_inner_overlay_color())

func _draw_bad_square_mark(outer: Rect2) -> void:
	if not is_bad_port:
		return
	var inset := 4.0
	draw_line(outer.position + Vector2(inset, inset), outer.end - Vector2(inset, inset), BAD_PORT_MARK_COLOR, 2.0)
	draw_line(Vector2(outer.end.x - inset, outer.position.y + inset), Vector2(outer.position.x + inset, outer.end.y - inset), BAD_PORT_MARK_COLOR, 2.0)

func _draw_bad_circle_mark(center: Vector2, radius: float) -> void:
	if not is_bad_port:
		return
	var delta := radius * 0.68
	draw_line(center + Vector2(-delta, -delta), center + Vector2(delta, delta), BAD_PORT_MARK_COLOR, 2.0)
	draw_line(center + Vector2(delta, -delta), center + Vector2(-delta, delta), BAD_PORT_MARK_COLOR, 2.0)

func _draw_sc_port() -> void:
	var inset := 3.0
	var outer := Rect2(Vector2(inset, inset), size - Vector2(inset * 2.0, inset * 2.0))
	var inner := Rect2(outer.position + Vector2(5.0, 5.0), outer.size - Vector2(10.0, 10.0))
	draw_rect(outer.grow(1.0), SHADOW_COLOR, true)
	draw_rect(outer, _get_body_color(), true)
	draw_rect(inner, SOCKET_COLOR, true)
	_draw_occupied_square_overlay(outer, inner)
	draw_rect(outer, _get_border_color(), false, 2.0)
	draw_rect(inner, Color(0.48, 0.52, 0.52, 1.0), false, 1.0)
	draw_line(inner.position + Vector2(2.0, 2.0), inner.position + Vector2(inner.size.x - 2.0, 2.0), Color(1.0, 1.0, 1.0, 0.28), 1.0)
	var key_slot := Rect2(Vector2(outer.position.x + outer.size.x * 0.5 - 2.0, outer.position.y + 1.0), Vector2(4.0, 3.0))
	draw_rect(key_slot, Color(0.32, 0.35, 0.35, 1.0), true)
	_draw_bad_square_mark(outer)

func _draw_fc_port() -> void:
	var inset := 3.0
	var outer := Rect2(Vector2(inset, inset), size - Vector2(inset * 2.0, inset * 2.0))
	var center := outer.get_center()
	var collar_radius := minf(outer.size.x, outer.size.y) * 0.31
	var socket_radius := collar_radius * 0.52
	var core_radius := socket_radius * 0.5
	var dot_margin := Vector2(2.8, 2.8)
	var top_left_dot_center := outer.position + dot_margin
	var bottom_right_dot_center := outer.end - dot_margin

	draw_rect(outer.grow(1.0), SHADOW_COLOR, true)
	draw_rect(outer, _get_body_color(), true)
	draw_circle(center + Vector2(1.0, 1.3), collar_radius, SHADOW_COLOR)
	draw_circle(center, collar_radius, Color(0.72, 0.75, 0.76, 1.0))
	draw_circle(center, collar_radius * 0.78, Color(0.44, 0.47, 0.48, 1.0))
	draw_circle(center, socket_radius, SOCKET_COLOR)

	if _get_overlay_color().a > 0.0:
		draw_rect(outer, _get_overlay_color(), true)
		draw_circle(center, socket_radius * 0.96, _get_inner_overlay_color())

	draw_rect(outer, _get_border_color(), false, 2.0)
	draw_arc(center, collar_radius, 0.0, TAU, 48, _get_border_color(), 1.4, true)
	draw_arc(center, socket_radius, 0.0, TAU, 40, Color(0.48, 0.52, 0.52, 1.0), 1.0, true)
	draw_circle(center, core_radius, Color(0.02, 0.025, 0.028, 1.0))
	draw_line(center + Vector2(-core_radius * 0.42, core_radius * 0.72), center + Vector2(core_radius * 0.42, core_radius * 0.72), Color(1.0, 1.0, 1.0, 0.14), 1.0)

	_draw_fc_mount_hole(top_left_dot_center)
	_draw_fc_mount_hole(bottom_right_dot_center)
	_draw_bad_square_mark(outer)

func _draw_fc_mount_hole(center: Vector2) -> void:
	draw_circle(center + Vector2(0.22, 0.3), 1.9, Color(0.0, 0.0, 0.0, 0.16))
	draw_circle(center, 1.65, Color(0.04, 0.045, 0.05, 1.0))
	draw_circle(center, 0.7, Color(0.16, 0.18, 0.19, 0.42))