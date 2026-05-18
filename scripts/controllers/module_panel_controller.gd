extends Panel

const SLOT_GROUP_SCRIPT := preload("res://scripts/controllers/module_slot_group.gd")
const LOCK_CLOSED_ICON := preload("res://assets/icons/lock_closed.svg")
const LOCK_OPEN_ICON := preload("res://assets/icons/lock_open.svg")
const CARD_ACTION_ADD_ICON := preload("res://assets/icons/card_action_add.svg")
const CARD_ACTION_EDIT_ICON := preload("res://assets/icons/card_action_edit.svg")

const PORT_SHAPE_CIRCLE := 0
const PORT_SHAPE_SQUARE := 1
const SLOT_LAYOUT_HORIZONTAL := 0
const SLOT_LAYOUT_VERTICAL := 1

const SLOT_DROP_LAYOUT := SLOT_LAYOUT_HORIZONTAL
const CARD_MENU_CLEAR := -1
const CARD_MENU_PORT_6 := 6
const CARD_MENU_PORT_8 := 8
const CARD_MENU_PORT_12 := 12

const CARD_PORT_SIZE := 14
const CARD_PORT_GAP := 2
const CARD_PADDING := 8
const CARD_GAP := 8
const CARD_BASE_WIDTH := 78
const CARD_BASE_HEIGHT := 62
const SLOT_PADDING := 10
const SLOT_GAP := 8
const CARD_LOCK_BUTTON_SIZE := 22
const CARD_LOCK_GAP := 4
const CARD_ACTION_BUTTON_SIZE := 22
const SLOT_BACKGROUND_COLOR := Color(0, 0, 0, 0)
const CARD_BACKGROUND_COLOR := Color(0.73, 0.74, 0.76, 0.88)
const CARD_BORDER_COLOR := Color(0.57, 0.59, 0.62, 1.0)
const CARD_ACTION_BG_COLOR := Color(1, 1, 1, 0.96)
const CARD_ACTION_BORDER_COLOR := Color(0.77, 0.79, 0.82, 1.0)
const CARD_PLACEHOLDER_PORT_COLOR := Color(1, 1, 1, 0)

@onready var row_input: SpinBox = $MarginContainer/RootVBox/ConfigPanel/ConfigVbox/InputRow/RowGroup/RowInput
@onready var col_input: SpinBox = $MarginContainer/RootVBox/ConfigPanel/ConfigVbox/InputRow/ColGroup/ColInput
@onready var faces_input: SpinBox = $MarginContainer/RootVBox/ConfigPanel/ConfigVbox/InputRow/FacesGroup/FacesInput
@onready var shape_input: OptionButton = $MarginContainer/RootVBox/ConfigPanel/ConfigVbox/EnumRow/ShapeGroup/ShapeInput
@onready var slot_layout_input: OptionButton = $MarginContainer/RootVBox/ConfigPanel/ConfigVbox/EnumRow/SlotLayoutGroup/SlotLayoutInput
@onready var prev_face_button: Button = $MarginContainer/RootVBox/ToolBarRow/PrevFaceButton
@onready var next_face_button: Button = $MarginContainer/RootVBox/ToolBarRow/NextFaceButton
@onready var face_page_label: Label = $MarginContainer/RootVBox/ToolBarRow/FacePageLabel
@onready var regenerate_button: Button = $MarginContainer/RootVBox/ToolBarRow/RegenerateButton
@onready var summary_label: Label = $MarginContainer/RootVBox/ToolBarRow/SummaryLabel
@onready var close_button: Button = $MarginContainer/RootVBox/HeaderRow/CloseButton
@onready var face_title: Label = $MarginContainer/RootVBox/PreviewPanel/PreviewVbox/FaceTitle
@onready var port_grid: VBoxContainer = $MarginContainer/RootVBox/PreviewPanel/PreviewVbox/PortScroll/PortGrid
@onready var status_label: Label = $MarginContainer/RootVBox/FooterRow/StatusLabel
@onready var apply_button: Button = $MarginContainer/RootVBox/FooterRow/ApplyButton

var current_face_index := 0
var face_slot_cards: Array = []
var face_card_locks: Array = []
var current_target: Node3D
var cabinet_configs: Dictionary = {}
var is_loading_target_config := false
var card_context_menu: PopupMenu
var pending_card_context: Dictionary = {}

