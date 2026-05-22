extends Button

const PORT_SOCKET_BG_COLOR := Color(0.015, 0.018, 0.02, 1.0)
const PORT_SOCKET_HOVER_BG_COLOR := Color(0.045, 0.055, 0.06, 1.0)
const PORT_SOCKET_PRESSED_BG_COLOR := Color(0.0, 0.01, 0.014, 1.0)
const PORT_SOCKET_BORDER_COLOR := Color(0.82, 0.86, 0.86, 0.95)
const PORT_SOCKET_ACTIVE_BORDER_COLOR := Color(0.9, 0.16, 0.12, 1.0)

var is_top_row := true
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

func set_port_visual(top_row: bool, occupied: bool) -> void:
	is_top_row = top_row
	is_occupied = occupied
	queue_redraw()

func _draw() -> void:
	var width := size.x
	var height := size.y
	var tab_height := minf(4.0, height * 0.32)
	var tab_side := floorf(width * 0.32)
	var socket_color := PORT_SOCKET_BG_COLOR
	if button_pressed:
		socket_color = PORT_SOCKET_PRESSED_BG_COLOR
	elif is_hovered:
		socket_color = PORT_SOCKET_HOVER_BG_COLOR
	var border_color := PORT_SOCKET_ACTIVE_BORDER_COLOR if is_occupied else PORT_SOCKET_BORDER_COLOR
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
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, border_color, 2.0, true)
	var lip_y := tab_height if is_top_row else height - tab_height
	draw_line(Vector2(2, lip_y), Vector2(width - 2, lip_y), Color(0.88, 0.9, 0.9, 0.45), 1.0, true)