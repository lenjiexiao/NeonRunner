extends Node2D
## 霓虹快跑 Neon Runner — 主控制器
## 操作：空格 / ↑ / W / 鼠标左键 跳跃（空中可再跳一次），R 重开，Esc 退出。

const GROUND_Y := 520.0
const PLAYER_X := 270.0
const START_SPEED := 350.0
const MAX_SPEED := 1000.0
const ACCEL := 9.5
const PX_PER_METER := 60.0
const ORB_BONUS := 10
const SPAWN_X := 1230.0
const CFG_PATH := "user://neon_runner.cfg"

enum State { MENU, RUN, DEAD }

var state := State.MENU
var speed := START_SPEED
var distance := 0.0
var scroll_px := 0.0
var best := 0
var next_spawn_at := 480.0
var bonus_meters := 0
var orbs_collected := 0
var death_stamp := 0.0
var flash := 0.0
var shake_time := 0.0
var _last_milestone := 0
var _new_record := false

var world: Node2D
var player: Player
var camera: Camera2D
var bg_mat: ShaderMaterial
var score_label: Label
var best_label: Label
var menu_ui: Control
var gameover_ui: Control
var go_stats: Label
var go_orbs: Label
var go_best: Label
var _dim_rect: ColorRect
var _prompt_labels: Array[Label] = []
var _menu_tween: Tween
var _font: SystemFont

var sfx_jump: AudioStreamPlayer
var sfx_djump: AudioStreamPlayer
var sfx_orb: AudioStreamPlayer
var sfx_death_a: AudioStreamPlayer
var sfx_death_b: AudioStreamPlayer
var sfx_milestone: AudioStreamPlayer

func _ready() -> void:
	randomize()
	_load_best()
	_build_font()
	_build_background()
	_build_audio()
	_build_world()
	_build_ui()
	_enter_menu()

# ---------- 搭建 ----------

func _build_font() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei", "sans-serif"])

func _build_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -100
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_mat = ShaderMaterial.new()
	bg_mat.shader = load("res://shaders/neon_bg.gdshader")
	rect.material = bg_mat
	layer.add_child(rect)

func _build_audio() -> void:
	sfx_jump = _ap(NeonAudio.tone(280.0, 540.0, 0.12, 0.45, "square"))
	sfx_djump = _ap(NeonAudio.tone(380.0, 760.0, 0.12, 0.4, "square"))
	sfx_orb = _ap(NeonAudio.tone(880.0, 1400.0, 0.09, 0.35, "sine"))
	sfx_death_a = _ap(NeonAudio.tone(220.0, 55.0, 0.45, 0.5, "saw"))
	sfx_death_b = _ap(NeonAudio.tone(0.0, 0.0, 0.35, 0.35, "noise"))
	sfx_milestone = _ap(NeonAudio.tone(660.0, 660.0, 0.16, 0.3, "sine"))

