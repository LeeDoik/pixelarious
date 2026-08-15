class_name Starfield
extends Node2D
## 카메라에 붙는 배경: 아래로 쏟아지는 별똥별 2겹 + 성운. "거슬러 오른다"의 그림.

func _ready() -> void:
	z_index = -10
	for cfg in [
		{"amount": 30, "vel": 40.0, "alpha": 0.35, "size": 1.0},
		{"amount": 16, "vel": 90.0, "alpha": 0.7, "size": 2.0},
	]:
		var p := CPUParticles2D.new()
		p.amount = cfg.amount
		p.lifetime = 8.0
		p.preprocess = 8.0
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(Tuning.VIEW_W / 2.0 + 20.0, Tuning.VIEW_H / 2.0 + 40.0)
		p.direction = Vector2(0, 1)
		p.spread = 5.0
		p.gravity = Vector2.ZERO
		p.initial_velocity_min = cfg.vel * 0.7
		p.initial_velocity_max = cfg.vel
		p.scale_amount_min = cfg.size
		p.scale_amount_max = cfg.size
		p.color = Color(1.0, 0.95, 0.91, cfg.alpha)   # #FFF1E8
		add_child(p)
	for i in range(2):
		var neb := Sprite2D.new()
		neb.texture = load("res://assets/img/nebula_%s.png" % ["a", "b"][i])
		neb.modulate.a = 0.5
		neb.position = Vector2([-60.0, 70.0][i], [-140.0, 100.0][i])
		neb.z_index = -5
		add_child(neb)
