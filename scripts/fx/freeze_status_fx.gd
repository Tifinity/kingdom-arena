class_name FreezeStatusFx
extends Node2D

const FPS := 30.0
const HOLD_FRAME := 40
const SHATTER_FRAME := 45
const FRAME_COUNT := 64

var _unit: Unit
var _stage: ArenaStage3D
var _sprite_scale: Vector3
var _elapsed := 0.0
var _shattering := false

@onready var _ice: Sprite3D = $Ice


func play() -> void:
	var ancestor := get_parent()
	while ancestor != null and not ancestor is Unit:
		ancestor = ancestor.get_parent()
	_unit = ancestor as Unit
	if _unit == null or not _unit.battle is Battle:
		set_process(false)
		return
	_stage = _unit.battle.stage
	var height := _unit.get_visual_height()
	var width_ratio := 1.16 if _unit.is_training_dummy() else 0.98
	var width := maxf(_unit.body_radius * 2.5, height * width_ratio)
	_sprite_scale = Vector3(width / 34.0, height * 1.13 / 52.0, 1.0)
	_update_anchor()
	_ice.show()


## 冰冻自然到期后，在解冻位置播放碎冰。控制结束与碎冰播放互不等待。
func finish() -> void:
	if _stage != null:
		_update_anchor()
	_shattering = true
	_elapsed = 0.0
	_ice.frame = SHATTER_FRAME
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	if _shattering:
		var index := SHATTER_FRAME + int(_elapsed * FPS)
		if index >= FRAME_COUNT:
			queue_free()
		else:
			_ice.frame = index
		return
	_update_anchor()
	var remaining := _unit.status_controller.remaining(&"freeze")
	var frame_to_shatter := SHATTER_FRAME - maxi(1, ceili(remaining * FPS))
	_ice.frame = maxi(mini(int(_elapsed * FPS), HOLD_FRAME), frame_to_shatter)


func _update_anchor() -> void:
	_ice.global_transform = Transform3D(_stage.camera.basis.scaled_local(_sprite_scale),
		_stage.billboard_anchor(_unit.global_position, Vector2.ZERO))
