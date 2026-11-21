class_name ArmorGuardFx
extends Node2D

const FRAME_SIZE := Vector2i(72, 60)
const FRAME_ORIGIN := Vector2(36, 47)
const COLUMNS := 8
const FPS := 24.0
const INTRO_FRAMES := 15
const LOOP_FRAMES := 60

@onready var _back: Sprite2D = $Back
@onready var _front: Sprite2D = $Front

var _elapsed := 0.0
var _frame := 0


func _ready() -> void:
	var ancestor := get_parent()
	while ancestor != null and not ancestor is Unit:
		ancestor = ancestor.get_parent()
	var unit := ancestor as Unit
	if unit != null and unit.visual != null:
		scale = unit.visual.scale.abs()
	for sprite in [_back, _front]:
		sprite.position = -FRAME_ORIGIN
	_show_frame(0)
	stop()


func play() -> void:
	_elapsed = 0.0
	_show_frame(0)
	show()
	set_process(true)


func stop() -> void:
	hide()
	set_process(false)


func is_playing() -> bool:
	return is_processing()


func current_frame() -> int:
	return _frame


func _process(delta: float) -> void:
	_elapsed += delta
	var index := int(_elapsed * FPS)
	if index >= INTRO_FRAMES:
		index = INTRO_FRAMES + (index - INTRO_FRAMES) % LOOP_FRAMES
	if index != _frame:
		_show_frame(index)


func _show_frame(index: int) -> void:
	_frame = index
	@warning_ignore("integer_division")
	var cell := Vector2i(index % COLUMNS, index / COLUMNS)
	var region := Rect2(cell * FRAME_SIZE, FRAME_SIZE)
	_back.region_rect = region
	_front.region_rect = region
