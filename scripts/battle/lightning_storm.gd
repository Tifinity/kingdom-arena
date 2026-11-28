class_name LightningStorm
extends Node2D

var center: Vector2
var strike_count := 0

var _battle: Battle
var _caster: Unit
var _caster_team: int
var _effect: ActionEffectDefinition
var _rng := RandomNumberGenerator.new()
var _interval: float
var _strike_radius: float
var _damage: float
var _elapsed := 0.0
var _fx: LightningStormFx


func setup(caster: Unit, point: Vector2, effect: ActionEffectDefinition, interval: float, strike_radius: float) -> void:
	_caster = caster
	_caster_team = caster.team
	_battle = caster.battle
	_effect = effect
	center = _battle.clamp_unit_position(point)
	_interval = interval
	_strike_radius = strike_radius
	_damage = caster.apply_status_damage_bonus(effect.raw_damage(caster.current_attack_damage()), false)
	if _battle.replay_config == null:
		_rng.randomize()
	else:
		_rng.seed = _battle.replay_config.seed ^ (_battle.action_casts * 2654435761) ^ (_caster.replay_id * 8461)
	_fx = LightningStormFx.new()
	add_child(_fx)
	_fx.setup(_battle.stage, center, effect.radius, strike_radius)


func _physics_process(delta: float) -> void:
	if not _battle.battle_active:
		queue_free()
		return
	_elapsed += delta
	var last_tick := minf(_elapsed, _effect.duration)
	while (strike_count + 1) * _interval <= last_tick + 0.0001:
		strike_count += 1
		_strike(_roll_point())
	if _elapsed + 0.0001 >= _effect.duration:
		_fx.finish()
		set_physics_process(false)


func _roll_point() -> Vector2:
	for _attempt in 24:
		var point := center + Vector2.from_angle(_rng.randf() * TAU) * (_effect.radius * sqrt(_rng.randf()))
		if point.is_equal_approx(_battle.clamp_unit_position(point)):
			return point
	return center


func _strike(point: Vector2) -> void:
	_fx.strike(point, strike_count % 2 == 0)
	_battle.play_action_sound(_effect.impact_sound)
	var source: Unit = _caster if is_instance_valid(_caster) else null
	for victim in _battle.enemies_in_circle(_caster_team, point, _strike_radius):
		if victim.global_position.distance_to(center) > _effect.radius + victim.body_radius:
			continue
		victim.take_damage(_damage, source, victim.get_effect_point(), false, _effect.ignore_shield)
		if source != null:
			source.register_damage_hit(victim, true)
		_battle.action_hits += 1