func _ready() -> void:
	_setup_option_inputs()
	_setup_card_context_menu()
	if row_input:
		row_input.value_changed.connect(_on_dimensions_changed)
	if col_input:
		col_input.value_changed.connect(_on_dimensions_changed)
	if faces_input:
		faces_input.value_changed.connect(_on_dimensions_changed)
	if shape_input:
		shape_input.item_selected.connect(_on_visual_option_changed)
	if slot_layout_input:
		slot_layout_input.item_selected.connect(_on_visual_option_changed)
	if prev_face_button:
		prev_face_button.pressed.connect(_on_prev_face_pressed)
	if next_face_button:
		next_face_button.pressed.connect(_on_next_face_pressed)
	if regenerate_button:
		regenerate_button.pressed.connect(_rebuild_slot_faces)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if apply_button:
		apply_button.pressed.connect(_on_apply_pressed)
	visibility_changed.connect(_refresh_port_view)
	_rebuild_slot_faces()

func _setup_option_inputs() -> void:
	if shape_input and shape_input.item_count == 0:
		shape_input.add_item("圆形", PORT_SHAPE_CIRCLE)
		shape_input.add_item("方形", PORT_SHAPE_SQUARE)
		shape_input.select(PORT_SHAPE_CIRCLE)
	if slot_layout_input and slot_layout_input.item_count == 0:
		slot_layout_input.add_item("横向插卡", SLOT_LAYOUT_HORIZONTAL)
		slot_layout_input.add_item("竖向插卡", SLOT_LAYOUT_VERTICAL)
		slot_layout_input.select(SLOT_LAYOUT_HORIZONTAL)

func _setup_card_context_menu() -> void:
	card_context_menu = PopupMenu.new()
	card_context_menu.name = "CardContextMenu"
	card_context_menu.add_item("12口", CARD_MENU_PORT_12)
	card_context_menu.add_item("8口", CARD_MENU_PORT_8)
	card_context_menu.add_item("6口", CARD_MENU_PORT_6)
	card_context_menu.add_separator()
	card_context_menu.add_item("清空端口", CARD_MENU_CLEAR)
	card_context_menu.id_pressed.connect(_on_card_context_menu_selected)
	add_child(card_context_menu)

func _on_dimensions_changed(_value: float) -> void:
	if is_loading_target_config:
		return
	_rebuild_slot_faces()

func _on_visual_option_changed(_index: int) -> void:
	if is_loading_target_config:
		return
	_refresh_port_view()
	_store_current_target_config()

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
	_store_current_target_config()
	visible = false

func _on_apply_pressed() -> void:
	var serialized_config: Dictionary = _serialize_current_config()
	print("ModulePanel serialized config:")
	print(JSON.stringify(serialized_config, "\t"))
	if status_label:
		status_label.text = "已打印当前插槽配置 JSON，后续可接存储接口"

func _rebuild_slot_faces() -> void:
	var total_faces: int = _get_total_faces()
	face_slot_cards.clear()
	face_card_locks.clear()
	for _face_index in range(total_faces):
		face_slot_cards.append(_create_face_slot_data(_get_slot_count(), _get_slot_spec()))
		face_card_locks.append(_create_face_card_locks(_get_slot_count(), _get_slot_spec()))
	current_face_index = clamp(current_face_index, 0, total_faces - 1)
	_refresh_port_view()
	_store_current_target_config()

func _refresh_port_view() -> void:
	var total_faces: int = _get_total_faces()
	current_face_index = clamp(current_face_index, 0, total_faces - 1)

	if face_page_label:
		face_page_label.text = "第%d面" % (current_face_index + 1)
	if face_title:
		face_title.text = "第%d面插槽预览" % (current_face_index + 1)
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

func _get_slot_count() -> int:
	if not row_input:
		return 1
	return max(1, int(row_input.value))

func _get_slot_spec() -> int:
	if not col_input:
		return 1
	return max(1, int(col_input.value))

func _get_port_shape() -> int:
	if not shape_input:
		return PORT_SHAPE_CIRCLE
	return shape_input.get_selected_id()

func _get_slot_layout() -> int:
	if not slot_layout_input:
		return SLOT_LAYOUT_HORIZONTAL
	return slot_layout_input.get_selected_id()

func _create_face_slot_data(slot_count: int, slot_spec: int) -> Array:
	var face_slots: Array = []
	for _slot_index in range(slot_count):
		face_slots.append(_create_slot_cards(slot_spec))
	return face_slots

func _create_slot_cards(slot_spec: int) -> Array:
	var slot_cards: Array = []
	for _card_index in range(slot_spec):
		slot_cards.append(_build_card_state(0, []))
	return slot_cards

func _build_card_state(port_count: int, ports: Array) -> Dictionary:
	return {
		"port_count": port_count,
		"ports": ports.duplicate(),
	}

func _create_slot_locks(slot_count: int) -> Array:
	var locks: Array = []
	locks.resize(slot_count)
	for slot_index in range(slot_count):
		locks[slot_index] = true
	return locks

