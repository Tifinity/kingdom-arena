extends Sprite2D

## pixelfx bows/piercing-arrow-line, facing right in the sheet.
const SHEET_LENGTH := 180.0
const SHEET_WIDTH := 20.0
const FRAME_COUNT := 13
const FPS := 30.0

var _elapsed := 0.0


func setup_from_effect(source: Unit, effect: ActionEffectDefinition) -> void:
	var cast := source.current_cast
	if cast == null or effect.length <= 0.0:
		queue_free()
		return
	# Keep the damage axis and lift the whole flight line to bow height.
	global_position = Vector2(source.global_position.x, source.get_muzzle_point().y)
	global_rotation = cast.direction.angle()
	scale = Vector2(effect.length / SHEET_LENGTH, maxf(effect.width, 1.0) / SHEET_WIDTH)


func _process(delta: float) -> void:
	_elapsed += delta
	var index := int(_elapsed * FPS)
	if index >= FRAME_COUNT:
		queue_free()
	else:
		frame = index
