class_name BattleReplayConfig
extends RefCounted

## 对阵输入。槽位和随机种子独立于当前窗口及布阵页的编辑状态。
const SCHEMA := 1
const TICKS_PER_SECOND := 60
const MAX_TICKS := GameState.BATTLE_TIME_LIMIT_SECONDS * TICKS_PER_SECOND
const SOURCE_DIRS := ["assets", "resources", "scenes", "scripts", "shaders"]
const OVERRIDE_FIELDS := [
	"max_hp", "attack_damage", "attack_speed", "attack_range", "armor",
	"move_speed", "max_mana", "starting_mana", "mana_regen",
]

const MODE_NAMES := ["elimination", "siege"]

var mode := GameState.BattleMode.ELIMINATION
var seed: int
var lineups: Array
var presets: Array
var positions: Array = []
var revision: String
var engine_version: String
var stat_overrides: Dictionary = {}
var _definitions: Dictionary = {}

static var _project_revision := ""


static func from_setup() -> BattleReplayConfig:
	var config := BattleReplayConfig.new()
	config.seed = randi()
	config.mode = GameState.battle_mode
	config.lineups = GameState.lineups.duplicate(true)
	config.presets = [GameState.selected_team_preset(0), GameState.selected_team_preset(1)]
	for team in 2:
		var slots: Array = []
		for slot in GameState.TEAM_SIZE:
			var point := GameState.deployment_position(team, slot, Vector2.INF)
			slots.append([point.x, point.y] if point.is_finite() else null)
		config.positions.append(slots)
	config.revision = project_revision()
	config.engine_version = _engine_build()
	for definition in UnitCatalog.all():
		var stats := UnitCatalog.get_stat_override(definition.unit_id)
		if not stats.is_empty():
			config.stat_overrides[String(definition.unit_id)] = stats.duplicate()
	return config


func to_dict() -> Dictionary:
	var data := {
		"schema": SCHEMA,
		"project_revision": revision,
		"godot_version": engine_version,
		"physics_ticks_per_second": TICKS_PER_SECOND,
		"seed": seed,
		"mode": MODE_NAMES[mode],
		"lineups": lineups,
		"presets": presets,
		"stat_overrides": stat_overrides,
	}
	if not positions.is_empty():
		data["positions"] = positions
	return data


func position_for_slot(team: int, slot: int, default_position: Vector2) -> Vector2:
	var point: Variant = null if positions.is_empty() else positions[team][slot]
	return default_position if point == null else Vector2(point[0], point[1])


func unit_definition(unit_id: StringName) -> UnitDefinition:
	if not _definitions.has(unit_id):
		var definition := UnitCatalog.get_source_definition(unit_id)
		if definition == null:
			return null
		var stats: Dictionary = stat_overrides.get(String(unit_id), {})
		if not stats.is_empty():
			definition.apply_stat_override(stats)
		_definitions[unit_id] = definition
	return _definitions[unit_id]


static func read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "无法打开配置 %s（%s）" % [path, error_string(FileAccess.get_open_error())]}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {"error": "配置 JSON 第 %d 行：%s" % [json.get_error_line(), json.get_error_message()]}
	if not json.data is Dictionary:
		return {"error": "配置必须是 JSON 对象"}
	var data: Dictionary = json.data
	if not _whole_number(data.get("schema"), SCHEMA, SCHEMA):
		return {"error": "不支持的对阵配置版本"}
	if not _whole_number(data.get("physics_ticks_per_second"), TICKS_PER_SECOND, TICKS_PER_SECOND):
		return {"error": "对阵物理频率必须为 %d Hz" % TICKS_PER_SECOND}
	if not _whole_number(data.get("seed"), 0, 0xffffffff):
		return {"error": "随机种子必须为 0 至 4294967295 的整数"}
	var mode_index := MODE_NAMES.find(data.get("mode", MODE_NAMES[GameState.BattleMode.ELIMINATION]))
	if mode_index == -1:
		return {"error": "不支持的战斗模式"}
	var roster_error := _validate_roster(data.get("lineups"), data.get("presets"))
	if not roster_error.is_empty():
		return {"error": roster_error}
	var positions_error := _validate_positions(data.get("positions", []), data["lineups"])
	if not positions_error.is_empty():
		return {"error": positions_error}
	var overrides_error := _validate_overrides(data.get("stat_overrides"))
	if not overrides_error.is_empty():
		return {"error": overrides_error}
	var current_revision := project_revision()
	if current_revision.is_empty() or data.get("project_revision") != current_revision:
		return {"error": "项目版本不匹配。配置 %s，当前 %s" % [data.get("project_revision"), current_revision]}
	var current_engine := _engine_build()
	if data.get("godot_version") != current_engine:
		return {"error": "Godot 版本不匹配。配置 %s，当前 %s" % [data.get("godot_version"), current_engine]}
	var config := BattleReplayConfig.new()
	config.seed = int(data["seed"])
	config.mode = mode_index as GameState.BattleMode
	config.lineups = data["lineups"]
	config.presets = [int(data["presets"][0]), int(data["presets"][1])]
	config.positions = data.get("positions", [])
	config.revision = current_revision
	config.engine_version = current_engine
	config.stat_overrides = data["stat_overrides"]
	return {"config": config}


