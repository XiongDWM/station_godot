extends Panel

const SLOT_GROUP_SCRIPT := preload("res://scripts/controllers/module_slot_group.gd")
const RJ45_PORT_BUTTON_SCRIPT := preload("res://scripts/style/rj45_port_button.gd")
const OPTICAL_PORT_BUTTON_SCRIPT := preload("res://scripts/style/optical_port_button.gd")
const PORT_CABLE_MOCK_DATA := preload("res://scripts/state/port_cable_mock_data.gd")
const LOCK_CLOSED_ICON := preload("res://assets/icons/lock_closed.svg")
const LOCK_OPEN_ICON := preload("res://assets/icons/lock_open.svg")
const CARD_ACTION_ADD_ICON := preload("res://assets/icons/card_action_add.svg")
const CARD_ACTION_EDIT_ICON := preload("res://assets/icons/card_action_edit.svg")

const PORT_SHAPE_CIRCLE := 0
const PORT_SHAPE_SQUARE := 1
const PORT_SHAPE_RJ45 := 2
const SLOT_LAYOUT_HORIZONTAL := 0
const SLOT_LAYOUT_VERTICAL := 1
const ODF_TYPE_CABINET := 0
const ODF_TYPE_RACK := 1

# 机柜配置默认值
const DEFAULT_SLOT_COUNT := 2
const DEFAULT_SLOT_SPEC := 6
const DEFAULT_FACE_COUNT := 1
const DEFAULT_PORT_SHAPE := PORT_SHAPE_SQUARE
const DEFAULT_SLOT_LAYOUT := SLOT_LAYOUT_HORIZONTAL
const DEFAULT_ODF_TYPE := ODF_TYPE_RACK
const CABINET_DEFAULT_SLOT_COUNT := 4
const CABINET_DEFAULT_SLOT_SPEC := 1
const CABINET_DEFAULT_FACE_COUNT := 1
const CABINET_DEFAULT_PORT_SHAPE := PORT_SHAPE_RJ45
const CABINET_DEFAULT_SLOT_LAYOUT := SLOT_LAYOUT_HORIZONTAL

const SLOT_DROP_LAYOUT := SLOT_LAYOUT_HORIZONTAL
const CARD_MENU_CLEAR := -1
const CARD_MENU_PORT_6 := 6
const CARD_MENU_PORT_8 := 8
const CARD_MENU_PORT_12 := 12
const CARD_MENU_SWITCH := 24
const CARD_TYPE_NORMAL := "normal"
const CARD_TYPE_SWITCH := "switch"
const PORT_STATUS_EMPTY := 0
const PORT_STATUS_NORMAL := 1
const PORT_STATUS_HIGH_LOSS := 2
const PORT_STATUS_BROKEN_CORE := 3
const PORT_STATUS_FREE_CORE := 4

const CARD_PORT_SIZE := 26
const CARD_PORT_GAP := 5
const SWITCH_PORT_SIZE := 14
const SWITCH_PORT_WIDTH := 22
const SWITCH_PORT_HEIGHT := 17
const SWITCH_PORT_GAP := 4
const SWITCH_PORT_COLUMNS := 12
const SWITCH_PORT_COUNT := 24
const CARD_PADDING := 6
const CARD_GAP := 6
const CARD_BASE_WIDTH := 38
const CARD_BASE_HEIGHT := 38
const SLOT_PADDING := 10
const SLOT_CUBE_TOP_DEPTH := 14
const SLOT_CONTENT_TOP_EXTRA := 8
const SLOT_GAP := 6	
const CARD_LOCK_BUTTON_SIZE := 22
const CARD_LOCK_GAP := 4
const CARD_ACTION_BUTTON_SIZE := 22
const SLOT_BACKGROUND_COLOR := Color(0, 0, 0, 0)
const CARD_BACKGROUND_COLOR := Color(0.78, 0.8, 0.81, 0.96)
const CARD_BORDER_COLOR := Color(0.48, 0.5, 0.52, 1.0)
const CARD_SHADOW_COLOR := Color(0.02, 0.025, 0.03, 0.36)
const CARD_METAL_BACKGROUND_COLOR := Color(0.72, 0.75, 0.76, 0.98)
const CARD_METAL_BORDER_COLOR := Color(0.9, 0.92, 0.92, 1.0)
const CARD_ACTION_BG_COLOR := Color(1, 1, 1, 0.96)
const CARD_ACTION_BORDER_COLOR := Color(0.77, 0.79, 0.82, 1.0)
const CARD_PLACEHOLDER_PORT_COLOR := Color(1, 1, 1, 0)
const PORT_CONTEXT_TEXT_COLOR := Color(0.97, 0.985, 1.0, 1.0)
const PORT_CONTEXT_MUTED_TEXT_COLOR := Color(0.86, 0.9, 0.94, 0.96)
const PORT_CONTEXT_SEPARATOR_COLOR := Color(1.0, 1.0, 1.0, 0.18)
const PORT_SOCKET_BG_COLOR := Color(0.015, 0.018, 0.02, 1.0)
const PORT_SOCKET_HOVER_BG_COLOR := Color(0.045, 0.055, 0.06, 1.0)
const PORT_SOCKET_PRESSED_BG_COLOR := Color(0.0, 0.01, 0.014, 1.0)
const PORT_SOCKET_BORDER_COLOR := Color(0.82, 0.86, 0.86, 0.95)
const PORT_SOCKET_ACTIVE_BORDER_COLOR := Color(0.9, 0.16, 0.12, 1.0)
const PORT_SOCKET_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.45)
const PREVIEW_LEGEND_BG_COLOR := Color(0.05, 0.06, 0.072, 0.94)
const PREVIEW_LEGEND_BORDER_COLOR := Color(0.86, 0.89, 0.92, 0.34)
const PREVIEW_LEGEND_TEXT_COLOR := Color(0.95, 0.97, 0.99, 0.98)
const PREVIEW_LEGEND_MUTED_TEXT_COLOR := Color(0.83, 0.87, 0.91, 0.92)

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
var port_context_popup: PopupPanel
var pending_port_context: Dictionary = {}
var port_fiber_type_input: OptionButton
var port_fiber_core_input: SpinBox
var port_status_group: ButtonGroup
var port_status_buttons: Dictionary = {}
var bad_port_check: CheckButton
var set_empty_port_button: Button
var is_syncing_port_context_ui := false
var api_request: HTTPRequest
var preview_overlay: Control
var pending_remote_cabinet_id := ""
var odf_type_input: OptionButton
var port_tooltip_theme: Theme
var port_context_radio_unchecked_icon: Texture2D
var port_context_radio_checked_icon: Texture2D
var port_context_check_unchecked_icon: Texture2D
var port_context_check_checked_icon: Texture2D

func _ready() -> void:
	_setup_odf_type_input()
	_setup_option_inputs()
	_setup_card_context_menu()
	_setup_port_context_popup()
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
	if odf_type_input:
		odf_type_input.item_selected.connect(_on_odf_type_selected)
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
	_bind_api_request()
	_bind_preview_overlay()
	_rebuild_slot_faces()

func _bind_api_request() -> void:
	var scene_root := get_tree().current_scene
	if not scene_root:
		return
	api_request = scene_root.get_node_or_null("HTTPRequest") as HTTPRequest
	if not api_request:
		return
	if api_request.has_signal("odf_detail_received") and not api_request.odf_detail_received.is_connected(_on_odf_detail_received):
		api_request.odf_detail_received.connect(_on_odf_detail_received)
	if api_request.has_signal("odf_detail_failed") and not api_request.odf_detail_failed.is_connected(_on_odf_detail_failed):
		api_request.odf_detail_failed.connect(_on_odf_detail_failed)
	if api_request.has_signal("odf_save_completed") and not api_request.odf_save_completed.is_connected(_on_odf_save_completed):
		api_request.odf_save_completed.connect(_on_odf_save_completed)
	if api_request.has_signal("odf_save_failed") and not api_request.odf_save_failed.is_connected(_on_odf_save_failed):
		api_request.odf_save_failed.connect(_on_odf_save_failed)

func _bind_preview_overlay() -> void:
	var scene_root := get_tree().current_scene
	if not scene_root:
		return
	preview_overlay = scene_root.get_node_or_null("CanvasLayer/OdfFocusPreviewOverlay") as Control

func _setup_option_inputs() -> void:
	if odf_type_input and odf_type_input.item_count == 0:
		odf_type_input.add_item("机柜", ODF_TYPE_CABINET)
		odf_type_input.add_item("机架", ODF_TYPE_RACK)
		odf_type_input.select(DEFAULT_ODF_TYPE)
	if shape_input and shape_input.item_count == 0:
		shape_input.add_item("圆形（FC）", PORT_SHAPE_CIRCLE)
		shape_input.add_item("方形（SC）", PORT_SHAPE_SQUARE)
		shape_input.add_item("RJ45", PORT_SHAPE_RJ45)
		shape_input.select(DEFAULT_PORT_SHAPE)
	if slot_layout_input and slot_layout_input.item_count == 0:
		slot_layout_input.add_item("横向插卡", SLOT_LAYOUT_HORIZONTAL)
		slot_layout_input.add_item("竖向插卡", SLOT_LAYOUT_VERTICAL)
		slot_layout_input.select(DEFAULT_SLOT_LAYOUT)
	_apply_odf_type_option_constraints(_get_odf_type())

