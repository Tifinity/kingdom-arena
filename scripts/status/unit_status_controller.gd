class_name UnitStatusController
extends Node

## 单位状态控制器：统一管理状态实例、叠加规则、Tick、属性修改和视觉表现。
## Unit/FSM 只通过 can_move / can_act / has_tag 查询结果，不关心具体状态名称。

signal changed

var unit: Unit
var _instances: Array[StatusInstance] = []
var _visuals: Node2D
var _next_instance_id := 1


func setup(p_unit: Unit) -> void:
	unit = p_unit
	if unit != null:
		_visuals = unit.get_node_or_null("StatusVisuals") as Node2D
	clear_all(false)


func apply(definition: StatusDefinition, source: Unit, options: Dictionary = {}) -> StatusInstance:
	if definition == null or definition.behavior == null or unit == null or not unit.alive:
		return null
	var duration: float = maxf(0.0, float(options.get("duration", definition.duration)))
	var power: float = float(options.get("power", definition.base_power))
	var requested_stacks: int = maxi(1, int(options.get("stacks", 1)))
	if duration <= 0.0 and definition.tick_interval <= 0.0:
		return null

	var existing := _find_instance(definition, source)
	if existing == null:
		return _create_instance(definition, source, duration, power, requested_stacks)

	match definition.stack_policy:
		StatusDefinition.StackPolicy.REFRESH:
			existing.remaining = maxf(existing.remaining, duration)
			definition.behavior.on_refresh(existing)
		StatusDefinition.StackPolicy.EXTEND:
			existing.remaining += duration
			definition.behavior.on_refresh(existing)
		StatusDefinition.StackPolicy.STRONGEST:
			if definition.behavior.is_stronger(existing.power, power):
				existing.power = power
				existing.source = source
			existing.remaining = maxf(existing.remaining, duration)
			definition.behavior.on_refresh(existing)
		StatusDefinition.StackPolicy.STACK:
			var old_stacks := existing.stacks
			existing.stacks = mini(definition.max_stacks, existing.stacks + requested_stacks)
			existing.power = maxf(existing.power, power)
			existing.remaining = maxf(existing.remaining, duration)
			definition.behavior.on_stack(existing, old_stacks)
			if existing.stacks >= definition.max_stacks:
				if definition.behavior.on_max_stacks(existing):
					if _instances.has(existing):
						_remove_instance(existing, false)
					return null
		StatusDefinition.StackPolicy.INDEPENDENT:
			return _create_instance(definition, source, duration, power, requested_stacks)
	changed.emit()
	return existing


func _create_instance(definition: StatusDefinition, source: Unit, duration: float, power: float, stacks: int) -> StatusInstance:
	var instance := StatusInstance.new()
	instance.definition = definition
	instance.target = unit
	instance.source = source
	instance.remaining = duration
	instance.stacks = mini(maxi(stacks, 1), definition.max_stacks)
	instance.power = power if power > 0.0 else definition.base_power
	instance.instance_id = _next_instance_id
	_next_instance_id += 1
	_instances.append(instance)
	_spawn_vfx(instance)
	definition.behavior.on_apply(instance)
	changed.emit()
	return instance


func _find_instance(definition: StatusDefinition, source: Unit) -> StatusInstance:
	for instance in _instances:
		if instance.definition.id != definition.id:
			continue
		if definition.source_scoped and instance.source != source:
			continue
		return instance
	return null


func _physics_process(delta: float) -> void:
	if unit == null or not unit.alive:
		return
	for raw_instance in _instances.duplicate():
		var instance: StatusInstance = raw_instance
		if not _instances.has(instance):
			continue
		var active := minf(delta, instance.remaining)
		instance.remaining = maxf(0.0, instance.remaining - delta)
		var interval := instance.definition.tick_interval
		if interval > 0.0:
			instance.tick_accum += active
			while instance.tick_accum >= interval and _instances.has(instance):
				instance.tick_accum -= interval
				instance.definition.behavior.on_tick(instance)
		if _instances.has(instance) and instance.remaining <= 0.0:
			_remove_instance(instance, true)


func _remove_instance(instance: StatusInstance, natural: bool) -> void:
	if not _instances.has(instance):
		return
	_instances.erase(instance)
	if natural:
		instance.definition.behavior.on_expire(instance)
	else:
		instance.definition.behavior.on_remove(instance)
	_free_vfx(instance)
	changed.emit()


func _spawn_vfx(instance: StatusInstance) -> void:
	var definition := instance.definition
	if definition.vfx_scene == null:
		return
	var parent := _visuals
	if parent == null:
		parent = unit
	var vfx := definition.vfx_scene.instantiate()
	parent.add_child(vfx)
	if vfx is Node2D:
		var bar_y := unit.health_bar.position.y if unit.health_bar != null else -100.0
		vfx.position = Vector2(0.0, bar_y) + definition.vfx_offset
		if vfx.has_method("play"):
			vfx.play()
	instance.vfx = vfx as Node2D


func _free_vfx(instance: StatusInstance) -> void:
	var vfx := instance.vfx
	instance.vfx = null
	if vfx == null or not is_instance_valid(vfx):
		return
	if vfx.has_method("stop"):
		vfx.stop()
	vfx.queue_free()


func clear_all(emit_change := true) -> void:
	for raw_instance in _instances.duplicate():
		var instance: StatusInstance = raw_instance
		instance.definition.behavior.on_remove(instance)
		_free_vfx(instance)
	_instances.clear()
	if emit_change:
		changed.emit()


func has_status(status_id: StringName) -> bool:
	for instance in _instances:
		if instance.definition.id == status_id:
			return true
	return false


func remaining(status_id: StringName) -> float:
	for instance in _instances:
		if instance.definition.id == status_id:
			return instance.remaining
	return 0.0


func stacks(status_id: StringName) -> int:
	for instance in _instances:
		if instance.definition.id == status_id:
			return instance.stacks
	return 0


func power(status_id: StringName) -> float:
	for instance in _instances:
		if instance.definition.id == status_id:
			return instance.power
	return 0.0


func has_tag(tag: StringName) -> bool:
	for instance in _instances:
		if instance.definition.has_tag(tag):
			return true
	return false


func has_any_tag(tags: Array[StringName]) -> bool:
	for tag in tags:
		if has_tag(tag):
			return true
	return false


func can_move() -> bool:
	for instance in _instances:
		if instance.definition.behavior.blocks_move(instance):
			return false
	return true


func can_act() -> bool:
	for instance in _instances:
		if instance.definition.behavior.blocks_action(instance):
			return false
	return true


func can_use_skill() -> bool:
	for instance in _instances:
		if instance.definition.behavior.blocks_skill(instance):
			return false
	return true


func modify_stat(stat: StringName, value: float) -> float:
	var result := value
	for instance in _instances:
		result = instance.definition.behavior.modify_stat(instance, stat, result)
	return result


func get_vfx(status_id: StringName) -> Node2D:
	for instance in _instances:
		if instance.definition.id == status_id:
			return instance.vfx
	return null


func snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for instance in _instances:
		result.append({
			"id": instance.definition.id,
			"display_name": instance.definition.display_name,
			"icon": instance.definition.icon,
			"remaining": instance.remaining,
			"stacks": instance.stacks,
			"tags": instance.definition.tags,
		})
	return result
