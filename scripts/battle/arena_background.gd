class_name ArenaBackground
extends Node2D

## 竞技场背景：夜空、远城堡、看台、双方战旗、火把与地面法阵。
## 纯绘制节点，不参与战斗逻辑；每 1/30 秒重绘一次以驱动火光与尘埃。

const VIEW := Vector2(1600, 900)
const HORIZON := 260.0
const GOLD := Color("#e7c46b")
const BLUE := Color("#58a6ff")
const RED := Color("#ff6b7a")

var _time := 0.0
var _redraw_accum := 0.0
var _rng := RandomNumberGenerator.new()
var _stars: Array[Vector2] = []
var _windows: Array[Vector2] = []
var _motes: Array[Dictionary] = []
var _stones: Array[Dictionary] = []


func _ready() -> void:
	_rng.seed = 20261103
	for index in 80:
		_stars.append(Vector2(_rng.randf_range(20.0, 1580.0), _rng.randf_range(20.0, 350.0)))
	for tower_x in [210.0, 520.0, 1080.0, 1390.0]:
		for row in 4:
			for column in 3:
				_windows.append(Vector2(tower_x - 18.0 + column * 18.0, 230.0 + row * 42.0))
	for index in 46:
		_motes.append({
			"pos": Vector2(_rng.randf_range(160.0, 1440.0), _rng.randf_range(500.0, 860.0)),
			"phase": _rng.randf_range(0.0, TAU),
			"speed": _rng.randf_range(4.0, 16.0),
			"size": _rng.randf_range(0.8, 2.0),
		})
	for index in 70:
		_stones.append({
			"pos": Vector2(_rng.randf_range(100.0, 1500.0), _rng.randf_range(520.0, 880.0)),
			"size": _rng.randf_range(1.0, 4.0),
			"alpha": _rng.randf_range(0.05, 0.16),
		})
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_sync_viewport()
	_redraw_accum += delta
	if _redraw_accum >= 1.0 / 30.0:
		_redraw_accum = 0.0
		queue_redraw()


## 背景在 1600x900 的设计坐标里绘制，再整体缩放到当前逻辑视口。
## 这样窗口变宽/变高时不会露出空白，也不会改变每个装饰物的相对构图。
func _sync_viewport() -> void:
	var view_size := get_viewport_rect().size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		return
	var wanted := Vector2(view_size.x / VIEW.x, view_size.y / VIEW.y)
	if not scale.is_equal_approx(wanted):
		scale = wanted
		queue_redraw()


func _draw() -> void:
	_draw_sky()
	_draw_castle()
	_draw_stands()
	_draw_ground()
	_draw_banners()
	_draw_torch(92.0)
	_draw_torch(1508.0)
	_draw_motes()
	_draw_vignette()


