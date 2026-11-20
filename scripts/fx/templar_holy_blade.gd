class_name TemplarHolyBlade
extends Sprite2D

## pixelfx melee/radiant-wave, trimmed to start at the sword's release.
const SHEET_REACH := 190.0
const BLADE_WIDTH_SCALE := 1.16
const FRAME_COUNT := 18
const FPS := 45.0

@export var rising := false

var _elapsed := 0.0


func setup_from_effect(source: Unit, effect: ActionEffectDefinition) -> void:
	var aim := source.current_cast.direction if source.current_cast != null else source.planned_direction
	if aim.is_zero_approx() and is_instance_valid(source.target):
		aim = source.target.global_position - source.global_position
	if aim.is_zero_approx():
		aim = Vector2(float(source.facing), 0.0)

	# Direction and travel follow the ground. Blade height stays in the camera plane, like the unit sprite.
	var projection := get_canvas_transform()
	var travel := projection.basis_xform(aim.normalized())
	var axis := travel.normalized()
	var reach_scale := maxf(effect.radius, 1.0) / SHEET_REACH
	var blade_height := clampf(reach_scale * 1.4, 1.05, 1.32) * projection.x.length()
	var side := (axis.orthogonal() + axis * 0.28) * blade_height
	if rising == (axis.x >= 0.0):
		side = -side
	var inverse := projection.affine_inverse()
	global_transform = Transform2D(
		inverse.basis_xform(travel * reach_scale * BLADE_WIDTH_SCALE),
		inverse.basis_xform(side),
		source.get_effect_point()
	)


func _process(delta: float) -> void:
	_elapsed += delta
	var index := int(_elapsed * FPS)
	if index >= FRAME_COUNT:
		queue_free()
	else:
		frame = index
