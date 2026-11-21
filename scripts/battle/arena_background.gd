class_name ArenaBackground
extends Node2D

## 用 400 × 225 个美术像素画出王城。每个像素在设计视口中占 4 × 4。
const SIZE := Vector2(400, 225)
const NIGHT := Color("#171b2a")
const SKY := Color("#242a40")
const DISTANT := Color("#30354a")
const STONE := Color("#343548")
const SHADE := Color("#242637")
const MORTAR := Color("#1c2031")
const EDGE := Color("#494a5d")
const BRASS := Color("#b08352")
const GOLD := Color("#e5bf79")
const BLUE := Color("#466a83")
const RED := Color("#884848")

@export var distant_only := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	get_viewport().size_changed.connect(_fit)
	_fit()


func _fit() -> void:
	var view_size := get_viewport_rect().size
	var zoom := maxf(view_size.x / SIZE.x, view_size.y / SIZE.y)
	scale = Vector2.ONE * zoom
	position = ((view_size - SIZE * zoom) * 0.5).round()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261121
	_rect(0, 0, 400, 225, NIGHT)
	_rect(0, 34, 400, 191, SKY)
	_rect(0, 61, 400, 164, DISTANT)
	for index in 98:
		var x := rng.randi_range(0, 399)
		var y := rng.randi_range(1, 74)
		var color := Color("#7e8294") if index % 9 == 0 else Color("#41455d")
		_rect(x, y, 1, 1, color)
		if index % 9 == 0:
			_rect(x - 1, y, 3, 1, color)
			_rect(x, y - 1, 1, 3, color)

	_disc(300, 33, 23, Color("#33354a"))
	_disc(300, 33, 17, Color("#b98d66"))
	_disc(299, 31, 15, Color("#ebc791"))
	_disc(294, 27, 4, Color("#caa378"))
	_disc(305, 36, 3, Color("#caa378"))
	_rect(286, 45, 25, 2, Color("#786680"))

	_cloud(26, 33, 75)
	_cloud(139, 56, 69)
	_cloud(280, 48, 83)
	_cloud(345, 21, 43)
	_ridge(87, 30, 0.065, Color("#292e42"))
	_ridge(105, 20, 0.084, Color("#202538"))

	_wall(0, 101, 400, 41, Color("#2b2c40"))
	for x in range(2, 400, 12):
		_rect(x, 97, 7, 4, SHADE)
		_rect(x, 97, 7, 1, EDGE)

	_tower(30, 61, 42, 93)
	_tower(328, 61, 42, 93)
	_tower(108, 75, 28, 74)
	_tower(264, 75, 28, 74)
	_wall(143, 68, 114, 82, STONE)
	_rect(147, 67, 106, 3, EDGE)
	for x in range(144, 255, 16):
		_rect(x, 62, 9, 6, SHADE)
		_rect(x, 62, 9, 1, EDGE)
	_tower(173, 43, 54, 111)
	_arch(187, 92, 26, 44)
	for x in [153, 239]:
		_banner(x, 83, 10, 26, Color("#68434d"))

	if distant_only:
		return

	_wall(0, 122, 400, 103, SHADE)
	_rect(0, 122, 400, 2, EDGE)
	_rect(0, 130, 400, 1, BRASS.darkened(0.40))
	for x in range(4, 400, 29):
		_arch(x, 136, 17, 33)
		_rect(x + 22, 149, 2, 6, BRASS)
		_rect(x + 21, 146, 4, 4, Color("#855149"))
		_rect(x + 22, 145, 2, 3, GOLD)

	_rect(0, 171, 400, 54, Color("#262b3c"))
	for row in 9:
		var y := 173 + row * 6
		var shift := 11 if row % 2 == 0 else 0
		for x in range(-24 + shift, 400, 22):
			var stone := Color("#33374a").darkened(0.055 * rng.randi_range(0, 3))
			_rect(x + 1, y, 21, 5, stone)
			_rect(x + 2, y, 19, 1, stone.lightened(0.065))
	_banner(20, 115, 19, 52, BLUE)
	_banner(361, 115, 19, 52, RED)
	_rect(0, 220, 400, 5, MORTAR)
	_rect(0, 220, 400, 1, Color("#414257"))


