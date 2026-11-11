extends Node2D

## patch-gg/pixelfx Hit spark：普通攻击的默认命中特效。
const SHEET := preload("res://assets/hit_spark_sheet.png")
const FRAME_SIZE := Vector2i(136, 80)
const FRAME_COUNT := 16
const COLUMNS := 4
const FPS := 30.0

@export_range(0.5, 3.0, 0.1) var effect_scale := 1.4
@export var effect_offset := Vector2.ZERO

var elapsed := 0.0
var sprite: Sprite2D


func _ready() -> void:
	z_index = 35
	sprite = Sprite2D.new()
	sprite.texture = SHEET
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.region_enabled = true
	sprite.scale = Vector2.ONE * effect_scale
	# 素材原点在 (44, 64)，把首帧闪光中心对齐命中点。
	sprite.position = Vector2(24.0, 0.0) * effect_scale + effect_offset
	add_child(sprite)
	_show_frame(0)


func setup(at: Vector2, direction: float) -> void:
	global_position = at
	scale.x = -1.0 if direction < 0.0 else 1.0


func _process(delta: float) -> void:
	elapsed += delta
	var frame := int(elapsed * FPS)
	if frame >= FRAME_COUNT:
		queue_free()
	else:
		_show_frame(frame)


func _show_frame(frame: int) -> void:
	sprite.region_rect = Rect2(Vector2i(frame % COLUMNS, int(frame / COLUMNS)) * FRAME_SIZE, FRAME_SIZE)