func _setup_card_context_menu() -> void:
	card_context_menu = PopupMenu.new()
	card_context_menu.name = "CardContextMenu"
	card_context_menu.add_item("12口", CARD_MENU_PORT_12)
	card_context_menu.add_item("8口", CARD_MENU_PORT_8)
	card_context_menu.add_item("6口", CARD_MENU_PORT_6)
	card_context_menu.add_item("24口交换机", CARD_MENU_SWITCH)
	card_context_menu.add_separator()
	card_context_menu.add_item("清空端口", CARD_MENU_CLEAR)
	card_context_menu.id_pressed.connect(_on_card_context_menu_selected)
	add_child(card_context_menu)

func _setup_port_context_popup() -> void:
	port_context_popup = PopupPanel.new()
	port_context_popup.name = "PortContextPopup"
	port_context_popup.visible = false
	port_context_popup.add_theme_stylebox_override("panel", _create_port_context_popup_stylebox())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	port_context_popup.add_child(margin)

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(220, 0)
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var fiber_title := Label.new()
	fiber_title.text = "光缆"
	_style_port_context_label(fiber_title, true)
	root.add_child(fiber_title)

	port_fiber_type_input = OptionButton.new()
	port_fiber_type_input.custom_minimum_size = Vector2(0, 32)
	_style_port_context_option_button(port_fiber_type_input)
	port_fiber_type_input.item_selected.connect(_on_port_fiber_type_selected)
	root.add_child(port_fiber_type_input)
	_populate_port_cable_options("")

	var fiber_core_row := HBoxContainer.new()
	fiber_core_row.add_theme_constant_override("separation", 10)
	root.add_child(fiber_core_row)

	var fiber_core_title := Label.new()
	fiber_core_title.text = "纤芯序号"
	_style_port_context_label(fiber_core_title, false)
	fiber_core_row.add_child(fiber_core_title)

	port_fiber_core_input = SpinBox.new()
	port_fiber_core_input.custom_minimum_size = Vector2(96, 32)
	port_fiber_core_input.step = 1.0
	port_fiber_core_input.rounded = true
	port_fiber_core_input.allow_greater = false
	port_fiber_core_input.allow_lesser = false
	port_fiber_core_input.editable = false
	port_fiber_core_input.value = 0
	port_fiber_core_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_port_context_spinbox(port_fiber_core_input)
	port_fiber_core_input.value_changed.connect(_on_port_fiber_core_changed)
	fiber_core_row.add_child(port_fiber_core_input)
	_refresh_port_fiber_core_input("", 0)

	var top_separator := HSeparator.new()
	_style_port_context_separator(top_separator)
	root.add_child(top_separator)

	var status_title := Label.new()
	status_title.text = "占用："
	_style_port_context_label(status_title, true)
	root.add_child(status_title)

	port_status_group = ButtonGroup.new()
	for item in [
		{"id": PORT_STATUS_FREE_CORE, "label": "空闲芯"},
		{"id": PORT_STATUS_NORMAL, "label": "正常"},
		{"id": PORT_STATUS_HIGH_LOSS, "label": "高衰耗"},
		{"id": PORT_STATUS_BROKEN_CORE, "label": "坏芯"},
	]:
		var status_button := CheckBox.new()
		status_button.text = str(item["label"])
		status_button.button_group = port_status_group
		status_button.set_meta("port_status", int(item["id"]))
		_style_port_context_button(status_button)
		_apply_port_context_radio_theme(status_button)
		status_button.pressed.connect(_on_port_status_button_pressed.bind(int(item["id"])))
		port_status_buttons[int(item["id"])] = status_button
		root.add_child(status_button)

	var bottom_separator := HSeparator.new()
	_style_port_context_separator(bottom_separator)
	root.add_child(bottom_separator)

	bad_port_check = CheckButton.new()
	bad_port_check.text = "标记坏端口"
	_style_port_context_button(bad_port_check)
	_apply_port_context_check_theme(bad_port_check)
	bad_port_check.toggled.connect(_on_bad_port_toggled)
	root.add_child(bad_port_check)

	set_empty_port_button = Button.new()
	set_empty_port_button.text = "设置空闲端口"
	set_empty_port_button.focus_mode = Control.FOCUS_NONE
	_style_port_context_button(set_empty_port_button)
	set_empty_port_button.pressed.connect(_on_set_empty_port_pressed)
	root.add_child(set_empty_port_button)

	add_child(port_context_popup)

func _create_port_context_popup_stylebox() -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.055, 0.065, 0.078, 0.985)
	style_box.border_color = Color(0.92, 0.95, 0.96, 0.96)
	style_box.set_border_width_all(1)
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	style_box.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style_box.shadow_size = 10
	style_box.shadow_offset = Vector2(0, 3)
	return style_box

func _style_port_context_label(label: Label, is_section_title: bool) -> void:
	label.add_theme_color_override("font_color", PORT_CONTEXT_TEXT_COLOR if is_section_title else PORT_CONTEXT_MUTED_TEXT_COLOR)
	label.add_theme_font_size_override("font_size", 15 if is_section_title else 13)

