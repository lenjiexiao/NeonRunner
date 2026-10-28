class_name Orb
extends Area2D
## 能量球：碰到 +10m，上下漂浮 + 旋转。

signal collected(orb: Orb)

var t := 0.0
var base_y := 0.0

func _ready() -> void:
	t = randf() * 6.28
	base_y = position.y
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 17.0
	cs.shape = circle
	add_child(cs)
	body_entered.connect(_on_body)

func _process(delta: float) -> void:
	t += delta
	rotation = t * 1.8
	position.y = base_y + sin(t * 3.0) * 5.0

func _on_body(body: Node) -> void:
	if body is Player:
		collected.emit(self)
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 17.0, Color(1.0, 0.85, 0.1, 0.12)) # 光晕
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -12.0), Vector2(12.0, 0.0), Vector2(0.0, 12.0), Vector2(-12.0, 0.0)
	]), Color(1.0, 0.85, 0.1))
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 1.0, 0.85))
