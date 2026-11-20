class_name UnitSprite3D
extends Sprite3D

## AnimatedSprite2D 继续驱动状态机和技能帧。这里复用当前像素帧与同一套比例。
var _unit: Unit
var _stage: ArenaStage3D
var _body: AnimatedSprite2D
var _ground: UnitGroundVisual3D
var _canvas: SubViewport
var _canvas_body: AnimatedSprite2D


func setup(unit: Unit, stage: ArenaStage3D) -> void:
	_unit = unit
	_stage = stage
	_body = unit.visual
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sorting_use_aabb_center = false
	pixel_size = 1.0
	_body.hide()
	_ground = UnitGroundVisual3D.new()
	add_child(_ground)
	_ground.setup(unit, stage)
	_sync_sprite()


func _process(_delta: float) -> void:
	if not is_instance_valid(_unit):
		queue_free()
		return
	_sync_sprite()
	_ground.sync()


func _sync_sprite() -> void:
	var local_offset := _body.global_position - _unit.global_position
	global_transform = Transform3D(_stage.camera.basis, _stage.billboard_anchor(_unit.global_position, local_offset))
	modulate = _unit.modulate * _body.modulate * _body.self_modulate

	if _body.material != null or _body.get_script() != null:
		_sync_canvas_body()
		return

	if _canvas != null:
		_canvas.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var frames := _body.sprite_frames
	texture = frames.get_frame_texture(_body.animation, _body.frame) if frames != null and frames.has_animation(_body.animation) else null
	scale = Vector3(_body.scale.x, _body.scale.y, 1.0)
	centered = _body.centered
	offset = Vector2(_body.offset.x, -_body.offset.y)
	flip_h = _body.flip_h
	flip_v = _body.flip_v


## 只在用到 CanvasItem 着色器或代码绘制时分配透明视口。
## 仍由同一个 Sprite3D 和场景深度缓冲绘制该单位。
func _sync_canvas_body() -> void:
	if _canvas == null:
		_canvas = SubViewport.new()
		_canvas.disable_3d = true
		_canvas.transparent_bg = true
		_canvas.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		add_child(_canvas)
		_canvas_body = AnimatedSprite2D.new()
		_canvas_body.set_script(_body.get_script())
		_canvas.add_child(_canvas_body)

	var frame_texture: Texture2D
	var frames := _body.sprite_frames
	if frames != null and frames.has_animation(_body.animation):
		frame_texture = frames.get_frame_texture(_body.animation, _body.frame)
	var bounds := Vector2(82.0, 164.0)
	if frame_texture != null:
		bounds = frame_texture.get_size()
		if not _body.centered:
			bounds *= 2.0
	bounds = (bounds + _body.offset.abs() * 2.0) * _body.scale.abs() + Vector2(32.0, 32.0)
	_canvas.size = Vector2i(ceilf(bounds.x), ceilf(bounds.y))
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_canvas_body.position = Vector2(_canvas.size) * 0.5
	_canvas_body.scale = _body.scale
	_canvas_body.material = _body.material
	_canvas_body.sprite_frames = frames
	_canvas_body.centered = _body.centered
	_canvas_body.offset = _body.offset
	_canvas_body.flip_h = _body.flip_h
	_canvas_body.flip_v = _body.flip_v
	if frame_texture != null:
		_canvas_body.animation = _body.animation
		_canvas_body.frame = _body.frame
	texture = _canvas.get_texture()
	scale = Vector3.ONE
	centered = true
	offset = Vector2.ZERO
	flip_h = false
	flip_v = false
