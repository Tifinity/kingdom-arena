class_name Projectile
extends Node2D

## 箭矢 / 法术弹。锁定目标追踪，命中时结算伤害并生成打击特效。

const ARROW_TEXTURE := preload("res://assets/projectiles/arrow.png")
const ORB_TEXTURE := preload("res://assets/projectiles/magic_orb.png")
const ICE_TEXTURE := preload("res://assets/projectiles/wizard_ice.png")
const FIREBALL_TEXTURE := preload("res://assets/projectiles/wizard_fireball.png")
const HOLY_BOLT_TEXTURE := preload("res://assets/fx/pixelfx/holy_laser_bolt.png")
const GHOSTFIRE_TEXTURE := preload("res://assets/magic/necromancer_attack02_effect.png")

var source: Unit
var target: Unit
var battle: Node
var damage := 0.0
var kind := 0
var tint := Color.WHITE
var effect: ActionEffectDefinition
var is_skill := false
var straight_flight := false
var speed := 900.0
var life := 2.6

var _velocity := Vector2.RIGHT
var _started := false
var _fizzle := 0.0
var _travel_elapsed := 0.0
var _impact_elapsed := -1.0
var _stage: ArenaStage3D
var _sprite_3d: Sprite3D
var _launch_point: Vector2
var _launch_height := 0.0
var _aim_point: Vector2
var _aim_height := 0.0
var _trail_offset := Vector2.ZERO
var _flight_frames: SpriteFrames
var _intercepts := false
var _enemy_team := -1
var _remaining_range := 0.0
var _flight_ground: Vector2
var _arc_duration := 0.0
var _arc_ground_origin: Vector2

@onready var sprite: Sprite2D = $Sprite


