extends ArenaBillboardEffect

# The heal hoop rises 43 px in the sheet. At this scale it reaches the shoulders.
const REFERENCE_BODY_HEIGHT_PX := 52.0
const REFERENCE_BODY_RADIUS_PX := 22.0

var _target: Unit
var _stage: ArenaStage3D


func setup_from_effect(source: Unit, _effect: ActionEffectDefinition) -> void:
	_target = source.current_cast.target if source.current_cast != null else source.target
	if not is_instance_valid(_target):
		_target = source
	_stage = source.battle.stage
	var height_scale := _target.get_visual_height() / REFERENCE_BODY_HEIGHT_PX
	var width_scale := maxf(height_scale, _target.body_radius / REFERENCE_BODY_RADIUS_PX)
	scale = Vector2(width_scale, height_scale)
	setup_projection(_stage, _target.global_position)


func _process(_delta: float) -> void:
	if not is_instance_valid(_target) or not _target.alive:
		return
	update_projection_anchor(_stage, _target.global_position)
