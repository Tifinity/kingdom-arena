class_name ArenaBillboardEffect
extends OneShotEffect

## 给已画好透视的序列帧使用与角色相同的相机朝向和像素比例。
@export var anchor_to_hit_point := false
@export var sorting_offset := 1.0

var _sprite: Sprite3D


func setup_from_effect(source: Unit, _effect: ActionEffectDefinition) -> void:
	var target := source.current_cast.target if source.current_cast != null else source.target
	if not is_instance_valid(target):
		target = source
	var ground := target.global_position
	var height_offset := target.get_hit_point() - ground if anchor_to_hit_point else Vector2.ZERO
	setup_projection(source.battle.stage, ground, height_offset)


func setup_projection(stage: ArenaStage3D, ground: Vector2, height_offset := Vector2.ZERO) -> void:
	global_position = ground
	_sprite = Sprite3D.new()
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sprite.pixel_size = 1.0
	_sprite.sorting_use_aabb_center = false
	_sprite.sorting_offset = sorting_offset
	add_child(_sprite)
	_sprite.global_transform = Transform3D(stage.camera.basis, stage.billboard_anchor(ground, height_offset))
	_sprite.scale = Vector3(scale.x, scale.y, 1.0)
	_sprite.centered = centered
	_sprite.offset = Vector2(offset.x, -offset.y)
	hide()
	frame_changed.connect(_sync_frame)
	_sync_frame()


func _sync_frame() -> void:
	_sprite.texture = sprite_frames.get_frame_texture(animation, frame)
