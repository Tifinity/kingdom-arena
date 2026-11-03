extends Node

## 英雄名册：启动时扫描 resources/units 下的 UnitDefinition 资源。
## 场景只依赖这个只读目录，新增英雄 = 新增一个 .tres，不改代码。

const UNIT_DIR := "res://resources/units"

var _units: Array[UnitDefinition] = []
var _by_id: Dictionary = {}


func _ready() -> void:
	_load_units()


func _load_units() -> void:
	_units.clear()
	_by_id.clear()
	var dir := DirAccess.open(UNIT_DIR)
	if dir == null:
		push_error("无法打开英雄目录: %s" % UNIT_DIR)
		return
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var resource: Resource = load(UNIT_DIR.path_join(file))
		if resource is UnitDefinition:
			_units.append(resource)
			_by_id[resource.unit_id] = resource
	_units.sort_custom(func(a: UnitDefinition, b: UnitDefinition) -> bool:
		return a.roster_order < b.roster_order
	)


func all() -> Array[UnitDefinition]:
	return _units


func get_definition(unit_id: StringName) -> UnitDefinition:
	return _by_id.get(unit_id)


func has_definition(unit_id: StringName) -> bool:
	return _by_id.has(unit_id)


func count() -> int:
	return _units.size()


func of_faction(faction: int) -> Array[UnitDefinition]:
	var result: Array[UnitDefinition] = []
	for unit in _units:
		if unit.faction == faction:
			result.append(unit)
	return result