func _create_face_card_locks(slot_count: int, slot_spec: int) -> Array:
	var face_locks: Array = []
	for _slot_index in range(slot_count):
		face_locks.append(_create_slot_locks(slot_spec))
	return face_locks

func _render_current_face() -> void:
	if not port_grid:
		return
	for child in port_grid.get_children():
		child.queue_free()
	port_grid.custom_minimum_size = Vector2.ZERO
	if face_slot_cards.is_empty():
		return

	var slot_root: VBoxContainer = VBoxContainer.new()
	slot_root.add_theme_constant_override("separation", SLOT_GAP)
	slot_root.size_flags_horizontal = Control.SIZE_FILL
	port_grid.add_child(slot_root)
	port_grid.custom_minimum_size = _get_preview_minimum_size(_get_slot_count(), _get_slot_spec())

	for slot_index in range(_get_slot_count()):
		slot_root.add_child(_create_slot_group(current_face_index, slot_index, _get_slot_spec()))

func _get_preview_minimum_size(slot_count: int, slot_spec: int) -> Vector2:
	var card_size: Vector2 = _get_card_slot_size(CARD_MENU_PORT_12)
	var slot_content_width: float = card_size.x + SLOT_PADDING * 2.0
	var slot_content_height: float = card_size.y + SLOT_PADDING * 2.0
	if _get_slot_layout() == SLOT_LAYOUT_HORIZONTAL:
		slot_content_height = slot_spec * card_size.y + max(0, slot_spec - 1) * CARD_GAP + SLOT_PADDING * 2.0
	else:
		slot_content_width = slot_spec * card_size.x + max(0, slot_spec - 1) * CARD_GAP + SLOT_PADDING * 2.0
	var total_width: float = slot_content_width + 24.0
	var total_height: float = slot_count * slot_content_height + max(0, slot_count - 1) * SLOT_GAP + 24.0
	return Vector2(total_width, total_height)

func _create_slot_group(face_index: int, slot_index: int, slot_spec: int) -> Control:
	var slot_wrapper: HBoxContainer = HBoxContainer.new()
	slot_wrapper.size_flags_horizontal = Control.SIZE_FILL

	var slot_panel: PanelContainer = PanelContainer.new()
	slot_panel.script = SLOT_GROUP_SCRIPT
	slot_panel.drag_enabled = false
	slot_panel.draw_dashed_outline = true
	slot_panel.script = SLOT_GROUP_SCRIPT
	slot_panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
	slot_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot_panel.add_theme_stylebox_override("panel", _create_slot_stylebox())

	var cards_root: BoxContainer
	if _get_slot_layout() == SLOT_LAYOUT_HORIZONTAL:
		cards_root = VBoxContainer.new()
	else:
		cards_root = HBoxContainer.new()
	cards_root.add_theme_constant_override("separation", CARD_GAP)
	cards_root.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cards_root.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot_panel.add_child(cards_root)

	for card_index in range(slot_spec):
		cards_root.add_child(_create_subcard_slot(face_index, slot_index, card_index))

	slot_wrapper.add_child(slot_panel)
	return slot_wrapper

func _create_slot_stylebox() -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = SLOT_BACKGROUND_COLOR
	style_box.set_border_width_all(0)
	style_box.content_margin_left = SLOT_PADDING
	style_box.content_margin_top = SLOT_PADDING
	style_box.content_margin_right = SLOT_PADDING
	style_box.content_margin_bottom = SLOT_PADDING
	return style_box

func _create_card_stylebox() -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = CARD_BACKGROUND_COLOR
	style_box.border_color = CARD_BORDER_COLOR
	style_box.set_border_width_all(1)
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	style_box.content_margin_left = CARD_PADDING
	style_box.content_margin_top = CARD_PADDING
	style_box.content_margin_right = CARD_PADDING
	style_box.content_margin_bottom = CARD_PADDING
	return style_box

