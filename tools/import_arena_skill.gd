extends Node

const ARROW_RAIN_ID := "archer_arrow_rain"
const ARROW_RAIN_PATH := "res://resources/actions/archer_arrow_rain.tres"
const GREATSWORD_PASSIVE := "greatsword_skeleton_decapitate"
const GREATSWORD_SHAPES := {
	"greatsword_skeleton_cleave": ["cone", ActionEffectDefinition.Shape.CONE],
	"greatsword_skeleton_heavy_slash": ["single", ActionEffectDefinition.Shape.SINGLE],
	"greatsword_skeleton_pierce": ["rect", ActionEffectDefinition.Shape.RECT],
}

const UNIT_SLOTS := {
	"skeleton_archer_volley": [["projectile", "projectile", "projectile"], [6, 9, 12]],
	"slime_acid": [["damage", "slow", "poison"], [8, 8, 8], "aim_at_enemy", true],
	"priest_holy_bolt": [["intercepting_projectile"], [3]],
	"priest_blessing": [["heal"], [2], "lowest_hp_ally"],
	"priest_sanctuary": [["heal"], [2], "lowest_hp_ally", true],
	"wizard_fireball": [["projectile", "burn"], [6, 6]],
	"wizard_freeze": [["projectile", "stun"], [5, 5]],
}
const GRACE_ID := "priest_grace"


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
	var error := _import_skill(parser.data)
	if not error.is_empty():
		_fail(error)
		return
	print("已导入 %s" % parser.data.skillId)
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
	var skill_id: Variant = skill.get("skillId")
	if skill_id is not String or (skill_id != ARROW_RAIN_ID and skill_id != GREATSWORD_PASSIVE \
			and skill_id != GRACE_ID and not GREATSWORD_SHAPES.has(skill_id) and not UNIT_SLOTS.has(skill_id)):
		return "未找到 skillId 对应的技能槽：%s" % str(skill_id)
	var skill_name: Variant = skill.get("name")
	if skill_name is not String or skill_name.strip_edges().is_empty() or skill_name.length() > 40:
		return "name 必须是 1 至 40 字符的技能名称。"
	if skill_id == GREATSWORD_PASSIVE:
		return _validate_greatsword_passive(skill)
	if skill_id == GRACE_ID:
		return _validate_passive(skill, "heal_below_hp")
	if not _has_fields(skill, ["schemaVersion", "skillId", "name", "cast", "targeting", "effects"]):
		return "技能文件包含缺失或未知的字段。"
	var cast: Variant = skill.cast
	if not _has_fields(cast, ["cooldownSeconds", "manaCost", "rangePx"]):
		return "cast 需要 cooldownSeconds、manaCost 和 rangePx。"
	if not _number_in(cast.cooldownSeconds, 0, 300) or not _number_in(cast.manaCost, 0, 1000) \
			or not _number_in(cast.rangePx, 1, 2000):
		return "cast 数值超出支持范围：冷却 0 至 300 秒、蓝耗 0 至 1000、射程 1 至 2000 像素。"
	if UNIT_SLOTS.has(skill_id):
		return _validate_unit_action(skill, UNIT_SLOTS[skill_id])
	if skill_id != ARROW_RAIN_ID:
		return _validate_greatsword_action(skill)
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


func _validate_greatsword_passive(skill: Dictionary) -> String:
	return _validate_passive(skill, "damage_vs_high_hp")


func _validate_passive(skill: Dictionary, kind: String) -> String:
	if not _has_fields(skill, ["schemaVersion", "skillId", "name", "passive"]):
		return "被动技能需要 passive 配置。"
	var bonus: Variant = skill.passive
	if not _has_fields(bonus, ["kind", "thresholdPercent", "bonusPercent"]) \
			or bonus.kind != kind or not _number_in(bonus.thresholdPercent, 1, 100) \
			or not _number_in(bonus.bonusPercent, 0, 300):
		return "被动需要匹配的类型、生命阈值 1 至 100% 及增幅 0 至 300%。"
	return ""


