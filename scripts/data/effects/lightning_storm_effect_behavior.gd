class_name LightningStormEffectBehavior
extends ActionEffectBehavior

@export_range(0.1, 2.0, 0.1) var interval := 0.5
@export_range(10.0, 600.0, 1.0) var strike_radius := 66.0


func execute(source: Unit, cast: ActionCast, effect: ActionEffectDefinition) -> void:
	if not source.battle is Battle or cast == null or not cast.has_point or interval <= 0.0:
		return
	var storm := LightningStorm.new()
	source.battle.effects_root.add_child(storm)
	storm.setup(source, cast.point, effect, interval, strike_radius)
