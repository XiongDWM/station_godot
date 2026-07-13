extends RigidBody3D

func _ready():
	# 运行时由 HoseManager 配置；保留温和默认值作兜底
	if freeze:
		return
	mass = 0.2
	gravity_scale = 0.35
	linear_damp = 2.0
	angular_damp = 3.0
