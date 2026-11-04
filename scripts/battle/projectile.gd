class_name Projectile
extends Node2D

## 箭矢 / 法术弹。锁定目标追踪，命中时结算伤害并生成打击特效。

const ARROW_TEXTURE := preload("res://assets/projectiles/arrow.png")
const ORB_TEXTURE := preload("res://assets/projectiles/magic_orb.png")

var source: Unit
var target: Unit
var battle: Node
var damage := 0.0
var kind := 0
var tint := Color.WHITE
var can_interrupt := true
var speed := 900.0
var life := 2.6

var _velocity := Vector2.RIGHT
var _started := false
var _fizzle := 0.0

@onready var sprite: Sprite2D = $Sprite


func setup(p_source: Unit, p_target: Unit, p_damage: float, p_kind: int, p_color: Color, p_can_interrupt := true) -> void:
	source = p_source
	target = p_target
	battle = p_source.battle if p_source != null else null
	damage = p_damage
	kind = p_kind
	tint = p_color
	can_interrupt = p_can_interrupt
	global_position = p_source.get_muzzle_point()

	if kind == UnitDefinition.ProjectileKind.MAGIC:
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
	life -= delta
	if life <= 0.0:
		queue_free()
		return

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
		target.take_damage(damage, shooter, global_position, can_interrupt)
	if battle != null and is_instance_valid(battle):
		battle.spawn_hit_spark(global_position, tint, 1.0 if kind != UnitDefinition.ProjectileKind.MAGIC else 1.35)
	queue_free()


func _draw() -> void:
	var back := -_velocity.normalized() * 22.0
	if kind == UnitDefinition.ProjectileKind.MAGIC:
		draw_circle(Vector2.ZERO, 7.0, Color(tint, 0.16))
		draw_line(back, Vector2.ZERO, Color(tint, 0.28), 5.0)
	else:
		draw_line(back, Vector2.ZERO, Color(1.0, 0.9, 0.7, 0.22), 2.0)
