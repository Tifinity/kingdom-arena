extends Node

## 英雄名册：启动时扫描 resources/units 下的 UnitDefinition 资源。
## 场景只依赖这个只读目录，新增英雄 = 新增一个 .tres，不改代码。

const UNIT_DIR := "res://resources/units"
const OVERRIDES_PATH := "user://hero_stat_overrides.cfg"

var _units: Array[UnitDefinition] = []
var _by_id: Dictionary = {}
var _overrides := ConfigFile.new()
var _persist_overrides := true


func _ready() -> void:
	# 无界面测试使用资源原始值，避免本机 Hero Lab 的用户覆盖影响断言。
	_persist_overrides = DisplayServer.get_name() != "headless"
	if _persist_overrides:
		var err := _overrides.load(OVERRIDES_PATH)
		if err != OK and err != ERR_FILE_NOT_FOUND:
			push_warning("无法读取 Hero Lab 属性覆盖: %s" % error_string(err))
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
			var override: Dictionary = _overrides.get_value("units", String(resource.unit_id), {})
			if not override.is_empty():
				resource.apply_stat_override(override)
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


## Hero Lab 修改后写入用户覆盖文件，启动时自动叠加到 UnitDefinition。
func save_stat_override(unit_id: StringName, stats: Dictionary) -> Error:
	if not _persist_overrides:
		return ERR_UNAVAILABLE
	_overrides.set_value("units", String(unit_id), stats)
	var err := _overrides.save(OVERRIDES_PATH)
	if err != OK:
		push_warning("无法保存 Hero Lab 属性覆盖: %s" % error_string(err))
	return err


func get_stat_override(unit_id: StringName) -> Dictionary:
	return _overrides.get_value("units", String(unit_id), {})


func clear_stat_override(unit_id: StringName) -> void:
	_overrides.erase_section_key("units", String(unit_id))
	if _persist_overrides:
		_overrides.save(OVERRIDES_PATH)
