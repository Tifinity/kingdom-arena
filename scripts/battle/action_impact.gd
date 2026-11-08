class_name ActionImpact
extends RefCounted

## 近战、冲锋和投射物命中后共用的附加状态结算。


static func apply_on_hit(effect: ActionEffectDefinition, source: Unit, victim: Unit, blocked: bool) -> void:
	if effect == null or victim == null or not is_instance_valid(victim) or not victim.alive or blocked:
		return
	if effect.burn_duration > 0.0:
		victim.apply_burn(effect.burn_duration,
			source.attack_damage * effect.burn_dps_ratio if source != null and is_instance_valid(source) else 0.0,
			source if source != null and is_instance_valid(source) else null)
	if effect.status_duration > 0.0:
		victim.apply_status(effect, source if source != null and is_instance_valid(source) else null)
