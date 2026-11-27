class_name ArenaStage3D
extends Node3D

## 战斗仍以 Vector2 表示地面坐标。舞台以 X/Z 表示同一平面，Y 留给高度。
const PITCH := deg_to_rad(50.0)
const TRAINING_PITCH := deg_to_rad(38.0)
const SIDE_GUTTER := 288.0
const CAMERA_DISTANCE := 2450.0
const SAMPLE_DISTANCE := 128.0
const SKY_DISTANCE := 4300.0
const SHADOW_PRIORITY := -20
const GROUND_MARKER_PRIORITY := -10

@onready var camera: Camera3D = $Camera3D
@onready var actors: Node3D = $Actors
@onready var projectiles: Node3D = $Projectiles

var ground_transform := Transform2D.IDENTITY
var _ground_inverse := Transform2D.IDENTITY
var _camera_origin := Vector3.ZERO
var _view_height := 900.0
var _vertical_offset := 0.0

@onready var _sky_viewport: SubViewport = $SkyViewport
@onready var _sky: Sprite3D = $Sky


func _ready() -> void:
	_sky.texture = _sky_viewport.get_texture()


func frame_field(view_size: Vector2, field_min: Vector2, field_max: Vector2, training_mode: bool) -> void:
	var center := (field_min + field_max) * 0.5
	var span := field_max - field_min
	camera.rotation.x = -TRAINING_PITCH if training_mode else -PITCH
	var field_width := maxf(view_size.x - SIDE_GUTTER * 2.0, view_size.x * 0.5)
	camera.size = view_size.y if training_mode else view_size.y * maxf(1.0, span.x / field_width)
	var screen_offset := view_size.y * 0.16 if training_mode else 0.0
	_view_height = view_size.y
	_camera_origin = ground_to_world(center) + camera.basis.z * CAMERA_DISTANCE + camera.basis.y * screen_offset
	set_vertical_offset(_vertical_offset)

	_sky.visible = training_mode
	$Walls.visible = training_mode
	_sky_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if training_mode else SubViewport.UPDATE_DISABLED
	if training_mode:
		_sky_viewport.size = Vector2i(view_size.ceil())
		_sky.transform = Transform3D(camera.basis, camera.position - camera.basis.z * SKY_DISTANCE)

	$Floor.position = ground_to_world(center) + Vector3.DOWN
	var floor_size := span + Vector2(420.0, 580.0)
	if not training_mode:
		# 名册打开时镜头会上移，铺地需要覆盖滑动前后的视口。
		floor_size = Vector2(
			view_size.x / ground_transform.x.length() + 300.0,
			view_size.y / ground_transform.y.length() + 1200.0)
	$Floor.scale = Vector3(floor_size.x, 1.0, floor_size.y)
	var material := $Floor.material_override as ShaderMaterial
	material.set_shader_parameter(&"field_min", field_min)
	material.set_shader_parameter(&"field_max", field_max)
	material.set_shader_parameter(&"training_mode", training_mode)

	if training_mode:
		_frame_training_walls(view_size, field_min, field_max, center, span)


func set_vertical_offset(pixels: float) -> void:
	_vertical_offset = pixels
	camera.position = _camera_origin - camera.basis.y * (pixels * camera.size / _view_height)
	# 地面、角色拾取和二维叠层共享正交相机的投影。
	var origin := camera.unproject_position(Vector3.ZERO)
	var right := camera.unproject_position(Vector3(SAMPLE_DISTANCE, 0.0, 0.0))
	var down := camera.unproject_position(Vector3(0.0, 0.0, SAMPLE_DISTANCE))
	ground_transform = Transform2D((right - origin) / SAMPLE_DISTANCE, (down - origin) / SAMPLE_DISTANCE, origin)
	_ground_inverse = ground_transform.affine_inverse()


func _frame_training_walls(view_size: Vector2, field_min: Vector2, field_max: Vector2, center: Vector2, span: Vector2) -> void:
	$Walls/BackWall.position = Vector3(center.x, 57.0, field_min.y - 124.0)
	$Walls/BackWall.scale = Vector3(span.x + 360.0, 114.0, 76.0)
	$Walls/Step.position = Vector3(center.x, 23.0, field_min.y - 74.0)
	$Walls/Step.scale = Vector3(span.x + 360.0, 46.0, 42.0)
	var tower_offset := clampf((view_size.x - span.x) * 0.5 - 58.0, 0.0, 124.0)
	$Walls/LeftTower.position = Vector3(field_min.x - tower_offset, 109.0, field_min.y - 128.0)
	$Walls/RightTower.position = Vector3(field_max.x + tower_offset, 109.0, field_min.y - 128.0)
	$Walls/LeftTower.scale = Vector3(90.0, 218.0, 104.0)
	$Walls/RightTower.scale = $Walls/LeftTower.scale


func ground_to_world(point: Vector2, height := 0.0) -> Vector3:
	return Vector3(point.x, height, point.y)


## 试炼场中只显示后墙以内、有地面承接的部分。
func training_floor_bounds() -> Rect2:
	var floor_bounds: AABB = $Floor.global_transform * $Floor.get_aabb()
	var wall_bounds: AABB = $Walls/BackWall.global_transform * $Walls/BackWall.get_aabb()
	var start := Vector2(floor_bounds.position.x, maxf(floor_bounds.position.z, wall_bounds.end.z))
	var end := Vector2(floor_bounds.end.x, floor_bounds.end.z)
	return Rect2(start, end - start)


## 保留编辑场景中 Sprite2D 的贴图、帧和脚下尺寸，让它参与 3D 场地的绘制顺序。
func add_ground_sprite(source: Sprite2D, parent: Node, priority: int) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = source.texture
	sprite.region_enabled = source.region_enabled
	sprite.region_rect = source.region_rect
	sprite.hframes = source.hframes
	sprite.vframes = source.vframes
	sprite.flip_h = source.flip_h
	sprite.flip_v = source.flip_v
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR if source.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR else BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.pixel_size = 1.0
	sprite.render_priority = priority
	parent.add_child(sprite)
	return sprite


func sync_ground_sprite(sprite: Sprite3D, source: Sprite2D, height: float) -> void:
	var transform_2d := source.global_transform
	var x := ground_to_world(transform_2d.x)
	var y := -ground_to_world(transform_2d.y)
	var center := transform_2d * source.get_rect().get_center()
	sprite.global_transform = Transform3D(Basis(x, y, x.cross(y).normalized()), ground_to_world(center, height))
	sprite.frame = source.frame


func screen_to_ground(point: Vector2) -> Vector2:
	return _ground_inverse * point


## 把旧角色素材的屏幕偏移挂到脚下的 3D 锚点，保持像素比例。
func billboard_anchor(ground: Vector2, offset: Vector2) -> Vector3:
	return ground_to_world(ground) + camera.basis.x * offset.x - camera.basis.y * offset.y


## 给投影 Canvas 中的旧命中特效提供一个能对齐立绘的锚点。
func elevated_canvas_point(ground: Vector2, offset: Vector2) -> Vector2:
	return screen_to_ground(ground_transform * ground + offset * ground_transform.x.length())
