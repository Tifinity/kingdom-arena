extends AnimatedSprite2D

## 稻草人按 2px 的本地格绘制，经场景倍率显示为约 4px 的美术像素。
const INK := Color("#231a2a")
const WOOD := Color("#6c4135")
const WOOD_LIGHT := Color("#aa6e48")
const CLOTH := Color("#925548")
const CLOTH_SHADE := Color("#6d3c43")
const STRAW := Color("#e4bc74")
const STRAW_SHADE := Color("#ab764d")
const STRAW_LIGHT := Color("#f5d397")


func _draw() -> void:
	# 立柱、横杆和分开的两撮稻草。
	_box(-2, -36, 4, 36, INK)
	_box(-1, -34, 2, 33, WOOD)
	_box(-1, -34, 1, 32, WOOD_LIGHT)
	_box(-18, -28, 36, 4, INK)
	_box(-17, -27, 34, 2, WOOD)
	for side in [-1, 1]:
		_box(side * 17 - 2, -29, 4, 6, STRAW_SHADE)
		_box(side * 18 - 2, -28, 4, 3, STRAW)
		_box(side * 19 - 1, -30, 2, 2, STRAW_LIGHT)
		_box(side * 19 - 1, -24, 2, 2, STRAW)

	# 褪色的练功服和铆钉形靶心。
	_box(-10, -28, 20, 4, INK)
	_box(-9, -24, 18, 10, INK)
	_box(-8, -14, 16, 5, INK)
	_box(-9, -27, 18, 4, CLOTH)
	_box(-8, -23, 16, 12, CLOTH)
	_box(5, -24, 3, 13, CLOTH_SHADE)
	_box(-7, -12, 14, 2, WOOD)
	_box(-4, -11, 4, 2, CLOTH_SHADE)
	_box(-2, -21, 6, 6, WOOD)
	_box(-1, -20, 4, 4, STRAW_SHADE)
	_box(0, -19, 2, 2, STRAW_LIGHT)

	# 麻布头、缝线和硬边草帽。
	_box(-6, -35, 12, 9, INK)
	_box(-5, -34, 10, 7, STRAW_SHADE)
	_box(-4, -34, 8, 5, STRAW)
	_box(-3, -33, 2, 2, INK)
	_box(2, -33, 2, 2, INK)
	_box(-2, -29, 5, 1, WOOD)
	_box(-8, -37, 16, 2, INK)
	_box(-7, -38, 14, 2, STRAW_SHADE)
	_box(-5, -40, 10, 2, WOOD)
	_box(-3, -41, 6, 2, CLOTH)
	_box(-6, -37, 12, 1, STRAW_LIGHT)


func _box(x: int, y: int, width: int, height: int, color: Color) -> void:
	draw_rect(Rect2(x * 2, y * 2, width * 2, height * 2), color)