func _ap(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	return p

func _build_world() -> void:
	camera = Camera2D.new()
	camera.position = Vector2(576.0, 324.0)
	add_child(camera)
	camera.make_current()

	# 地面（物理）
	var ground := StaticBody2D.new()
	ground.position = Vector2(600.0, GROUND_Y + 30.0)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(3200.0, 60.0)
	cs.shape = r
	ground.add_child(cs)
	add_child(ground)

	# 地面霓虹线
	var glow := Line2D.new()
	glow.points = PackedVector2Array([Vector2(-400.0, GROUND_Y), Vector2(1600.0, GROUND_Y)])
	glow.width = 14.0
	glow.default_color = Color(0.0, 1.0, 1.0, 0.15)
	add_child(glow)
	var line := Line2D.new()
	line.points = PackedVector2Array([Vector2(-400.0, GROUND_Y), Vector2(1600.0, GROUND_Y)])
	line.width = 3.5
	line.default_color = Color(0.1, 1.0, 1.0)
	add_child(line)

	# 障碍物容器
	world = Node2D.new()
	add_child(world)

	# 玩家
	player = Player.new()
	player.reset(PLAYER_X, GROUND_Y - 16.5)
	add_child(player)
	player.jumped.connect(_on_player_jumped)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	score_label = _label("0 m", 46, Color(0.9, 1.0, 1.0))
	score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	score_label.offset_top = 10.0
	layer.add_child(score_label)

	best_label = _label("", 20, Color(0.2, 0.9, 1.0, 0.8))
	best_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	best_label.offset_top = 68.0
	layer.add_child(best_label)

	# 主菜单
	menu_ui = Control.new()
	menu_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(menu_ui)
	var box := _center_box(menu_ui)
	box.add_child(_label("霓虹快跑", 96, Color(0.1, 0.95, 1.0)))
	box.add_child(_label("N E O N   R U N", 30, Color(1.0, 0.2, 0.8)))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0.0, 34.0)
	box.add_child(sp)
	var prompt := _label("按 空格 / 鼠标点击 起跑", 28, Color(1.0, 1.0, 1.0))
	box.add_child(prompt)
	_prompt_labels.append(prompt)

	# 结算界面
	gameover_ui = Control.new()
	gameover_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gameover_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameover_ui.visible = false
	layer.add_child(gameover_ui)
	_dim_rect = ColorRect.new()
	_dim_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim_rect.color = Color(0.02, 0.0, 0.06, 0.0)
	_dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameover_ui.add_child(_dim_rect)
	var gbox := _center_box(gameover_ui)
	gbox.add_child(_label("GAME OVER", 80, Color(1.0, 0.25, 0.35)))
	go_stats = _label("", 40, Color(1.0, 1.0, 1.0))
	go_orbs = _label("", 26, Color(1.0, 0.85, 0.2))
	go_best = _label("", 26, Color(0.2, 0.9, 1.0))
	gbox.add_child(go_stats)
	gbox.add_child(go_orbs)
	gbox.add_child(go_best)
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0.0, 24.0)
	gbox.add_child(sp2)
	var prompt2 := _label("按 空格 重新开始", 26, Color(1.0, 1.0, 1.0))
	gbox.add_child(prompt2)
	_prompt_labels.append(prompt2)

func _center_box(parent: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 16)
	parent.add_child(box)
	return box

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# ---------- 流程 ----------

func _enter_menu() -> void:
	_reset_run()
	state = State.MENU
	menu_ui.visible = true
	gameover_ui.visible = false
	best_label.text = ("最高纪录 %d m" % best) if best > 0 else ""
	# 待机呼吸动画
	_menu_tween = create_tween().set_loops()
	_menu_tween.tween_property(player, "scale", Vector2(1.08, 0.94), 0.8).set_ease(Tween.EASE_IN_OUT)
	_menu_tween.tween_property(player, "scale", Vector2(0.94, 1.08), 0.8).set_ease(Tween.EASE_IN_OUT)

func _start_run() -> void:
	if _menu_tween:
		_menu_tween.kill()
		_menu_tween = null
	player.scale = Vector2.ONE
	_reset_run()
	state = State.RUN
	menu_ui.visible = false
	player.world_moving = true

func _restart() -> void:
	if _menu_tween:
		_menu_tween.kill()
		_menu_tween = null
	_reset_run()
	state = State.RUN
	gameover_ui.visible = false
	player.world_moving = true

func _reset_run() -> void:
	for c in world.get_children():
		c.queue_free()
	speed = START_SPEED
	distance = 0.0
	bonus_meters = 0
	orbs_collected = 0
	next_spawn_at = 480.0
	_last_milestone = 0
	_new_record = false
	flash = 0.0
	shake_time = 0.0
	player.world_moving = false
	player.reset(PLAYER_X, GROUND_Y - 16.5)
	score_label.text = "0 m"

# ---------- 主循环 ----------