func save(path: String) -> Error:
	if revision.is_empty() or not _validate_roster(lineups, presets).is_empty() \
			or not _validate_positions(positions, lineups).is_empty() or not _validate_overrides(stat_overrides).is_empty():
		return ERR_INVALID_DATA
	return write_json(path, to_dict())


static func write_json(path: String, data: Dictionary) -> Error:
	var destination := ProjectSettings.globalize_path(path)
	var temporary := "%s.%d.%d.tmp" % [destination, OS.get_process_id(), Time.get_ticks_usec()]
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var written := file.store_string(JSON.stringify(data, "\t", true, true) + "\n")
	file.close()
	var error := DirAccess.rename_absolute(temporary, destination) if written else ERR_FILE_CANT_WRITE
	if error != OK:
		DirAccess.remove_absolute(temporary)
	return error


static func _whole_number(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and value >= minimum and value <= maximum and value == floor(value)


static func _engine_build() -> String:
	var version := Engine.get_version_info()
	return "%s (%s)" % [version["string"], version["hash"]]


static func _validate_roster(teams: Variant, team_presets: Variant) -> String:
	if not teams is Array or teams.size() != 2 or not team_presets is Array or team_presets.size() != 2:
		return "配置必须包含两支队伍和对应的预设编号"
	for team: int in range(2):
		if not _whole_number(team_presets[team], 0, GameState.TEAM_PRESETS.size() - 1):
			return "第 %d 队的预设编号无效" % (team + 1)
		var slots: Variant = teams[team]
		if not slots is Array or slots.size() != GameState.TEAM_SIZE:
			return "第 %d 队必须有 %d 个槽位" % [team + 1, GameState.TEAM_SIZE]
		var populated := false
		for unit_id: Variant in slots:
			if unit_id == null:
				continue
			if not (unit_id is String or unit_id is StringName) or not UnitCatalog.has_definition(StringName(unit_id)):
				return "第 %d 队包含未知英雄 %s" % [team + 1, unit_id]
			populated = true
		if not populated:
			return "第 %d 队至少需要 1 名英雄" % (team + 1)
	return ""


static func _validate_positions(teams: Variant, lineups_by_team: Array) -> String:
	if not teams is Array or teams.size() not in [0, 2]:
		return "站位必须为空或包含两支队伍"
	for team in teams.size():
		var slots: Variant = teams[team]
		if not slots is Array or slots.size() != GameState.TEAM_SIZE:
			return "第 %d 队的站位槽位数量无效" % (team + 1)
		for slot in slots.size():
			var point: Variant = slots[slot]
			if point == null:
				continue
			if lineups_by_team[team][slot] == null or not point is Array or point.size() != 2:
				return "第 %d 队第 %d 位的站位无效" % [team + 1, slot + 1]
			for coordinate: Variant in point:
				if not (coordinate is int or coordinate is float) or not is_finite(coordinate):
					return "站位坐标必须是有限数字"
	return ""


static func _validate_overrides(overrides: Variant) -> String:
	if not overrides is Dictionary:
		return "属性覆盖必须是 JSON 对象"
	for unit_id: String in overrides:
		var stats: Variant = overrides[unit_id]
		if not UnitCatalog.has_definition(StringName(unit_id)) or not stats is Dictionary:
			return "英雄 %s 的属性覆盖无效" % unit_id
		for field: String in stats:
			var value: Variant = stats[field]
			if not OVERRIDE_FIELDS.has(field) or not (value is int or value is float) or not is_finite(value):
				return "英雄 %s 的属性 %s 无效" % [unit_id, field]
	return ""


## 内容指纹包含尚未提交的资源和脚本改动，且不依赖本机 Git 或 Godot 导入缓存。
static func project_revision() -> String:
	if not _project_revision.is_empty():
		return _project_revision
	var paths: PackedStringArray = ["res://project.godot", "res://tools/replay_battle.gd", "res://tools/replay_battle.tscn"]
	for directory: String in SOURCE_DIRS:
		_append_source_paths("res://" + directory, paths)
	paths.sort()
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	for path: String in paths:
		var digest := FileAccess.get_sha256(path)
		if digest.is_empty():
			return ""
		context.update(("%s:%s\n" % [path, digest]).to_utf8_buffer())
	_project_revision = context.finish().hex_encode()
	return _project_revision


static func _append_source_paths(directory: String, paths: PackedStringArray) -> void:
	for file: String in DirAccess.get_files_at(directory):
		# 对阵和结果 JSON、导入缓存均不影响模拟版本。
		if not file.begins_with(".") and file.get_extension() not in ["import", "tmp", "json"]:
			paths.append(directory.path_join(file))
	for child: String in DirAccess.get_directories_at(directory):
		if not child.begins_with("."):
			_append_source_paths(directory.path_join(child), paths)
