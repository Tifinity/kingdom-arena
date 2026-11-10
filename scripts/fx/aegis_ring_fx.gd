class_name AegisRingFx
extends Node2D

## Pixelfx 的 holy/aegis-ring：金色光点钻进地面，结界从落点滚开，光柱与盾徽升起后碎成光屑。
## 只负责表现；半径直接读取效果数据，落地圆环的边界与嘲讽圈重合。
##
## 精灵表拆成前后两层：地面的一层落在单位下方（背景在 z = -100），竖起来的光柱和盾徽在单位上方，
## 这样被罩住的单位是“站在结界里”，而不是被一整张光斑糊住。

## 精灵表内结界墙的半径（256×136 画布、reach 104 时约 97.8px）。
const SHEET_RING_RADIUS := 97.8
## 相对 Effects 根节点（z = 12）：-13 落到绝对 z = -1，位于背景之上、单位之下。
const GROUND_Z := -13

@export var ground_sheet: Texture2D
@export var glow_sheet: Texture2D
@export var frame_size := Vector2i(256, 136)
@export var frame_count := 97
@export var fps := 30.0
## 从第几帧开始播：跳过“光点汇聚”的前摇，让结界在落地瞬间炸开。
@export var start_frame := 8
## 精灵表内结界墙的半径；与效果半径一致时缩放就位。用其他 reach 重渲染时同步改这里。
@export var sheet_ring_radius := SHEET_RING_RADIUS

var radius := 160.0

var _elapsed := 0.0
var _frames: Array[AtlasTexture] = []
var _ground: Sprite2D
var _glow: Sprite2D
var _index := -1


func _ready() -> void:
	_build_frames()
	_show_frame(start_frame)


func setup_from_effect(source: Unit, effect: ActionEffectDefinition) -> void:
	if not is_instance_valid(source) or ground_sheet == null or glow_sheet == null:
		queue_free()
		return
	global_position = source.global_position
	if effect != null:
		radius = maxf(effect.radius, 1.0)
	scale = Vector2.ONE * (radius / maxf(sheet_ring_radius, 1.0))
	if not is_node_ready():
		return
	_show_frame(start_frame)


func _process(delta: float) -> void:
	_elapsed += delta
	if _show_frame(start_frame + int(_elapsed * fps)):
		queue_free()


func _build_frames() -> void:
	if not _frames.is_empty() or ground_sheet == null or glow_sheet == null:
		return
	_ground = Sprite2D.new()
	_ground.name = "Ground"
	_ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ground.offset = Vector2(0, -36)
	_ground.z_index = GROUND_Z
	add_child(_ground)
	_glow = Sprite2D.new()
	_glow.name = "Glow"
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glow.offset = Vector2(0, -36)
	add_child(_glow)
	var columns := maxi(1, ground_sheet.get_width() / frame_size.x)
	for index in frame_count:
		var region := Rect2((index % columns) * frame_size.x, int(index / columns) * frame_size.y,
			frame_size.x, frame_size.y)
		_frames.append(_atlas(ground_sheet, region))
		_frames.append(_atlas(glow_sheet, region))
	_index = -1


func _atlas(sheet: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = region
	return atlas


## 切到指定帧；越界说明播放结束，返回 true。
func _show_frame(index: int) -> bool:
	if index >= frame_count:
		return true
	if index != _index and _ground != null and _glow != null:
		_index = index
		_ground.texture = _frames[index * 2]
		_glow.texture = _frames[index * 2 + 1]
	return false
