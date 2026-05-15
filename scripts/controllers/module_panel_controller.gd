extends Panel

const PORT_CELL_SIZE := 24.0
const PORT_GAP := 4.0

@onready var row_input: SpinBox = $MarginContainer/RootVBox/ConfigPanel/ConfigVbox/InputRow/RowGroup/RowInput
@onready var col_input: SpinBox = $MarginContainer/RootVBox/ConfigPanel/ConfigVbox/InputRow/ColGroup/ColInput
@onready var faces_input: SpinBox = $MarginContainer/RootVBox/ConfigPanel/ConfigVbox/InputRow/FacesGroup/FacesInput
@onready var prev_face_button: Button = $MarginContainer/RootVBox/ToolBarRow/PrevFaceButton
@onready var next_face_button: Button = $MarginContainer/RootVBox/ToolBarRow/NextFaceButton
@onready var face_page_label: Label = $MarginContainer/RootVBox/ToolBarRow/FacePageLabel
@onready var regenerate_button: Button = $MarginContainer/RootVBox/ToolBarRow/RegenerateButton
@onready var summary_label: Label = $MarginContainer/RootVBox/ToolBarRow/SummaryLabel
@onready var close_button: Button = $MarginContainer/RootVBox/HeaderRow/CloseButton
@onready var face_title: Label = $MarginContainer/RootVBox/PreviewPanel/PreviewVbox/FaceTitle
@onready var port_grid: GridContainer = $MarginContainer/RootVBox/PreviewPanel/PreviewVbox/PortScroll/PortGrid
@onready var status_label: Label = $MarginContainer/RootVBox/FooterRow/StatusLabel

var current_face_index := 0
var face_port_states: Array = []

func _ready() -> void:
	if row_input:
		row_input.value_changed.connect(_on_dimensions_changed)
	if col_input:
		col_input.value_changed.connect(_on_dimensions_changed)
	if faces_input:
		faces_input.value_changed.connect(_on_dimensions_changed)
	if prev_face_button:
		prev_face_button.pressed.connect(_on_prev_face_pressed)
	if next_face_button:
		next_face_button.pressed.connect(_on_next_face_pressed)
	if regenerate_button:
		regenerate_button.pressed.connect(_rebuild_port_faces)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	visibility_changed.connect(_refresh_port_view)
	_rebuild_port_faces()

func _on_dimensions_changed(_value: float) -> void:
	_rebuild_port_faces()

func _on_prev_face_pressed() -> void:
	if current_face_index <= 0:
		return
	current_face_index -= 1
	_refresh_port_view()

func _on_next_face_pressed() -> void:
	var total_faces := _get_total_faces()
	if current_face_index >= total_faces - 1:
		return
	current_face_index += 1
	_refresh_port_view()

func _on_close_pressed() -> void:
	visible = false

func _rebuild_port_faces() -> void:
	var total_faces := _get_total_faces()
	var port_count := _get_row_count() * _get_col_count()
	face_port_states.clear()
	for _face_index in range(total_faces):
		var face_ports: Array = []
		face_ports.resize(port_count)
		for port_index in range(port_count):
			face_ports[port_index] = false
		face_port_states.append(face_ports)
	current_face_index = clamp(current_face_index, 0, total_faces - 1)
	_refresh_port_view()

func _refresh_port_view() -> void:
	var total_faces := _get_total_faces()
	current_face_index = clamp(current_face_index, 0, total_faces - 1)

	if face_page_label:
		face_page_label.text = "第%d面" % (current_face_index + 1)
	if face_title:
		face_title.text = "第%d面端口预览" % (current_face_index + 1)

	if prev_face_button:
		prev_face_button.disabled = total_faces <= 1 or current_face_index == 0

	if next_face_button:
		next_face_button.disabled = total_faces <= 1 or current_face_index >= total_faces - 1

	_render_current_face()
	_refresh_summary()

func _get_total_faces() -> int:
	if not faces_input:
		return 1
	return max(1, int(faces_input.value))

func _get_row_count() -> int:
	if not row_input:
		return 1
	return max(1, int(row_input.value))

func _get_col_count() -> int:
	if not col_input:
		return 1
	return max(1, int(col_input.value))

func _render_current_face() -> void:
	if not port_grid:
		return

	for child in port_grid.get_children():
		child.queue_free()

	var rows := _get_row_count()
	var cols := _get_col_count()
	var total_ports := rows * cols
	port_grid.columns = cols
	port_grid.custom_minimum_size = Vector2(
		cols * PORT_CELL_SIZE + max(0, cols - 1) * PORT_GAP,
		rows * PORT_CELL_SIZE + max(0, rows - 1) * PORT_GAP
	)

	if face_port_states.is_empty():
		return

	var current_face_ports: Array = face_port_states[current_face_index]
	for port_index in range(total_ports):
		var port_button := Button.new()
		port_button.custom_minimum_size = Vector2(PORT_CELL_SIZE, PORT_CELL_SIZE)
		port_button.flat = true
		port_button.toggle_mode = true
		port_button.focus_mode = Control.FOCUS_NONE
		port_button.button_pressed = bool(current_face_ports[port_index])
		_update_port_button(port_button, port_index)
		port_button.toggled.connect(_on_port_toggled.bind(port_index, port_button))
		port_grid.add_child(port_button)

func _on_port_toggled(pressed: bool, port_index: int, port_button: Button) -> void:
	if face_port_states.is_empty():
		return
	face_port_states[current_face_index][port_index] = pressed
	_update_port_button(port_button, port_index)
	_refresh_summary()

func _update_port_button(port_button: Button, port_index: int) -> void:
	var cols := _get_col_count()
	var row_number := int(floor(float(port_index) / float(cols))) + 1
	var col_number := int(port_index % cols) + 1
	var is_occupied := port_button.button_pressed
	var port_color := Color(0.85, 0.22, 0.22, 1.0) if is_occupied else Color(0.16, 0.72, 0.29, 1.0)
	port_button.text = "●"
	port_button.add_theme_color_override("font_color", port_color)
	port_button.add_theme_color_override("font_focus_color", port_color)
	port_button.add_theme_color_override("font_hover_color", port_color)
	port_button.add_theme_color_override("font_hover_pressed_color", port_color)
	port_button.add_theme_color_override("font_pressed_color", port_color)
	port_button.tooltip_text = "%s | Face %d, Row %d, Col %d" % ["已占用" if is_occupied else "空闲", current_face_index + 1, row_number, col_number]

func _refresh_summary() -> void:
	var rows := _get_row_count()
	var cols := _get_col_count()
	var total_faces := _get_total_faces()
	var ports_per_face := rows * cols
	var occupied_count := _get_current_face_occupied_count()

	if summary_label:
		summary_label.text = "%d x %d x %d" % [rows, cols, total_faces]

	if status_label:
		status_label.text = "当前面占用 %d/%d 个端口" % [occupied_count, ports_per_face]

func _get_current_face_occupied_count() -> int:
	if face_port_states.is_empty():
		return 0
	var occupied_count := 0
	for occupied in face_port_states[current_face_index]:
		if bool(occupied):
			occupied_count += 1
	return occupied_count