extends Node2D

## pixelfx bows/arrow-rain-volley. Both layers share the target point and pixel grid.
const SHEET_GROUND_RADIUS := 70.0
const IMPACT_FRAME := 12
const FRAME_COUNT := 25
const FPS := 30.0

@onready var _ground: Sprite2D = $Ground
@onready var _arrows: Sprite2D = $Arrows

var _source: Unit
var _cast: ActionCast
var _impact_index := -1
var _start_time := 0.0
var _impact_time := 0.0
var _landed := false
var _after_impact := 0.0


func setup_from_effect(source: Unit, effect: ActionEffectDefinition) -> void:
	_cast = source.current_cast
	if _cast == null or not _cast.has_point:
		queue_free()
		return
	for index in range(_cast.next_effect + 1, _cast.effects.size()):
		var candidate := _cast.effects[index]
		if candidate.kind == ActionEffectDefinition.Kind.DAMAGE \
				and candidate.shape == ActionEffectDefinition.Shape.CIRCLE and not candidate.center_on_self:
			_impact_index = index
			break
	if _impact_index < 0:
		queue_free()
		return
	var damage := _cast.effects[_impact_index]
	var frames := source.definition.sprite_frames
	var animation := _cast.action.animation
	var animation_fps := frames.get_animation_speed(animation) if frames != null and frames.has_animation(animation) else 10.0
	animation_fps = maxf(animation_fps * source.visual.speed_scale, 0.01)
	_start_time = effect.trigger_frame / animation_fps
	_impact_time = damage.trigger_frame / animation_fps
	_source = source
	global_position = _cast.point
	scale = Vector2.ONE * (damage.radius / SHEET_GROUND_RADIUS)


func _process(delta: float) -> void:
	if not _landed:
		if _cast == null:
			return
		# ActionState advances this index after it resolves damage, even when the circle is empty.
		if _cast.next_effect > _impact_index:
			_landed = true
			_cast = null
			_source = null
			_show_frame(IMPACT_FRAME)
		elif not is_instance_valid(_source) or _source.current_cast != _cast:
			queue_free()
		else:
			var progress := clampf((_cast.elapsed - _start_time) / maxf(_impact_time - _start_time, 0.001), 0.0, 1.0)
			_show_frame(mini(int(progress * IMPACT_FRAME), IMPACT_FRAME - 1))
		return

	_after_impact += delta
	var frame := IMPACT_FRAME + int(_after_impact * FPS)
	if frame >= FRAME_COUNT:
		queue_free()
	else:
		_show_frame(frame)


func _show_frame(index: int) -> void:
	_ground.frame = index
	_arrows.frame = index
