extends Node3D

const BuildingControllerScript = preload("res://scripts/controllers/building_controller.gd")
const LayoutSerializerScript = preload("res://scripts/serializers/layout_serializer.gd")
const LayoutFlowControllerScript = preload("res://scripts/controllers/layout_flow_controller.gd")
const SelectionControllerScript = preload("res://scripts/controllers/selection_controller.gd")

@export var grid_map: GridMap
@export var btn_cube: Button
@export var btn_wall: Button
@export var preview_cube: MeshInstance3D
@export var preview_wall: MeshInstance3D
@export var block_scene: PackedScene
@export var wall_scene: PackedScene
@export var module_panel: Panel
@export var operation_panel: Control 
@export var btn_rotate: Button
@export var btn_delete: Button
@export var btn_save:Button
@export var http_request:HTTPRequest
@export var btn_door: Button
@export var door_scene: PackedScene
@export var floor_brick_scene: PackedScene

var building_controller := BuildingControllerScript.new()
var layout_serializer := LayoutSerializerScript.new()
var layout_flow_controller := LayoutFlowControllerScript.new()
var selection_controller := SelectionControllerScript.new()

func _ready():
	# print("[MainScene._ready] btn_cube=", btn_cube, ", btn_wall=", btn_wall, ", preview_cube=", preview_cube, ", preview_wall=", preview_wall, ", block_scene=", block_scene, ", wall_scene=", wall_scene)
	building_controller.initialize(preview_cube, preview_wall)
	building_controller.bind_buttons(btn_cube, btn_wall, btn_door, block_scene, wall_scene, door_scene, preview_cube, preview_wall, self, &"_on_building_mode_selected")
	selection_controller.initialize(operation_panel, module_panel)
	selection_controller.bind_buttons(btn_rotate, btn_delete, self, &"_on_rotate_selected_object", &"_on_delete_selected_object")
	layout_flow_controller.setup(self, http_request, layout_serializer)
	layout_flow_controller.bind_save_button(btn_save)
	layout_flow_controller.bind_api_signals()
	layout_flow_controller.bootstrap()

func _on_building_mode_selected(scene: PackedScene, preview: MeshInstance3D):
	# print("[MainScene._on_building_mode_selected] scene=", scene, ", preview=", preview)
	building_controller.set_building_mode(scene, preview, operation_panel, module_panel)

func _process(_delta):
	if selection_controller.has_visible_panel(operation_panel, module_panel):
		return
	if building_controller.is_active() and building_controller.get_preview():
		building_controller.handle_preview_logic(self, grid_map)

func _unhandled_input(event):
	if building_controller.handle_unhandled_input(self, event):
		return
	selection_controller.handle_unhandled_input(self, event, operation_panel, module_panel)

func _input(event):
	if Input.is_key_pressed(KEY_CTRL):
		return

	if event is InputEventMouseButton and event.pressed:
		var hovered_control := get_viewport().gui_get_hovered_control()
		if hovered_control:
			return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if building_controller.is_active():
				building_controller.place_current_building(self)
				return
			selection_controller.handle_left_click_module(self, block_scene, module_panel)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if selection_controller.toggle_panels_on_right_click(operation_panel, module_panel):
				return
			selection_controller.handle_right_click_operation(self, grid_map, preview_cube, preview_wall, operation_panel)

func _on_rotate_selected_object():
	selection_controller.rotate_selected_object()

func _on_delete_selected_object():
	selection_controller.delete_selected_object(operation_panel)