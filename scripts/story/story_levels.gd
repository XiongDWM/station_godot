extends RefCounted

class_name StoryLevels

const STORY_HEIGHT := 3.0
const CEILING_Y_OFFSET := STORY_HEIGHT
const LOWER_MEZZANINE_FLOOR_OFFSET := -1.0
const LOWER_MEZZANINE_CEILING_OFFSET := 0.0
const UPPER_MEZZANINE_FLOOR_OFFSET := 1.0
const UPPER_MEZZANINE_CEILING_OFFSET := 1.8
const MEZZANINE_WALL_HEIGHT := 0.5
const DEFAULT_BUILDING_STORY_COUNT := 3
const ABSOLUTE_MAX_STORY_LEVEL := 99

const VIEW_LAYER_OFFSET := {
	-1: LOWER_MEZZANINE_FLOOR_OFFSET,
	0: 0.0,
	1: UPPER_MEZZANINE_FLOOR_OFFSET,
}

const FLOOR_KIND_ORDER := ["ground", "ceiling"]

const FLOOR_KIND_LABELS := {
	"ground": "地面",
	"ceiling": "天花板",
}

static func get_story_base(story_level: int) -> float:
	return float(maxi(story_level, 1) - 1) * STORY_HEIGHT

static func get_story_floor_top_y(story_level: int, grid_floor_top_y: float) -> float:
	return grid_floor_top_y + get_story_base(story_level)

static func get_view_layer_y(story_level: int, view_layer: int) -> float:
	return get_story_base(story_level) + float(VIEW_LAYER_OFFSET.get(view_layer, 0.0))

static func get_mezzanine_floor_y(story_level: int, grid_floor_top_y: float) -> float:
	return get_story_floor_top_y(story_level, grid_floor_top_y) + UPPER_MEZZANINE_FLOOR_OFFSET

static func get_mezzanine_ceiling_y(story_level: int, grid_floor_top_y: float) -> float:
	return get_story_floor_top_y(story_level, grid_floor_top_y) + UPPER_MEZZANINE_CEILING_OFFSET

static func get_floor_kind_y(story_level: int, floor_kind: String, grid_floor_top_y: float) -> float:
	match floor_kind:
		"ceiling":
			return get_story_floor_top_y(story_level, grid_floor_top_y) + CEILING_Y_OFFSET
		_:
			return get_story_floor_top_y(story_level, grid_floor_top_y)

static func get_floor_build_view_layer(floor_kind: String) -> int:
	return 0

static func is_revealable_floor_kind(floor_kind: String) -> bool:
	return floor_kind == "ground" or floor_kind == "ceiling"

static func get_reveal_view_layer(floor_kind: String) -> int:
	if floor_kind == "ceiling":
		return 1
	return -1

static func get_lower_mezzanine_floor_y(story_level: int, grid_floor_top_y: float) -> float:
	return get_story_floor_top_y(story_level, grid_floor_top_y) + LOWER_MEZZANINE_FLOOR_OFFSET

static func get_lower_mezzanine_ceiling_y(story_level: int, grid_floor_top_y: float) -> float:
	return get_story_floor_top_y(story_level, grid_floor_top_y) + LOWER_MEZZANINE_CEILING_OFFSET

static func is_mezzanine_runtime_layer(view_layer: int) -> bool:
	return view_layer == -1 or view_layer == 1

static func get_mezzanine_work_y(story_level: int, grid_floor_top_y: float) -> float:
	return get_mezzanine_floor_y(story_level, grid_floor_top_y)

static func get_mezzanine_trench_y(story_level: int, grid_floor_top_y: float) -> float:
	return get_mezzanine_ceiling_y(story_level, grid_floor_top_y)

static func get_lower_mezzanine_trench_y(story_level: int, grid_floor_top_y: float) -> float:
	return get_lower_mezzanine_ceiling_y(story_level, grid_floor_top_y)

static func uses_ceiling_tray_trench(view_layer: int) -> bool:
	return view_layer == 1

static func get_mezzanine_work_plane_y(story_level: int, view_layer: int, grid_floor_top_y: float) -> float:
	if view_layer == 1:
		return get_mezzanine_floor_y(story_level, grid_floor_top_y)
	if view_layer == -1:
		return get_lower_mezzanine_floor_y(story_level, grid_floor_top_y)
	return get_story_floor_top_y(story_level, grid_floor_top_y)

static func get_mezzanine_trench_plane_y(story_level: int, view_layer: int, grid_floor_top_y: float) -> float:
	if view_layer == 1:
		return get_mezzanine_trench_y(story_level, grid_floor_top_y)
	if view_layer == -1:
		return get_lower_mezzanine_trench_y(story_level, grid_floor_top_y)
	return get_story_floor_top_y(story_level, grid_floor_top_y)

static func get_mezzanine_air_wall_height(view_layer: int) -> float:
	if view_layer == -1:
		return LOWER_MEZZANINE_CEILING_OFFSET - LOWER_MEZZANINE_FLOOR_OFFSET
	if view_layer == 1:
		return UPPER_MEZZANINE_CEILING_OFFSET - UPPER_MEZZANINE_FLOOR_OFFSET
	return MEZZANINE_WALL_HEIGHT

static func cycle_floor_kind(current: String, direction: int) -> String:
	var index := FLOOR_KIND_ORDER.find(current)
	if index < 0:
		index = 0
	index = posmod(index + direction, FLOOR_KIND_ORDER.size())
	return FLOOR_KIND_ORDER[index]

static func get_floor_kind_label(floor_kind: String) -> String:
	return str(FLOOR_KIND_LABELS.get(floor_kind, floor_kind))

static func normalize_building_story_count(value: Variant) -> int:
	return clampi(int(value), 1, ABSOLUTE_MAX_STORY_LEVEL)

static func normalize_story_level(value: Variant, max_story: int = DEFAULT_BUILDING_STORY_COUNT) -> int:
	return clampi(int(value), 1, maxi(max_story, 1))

static func normalize_floor_kind(value: Variant) -> String:
	var kind := str(value)
	if kind == "mezzanine_floor":
		return "ground"
	if FLOOR_KIND_ORDER.has(kind):
		return kind
	return "ground"
