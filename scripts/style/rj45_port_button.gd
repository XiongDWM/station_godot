extends Button

const PORT_STATUS_EMPTY := 0
const PORT_STATUS_NORMAL := 1
const PORT_STATUS_HIGH_LOSS := 2
const PORT_STATUS_BROKEN_CORE := 3
const PORT_STATUS_FREE_CORE := 4

const PORT_SOCKET_BG_COLOR := Color(0.015, 0.018, 0.02, 1.0)
const PORT_SOCKET_HOVER_BG_COLOR := Color(0.045, 0.055, 0.06, 1.0)
const PORT_SOCKET_PRESSED_BG_COLOR := Color(0.0, 0.01, 0.014, 1.0)
const PORT_SOCKET_BORDER_COLOR := Color(0.82, 0.86, 0.86, 0.95)
const IDLE_OVERLAY_COLOR := Color(0.24, 0.57, 0.92, 0.0)
const NORMAL_OVERLAY_COLOR := Color(0.16, 0.72, 0.29, 0.24)
const HIGH_LOSS_OVERLAY_COLOR := Color(0.94, 0.76, 0.18, 0.28)
const BROKEN_CORE_OVERLAY_COLOR := Color(0.9, 0.16, 0.12, 0.28)
const BAD_PORT_OVERLAY_COLOR := Color(0.9, 0.16, 0.12, 0.38)
const BAD_PORT_MARK_COLOR := Color(0.98, 0.96, 0.96, 0.96)

var is_top_row := true
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

func set_port_visual(top_row: bool, status: int, bad_port: bool) -> void:
	is_top_row = top_row
	port_status = status
	is_bad_port = bad_port
	queue_redraw()

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

func _get_border_color() -> Color:
	return Color(0.9, 0.16, 0.12, 0.95) if is_bad_port else PORT_SOCKET_BORDER_COLOR

func _draw_bad_mark(width: float, height: float) -> void:
	if not is_bad_port:
		return
	var inset := 4.0
	draw_line(Vector2(inset, inset), Vector2(width - inset, height - inset), BAD_PORT_MARK_COLOR, 2.0)
	draw_line(Vector2(width - inset, inset), Vector2(inset, height - inset), BAD_PORT_MARK_COLOR, 2.0)

func _draw() -> void:
	var width := size.x
	var height := size.y
	var tab_height := minf(4.0, height * 0.32)
	var tab_side := floorf(width * 0.32)
	var socket_color := PORT_SOCKET_BG_COLOR
	if button_pressed:
		socket_color = PORT_SOCKET_PRESSED_BG_COLOR
	elif is_hovered_bool:
		socket_color = PORT_SOCKET_HOVER_BG_COLOR
	var points := PackedVector2Array()
	if is_top_row:
		points.append(Vector2(0, tab_height))
		points.append(Vector2(tab_side, tab_height))
		points.append(Vector2(tab_side, 0))
		points.append(Vector2(width - tab_side, 0))
		points.append(Vector2(width - tab_side, tab_height))
		points.append(Vector2(width, tab_height))
		points.append(Vector2(width, height))
		points.append(Vector2(0, height))
	else:
		points.append(Vector2(0, 0))
		points.append(Vector2(width, 0))
		points.append(Vector2(width, height - tab_height))
		points.append(Vector2(width - tab_side, height - tab_height))
		points.append(Vector2(width - tab_side, height))
		points.append(Vector2(tab_side, height))
		points.append(Vector2(tab_side, height - tab_height))
		points.append(Vector2(0, height - tab_height))
	draw_colored_polygon(points, socket_color)
	if _get_overlay_color().a > 0.0:
		draw_colored_polygon(points, _get_overlay_color())
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, _get_border_color(), 2.0, true)
	var lip_y := tab_height if is_top_row else height - tab_height
	draw_line(Vector2(2, lip_y), Vector2(width - 2, lip_y), Color(0.88, 0.9, 0.9, 0.45), 1.0, true)
	_draw_bad_mark(width, height)