func _validate_greatsword_action(skill: Dictionary) -> String:
	if not _has_fields(skill.targeting, ["kind"]) or skill.targeting.kind != "aim_at_enemy":
		return "巨剑骷髅的主动技能需要朝敌人释放。"
	if skill.cast.manaCost > 100:
		return "巨剑骷髅的蓝耗不能超过 100。"
	var effects: Variant = skill.effects
	if effects is not Array or effects.size() != 1:
		return "巨剑骷髅的主动技能需要一个伤害效果。"
	var effect: Variant = effects[0]
	var area: String = GREATSWORD_SHAPES[skill.skillId][0]
	var fields: Array[String] = ["kind", "trigger", "area", "attackDamageMultiplier"]
	if area == "cone":
		fields.append("halfAngleDegrees")
	elif area == "rect":
		fields.append("widthPx")
	if not _has_fields(effect, fields) or effect.kind != "damage" or effect.trigger != "impact" \
			or effect.area != area or not _number_in(effect.attackDamageMultiplier, 0, 3):
		return "伤害效果需要与技能槽的范围类型一致，倍率须在 0 至 3 AD 之间。"
	if area == "cone" and (skill.cast.rangePx > 1500 or not _number_in(effect.halfAngleDegrees, 7.5, 110)):
		return "扇形范围需要 1 至 1500 像素射程及 7.5 至 110 度半角。"
	if area == "rect" and not _number_in(effect.widthPx, 1, 400):
		return "直线范围需要 1 至 400 像素全宽。"
	return ""


func _validate_unit_action(skill: Dictionary, slot: Array) -> String:
	var target_kind: String = slot[2] if slot.size() >= 3 else "aim_at_enemy"
	var has_radius := slot.size() == 4
	var target_fields: Array[String] = ["kind"]
	if has_radius:
		target_fields.append("radiusPx")
	if skill.cast.manaCost > 100 or not _has_fields(skill.targeting, target_fields) \
			or skill.targeting.kind != target_kind \
			or (has_radius and not _number_in(skill.targeting.radiusPx, 40, 600)):
		return "蓝耗或选目标规则与技能槽不匹配。"
	if skill.effects is not Array or skill.effects.size() != slot[0].size():
		return "效果数量与技能槽不匹配。"
	for index in slot[0].size():
		var hit: Variant = skill.effects[index]
		var kind: String = slot[0][index]
		var fields: Array[String] = ["frame", "kind"]
		var limits := {}
		match kind:
			"intercepting_projectile":
				limits = {"speedPxPerSecond": [100, 4000], "widthPx": [20, 300], "baseDamage": [0, 300],
					"attackDamageMultiplier": [0, 6], "durationSeconds": [0.1, 6], "slowPercent": [0, 99]}
				if skill.name != "圣光弹" or skill.cast.manaCost != 0:
					return "牧师技能槽使用「圣光弹」名称与零蓝耗。"
			"projectile", "damage", "heal":
				limits["attackDamageMultiplier"] = [0, 3]
				if kind == "heal":
					limits["baseHeal"] = [0, 3000]
			"slow", "stun", "poison", "burn":
				limits["durationSeconds"] = [0.1, 6 if kind in ["slow", "stun"] else 20]
				if kind in ["poison", "burn"]:
					limits["damagePerSecondRatio"] = [0.001, 1] if kind == "poison" else [0, 3]
				if kind == "slow":
					limits["slowPercent"] = [0, 99]
		for field: String in limits:
			fields.append(field)
		if not _has_fields(hit, fields) or hit.kind != kind or not _number_in(hit.frame, slot[1][index], slot[1][index]):
			return "第 %d 项效果的类型或动画帧与技能槽不匹配。" % (index + 1)
		for field: String in limits:
			if not _number_in(hit[field], limits[field][0], limits[field][1]):
				return "第 %d 项效果的 %s 超出支持范围。" % [index + 1, field]
	return ""


