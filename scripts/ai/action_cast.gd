class_name ActionCast
extends RefCounted

## 一次施放的运行时数据。Action/Effect Resource 始终只保存静态配置。

var action: CombatActionDefinition
var target: Unit
var point := Vector2.ZERO
var has_point := false
var direction := Vector2.ZERO
var elapsed := 0.0
var duration := 0.0
var next_effect := 0
var advanced_distance := 0.0
var charge_destination := Vector2.ZERO
var charge_hits: Dictionary = {}
var hit_targets: Dictionary = {}
var effects: Array[ActionEffectDefinition] = []


static func create(plan: ActionPlan) -> ActionCast:
	var cast := ActionCast.new()
	cast.action = plan.action
	cast.target = plan.target
	cast.point = plan.point
	cast.has_point = plan.has_point
	cast.direction = plan.direction
	return cast


func record_hit(victim: Unit) -> void:
	hit_targets[victim.get_instance_id()] = true


func has_hit(victim: Unit) -> bool:
	return hit_targets.has(victim.get_instance_id())
