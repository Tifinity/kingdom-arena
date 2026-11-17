extends Node2D

## pixelfx bows/arrow-rain-perspective, 73 frames at 30 fps.
@export var sheet: Texture2D
const FRAME_SIZE := Vector2i(288, 190)
const PIVOT := Vector2(144, 150)
const FRAME_COUNT := 73
const COLUMNS := 7
const FPS := 30.0

var _sprite: Sprite2D
var _elapsed := 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.position = -PIVOT
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_show_frame(0)


func setup_from_effect(source: Unit, effect: ActionEffectDefinition) -> void:
	global_position = source.current_cast.point if source.current_cast != null and source.current_cast.has_point else source.global_position
	scale = Vector2.ONE * (effect.radius / 140.0 if effect.radius > 0.0 else 1.0)


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
	atlas.region = Rect2((index % COLUMNS) * FRAME_SIZE.x, (index / COLUMNS) * FRAME_SIZE.y,
		FRAME_SIZE.x, FRAME_SIZE.y)
	_sprite.texture = atlas
