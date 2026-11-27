class_name HealEffectBehavior
extends ActionEffectBehavior


func execute(source: Unit, cast: ActionCast, effect: ActionEffectDefinition) -> void:
	if source.battle == null:
		return
	var cast_target: Unit = source if cast == null or cast.action.target_mode == CombatActionDefinition.TargetMode.SELF else cast.target
	var direction := cast.direction if cast != null else Vector2.ZERO
	var point := cast.point if cast != null else Vector2.ZERO
	var use_point := cast != null and cast.has_point
	var amount := effect.heal_amount + source.current_attack_damage() * effect.heal_ratio
	var passive := source.definition.passive
	var triggered_bonus := false
	for ally in ActionTargetQuery.allies(source, effect, cast_target, direction, point, use_point):
		var before := ally.hp
		var boosted := passive != null and passive.heal_multiplier(ally.hp_ratio()) > 1.0
		ally.heal(amount, source)
		if not boosted or ally.hp <= before:
			continue
		triggered_bonus = true
		if passive.heal_bonus_fx != null:
			source.battle.spawn_billboard_effect_at(passive.heal_bonus_fx, ally)
	if triggered_bonus:
		source.battle.play_action_sound(passive.heal_bonus_sound)