func _create_subcard_slot(face_index: int, slot_index: int, card_index: int) -> Control:
	var fixed_card_size: Vector2 = _get_card_slot_size(CARD_MENU_PORT_12)
	var card_wrapper: BoxContainer
	if _get_slot_layout() == SLOT_LAYOUT_VERTICAL:
		card_wrapper = VBoxContainer.new()
		card_wrapper.custom_minimum_size = Vector2(fixed_card_size.x, fixed_card_size.y + CARD_ACTION_BUTTON_SIZE + CARD_LOCK_GAP)
	else:
		card_wrapper = HBoxContainer.new()
		card_wrapper.custom_minimum_size = Vector2(fixed_card_size.x + max(CARD_LOCK_BUTTON_SIZE, CARD_ACTION_BUTTON_SIZE) + CARD_LOCK_GAP, fixed_card_size.y)
	card_wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card_wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	card_wrapper.add_theme_constant_override("separation", CARD_LOCK_GAP)

	var card_panel: PanelContainer = PanelContainer.new()
	card_panel.script = SLOT_GROUP_SCRIPT
	card_panel.controller = self
	card_panel.face_index = face_index
	card_panel.slot_index = slot_index
	card_panel.card_index = card_index
	card_panel.slot_layout = _get_slot_layout()
	card_panel.drag_enabled = true
	card_panel.draw_dashed_outline = false
	card_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card_panel.add_theme_stylebox_override("panel", _create_card_stylebox())
	card_panel.custom_minimum_size = fixed_card_size
	card_panel.mouse_default_cursor_shape = Control.CURSOR_DRAG if not is_card_locked(face_index, slot_index, card_index) else Control.CURSOR_ARROW
	card_panel.gui_input.connect(_on_subcard_slot_gui_input.bind(face_index, slot_index, card_index, card_panel))

	var lock_button: Button = _create_card_lock_button(face_index, slot_index, card_index, card_panel)
	var action_button: Button = _create_card_action_button(face_index, slot_index, card_index)
	if _get_slot_layout() == SLOT_LAYOUT_VERTICAL:
		var tool_row: HBoxContainer = HBoxContainer.new()
		tool_row.custom_minimum_size = Vector2(fixed_card_size.x, CARD_ACTION_BUTTON_SIZE)
		tool_row.size_flags_horizontal = Control.SIZE_FILL
		tool_row.add_child(lock_button)
		var tool_spacer: Control = Control.new()
		tool_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tool_row.add_child(tool_spacer)
		tool_row.add_child(action_button)
		card_wrapper.add_child(tool_row)
		card_wrapper.add_child(card_panel)
	else:
		var tool_column: VBoxContainer = VBoxContainer.new()
		tool_column.custom_minimum_size = Vector2(max(CARD_LOCK_BUTTON_SIZE, CARD_ACTION_BUTTON_SIZE), fixed_card_size.y)
		tool_column.size_flags_vertical = Control.SIZE_FILL
		tool_column.alignment = BoxContainer.ALIGNMENT_CENTER
		tool_column.add_theme_constant_override("separation", CARD_LOCK_GAP)
		tool_column.add_child(lock_button)
		tool_column.add_child(action_button)
		card_wrapper.add_child(tool_column)
		card_wrapper.add_child(card_panel)

	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", CARD_PORT_GAP)
	card_panel.add_child(content)

	var ports_grid: GridContainer = GridContainer.new()
	ports_grid.columns = _get_card_grid_columns(CARD_MENU_PORT_12)
	ports_grid.add_theme_constant_override("h_separation", CARD_PORT_GAP)
	ports_grid.add_theme_constant_override("v_separation", CARD_PORT_GAP)
	ports_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for port_index in range(CARD_MENU_PORT_12):
		ports_grid.add_child(_create_card_port_button(face_index, slot_index, card_index, port_index))
	content.add_child(ports_grid)

	return card_wrapper

func _create_card_lock_button(face_index: int, slot_index: int, card_index: int, card_panel: PanelContainer) -> Button:
	var lock_button: Button = Button.new()
	lock_button.custom_minimum_size = Vector2(CARD_LOCK_BUTTON_SIZE, CARD_LOCK_BUTTON_SIZE)
	lock_button.focus_mode = Control.FOCUS_NONE
	lock_button.flat = true
	lock_button.expand_icon = true
	_update_card_lock_button(lock_button, face_index, slot_index, card_index, card_panel)
	lock_button.pressed.connect(_on_card_lock_pressed.bind(face_index, slot_index, card_index, lock_button, card_panel))
	return lock_button

func _create_card_action_stylebox() -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = CARD_ACTION_BG_COLOR
	style_box.border_color = CARD_ACTION_BORDER_COLOR
	style_box.set_border_width_all(1)
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	return style_box

func _create_card_action_button(face_index: int, slot_index: int, card_index: int) -> Button:
	var action_button: Button = Button.new()
	action_button.custom_minimum_size = Vector2(CARD_ACTION_BUTTON_SIZE, CARD_ACTION_BUTTON_SIZE)
	action_button.focus_mode = Control.FOCUS_NONE
	action_button.flat = false
	action_button.expand_icon = true
	action_button.add_theme_stylebox_override("normal", _create_card_action_stylebox())
	action_button.add_theme_stylebox_override("hover", _create_card_action_stylebox())
	action_button.add_theme_stylebox_override("pressed", _create_card_action_stylebox())
	action_button.add_theme_stylebox_override("focus", _create_card_action_stylebox())
	_update_card_action_button(action_button, face_index, slot_index, card_index)
	action_button.pressed.connect(_on_card_action_pressed.bind(face_index, slot_index, card_index, action_button))
	return action_button