func _import_unit_action(skill: Dictionary) -> String:
	var path := "res://resources/actions/%s.tres" % skill.skillId
	var action := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as CombatActionDefinition
	var friendly: bool = skill.targeting.kind == "lowest_hp_ally"
	var expected_mode := CombatActionDefinition.TargetMode.ALLY if friendly else CombatActionDefinition.TargetMode.ENEMY
	if action == null or action.action_id != skill.skillId or action.target_mode != expected_mode \
			or (friendly and (action.targeting == null or action.targeting.selection != ActionTargetingDefinition.Selection.LOWEST_HP_ALLY)):
		return "当前动作与选目标规则不匹配。"
	var kinds := {"projectile": ActionEffectDefinition.Kind.PROJECTILE, "damage": ActionEffectDefinition.Kind.DAMAGE,
		"intercepting_projectile": ActionEffectDefinition.Kind.PROJECTILE,
		"heal": ActionEffectDefinition.Kind.HEAL, "slow": ActionEffectDefinition.Kind.STATUS, "poison": ActionEffectDefinition.Kind.STATUS}
	var radius: float = skill.targeting.get("radiusPx", 0.0)
	var expected_shape := ActionEffectDefinition.Shape.CIRCLE if radius > 0 else ActionEffectDefinition.Shape.SINGLE
	var next_effect := 0
	var effect: ActionEffectDefinition
	action.display_name = skill.name
	action.cooldown = skill.cast.cooldownSeconds
	action.mana_cost = skill.cast.manaCost
	action.action_range = skill.cast.rangePx
	for hit: Dictionary in skill.effects:
		if kinds.has(hit.kind):
			if next_effect >= action.effects.size():
				return "动作缺少第 %d 个效果资源。" % (next_effect + 1)
			effect = action.effects[next_effect]
			next_effect += 1
			if effect == null or effect.kind != kinds[hit.kind]:
				return "动作的第 %d 个效果资源类型不匹配。" % next_effect
			effect.trigger_frame = int(hit.frame)
			effect.shape = expected_shape
			effect.radius = radius
		match hit.kind:
			"intercepting_projectile":
				effect.base_damage = hit.baseDamage
				effect.damage_ratio = hit.attackDamageMultiplier
				effect.projectile_speed_override = hit.speedPxPerSecond
				effect.projectile_collision_width = hit.widthPx
				effect.status_kind = ActionEffectDefinition.StatusKind.SLOW
				effect.status_duration = hit.durationSeconds
				effect.status_power = 1.0 - hit.slowPercent / 100.0
			"damage", "projectile":
				effect.damage_ratio = hit.attackDamageMultiplier
			"heal":
				effect.heal_amount = hit.baseHeal
				effect.heal_ratio = hit.attackDamageMultiplier
			"slow":
				effect.status_kind = ActionEffectDefinition.StatusKind.SLOW
				effect.status_duration = hit.durationSeconds
				effect.status_power = 1.0 - hit.slowPercent / 100.0
				effect.requires_action_hit = true
			"poison":
				effect.status_id = &"poison"
				effect.status_duration = hit.durationSeconds
				effect.status_power = hit.damagePerSecondRatio
				effect.requires_action_hit = true
			"burn":
				effect.burn_duration = hit.durationSeconds
				effect.burn_dps_ratio = hit.damagePerSecondRatio
			"stun":
				effect.status_kind = ActionEffectDefinition.StatusKind.STUN
				effect.status_duration = hit.durationSeconds
	if next_effect != action.effects.size():
		return "动作包含未绑定的效果资源。"
	action.description = _unit_action_description(skill)
	return _save_resource(action, path)


func _unit_action_description(skill: Dictionary) -> String:
	match skill.skillId:
		"skeleton_archer_volley":
			var effects: Array = skill.effects
			if effects.all(func(hit: Dictionary) -> bool: return hit.attackDamageMultiplier == effects[0].attackDamageMultiplier):
				return "锁定同一目标连射三箭，每箭造成 {damage_0} 单体伤害。"
			return "锁定同一目标连射三箭，依次造成 {damage_0}、{damage_1}、{damage_2} 单体伤害。"
		"slime_acid":
			return "向目标喷出酸液，造成 {damage_0} 范围伤害。命中附加减速与中毒。"
		"priest_holy_bolt":
			var hit: Dictionary = skill.effects[0]
			return "沿瞄准方向发射圣光弹，命中首名敌人时停止，造成 {damage_0} 单体伤害并减速 %s%%，持续 %s 秒。" % [
				str(hit.slowPercent), str(hit.durationSeconds)]
		"priest_blessing", "priest_sanctuary":
			var hit: Dictionary = skill.effects[0]
			var area := "以生命比例最低的受伤友军为中心，范围治疗" if skill.targeting.has("radiusPx") \
				else "治疗生命比例最低的受伤友军"
			return "%s %s + %s AD。" % [area, str(hit.baseHeal), str(hit.attackDamageMultiplier)]
		"wizard_fireball":
			return "发射火球，命中造成 {damage_0} 单体伤害，并燃烧 %s 秒。" % str(skill.effects[1].durationSeconds)
		"wizard_freeze":
			return "发射冰封弹，命中造成 {damage_0} 单体伤害并眩晕 %s 秒。" % str(skill.effects[1].durationSeconds)
	return ""


