class_name Obstacle
extends Area2D
## 障碍物：尖刺 / 方块 / 高柱（需二段跳）/ 浮空横梁（要压低身位钻过去）。
## 地面类的原点在底部中央，横梁的原点在中心。

enum Kind { SPIKE, BLOCK, PILLAR, BAR }

var kind := Kind.SPIKE
var w := 44.0
var h := 42.0
var color := Color(1.0, 0.16, 0.75)
var _phase := 0.0

func setup(k: int) -> void:
	kind = k
	match k:
		Kind.SPIKE:
			w = 44.0
			h = 42.0
			color = Color(1.0, 0.16, 0.75)
		Kind.BLOCK:
			w = 44.0
			h = 44.0
			color = Color(1.0, 0.55, 0.12)
		Kind.PILLAR:
			w = 34.0
			h = 112.0
			color = Color(1.0, 0.22, 0.30)
		Kind.BAR:
			w = 150.0
			h = 26.0
			color = Color(0.75, 0.30, 1.0)

	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	if kind == Kind.SPIKE:
		rect.size = Vector2(w * 0.55, h * 0.7)
		cs.position = Vector2(0.0, -h * 0.35)
	elif kind == Kind.BAR:
		rect.size = Vector2(w - 8.0, h - 4.0)
	else:
		rect.size = Vector2(w - 6.0, h - 6.0)
		cs.position = Vector2(0.0, -h / 2.0)
	cs.shape = rect
	add_child(cs)
	_phase = randf() * 6.28

func _process(delta: float) -> void:
	_phase += delta
	# 轻微呼吸式闪烁
	modulate.a = 0.88 + 0.12 * sin(_phase * 5.0)

func _draw() -> void:
	if kind == Kind.SPIKE:
		var outline := PackedVector2Array([
			Vector2(-w / 2.0, 0.0),
			Vector2(w / 2.0, 0.0),
			Vector2(0.0, -h),
			Vector2(-w / 2.0, 0.0),
		])
		draw_colored_polygon(outline, Color(color.r * 0.25, color.g * 0.25, color.b * 0.3))
		draw_polyline(outline, Color(color.r, color.g, color.b, 0.3), 8.0) # 发光晕
		draw_polyline(outline, color, 3.0)
	else:
		var rect := Rect2(-w / 2.0, -h / 2.0, w, h)
		if kind != Kind.BAR:
			rect = Rect2(-w / 2.0, -h, w, h)
		draw_rect(rect.grow(5.0), Color(color.r, color.g, color.b, 0.22), false, 4.0) # 发光晕
		draw_rect(rect, Color(color.r * 0.22, color.g * 0.22, color.b * 0.3))
		draw_rect(rect, color, false, 3.0)
		if kind == Kind.BLOCK: # 内部小细节
			draw_rect(Rect2(-w / 4.0, -h * 0.75, w / 2.0, h / 4.0), color, false, 2.0)
