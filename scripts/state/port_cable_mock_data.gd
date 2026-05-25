extends RefCounted

static func get_cables() -> Array:
	return [
		{
			"id": "mock_cable_1",
			"name": "光缆示例1",
			"core_count": 12,
		},
		{
			"id": "mock_cable_2",
			"name": "光缆示例2",
			"core_count": 24,
		},
		{
			"id": "mock_cable_3",
			"name": "光缆示例3",
			"core_count": 48,
		},
	]