class_name HealEffectBehavior
extends ActionEffectBehavior


func execute(source: Unit, cast: ActionCast, effect: ActionEffectDefinition) -> void:
	if source.battle == null:
		return
	var cast_target: Unit = source if cast == null or cast.action.target_mode == CombatActionDefinition.TargetMode.SELF else cast.target
	var direction := cast.direction if cast != null else Vector2.ZERO
	var point := cast.point if cast != null else Vector2.ZERO
	var use_point := cast != null and cast.has_point
	var amount := effect.heal_amount + source.attack_damage * effect.heal_ratio
	for ally in ActionTargetQuery.allies(source, effect, cast_target, direction, point, use_point):
		ally.heal(amount, source)