func _physics_process(delta: float) -> void:
	match state:
		State.MENU:
			scroll_px += 60.0 * delta
		State.RUN:
			speed = minf(speed + ACCEL * delta, MAX_SPEED)
			distance += speed * delta
			scroll_px = distance
			_move_world(-speed * delta)
			_spawner()
			_score_hud()

func _process(delta: float) -> void:
	flash = maxf(0.0, flash - delta * 2.2)
	bg_mat.set_shader_parameter("flash", flash)
	bg_mat.set_shader_parameter("scroll", scroll_px * 0.0035)

	# 提示文字闪烁
	var blink := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.004)
	for l in _prompt_labels:
		l.modulate.a = blink

	# 镜头震动
	if shake_time > 0.0:
		shake_time = maxf(0.0, shake_time - delta)
		var amp := 16.0 * (shake_time / 0.5)
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amp
	else:
		camera.offset = Vector2.ZERO

func _move_world(dx: float) -> void:
	for c in world.get_children():
		c.position.x += dx
		if c.position.x < -220.0:
			c.queue_free()

func _score_hud() -> void:
	var m := current_meters()
	score_label.text = "%d m" % m
	if m / 100 > _last_milestone:
		_last_milestone = m / 100
		sfx_milestone.play()
		var tw := create_tween()
		tw.tween_property(score_label, "scale", Vector2(1.35, 1.35), 0.08)
		tw.tween_property(score_label, "scale", Vector2.ONE, 0.18)

func current_meters() -> int:
	return int(distance / PX_PER_METER) + bonus_meters

# ---------- 障碍生成 ----------

func _spawner() -> void:
	if distance < next_spawn_at:
		return
	var pw := _spawn_pattern()
	var gap := clampf(speed * randf_range(0.62, 1.05), 240.0, 640.0)
	next_spawn_at = distance + pw + gap

func _spawn_pattern() -> float:
	var roll := randf()
	if roll < 0.20:
		_spawn_obstacle(Obstacle.Kind.SPIKE, SPAWN_X, GROUND_Y)
		return 44.0
	elif roll < 0.40:
		_spawn_obstacle(Obstacle.Kind.SPIKE, SPAWN_X, GROUND_Y)
		_spawn_obstacle(Obstacle.Kind.SPIKE, SPAWN_X + 50.0, GROUND_Y)
		return 94.0
	elif roll < 0.52:
		for i in 3:
			_spawn_obstacle(Obstacle.Kind.SPIKE, SPAWN_X + i * 50.0, GROUND_Y)
		_spawn_orb_arc(SPAWN_X + 100.0)
		return 190.0
	elif roll < 0.68:
		_spawn_obstacle(Obstacle.Kind.BLOCK, SPAWN_X, GROUND_Y)
		_spawn_orb_arc(SPAWN_X)
		return 60.0
	elif roll < 0.82:
		_spawn_obstacle(Obstacle.Kind.PILLAR, SPAWN_X, GROUND_Y)
		_spawn_orb(SPAWN_X - 45.0, GROUND_Y - 170.0)
		_spawn_orb(SPAWN_X + 45.0, GROUND_Y - 190.0)
		return 44.0
	else:
		_spawn_obstacle(Obstacle.Kind.BAR, SPAWN_X, GROUND_Y - 77.0)
		_spawn_orb(SPAWN_X - 48.0, GROUND_Y - 38.0)
		_spawn_orb(SPAWN_X + 48.0, GROUND_Y - 38.0)
		return 150.0

func _spawn_obstacle(kind: int, x: float, y: float) -> Obstacle:
	var o := Obstacle.new()
	o.setup(kind)
	o.position = Vector2(x, y)
	world.add_child(o)
	o.body_entered.connect(_on_obstacle_body)
	return o

func _spawn_orb(x: float, y: float) -> Orb:
	var o := Orb.new()
	o.position = Vector2(x, y)
	world.add_child(o)
	o.collected.connect(_on_orb_collected)
	return o

