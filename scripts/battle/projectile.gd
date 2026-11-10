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
var speed := 900.0
var life := 2.6

var _velocity := Vector2.RIGHT
var _started := false
var _fizzle := 0.0
var _travel_elapsed := 0.0
var _impact_elapsed := -1.0

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
	is_skill = p_source.current_cast != null and p_source.current_cast.action.category == CombatActionDefinition.Category.SKILL
	global_position = p_source.get_muzzle_point()

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

	if target != null and is_instance_valid(target):
		var aim := target.get_hit_point() - global_position
		if aim.length() > 0.01:
			_velocity = aim.normalized() * speed
			rotation = _velocity.angle() if kind != UnitDefinition.ProjectileKind.MAGIC else 0.0
	_started = true
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
	if kind == UnitDefinition.ProjectileKind.HOLY_BOLT:
		_set_effect_frame(int(_travel_elapsed * 30.0) % 15)
	elif kind == UnitDefinition.ProjectileKind.FIREBALL:
		_set_effect_frame(int(_travel_elapsed * 16.0) % 4)
	elif kind == UnitDefinition.ProjectileKind.GHOSTFIRE:
		_set_effect_frame(mini(2, int(_travel_elapsed * 12.0)))

	if target != null and is_instance_valid(target) and target.alive:
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


func _hit() -> void:
	if target != null and is_instance_valid(target) and target.alive:
		var shooter: Unit = source if is_instance_valid(source) else null
		var blocked := target.is_guarding()
		target.take_damage(damage, shooter, global_position)
		if is_instance_valid(shooter):
			shooter.register_damage_hit(target, is_skill)
		ActionImpact.apply_on_hit(effect, shooter, target, blocked)
	if battle != null and is_instance_valid(battle):
		var spark_color := Color("#87d9ff") if kind == UnitDefinition.ProjectileKind.ICE else (
			Color("#ff9d42") if kind == UnitDefinition.ProjectileKind.FIREBALL else (
				Color("#8be38b") if kind == UnitDefinition.ProjectileKind.GHOSTFIRE else tint
			)
		)
		battle.spawn_hit_spark(global_position, spark_color, 1.35)
	if kind == UnitDefinition.ProjectileKind.ICE or kind == UnitDefinition.ProjectileKind.FIREBALL or kind == UnitDefinition.ProjectileKind.GHOSTFIRE:
		_impact_elapsed = 0.0
		_set_effect_frame(0 if kind == UnitDefinition.ProjectileKind.ICE else (3 if kind == UnitDefinition.ProjectileKind.GHOSTFIRE else 4))
	else:
		queue_free()


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
	var back := -_velocity.normalized() * 22.0
	if kind == UnitDefinition.ProjectileKind.MAGIC:
		draw_circle(Vector2.ZERO, 7.0, Color(tint, 0.16))
		draw_line(back, Vector2.ZERO, Color(tint, 0.28), 5.0)
	else:
		draw_line(back, Vector2.ZERO, Color(1.0, 0.9, 0.7, 0.22), 2.0)