func _on_card_action_pressed(face_index: int, slot_index: int, card_index: int, action_button: Button) -> void:
	_show_card_context_menu(face_index, slot_index, card_index, action_button.get_screen_position() + Vector2(0, action_button.size.y))

func _update_card_action_button(action_button: Button, face_index: int, slot_index: int, card_index: int) -> void:
	var has_ports: bool = _get_card_port_count(face_index, slot_index, card_index) > 0
	action_button.text = ""
	action_button.icon = CARD_ACTION_EDIT_ICON if has_ports else CARD_ACTION_ADD_ICON
	action_button.tooltip_text = "编辑子卡端口" if has_ports else "添加子卡端口"

func _on_card_lock_pressed(face_index: int, slot_index: int, card_index: int, lock_button: Button, card_panel: PanelContainer) -> void:
	_toggle_card_locked(face_index, slot_index, card_index)
	_update_card_lock_button(lock_button, face_index, slot_index, card_index, card_panel)
	_store_current_target_config()

func _update_card_lock_button(lock_button: Button, face_index: int, slot_index: int, card_index: int, card_panel: PanelContainer) -> void:
	var locked: bool = is_card_locked(face_index, slot_index, card_index)
	lock_button.text = ""
	lock_button.icon = LOCK_CLOSED_ICON if locked else LOCK_OPEN_ICON
	lock_button.tooltip_text = "已锁定，点击解锁拖拽子卡" if locked else "已解锁，可拖拽子卡，点击重新锁定"
	if card_panel:
		card_panel.mouse_default_cursor_shape = Control.CURSOR_ARROW if locked else Control.CURSOR_DRAG

func _get_card_slot_size(port_count: int) -> Vector2:
	var _effective_port_count: int = CARD_MENU_PORT_12 if port_count <= 0 else port_count
	var content_size: Vector2 = _get_card_content_size(CARD_MENU_PORT_12)
	var width: float = maxf(float(CARD_BASE_WIDTH), content_size.x + CARD_PADDING * 2.0)
	var height: float = maxf(float(CARD_BASE_HEIGHT), content_size.y + CARD_PADDING * 2.0)
	return Vector2(width, height)

func _get_card_content_size(port_count: int) -> Vector2:
	var dimensions: Vector2i = _get_card_grid_dimensions(port_count)
	var width: float = dimensions.x * CARD_PORT_SIZE + max(0, dimensions.x - 1) * CARD_PORT_GAP
	var height: float = dimensions.y * CARD_PORT_SIZE + max(0, dimensions.y - 1) * CARD_PORT_GAP
	return Vector2(width, height)

func _get_card_grid_columns(port_count: int) -> int:
	return _get_card_grid_dimensions(port_count).x

func _get_card_grid_dimensions(port_count: int) -> Vector2i:
	var effective_port_count: int = max(1, port_count)
	if _get_slot_layout() == SLOT_LAYOUT_HORIZONTAL:
		return Vector2i(effective_port_count, 1)
	return Vector2i(1, effective_port_count)

func _create_card_port_button(face_index: int, slot_index: int, card_index: int, port_index: int) -> Button:
	var port_button: Button = Button.new()
	var active_port_count: int = _get_card_port_count(face_index, slot_index, card_index)
	var is_active_port: bool = port_index < active_port_count
	port_button.custom_minimum_size = Vector2(CARD_PORT_SIZE, CARD_PORT_SIZE)
	port_button.flat = true
	port_button.toggle_mode = is_active_port
	port_button.focus_mode = Control.FOCUS_NONE
	port_button.disabled = not is_active_port
	port_button.mouse_filter = Control.MOUSE_FILTER_STOP if is_active_port else Control.MOUSE_FILTER_IGNORE
	port_button.button_pressed = is_active_port and _get_card_port_state(face_index, slot_index, card_index, port_index)
	_update_port_button(port_button, face_index, slot_index, card_index, port_index)
	if is_active_port:
		port_button.toggled.connect(_on_card_port_toggled.bind(face_index, slot_index, card_index, port_index, port_button))
	return port_button

func _on_card_port_toggled(pressed: bool, face_index: int, slot_index: int, card_index: int, port_index: int, port_button: Button) -> void:
	var card_state: Dictionary = _get_card_state(face_index, slot_index, card_index)
	var ports: Array = card_state.get("ports", [])
	if port_index >= ports.size():
		return
	ports[port_index] = pressed
	card_state["ports"] = ports
	face_slot_cards[face_index][slot_index][card_index] = card_state
	_update_port_button(port_button, face_index, slot_index, card_index, port_index)
	_refresh_summary()
	_store_current_target_config()

