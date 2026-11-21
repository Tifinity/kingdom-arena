class_name SummonEffectBehavior
extends ActionEffectBehavior


func execute(source: Unit, _cast: ActionCast, effect: ActionEffectDefinition) -> void:
	if source.battle != null:
		source.battle.spawn_summons(source, effect.summon_unit_id, effect.summon_count, effect.effect_scene)