func _tower(x: int, y: int, width: int, height: int) -> void:
	_wall(x, y, width, height, STONE)
	_rect(x + width - 6, y, 6, height, SHADE)
	_rect(x - 2, y, width + 4, 3, EDGE)
	for offset in range(0, width, 10):
		_rect(x + offset, y - 5, 6, 5, STONE)
		_rect(x + offset, y - 5, 6, 1, EDGE)
	for row in range(y + 12, y + height - 14, 18):
		for column in range(x + 7, x + width - 7, 13):
			_arch(column, row, 4, 8)
			if (row + column) % 5 < 2:
				_rect(column + 1, row + 3, 2, 3, BRASS)


func _wall(x: int, y: int, width: int, height: int, stone: Color) -> void:
	_rect(x, y, width, height, stone)
	for row in range(7, height, 7):
		_rect(x, y + row, width, 1, MORTAR)
		var first_brick := 7 if row % 14 == 0 else 16
		for column in range(first_brick, width, 17):
			_rect(x + column, y + row - 5, 1, 5, MORTAR)
			if column + 6 < width and (row + column) % 4 == 0:
				_rect(x + column + 2, y + row + 1, 4, 1, stone.lightened(0.10))


func _arch(x: int, y: int, width: int, height: int) -> void:
	_rect(x + 2, y, width - 4, height, MORTAR)
	_rect(x + 1, y + 1, width - 2, height - 1, MORTAR)
	_rect(x, y + 3, width, height - 3, MORTAR)
	_rect(x + 2, y - 1, width - 4, 1, EDGE)
	_rect(x - 1, y + 3, 1, height - 3, EDGE)


func _banner(x: int, y: int, width: int, height: int, cloth: Color) -> void:
	_rect(x - 2, y - 2, width + 4, 2, BRASS)
	_rect(x, y, width, height - 5, cloth)
	_rect(x + 2, y + height - 5, width - 4, 3, cloth)
	_rect(x + 4, y + height - 2, width - 8, 2, cloth)
	_rect(x + 1, y + 1, 1, height - 7, BRASS)
	_rect(x + width - 2, y + 1, 1, height - 7, BRASS.darkened(0.24))
	var center := x + int(width * 0.5)
	var mark_y := y + int(height * 0.35)
	_rect(center - 2, mark_y + 2, 5, 3, GOLD)
	_rect(center - 1, mark_y, 3, 7, GOLD)
	_rect(center, mark_y - 1, 1, 9, GOLD)


func _cloud(x: int, y: int, width: int) -> void:
	_rect(x, y, width, 2, Color("#373a50"))
	_rect(x + 6, y - 2, width - 17, 2, Color("#373a50"))
	_rect(x + 18, y - 4, width - 37, 2, Color("#373a50"))
	_rect(x + 11, y + 2, width - 18, 1, Color("#2d3048"))


func _ridge(y: int, height: int, frequency: float, color: Color) -> void:
	for x in range(0, 400, 2):
		var edge := y - int((sin(x * frequency) + cos(x * frequency * 0.46)) * height * 0.5)
		_rect(x, edge, 2, 225 - edge, color)


func _disc(x: int, y: int, radius: int, color: Color) -> void:
	for row in range(-radius, radius + 1):
		var span := int(sqrt(float(radius * radius - row * row)))
		_rect(x - span, y + row, span * 2 + 1, 1, color)


func _rect(x: int, y: int, width: int, height: int, color: Color) -> void:
	if width > 0 and height > 0:
		draw_rect(Rect2(x, y, width, height), color)