func _draw_sky() -> void:
	var top := Color(0.012, 0.024, 0.043)
	var bottom := Color(0.075, 0.106, 0.157)
	var bands := 48
	for index in bands:
		var t := float(index) / float(bands - 1)
		var y := lerpf(0.0, HORIZON, float(index) / float(bands))
		var height := HORIZON / float(bands) + 1.5
		draw_rect(Rect2(0, y, VIEW.x, height), top.lerp(bottom, t))

	# 月亮与光晕
	var moon := Vector2(1285, 148)
	for index in range(7, 0, -1):
		draw_circle(moon, 48.0 + index * 14.0, Color(0.55, 0.7, 0.95, 0.012 * (8 - index)))
	draw_circle(moon, 48.0, Color(0.79, 0.85, 0.93, 0.85))
	draw_circle(moon + Vector2(-12, -8), 9.0, Color(0.69, 0.76, 0.86, 0.6))
	draw_circle(moon + Vector2(14, 14), 13.0, Color(0.7, 0.77, 0.87, 0.5))
	draw_circle(moon + Vector2(6, -18), 6.0, Color(0.72, 0.79, 0.88, 0.5))

	for index in _stars.size():
		var star := _stars[index]
		var twinkle := 0.25 + 0.25 * sin(_time * 1.4 + float(index))
		draw_circle(star, 1.8 if index % 5 == 0 else 1.0, Color(0.68, 0.79, 0.94, twinkle))

	# 薄云
	draw_set_transform(Vector2(360, 190), 0.0, Vector2(2.8, 0.30))
	draw_circle(Vector2.ZERO, 52.0, Color(0.13, 0.18, 0.26, 0.32))
	draw_circle(Vector2(110, 6), 38.0, Color(0.13, 0.18, 0.26, 0.26))
	draw_set_transform(Vector2(1010, 120), 0.0, Vector2(2.2, 0.25))
	draw_circle(Vector2.ZERO, 46.0, Color(0.13, 0.18, 0.26, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_castle() -> void:
	var stone := Color(0.035, 0.051, 0.075)
	var rim := Color(0.16, 0.22, 0.31, 0.52)

	# 主城墙与垛口
	draw_rect(Rect2(0, 328, VIEW.x, 146), stone)
	for x in range(-16, 1616, 58):
		draw_rect(Rect2(x, 306, 34, 26), stone)
		draw_line(Vector2(x, 306), Vector2(x + 34, 306), rim, 1.0)
	draw_line(Vector2(0, 328), Vector2(VIEW.x, 328), rim, 2.0)

	# 塔楼
	for tower_x in [210.0, 520.0, 1080.0, 1390.0]:
		draw_rect(Rect2(tower_x - 44, 176, 88, 294), stone.darkened(0.18))
		draw_rect(Rect2(tower_x - 54, 158, 108, 24), stone)
		draw_colored_polygon(PackedVector2Array([
			Vector2(tower_x - 62, 158),
			Vector2(tower_x, 112),
			Vector2(tower_x + 62, 158),
		]), stone.darkened(0.05))
		draw_line(Vector2(tower_x - 62, 158), Vector2(tower_x, 112), rim, 1.5)
		draw_line(Vector2(tower_x, 112), Vector2(tower_x + 62, 158), rim, 1.5)
		# 塔身砌缝
		for row in 5:
			var y := 206.0 + row * 44.0
			draw_line(Vector2(tower_x - 40, y), Vector2(tower_x + 40, y), Color(0.1, 0.14, 0.2, 0.35), 1.0)

	# 亮灯的窗户（固定种子 → 每次一样）
	for index in _windows.size():
		var window_pos := _windows[index]
		if index % 4 == 0:
			continue
		var glow := 0.55 + 0.15 * sin(_time * 1.1 + float(index))
		draw_rect(Rect2(window_pos, Vector2(7, 12)), Color(1.0, 0.78, 0.43, glow))

	# 城墙边缘的冷光
	for x in range(30, 1600, 120):
		draw_circle(Vector2(x, 430), 2.0, Color(0.55, 0.72, 0.95, 0.25))


func _draw_stands() -> void:
	# 城墙前的看台拱廊
	draw_rect(Rect2(0, 430, VIEW.x, 44), Color(0.031, 0.043, 0.063))
	for x in range(20, 1600, 92):
		draw_arc(Vector2(x + 34, 470), 28.0, PI, TAU, 12, Color(0.13, 0.18, 0.25, 0.55), 2.0)
		draw_circle(Vector2(x + 6, 446), 1.6, Color(1.0, 0.72, 0.4, 0.5))
	draw_rect(Rect2(0, 470, VIEW.x, 5), Color(0.19, 0.15, 0.14, 0.95))
	draw_line(Vector2(0, 470), Vector2(VIEW.x, 470), Color(0.45, 0.36, 0.28, 0.55), 1.0)


func _draw_ground() -> void:
	var near := Color(0.19, 0.155, 0.15)
	var far := Color(0.105, 0.09, 0.095)
	var bands := 44
	for index in bands:
		var t := float(index) / float(bands - 1)
		var y := lerpf(HORIZON, VIEW.y, float(index) / float(bands))
		draw_rect(Rect2(0, y, VIEW.x, (VIEW.y - HORIZON) / float(bands) + 1.0), far.lerp(near, t))

	# 透视地砖线
	var vanish := Vector2(800, HORIZON)
	for x in range(-400, 2000, 100):
		draw_line(vanish, Vector2(x, VIEW.y), Color(0.55, 0.44, 0.35, 0.085), 1.0)
	for index in 6:
		var t := float(index + 1) / 7.0
		var y := lerpf(HORIZON + 18.0, 880.0, t * t)
		draw_set_transform(Vector2(800, y), 0.0, Vector2(1.0, 0.20))
		draw_arc(Vector2.ZERO, 620.0, PI, TAU, 40, Color(0.55, 0.44, 0.35, 0.09), 1.5, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 中央演武法阵
	var center := Vector2(800, 706)
	draw_set_transform(center, 0.0, Vector2(1.0, 0.30))
	draw_arc(Vector2.ZERO, 300.0, 0.0, TAU, 64, Color(GOLD, 0.16), 2.0, true)
	draw_arc(Vector2.ZERO, 252.0, 0.0, TAU, 64, Color(GOLD, 0.09), 1.0, true)
	draw_arc(Vector2.ZERO, 180.0, 0.0, TAU, 48, Color(BLUE, 0.10), 1.0, true)
	for index in 8:
		var angle := float(index) * TAU / 8.0 + _time * 0.02
		var inner := Vector2.from_angle(angle) * 210.0
		var outer := Vector2.from_angle(angle) * 292.0
		draw_line(inner, outer, Color(GOLD, 0.08), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 碎石
	for stone in _stones:
		var pos: Vector2 = stone["pos"]
		draw_rect(Rect2(pos, Vector2(stone["size"], stone["size"] * 0.6)), Color(0.62, 0.5, 0.4, stone["alpha"]))

	# 场地边缘的暗角
	draw_rect(Rect2(0, 500, 120, 400), Color(0.02, 0.03, 0.05, 0.18))
	draw_rect(Rect2(1480, 500, 120, 400), Color(0.02, 0.03, 0.05, 0.18))
	_draw_arena_wall()


func _draw_arena_wall() -> void:
	# 竞技场背墙：把天空/城堡和地面接起来，避免地平线是一条生硬的切线。
	var stone := Color(0.105, 0.093, 0.095)
	var stone_dark := Color(0.07, 0.062, 0.068)
	var rim := Color(0.32, 0.265, 0.21, 0.8)
	draw_rect(Rect2(0, HORIZON - 36, VIEW.x, 52), stone)
	for x in range(0, int(VIEW.x), 56):
		draw_rect(Rect2(x + 8, HORIZON - 52, 30, 18), stone)
		draw_line(Vector2(x + 8, HORIZON - 52), Vector2(x + 38, HORIZON - 52), Color(rim, 0.45), 1.0)
		draw_line(Vector2(x + 8, HORIZON - 52), Vector2(x + 8, HORIZON - 36), Color(0, 0, 0, 0.22), 1.0)
	for x in range(0, int(VIEW.x), 112):
		draw_line(Vector2(x, HORIZON - 34), Vector2(x, HORIZON + 14), Color(0, 0, 0, 0.2), 1.0)
	draw_line(Vector2(0, HORIZON - 36), Vector2(VIEW.x, HORIZON - 36), rim, 1.5)
	draw_line(Vector2(0, HORIZON + 15), Vector2(VIEW.x, HORIZON + 15), Color(rim, 0.7), 2.0)
	draw_rect(Rect2(0, HORIZON + 15, VIEW.x, 9), Color(0, 0, 0, 0.16))
	draw_rect(Rect2(0, HORIZON - 54, VIEW.x, 3), stone_dark)


func _draw_banners() -> void:
	_draw_banner(94.0, BLUE, true)
	_draw_banner(1506.0, RED, false)


func _draw_banner(x: float, color: Color, crown: bool) -> void:
	draw_line(Vector2(x, 96), Vector2(x, 422), Color(0.34, 0.27, 0.2), 4.0)
	draw_circle(Vector2(x, 92), 5.0, GOLD)
	var cloth := PackedVector2Array([
		Vector2(x - 44, 118),
		Vector2(x + 44, 118),
		Vector2(x + 36, 344),
		Vector2(x, 318),
		Vector2(x - 36, 344),
	])
	draw_colored_polygon(cloth, Color(color, 0.82))
	# 金色滚边与褶皱
	draw_polyline(PackedVector2Array([cloth[0], cloth[1], cloth[2], cloth[3]]), Color(GOLD, 0.75), 2.0)
	draw_polyline(PackedVector2Array([cloth[0], cloth[4], cloth[3]]), Color(GOLD, 0.55), 1.5)
	for index in 3:
		var fx := x - 22.0 + index * 22.0
		draw_line(Vector2(fx, 122), Vector2(fx + 2.0, 330), Color(0.02, 0.03, 0.05, 0.15), 1.0)

	if crown:
		var emblem := Vector2(x, 226)
		draw_colored_polygon(PackedVector2Array([
			emblem + Vector2(-24, 12), emblem + Vector2(-24, -8),
			emblem + Vector2(-10, 2), emblem + Vector2(0, -16),
			emblem + Vector2(10, 2), emblem + Vector2(24, -8),
			emblem + Vector2(24, 12),
		]), Color(GOLD, 0.95))
		draw_rect(Rect2(emblem + Vector2(-24, 14), Vector2(48, 5)), Color(GOLD, 0.8))
	else:
		var emblem := Vector2(x, 226)
		draw_circle(emblem, 22.0, Color(0.07, 0.04, 0.06, 0.85))
		draw_arc(emblem, 22.0, 0.0, TAU, 24, Color(GOLD, 0.8), 2.0, true)
		draw_colored_polygon(PackedVector2Array([
			emblem + Vector2(0, -16), emblem + Vector2(12, 0),
			emblem + Vector2(0, 16), emblem + Vector2(-12, 0),
		]), Color(GOLD, 0.75))
		draw_circle(emblem, 4.0, Color(0.1, 0.02, 0.03, 1.0))

	# 旗杆上的小灯
	draw_circle(Vector2(x, 118), 3.0, Color(1.0, 0.85, 0.5, 0.8))


func _draw_torch(x: float) -> void:
	var pillar := Color(0.09, 0.085, 0.095)
	draw_rect(Rect2(x - 16, 470, 32, 260), pillar)
	draw_rect(Rect2(x - 22, 470, 44, 14), pillar.lightened(0.12))
	draw_rect(Rect2(x - 26, 730, 52, 16), pillar.darkened(0.2))
	for row in 5:
		draw_line(Vector2(x - 14, 500 + row * 44), Vector2(x + 14, 500 + row * 44), Color(0.2, 0.18, 0.19, 0.35), 1.0)

	var flicker := sin(_time * 11.0 + x) * 3.0 + sin(_time * 23.0 + x * 0.3) * 1.5
	var base := Vector2(x, 470)
	# 火光光晕
	for index in range(6, 0, -1):
		draw_circle(base + Vector2(0, -18), 34.0 + index * 26.0, Color(1.0, 0.55, 0.2, 0.008 * (7 - index)))
	# 火焰
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-14, -6),
		base + Vector2(-8, -30 - flicker),
		base + Vector2(-2, -18),
		base + Vector2(0, -46 - flicker),
		base + Vector2(6, -22),
		base + Vector2(12, -34 + flicker),
		base + Vector2(14, -6),
	]), Color(1.0, 0.52, 0.18, 0.92))
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-7, -8),
		base + Vector2(-3, -28 - flicker * 0.6),
		base + Vector2(1, -20),
		base + Vector2(4, -32 - flicker * 0.5),
		base + Vector2(8, -8),
	]), Color(1.0, 0.82, 0.38, 0.95))
	for index in 4:
		var spark_y := -40.0 - fmod(_time * (20.0 + index * 7.0) + index * 30.0, 70.0)
		var spark_x := x + sin(_time * 3.0 + index) * 12.0
		draw_circle(Vector2(spark_x, 470 + spark_y), 1.2, Color(1.0, 0.75, 0.35, 0.55))


func _draw_motes() -> void:
	for mote in _motes:
		var pos: Vector2 = mote["pos"]
		var phase: float = mote["phase"]
		var speed: float = mote["speed"]
		var drift := Vector2(
			sin(_time * 0.35 + phase) * 10.0,
			-sin(_time * 0.22 + phase) * 14.0
		)
		var alpha := 0.10 + 0.10 * sin(_time * 0.9 + phase)
		draw_circle(pos + drift, mote["size"], Color(1.0, 0.82, 0.55, alpha))


func _draw_vignette() -> void:
	for index in 10:
		var alpha := 0.022
		draw_rect(Rect2(0, index * 12.0, VIEW.x, 12.0), Color(0, 0, 0, alpha))
		draw_rect(Rect2(0, VIEW.y - (index + 1) * 12.0, VIEW.x, 12.0), Color(0, 0, 0, alpha))
		draw_rect(Rect2(index * 14.0, 0, 14.0, VIEW.y), Color(0, 0, 0, alpha * 0.8))
		draw_rect(Rect2(VIEW.x - (index + 1) * 14.0, 0, 14.0, VIEW.y), Color(0, 0, 0, alpha * 0.8))
