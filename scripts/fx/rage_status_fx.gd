class_name RageStatusFx
extends Node2D

## pixelfx status/rage 的纯光环循环：怒纹、蒸汽、地裂、火星和红光。
## 由 UnitStatusController 在“狂怒”状态生效期间创建，条件结束后释放。
## 精灵表与导出脚本见 tools/export_rage_status.mjs。

const SHEET := preload("res://assets/fx/pixelfx/elite_orc_rage.png")
const FRAME_SIZE := Vector2i(80, 80)
const FRAME_COUNT := 36
const COLUMNS := 6
const FPS := 30.0
## 画布原点（脚底）在帧内的位置。
const FRAME_ORIGIN := Vector2(40.0, 70.0)

var _sprite: Sprite2D
var _elapsed := 0.0
var _playing := false


func _ready() -> void:
	# 画在单位身体之上、血条与状态图标之下。
	z_as_relative = false
	z_index = 15
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.region_enabled = true
	_sprite.centered = false
	_sprite.position = -FRAME_ORIGIN
	add_child(_sprite)
	# 和单位精灵使用同一像素密度，光环才会贴着身体而不是缩成一小圈。
	scale = Vector2.ONE * _unit_visual_scale()
	_show_frame(0)
	visible = false
	set_process(false)


func play() -> void:
	_playing = true
	_elapsed = 0.0
	_show_frame(0)
	visible = true
	set_process(true)


func stop() -> void:
	_playing = false
	visible = false
	set_process(false)


func is_playing() -> bool:
	return _playing


func current_frame() -> int:
	return int(_elapsed * FPS) % FRAME_COUNT if _playing else 0


func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	_show_frame(int(_elapsed * FPS) % FRAME_COUNT)


func _show_frame(index: int) -> void:
	if _sprite == null:
		return
	_sprite.region_rect = Rect2(
		Vector2i(index % COLUMNS, index / COLUMNS) * FRAME_SIZE,
		FRAME_SIZE
	)


func _unit_visual_scale() -> float:
	var node := get_parent()
	while node != null:
		if node is Unit:
			var unit := node as Unit
			if unit.visual != null:
				return absf(unit.visual.scale.x)
			if unit.definition != null:
				return unit.definition.visual_scale
		node = node.get_parent()
	return 1.0