func setup(p_source: Unit, p_target: Unit, p_damage: float, p_kind: int, p_color: Color, p_effect: ActionEffectDefinition = null) -> void:
	source = p_source
	target = p_target
	battle = p_source.battle if p_source != null else null
	damage = p_damage
	kind = p_kind
	tint = Color("#87d9ff") if p_kind == UnitDefinition.ProjectileKind.ICE else (
		Color("#ff9d42") if p_kind == UnitDefinition.ProjectileKind.FIREBALL else (
			Color("#8be38b") if p_kind == UnitDefinition.ProjectileKind.GHOSTFIRE else p_color
		)
	)
	effect = p_effect
	straight_flight = effect != null and effect.straight_projectile
	is_skill = p_source.current_cast != null and p_source.current_cast.action.category == CombatActionDefinition.Category.SKILL
	global_position = p_source.get_muzzle_point()
	_launch_point = global_position
	_launch_height = source.global_position.y - _launch_point.y

	if kind == UnitDefinition.ProjectileKind.HOLY_BOLT:
		sprite.scale = Vector2(0.8, 0.8)
		speed = 900.0
		_set_effect_frame(0)
	elif kind == UnitDefinition.ProjectileKind.ICE or kind == UnitDefinition.ProjectileKind.FIREBALL:
		sprite.scale = Vector2(2.4, 2.4)
		speed = 800.0
		_set_effect_frame(7 if kind == UnitDefinition.ProjectileKind.ICE else 0)
	elif kind == UnitDefinition.ProjectileKind.GHOSTFIRE:
		sprite.scale = Vector2(2.4, 2.4)
		sprite.modulate = Color(0.9, 1.0, 0.85, 1.0)
		speed = 700.0
		_set_effect_frame(0)
	elif kind == UnitDefinition.ProjectileKind.MAGIC:
		sprite.texture = ORB_TEXTURE
		sprite.scale = Vector2(0.95, 0.95)
		sprite.modulate = tint.lightened(0.25)
		speed = 760.0
	else:
		sprite.texture = ARROW_TEXTURE
		sprite.scale = Vector2(1.7, 1.7)
		sprite.modulate = Color(1.0, 0.96, 0.86)
		speed = 1180.0

	if effect != null and effect.projectile_frames != null:
		_flight_frames = effect.projectile_frames
		sprite.scale = Vector2.ONE * effect.projectile_visual_scale
		sprite.offset = effect.projectile_visual_offset
		sprite.texture = _flight_frames.get_frame_texture(&"default", 0)

	_intercepts = effect != null and effect.projectile_collision_width > 0.0
	if effect != null and effect.projectile_ground_arc:
		_aim_point = source.current_cast.point
		_arc_ground_origin = _launch_point + Vector2(0, _launch_height)
		_flight_ground = _arc_ground_origin
		var distance := source.global_position.distance_to(_aim_point)
		speed = effect.projectile_speed_override if effect.projectile_speed_override > 0.0 else speed
		_arc_duration = maxf(0.08, 1.15 * distance / speed)
		life = maxf(life, _arc_duration + 0.1)
	elif _intercepts:
		var cast := source.current_cast
		var direction := cast.direction if cast != null else Vector2(float(source.facing), 0.0)
		speed = effect.projectile_speed_override if effect.projectile_speed_override > 0.0 else speed
		_remaining_range = cast.action.action_range if cast != null else source.attack_range
		life = maxf(life, _remaining_range / speed + 0.1)
		_enemy_team = 1 - source.team
		_flight_ground = source.global_position
		_velocity = direction * speed
		rotation = direction.angle()
	elif target != null and is_instance_valid(target):
		var aim := target.get_hit_point() - global_position
		if aim.length() > 0.01:
			_velocity = aim.normalized() * speed
			rotation = _velocity.angle() if kind != UnitDefinition.ProjectileKind.MAGIC else 0.0
	_started = true
	if battle is Battle:
		_stage = battle.stage
		if _arc_duration <= 0.0:
			_aim_point = _launch_point + _velocity
			_aim_height = _launch_height
		_sprite_3d = Sprite3D.new()
		_sprite_3d.pixel_size = 1.0
		_sprite_3d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_sprite_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_stage.projectiles.add_child(_sprite_3d)
		tree_exiting.connect(_sprite_3d.queue_free, CONNECT_ONE_SHOT)
		sprite.hide()
		_sync_presentation()
	queue_redraw()


func _process(_delta: float) -> void:
	if _sprite_3d != null:
		_sync_presentation()