func _update_port_button(port_button: Button, face_index: int, slot_index: int, card_index: int, port_index: int) -> void:
	var is_active_port: bool = port_index < _get_card_port_count(face_index, slot_index, card_index)
	var is_occupied: bool = port_button.button_pressed
	var port_color: Color = CARD_PLACEHOLDER_PORT_COLOR
	if is_active_port:
		port_color = Color(0.85, 0.22, 0.22, 1.0) if is_occupied else Color(0.16, 0.72, 0.29, 1.0)
	port_button.text = "■" if _get_port_shape() == PORT_SHAPE_SQUARE else "●"
	port_button.add_theme_color_override("font_color", port_color)
	port_button.add_theme_color_override("font_disabled_color", port_color)
	port_button.add_theme_color_override("font_focus_color", port_color)
	port_button.add_theme_color_override("font_hover_color", port_color)
	port_button.add_theme_color_override("font_hover_pressed_color", port_color)
	port_button.add_theme_color_override("font_pressed_color", port_color)
	port_button.tooltip_text = "%s | Face %d, 插槽 %d, 子卡 %d, 端口 %d" % ["占位" if not is_active_port else "已占用" if is_occupied else "空闲", face_index + 1, slot_index + 1, card_index + 1, port_index + 1]

func _on_subcard_slot_gui_input(_event: InputEvent, _face_index: int, _slot_index: int, _card_index: int, _card_panel: Control) -> void:
	return

func _show_card_context_menu(face_index: int, slot_index: int, card_index: int, popup_position: Vector2) -> void:
	pending_card_context = {
		"face_index": face_index,
		"slot_index": slot_index,
		"card_index": card_index,
	}
	card_context_menu.position = Vector2i(popup_position)
	card_context_menu.reset_size()
	card_context_menu.popup()

func _on_card_context_menu_selected(port_count: int) -> void:
	if pending_card_context.is_empty():
		return
	if port_count == CARD_MENU_CLEAR:
		port_count = 0
	_set_card_port_count(
		int(pending_card_context.get("face_index", current_face_index)),
		int(pending_card_context.get("slot_index", 0)),
		int(pending_card_context.get("card_index", 0)),
		port_count
	)
	pending_card_context.clear()
	_refresh_port_view()
	_store_current_target_config()

func _set_card_port_count(face_index: int, slot_index: int, card_index: int, port_count: int) -> void:
	var card_state: Dictionary = _get_card_state(face_index, slot_index, card_index)
	card_state["port_count"] = port_count
	card_state["ports"] = _resize_port_state(card_state.get("ports", []), port_count)
	face_slot_cards[face_index][slot_index][card_index] = card_state

func _resize_port_state(existing_ports: Variant, port_count: int) -> Array:
	var resized_ports: Array = []
	resized_ports.resize(port_count)
	for port_index in range(port_count):
		resized_ports[port_index] = existing_ports is Array and port_index < existing_ports.size() and bool(existing_ports[port_index])
	return resized_ports

func _get_card_state(face_index: int, slot_index: int, card_index: int) -> Dictionary:
	if face_index >= face_slot_cards.size():
		return _build_card_state(0, [])
	if slot_index >= face_slot_cards[face_index].size():
		return _build_card_state(0, [])
	if card_index >= face_slot_cards[face_index][slot_index].size():
		return _build_card_state(0, [])
	return face_slot_cards[face_index][slot_index][card_index]

func _get_card_port_count(face_index: int, slot_index: int, card_index: int) -> int:
	return int(_get_card_state(face_index, slot_index, card_index).get("port_count", 0))

func _get_card_port_state(face_index: int, slot_index: int, card_index: int, port_index: int) -> bool:
	var ports: Array = _get_card_state(face_index, slot_index, card_index).get("ports", [])
	return port_index < ports.size() and bool(ports[port_index])

func _refresh_summary() -> void:
	var slot_count: int = _get_slot_count()
	var slot_spec: int = _get_slot_spec()
	var total_faces: int = _get_total_faces()
	var shape_text: String = "圆形" if _get_port_shape() == PORT_SHAPE_CIRCLE else "方形"
	var slot_layout_text: String = "横向插卡" if _get_slot_layout() == SLOT_LAYOUT_HORIZONTAL else "竖向插卡"
	var configured_cards: int = 0
	var total_ports: int = 0
	var occupied_ports: int = 0

	if current_face_index < face_slot_cards.size():
		for slot_cards in face_slot_cards[current_face_index]:
			for card_state in slot_cards:
				var port_count := int(card_state.get("port_count", 0))
				if port_count > 0:
					configured_cards += 1
					total_ports += port_count
					for occupied in card_state.get("ports", []):
						if bool(occupied):
							occupied_ports += 1

	if summary_label:
		summary_label.text = "%d 槽 | 规格 %d | %d 面 | %s" % [slot_count, slot_spec, total_faces, slot_layout_text]
	if status_label:
		status_label.text = "点子卡右上角 + / 编辑设置端口；拖拽前再解锁。已配 %d 张子卡，端口 %d/%d" % [configured_cards, occupied_ports, total_ports]