func _style_port_context_button(button: BaseButton) -> void:
	button.add_theme_color_override("font_color", PORT_CONTEXT_TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", PORT_CONTEXT_TEXT_COLOR)
	button.add_theme_color_override("font_pressed_color", PORT_CONTEXT_TEXT_COLOR)
	button.add_theme_color_override("font_hover_pressed_color", PORT_CONTEXT_TEXT_COLOR)
	button.add_theme_color_override("font_focus_color", PORT_CONTEXT_TEXT_COLOR)
	button.add_theme_color_override("font_disabled_color", Color(PORT_CONTEXT_TEXT_COLOR, 0.45))
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_constant_override("h_separation", 10)

func _get_port_tooltip_theme() -> Theme:
	if port_tooltip_theme:
		return port_tooltip_theme
	port_tooltip_theme = Theme.new()
	var tooltip_panel := StyleBoxFlat.new()
	tooltip_panel.bg_color = Color(0.055, 0.065, 0.078, 0.985)
	tooltip_panel.border_color = Color(0.94, 0.96, 0.98, 0.98)
	tooltip_panel.set_border_width_all(1)
	tooltip_panel.corner_radius_top_left = 6
	tooltip_panel.corner_radius_top_right = 6
	tooltip_panel.corner_radius_bottom_left = 6
	tooltip_panel.corner_radius_bottom_right = 6
	tooltip_panel.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	tooltip_panel.shadow_size = 8
	tooltip_panel.shadow_offset = Vector2(0, 2)
	tooltip_panel.content_margin_left = 10
	tooltip_panel.content_margin_top = 8
	tooltip_panel.content_margin_right = 10
	tooltip_panel.content_margin_bottom = 8
	port_tooltip_theme.set_stylebox("panel", "TooltipPanel", tooltip_panel)
	port_tooltip_theme.set_color("font_color", "TooltipLabel", Color(0.98, 0.99, 1.0, 1.0))
	port_tooltip_theme.set_font_size("font_size", "TooltipLabel", 14)
	return port_tooltip_theme

func _apply_port_tooltip_theme(control: Control) -> void:
	if control:
		control.theme = _get_port_tooltip_theme()

func _get_port_context_indicator_icon(is_checked: bool, is_radio: bool) -> Texture2D:
	var image := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var border_color := Color(0.9, 0.93, 0.96, 0.98) if is_checked else Color(0.72, 0.76, 0.8, 0.96)
	var fill_color := Color(0.92, 0.95, 0.98, 0.16) if is_radio else Color(0.92, 0.95, 0.98, 0.1)
	var mark_color := Color(0.98, 0.99, 1.0, 1.0)
	if is_radio:
		var center := Vector2(8.5, 8.5)
		for y in range(18):
			for x in range(18):
				var distance := center.distance_to(Vector2(x, y))
				if distance <= 7.2 and distance >= 5.6:
					image.set_pixel(x, y, border_color)
				elif distance < 5.6:
					image.set_pixel(x, y, fill_color)
				if is_checked and distance < 2.8:
					image.set_pixel(x, y, mark_color)
	else:
		for y in range(2, 16):
			for x in range(2, 16):
				var is_border := x <= 3 or x >= 14 or y <= 3 or y >= 14
				image.set_pixel(x, y, border_color if is_border else fill_color)
		if is_checked:
			var check_pixels := [
				Vector2i(5, 9), Vector2i(6, 10), Vector2i(7, 11),
				Vector2i(8, 10), Vector2i(9, 9), Vector2i(10, 8),
				Vector2i(11, 7), Vector2i(12, 6),
			]
			for point in check_pixels:
				image.set_pixel(point.x, point.y, mark_color)
				if point.y + 1 < 18:
					image.set_pixel(point.x, point.y + 1, mark_color)
	return ImageTexture.create_from_image(image)

func _ensure_port_context_indicator_icons() -> void:
	if not port_context_radio_unchecked_icon:
		port_context_radio_unchecked_icon = _get_port_context_indicator_icon(false, true)
	if not port_context_radio_checked_icon:
		port_context_radio_checked_icon = _get_port_context_indicator_icon(true, true)
	if not port_context_check_unchecked_icon:
		port_context_check_unchecked_icon = _get_port_context_indicator_icon(false, false)
	if not port_context_check_checked_icon:
		port_context_check_checked_icon = _get_port_context_indicator_icon(true, false)

func _apply_port_context_radio_theme(button: CheckBox) -> void:
	_ensure_port_context_indicator_icons()
	button.add_theme_icon_override("radio_unchecked", port_context_radio_unchecked_icon)
	button.add_theme_icon_override("radio_checked", port_context_radio_checked_icon)
	button.add_theme_icon_override("radio_unchecked_disabled", port_context_radio_unchecked_icon)
	button.add_theme_icon_override("radio_checked_disabled", port_context_radio_checked_icon)

func _apply_port_context_check_theme(button: CheckButton) -> void:
	_ensure_port_context_indicator_icons()
	button.add_theme_icon_override("unchecked", port_context_check_unchecked_icon)
	button.add_theme_icon_override("checked", port_context_check_checked_icon)
	button.add_theme_icon_override("unchecked_disabled", port_context_check_unchecked_icon)
	button.add_theme_icon_override("checked_disabled", port_context_check_checked_icon)

func _style_port_context_option_button(option_button: OptionButton) -> void:
	option_button.add_theme_color_override("font_color", PORT_CONTEXT_TEXT_COLOR)
	option_button.add_theme_color_override("font_hover_color", PORT_CONTEXT_TEXT_COLOR)
	option_button.add_theme_color_override("font_pressed_color", PORT_CONTEXT_TEXT_COLOR)
	option_button.add_theme_color_override("font_focus_color", PORT_CONTEXT_TEXT_COLOR)
	option_button.add_theme_color_override("font_disabled_color", Color(PORT_CONTEXT_TEXT_COLOR, 0.45))
	option_button.add_theme_font_size_override("font_size", 14)

func _style_port_context_spinbox(spin_box: SpinBox) -> void:
	spin_box.add_theme_color_override("font_color", PORT_CONTEXT_TEXT_COLOR)
	spin_box.add_theme_color_override("font_hover_color", PORT_CONTEXT_TEXT_COLOR)
	spin_box.add_theme_color_override("font_focus_color", PORT_CONTEXT_TEXT_COLOR)
	spin_box.add_theme_color_override("font_disabled_color", Color(PORT_CONTEXT_TEXT_COLOR, 0.45))
	spin_box.add_theme_font_size_override("font_size", 14)

func _style_port_context_separator(separator: HSeparator) -> void:
	separator.modulate = PORT_CONTEXT_SEPARATOR_COLOR

func _on_dimensions_changed(_value: float) -> void:
	if is_loading_target_config:
		return
	_rebuild_slot_faces()

func _on_visual_option_changed(_index: int) -> void:
	if is_loading_target_config:
		return
	_refresh_port_view()
	_store_current_target_config()

func _setup_odf_type_input() -> void:
	var enum_row := get_node_or_null("MarginContainer/RootVBox/ConfigPanel/ConfigVbox/EnumRow") as BoxContainer
	if not enum_row:
		return
	var existing := enum_row.get_node_or_null("OdfTypeGroup")
	if existing:
		odf_type_input = existing.get_node_or_null("OdfTypeInput") as OptionButton
		return
	var type_group := VBoxContainer.new()
	type_group.name = "OdfTypeGroup"
	type_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enum_row.add_child(type_group)

	var label := Label.new()
	label.text = "类型"
	type_group.add_child(label)

	odf_type_input = OptionButton.new()
	odf_type_input.name = "OdfTypeInput"
	odf_type_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_group.add_child(odf_type_input)

func _on_odf_type_selected(_index: int) -> void:
	if is_loading_target_config:
		return
	_apply_odf_type_defaults(_get_odf_type())
	_refresh_preview_overlay()

func _apply_odf_type_defaults(odf_type: int) -> void:
	is_loading_target_config = true
	if odf_type == ODF_TYPE_CABINET:
		if row_input:
			row_input.value = CABINET_DEFAULT_SLOT_COUNT
		if col_input:
			col_input.value = CABINET_DEFAULT_SLOT_SPEC
		if faces_input:
			faces_input.value = CABINET_DEFAULT_FACE_COUNT
		if shape_input:
			_select_option_id(shape_input, CABINET_DEFAULT_PORT_SHAPE)
		if slot_layout_input:
			_select_option_id(slot_layout_input, CABINET_DEFAULT_SLOT_LAYOUT)
	else:
		if row_input:
			row_input.value = DEFAULT_SLOT_COUNT
		if col_input:
			col_input.value = DEFAULT_SLOT_SPEC
		if faces_input:
			faces_input.value = DEFAULT_FACE_COUNT
		if shape_input:
			_select_option_id(shape_input, DEFAULT_PORT_SHAPE)
		if slot_layout_input:
			_select_option_id(slot_layout_input, DEFAULT_SLOT_LAYOUT)
	is_loading_target_config = false
	_apply_odf_type_option_constraints(odf_type)
	_rebuild_slot_faces()

func _apply_odf_type_option_constraints(odf_type: int) -> void:
	if shape_input:
		_set_option_disabled(shape_input, PORT_SHAPE_RJ45, odf_type != ODF_TYPE_CABINET)
		shape_input.disabled = odf_type == ODF_TYPE_CABINET
		if odf_type == ODF_TYPE_CABINET:
			_select_option_id(shape_input, CABINET_DEFAULT_PORT_SHAPE)
		elif shape_input.get_selected_id() == PORT_SHAPE_RJ45:
			_select_option_id(shape_input, DEFAULT_PORT_SHAPE)
	if slot_layout_input:
		slot_layout_input.disabled = odf_type == ODF_TYPE_CABINET
		if odf_type == ODF_TYPE_CABINET:
			_select_option_id(slot_layout_input, CABINET_DEFAULT_SLOT_LAYOUT)

func _set_option_disabled(option_button: OptionButton, option_id: int, disabled: bool) -> void:
	for item_index in range(option_button.item_count):
		if option_button.get_item_id(item_index) == option_id:
			option_button.set_item_disabled(item_index, disabled)
			return

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
	close_panel_only()

func close_panel_only() -> void:
	_store_current_target_config()
	visible = false
	close_cabinet_if_panels_closed()

func close_for_current_target() -> void:
	_store_current_target_config()
	if preview_overlay and preview_overlay.has_method("hide_preview"):
		preview_overlay.call("hide_preview")
	visible = false
	_close_current_target_cabinet()

func close_cabinet_if_panels_closed() -> void:
	if visible:
		return
	if preview_overlay and preview_overlay.visible:
		return
	_close_current_target_cabinet()

func _close_current_target_cabinet() -> void:
	if current_target and current_target.has_method("close_cabinet"):
		current_target.call("close_cabinet")

func _on_apply_pressed() -> void:
	var serialized_config: Dictionary = _serialize_current_config()
	_store_current_target_config()
	print("ModulePanel serialized config:")
	var serialized_json := JSON.stringify(serialized_config, "\t")
	print(serialized_json)
	if current_target:
		current_target.set_meta("module_config", serialized_config.duplicate(true))
	if api_request and api_request.has_method("save_odf_detail"):
		var cabinet_id := str(serialized_config.get("cabinet_id", "")).strip_edges()
		if cabinet_id != "":
			if status_label:
				status_label.text = "正在保存 ODF 详情..."
			api_request.call("save_odf_detail", cabinet_id, serialized_json)
			return
	if status_label:
		status_label.text = "已打印当前插槽配置 JSON，未接入 ODF 保存接口"

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
	return _normalize_shape_for_odf_type(shape_input.get_selected_id(), _get_odf_type())

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

func _build_card_state(port_count: int, ports: Array, card_type: String = CARD_TYPE_NORMAL) -> Dictionary:
	return {
		"card_type": card_type,
		"port_count": port_count,
		"ports": _resize_port_state(ports, port_count),
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
	_clear_port_grid_now()
	if face_slot_cards.is_empty():
		return

	var content_column := VBoxContainer.new()
	content_column.add_theme_constant_override("separation", 10)
	content_column.alignment = BoxContainer.ALIGNMENT_BEGIN
	content_column.size_flags_horizontal = Control.SIZE_FILL
	content_column.size_flags_vertical = Control.SIZE_FILL
	port_grid.add_child(content_column)

	content_column.add_child(_create_preview_legend())

	var slot_root: VBoxContainer = VBoxContainer.new()
	slot_root.add_theme_constant_override("separation", SLOT_GAP)
	slot_root.size_flags_horizontal = Control.SIZE_FILL
	content_column.add_child(slot_root)
	var preview_minimum := _get_preview_minimum_size(_get_slot_count(), _get_slot_spec())
	preview_minimum.y += 54.0
	port_grid.custom_minimum_size = preview_minimum

	for slot_index in range(_get_slot_count()):
		slot_root.add_child(_create_slot_group(current_face_index, slot_index, _get_slot_spec()))

func _create_preview_legend() -> Control:
	var legend_panel := PanelContainer.new()
	legend_panel.size_flags_horizontal = Control.SIZE_FILL
	legend_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	legend_panel.add_theme_stylebox_override("panel", _create_preview_legend_stylebox())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	legend_panel.add_child(margin)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.alignment = BoxContainer.ALIGNMENT_BEGIN
	content.size_flags_horizontal = Control.SIZE_FILL
	margin.add_child(content)

	var title := Label.new()
	title.text = ""
	title.add_theme_color_override("font_color", PREVIEW_LEGEND_TEXT_COLOR)
	title.add_theme_font_size_override("font_size", 14)
	content.add_child(title)

	var items_row := HBoxContainer.new()
	items_row.add_theme_constant_override("separation", 12)
	items_row.size_flags_horizontal = Control.SIZE_FILL
	content.add_child(items_row)

	var items := [
		{"label": "空闲口", "color": Color(0.10, 0.12, 0.14, 0.18), "border": Color(0.78, 0.82, 0.86, 0.7), "mark": ""},
		{"label": "空闲芯", "color": Color(0.24, 0.57, 0.92, 0.72), "border": Color(0.73, 0.85, 0.98, 0.95), "mark": ""},
		{"label": "正常", "color": Color(0.16, 0.72, 0.29, 0.72), "border": Color(0.73, 0.95, 0.79, 0.95), "mark": ""},
		{"label": "高衰耗", "color": Color(0.94, 0.76, 0.18, 0.76), "border": Color(0.99, 0.9, 0.59, 0.98), "mark": ""},
		{"label": "坏芯", "color": Color(0.9, 0.16, 0.12, 0.74), "border": Color(0.98, 0.75, 0.72, 0.98), "mark": ""},
		{"label": "坏端口", "color": Color(0.9, 0.16, 0.12, 0.86), "border": Color(0.99, 0.84, 0.81, 1.0), "mark": "×"},
	]
	for item in items:
		items_row.add_child(_create_preview_legend_item(str(item["label"]), item["color"], item["border"], str(item["mark"])))

	return legend_panel

func _create_preview_legend_stylebox() -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = PREVIEW_LEGEND_BG_COLOR
	style_box.border_color = PREVIEW_LEGEND_BORDER_COLOR
	style_box.set_border_width_all(1)
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	style_box.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	style_box.shadow_size = 4
	style_box.shadow_offset = Vector2(1, 2)
	return style_box

func _create_preview_legend_item(label_text: String, fill_color: Color, border_color: Color, mark_text: String = "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var swatch_holder := CenterContainer.new()
	swatch_holder.custom_minimum_size = Vector2(22, 18)
	row.add_child(swatch_holder)

	var swatch := PanelContainer.new()
	swatch.custom_minimum_size = Vector2(18, 14)
	swatch.add_theme_stylebox_override("panel", _create_preview_legend_swatch_stylebox(fill_color, border_color))
	swatch_holder.add_child(swatch)

	if mark_text != "":
		var mark := Label.new()
		mark.text = mark_text
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.add_theme_color_override("font_color", Color(0.99, 0.99, 1.0, 0.98))
		mark.add_theme_font_size_override("font_size", 14)
		mark.size_flags_horizontal = Control.SIZE_FILL
		mark.size_flags_vertical = Control.SIZE_FILL
		swatch.add_child(mark)

	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", PREVIEW_LEGEND_MUTED_TEXT_COLOR)
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)
	return row

func _create_preview_legend_swatch_stylebox(fill_color: Color, border_color: Color) -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = fill_color
	style_box.border_color = border_color
	style_box.set_border_width_all(1)
	style_box.corner_radius_top_left = 3
	style_box.corner_radius_top_right = 3
	style_box.corner_radius_bottom_left = 3
	style_box.corner_radius_bottom_right = 3
	return style_box

func _clear_port_grid_now() -> void:
	if not port_grid:
		return
	for child in port_grid.get_children():
		port_grid.remove_child(child)
		child.free()
	port_grid.custom_minimum_size = Vector2.ZERO

func _get_preview_minimum_size(slot_count: int, slot_spec: int) -> Vector2:
	var card_size: Vector2 = _get_card_slot_size(CARD_MENU_PORT_12)
	var slot_content_width: float = card_size.x + SLOT_PADDING * 2.0
	var slot_content_height: float = card_size.y + SLOT_PADDING * 2.0
	if _get_slot_layout() == SLOT_LAYOUT_HORIZONTAL:
		slot_content_height = slot_spec * card_size.y + max(0, slot_spec - 1) * CARD_GAP + SLOT_PADDING * 2.0
	else:
		slot_content_width = slot_spec * card_size.x + max(0, slot_spec - 1) * CARD_GAP + SLOT_PADDING * 2.0
	slot_content_height += SLOT_CUBE_TOP_DEPTH + SLOT_CONTENT_TOP_EXTRA
	var total_width: float = slot_content_width + 24.0
	var total_height: float = slot_count * slot_content_height + max(0, slot_count - 1) * SLOT_GAP + 24.0
	return Vector2(total_width, total_height)

func _create_slot_group(face_index: int, slot_index: int, slot_spec: int) -> Control:
	var slot_wrapper: HBoxContainer = HBoxContainer.new()
	slot_wrapper.name = "SlotWrapper_%d_%d" % [face_index, slot_index]
	slot_wrapper.size_flags_horizontal = Control.SIZE_FILL

	var slot_panel: PanelContainer = PanelContainer.new()
	slot_panel.script = SLOT_GROUP_SCRIPT
	slot_panel.drag_enabled = false
	slot_panel.draw_dashed_outline = true
	slot_panel.slot_index = slot_index
	slot_panel.script = SLOT_GROUP_SCRIPT
	slot_panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
	slot_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot_panel.add_theme_stylebox_override("panel", _create_slot_stylebox())

	var cards_root: BoxContainer
	if _get_slot_layout() == SLOT_LAYOUT_HORIZONTAL:
		cards_root = VBoxContainer.new()
	else:
		cards_root = HBoxContainer.new()
	cards_root.name = "CardsRoot_%d_%d" % [face_index, slot_index]
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
	style_box.content_margin_top = SLOT_PADDING + SLOT_CUBE_TOP_DEPTH + SLOT_CONTENT_TOP_EXTRA
	style_box.content_margin_right = SLOT_PADDING
	style_box.content_margin_bottom = SLOT_PADDING
	return style_box

func _create_card_stylebox(has_ports: bool = false) -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = CARD_METAL_BACKGROUND_COLOR if has_ports else CARD_BACKGROUND_COLOR
	style_box.border_color = CARD_METAL_BORDER_COLOR if has_ports else CARD_BORDER_COLOR
	style_box.set_border_width_all(1)
	style_box.shadow_color = CARD_SHADOW_COLOR
	style_box.shadow_size = 5
	style_box.shadow_offset = Vector2(2, 3)
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
	card_wrapper.name = "CardWrapper_%d_%d_%d" % [face_index, slot_index, card_index]
	card_wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card_wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	card_wrapper.add_theme_constant_override("separation", CARD_LOCK_GAP)

	var is_switch_card := _is_switch_card(face_index, slot_index, card_index)
	var has_ports := _get_card_port_count(face_index, slot_index, card_index) > 0

	var card_panel: PanelContainer = PanelContainer.new()
	card_panel.script = SLOT_GROUP_SCRIPT
	card_panel.controller = self
	card_panel.face_index = face_index
	card_panel.slot_index = slot_index
	card_panel.card_index = card_index
	card_panel.slot_layout = _get_slot_layout()
	card_panel.drag_enabled = true
	card_panel.draw_dashed_outline = false
	card_panel.draw_metal_surface = has_ports
	card_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card_panel.add_theme_stylebox_override("panel", _create_card_stylebox(has_ports))
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

	var content: BoxContainer = HBoxContainer.new() if is_switch_card else VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", SWITCH_PORT_GAP if is_switch_card else CARD_PORT_GAP)
	card_panel.add_child(content)

	if is_switch_card:
		content.add_child(_create_switch_blank_space())
		content.add_child(_create_switch_ports_grid(face_index, slot_index, card_index))
	else:
		var ports_grid: GridContainer = GridContainer.new()
		ports_grid.columns = _get_card_grid_columns(CARD_MENU_PORT_12)
		ports_grid.add_theme_constant_override("h_separation", CARD_PORT_GAP)
		ports_grid.add_theme_constant_override("v_separation", CARD_PORT_GAP)
		ports_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		for port_index in range(CARD_MENU_PORT_12):
			ports_grid.add_child(_create_card_port_button(face_index, slot_index, card_index, port_index))
		content.add_child(ports_grid)

	return card_wrapper

func _create_switch_blank_space() -> Control:
	var blank_space := PanelContainer.new()
	blank_space.custom_minimum_size = Vector2(_get_switch_blank_width(), SWITCH_PORT_HEIGHT * 2.0 + SWITCH_PORT_GAP)
	blank_space.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	blank_space.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	blank_space.add_theme_stylebox_override("panel", _create_switch_blank_stylebox())
	return blank_space

func _create_switch_ports_grid(face_index: int, slot_index: int, card_index: int) -> GridContainer:
	var ports_grid := GridContainer.new()
	ports_grid.columns = SWITCH_PORT_COLUMNS
	ports_grid.add_theme_constant_override("h_separation", SWITCH_PORT_GAP)
	ports_grid.add_theme_constant_override("v_separation", SWITCH_PORT_GAP)
	ports_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for port_index in range(SWITCH_PORT_COUNT):
		ports_grid.add_child(_create_switch_port_button(face_index, slot_index, card_index, port_index))
	return ports_grid

func _get_switch_blank_width() -> float:
	return 4.0 * CARD_PORT_SIZE + 3.0 * CARD_PORT_GAP

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
	var active_port_count: int = _get_card_port_count(face_index, slot_index, card_index)
	var is_active_port: bool = port_index < active_port_count
	var use_rj45_style := _get_odf_type() == ODF_TYPE_CABINET and _get_port_shape() == PORT_SHAPE_RJ45 and is_active_port
	var port_button: Button = RJ45_PORT_BUTTON_SCRIPT.new() if use_rj45_style else OPTICAL_PORT_BUTTON_SCRIPT.new() if is_active_port else Button.new()
	port_button.custom_minimum_size = Vector2(CARD_PORT_SIZE, CARD_PORT_SIZE)
	port_button.flat = false
	port_button.toggle_mode = false
	port_button.focus_mode = Control.FOCUS_NONE
	port_button.disabled = not is_active_port
	port_button.mouse_filter = Control.MOUSE_FILTER_STOP if is_active_port else Control.MOUSE_FILTER_IGNORE
	_apply_port_tooltip_theme(port_button)
	var port_state := _get_card_port_state(face_index, slot_index, card_index, port_index)
	port_button.button_pressed = is_active_port and _should_port_button_appear_pressed(port_state)
	_update_port_button(port_button, face_index, slot_index, card_index, port_index)
	if is_active_port:
		port_button.pressed.connect(_on_card_port_pressed.bind(face_index, slot_index, card_index, port_index, port_button))
		port_button.gui_input.connect(_on_port_button_gui_input.bind(face_index, slot_index, card_index, port_index, port_button))
	return port_button

func _create_switch_port_button(face_index: int, slot_index: int, card_index: int, port_index: int) -> Button:
	var port_button: Button = RJ45_PORT_BUTTON_SCRIPT.new()
	port_button.custom_minimum_size = Vector2(SWITCH_PORT_WIDTH, SWITCH_PORT_HEIGHT)
	port_button.flat = false
	port_button.toggle_mode = false
	port_button.focus_mode = Control.FOCUS_NONE
	_apply_port_tooltip_theme(port_button)
	var port_state := _get_card_port_state(face_index, slot_index, card_index, port_index)
	port_button.button_pressed = _should_port_button_appear_pressed(port_state)
	_update_switch_port_button(port_button, face_index, slot_index, card_index, port_index)
	port_button.pressed.connect(_on_card_port_pressed.bind(face_index, slot_index, card_index, port_index, port_button))
	port_button.gui_input.connect(_on_port_button_gui_input.bind(face_index, slot_index, card_index, port_index, port_button))
	return port_button

func _on_card_port_pressed(face_index: int, slot_index: int, card_index: int, port_index: int, port_button: Button) -> void:
	var current_state := _get_card_port_state(face_index, slot_index, card_index, port_index)
	var next_state := _get_next_cycle_port_state(current_state)
	_set_port_state(face_index, slot_index, card_index, port_index, next_state["status"], next_state["is_bad"])
	if _is_switch_card(face_index, slot_index, card_index):
		_update_switch_port_button(port_button, face_index, slot_index, card_index, port_index)
	else:
		_update_port_button(port_button, face_index, slot_index, card_index, port_index)
	_refresh_summary()
	_store_current_target_config()

func _update_switch_port_button(port_button: Button, face_index: int, slot_index: int, card_index: int, port_index: int) -> void:
	var port_state := _get_card_port_state(face_index, slot_index, card_index, port_index)
	var port_color: Color = _get_port_status_color(port_state)
	port_button.text = ""
	if port_button.has_method("set_port_visual"):
		port_button.call("set_port_visual", port_index < SWITCH_PORT_COLUMNS, int(port_state.get("status", PORT_STATUS_EMPTY)), _variant_to_bool(port_state.get("is_bad", false)))
	port_button.add_theme_stylebox_override("normal", _create_port_stylebox(false, false))
	port_button.add_theme_stylebox_override("hover", _create_port_stylebox(false, false))
	port_button.add_theme_stylebox_override("pressed", _create_port_stylebox(false, false))
	port_button.add_theme_stylebox_override("hover_pressed", _create_port_stylebox(false, false))
	port_button.add_theme_color_override("font_color", port_color)
	port_button.add_theme_color_override("font_focus_color", port_color)
	port_button.add_theme_color_override("font_hover_color", port_color)
	port_button.add_theme_color_override("font_hover_pressed_color", port_color)
	port_button.add_theme_color_override("font_pressed_color", port_color)
	port_button.button_pressed = _should_port_button_appear_pressed(port_state)
	port_button.tooltip_text = _build_port_tooltip(face_index, slot_index, card_index, port_index, port_state, true)

func _update_port_button(port_button: Button, face_index: int, slot_index: int, card_index: int, port_index: int) -> void:
	var is_active_port: bool = port_index < _get_card_port_count(face_index, slot_index, card_index)
	var port_state := _get_card_port_state(face_index, slot_index, card_index, port_index)
	var port_color: Color = CARD_PLACEHOLDER_PORT_COLOR
	if not is_active_port:
		port_button.text = ""
		port_button.add_theme_stylebox_override("normal", _create_port_stylebox(false, false))
		port_button.add_theme_stylebox_override("hover", _create_port_stylebox(false, false))
		port_button.add_theme_stylebox_override("pressed", _create_port_stylebox(false, false))
		port_button.add_theme_stylebox_override("hover_pressed", _create_port_stylebox(false, false))
		port_button.add_theme_stylebox_override("disabled", _create_port_stylebox(false, false))
		port_button.add_theme_color_override("font_color", port_color)
		port_button.add_theme_color_override("font_disabled_color", port_color)
		port_button.add_theme_color_override("font_focus_color", port_color)
		port_button.add_theme_color_override("font_hover_color", port_color)
		port_button.add_theme_color_override("font_hover_pressed_color", port_color)
		port_button.add_theme_color_override("font_pressed_color", port_color)
		port_button.tooltip_text = "占位\n%s" % _get_port_location_label(face_index, slot_index, card_index, port_index, false)
		return
	if is_active_port:
		port_color = _get_port_status_color(port_state)
	if port_button.has_method("set_optical_visual"):
		port_button.text = ""
		port_button.call("set_optical_visual", _get_port_shape(), int(port_state.get("status", PORT_STATUS_EMPTY)), _variant_to_bool(port_state.get("is_bad", false)))
		port_button.add_theme_stylebox_override("normal", _create_port_stylebox(false, false))
		port_button.add_theme_stylebox_override("hover", _create_port_stylebox(false, false))
		port_button.add_theme_stylebox_override("pressed", _create_port_stylebox(false, false))
		port_button.add_theme_stylebox_override("hover_pressed", _create_port_stylebox(false, false))
		port_button.add_theme_stylebox_override("disabled", _create_port_stylebox(false, false))
	elif port_button.has_method("set_port_visual"):
		port_button.text = ""
		port_button.call("set_port_visual", true, int(port_state.get("status", PORT_STATUS_EMPTY)), _variant_to_bool(port_state.get("is_bad", false)))
		port_button.add_theme_stylebox_override("normal", _create_port_stylebox(false, false))
		port_button.add_theme_stylebox_override("hover", _create_port_stylebox(false, false))
		port_button.add_theme_stylebox_override("pressed", _create_port_stylebox(false, false))
		port_button.add_theme_stylebox_override("hover_pressed", _create_port_stylebox(false, false))
		port_button.add_theme_stylebox_override("disabled", _create_port_stylebox(false, false))
	else:
		port_button.text = "▣" if _get_port_shape() == PORT_SHAPE_SQUARE else "◉"
		port_button.add_theme_font_size_override("font_size", 22)
		var is_emphasized := _should_port_button_appear_pressed(port_state)
		port_button.add_theme_stylebox_override("normal", _create_port_stylebox(is_active_port, false, false, is_emphasized))
		port_button.add_theme_stylebox_override("hover", _create_port_stylebox(is_active_port, false, true, is_emphasized))
		port_button.add_theme_stylebox_override("pressed", _create_port_stylebox(is_active_port, true, false, is_emphasized))
		port_button.add_theme_stylebox_override("hover_pressed", _create_port_stylebox(is_active_port, true, true, is_emphasized))
		port_button.add_theme_stylebox_override("disabled", _create_port_stylebox(is_active_port, false, false, is_emphasized))
	port_button.add_theme_color_override("font_color", port_color)
	port_button.add_theme_color_override("font_disabled_color", port_color)
	port_button.add_theme_color_override("font_focus_color", port_color)
	port_button.add_theme_color_override("font_hover_color", port_color)
	port_button.add_theme_color_override("font_hover_pressed_color", port_color)
	port_button.add_theme_color_override("font_pressed_color", port_color)
	port_button.button_pressed = _should_port_button_appear_pressed(port_state)
	port_button.tooltip_text = _build_port_tooltip(face_index, slot_index, card_index, port_index, port_state, false)

func _create_port_stylebox(is_active_port: bool, is_pressed: bool, is_hover: bool = false, is_occupied: bool = false) -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	if not is_active_port:
		style_box.bg_color = Color(1, 1, 1, 0)
		style_box.border_color = Color(1, 1, 1, 0)
		style_box.set_content_margin_all(0)
		return style_box
	style_box.bg_color = PORT_SOCKET_PRESSED_BG_COLOR if is_pressed else PORT_SOCKET_HOVER_BG_COLOR if is_hover else PORT_SOCKET_BG_COLOR
	style_box.border_color = PORT_SOCKET_ACTIVE_BORDER_COLOR if is_occupied else PORT_SOCKET_BORDER_COLOR
	style_box.border_width_left = 2
	style_box.border_width_top = 4
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.corner_radius_top_left = 2
	style_box.corner_radius_top_right = 2
	style_box.corner_radius_bottom_left = 2
	style_box.corner_radius_bottom_right = 2
	style_box.shadow_color = PORT_SOCKET_SHADOW_COLOR
	style_box.shadow_size = 2
	style_box.shadow_offset = Vector2(1, 1)
	style_box.content_margin_left = 1
	style_box.content_margin_top = 4
	style_box.content_margin_right = 1
	style_box.content_margin_bottom = 1
	return style_box

func _create_switch_blank_stylebox() -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.12, 0.13, 0.13, 1.0)
	style_box.border_color = Color(0.8, 0.83, 0.83, 0.85)
	style_box.set_border_width_all(1)
	style_box.corner_radius_top_left = 2
	style_box.corner_radius_top_right = 2
	style_box.corner_radius_bottom_left = 2
	style_box.corner_radius_bottom_right = 2
	return style_box

func _on_subcard_slot_gui_input(event: InputEvent, face_index: int, slot_index: int, card_index: int, card_panel: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_show_card_context_menu(face_index, slot_index, card_index, card_panel.get_screen_position() + event.position)
		card_panel.accept_event()

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
	var face_index := int(pending_card_context.get("face_index", current_face_index))
	var slot_index := int(pending_card_context.get("slot_index", 0))
	var card_index := int(pending_card_context.get("card_index", 0))
	if port_count == CARD_MENU_SWITCH:
		_set_switch_card(face_index, slot_index, card_index)
	else:
		if port_count == CARD_MENU_CLEAR:
			port_count = 0
		_set_card_port_count(
			face_index,
			slot_index,
			card_index,
			port_count
		)
	pending_card_context.clear()
	_refresh_port_view()
	_store_current_target_config()

func _set_card_port_count(face_index: int, slot_index: int, card_index: int, port_count: int) -> void:
	var card_state: Dictionary = _get_card_state(face_index, slot_index, card_index)
	card_state["card_type"] = CARD_TYPE_NORMAL
	card_state["port_count"] = port_count
	card_state["ports"] = _resize_port_state(card_state.get("ports", []), port_count)
	face_slot_cards[face_index][slot_index][card_index] = card_state

func _set_switch_card(face_index: int, slot_index: int, card_index: int) -> void:
	var card_state: Dictionary = _get_card_state(face_index, slot_index, card_index)
	card_state["card_type"] = CARD_TYPE_SWITCH
	card_state["port_count"] = SWITCH_PORT_COUNT
	card_state["ports"] = _resize_port_state(card_state.get("ports", []), SWITCH_PORT_COUNT)
	face_slot_cards[face_index][slot_index][card_index] = card_state

func _resize_port_state(existing_ports: Variant, port_count: int) -> Array:
	var resized_ports: Array = []
	resized_ports.resize(port_count)
	for port_index in range(port_count):
		var raw_port: Variant = null
		if existing_ports is Array and port_index < existing_ports.size():
			raw_port = existing_ports[port_index]
		resized_ports[port_index] = _normalize_port_state(raw_port)
	return resized_ports

func _variant_to_bool(value: Variant) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT:
			return int(value) != 0
		TYPE_FLOAT:
			return not is_zero_approx(float(value))
		TYPE_STRING:
			var normalized := str(value).strip_edges().to_lower()
			return normalized == "true" or normalized == "1" or normalized == "yes"
		TYPE_NIL:
			return false
		_:
			return true

func _build_default_port_state() -> Dictionary:
	return {
		"status": PORT_STATUS_EMPTY,
		"is_bad": false,
		"cable_id": "",
		"fiber_core_index": 0,
	}

func _normalize_port_state(raw_port: Variant) -> Dictionary:
	var normalized := _build_default_port_state()
	if raw_port is Dictionary:
		var port_status := int(raw_port.get("status", PORT_STATUS_EMPTY))
		if port_status != PORT_STATUS_NORMAL and port_status != PORT_STATUS_HIGH_LOSS and port_status != PORT_STATUS_BROKEN_CORE and port_status != PORT_STATUS_FREE_CORE:
			port_status = PORT_STATUS_EMPTY
		normalized["status"] = port_status
		normalized["is_bad"] = _variant_to_bool(raw_port.get("is_bad", raw_port.get("bad_port", false)))
		normalized["cable_id"] = str(raw_port.get("cable_id", raw_port.get("fiber_cable_id", raw_port.get("cable", ""))))
		normalized["fiber_core_index"] = max(0, int(raw_port.get("fiber_core_index", raw_port.get("core_index", raw_port.get("fiber_no", 0)))))
	elif _variant_to_bool(raw_port):
		normalized["status"] = PORT_STATUS_BROKEN_CORE
	if _variant_to_bool(normalized.get("is_bad", false)):
		normalized["status"] = PORT_STATUS_EMPTY
	if str(normalized.get("cable_id", "")).strip_edges() == "":
		normalized["fiber_core_index"] = 0
	return normalized

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

func _is_switch_card(face_index: int, slot_index: int, card_index: int) -> bool:
	return str(_get_card_state(face_index, slot_index, card_index).get("card_type", CARD_TYPE_NORMAL)) == CARD_TYPE_SWITCH

func _get_card_port_state(face_index: int, slot_index: int, card_index: int, port_index: int) -> Dictionary:
	var ports: Array = _get_card_state(face_index, slot_index, card_index).get("ports", [])
	if port_index >= ports.size():
		return _build_default_port_state()
	return _normalize_port_state(ports[port_index])

func _set_port_state(face_index: int, slot_index: int, card_index: int, port_index: int, status: int, is_bad: bool) -> void:
	var card_state: Dictionary = _get_card_state(face_index, slot_index, card_index)
	var ports: Array = _resize_port_state(card_state.get("ports", []), int(card_state.get("port_count", 0)))
	if port_index >= ports.size():
		return
	var current_port_state := _normalize_port_state(ports[port_index])
	ports[port_index] = {
		"status": PORT_STATUS_EMPTY if is_bad else status,
		"is_bad": is_bad,
		"cable_id": str(current_port_state.get("cable_id", "")),
		"fiber_core_index": int(current_port_state.get("fiber_core_index", 0)),
	}
	card_state["ports"] = ports
	face_slot_cards[face_index][slot_index][card_index] = card_state

func _set_port_cable_selection(face_index: int, slot_index: int, card_index: int, port_index: int, cable_id: String, fiber_core_index: int) -> void:
	var card_state: Dictionary = _get_card_state(face_index, slot_index, card_index)
	var ports: Array = _resize_port_state(card_state.get("ports", []), int(card_state.get("port_count", 0)))
	if port_index >= ports.size():
		return
	var current_port_state := _normalize_port_state(ports[port_index])
	ports[port_index] = {
		"status": int(current_port_state.get("status", PORT_STATUS_EMPTY)),
		"is_bad": _variant_to_bool(current_port_state.get("is_bad", false)),
		"cable_id": cable_id,
		"fiber_core_index": fiber_core_index if cable_id != "" else 0,
	}
	card_state["ports"] = ports
	face_slot_cards[face_index][slot_index][card_index] = card_state

func _get_mock_port_cables() -> Array:
	return PORT_CABLE_MOCK_DATA.get_cables() if PORT_CABLE_MOCK_DATA else []

func _find_mock_port_cable(cable_id: String) -> Dictionary:
	for cable in _get_mock_port_cables():
		if cable is Dictionary and str(cable.get("id", "")) == cable_id:
			return cable
	return {}

func _populate_port_cable_options(selected_cable_id: String) -> void:
	if not port_fiber_type_input:
		return
	port_fiber_type_input.clear()
	port_fiber_type_input.add_item("请选择光缆", -1)
	port_fiber_type_input.set_item_metadata(0, "")
	var selected_index := 0
	for cable in _get_mock_port_cables():
		if not cable is Dictionary:
			continue
		var item_index := port_fiber_type_input.item_count
		var cable_id := str(cable.get("id", ""))
		var cable_name := str(cable.get("name", cable_id))
		var core_count := int(cable.get("core_count", 0))
		port_fiber_type_input.add_item("%s (%d芯)" % [cable_name, core_count], item_index)
		port_fiber_type_input.set_item_metadata(item_index, cable_id)
		if cable_id == selected_cable_id:
			selected_index = item_index
	port_fiber_type_input.select(selected_index)

func _get_selected_port_cable_id() -> String:
	if not port_fiber_type_input:
		return ""
	var selected_index := port_fiber_type_input.selected
	if selected_index < 0 or selected_index >= port_fiber_type_input.item_count:
		return ""
	return str(port_fiber_type_input.get_item_metadata(selected_index))

func _refresh_port_fiber_core_input(cable_id: String, selected_core_index: int) -> void:
	if not port_fiber_core_input:
		return
	var cable := _find_mock_port_cable(cable_id)
	if cable.is_empty():
		port_fiber_core_input.editable = false
		port_fiber_core_input.min_value = 0
		port_fiber_core_input.max_value = 0
		port_fiber_core_input.value = 0
		port_fiber_core_input.tooltip_text = "请先选择光缆"
		return
	var core_count := maxf(1, int(cable.get("core_count", 1)))
	port_fiber_core_input.editable = true
	port_fiber_core_input.min_value = 1
	port_fiber_core_input.max_value = core_count
	port_fiber_core_input.value = clampi(selected_core_index if selected_core_index > 0 else 1, 1, core_count)
	port_fiber_core_input.tooltip_text = "可输入 1 到 %d 的纤芯序号" % core_count

func _get_next_cycle_port_state(port_state: Dictionary) -> Dictionary:
	if _variant_to_bool(port_state.get("is_bad", false)):
		return {
			"status": PORT_STATUS_EMPTY,
			"is_bad": false,
		}
	match int(port_state.get("status", PORT_STATUS_EMPTY)):
		PORT_STATUS_EMPTY:
			return {"status": PORT_STATUS_FREE_CORE, "is_bad": false}
		PORT_STATUS_FREE_CORE:
			return {"status": PORT_STATUS_NORMAL, "is_bad": false}
		PORT_STATUS_NORMAL:
			return {"status": PORT_STATUS_HIGH_LOSS, "is_bad": false}
		PORT_STATUS_HIGH_LOSS:
			return {"status": PORT_STATUS_BROKEN_CORE, "is_bad": false}
		_:
			return {"status": PORT_STATUS_EMPTY, "is_bad": false}

func _should_port_button_appear_pressed(port_state: Dictionary) -> bool:
	return _variant_to_bool(port_state.get("is_bad", false)) or int(port_state.get("status", PORT_STATUS_EMPTY)) != PORT_STATUS_EMPTY

func _get_port_status_label(port_state: Dictionary) -> String:
	if _variant_to_bool(port_state.get("is_bad", false)):
		return "坏端口"
	match int(port_state.get("status", PORT_STATUS_EMPTY)):
		PORT_STATUS_FREE_CORE:
			return "空闲芯"
		PORT_STATUS_NORMAL:
			return "正常"
		PORT_STATUS_HIGH_LOSS:
			return "高衰耗"
		PORT_STATUS_BROKEN_CORE:
			return "坏芯"
		_:
			return "空闲口"

func _get_port_cable_label(port_state: Dictionary) -> String:
	var cable_id := str(port_state.get("cable_id", "")).strip_edges()
	if cable_id == "":
		return "未选择光缆"
	var cable_info := _find_mock_port_cable(cable_id)
	var cable_name := str(cable_info.get("name", cable_id)).strip_edges()
	var fiber_core_index := maxi(0, int(port_state.get("fiber_core_index", 0)))
	if fiber_core_index <= 0:
		return "%s，未选纤芯" % cable_name
	return "%s，第%d芯" % [cable_name, fiber_core_index]

func _get_port_location_label(face_index: int, slot_index: int, card_index: int, port_index: int, is_switch_card: bool) -> String:
	return "Face %d，插槽 %d，%s %d，端口 %d" % [
		face_index + 1,
		slot_index + 1,
		"交换机子卡" if is_switch_card else "子卡",
		card_index + 1,
		port_index + 1,
	]

func _build_port_tooltip(face_index: int, slot_index: int, card_index: int, port_index: int, port_state: Dictionary, is_switch_card: bool) -> String:
	return "%s\n%s\n%s" % [
		_get_port_cable_label(port_state),
		_get_port_status_label(port_state),
		_get_port_location_label(face_index, slot_index, card_index, port_index, is_switch_card),
	]

func _get_port_status_color(port_state: Dictionary) -> Color:
	if _variant_to_bool(port_state.get("is_bad", false)):
		return Color(0.9, 0.16, 0.12, 1.0)
	match int(port_state.get("status", PORT_STATUS_EMPTY)):
		PORT_STATUS_FREE_CORE:
			return Color(0.24, 0.57, 0.92, 1.0)
		PORT_STATUS_NORMAL:
			return Color(0.16, 0.72, 0.29, 1.0)
		PORT_STATUS_HIGH_LOSS:
			return Color(0.94, 0.76, 0.18, 1.0)
		PORT_STATUS_BROKEN_CORE:
			return Color(0.9, 0.16, 0.12, 1.0)
		_:
			return Color(0.72, 0.76, 0.78, 1.0)

func _on_port_button_gui_input(event: InputEvent, face_index: int, slot_index: int, card_index: int, port_index: int, port_button: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_show_port_context_menu(face_index, slot_index, card_index, port_index, port_button.get_screen_position() + event.position)
		port_button.accept_event()

func _show_port_context_menu(face_index: int, slot_index: int, card_index: int, port_index: int, popup_position: Vector2) -> void:
	pending_port_context = {
		"face_index": face_index,
		"slot_index": slot_index,
		"card_index": card_index,
		"port_index": port_index,
	}
	var port_state := _get_card_port_state(face_index, slot_index, card_index, port_index)
	is_syncing_port_context_ui = true
	_populate_port_cable_options(str(port_state.get("cable_id", "")))
	_refresh_port_fiber_core_input(str(port_state.get("cable_id", "")), int(port_state.get("fiber_core_index", 0)))
	for status_id in port_status_buttons.keys():
		var status_button := port_status_buttons[status_id] as BaseButton
		if status_button:
			status_button.set_pressed_no_signal(int(port_state.get("status", PORT_STATUS_EMPTY)) == int(status_id) and not _variant_to_bool(port_state.get("is_bad", false)))
	if bad_port_check:
		bad_port_check.set_pressed_no_signal(_variant_to_bool(port_state.get("is_bad", false)))
	is_syncing_port_context_ui = false
	port_context_popup.position = Vector2i(popup_position)
	port_context_popup.reset_size()
	port_context_popup.popup()

func _on_port_fiber_type_selected(_index: int) -> void:
	if is_syncing_port_context_ui or pending_port_context.is_empty():
		return
	var cable_id := _get_selected_port_cable_id()
	var current_core_index := int(port_fiber_core_input.value) if port_fiber_core_input else 0
	is_syncing_port_context_ui = true
	_refresh_port_fiber_core_input(cable_id, current_core_index)
	is_syncing_port_context_ui = false
	_commit_pending_port_cable_selection()

func _on_port_fiber_core_changed(value: float) -> void:
	if is_syncing_port_context_ui or pending_port_context.is_empty():
		return
	if not port_fiber_core_input or not port_fiber_core_input.editable:
		return
	_commit_pending_port_cable_selection(int(round(value)))

func _commit_pending_port_cable_selection(explicit_core_index: int = -1) -> void:
	if pending_port_context.is_empty():
		return
	var face_index := int(pending_port_context.get("face_index", current_face_index))
	var slot_index := int(pending_port_context.get("slot_index", 0))
	var card_index := int(pending_port_context.get("card_index", 0))
	var port_index := int(pending_port_context.get("port_index", 0))
	var cable_id := _get_selected_port_cable_id()
	var core_index := 0
	if cable_id != "" and port_fiber_core_input and port_fiber_core_input.editable:
		core_index = explicit_core_index if explicit_core_index > 0 else int(round(port_fiber_core_input.value))
	_set_port_cable_selection(face_index, slot_index, card_index, port_index, cable_id, core_index)
	_store_current_target_config()

func _on_port_status_button_pressed(status: int) -> void:
	if is_syncing_port_context_ui or pending_port_context.is_empty():
		return
	_apply_port_context_selection(status, false)

func _on_bad_port_toggled(pressed: bool) -> void:
	if is_syncing_port_context_ui or pending_port_context.is_empty():
		return
	_apply_port_context_selection(PORT_STATUS_EMPTY, pressed)

func _on_set_empty_port_pressed() -> void:
	if pending_port_context.is_empty():
		return
	_apply_port_context_selection(PORT_STATUS_EMPTY, false)

func _apply_port_context_selection(status: int, is_bad: bool) -> void:
	var face_index := int(pending_port_context.get("face_index", current_face_index))
	var slot_index := int(pending_port_context.get("slot_index", 0))
	var card_index := int(pending_port_context.get("card_index", 0))
	var port_index := int(pending_port_context.get("port_index", 0))
	_set_port_state(face_index, slot_index, card_index, port_index, status, is_bad)
	pending_port_context.clear()
	if port_context_popup:
		port_context_popup.hide()
	_refresh_port_view()
	_store_current_target_config()

func _refresh_summary() -> void:
	var slot_count: int = _get_slot_count()
	var slot_spec: int = _get_slot_spec()
	var total_faces: int = _get_total_faces()
	var _shape_text: String = "圆形" if _get_port_shape() == PORT_SHAPE_CIRCLE else "方形"
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
					for port_state in card_state.get("ports", []):
						if _should_port_button_appear_pressed(_normalize_port_state(port_state)):
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
	return face_index < face_card_locks.size() and slot_index < face_card_locks[face_index].size() and card_index < face_card_locks[face_index][slot_index].size() and _variant_to_bool(face_card_locks[face_index][slot_index][card_index])

func _toggle_card_locked(face_index: int, slot_index: int, card_index: int) -> void:
	if face_index >= face_card_locks.size() or slot_index >= face_card_locks[face_index].size() or card_index >= face_card_locks[face_index][slot_index].size():
		return
	face_card_locks[face_index][slot_index][card_index] = not _variant_to_bool(face_card_locks[face_index][slot_index][card_index])

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
	var moved_lock: bool = _variant_to_bool(face_card_locks[face_index][slot_index][source_card_index])
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
	if preview_overlay and preview_overlay.has_method("show_for_target"):
		preview_overlay.call("show_for_target", target)
	visible = true
	_request_remote_target_config(target)

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
	_apply_target_config(stored_config)

func _apply_target_config(stored_config: Dictionary) -> void:
	if stored_config.is_empty():
		return

	is_loading_target_config = true
	if odf_type_input:
		_select_option_id(odf_type_input, int(stored_config.get("odf_type", stored_config.get("type", DEFAULT_ODF_TYPE))))
	var odf_type := _get_odf_type()
	row_input.value = int(stored_config.get("slot_count", stored_config.get("rows", _get_default_slot_count_for_type(odf_type))))
	col_input.value = int(stored_config.get("slot_spec", stored_config.get("cols", _get_default_slot_spec_for_type(odf_type))))
	faces_input.value = int(stored_config.get("faces", _get_default_face_count_for_type(odf_type)))
	if shape_input:
		_select_option_id(shape_input, _normalize_shape_for_odf_type(int(stored_config.get("shape", _get_default_port_shape_for_type(odf_type))), odf_type))
	if slot_layout_input:
		_select_option_id(slot_layout_input, int(stored_config.get("slot_layout", _get_default_slot_layout_for_type(odf_type))))
	_apply_odf_type_option_constraints(odf_type)
	face_slot_cards = _sanitize_face_slot_cards(stored_config.get("face_slot_cards", []), _get_slot_count(), _get_slot_spec(), _get_total_faces())
	face_card_locks = _sanitize_card_locks(stored_config.get("card_locks", stored_config.get("slot_locks", [])), _get_slot_count(), _get_slot_spec(), _get_total_faces())
	current_face_index = clamp(int(stored_config.get("current_face_index", 0)), 0, max(0, _get_total_faces() - 1))
	is_loading_target_config = false
	_refresh_port_view()

func _request_remote_target_config(target: Node3D) -> void:
	var cabinet_id := _ensure_target_id(target)
	pending_remote_cabinet_id = cabinet_id
	if not api_request or not api_request.has_method("fetch_odf_detail"):
		pending_remote_cabinet_id = ""
		return
	if status_label:
		status_label.text = "正在加载 ODF 详情..."
	api_request.call("fetch_odf_detail", cabinet_id)

func _on_odf_detail_received(odf_id: String, payload: Variant) -> void:
	if odf_id != pending_remote_cabinet_id:
		return
	if not current_target or _ensure_target_id(current_target) != odf_id:
		return
	pending_remote_cabinet_id = ""
	var remote_config := _extract_odf_config(payload)
	push_warning("Received ODF config for cabinet_id %s: %s" % [odf_id, str(remote_config)])
	if remote_config.is_empty():
		if status_label:
			status_label.text = "未返回 ODF 详情，继续使用当前配置"
		return
	cabinet_configs[odf_id] = remote_config.duplicate(true)
	current_target.set_meta("module_config", remote_config.duplicate(true))
	_apply_target_config(remote_config)
	_refresh_preview_overlay()
	if status_label:
		status_label.text = "已加载 ODF 详情"

func _on_odf_detail_failed(odf_id: String, _message: String, _response_code: int) -> void:
	if odf_id != pending_remote_cabinet_id:
		return
	pending_remote_cabinet_id = ""
	if status_label:
		status_label.text = "ODF 详情加载失败，已使用当前配置"

func _on_odf_save_completed(odf_id: String, _payload: Variant) -> void:
	if not current_target or _ensure_target_id(current_target) != odf_id:
		return
	if status_label:
		status_label.text = "ODF 详情已保存"

func _on_odf_save_failed(odf_id: String, _message: String, _response_code: int) -> void:
	if not current_target or _ensure_target_id(current_target) != odf_id:
		return
	if status_label:
		status_label.text = "ODF 详情保存失败"

func _extract_odf_config(payload: Variant) -> Dictionary:
	match typeof(payload):
		TYPE_DICTIONARY:
			var payload_dict := payload as Dictionary
			if _looks_like_odf_config(payload_dict):
				return payload_dict.duplicate(true)
			for key in ["json", "odf_json", "config", "data", "result"]:
				if payload_dict.has(key):
					var nested_config := _extract_odf_config(payload_dict[key])
					if not nested_config.is_empty():
						return nested_config
			for nested_value in payload_dict.values():
				var nested_config := _extract_odf_config(nested_value)
				if not nested_config.is_empty():
					return nested_config
		TYPE_STRING:
			var normalized := str(payload).strip_edges()
			if normalized == "":
				return {}
			var json := JSON.new()
			if json.parse(normalized) == OK:
				return _extract_odf_config(json.data)
	return {}

func _looks_like_odf_config(payload: Dictionary) -> bool:
	return payload.has("face_slot_cards") or payload.has("card_locks") or payload.has("slot_count") or payload.has("slot_spec") or payload.has("faces")

func _store_current_target_config() -> void:
	if not current_target or is_loading_target_config:
		return
	var cabinet_id: String = _ensure_target_id(current_target)
	var config: Dictionary = _serialize_current_config()
	cabinet_configs[cabinet_id] = config.duplicate(true)
	current_target.set_meta("module_config", config.duplicate(true))

func _refresh_preview_overlay() -> void:
	if current_target and preview_overlay and preview_overlay.visible and preview_overlay.has_method("show_for_target"):
		preview_overlay.call("show_for_target", current_target)

func _serialize_current_config() -> Dictionary:
	var cabinet_id := _ensure_target_id(current_target) if current_target else ""
	var odf_type := _get_odf_type()
	var port_shape := _normalize_shape_for_odf_type(_get_port_shape(), odf_type)
	var slot_layout := _get_slot_layout()
	if odf_type == ODF_TYPE_CABINET:
		slot_layout = CABINET_DEFAULT_SLOT_LAYOUT
	return {
		"odf_id": cabinet_id,
		"cabinet_id": cabinet_id,
		"odf_type": odf_type,
		"type": odf_type,
		"slot_count": _get_slot_count(),
		"slot_spec": _get_slot_spec(),
		"faces": _get_total_faces(),
		"shape": port_shape,
		"slot_layout": slot_layout,
		"current_face_index": current_face_index,
		"card_locks": face_card_locks.duplicate(true),
		"face_slot_cards": face_slot_cards.duplicate(true),
	}

func _build_default_config(odf_type: int = DEFAULT_ODF_TYPE) -> Dictionary:
	var slot_count := _get_default_slot_count_for_type(odf_type)
	var slot_spec := _get_default_slot_spec_for_type(odf_type)
	var total_faces := _get_default_face_count_for_type(odf_type)
	return {
		"slot_count": slot_count,
		"slot_spec": slot_spec,
		"faces": total_faces,
		"odf_type": odf_type,
		"type": odf_type,
		"shape": _get_default_port_shape_for_type(odf_type),
		"slot_layout": _get_default_slot_layout_for_type(odf_type),
		"current_face_index": 0,
		"card_locks": _build_default_card_locks(total_faces, slot_count, slot_spec),
		"face_slot_cards": _build_default_face_slot_cards(total_faces, slot_count, slot_spec),
	}

func _build_default_face_slot_cards(total_faces: int, slot_count: int, slot_spec: int) -> Array:
	var default_faces: Array = []
	for _face_index in range(total_faces):
		default_faces.append(_create_face_slot_data(slot_count, slot_spec))
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
				var card_type := str(source_card.get("card_type", CARD_TYPE_NORMAL))
				var port_count := int(source_card.get("port_count", 0))
				if card_type == CARD_TYPE_SWITCH:
					port_count = SWITCH_PORT_COUNT
				else:
					card_type = CARD_TYPE_NORMAL
				if card_type == CARD_TYPE_NORMAL and port_count != CARD_MENU_PORT_12 and port_count != CARD_MENU_PORT_8 and port_count != CARD_MENU_PORT_6:
					port_count = 0
				sanitized_cards.append(_build_card_state(port_count, _resize_port_state(source_card.get("ports", []), port_count), card_type))
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
				sanitized_cards[card_index] = not (card_index < source_slot.size() and not _variant_to_bool(source_slot[card_index]))
			sanitized_slots.append(sanitized_cards)
		sanitized_faces.append(sanitized_slots)
	return sanitized_faces

func _select_option_id(option_button: OptionButton, option_id: int) -> void:
	for item_index in range(option_button.item_count):
		if option_button.get_item_id(item_index) == option_id:
			option_button.select(item_index)
			return
	if option_button.item_count > 0:
		option_button.select(0)

func _get_odf_type() -> int:
	if not odf_type_input:
		return DEFAULT_ODF_TYPE
	return odf_type_input.get_selected_id()

func _normalize_shape_for_odf_type(shape: int, odf_type: int) -> int:
	if odf_type == ODF_TYPE_CABINET:
		return CABINET_DEFAULT_PORT_SHAPE
	if shape == PORT_SHAPE_RJ45:
		return DEFAULT_PORT_SHAPE
	return shape

func _get_default_slot_count_for_type(odf_type: int) -> int:
	return CABINET_DEFAULT_SLOT_COUNT if odf_type == ODF_TYPE_CABINET else DEFAULT_SLOT_COUNT

func _get_default_slot_spec_for_type(odf_type: int) -> int:
	return CABINET_DEFAULT_SLOT_SPEC if odf_type == ODF_TYPE_CABINET else DEFAULT_SLOT_SPEC

func _get_default_face_count_for_type(odf_type: int) -> int:
	return CABINET_DEFAULT_FACE_COUNT if odf_type == ODF_TYPE_CABINET else DEFAULT_FACE_COUNT

func _get_default_port_shape_for_type(odf_type: int) -> int:
	return CABINET_DEFAULT_PORT_SHAPE if odf_type == ODF_TYPE_CABINET else DEFAULT_PORT_SHAPE

func _get_default_slot_layout_for_type(odf_type: int) -> int:
	return CABINET_DEFAULT_SLOT_LAYOUT if odf_type == ODF_TYPE_CABINET else DEFAULT_SLOT_LAYOUT

func _ensure_target_id(target: Node3D) -> String:
	if target.has_method("ensure_persistent_id"):
		return str(target.call("ensure_persistent_id"))
	if target.has_meta("module_cabinet_id"):
		return str(target.get_meta("module_cabinet_id"))
	var cabinet_id: String = "cab_%013d_%s" % [int(Time.get_unix_time_from_system() * 1000.0), str(target.get_instance_id())]
	target.set_meta("module_cabinet_id", cabinet_id)
	return cabinet_id