func _sync_presentation() -> void:
	if not _intercepts and _impact_elapsed < 0.0 and is_instance_valid(target) and target.alive:
		_aim_point = target.get_hit_point()
		_aim_height = target.global_position.y - _aim_point.y
	var path := _aim_point - _launch_point
	var progress := clampf((global_position - _launch_point).dot(path) / maxf(path.length_squared(), 1.0), 0.0, 1.0)
	var height := lerpf(_launch_height, _aim_height, progress)
	var ground := global_position + Vector2(0.0, height)
	var offset := Vector2(0.0, -height)
	var screen_scale := _stage.ground_transform.x.length()
	var basis := _stage.camera.basis
	var angle := rotation
	if kind != UnitDefinition.ProjectileKind.MAGIC:
		# 贴图朝向沿投影后的飞行线，保留始末高度的差。
		var ground_path := path + Vector2(0.0, _aim_height - _launch_height)
		var projected_path := _stage.ground_transform.basis_xform(ground_path) + Vector2(0.0, _launch_height - _aim_height) * screen_scale
		if projected_path.length_squared() > 1.0:
			angle = projected_path.angle()
	if _arc_duration > 0.0:
		var arc_progress := clampf(_travel_elapsed / _arc_duration, 0.0, 1.0)
		ground = _flight_ground
		height = ground.y - global_position.y
		offset = Vector2(0, -height)
		var height_slope := -2.0 * _launch_height * arc_progress
		var tangent := _stage.ground_transform.basis_xform(_aim_point - _arc_ground_origin)
		tangent.y -= height_slope * screen_scale
		angle = tangent.angle()
	_sprite_3d.global_transform = Transform3D(basis.rotated(basis.z, -angle), _stage.ground_to_world(ground, height / basis.y.y))
	_sprite_3d.scale = Vector3(sprite.scale.x, sprite.scale.y, 1.0)
	_sprite_3d.offset = Vector2(sprite.offset.x, -sprite.offset.y)
	_sprite_3d.texture = sprite.texture
	_sprite_3d.modulate = sprite.modulate
	_trail_offset = to_local(_stage.elevated_canvas_point(ground, offset))
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _impact_elapsed >= 0.0:
		_impact_elapsed += delta
		var frame_base := 0 if kind == UnitDefinition.ProjectileKind.ICE else (3 if kind == UnitDefinition.ProjectileKind.GHOSTFIRE else 4)
		var max_frame := 5 if kind == UnitDefinition.ProjectileKind.GHOSTFIRE else 6
		_set_effect_frame(mini(max_frame, int(_impact_elapsed * 16.0) + frame_base))
		var impact_life := 0.44 if kind == UnitDefinition.ProjectileKind.ICE else (0.24 if kind == UnitDefinition.ProjectileKind.GHOSTFIRE else 0.19)
		if _impact_elapsed >= impact_life:
			queue_free()
		return
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	_travel_elapsed += delta
	if _flight_frames != null:
		var frame_count := _flight_frames.get_frame_count(&"default")
		var frame_index := int(_travel_elapsed * _flight_frames.get_animation_speed(&"default")) % frame_count
		sprite.texture = _flight_frames.get_frame_texture(&"default", frame_index)
	elif kind == UnitDefinition.ProjectileKind.HOLY_BOLT:
		_set_effect_frame(int(_travel_elapsed * 30.0) % 15)
	elif kind == UnitDefinition.ProjectileKind.FIREBALL:
		_set_effect_frame(int(_travel_elapsed * 16.0) % 4)
	elif kind == UnitDefinition.ProjectileKind.GHOSTFIRE:
		_set_effect_frame(mini(2, int(_travel_elapsed * 12.0)))

	if _arc_duration > 0.0:
		var progress := clampf(_travel_elapsed / _arc_duration, 0.0, 1.0)
		_flight_ground = _arc_ground_origin.lerp(_aim_point, progress)
		var height := _launch_height * (1.0 - progress * progress)
		global_position = _flight_ground - Vector2(0, height)
		if progress >= 1.0:
			_land()
		return
	if _intercepts:
		_advance_intercepting_projectile(delta)
		return
	if target != null and is_instance_valid(target) and target.alive:
		if straight_flight:
			var next_position := global_position + _velocity * delta
			var segment := next_position - global_position
			var aim := target.get_hit_point()
			var progress := clampf((aim - global_position).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
			var nearest := global_position + segment * progress
			if aim.distance_to(nearest) <= target.body_radius * 0.6 + 10.0:
				global_position = nearest
				_hit()
				return
			global_position = next_position
			queue_redraw()
			return
		var aim := target.get_hit_point()
		var offset := aim - global_position
		var step := speed * delta
		if offset.length() <= step + 10.0:
			global_position = aim
			_hit()
			return
		_velocity = offset.normalized() * speed
		global_position += _velocity * delta
		if kind == UnitDefinition.ProjectileKind.MAGIC:
			rotation += delta * 5.0
		else:
			rotation = _velocity.angle()
	else:
		# 目标死亡后继续飞一小段，避免弹道瞬间消失。
		_fizzle += delta
		global_position += _velocity * delta
		if _fizzle > 0.25:
			queue_free()
	queue_redraw()


func _advance_intercepting_projectile(delta: float) -> void:
	var step := minf(speed * delta, _remaining_range)
	var direction := _velocity.normalized()
	var contact := ActionTargetQuery.first_projectile_contact(_flight_ground, direction, step,
		effect.projectile_collision_width * 0.5, battle.living_units(_enemy_team))
	var travel: float = contact.distance
	_flight_ground += direction * travel
	global_position += direction * travel
	target = contact.unit
	if target != null:
		_hit()
		return
	_remaining_range -= step
	if _remaining_range <= 0.0:
		queue_free()


func _hit() -> void:
	if target != null and is_instance_valid(target) and target.alive:
		_apply_hit(target)
	if effect != null and effect.projectile_impact_scene != null and is_instance_valid(target) and _stage != null:
		battle.spawn_billboard_effect_at(effect.projectile_impact_scene, target)
		queue_free()
		return
	if battle != null and is_instance_valid(battle):
		var spark_color := Color("#87d9ff") if kind == UnitDefinition.ProjectileKind.ICE else (
			Color("#ff9d42") if kind == UnitDefinition.ProjectileKind.FIREBALL else (
				Color("#8be38b") if kind == UnitDefinition.ProjectileKind.GHOSTFIRE else tint
			)
		)
		var impact_point := global_position
		if _stage != null and is_instance_valid(target):
			impact_point = target.get_effect_point()
		battle.spawn_hit_spark(impact_point, spark_color, 1.35)
	if kind == UnitDefinition.ProjectileKind.ICE or kind == UnitDefinition.ProjectileKind.FIREBALL or kind == UnitDefinition.ProjectileKind.GHOSTFIRE:
		_impact_elapsed = 0.0
		_set_effect_frame(0 if kind == UnitDefinition.ProjectileKind.ICE else (3 if kind == UnitDefinition.ProjectileKind.GHOSTFIRE else 4))
	else:
		queue_free()


func _land() -> void:
	for victim in battle.units_in_circle(source, _aim_point, effect.radius):
		if victim.alive:
			_apply_hit(victim, false)
	battle.play_action_sound(effect.impact_sound)
	if effect.projectile_impact_scene != null:
		var impact := effect.projectile_impact_scene.instantiate() as RosterAreaFx
		battle.effects_root.add_child(impact)
		impact.setup_at(battle, _aim_point, effect.radius)
	queue_free()


func _apply_hit(victim: Unit, play_sound := true) -> void:
	var shooter: Unit = source if is_instance_valid(source) else null
	var blocked := victim.is_guarding()
	var pierces_shield := effect != null and effect.ignore_shield
	var impact_point := victim.get_effect_point() if _stage != null else global_position
	victim.take_damage(damage, shooter, impact_point, false, pierces_shield)
	if is_instance_valid(shooter):
		shooter.register_damage_hit(victim, is_skill, blocked)
	ActionImpact.apply_on_hit(effect, shooter, victim, blocked, play_sound)


func _set_effect_frame(frame: int) -> void:
	var atlas := AtlasTexture.new()
	if kind == UnitDefinition.ProjectileKind.HOLY_BOLT:
		atlas.atlas = HOLY_BOLT_TEXTURE
		atlas.region = Rect2((frame % 2) * 128, int(frame / 2) * 32, 128, 32)
		sprite.texture = atlas
		return
	if kind == UnitDefinition.ProjectileKind.ICE:
		atlas.atlas = ICE_TEXTURE
	elif kind == UnitDefinition.ProjectileKind.GHOSTFIRE:
		atlas.atlas = GHOSTFIRE_TEXTURE
	else:
		atlas.atlas = FIREBALL_TEXTURE
	atlas.region = Rect2(frame * 100, 0, 100, 100)
	sprite.texture = atlas


func _draw() -> void:
	if _flight_frames != null:
		return
	draw_set_transform(_trail_offset)
	var back := -_velocity.normalized()
	var magic := kind == UnitDefinition.ProjectileKind.MAGIC
	var trace := tint if magic else Color("#f3d99e")
	for index in range(1, 5):
		PixelCombatDraw.dot(self, back * (index * 5.0), Color(trace, 0.39 - index * 0.07))
