extends Node

## 跨场景的比赛配置：布阵界面写入，战斗场景读取。
## 每个队伍固定 5 个槽位，槽位顺序 = 战场站位；空槽用 null 表示。

const TEAM_SIZE := 5
const TEAM_NAMES := ["晨曦王庭", "暗影军团"]
const TEAM_SHORT_NAMES := ["蓝方", "红方"]
const TEAM_COLORS := [Color("#58a6ff"), Color("#ff6b7a")]
const TEAM_COLORS_DIM := [Color("#2b5f96"), Color("#8d3541")]

const DEFAULT_LINEUPS := [
	[&"knight_templar", &"armored_axeman", &"lancer", &"archer", &"wizard"],
	[&"armored_orc", &"orc", &"skeleton_archer", &"necromancer", &"werewolf"],
]

var lineups: Array = []
var last_result: Dictionary = {}


func _ready() -> void:
	reset_lineups()


func reset_lineups() -> void:
	lineups = [_empty_slots(), _empty_slots()]
	for team in 2:
		for slot in TEAM_SIZE:
			if slot < DEFAULT_LINEUPS[team].size():
				var unit_id: StringName = DEFAULT_LINEUPS[team][slot]
				if UnitCatalog.has_definition(unit_id):
					lineups[team][slot] = unit_id


func _empty_slots() -> Array:
	var slots: Array = []
	slots.resize(TEAM_SIZE)
	slots.fill(null)
	return slots


func get_lineup(team: int) -> Array:
	return lineups[team]


func get_slot(team: int, slot: int) -> Variant:
	if slot < 0 or slot >= TEAM_SIZE:
		return null
	return lineups[team][slot]


func set_slot(team: int, slot: int, unit_id: Variant) -> bool:
	if slot < 0 or slot >= TEAM_SIZE:
		return false
	if unit_id == null:
		lineups[team][slot] = null
		return true
	if not UnitCatalog.has_definition(StringName(unit_id)):
		return false
	lineups[team][slot] = StringName(unit_id)
	return true


func set_lineup(team: int, unit_ids: Array) -> void:
	lineups[team] = _empty_slots()
	for slot in mini(unit_ids.size(), TEAM_SIZE):
		var unit_id: Variant = unit_ids[slot]
		if unit_id != null and UnitCatalog.has_definition(StringName(unit_id)):
			lineups[team][slot] = StringName(unit_id)


func first_empty_slot(team: int) -> int:
	for slot in TEAM_SIZE:
		if lineups[team][slot] == null:
			return slot
	return -1


func add_unit(team: int, unit_id: StringName) -> int:
	var slot := first_empty_slot(team)
	if slot < 0 or not UnitCatalog.has_definition(unit_id):
		return -1
	lineups[team][slot] = unit_id
	return slot


func remove_slot(team: int, slot: int) -> void:
	if slot >= 0 and slot < TEAM_SIZE:
		lineups[team][slot] = null


func clear_lineup(team: int) -> void:
	lineups[team] = _empty_slots()


func unit_count(team: int) -> int:
	return lineups[team].filter(func(entry: Variant) -> bool: return entry != null).size()


func lineup_ready() -> bool:
	return unit_count(0) > 0 and unit_count(1) > 0


func lineup_power(team: int) -> int:
	var total := 0
	for unit_id in lineups[team]:
		if unit_id == null:
			continue
		var definition: UnitDefinition = UnitCatalog.get_definition(unit_id)
		if definition != null:
			total += definition.power_rating()
	return total


func team_name(team: int) -> String:
	return TEAM_NAMES[team]


func team_color(team: int) -> Color:
	return TEAM_COLORS[team]


func team_short_name(team: int) -> String:
	return TEAM_SHORT_NAMES[team]
