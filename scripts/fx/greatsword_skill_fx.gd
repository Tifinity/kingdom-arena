extends Sprite2D

@export var first_frame := 0
@export var frame_count := 1
@export var reference_reach := 0.0
@export var reference_width := 0.0
@export var height_scale := 1.0

var _elapsed := 0.0


func setup_from_effect(source: Unit, effect: ActionEffectDefinition) -> void:
	frame = first_frame
	var projection := get_canvas_transform()
	var inverse := projection.affine_inverse()
	var screen_height := projection.x.length() * height_scale
	if effect == null:
		global_transform = Transform2D(inverse.basis_xform(Vector2.RIGHT * screen_height),
			inverse.basis_xform(Vector2.DOWN * screen_height), source.get_effect_point())
		return

	var cast := source.current_cast
	var aim := cast.direction if cast != null else Vector2(float(source.facing), 0.0)
	var reach := effect.length if effect.shape == ActionEffectDefinition.Shape.RECT else effect.radius
	var screen_aim := projection.basis_xform(aim)
	var forward := screen_aim * maxf(reach, 1.0) / reference_reach
	var vertical := Vector2.DOWN * screen_height
	var anchor := source.global_position
	if reference_width > 0.0:
		# The thrust follows the ground aim while its blade sits above the caster's feet.
		vertical = screen_aim.normalized().orthogonal() * screen_height
		if vertical.y < 0.0:
			vertical = -vertical
		vertical *= clampf(effect.width / reference_width, 0.5, 2.0)
		anchor += inverse.basis_xform(Vector2.UP * 17.0 * projection.x.length() + vertical * 20.0)
	global_transform = Transform2D(inverse.basis_xform(forward), inverse.basis_xform(vertical), anchor)


func _process(delta: float) -> void:
	_elapsed += delta
	var next := int(_elapsed * 30.0)
	if next >= frame_count:
		queue_free()
	else:
		frame = first_frame + next
