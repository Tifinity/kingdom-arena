extends Node

const ARROW_RAIN_ID := "archer_arrow_rain"
const ARROW_RAIN_PATH := "res://resources/actions/archer_arrow_rain.tres"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		_fail("用法：godot --headless --path . res://tools/import_arena_skill.tscn -- <技能文件>")
		return
	var file := FileAccess.open(args[0], FileAccess.READ)
	if file == null:
		_fail("无法读取 %s：%s" % [args[0], error_string(FileAccess.get_open_error())])
		return
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		_fail("JSON 第 %d 行：%s" % [parser.get_error_line(), parser.get_error_message()])
		return
	var validation_error := _validate(parser.data)
	if not validation_error.is_empty():
		_fail(validation_error)
		return
	var error := _import_arrow_rain(parser.data)
	if not error.is_empty():
		_fail(error)
		return
	print("已导入弓箭手箭雨：%s" % ARROW_RAIN_PATH)
	get_tree().quit()


func _fail(message: String) -> void:
	printerr("技能导入失败：", message)
	get_tree().quit(1)


func _has_fields(value: Variant, fields: Array[String]) -> bool:
	if value is not Dictionary or value.size() != fields.size():
		return false
	for field in fields:
		if not value.has(field):
			return false
	return true


func _number_in(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(value) and value >= minimum and value <= maximum


func _validate(skill: Variant) -> String:
	if skill is not Dictionary or not _number_in(skill.get("schemaVersion"), 1, 1):
		return "需要 schemaVersion 为 1 的竞技场单技能 JSON。"
	if skill.get("skillId") != ARROW_RAIN_ID:
		return "未找到 skillId 对应的技能槽：%s" % str(skill.get("skillId"))
	if not _has_fields(skill, ["schemaVersion", "skillId", "name", "cast", "targeting", "effects"]):
		return "技能文件包含缺失或未知的字段。"
	var skill_name: Variant = skill.name
	if skill_name is not String or skill_name.strip_edges().is_empty() or skill_name.length() > 40:
		return "name 必须是 1 至 40 字符的技能名称。"
	var cast: Variant = skill.cast
	if not _has_fields(cast, ["cooldownSeconds", "manaCost", "rangePx"]):
		return "cast 需要 cooldownSeconds、manaCost 和 rangePx。"
	if not _number_in(cast.cooldownSeconds, 0, 300) or not _number_in(cast.manaCost, 0, 1000) \
			or not _number_in(cast.rangePx, 1, 2000):
		return "cast 数值超出支持范围：冷却 0 至 300 秒、蓝耗 0 至 1000、射程 1 至 2000 像素。"
	var targeting: Variant = skill.targeting
	if not _has_fields(targeting, ["kind", "radiusPx"]) or targeting.kind != "densest_enemy_cluster" \
			or not _number_in(targeting.radiusPx, 40, 600):
		return "targeting 需要最密集敌群选点和 40 至 600 像素的半径。"
	var effects: Variant = skill.effects
	if effects is not Array or effects.size() != 1:
		return "箭雨技能槽需要恰好一个伤害效果。"
	var effect: Variant = effects[0]
	if not _has_fields(effect, ["trigger", "kind", "area", "radiusPx", "attackDamageMultiplier"]) \
			or effect.trigger != "impact" or effect.kind != "damage" or effect.area != "target_circle":
		return "箭雨技能槽需要在 impact 结算的目标圆形伤害。"
	if not _number_in(effect.radiusPx, 40, 600) or not is_equal_approx(effect.radiusPx, targeting.radiusPx):
		return "伤害半径必须与选点半径相同。"
	if not _number_in(effect.attackDamageMultiplier, 0, 3):
		return "伤害倍率须在 0 至 3 AD 之间。"
	return ""


func _import_arrow_rain(skill: Dictionary) -> String:
	var action := ResourceLoader.load(ARROW_RAIN_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as CombatActionDefinition
	if action == null or action.action_id != ARROW_RAIN_ID \
			or action.target_mode != CombatActionDefinition.TargetMode.POINT \
			or not action.select_densest_cluster() or action.effects.size() != 2:
		return "当前项目中的箭雨资源与导入绑定不匹配。"
	var visual := action.effects[0]
	var damage := action.effects[1]
	if visual == null or damage == null or visual.kind != ActionEffectDefinition.Kind.VISUAL \
			or visual.effect_scene == null or damage.kind != ActionEffectDefinition.Kind.DAMAGE \
			or damage.shape != ActionEffectDefinition.Shape.CIRCLE or damage.center_on_self:
		return "箭雨绑定需要一个特效和一个以落点为中心的圆形伤害。"
	if action.display_name == skill.name and action.cooldown == skill.cast.cooldownSeconds \
			and action.mana_cost == skill.cast.manaCost and action.action_range == skill.cast.rangePx \
			and visual.radius == skill.targeting.radiusPx and damage.radius == skill.targeting.radiusPx \
			and damage.damage_ratio == skill.effects[0].attackDamageMultiplier:
		return ""
	action.display_name = skill.name
	action.cooldown = skill.cast.cooldownSeconds
	action.mana_cost = skill.cast.manaCost
	action.action_range = skill.cast.rangePx
	visual.radius = skill.targeting.radiusPx
	damage.radius = skill.targeting.radiusPx
	damage.damage_ratio = skill.effects[0].attackDamageMultiplier

	var temporary := ARROW_RAIN_PATH.get_base_dir().path_join(".arena_skill_%s.tres" % OS.get_process_id())
	var save_error := ResourceSaver.save(action, temporary)
	if save_error == OK:
		save_error = DirAccess.rename_absolute(temporary, ARROW_RAIN_PATH)
	if save_error != OK:
		if FileAccess.file_exists(temporary):
			DirAccess.remove_absolute(temporary)
		return "无法写入技能资源：%s" % error_string(save_error)
	return ""
