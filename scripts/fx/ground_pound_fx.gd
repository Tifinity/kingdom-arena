extends Node2D

## pixelfx moves/ground-pound 的落地冲击部分（impacts/ground-slam）。
@export var sheet: Texture2D
const FRAME_SIZE := Vector2i(288, 208)
const FRAME_COUNT := 97
const FPS := 30.0

var _sprite: Sprite2D
var _elapsed := 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.offset = Vector2(0, -60)
	add_child(_sprite)
	_show_frame(0)


func setup_from_effect(source: Unit, effect: ActionEffectDefinition) -> void:
	global_position = source.global_position
	scale = Vector2.ONE * (effect.radius / 104.0)


func _process(delta: float) -> void:
	_elapsed += delta
	var frame := int(_elapsed * FPS)
	if frame >= FRAME_COUNT:
		queue_free()
	else:
		_show_frame(frame)


func _show_frame(index: int) -> void:
	if sheet == null or _sprite == null:
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2((index % 9) * FRAME_SIZE.x, (index / 9) * FRAME_SIZE.y,
		FRAME_SIZE.x, FRAME_SIZE.y)
	_sprite.texture = atlas