func _import_skill(skill: Dictionary) -> String:
	var skill_id: String = skill.skillId
	if skill_id == ARROW_RAIN_ID:
		return _import_arrow_rain(skill)
	if UNIT_SLOTS.has(skill_id):
		return _import_unit_action(skill)
	if skill_id == GRACE_ID:
		var path := "res://resources/passives/priest_grace.tres"
		var passive := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PassiveDefinition
		if passive == null:
			return "当前项目中缺少恩泽资源。"
		passive.display_name = skill.name
		passive.heal_below_hp_ratio = skill.passive.thresholdPercent / 100.0
		passive.heal_bonus_ratio = skill.passive.bonusPercent / 100.0
		passive.description = "治疗生命低于 %s%% 的友军时，治疗量提高 %s%%。" % [
			str(skill.passive.thresholdPercent), str(skill.passive.bonusPercent)]
		return _save_resource(passive, path)
	if skill_id == GREATSWORD_PASSIVE:
		var path := "res://resources/passives/%s.tres" % skill_id
		var passive := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PassiveDefinition
		if passive == null:
			return "当前项目中缺少斩首资源。"
		var threshold: float = skill.passive.thresholdPercent / 100.0
		var bonus: float = skill.passive.bonusPercent / 100.0
		if passive.display_name == skill.name and is_equal_approx(passive.bonus_damage_target_above_hp_ratio, threshold) \
				and is_equal_approx(passive.bonus_damage_above_hp_ratio, bonus):
			return ""
		passive.display_name = skill.name
		passive.bonus_damage_target_above_hp_ratio = threshold
		passive.bonus_damage_above_hp_ratio = bonus
		return _save_resource(passive, path)

	var path := "res://resources/actions/%s.tres" % skill_id
	var action := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as CombatActionDefinition
	if action == null or action.action_id != skill_id or action.category != CombatActionDefinition.Category.SKILL \
			or action.target_mode != CombatActionDefinition.TargetMode.ENEMY:
		return "当前项目中的主动技能资源与导入绑定不匹配。"
	var damage_effect: ActionEffectDefinition
	for effect in action.effects:
		if effect.kind == ActionEffectDefinition.Kind.DAMAGE:
			if damage_effect != null or effect.shape != GREATSWORD_SHAPES[skill_id][1]:
				return "主动技能资源的伤害效果与导入绑定不匹配。"
			damage_effect = effect
	if damage_effect == null:
		return "主动技能资源缺少伤害效果。"

	var hit: Dictionary = skill.effects[0]
	var range_px: float = skill.cast.rangePx
	var geometry_unchanged := true
	match damage_effect.shape:
		ActionEffectDefinition.Shape.CONE:
			geometry_unchanged = damage_effect.radius == range_px and damage_effect.half_angle == hit.halfAngleDegrees
			damage_effect.radius = range_px
			damage_effect.half_angle = hit.halfAngleDegrees
		ActionEffectDefinition.Shape.RECT:
			geometry_unchanged = damage_effect.length == range_px and damage_effect.width == hit.widthPx
			damage_effect.length = range_px
			damage_effect.width = hit.widthPx
	if geometry_unchanged and action.display_name == skill.name and action.action_range == range_px \
			and action.cooldown == skill.cast.cooldownSeconds and action.mana_cost == skill.cast.manaCost \
			and damage_effect.damage_ratio == hit.attackDamageMultiplier:
		return ""
	action.display_name = skill.name
	action.action_range = range_px
	action.cooldown = skill.cast.cooldownSeconds
	action.mana_cost = skill.cast.manaCost
	damage_effect.damage_ratio = hit.attackDamageMultiplier
	return _save_resource(action, path)


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

	return _save_resource(action, ARROW_RAIN_PATH)


func _save_resource(resource: Resource, path: String) -> String:
	var temporary := path.get_base_dir().path_join(".arena_skill_%s.tres" % OS.get_process_id())
	var save_error := ResourceSaver.save(resource, temporary)
	if save_error == OK:
		save_error = DirAccess.rename_absolute(temporary, path)
	if save_error != OK:
		if FileAccess.file_exists(temporary):
			DirAccess.remove_absolute(temporary)
		return "无法写入技能资源：%s" % error_string(save_error)
	return ""
