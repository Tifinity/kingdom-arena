class_name HeroDragData
extends RefCounted

## 布阵界面的拖拽载荷：既可以从名册卡拖出英雄，也可以从已部署槽位拖出。
## 用对象而不是裸 Dictionary，避免 _drop_data 里靠字符串猜字段。

enum Kind { HERO, SLOT }

var kind: int = Kind.HERO
var unit_id: StringName
var source_team := -1
var source_slot := -1


static func from_hero(hero_id: StringName) -> HeroDragData:
	var payload := HeroDragData.new()
	payload.kind = Kind.HERO
	payload.unit_id = hero_id
	return payload


static func from_slot(team: int, slot: int, hero_id: StringName) -> HeroDragData:
	var payload := HeroDragData.new()
	payload.kind = Kind.SLOT
	payload.unit_id = hero_id
	payload.source_team = team
	payload.source_slot = slot
	return payload
