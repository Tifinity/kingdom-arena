extends AnimatedSprite2D

## 训练稻草人的纯代码绘制体。
##
## 稻草人没有 SpriteFrames，因此不参与移动/攻击动画；它仍然复用 Unit 的
## 受击闪烁（modulate）、状态图标和血条挂点，作为不会死亡、不会移动的靶子。

const WOOD := Color("#5b4028")
const WOOD_LIGHT := Color("#7a5738")
const WOOD_SHADOW := Color("#3f2b1b")
const STRAW := Color("#d8b877")
const STRAW_DARK := Color("#a5843f")
const CLOTH := Color("#7b4a3a")
const CLOTH_DARK := Color("#573426")
const PATCH := Color("#a9743f")
const INK := Color("#2b2118")


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	_draw_pole()
	_draw_arms()
	_draw_tunic()
	_draw_head()
	_draw_hat()


func _draw_pole() -> void:
	# 立柱：脚底 0，顶端藏在头部后方。
	draw_rect(Rect2(-2.5, -76.0, 5.0, 76.0), WOOD)
	draw_line(Vector2(-2.5, 0.0), Vector2(-2.5, -76.0), WOOD_LIGHT, 1.0)
	draw_line(Vector2(2.5, 0.0), Vector2(2.5, -76.0), WOOD_SHADOW, 1.0)


func _draw_arms() -> void:
	# 横杆与两端的稻草束。
	draw_line(Vector2(-30.0, -52.0), Vector2(30.0, -52.0), WOOD, 4.0)
	draw_line(Vector2(-30.0, -53.0), Vector2(30.0, -53.0), WOOD_LIGHT, 1.0)
	for side in [-1.0, 1.0]:
		var tip := Vector2(30.0 * side, -52.0)
		for index in 5:
			var offset := Vector2(side * (3.0 + index * 1.6), -5.0 + index * 2.5)
			draw_line(tip, tip + offset, STRAW_DARK, 1.5)
		draw_line(tip + Vector2(-side * 6.0, 1.0), tip + Vector2(side * 4.0, -1.0), STRAW, 2.0)


func _draw_tunic() -> void:
	# 破旧上衣：肩宽腰窄，下摆做出撕裂缺口。
	var body := PackedVector2Array([
		Vector2(-17.0, -51.0), Vector2(17.0, -51.0),
		Vector2(14.0, -22.0), Vector2(9.0, -18.0),
		Vector2(4.0, -23.0), Vector2(-2.0, -18.0),
		Vector2(-8.0, -23.0), Vector2(-13.0, -19.0),
		Vector2(-15.0, -22.0),
	])
	draw_colored_polygon(body, CLOTH)
	draw_polyline(PackedVector2Array([
		Vector2(-17.0, -51.0), Vector2(-15.0, -22.0), Vector2(-13.0, -19.0),
		Vector2(-8.0, -23.0), Vector2(-2.0, -18.0), Vector2(4.0, -23.0),
		Vector2(9.0, -18.0), Vector2(14.0, -22.0), Vector2(17.0, -51.0),
	]), CLOTH_DARK, 1.2)
	# 领口的稻草。
	for index in 7:
		var x := -12.0 + float(index) * 4.0
		draw_line(Vector2(x, -51.0), Vector2(x + (2.0 if index % 2 == 0 else -2.0), -56.0), STRAW_DARK, 1.4)
	# 补丁与缝线。
	draw_rect(Rect2(2.0, -43.0, 7.0, 6.0), PATCH)
	draw_line(Vector2(3.0, -40.0), Vector2(8.0, -40.0), INK, 0.8)
	draw_line(Vector2(5.5, -43.0), Vector2(5.5, -37.0), INK, 0.8)
	# 束腰麻绳。
	draw_line(Vector2(-14.0, -27.0), Vector2(13.0, -27.0), STRAW_DARK, 2.0)
	draw_line(Vector2(-11.0, -27.0), Vector2(-11.0, -23.0), STRAW_DARK, 1.5)
	draw_line(Vector2(9.0, -27.0), Vector2(9.0, -23.0), STRAW_DARK, 1.5)


func _draw_head() -> void:
	# 麻布头：略扁的圆，底部用稻草扎紧。
	draw_circle(Vector2(0.0, -60.0), 9.5, STRAW)
	draw_arc(Vector2(0.0, -60.0), 9.5, 0.0, TAU, 24, STRAW_DARK, 1.4, true)
	draw_line(Vector2(-9.0, -55.0), Vector2(9.0, -55.0), STRAW_DARK, 1.2)
	for index in 5:
		var x := -7.0 + float(index) * 3.5
		draw_line(Vector2(x, -55.0), Vector2(x + 1.5, -51.0), STRAW_DARK, 1.0)
	# 眼睛与缝合的嘴。
	draw_circle(Vector2(-3.4, -62.0), 1.5, INK)
	draw_circle(Vector2(3.4, -62.0), 1.5, INK)
	draw_line(Vector2(-4.2, -57.0), Vector2(4.2, -57.0), INK, 1.0)
	for index in 3:
		var x := -2.8 + float(index) * 2.8
		draw_line(Vector2(x, -58.2), Vector2(x, -55.8), INK, 0.8)


func _draw_hat() -> void:
	# 破草帽：宽帽檐 + 斜顶。
	draw_line(Vector2(-12.0, -68.0), Vector2(12.0, -68.0), STRAW_DARK, 3.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7.0, -68.0), Vector2(-3.0, -77.0),
		Vector2(1.0, -78.0), Vector2(7.0, -68.0),
	]), CLOTH_DARK)
	draw_polyline(PackedVector2Array([
		Vector2(-7.0, -68.0), Vector2(-3.0, -77.0),
		Vector2(1.0, -78.0), Vector2(7.0, -68.0),
	]), INK, 0.9)
	draw_line(Vector2(-9.0, -69.5), Vector2(9.0, -69.5), STRAW, 1.4)
