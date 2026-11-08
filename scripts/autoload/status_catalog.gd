extends Node

## 状态目录：启动时扫描 resources/status 下的 StatusDefinition 资源。
## 新增状态 = 新增一个 .tres，不需要修改 Unit 或 Controller。

const STATUS_DIR := "res://resources/status"

var _definitions: Array[StatusDefinition] = []
var _by_id: Dictionary = {}


func _ready() -> void:
	_load_definitions()


func _load_definitions() -> void:
	_definitions.clear()
	_by_id.clear()
	var dir := DirAccess.open(STATUS_DIR)
	if dir == null:
		push_error("无法打开状态目录: %s" % STATUS_DIR)
		return
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var resource: Resource = load(STATUS_DIR.path_join(file))
		if resource is StatusDefinition:
			_definitions.append(resource)
			_by_id[resource.id] = resource


func all() -> Array[StatusDefinition]:
	return _definitions


func count() -> int:
	return _definitions.size()


func get_definition(status_id: StringName) -> StatusDefinition:
	return _by_id.get(status_id)


func has_definition(status_id: StringName) -> bool:
	return _by_id.has(status_id)


## 兼容旧的 status_kind 数据：0 眩晕、1 减速、2 流血、3 燃烧。
func legacy_definition(status_kind: int) -> StatusDefinition:
	match status_kind:
		0:
			return get_definition(&"stun")
		1:
			return get_definition(&"slow")
		2:
			return get_definition(&"bleed")
		3:
			return get_definition(&"burn")
	return null


func definition_for_effect(effect: ActionEffectDefinition) -> StatusDefinition:
	if effect == null:
		return null
	if not effect.status_id.is_empty():
		return get_definition(effect.status_id)
	return legacy_definition(effect.status_kind)
