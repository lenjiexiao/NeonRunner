class_name Player
extends CharacterBody2D
## 玩家小方块：跳跃手感三件套（土狼时间 / 输入缓冲 / 二段跳）+ 弹性动画。

signal jumped(is_double: bool)

const GRAVITY := 2400.0
const JUMP_VELOCITY := -780.0
const DOUBLE_JUMP_VELOCITY := -700.0
const COYOTE_TIME := 0.12
const BUFFER_TIME := 0.12
const HALF := 18.0

var world_moving := false # 是否在跑（控制脚下火花）
var double_jump_available := true

var _coyote_timer := 0.0
var _buffer_timer := 0.0
var _was_on_floor := true
var _sparks: CPUParticles2D

func _ready() -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(HALF * 2.0 - 4.0, HALF * 2.0 - 4.0)
	cs.shape = rect
	add_child(cs)

	_sparks = CPUParticles2D.new()
	_sparks.position = Vector2(-HALF + 2.0, HALF - 3.0)
	_sparks.emitting = false
	_sparks.amount = 24
	_sparks.lifetime = 0.35
	_sparks.direction = Vector2(-1.0, -0.35)
	_sparks.spread = 22.0
	_sparks.initial_velocity_min = 70.0
	_sparks.initial_velocity_max = 110.0
	_sparks.gravity = Vector2(0.0, 500.0)
	_sparks.scale_amount_min = 2.0
	_sparks.scale_amount_max = 3.5
	_sparks.color = Color(0.0, 0.95, 1.0, 0.55)
	add_child(_sparks)

func reset(x: float, y: float) -> void:
	position = Vector2(x, y)
	velocity = Vector2.ZERO
	rotation = 0.0
	scale = Vector2.ONE
	double_jump_available = true
	_coyote_timer = 0.0
	_buffer_timer = 0.0
	_was_on_floor = true
	visible = true
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	_coyote_timer = maxf(0.0, _coyote_timer - delta)
	_buffer_timer = maxf(0.0, _buffer_timer - delta)

	if is_on_floor():
		_coyote_timer = COYOTE_TIME
		double_jump_available = true

	velocity.y += GRAVITY * delta
	velocity.x = 0.0

	_try_consume_buffer()
	move_and_slide()

	# 落地压扁
	if is_on_floor() and not _was_on_floor:
		_squash(Vector2(1.35, 0.65))
	_was_on_floor = is_on_floor()

	# 脚下火花只在跑动时喷
	_sparks.emitting = world_moving and is_on_floor()

	# 空中轻微前倾
	var target_rot := 0.0
	if not is_on_floor():
		target_rot = clampf(velocity.y / 2800.0, -0.2, 0.45)
	rotation = lerpf(rotation, target_rot, 10.0 * delta)

func request_jump() -> void:
	_buffer_timer = BUFFER_TIME
	_try_consume_buffer()

func release_jump() -> void:
	# 提前松手 → 跳矮一点（可变跳跃高度）
	if velocity.y < 0.0:
		velocity.y *= 0.55

func _try_consume_buffer() -> void:
	if _buffer_timer <= 0.0:
		return
	if _coyote_timer > 0.0:
		_do_jump(false)
	elif not is_on_floor() and double_jump_available:
		_do_jump(true)

func _do_jump(is_double: bool) -> void:
	velocity.y = DOUBLE_JUMP_VELOCITY if is_double else JUMP_VELOCITY
	if is_double:
		double_jump_available = false
	else:
		_coyote_timer = 0.0
	_buffer_timer = 0.0
	jumped.emit(is_double)
	_squash(Vector2(0.7, 1.3))

func _squash(s: Vector2) -> void:
	scale = s
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	# 外发光
	draw_rect(Rect2(-HALF - 4.0, -HALF - 4.0, HALF * 2.0 + 8.0, HALF * 2.0 + 8.0),
		Color(0.0, 1.0, 1.0, 0.25), false, 3.0)
	# 暗底 + 亮面
	draw_rect(Rect2(-HALF, -HALF, HALF * 2.0, HALF * 2.0), Color(0.0, 0.3, 0.35))
	draw_rect(Rect2(-HALF + 3.0, -HALF + 3.0, HALF * 2.0 - 6.0, HALF * 2.0 - 6.0),
		Color(0.05, 0.95, 1.0))
	# 眼睛
	draw_rect(Rect2(-6.0, -8.0, 5.0, 9.0), Color(0.0, 0.08, 0.12))
	draw_rect(Rect2(3.0, -8.0, 5.0, 9.0), Color(0.0, 0.08, 0.12))
