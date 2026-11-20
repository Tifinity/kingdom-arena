class_name ArenaStage3D
extends Node3D

## 战斗仍以 Vector2 表示地面坐标。舞台以 X/Z 表示同一平面，Y 留给高度。
const PITCH := deg_to_rad(38.0)
const CAMERA_DISTANCE := 2450.0
const SAMPLE_DISTANCE := 128.0
const SKY_DISTANCE := 4300.0

@onready var camera: Camera3D = $Camera3D
@onready var actors: Node3D = $Actors
@onready var projectiles: Node3D = $Projectiles

var ground_transform := Transform2D.IDENTITY
var _ground_inverse := Transform2D.IDENTITY

@onready var _sky_viewport: SubViewport = $SkyViewport
@onready var _sky: Sprite3D = $Sky


func _ready() -> void:
	_sky.texture = _sky_viewport.get_texture()


func frame_field(view_size: Vector2, field_min: Vector2, field_max: Vector2) -> void:
	var center := (field_min + field_max) * 0.5
	camera.rotation.x = -PITCH
	camera.size = view_size.y
	# 相机把场地中心放在屏幕下方，给战斗标题和角色留出空间。
	var screen_offset := view_size.y * 0.16
	camera.position = ground_to_world(center) + camera.basis.z * CAMERA_DISTANCE + camera.basis.y * screen_offset
	_sky_viewport.size = Vector2i(view_size.ceil())
	_sky.transform = Transform3D(camera.basis, camera.position - camera.basis.z * SKY_DISTANCE)

	# 正交投影在固定地面上是仿射变换。让旧的地面绘制使用同一台相机的基向量。
	var origin := camera.unproject_position(Vector3.ZERO)
	var right := camera.unproject_position(Vector3(SAMPLE_DISTANCE, 0.0, 0.0))
	var down := camera.unproject_position(Vector3(0.0, 0.0, SAMPLE_DISTANCE))
	ground_transform = Transform2D((right - origin) / SAMPLE_DISTANCE, (down - origin) / SAMPLE_DISTANCE, origin)
	_ground_inverse = ground_transform.affine_inverse()

	var span := field_max - field_min
	$Floor.position = ground_to_world(center) + Vector3.DOWN
	$Floor.scale = Vector3(span.x + 420.0, 1.0, span.y + 580.0)
	var material := $Floor.material_override as ShaderMaterial
	material.set_shader_parameter(&"field_min", field_min)
	material.set_shader_parameter(&"field_max", field_max)

	$Walls/BackWall.position = Vector3(center.x, 57.0, field_min.y - 124.0)
	$Walls/BackWall.scale = Vector3(span.x + 360.0, 114.0, 76.0)
	$Walls/Step.position = Vector3(center.x, 23.0, field_min.y - 74.0)
	$Walls/Step.scale = Vector3(span.x + 360.0, 46.0, 42.0)
	$Walls/LeftTower.position = Vector3(field_min.x - 124.0, 109.0, field_min.y - 128.0)
	$Walls/RightTower.position = Vector3(field_max.x + 124.0, 109.0, field_min.y - 128.0)
	$Walls/LeftTower.scale = Vector3(90.0, 218.0, 104.0)
	$Walls/RightTower.scale = $Walls/LeftTower.scale


func ground_to_world(point: Vector2, height := 0.0) -> Vector3:
	return Vector3(point.x, height, point.y)


func screen_to_ground(point: Vector2) -> Vector2:
	return _ground_inverse * point


## 把旧角色素材的屏幕偏移挂到脚下的 3D 锚点，保持像素比例。
func billboard_anchor(ground: Vector2, offset: Vector2) -> Vector3:
	var screen_scale := ground_transform.x.length()
	return ground_to_world(ground) + (camera.basis.x * offset.x - camera.basis.y * offset.y) / screen_scale


## 给投影 Canvas 中的旧命中特效提供一个能对齐立绘的锚点。
func elevated_canvas_point(ground: Vector2, offset: Vector2) -> Vector2:
	return screen_to_ground(ground_transform * ground + offset)
