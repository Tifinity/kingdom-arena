extends Sprite2D

## Pixelfx sheet: Heal (58 frames) or Healing ring (88 frames), both at 30 fps.
@export var sheet: Texture2D
@export var frame_size := Vector2i(80, 104)
@export var columns := 9
@export var frame_count := 58
@export var ground_ring := false

var target: Unit
var elapsed := 0.0


func setup_from_effect(source: Unit, _effect: ActionEffectDefinition) -> void:
	if not is_instance_valid(source):
		queue_free()
		return
	target = source.current_cast.target if source.current_cast != null else source
	if not is_instance_valid(target):
		target = source
	global_position = target.global_position if ground_ring else target.get_hit_point()
	_set_frame(0)


func _process(delta: float) -> void:
	elapsed += delta
	var index := int(elapsed * 30.0)
	if index >= frame_count:
		queue_free()
		return
	if not ground_ring and is_instance_valid(target):
		global_position = target.get_hit_point()
	_set_frame(index)


func _set_frame(index: int) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2((index % columns) * frame_size.x, int(index / columns) * frame_size.y,
		frame_size.x, frame_size.y)
	texture = atlas