func build_card_drag_payload(face_index: int, slot_index: int, card_index: int, slot_layout: int) -> Dictionary:
	return {
		"type": "module_card",
		"face_index": face_index,
		"slot_index": slot_index,
		"card_index": card_index,
		"slot_layout": slot_layout,
	}

func is_card_locked(face_index: int, slot_index: int, card_index: int) -> bool:
	return face_index < face_card_locks.size() and slot_index < face_card_locks[face_index].size() and card_index < face_card_locks[face_index][slot_index].size() and bool(face_card_locks[face_index][slot_index][card_index])

func _toggle_card_locked(face_index: int, slot_index: int, card_index: int) -> void:
	if face_index >= face_card_locks.size() or slot_index >= face_card_locks[face_index].size() or card_index >= face_card_locks[face_index][slot_index].size():
		return
	face_card_locks[face_index][slot_index][card_index] = not bool(face_card_locks[face_index][slot_index][card_index])

func can_drop_card_payload(data: Variant, face_index: int, slot_index: int, slot_layout: int) -> bool:
	return data is Dictionary and data.get("type", "") == "module_card" and data.get("face_index", -1) == face_index and data.get("slot_index", -1) == slot_index and data.get("slot_layout", -1) == slot_layout

func drop_card_payload(data: Variant, target_slot_index: int, target_card_index: int, slot_layout: int, insert_before: bool) -> void:
	if not can_drop_card_payload(data, current_face_index, target_slot_index, slot_layout):
		return
	var source_card_index: int = int(data.get("card_index", -1))
	if source_card_index == -1:
		return
	_move_card_group(current_face_index, target_slot_index, source_card_index, target_card_index, insert_before)
	_refresh_port_view()
	_store_current_target_config()

func _move_card_group(face_index: int, slot_index: int, source_card_index: int, target_card_index: int, insert_before: bool) -> void:
	var insert_index: int = target_card_index if insert_before else target_card_index + 1
	if source_card_index < insert_index:
		insert_index -= 1
	if source_card_index == insert_index:
		return
	var moved_card: Dictionary = face_slot_cards[face_index][slot_index][source_card_index]
	var moved_lock: bool = bool(face_card_locks[face_index][slot_index][source_card_index])
	face_slot_cards[face_index][slot_index].remove_at(source_card_index)
	face_card_locks[face_index][slot_index].remove_at(source_card_index)
	face_slot_cards[face_index][slot_index].insert(insert_index, moved_card)
	face_card_locks[face_index][slot_index].insert(insert_index, moved_lock)

func open_for_target(target: Node3D) -> void:
	if not target:
		return
	if current_target and current_target != target:
		_store_current_target_config()
	current_target = target
	_load_target_config(target)
	visible = true

func _load_target_config(target: Node3D) -> void:
	var cabinet_id: String = _ensure_target_id(target)
	var stored_config: Dictionary = cabinet_configs.get(cabinet_id, {})
	if stored_config.is_empty() and target.has_meta("module_config"):
		var target_config: Variant = target.get_meta("module_config")
		if target_config is Dictionary:
			stored_config = target_config.duplicate(true)
	if stored_config.is_empty():
		stored_config = _build_default_config()
		cabinet_configs[cabinet_id] = stored_config.duplicate(true)
		target.set_meta("module_config", stored_config.duplicate(true))

	is_loading_target_config = true
	row_input.value = int(stored_config.get("slot_count", stored_config.get("rows", _get_slot_count())))
	col_input.value = int(stored_config.get("slot_spec", stored_config.get("cols", _get_slot_spec())))
	faces_input.value = int(stored_config.get("faces", _get_total_faces()))
	if shape_input:
		_select_option_id(shape_input, int(stored_config.get("shape", PORT_SHAPE_CIRCLE)))
	if slot_layout_input:
		_select_option_id(slot_layout_input, int(stored_config.get("slot_layout", SLOT_LAYOUT_HORIZONTAL)))
	face_slot_cards = _sanitize_face_slot_cards(stored_config.get("face_slot_cards", []), _get_slot_count(), _get_slot_spec(), _get_total_faces())
	face_card_locks = _sanitize_card_locks(stored_config.get("card_locks", stored_config.get("slot_locks", [])), _get_slot_count(), _get_slot_spec(), _get_total_faces())
	current_face_index = clamp(int(stored_config.get("current_face_index", 0)), 0, max(0, _get_total_faces() - 1))
	is_loading_target_config = false
	_refresh_port_view()

