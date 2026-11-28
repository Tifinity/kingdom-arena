class_name LightningStormFx
extends Node3D

const CLOUD := preload("res://assets/fx/pixelfx/wizard_storm_cloud.png")
const STRIKE := preload("res://assets/fx/pixelfx/wizard_storm_strike.png")
const ZONE := preload("res://assets/fx/pixelfx/wizard_storm_zone.png")
const CLOUD_BOTTOM := 198.0
const CLOUD_FRAME_HEIGHT := 104.0
const STRIKE_FRAMES := 9
const STRIKE_FPS := 30.0

var _stage: ArenaStage3D
var _center: Vector2
var _strike_radius: float
var _cloud: Sprite3D
var _land: Sprite3D
var _bolt: Sprite3D
var _age := 0.0
var _bolt_age := 1.0
var _fade_age := -1.0


func setup(stage: ArenaStage3D, center: Vector2, radius: float, strike_radius: float) -> void:
	_stage = stage
	_center = center
	_strike_radius = strike_radius
	_cloud = _add_sprite(CLOUD, 6, 10, Vector2(0.0, CLOUD_FRAME_HEIGHT * 0.5))
	_cloud.global_transform = Transform3D(stage.camera.basis.scaled_local(Vector3(radius / 68.0, 1.42, 1.0)),
		stage.billboard_anchor(center, Vector2(0.0, -CLOUD_BOTTOM)))
	_cloud.modulate.a = 0.0
	_land = _add_sprite(ZONE, 1, 1, Vector2.ZERO)
	_land.render_priority = ArenaStage3D.GROUND_MARKER_PRIORITY + 1
	var land_basis := Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP).scaled(Vector3.ONE * (radius / 80.0))
	_land.global_transform = Transform3D(land_basis, stage.ground_to_world(center, 0.2))
	_land.modulate.a = 0.0
	_bolt = _add_sprite(STRIKE, 4, 3, Vector2(0.0, 96.0))
	_bolt.sorting_offset = 4.0
	_bolt.hide()


func strike(point: Vector2, mirrored: bool) -> void:
	_bolt_age = 0.0
	_bolt.frame = 0
	_bolt.flip_h = mirrored
	var ground_offset := _stage.ground_transform.basis_xform(point - _center)
	var height := CLOUD_BOTTOM + 34.0 + ground_offset.y / _stage.ground_transform.x.length()
	var strike_basis := _stage.camera.basis.scaled_local(Vector3(_strike_radius / 77.0, maxf(85.0, height) / 224.0, 1.0))
	_bolt.global_transform = Transform3D(strike_basis, _stage.billboard_anchor(point, Vector2.ZERO))
	_bolt.show()


func finish() -> void:
	_fade_age = 0.0


func _process(delta: float) -> void:
	_age += delta
	_bolt_age += delta
	_cloud.frame = int(_age * 20.0) % 60
	var bolt_frame := int(_bolt_age * STRIKE_FPS)
	_bolt.visible = bolt_frame < STRIKE_FRAMES
	if _bolt.visible:
		_bolt.frame = bolt_frame
	var opacity := clampf(_age / 0.32, 0.0, 1.0)
	if _fade_age >= 0.0:
		_fade_age += delta
		opacity *= 1.0 - clampf(_fade_age / 0.30, 0.0, 1.0)
		if _fade_age >= 0.30 and not _bolt.visible:
			get_parent().queue_free()
	_cloud.modulate.a = opacity
	_land.modulate.a = 0.66 * opacity


func _add_sprite(texture: Texture2D, columns: int, rows: int, offset: Vector2) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.hframes = columns
	sprite.vframes = rows
	sprite.offset = offset
	sprite.pixel_size = 1.0
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.sorting_use_aabb_center = false
	add_child(sprite)
	return sprite