func _spawn_orb_arc(cx: float) -> void:
	_spawn_orb(cx - 80.0, GROUND_Y - 95.0)
	_spawn_orb(cx, GROUND_Y - 130.0)
	_spawn_orb(cx + 80.0, GROUND_Y - 95.0)

# ---------- 事件 ----------

func _on_player_jumped(is_double: bool) -> void:
	if is_double:
		sfx_djump.play()
	else:
		sfx_jump.play()

func _on_obstacle_body(body: Node) -> void:
	if body is Player and state == State.RUN:
		_die()

func _on_orb_collected(orb: Orb) -> void:
	orbs_collected += 1
	bonus_meters += ORB_BONUS
	sfx_orb.play()
	_burst(orb.position, Color(1.0, 0.85, 0.15), 12, 220.0, 0.4)
	_float_text(orb.position, "+%d m" % ORB_BONUS, Color(1.0, 0.9, 0.3))

func _die() -> void:
	state = State.DEAD
	death_stamp = Time.get_ticks_msec()
	flash = 1.0
	shake_time = 0.5
	player.world_moving = false
	_burst(player.position, Color(0.05, 0.95, 1.0), 40, 420.0, 0.8)
	player.visible = false
	player.set_physics_process(false)
	sfx_death_a.play()
	sfx_death_b.play()
	# 慢动作定格
	Engine.time_scale = 0.12
	await get_tree().create_timer(0.18, true, false, true).timeout
	Engine.time_scale = 1.0
	# 结算
	var m := current_meters()
	_new_record = m > best
	_save_best()
	await get_tree().create_timer(0.25).timeout
	_show_gameover(m)

func _show_gameover(m: int) -> void:
	go_stats.text = "跑了 %d m" % m
	go_orbs.text = "✦ 能量球 × %d（+%d m）" % [orbs_collected, orbs_collected * ORB_BONUS]
	go_best.text = ("新纪录！最高 %d m" % best) if _new_record else ("最高纪录 %d m" % best)
	gameover_ui.visible = true
	_dim_rect.color.a = 0.0
	var tw := create_tween()
	tw.tween_property(_dim_rect, "color:a", 0.62, 0.35)

# ---------- 输入 ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var e := event as InputEventKey
		if e.pressed and not e.echo:
			match e.keycode:
				KEY_SPACE, KEY_UP, KEY_W:
					_press()
				KEY_R:
					if state != State.MENU:
						_restart()
				KEY_ESCAPE:
					get_tree().quit()
		elif not e.pressed:
			match e.keycode:
				KEY_SPACE, KEY_UP, KEY_W:
					player.release_jump()
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.button_index == MOUSE_BUTTON_LEFT:
			if m.pressed:
				_press()
			else:
				player.release_jump()

func _press() -> void:
	match state:
		State.MENU:
			_start_run()
		State.RUN:
			player.request_jump()
		State.DEAD:
			if Time.get_ticks_msec() - death_stamp > 700:
				_restart()

# ---------- 特效 ----------

func _burst(pos: Vector2, color: Color, amount: int, vel: float, life: float) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = vel * 0.6
	p.initial_velocity_max = vel
	p.direction = Vector2(0.0, -1.0)
	p.gravity = Vector2(0.0, 500.0)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color
	world.add_child(p)
	var tw := create_tween()
	tw.tween_interval(life + 0.6)
	tw.tween_callback(p.queue_free)

func _float_text(pos: Vector2, txt: String, color: Color) -> void:
	var l := _label(txt, 24, color)
	l.position = pos + Vector2(-20.0, -30.0)
	world.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 46.0, 0.7).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(l.queue_free)

# ---------- 存档 ----------

func _load_best() -> void:
	var cf := ConfigFile.new()
	if cf.load(CFG_PATH) == OK:
		best = int(cf.get_value("run", "best", 0))

func _save_best() -> void:
	var m := current_meters()
	if m > best:
		best = m
	var cf := ConfigFile.new()
	cf.set_value("run", "best", best)
	cf.save(CFG_PATH)