func _store_current_target_config() -> void:
	if not current_target or is_loading_target_config:
		return
	var cabinet_id: String = _ensure_target_id(current_target)
	var config: Dictionary = _serialize_current_config()
	cabinet_configs[cabinet_id] = config.duplicate(true)
	current_target.set_meta("module_config", config.duplicate(true))

func _serialize_current_config() -> Dictionary:
	return {
		"odf_id": str(current_target.get_instance_id()) if current_target else "",
		"slot_count": _get_slot_count(),
		"slot_spec": _get_slot_spec(),
		"faces": _get_total_faces(),
		"shape": _get_port_shape(),
		"slot_layout": _get_slot_layout(),
		"current_face_index": current_face_index,
		"card_locks": face_card_locks.duplicate(true),
		"face_slot_cards": face_slot_cards.duplicate(true),
	}

func _build_default_config() -> Dictionary:
	return {
		"slot_count": int(row_input.value),
		"slot_spec": int(col_input.value),
		"faces": int(faces_input.value),
		"shape": PORT_SHAPE_CIRCLE,
		"slot_layout": SLOT_LAYOUT_HORIZONTAL,
		"current_face_index": 0,
		"card_locks": _build_default_card_locks(int(faces_input.value), int(row_input.value), int(col_input.value)),
		"face_slot_cards": _build_default_face_slot_cards(),
	}

func _build_default_face_slot_cards() -> Array:
	var default_faces: Array = []
	for _face_index in range(int(faces_input.value)):
		default_faces.append(_create_face_slot_data(int(row_input.value), int(col_input.value)))
	return default_faces

func _build_default_card_locks(total_faces: int, slot_count: int, slot_spec: int) -> Array:
	var default_locks: Array = []
	for _face_index in range(total_faces):
		default_locks.append(_create_face_card_locks(slot_count, slot_spec))
	return default_locks

func _sanitize_face_slot_cards(raw_cards: Variant, slot_count: int, slot_spec: int, total_faces: int) -> Array:
	var sanitized_faces: Array = []
	for face_index in range(total_faces):
		var source_face: Array = []
		if raw_cards is Array and face_index < raw_cards.size() and raw_cards[face_index] is Array:
			source_face = raw_cards[face_index]
		var sanitized_slots: Array = []
		for slot_index in range(slot_count):
			var source_slot: Array = []
			if slot_index < source_face.size() and source_face[slot_index] is Array:
				source_slot = source_face[slot_index]
			var sanitized_cards: Array = []
			for card_index in range(slot_spec):
				var source_card: Dictionary = {}
				if card_index < source_slot.size() and source_slot[card_index] is Dictionary:
					source_card = source_slot[card_index]
				var port_count := int(source_card.get("port_count", 0))
				if port_count != CARD_MENU_PORT_12 and port_count != CARD_MENU_PORT_8 and port_count != CARD_MENU_PORT_6:
					port_count = 0
				sanitized_cards.append(_build_card_state(port_count, _resize_port_state(source_card.get("ports", []), port_count)))
			sanitized_slots.append(sanitized_cards)
		sanitized_faces.append(sanitized_slots)
	return sanitized_faces

func _sanitize_card_locks(raw_locks: Variant, slot_count: int, slot_spec: int, total_faces: int) -> Array:
	var sanitized_faces: Array = []
	for face_index in range(total_faces):
		var source_face: Array = []
		if raw_locks is Array and face_index < raw_locks.size() and raw_locks[face_index] is Array:
			source_face = raw_locks[face_index]
		var sanitized_slots: Array = []
		for slot_index in range(slot_count):
			var source_slot: Array = []
			if slot_index < source_face.size() and source_face[slot_index] is Array:
				source_slot = source_face[slot_index]
			var sanitized_cards: Array = []
			sanitized_cards.resize(slot_spec)
			for card_index in range(slot_spec):
				sanitized_cards[card_index] = not (card_index < source_slot.size() and not bool(source_slot[card_index]))
			sanitized_slots.append(sanitized_cards)
		sanitized_faces.append(sanitized_slots)
	return sanitized_faces

func _select_option_id(option_button: OptionButton, option_id: int) -> void:
	for item_index in range(option_button.item_count):
		if option_button.get_item_id(item_index) == option_id:
			option_button.select(item_index)
			return

func _ensure_target_id(target: Node3D) -> String:
	if target.has_meta("module_cabinet_id"):
		return str(target.get_meta("module_cabinet_id"))
	var cabinet_id: String = "cabinet_%s_%s" % [target.get_instance_id(), Time.get_ticks_usec()]
	target.set_meta("module_cabinet_id", cabinet_id)
	return cabinet_id
