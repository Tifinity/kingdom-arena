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
	var height := source.get_muzzle_point().y - source.global_position.y
	global_position = source.global_position + Vector2(0.0, height)
	if source.battle is Battle:
		global_position = source.battle.stage.elevated_canvas_point(source.global_position, Vector2(0.0, height))
	global_rotation = cast.direction.angle()
	scale = Vector2(effect.length / SHEET_LENGTH, maxf(effect.width, 1.0) / SHEET_WIDTH)


func _process(delta: float) -> void:
	_elapsed += delta
	var index := int(_elapsed * FPS)
	if index >= FRAME_COUNT:
		queue_free()
	else:
		frame = index
