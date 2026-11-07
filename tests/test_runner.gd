extends Node

## 无界面冒烟测试：
## 1) 22 份英雄数据/动画完整；2) 布阵场景能实例化并生成卡牌；
## 3) 默认阵容可以完整打完一场战斗，且 FSM 真的经历了攻击/受击/死亡；
## 4) OODA 快照有观察、判断、决策、行动文本。

var failures := 0
var checks := 0


func _ready() -> void:
	await _run_all()
	if failures == 0:
		print("\n[TEST] ALL PASS (%d checks)" % checks)
	else:
		print("\n[TEST] FAILED: %d / %d checks" % [failures, checks])
	get_tree().quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("  PASS  %s" % message)
	else:
		failures += 1
		printerr("  FAIL  %s" % message)


func _run_all() -> void:
	await get_tree().process_frame
	await _test_catalog()
	await _test_setup_scene()
	await _test_hero_lab()
	await _test_flame_slash()
	await _test_smart_knight()
	await _test_wizard_and_elite_orc()
	await _test_lancer_charge()
	await _test_orc_rider_tank()
	await _test_werewolf_combo()
	await _test_armored_skeleton_basic_and_ultimate()
	await _test_axeman_skills()
	await _test_skill_effects()
	await _test_stun_effect()
	await _test_status_framework()
	await _test_basic_no_interrupt()
	await _test_necromancer()
	await _test_battle()
	await _test_extra_lineup()
	await _test_stat_editor()


func _test_catalog() -> void:
	print("\n[1] 英雄数据")
	_check(UnitCatalog.count() == 22, "名册包含 22 名英雄（实际 %d）" % UnitCatalog.count())
	var expected_factions := {
		UnitDefinition.Faction.HUMAN: [&"soldier", &"knight", &"knight_templar", &"armored_axeman", &"lancer", &"swordsman", &"archer", &"priest", &"wizard"],
		UnitDefinition.Faction.WILDERNESS: [&"orc", &"elite_orc", &"armored_orc", &"orc_rider", &"werebear", &"werewolf"],
		UnitDefinition.Faction.MONSTER: [&"skeleton", &"armored_skeleton", &"greatsword_skeleton", &"skeleton_archer", &"necromancer", &"bat", &"slime"],
	}
	for faction in expected_factions:
		var actual: Array[StringName] = []
		for definition in UnitCatalog.of_faction(faction):
			actual.append(definition.unit_id)
		actual.sort()
		var wanted: Array[StringName] = []
		for unit_id in expected_factions[faction]:
			wanted.append(unit_id)
		wanted.sort()
		_check(actual == wanted, "%s阵营成员与预期一致（%d 名）" % [UnitDefinition.FACTION_NAMES[faction], wanted.size()])
	var required := [&"idle", &"move", &"attack_01", &"hurt", &"death"]
	var missing_visual: Array[String] = []
	var missing_behavior: Array[String] = []
	var nonzero_starting_mana: Array[StringName] = []
	for definition in UnitCatalog.all():
		if not is_zero_approx(definition.starting_mana):
			nonzero_starting_mana.append(definition.unit_id)
		if definition.visual_scene == null:
			missing_visual.append(definition.unit_id)
		if (definition.behavior_profile == null or definition.behavior_profile.targeting == null
				or definition.behavior_profile.movement == null):
			missing_behavior.append(definition.unit_id)
	_check(missing_visual.is_empty(), "22 名英雄都有视觉子场景")
	_check(missing_behavior.is_empty(), "22 名英雄都有索敌/移动行为配置")
	_check(nonzero_starting_mana.is_empty(), "22 名英雄的入场蓝量配置均为 0")

	var missing_ultimate: Array[String] = []
	var bad_mana: Array[String] = []
	var missing_attack_use: Array[String] = []
	var effect_kinds := {}
	var summon_owners: Array[StringName] = []
	for definition in UnitCatalog.all():
		var has_ultimate := false
		var used_animations := {}
		for action in definition.actions:
			if action.mana_cost >= definition.max_mana - 0.001:
				has_ultimate = true
			elif action.mana_cost > 0.001:
				bad_mana.append("%s/%s" % [definition.unit_id, action.action_id])
			used_animations[action.animation] = true
			for effect in action.effects:
				effect_kinds[effect.kind] = true
				if effect.kind == ActionEffectDefinition.Kind.SUMMON and not summon_owners.has(definition.unit_id):
					summon_owners.append(definition.unit_id)
		if not has_ultimate:
			missing_ultimate.append(definition.unit_id)
		for animation in [&"attack_02", &"attack_03"]:
			if definition.sprite_frames != null and definition.sprite_frames.has_animation(animation) and not used_animations.has(animation):
				missing_attack_use.append("%s/%s" % [definition.unit_id, animation])
	_check(missing_ultimate.is_empty(), "每名英雄都有一个满蓝大招")
	_check(bad_mana.is_empty(), "普通技能只受 CD，不再消耗蓝量")
	_check(missing_attack_use.is_empty(), "所有现有 attack02/attack03 动画都被技能使用")
	_check(effect_kinds.has(ActionEffectDefinition.Kind.HEAL), "技能数据包含治疗效果")
	_check(effect_kinds.has(ActionEffectDefinition.Kind.SUMMON), "技能数据包含召唤效果")
	_check(effect_kinds.has(ActionEffectDefinition.Kind.SHIELD), "技能数据包含护盾效果")
	_check(summon_owners == [&"necromancer"], "只有死灵法师能召唤单位")
	_check(effect_kinds.has(ActionEffectDefinition.Kind.STATUS), "技能数据包含状态效果")
	_check(effect_kinds.has(ActionEffectDefinition.Kind.DISPLACE), "技能数据包含击退效果")

	var bad_aoe_range: Array[String] = []
	for definition in UnitCatalog.all():
		for action in definition.actions:
			var shape_reach := 0.0
			for effect in action.effects:
				if effect.kind != ActionEffectDefinition.Kind.DAMAGE:
					continue
				if effect.shape == ActionEffectDefinition.Shape.CONE:
					shape_reach = maxf(shape_reach, effect.radius)
				elif effect.shape == ActionEffectDefinition.Shape.RECT:
					shape_reach = maxf(shape_reach, effect.length)
			if shape_reach > 0.0 and not is_equal_approx(action.action_range, shape_reach):
				bad_aoe_range.append("%s/%s" % [definition.unit_id, action.action_id])
	_check(bad_aoe_range.is_empty(), "所有扇形/矩形技能的释放距离与实际伤害范围一致")

	var expected_ranged := {
		&"archer": 510.0, &"priest": 465.0, &"wizard": 540.0,
		&"skeleton_archer": 495.0, &"necromancer": 525.0,
	}
	var ranged_range_ok := true
	var ranged_basic_ok := true
	for unit_id in expected_ranged:
		var definition := UnitCatalog.get_definition(unit_id)
		if definition == null or not is_equal_approx(definition.attack_range, expected_ranged[unit_id]):
			ranged_range_ok = false
			continue
		var basic: CombatActionDefinition = null
		for action in definition.actions:
			if action.action_id == (&"%s_basic" % unit_id) or action.action_id == &"necromancer_ghostfire":
				basic = action
		if basic == null or not is_equal_approx(basic.action_range, expected_ranged[unit_id]):
			ranged_basic_ok = false
	_check(ranged_range_ok, "所有远程单位的射程为原来的 1.5 倍")
	_check(ranged_basic_ok, "所有远程单位的基础攻击距离同步为 1.5 倍")

	var knight_definition := UnitCatalog.get_definition(&"knight")
	var archer_definition := UnitCatalog.get_definition(&"archer")
	var assassin_definition := UnitCatalog.get_definition(&"werewolf")
	_check(knight_definition.behavior_profile.movement.preferred_range_ratio > 0.95,
		"坦克使用贴近型移动配置")
	_check(archer_definition.behavior_profile.movement.preferred_range_ratio < 0.90,
		"弓手使用远程保持距离配置")
	_check(assassin_definition.behavior_profile.targeting.backline_bonus > 0.20,
		"突袭英雄拥有后排索敌加成")
	var knight_visual: PackedScene = knight_definition.visual_scene
	if knight_visual != null:
		var visual_instance = knight_visual.instantiate()
		add_child(visual_instance)
		await get_tree().process_frame
		_check(visual_instance.has_node("Body") and visual_instance.has_node("HealthBar")
			and visual_instance.has_node("Shadow") and visual_instance.has_node("TeamRing")
			and visual_instance.has_node("SelectionRing") and visual_instance.has_node("Hurtbox/CollisionShape2D")
			and visual_instance.has_node("AttackBox/CollisionShape2D"),
			"视觉场景包含 Body/血条/影子/选中环/受击框/攻击框节点")
		var hurt_shape: Shape2D = visual_instance.get_node("Hurtbox/CollisionShape2D").shape
		var attack_shape: Shape2D = visual_instance.get_node("AttackBox/CollisionShape2D").shape
		_check(hurt_shape is CircleShape2D and attack_shape is CircleShape2D
			and hurt_shape.radius > 0.0 and attack_shape.radius > 0.0,
			"受击框/攻击框拥有可视的圆形范围")
		visual_instance.queue_free()
		await get_tree().process_frame

	for definition in UnitCatalog.all():
		var valid := true
		for animation in required:
			if definition.sprite_frames == null or not definition.sprite_frames.has_animation(animation):
				valid = false
		_check(valid, "%s: idle/move/attack_01/hurt/death 动画齐全" % definition.display_name)
		_check(definition.portrait != null and definition.max_hp > 0.0 and definition.character_height > 0.0,
			"%s: 头像与基础数据有效" % definition.display_name)


func _test_setup_scene() -> void:
	print("\n[2] 布阵场景")
	var scene: PackedScene = load("res://scenes/setup/setup_screen.tscn")
	_check(scene != null, "setup_screen.tscn 可加载")
	if scene == null:
		return
	var setup = scene.instantiate()
	add_child(setup)
	await get_tree().process_frame
	var grid: GridContainer = setup.get_node("Root/VBox/Content/Center/RosterScroll/RosterGrid")
	_check(grid.get_child_count() == 22, "名册生成 22 张卡牌（实际 %d）" % grid.get_child_count())
	var blue: LineupPanel = setup.get_node("Root/VBox/Content/BluePanel")
	var red: LineupPanel = setup.get_node("Root/VBox/Content/RedPanel")
	_check(blue.slots.size() == 5 and red.slots.size() == 5, "双方各有 5 个布阵槽位")
	_check(GameState.unit_count(0) == 5 and GameState.unit_count(1) == 5, "默认双方阵容各 5 人")
	_check(blue.power_label.text.begins_with("战力"), "布阵面板显示战力")

	var target_definition := UnitCatalog.get_definition(&"werebear")
	setup._select_definition(target_definition)
	_check(setup.detail_desc.text.contains("CD") and setup.detail_desc.text.contains(target_definition.actions[1].display_name),
		"英雄详情显示技能描述与冷却")
	var hero_payload := HeroDragData.from_hero(&"werebear")
	_check(blue.slots[0]._can_drop_data(Vector2.ZERO, hero_payload), "槽位可接收英雄拖拽")
	blue.slots[0]._drop_data(Vector2.ZERO, hero_payload)
	_check(GameState.get_slot(0, 0) == &"werebear", "拖拽英雄卡到槽位完成部署")
	blue.slots[0].remove_requested.emit(0, 0)
	_check(GameState.get_slot(0, 0) == null, "× / 右键移除槽位英雄")

	GameState.reset_lineups()
	setup._refresh_panels()
	var first_id: Variant = GameState.get_slot(0, 0)
	var second_id: Variant = GameState.get_slot(0, 1)
	var slot_payload := HeroDragData.from_slot(0, 0, StringName(first_id))
	blue.slots[1]._drop_data(Vector2.ZERO, slot_payload)
	_check(
		GameState.get_slot(0, 1) == first_id and GameState.get_slot(0, 0) == second_id,
		"拖动已部署英雄可交换槽位"
	)

	setup._set_filter(UnitDefinition.Faction.HUMAN)
	_check(setup.roster_count.text == "显示 9 / 22", "人类筛选显示 9 名英雄")
	setup._set_filter(UnitDefinition.Faction.WILDERNESS)
	_check(setup.roster_count.text == "显示 6 / 22", "荒野筛选显示 6 名英雄")
	setup._set_filter(UnitDefinition.Faction.MONSTER)
	_check(setup.roster_count.text == "显示 7 / 22", "怪物筛选显示 7 名英雄")
	GameState.reset_lineups()
	setup.queue_free()
	await get_tree().process_frame


func _test_hero_lab() -> void:
	print("\n[3] 英雄试炼场")
	var scene: PackedScene = load("res://scenes/debug/hero_lab.tscn")
	_check(scene != null, "hero_lab.tscn 可加载")
	if scene == null:
		return
	var lab = scene.instantiate()
	add_child(lab)
	await get_tree().process_frame
	_check(lab.hero_grid.get_child_count() == 22, "试炼场生成 22 张英雄卡（实际 %d）" % lab.hero_grid.get_child_count())
	_check(lab.preview_unit != null, "试炼场默认生成预览单位")
	_check(lab.animation_buttons.get_child_count() > 0, "动作预览按钮已生成")

	var wizard := UnitCatalog.get_definition(&"wizard")
	lab._select_definition(wizard)
	await get_tree().process_frame
	_check(lab.preview_unit.definition.unit_id == &"wizard", "切换到法师后预览单位同步更新")
	_check(lab.detail_name.text == "法师", "右侧详情同步更新")
	lab._play_animation(&"attack_01")
	_check(lab.current_anim.text.begins_with("普攻1"), "手动播放普攻动画并更新状态标签")
	_check(lab.preview_unit.current_animation() == &"attack_01", "预览单位实际切到 attack_01")
	var original_attack := wizard.attack_damage
	lab.stat_atk.value = 77.0
	await get_tree().process_frame
	_check(is_equal_approx(wizard.attack_damage, 77.0) and is_equal_approx(lab.preview_unit.attack_damage, 77.0),
		"在属性展示 SpinBox 上修改立即生效")
	lab.stat_atk.value = original_attack
	await get_tree().process_frame
	lab.queue_free()
	await get_tree().process_frame
	GameState.reset_lineups()


func _test_flame_slash() -> void:
	print("\n[4] 火焰斩击 AOE")
	var knight_definition := UnitCatalog.get_definition(&"knight")
	var skill: CombatActionDefinition = null
	var block: CombatActionDefinition = null
	for action in knight_definition.actions:
		if action.action_id == &"knight_flame_slash":
			skill = action
		elif action.action_id == &"knight_block":
			block = action
	_check(skill != null, "骑士拥有火焰斩击 Action")
	_check(block != null, "骑士拥有格挡 Action")
	if skill == null or block == null:
		return
	_check(skill.animation == &"attack_03", "火焰斩击使用 attack_03 火焰帧动画")
	_check(block.animation == &"block" and block.action_duration >= 1.0,
		"格挡使用 block 动画并持续 1 秒")
	_check(not block.effects.is_empty() and block.effects[0].kind == ActionEffectDefinition.Kind.GUARD
		and block.effects[0].duration >= 1.0, "格挡效果持续 1 秒")
	_check(not skill.effects.is_empty() and skill.effects[0].shape == ActionEffectDefinition.Shape.CONE,
		"火焰斩击配置为扇形 AOE")
	_check(skill.mana_cost > 0.0 and knight_definition.max_mana > 0.0,
		"火焰斩击有蓝耗，单位有蓝量属性")

	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"knight")
	GameState.set_slot(1, 0, &"soldier")
	GameState.set_slot(1, 1, &"archer")
	GameState.set_slot(1, 2, &"skeleton")

	var battle: Battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame

	var knight: Unit = null
	var enemies: Array[Unit] = []
	for unit in battle.units:
		if unit.team == 0:
			knight = unit
		else:
			enemies.append(unit)
	_check(knight != null and enemies.size() == 3, "AOE 测试生成骑士与 3 名敌人")
	if knight == null or enemies.size() < 3:
		battle.queue_free()
		await get_tree().process_frame
		return

	# 把敌人放到骑士前方扇形内/外，关闭敌人 AI，手动触发技能。
	knight.position = Vector2(700, 650)
	enemies[0].position = Vector2(820, 650)   # 扇形内
	enemies[1].position = Vector2(820, 700)   # 扇形内
	enemies[2].position = Vector2(600, 650)   # 身后，不应命中
	for enemy in enemies:
		enemy.brain.enabled = false
	var hp_before: Array[float] = [enemies[0].hp, enemies[1].hp, enemies[2].hp]
	# 先验证决策层：技能就绪且目标在范围内时，应选中火焰斩击而不是普攻。
	knight.mana = knight.max_mana
	knight.brain.enabled = true
	knight.brain.force_think()
	_check(knight.planned_action != null and knight.planned_action.action_id == &"knight_flame_slash",
		"决策层在火焰斩击可用时选择技能 Action")
	# 蓝量不足时不应继续选技能，应回退到普攻。
	knight.mana = 0.0
	knight.brain.force_think()
	_check(knight.planned_action == null or knight.planned_action.action_id != &"knight_flame_slash",
		"蓝量不足时决策层不会选择火焰斩击")
	knight.mana = knight.max_mana
	knight.brain.force_think()
	knight.brain.enabled = false
	knight.target = enemies[0]
	knight.planned_action = skill
	knight.state_machine.transition_to(&"action", true)
	_check(knight.state_machine.current_name == &"action", "骑士进入统一 Action 状态")

	await get_tree().create_timer(1.1).timeout
	_check(enemies[0].hp < hp_before[0] and enemies[1].hp < hp_before[1],
		"扇形内两名敌人同时受到火焰斩击伤害")
	_check(enemies[2].hp == hp_before[2], "身后敌人不受扇形 AOE 影响")
	_check(battle.skill_casts == 1 and knight.action_cooldown(skill) > 0.0,
		"一次技能只释放一次并进入冷却")
	_check(knight.mana < knight.max_mana, "释放火焰斩击消耗蓝量")
	var hud_snapshot := knight.ai_snapshot()
	_check(hud_snapshot.has("mana") and hud_snapshot.has("attack_range") and hud_snapshot.has("skill_range"),
		"调试快照包含蓝量与攻击范围")

	# AOE 选择距离应和扇形实际半径一致，并留出施法缓冲。
	knight.target = enemies[1]  # archer
	knight.position = Vector2(700, 650)
	enemies[1].position = knight.position + Vector2(180, 0)
	_check(not knight.is_target_in_action_range(skill, 4.0),
		"火焰斩击不会在扇形有效半径之外释放")
	enemies[1].position = knight.position + Vector2(160, 0)
	_check(knight.is_target_in_action_range(skill, 4.0),
		"火焰斩击在安全范围内可释放")
	var cleave: CombatActionDefinition = null
	for action in knight.actions:
		if action.action_id == &"knight_cleave":
			cleave = action
			break
	if cleave != null:
		enemies[1].position = knight.position + Vector2(112, 0)
		_check(not knight.is_target_in_action_range(cleave, 4.0),
			"回旋斩不会在扇形有效半径之外释放")
		enemies[1].position = knight.position + Vector2(95, 0)
		_check(knight.is_target_in_action_range(cleave, 4.0),
			"回旋斩在安全范围内可释放")

	# 低血量、火焰斩击与格挡都就绪时，防御紧迫度应让格挡胜出。
	knight.hp = knight.max_hp * 0.4
	knight.mana = knight.max_mana
	for key in knight.action_cooldowns.keys():
		knight.action_cooldowns[key] = 0.0
	knight.brain.enabled = true
	knight.brain.force_think()
	_check(knight.planned_action != null and knight.planned_action.action_id == &"knight_block",
		"低血量且多个动作可用时优先选择格挡")
	knight.brain.enabled = false
	knight.target = enemies[0]
	knight.planned_action = block
	knight.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(0.12).timeout
	_check(knight.guard_time > 0.5, "格挡 Action 进入无敌状态")
	var hp_guarded := knight.hp
	knight.take_damage(100.0, enemies[0])
	_check(is_equal_approx(knight.hp, hp_guarded), "格挡期间完全免伤")
	await get_tree().create_timer(1.1).timeout
	_check(knight.guard_time <= 0.0, "格挡 1 秒后结束")
	_check(not knight.can_execute_planned_action(), "冷却中的旧动作不会被 Idle 重复进入")

	# 格挡和火焰斩击都在冷却时，应回到普通攻击，而不是卡在格挡循环。
	var settle := 0.0
	while knight.state_machine.current_name != &"idle" and settle < 1.5:
		await get_tree().process_frame
		settle += get_process_delta_time()
	for key in knight.action_cooldowns.keys():
		knight.action_cooldowns[key] = 0.0
	for action in knight.actions:
		if action.action_id != &"knight_basic":
			knight.action_cooldowns[action.action_id] = action.cooldown
	knight.mana = knight.max_mana
	enemies[0].position = knight.position + Vector2(70, 0)
	knight.target = enemies[0]
	knight.brain.enabled = true
	knight.brain.force_think()
	_check(knight.planned_action != null and knight.planned_action.action_id == &"knight_basic",
		"技能冷却后骑士恢复普通攻击")

	var hp_after_guard := knight.hp
	knight.take_damage(100.0, enemies[0])
	_check(knight.hp < hp_after_guard, "格挡结束后恢复正常受伤")

	Engine.time_scale = 1.0
	# 等 Battle 的 3 秒倒计时协程结束，避免测试退出时留下 SceneTreeTimer。
	await get_tree().create_timer(2.1).timeout
	GameState.reset_lineups()
	battle.queue_free()
	await get_tree().process_frame


func _test_smart_knight() -> void:
	print("\n[骑士] 联合目标/技能决策")
	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"knight")
	GameState.set_slot(0, 1, &"wizard")
	GameState.set_slot(1, 0, &"soldier")
	GameState.set_slot(1, 1, &"archer")
	GameState.set_slot(1, 2, &"skeleton")
	var battle: Battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	var knight: Unit = battle.living_units(0)[0]
	var wizard: Unit = battle.living_units(0)[1]
	var enemies: Array[Unit] = battle.living_units(1)
	var origin := Vector2(battle.field_min.x + 320.0, (battle.field_min.y + battle.field_max.y) * 0.5)
	knight.position = origin
	wizard.position = origin + Vector2(-235, -80)
	enemies[0].position = origin + Vector2(-100, 0)
	enemies[1].position = origin + Vector2(125, -25)
	enemies[2].position = origin + Vector2(135, 25)
	enemies[0].hp *= 0.55
	for fighter in [wizard, enemies[0], enemies[1], enemies[2]]:
		fighter.brain.enabled = false
	knight.brain.target = enemies[0]
	knight.target = enemies[0]
	knight.mana = knight.max_mana
	knight.brain._observe()
	var score_before := knight.brain._score_target(enemies[0], 100.0)
	enemies[0].target = wizard
	var score_after := knight.brain._score_target(enemies[0], 100.0)
	_check(score_after > score_before + 0.30, "威胁后排队友的敌人得到保护优先级")
	knight.brain.force_think()
	_check(knight.brain.judgment.target == enemies[0], "单独索敌倾向近处的残血敌人")
	_check(knight.planned_action != null and knight.planned_action.action_id == &"knight_flame_slash"
		and knight.target in [enemies[1], enemies[2]] and knight.brain.planned_target_count == 2,
		"联合评分让火焰斩击转向两名聚集的敌人")
	_check(knight.brain.plan_reason.contains("预计命中 2 人"), "观察镜解释技能选择的预计命中人数")
	knight.brain.enabled = false
	var isolated_hp := enemies[0].hp
	var cluster_hp := [enemies[1].hp, enemies[2].hp]
	knight.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(0.9).timeout
	_check(is_equal_approx(enemies[0].hp, isolated_hp)
		and enemies[1].hp < cluster_hp[0] and enemies[2].hp < cluster_hp[1],
		"实际施法命中聚集目标且未误伤孤立目标")
	# 同等距离、近似价值的目标之间保持当前目标，不因微小差距反复转向。
	enemies[0].position = origin + Vector2(-400, 0)
	enemies[0].target = null
	wizard.target = null
	enemies[1].position = origin + Vector2(110, -15)
	enemies[2].position = origin + Vector2(110, 15)
	for foe in enemies:
		foe.hp = foe.max_hp
	var targeting: WeightedTargeting = knight.definition.behavior_profile.targeting
	var old_sticky: float = targeting.sticky_bonus
	var old_jitter: float = targeting.random_jitter
	targeting.sticky_bonus = 0.0
	targeting.random_jitter = 0.0
	knight.brain.target = enemies[2]
	knight.target = enemies[2]
	knight.brain._observe()
	var challenger_score := knight.brain._score_target(enemies[1], knight.position.distance_to(enemies[1].position))
	var incumbent_score := knight.brain._score_target(enemies[2], knight.position.distance_to(enemies[2].position))
	knight.brain._judge()
	_check(challenger_score > incumbent_score and knight.brain.target == enemies[2],
		"近似评分目标保持锁定，避免来回切换")
	targeting.sticky_bonus = old_sticky
	targeting.random_jitter = old_jitter
	# 低血量时，候选站位避开其他近身敌人。
	knight.hp = knight.max_hp * 0.3
	knight.target = enemies[1]
	var movement: StandardMovement = knight.definition.behavior_profile.movement
	var stop := maxf(knight.target_reach(-18.0) * movement.preferred_range_ratio, 54.0)
	var lateral := (2.0 - float(knight.slot)) / 2.0 * minf(movement.lateral_span, stop * 0.36) + movement.flank_y_bias
	var forward := sqrt(maxf(stop * stop - lateral * lateral, 0.0)) * movement.forward_ratio
	var old_position: Vector2 = battle.clamp_unit_position(enemies[1].position + Vector2(-forward, lateral))
	enemies[0].position = old_position
	var safer_position := knight.movement_goal()
	_check(safer_position.distance_to(enemies[0].position) > 20.0,
		"低血量骑士避开被敌人占据的默认站位")
	# 队友的单体攻击已足以击杀时，骑士不跟着交满蓝大招。
	knight.hp = knight.max_hp
	knight.action_cooldowns[knight.actions[2].action_id] = 0.0
	enemies[0].position = origin + Vector2(-400, 0)
	enemies[2].position = origin + Vector2(500, 0)
	enemies[1].hp = wizard.attack_damage * 0.5
	wizard.target = enemies[1]
	wizard.planned_action = wizard.actions[0]
	wizard.state_machine.transition_to(&"action", true)
	knight.brain.enabled = true
	knight.brain.force_think()
	_check(knight.brain._committed_ally_damage(enemies[1]) > enemies[1].hp
		and (knight.planned_action == null or knight.planned_action.action_id != &"knight_flame_slash"),
		"队友已承诺补刀时骑士保留满蓝大招")
	GameState.reset_lineups()
	battle.queue_free()
	await get_tree().process_frame


func _test_wizard_and_elite_orc() -> void:
	print("\n[法师/精锐兽人] 技能与战斗信息")
	var wizard_def := UnitCatalog.get_definition(&"wizard")
	var fireball: CombatActionDefinition = wizard_def.actions[1]
	var freeze: CombatActionDefinition = wizard_def.actions[2]
	_check(fireball.effects[0].projectile_kind == UnitDefinition.ProjectileKind.FIREBALL
		and freeze.effects[0].projectile_kind == UnitDefinition.ProjectileKind.ICE,
		"法师两招使用火球和冰封素材")
	_check(fireball.mana_cost == 0.0 and freeze.mana_cost >= wizard_def.max_mana,
		"法师火球按 CD、冰封按满蓝释放")
	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"wizard")
	GameState.set_slot(1, 0, &"soldier")
	var battle: Battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	var wizard: Unit = battle.living_units(0)[0]
	var enemy: Unit = battle.living_units(1)[0]
	wizard.brain.enabled = false
	enemy.brain.enabled = false
	wizard.position = battle.field_min + Vector2(180, 150)
	enemy.position = wizard.position + Vector2(230, 0)
	wizard.target = enemy
	wizard.planned_action = fireball
	wizard.state_machine.transition_to(&"action", true)
	battle.hud.set_selected_unit(wizard)
	_check(battle.hud.skill_status.text.contains("火球术") and battle.hud.skill_status.text.contains("冰封术")
		and battle.hud.skill_status.text.contains("CD"), "战斗观察镜显示每招冷却和蓝耗")
	await get_tree().create_timer(0.9).timeout
	_check(enemy.burn_time > 0.0 and enemy.hp < enemy.max_hp and battle.projectiles_fired > 0,
		"火球飞行命中后造成伤害和灼烧")
	wizard.mana = wizard.max_mana
	wizard.planned_action = freeze
	wizard.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(0.8).timeout
	_check(enemy.stun_time > 0.0, "冰封弹命中后眩晕目标")
	battle.queue_free()
	await get_tree().process_frame

	var elite_def := UnitCatalog.get_definition(&"elite_orc")
	var sweep: CombatActionDefinition = elite_def.actions[1]
	var heavy: CombatActionDefinition = elite_def.actions[2]
	_check(sweep.animation == &"attack_02" and sweep.target_mode == CombatActionDefinition.TargetMode.DIRECTION
		and sweep.advance_speed > 0.0 and sweep.effects.size() == 4,
		"attack02 向人群推进并连续攻击")
	_check(heavy.animation == &"attack_03" and heavy.effects[0].shape == ActionEffectDefinition.Shape.SINGLE
		and heavy.effects[0].damage_ratio >= 3.0, "attack03 是高伤害单体大招")
	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"elite_orc")
	GameState.set_slot(1, 0, &"soldier")
	GameState.set_slot(1, 1, &"archer")
	GameState.set_slot(1, 2, &"skeleton")
	battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	var elite: Unit = battle.living_units(0)[0]
	var enemies: Array[Unit] = battle.living_units(1)
	elite.position = battle.field_min + Vector2(180, 170)
	enemies[0].position = elite.position + Vector2(105, 0)
	enemies[1].position = elite.position + Vector2(170, 0)
	enemies[2].position = elite.position + Vector2(0, 180)
	for foe in enemies:
		foe.brain.enabled = false
	elite.mana = 0.0
	elite.brain.force_think()
	_check(elite.planned_action == sweep and elite.planned_direction.x > 0.5,
		"空蓝时选 attack02 并朝敌人密集方向")
	elite.brain.enabled = false
	var start_x := elite.position.x
	var off_hp := enemies[2].hp
	elite.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(1.0).timeout
	_check(elite.position.x > start_x + 30.0 and enemies[0].hp < enemies[0].max_hp
		and enemies[1].hp < enemies[1].max_hp and is_equal_approx(enemies[2].hp, off_hp),
		"attack02 边移动边多次命中人群")
	elite.position = Vector2(start_x, elite.position.y)
	enemies[0].position = elite.position + Vector2(75, 0)
	enemies[1].position = elite.position + Vector2(95, 40)
	elite.mana = elite.max_mana
	elite.target = enemies[0]
	elite.planned_action = heavy
	var target_hp := enemies[0].hp
	var other_hp := enemies[1].hp
	elite.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(0.8).timeout
	_check(enemies[0].hp < target_hp - 100.0 and is_equal_approx(enemies[1].hp, other_hp),
		"attack03 仅对目标造成高额伤害")
	GameState.reset_lineups()
	battle.queue_free()
	await get_tree().process_frame


func _test_lancer_charge() -> void:
	print("\n[枪兵] 冲锋与火焰 DOT")
	var definition := UnitCatalog.get_definition(&"lancer")
	var pierce: CombatActionDefinition = definition.actions[1]
	var flame: CombatActionDefinition = definition.actions[2]
	_check(pierce.charge_to_farthest and flame.charge_to_farthest and pierce.charge_speed > 0.0,
		"两招均配置为向最远敌人冲锋")
	_check(pierce.mana_cost == 0.0 and flame.mana_cost >= definition.max_mana,
		"attack2 仅受 CD 限制，attack3 满蓝释放")
	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"lancer")
	GameState.set_slot(1, 0, &"soldier")
	GameState.set_slot(1, 1, &"archer")
	GameState.set_slot(1, 2, &"skeleton")
	var battle: Battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	var lancer: Unit
	var enemies: Array[Unit] = []
	for fighter in battle.units:
		if fighter.team == 0:
			lancer = fighter
		else:
			enemies.append(fighter)
	if lancer == null or enemies.size() != 3:
		_check(false, "枪兵与 3 名敌人生成成功")
		battle.queue_free()
		return
	var start := battle.field_min + Vector2(150, 150)
	start.y = (battle.field_min.y + battle.field_max.y) * 0.5
	lancer.position = start
	enemies[0].position = start + Vector2(150, 0)
	enemies[1].position = start + Vector2(400, 0)
	enemies[2].position = start + Vector2(200, 150)
	for enemy in enemies:
		enemy.brain.enabled = false
	lancer.mana = lancer.max_mana
	lancer.brain.force_think()
	_check(lancer.planned_action == flame and lancer.target == enemies[1],
		"满蓝时选 attack3，目标是最远敌人")
	lancer.mana = 0.0
	lancer.brain.force_think()
	_check(lancer.planned_action == pierce and lancer.target == enemies[1],
		"空蓝时选 attack2，仍以最远敌人为目标")
	lancer.brain.enabled = false
	var hp0 := enemies[0].hp
	var hp1 := enemies[1].hp
	var hp2 := enemies[2].hp
	lancer.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(1.2).timeout
	_check(lancer.global_position.x >= start.x + 370.0, "枪兵移动到冲锋目标附近")
	_check(enemies[0].hp < hp0 and enemies[1].hp < hp1 and is_equal_approx(enemies[2].hp, hp2),
		"路径内敌人受伤，路径外敌人不受伤")
	_check(battle.action_hits == 2 and enemies[0].global_position.x > start.x + 150.0,
		"每个路径敌人只命中一次并被击退")
	# 复位战场，单独验证大招首击与后续跳伤。
	lancer.position = start
	enemies[0].position = start + Vector2(150, 0)
	enemies[1].position = start + Vector2(400, 0)
	lancer.mana = lancer.max_mana
	lancer.action_cooldowns[flame.action_id] = 0.0
	lancer.target = enemies[1]
	lancer.planned_action = flame
	lancer.planned_direction = Vector2.RIGHT
	var flame_before := enemies[0].hp
	lancer.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(1.2).timeout
	var after_direct := enemies[0].hp
	_check(after_direct < flame_before and enemies[0].burn_time > 0.0,
		"attack3 首击后附加火焰状态")
	await get_tree().create_timer(0.65).timeout
	_check(enemies[0].hp < after_direct and battle.action_hits == 4,
		"火焰持续跳伤且不重复计为冲锋命中")
	await get_tree().create_timer(2.2).timeout
	var expired_hp := enemies[0].hp
	_check(is_zero_approx(enemies[0].burn_time), "火焰在配置的持续时间后结束")
	await get_tree().create_timer(0.6).timeout
	_check(is_equal_approx(enemies[0].hp, expired_hp), "火焰结束后不再扣血")
	GameState.reset_lineups()
	battle.queue_free()
	await get_tree().process_frame


func _test_orc_rider_tank() -> void:
	print("\n[兽人骑兵] 抗线、冲撞与护盾")
	var definition := UnitCatalog.get_definition(&"orc_rider")
	var basic: CombatActionDefinition = definition.actions[0]
	var ram: CombatActionDefinition = definition.actions[1]
	var cyclone: CombatActionDefinition = definition.actions[2]
	var block: CombatActionDefinition = definition.actions[3]
	_check(definition.role == "坦克" and definition.max_hp > UnitCatalog.get_definition(&"werebear").max_hp
		and definition.armor > UnitCatalog.get_definition(&"armored_orc").armor,
		"兽人骑兵成为荒野最高生命与护甲的前排")
	_check(basic.animation == &"attack_02" and definition.attack_animation == &"attack_02",
		"attack02 是兽人骑兵普通攻击")
	_check(ram.animation == &"attack_01" and ram.mana_cost == 0.0
		and ram.advance_distance > 0.0 and ram.effects[0].knockback > 0.0,
		"attack01 是定距突进击退技能")
	_check(block.animation == &"block" and block.effects[0].kind == ActionEffectDefinition.Kind.GUARD,
		"block 动画对应格挡技能")
	_check(cyclone.animation == &"attack_03" and cyclone.mana_cost >= definition.max_mana
		and cyclone.effects[1].kind == ActionEffectDefinition.Kind.SHIELD,
		"attack03 是满蓝环斩与护盾大招")

	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"orc_rider")
	for index in 4:
		GameState.set_slot(1, index, &"soldier")
	var battle: Battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	var rider: Unit = null
	var enemies: Array[Unit] = []
	for fighter in battle.units:
		fighter.brain.enabled = false
		if fighter.team == 0:
			rider = fighter
		else:
			enemies.append(fighter)
	if rider == null or enemies.size() != 4:
		_check(false, "兽人骑兵与四名敌人生成成功")
		GameState.reset_lineups()
		battle.queue_free()
		return
	var start: Vector2 = battle.field_min + Vector2(220.0, 220.0)
	rider.position = start
	enemies[0].position = start + Vector2(230.0, 0.0)
	for index in range(1, 4):
		enemies[index].position = start + Vector2(300.0, 250.0 + index * 70.0)
	rider.mana = 0.0
	rider.brain.enabled = true
	rider.brain.force_think()
	_check(rider.planned_action == ram, "目标在远处且空蓝时选择冲撞")
	rider.brain.enabled = false
	rider.target = enemies[0]
	rider.planned_action = ram
	rider.planned_direction = Vector2.RIGHT
	var before_hp: float = enemies[0].hp
	rider.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(0.8).timeout
	_check(rider.global_position.x >= start.x + 160.0 and rider.global_position.x <= start.x + 185.0,
		"冲撞前进约 180 像素后停止")
	_check(enemies[0].hp < before_hp and enemies[0].global_position.x > start.x + 270.0,
		"冲撞命中目标并将其击退")

	rider.hp = rider.max_hp * 0.5
	rider.target = enemies[0]
	rider.planned_action = block
	rider.action_cooldowns[block.action_id] = 0.0
	rider.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(0.1).timeout
	var guarded_hp: float = rider.hp
	rider.take_damage(100.0, enemies[0])
	_check(rider.guard_time > 0.0 and is_equal_approx(rider.hp, guarded_hp),
		"格挡期间免疫伤害")
	await get_tree().create_timer(1.3).timeout

	rider.position = start
	enemies[0].position = start + Vector2(90.0, 0.0)
	enemies[1].position = start + Vector2(120.0, 60.0)
	enemies[2].position = start + Vector2(280.0, 100.0)
	enemies[3].position = start + Vector2(280.0, -100.0)
	rider.mana = rider.max_mana
	rider.target = enemies[0]
	rider.planned_action = cyclone
	rider.planned_direction = Vector2.RIGHT
	var hp_near: float = enemies[0].hp
	var hp_far: float = enemies[2].hp
	rider.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(0.9).timeout
	var two_target_shield: float = rider.max_hp * 0.24
	_check(enemies[0].hp < hp_near and is_equal_approx(enemies[2].hp, hp_far),
		"环斩只命中周围范围内的敌人")
	_check(absf(rider.shield - two_target_shield) < 1.0 and rider.shield_time > 0.0,
		"命中两名敌人获得 24% 最大生命护盾")
	var hp_before_absorb: float = rider.hp
	var shield_before_absorb: float = rider.shield
	rider.take_damage(100.0, enemies[0])
	_check(is_equal_approx(rider.hp, hp_before_absorb) and rider.shield < shield_before_absorb,
		"护盾先于生命吸收伤害")
	_check(rider.health_bar.shield_ratio > 0.0 and rider.ai_snapshot().shield != "0",
		"血条与战斗观察镜显示护盾")

	enemies[2].position = start + Vector2(0.0, 110.0)
	enemies[3].position = start + Vector2(-100.0, 30.0)
	rider.mana = rider.max_mana
	rider.action_cooldowns[cyclone.action_id] = 0.0
	rider.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(0.9).timeout
	_check(absf(rider.shield - rider.max_hp * 0.48) < 1.0,
		"四目标叠加护盾不超过 48% 最大生命")
	await get_tree().create_timer(6.1).timeout
	_check(is_zero_approx(rider.shield) and is_zero_approx(rider.shield_time),
		"护盾持续时间结束后消失")
	rider.apply_shield(100.0, 3.0, rider.max_hp * 0.48)
	var hp_before_overflow: float = rider.hp
	rider.take_damage(200.0, enemies[0])
	_check(is_zero_approx(rider.shield) and absf(rider.hp - (hp_before_overflow - 52.0)) < 0.1,
		"破盾后的剩余伤害正确扣除生命")
	GameState.reset_lineups()
	battle.queue_free()
	await get_tree().process_frame


func _test_werewolf_combo() -> void:
	print("\n[狼人] 血月连斩")
	var definition := UnitCatalog.get_definition(&"werewolf")
	var combo: CombatActionDefinition = definition.actions[1]
	_check(combo.display_name == "血月连斩" and combo.animation == &"attack_02"
		and combo.teleport_to_target and combo.preferred_min_range >= 130.0
		and combo.mana_cost >= definition.max_mana,
		"血月连斩使用 attack02，满蓝闪现到目标身前")
	_check(combo.effects.size() == 4 and combo.effects[0].shape == ActionEffectDefinition.Shape.SINGLE
		and combo.effects[3].status_kind == ActionEffectDefinition.StatusKind.BLEED
		and combo.effects[3].requires_action_hit,
		"三段单体伤害后仅对命中目标附加流血")
	_check(definition.sprite_frames.get_frame_count(&"attack_02") > combo.effects[3].trigger_frame,
		"所有连斩结算帧都处于实际动画内")

	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"werewolf")
	GameState.set_slot(1, 0, &"werebear")
	GameState.set_slot(1, 1, &"soldier")
	GameState.set_slot(1, 2, &"skeleton")
	var battle: Battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	var wolf: Unit = battle.living_units(0)[0]
	var enemies: Array[Unit] = battle.living_units(1)
	for enemy in enemies:
		enemy.brain.enabled = false
	var start: Vector2 = battle.field_min + Vector2(260.0, 210.0)
	wolf.position = start
	enemies[0].position = start + Vector2(230.0, 0.0)
	enemies[1].position = start + Vector2(70.0, 70.0)
	enemies[2].position = start + Vector2(470.0, 0.0)
	wolf.mana = 0.0
	wolf.brain.force_think()
	_check(wolf.planned_action != combo, "空蓝时不会选择血月连斩")
	wolf.mana = wolf.max_mana
	wolf.brain.force_think()
	_check(wolf.planned_action == combo and wolf.target == enemies[0],
		"满蓝时选择中距离敌人并释放血月连斩")
	wolf.brain.enabled = false
	wolf.target = enemies[0]
	wolf.planned_action = combo
	var target_hp: float = enemies[0].hp
	var other_hp: float = enemies[1].hp
	wolf.state_machine.transition_to(&"action", true)
	_check(wolf.global_position.distance_to(enemies[0].global_position) < 100.0
		and wolf.global_position.x > start.x + 110.0,
		"狼人立即闪现到目标身前的近战位置")
	await get_tree().create_timer(0.9).timeout
	_check(battle.action_hits == 3 and enemies[0].hp < target_hp - wolf.attack_damage * 2.5,
		"血月连斩对单体连续命中三次并造成高额伤害")
	_check(is_equal_approx(enemies[1].hp, other_hp), "附近其他敌人不受连斩伤害")
	_check(enemies[0].bleed_time > 0.0 and is_zero_approx(enemies[1].bleed_time),
		"只有被连斩命中的目标流血")
	var after_direct: float = enemies[0].hp
	await get_tree().create_timer(0.6).timeout
	_check(enemies[0].hp < after_direct and battle.action_hits == 3,
		"流血持续跳伤且不重复计入连斩命中")

	wolf.position = start
	enemies[0].position = start + Vector2(0.0, 300.0)
	enemies[1].position = start + Vector2(0.0, -250.0)
	enemies[2].position = start + Vector2(240.0, 0.0)
	wolf.mana = wolf.max_mana
	wolf.action_cooldowns[combo.action_id] = 0.0
	wolf.target = enemies[2]
	wolf.planned_action = combo
	wolf.state_machine.transition_to(&"action", true)
	enemies[2].position = start + Vector2(500.0, 0.0)
	var missed_hp: float = enemies[2].hp
	await get_tree().create_timer(0.9).timeout
	_check(is_equal_approx(enemies[2].hp, missed_hp) and is_zero_approx(enemies[2].bleed_time),
		"目标离开近战距离后，落空的连斩不会附加流血")
	await get_tree().create_timer(2.8).timeout
	_check(is_zero_approx(enemies[0].bleed_time), "流血在四秒后结束")
	wolf.position = start
	enemies[0].position = start + Vector2(500.0, 300.0)
	enemies[1].position = start + Vector2(500.0, -250.0)
	enemies[2].position = start + Vector2(75.0, 0.0)
	wolf.mana = wolf.max_mana
	wolf.action_cooldowns[combo.action_id] = 0.0
	wolf.brain.enabled = true
	wolf.brain.force_think()
	_check(wolf.planned_action == combo and wolf.target == enemies[2],
		"没有中距离目标时也会对贴身敌人释放连斩")
	wolf.brain.enabled = false
	GameState.reset_lineups()
	battle.queue_free()
	await get_tree().process_frame


func _test_armored_skeleton_basic_and_ultimate() -> void:
	print("\n[重甲骷髅] 普攻与大招")
	var definition := UnitCatalog.get_definition(&"armored_skeleton")
	_check(definition.actions.size() == 2, "重甲骷髅只配置普攻和满蓝大招")
	if definition.actions.size() != 2:
		return
	var basic: CombatActionDefinition = definition.actions[0]
	var ultimate: CombatActionDefinition = definition.actions[1]
	_check(basic.animation == &"attack_01" and basic.category == CombatActionDefinition.Category.BASIC
		and basic.mana_cost == 0.0 and basic.effects[0].trigger_frame < definition.sprite_frames.get_frame_count(&"attack_01"),
		"attack1 普攻无需蓝量且伤害帧有效")
	_check(ultimate.animation == &"attack_02" and ultimate.mana_cost >= definition.max_mana,
		"attack2 只作为满蓝大招")
	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"armored_skeleton")
	GameState.set_slot(1, 0, &"werebear")
	var battle: Battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	var skeleton: Unit = battle.living_units(0)[0]
	var enemy: Unit = battle.living_units(1)[0]
	skeleton.position = battle.field_min + Vector2(250.0, 220.0)
	enemy.position = skeleton.position + Vector2(75.0, 0.0)
	enemy.brain.enabled = false
	skeleton.brain.force_think()
	_check(skeleton.planned_action == basic, "开场空蓝时决策层选择 attack1 普攻")
	skeleton.brain.enabled = false
	skeleton.target = enemy
	skeleton.planned_action = basic
	var hp_before_basic: float = enemy.hp
	skeleton.state_machine.transition_to(&"action", true)
	_check(skeleton.current_animation() == &"attack_01", "普攻实际播放 attack1 动画")
	await get_tree().create_timer(0.7).timeout
	_check(enemy.hp < hp_before_basic and battle.action_hits == 1,
		"attack1 普攻实际命中目标一次")
	skeleton.mana = skeleton.max_mana
	skeleton.brain.enabled = true
	skeleton.brain.force_think()
	_check(skeleton.planned_action == ultimate, "满蓝后决策层选择 attack2 大招")
	skeleton.brain.enabled = false
	skeleton.planned_action = ultimate
	var hp_before_ultimate: float = enemy.hp
	skeleton.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(0.7).timeout
	_check(enemy.hp < hp_before_ultimate and enemy.stun_time > 0.0,
		"attack2 大招造成范围伤害与眩晕")
	_check(skeleton.mana < skeleton.max_mana, "attack2 大招消耗满蓝")
	skeleton.brain.enabled = true
	skeleton.brain.force_think()
	_check(skeleton.planned_action == basic, "大招后继续使用 attack1 普攻")
	skeleton.brain.enabled = false
	GameState.reset_lineups()
	battle.queue_free()
	await get_tree().process_frame


func _test_axeman_skills() -> void:
	print("\n[5] 重甲斧兵技能")
	var axeman_definition := UnitCatalog.get_definition(&"armored_axeman")
	var spin: CombatActionDefinition = null
	var heavy: CombatActionDefinition = null
	for action in axeman_definition.actions:
		if action.action_id == &"armored_axeman_spin":
			spin = action
		elif action.action_id == &"armored_axeman_heavy":
			heavy = action
	_check(spin != null, "重甲斧兵拥有旋风斩 Action")
	_check(heavy != null, "重甲斧兵拥有重击 Action")
	if spin == null or heavy == null:
		return
	_check(spin.animation == &"attack_02" and spin.target_mode == CombatActionDefinition.TargetMode.DIRECTION,
		"旋风斩使用 attack_02 并选择方向")
	_check(spin.effects.size() == 5 and spin.advance_speed > 0.0 and spin.min_targets <= 1,
		"旋风斩包含 5 个伤害帧并边转边移动")
	_check(heavy.animation == &"attack_03" and not heavy.effects.is_empty()
		and is_equal_approx(heavy.effects[0].damage_ratio, 2.0), "重击使用 attack_03 且为 2 倍单体伤害")
	_check(spin.mana_cost >= axeman_definition.max_mana, "旋风斩需要满蓝释放")
	_check(is_equal_approx(heavy.mana_cost, 0.0), "重击不消耗蓝量")

	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"armored_axeman")
	GameState.set_slot(1, 0, &"werebear")
	GameState.set_slot(1, 1, &"soldier")
	GameState.set_slot(1, 2, &"skeleton")
	var battle: Battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame

	var axeman: Unit = null
	var enemies: Array[Unit] = []
	for unit in battle.units:
		if unit.team == 0:
			axeman = unit
		else:
			enemies.append(unit)
	_check(axeman != null and enemies.size() == 3, "技能测试生成斧兵与 3 名敌人")
	if axeman == null or enemies.size() < 3:
		battle.queue_free()
		await get_tree().process_frame
		return

	axeman.position = Vector2(700, 650)
	enemies[0].position = Vector2(780, 650)
	enemies[1].position = Vector2(400, 800)
	enemies[2].position = Vector2(1000, 800)
	for enemy in enemies:
		enemy.brain.enabled = false
	axeman.brain.enabled = true
	axeman.mana = axeman.max_mana
	axeman.brain.force_think()
	_check(axeman.planned_action != null and axeman.planned_action.action_id == &"armored_axeman_spin",
		"只有单个目标时旋风斩仍然满足释放条件")
	axeman.mana = 0.0
	axeman.action_cooldowns[spin.action_id] = 0.0
	axeman.brain.force_think()
	_check(axeman.planned_action != null and axeman.planned_action.action_id == &"armored_axeman_heavy",
		"空蓝时旋风斩不可用，重击无蓝耗仍可选择")
	axeman.mana = axeman.max_mana
	axeman.brain.force_think()
	_check(axeman.planned_action != null and axeman.planned_action.action_id == &"armored_axeman_spin",
		"满蓝后旋风斩重新可用")
	# 旋风斩冷却时才轮到重击；重击不是靠“至少 2 人”这个条件才出现的。
	axeman.action_cooldowns[spin.action_id] = spin.cooldown
	axeman.brain.force_think()
	_check(axeman.planned_action != null and axeman.planned_action.action_id == &"armored_axeman_heavy",
		"旋风斩冷却后单目标选择重击")
	axeman.action_cooldowns[spin.action_id] = 0.0
	enemies[0].position = Vector2(820, 650)
	enemies[1].position = Vector2(820, 700)
	enemies[2].position = Vector2(600, 650)
	axeman.brain.force_think()
	_check(axeman.planned_action != null and axeman.planned_action.action_id == &"armored_axeman_spin",
		"两名敌人成排时决策层选择旋风斩")
	_check(axeman.planned_direction.x > 0.5, "旋风斩选择右侧人数最多的方向")

	axeman.brain.enabled = false
	axeman.target = enemies[0]
	axeman.planned_action = spin
	axeman.planned_direction = Vector2.RIGHT
	var spin_hp: Array[float] = [enemies[0].hp, enemies[1].hp]
	var behind_hp: float = enemies[2].hp
	var start_x: float = axeman.global_position.x
	axeman.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(1.0).timeout
	_check(enemies[0].hp < spin_hp[0] and enemies[1].hp < spin_hp[1], "旋风斩沿直线命中多名敌人")
	_check(enemies[2].hp == behind_hp, "旋风斩不命中身后敌人")
	_check(battle.action_hits >= 5, "旋风斩产生五次碰撞伤害")
	_check(axeman.global_position.x > start_x + 20.0, "旋风斩边旋转边向攻击方向移动")

	# 重击：单目标 2 倍伤害。
	if enemies[0].alive:
		enemies[0].position = axeman.global_position + Vector2(70, 0)
		axeman.target = enemies[0]
		var heavy_before: float = enemies[0].hp
		var hits_before: int = battle.action_hits
		axeman.planned_action = heavy
		axeman.planned_direction = Vector2.RIGHT
		axeman.state_machine.transition_to(&"action", true)
		await get_tree().create_timer(0.8).timeout
		_check(enemies[0].hp < heavy_before, "重击对单体造成伤害")
		_check(battle.action_hits == hits_before + 1, "重击只结算一次伤害")

	await get_tree().create_timer(2.1).timeout
	GameState.reset_lineups()
	battle.queue_free()
	await get_tree().process_frame


func _test_skill_effects() -> void:
	print("\n[6] 治疗/召唤/状态技能")

	# 治疗
	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"priest")
	GameState.set_slot(0, 1, &"soldier")
	GameState.set_slot(1, 0, &"soldier")
	var battle: Battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	var priest: Unit = null
	var patient: Unit = null
	var enemy: Unit = null
	for unit in battle.units:
		if unit.team == 1:
			enemy = unit
		elif unit.definition.unit_id == &"priest":
			priest = unit
		else:
			patient = unit
	_check(priest != null and patient != null and enemy != null, "治疗测试生成牧师与队友")
	if priest != null and patient != null and enemy != null:
		for unit in battle.units:
			unit.brain.enabled = false
		patient.hp = patient.max_hp * 0.4
		priest.mana = priest.max_mana
		var heal_action: CombatActionDefinition = null
		for action in priest.actions:
			if action.action_id == &"priest_sanctuary":
				heal_action = action
				break
		_check(heal_action != null, "牧师拥有圣光普照 Action")
		if heal_action != null:
			var before_hp: float = patient.hp
			priest.target = enemy
			priest.planned_action = heal_action
			priest.state_machine.transition_to(&"action", true)
			await get_tree().create_timer(1.0).timeout
			_check(patient.hp > before_hp, "圣光普照治疗队友")
			_check(priest.mana < priest.max_mana, "治疗大招消耗满蓝")
	await get_tree().create_timer(2.1).timeout
	GameState.reset_lineups()
	battle.queue_free()
	await get_tree().process_frame

	# 召唤
	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"necromancer")
	GameState.set_slot(1, 0, &"soldier")
	var summon_battle: Battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(summon_battle)
	await get_tree().process_frame
	var summoner: Unit = null
	var target: Unit = null
	for unit in summon_battle.units:
		if unit.team == 0:
			summoner = unit
		else:
			target = unit
	if summoner != null and target != null:
		for unit in summon_battle.units:
			unit.brain.enabled = false
		summoner.mana = summoner.max_mana
		var summon_action: CombatActionDefinition = null
		for action in summoner.actions:
			if action.action_id == &"necromancer_summon":
				summon_action = action
				break
		_check(summon_action != null, "死灵法师拥有亡者大军 Action")
		if summon_action != null:
			var before_units := summon_battle.units.size()
			summoner.target = target
			summoner.planned_action = summon_action
			summoner.state_machine.transition_to(&"action", true)
			await get_tree().create_timer(1.0).timeout
			_check(summon_battle.units.size() > before_units, "亡者大军生成新的骷髅单位")
	await get_tree().create_timer(2.1).timeout
	GameState.reset_lineups()
	summon_battle.queue_free()
	await get_tree().process_frame

	# 眩晕 + 击退
	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"armored_orc")
	GameState.set_slot(1, 0, &"werebear")
	GameState.set_slot(1, 1, &"soldier")
	var cc_battle: Battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(cc_battle)
	await get_tree().process_frame
	var orc: Unit = null
	var bear: Unit = null
	var far_enemy: Unit = null
	for unit in cc_battle.units:
		if unit.team == 0:
			orc = unit
		elif unit.definition.unit_id == &"werebear":
			bear = unit
		else:
			far_enemy = unit
	if orc != null and bear != null and far_enemy != null:
		for unit in cc_battle.units:
			unit.brain.enabled = false
		# 目标太远时，贯甲突刺不应参与决策（它是自身圆形 AOE）。
		orc.position = Vector2(700, 650)
		bear.position = Vector2(700, 300)
		far_enemy.position = Vector2(1200, 300)
		orc.brain.enabled = true
		orc.brain.force_think()
		_check(orc.planned_action == null or orc.planned_action.action_id != &"armored_orc_bash",
			"贯甲突刺不会无视距离释放")
		orc.brain.enabled = false
		orc.position = Vector2(700, 650)
		bear.position = Vector2(790, 650)
		far_enemy.position = Vector2(300, 300)
		var bash: CombatActionDefinition = null
		for action in orc.actions:
			if action.action_id == &"armored_orc_bash":
				bash = action
				break
		_check(bash != null, "重甲兽人拥有贯甲突刺 Action")
		if bash != null:
			var bear_x := bear.global_position.x
			var bear_hp := bear.hp
			var far_hp := far_enemy.hp
			orc.target = bear
			orc.planned_action = bash
			orc.state_machine.transition_to(&"action", true)
			await get_tree().create_timer(0.7).timeout
			_check(bear.hp < bear_hp and bear.global_position.x > bear_x,
				"贯甲突刺造成伤害与击退")
			_check(bear.stun_time <= 0.0, "贯甲突刺不再造成眩晕")
			_check(far_enemy.stun_time <= 0.0 and is_equal_approx(far_enemy.hp, far_hp),
				"贯甲突刺不命中圆形范围外敌人")

		# 暂停时 HUD 应继续处理点击选人。
		get_tree().paused = true
		if cc_battle.hud != null and bear != null:
			var world_point := bear.global_position + Vector2(0, -30)
			var screen_point: Vector2 = cc_battle.get_global_transform_with_canvas() * world_point
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = screen_point
			cc_battle.hud._unhandled_input(click)
			_check(cc_battle.selected_unit == bear, "暂停时仍可通过 HUD 点击切换观察镜")
		get_tree().paused = false
	await get_tree().create_timer(2.6).timeout
	GameState.reset_lineups()
	cc_battle.queue_free()
	await get_tree().process_frame


func _test_stun_effect() -> void:
	print("\n[眩晕] 三星特效/打断/裂地盾击")
	var orc_definition := UnitCatalog.get_definition(&"armored_orc")
	var bash: CombatActionDefinition = null
	var quakeslam: CombatActionDefinition = null
	for action in orc_definition.actions:
		if action.action_id == &"armored_orc_bash":
			bash = action
		elif action.action_id == &"armored_orc_quakeslam":
			quakeslam = action
	_check(bash != null and quakeslam != null, "重甲兽人拥有贯甲突刺/裂地盾击")
	if bash == null or quakeslam == null:
		return
	var bash_has_stun := false
	for effect in bash.effects:
		if effect.kind == ActionEffectDefinition.Kind.STATUS \
				and effect.status_kind == ActionEffectDefinition.StatusKind.STUN:
			bash_has_stun = true
	_check(not bash_has_stun, "贯甲突刺只有伤害和击退，不附带眩晕")
	var stun_effect: ActionEffectDefinition = null
	for effect in quakeslam.effects:
		if effect.kind == ActionEffectDefinition.Kind.STATUS \
				and effect.status_kind == ActionEffectDefinition.StatusKind.STUN:
			stun_effect = effect
			break
	_check(stun_effect != null and stun_effect.status_duration > 0.0
		and stun_effect.shape == ActionEffectDefinition.Shape.CIRCLE
		and stun_effect.center_on_self and stun_effect.radius >= 150.0
		and stun_effect.requires_action_hit,
		"裂地盾击只眩晕圆形范围内被命中的敌人")

	# 特效本身：三颗星星、可播放、持续旋转、可停止。
	var star_scene: PackedScene = load("res://scenes/fx/stun_stars.tscn")
	_check(star_scene != null, "三星眩晕特效场景可加载")
	if star_scene != null:
		var stars: StunStars = star_scene.instantiate()
		add_child(stars)
		await get_tree().process_frame
		_check(stars.star_count() == 3, "眩晕特效由 3 颗星星组成")
		var start_angle := stars._angle
		stars.play()
		await get_tree().create_timer(0.22).timeout
		_check(stars.visible and stars.is_playing(), "眩晕特效可以播放")
		_check(not is_equal_approx(stars._angle, start_angle), "眩晕星星持续旋转")
		stars.stop()
		_check(not stars.visible, "眩晕特效可以停止")
		stars.queue_free()
		await get_tree().process_frame

	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"armored_orc")
	GameState.set_slot(1, 0, &"werebear")
	GameState.set_slot(1, 1, &"soldier")
	GameState.set_slot(1, 2, &"skeleton")
	var battle: Battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	var orc: Unit = battle.living_units(0)[0]
	var bear: Unit = battle.living_units(1)[0]
	var soldier: Unit = battle.living_units(1)[1]
	var outside: Unit = battle.living_units(1)[2]
	for unit in battle.units:
		unit.brain.enabled = false
	orc.position = Vector2(700, 650)
	bear.position = Vector2(770, 650)
	soldier.position = Vector2(700, 720)
	outside.position = Vector2(1100, 650)
	var bear_hp := bear.hp
	var soldier_hp := soldier.hp
	var outside_hp := outside.hp

	# 两名目标都先处于 Action 中，验证裂地盾击会打断所有被命中目标。
	bear.target = orc
	bear.planned_action = bear.actions[0]
	bear.state_machine.transition_to(&"action", true)
	soldier.target = orc
	soldier.planned_action = soldier.actions[0]
	soldier.state_machine.transition_to(&"action", true)
	_check(bear.state_machine.current_name == &"action" and soldier.state_machine.current_name == &"action",
		"测试前两名目标都在执行动作")

	orc.mana = orc.max_mana
	orc.target = bear
	orc.planned_action = quakeslam
	orc.state_machine.transition_to(&"action", true)
	# attack_03 第 6 帧约 0.375 秒触发伤害/眩晕。
	await get_tree().create_timer(0.7).timeout
	_check(bear.hp < bear_hp and soldier.hp < soldier_hp,
		"裂地盾击命中圆形范围内的所有敌人")
	_check(bear.stun_time > 0.0 and soldier.stun_time > 0.0,
		"裂地盾击眩晕所有被命中的敌人")
	_check(bear.state_machine.current_name == &"hurt" and soldier.state_machine.current_name == &"hurt",
		"眩晕立即打断所有目标的当前动作")
	_check(bear.current_animation() == &"hurt", "眩晕期间播放受击动画")
	var bear_vfx := bear.status_controller.get_vfx(&"stun") as StunStars
	var soldier_vfx := soldier.status_controller.get_vfx(&"stun") as StunStars
	_check(bear_vfx != null and bear_vfx.visible and bear_vfx.is_playing()
		and soldier_vfx != null and soldier_vfx.visible and soldier_vfx.is_playing(),
		"每名眩晕单位头顶都出现三星特效")
	_check(bear_vfx != null and bear_vfx.position.y < bear.health_bar.position.y,
		"三星特效位于血条上方（头顶）")
	_check(outside.stun_time <= 0.0 and is_equal_approx(outside.hp, outside_hp),
		"圆形范围外的敌人既不受伤害也不眩晕")

	await get_tree().create_timer(0.95).timeout
	_check(bear.stun_time <= 0.0 and soldier.stun_time <= 0.0
		and bear.status_controller.get_vfx(&"stun") == null
		and soldier.status_controller.get_vfx(&"stun") == null,
		"眩晕结束后所有头顶三星消失")
	_check(bear.state_machine.current_name != &"hurt" and soldier.state_machine.current_name != &"hurt",
		"眩晕结束后所有目标离开受击状态")

	await get_tree().create_timer(3.2).timeout
	GameState.reset_lineups()
	battle.queue_free()
	await get_tree().process_frame


func _test_status_framework() -> void:
	print("\n[状态] 定义/叠加/中毒爆发/图标")
	var stun_def := StatusCatalog.get_definition(&"stun")
	var slow_def := StatusCatalog.get_definition(&"slow")
	var bleed_def := StatusCatalog.get_definition(&"bleed")
	var burn_def := StatusCatalog.get_definition(&"burn")
	var poison_def := StatusCatalog.get_definition(&"poison")
	_check(StatusCatalog.count() == 5, "状态目录包含 5 种状态")
	_check(stun_def != null and slow_def != null and bleed_def != null
		and burn_def != null and poison_def != null, "眩晕/减速/流血/燃烧/中毒定义齐全")
	_check(stun_def != null and stun_def.stack_policy == StatusDefinition.StackPolicy.REFRESH,
		"眩晕使用刷新叠加")
	_check(bleed_def != null and bleed_def.stack_policy == StatusDefinition.StackPolicy.STRONGEST
		and burn_def != null and burn_def.stack_policy == StatusDefinition.StackPolicy.STRONGEST,
		"流血/燃烧只取最强")
	_check(slow_def != null and slow_def.stack_policy == StatusDefinition.StackPolicy.STRONGEST,
		"减速只取最强")
	_check(poison_def != null and poison_def.stack_policy == StatusDefinition.StackPolicy.STACK
		and poison_def.max_stacks == 5, "中毒叠层上限为 5")
	_check(stun_def != null and stun_def.icon != null and slow_def != null and slow_def.icon != null
		and bleed_def != null and bleed_def.icon != null
		and burn_def != null and burn_def.icon != null
		and poison_def != null and poison_def.icon != null, "五种状态都有占位图标")
	var slime_definition := UnitCatalog.get_definition(&"slime")
	var slime_acid: CombatActionDefinition = null
	for action in slime_definition.actions:
		if action.action_id == &"slime_acid":
			slime_acid = action
	var slime_has_poison := false
	if slime_acid != null:
		for effect in slime_acid.effects:
			if effect.kind == ActionEffectDefinition.Kind.STATUS and effect.status_id == &"poison":
				slime_has_poison = true
	_check(slime_has_poison, "酸液喷吐可以附加中毒状态")

	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"armored_orc")
	GameState.set_slot(1, 0, &"werebear")
	var battle: Battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	var source: Unit = battle.living_units(0)[0]
	var victim: Unit = battle.living_units(1)[0]
	for unit in battle.units:
		unit.brain.enabled = false
	victim.position = Vector2(900, 650)
	source.position = Vector2(700, 650)
	victim.hp = victim.max_hp
	victim.health_bar.set_ratio(1.0)

	# 眩晕：刷新而不是累加。
	victim.status_controller.apply(stun_def, source, {"duration": 1.0})
	await get_tree().create_timer(0.2).timeout
	var stun_left := victim.status_controller.remaining(&"stun")
	victim.status_controller.apply(stun_def, source, {"duration": 0.6})
	_check(stun_left > 0.5 and victim.status_controller.remaining(&"stun") <= stun_left + 0.05,
		"眩晕刷新剩余时间而不是累加")
	_check(victim.status_controller.get_vfx(&"stun") != null, "眩晕状态自动创建三星特效")
	battle.hud.set_selected_unit(victim)
	await get_tree().process_frame
	_check(battle.hud.status_row.visible and battle.hud.status_row.get_child_count() > 0,
		"观察镜显示状态图标")
	victim.status_controller.clear_all()
	await get_tree().process_frame

	# 流血：取最强，弱效果不会覆盖强效果。
	victim.status_controller.apply(bleed_def, source, {"duration": 4.0, "power": 10.0})
	victim.status_controller.apply(bleed_def, source, {"duration": 4.0, "power": 20.0})
	victim.status_controller.apply(bleed_def, source, {"duration": 4.0, "power": 5.0})
	_check(is_equal_approx(victim.status_controller.power(&"bleed"), 20.0)
		and victim.status_controller.remaining(&"bleed") > 3.5,
		"流血只保留最强伤害并刷新持续时间")
	victim.status_controller.clear_all()

	# 燃烧：同样取最强。
	victim.status_controller.apply(burn_def, source, {"duration": 3.0, "power": 10.0})
	victim.status_controller.apply(burn_def, source, {"duration": 3.0, "power": 18.0})
	victim.status_controller.apply(burn_def, source, {"duration": 3.0, "power": 6.0})
	_check(is_equal_approx(victim.status_controller.power(&"burn"), 18.0),
		"燃烧只保留最强伤害")
	victim.status_controller.clear_all()

	# 减速：0.5 比 0.7 更强，0.8 不会覆盖 0.5。
	victim.status_controller.apply(slow_def, source, {"duration": 2.0, "power": 0.7})
	victim.status_controller.apply(slow_def, source, {"duration": 2.0, "power": 0.5})
	victim.status_controller.apply(slow_def, source, {"duration": 2.0, "power": 0.8})
	_check(is_equal_approx(victim.status_controller.modify_stat(&"move_speed", 1.0), 0.5),
		"减速只保留最强倍率")
	victim.status_controller.clear_all()

	# 中毒：叠到 5 层立即结算剩余 DoT 并移除。
	victim.hp = victim.max_hp
	victim.health_bar.set_ratio(1.0)
	var poison_hp := victim.hp
	for index in 4:
		victim.status_controller.apply(poison_def, source, {"duration": 4.0, "power": 0.02})
	_check(victim.status_controller.stacks(&"poison") == 4 and victim.status_controller.has_status(&"poison"),
		"中毒可以叠到 4 层")
	victim.status_controller.apply(poison_def, source, {"duration": 4.0, "power": 0.02})
	_check(not victim.status_controller.has_status(&"poison") and victim.hp < poison_hp
		and victim.alive, "中毒满 5 层立即引爆剩余伤害并移除")
	var poison_effect := ActionEffectDefinition.new()
	poison_effect.status_id = &"poison"
	_check(StatusCatalog.definition_for_effect(poison_effect) == poison_def,
		"ActionEffect 可通过 status_id 引用中毒定义")

	await get_tree().create_timer(3.2).timeout
	GameState.reset_lineups()
	battle.queue_free()
	await get_tree().process_frame


func _test_basic_no_interrupt() -> void:
	print("\n[7] 普攻不打断/不击退")
	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"soldier")
	GameState.set_slot(1, 0, &"knight")
	var battle: Battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	var attacker: Unit = null
	var target: Unit = null
	for unit in battle.units:
		if unit.team == 0:
			attacker = unit
		else:
			target = unit
	if attacker != null and target != null:
		attacker.brain.enabled = false
		target.brain.enabled = false
		target._flinch_cooldown = 0.0
		target.state_machine.transition_to(&"idle", true)
		var start_position := target.global_position
		target.take_damage(target.max_hp * 0.2, attacker, null, false)
		_check(target.state_machine.current_name != &"hurt", "普通攻击不进入受击硬直")
		_check(target.global_position.distance_to(start_position) < 0.01, "普通攻击不产生击退")
		target.hp = target.max_hp
		target._flinch_cooldown = 0.0
		target.state_machine.transition_to(&"idle", true)
		target.take_damage(target.max_hp * 0.2, attacker, null, true)
		_check(target.state_machine.current_name == &"hurt", "技能伤害仍然可以造成受击硬直")
	await get_tree().create_timer(3.2).timeout
	GameState.reset_lineups()
	battle.queue_free()
	await get_tree().process_frame


func _test_necromancer() -> void:
	print("\n[8] 死灵法师镰刀/鬼火/召唤")
	var necro_definition := UnitCatalog.get_definition(&"necromancer")
	var scythe: CombatActionDefinition = null
	var ghostfire: CombatActionDefinition = null
	var summon: CombatActionDefinition = null
	for action in necro_definition.actions:
		if action.action_id == &"necromancer_basic":
			scythe = action
		elif action.action_id == &"necromancer_ghostfire":
			ghostfire = action
		elif action.action_id == &"necromancer_summon":
			summon = action
	_check(scythe != null and ghostfire != null and summon != null, "死灵法师拥有镰刀/鬼火/召唤三个 Action")
	if scythe == null or ghostfire == null or summon == null:
		return
	_check(scythe.animation == &"attack_01" and scythe.action_range <= 80.0
		and not scythe.effects.is_empty() and scythe.effects[0].kind == ActionEffectDefinition.Kind.DAMAGE,
		"近战使用 attack01 镰刀")
	_check(ghostfire.animation == &"attack_02" and ghostfire.min_range >= 100.0
		and not ghostfire.effects.is_empty() and ghostfire.effects[0].kind == ActionEffectDefinition.Kind.DAMAGE
		and ghostfire.effects[0].effect_scene != null,
		"远程使用 attack02 在目标位置生成鬼火")
	_check(not summon.effects.is_empty() and summon.effects[0].kind == ActionEffectDefinition.Kind.SUMMON
		and summon.effects[0].summon_count == 1 and summon.effects[0].effect_scene != null,
		"大招召唤 1 只骷髅并带魔法阵特效")

	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"necromancer")
	GameState.set_slot(1, 0, &"soldier")
	var battle: Battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	var necro: Unit = null
	var target: Unit = null
	for unit in battle.units:
		if unit.team == 0:
			necro = unit
		else:
			target = unit
	if necro != null and target != null:
		for unit in battle.units:
			unit.brain.enabled = false
		necro.target = target
		necro.position = Vector2(700, 650)
		target.position = necro.position + Vector2(60, 0)
		_check(not necro.is_target_in_action_range(ghostfire, 0.0) and necro.is_target_in_action_range(scythe, 0.0),
			"近距离鬼火不可用，镰刀可用")
		target.position = necro.position + Vector2(160, 0)
		_check(necro.is_target_in_action_range(ghostfire, 0.0) and not necro.is_target_in_action_range(scythe, 0.0),
			"远距离鬼火可用，镰刀不可用")

		# 鬼火实际发射并命中。
		var hp_before := target.hp
		var projectiles_before := battle.projectiles_fired
		necro.target = target
		necro.planned_action = ghostfire
		necro.state_machine.transition_to(&"action", true)
		await get_tree().create_timer(0.9).timeout
		_check(battle.projectiles_fired == projectiles_before and target.hp < hp_before,
			"鬼火直接在目标位置生成并命中，不发射飞行物")

		# 召唤完整流程：魔法阵 + 骷髅 summon 动画 + 正常行动。
		necro.mana = necro.max_mana
		necro.target = target
		necro.planned_action = summon
		var units_before := battle.units.size()
		necro.state_machine.transition_to(&"action", true)
		await get_tree().create_timer(0.35).timeout
		_check(battle.units.size() == units_before + 1, "亡者召唤只生成 1 只骷髅")
		var summoned: Unit = null
		for unit in battle.units:
			if unit.summoned:
				summoned = unit
		_check(summoned != null and not summoned.brain.enabled, "召唤骷髅先播放 summon 动画")
		await get_tree().create_timer(1.1).timeout
		_check(summoned != null and summoned.brain.enabled, "召唤动画结束后骷髅恢复行动")
	await get_tree().create_timer(3.2).timeout
	GameState.reset_lineups()
	battle.queue_free()
	await get_tree().process_frame


func _test_stat_editor() -> void:
	print("\n[10] 属性调试立即生效")
	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"knight")
	GameState.set_slot(1, 0, &"soldier")
	var battle: Battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	_check(battle.hud != null and battle.hud.debug_panel != null, "战斗内 F2 属性调试面板已创建")
	var unit: Unit = null
	for fighter in battle.units:
		if fighter.team == 0:
			unit = fighter
	if unit != null:
		unit.brain.enabled = false
		var old_ratio := unit.hp / unit.max_hp
		unit.apply_debug_stats({
			"max_hp": 1200.0, "attack_damage": 120.0, "attack_speed": 2.0,
			"attack_range": 140.0, "armor": 0.30, "move_speed": 150.0,
			"mana_regen": 12.0,
		})
		_check(is_equal_approx(unit.max_hp, 1200.0) and is_equal_approx(unit.hp / unit.max_hp, old_ratio)
			and is_equal_approx(unit.attack_damage, 120.0) and is_equal_approx(unit.attack_interval, 0.5)
			and is_equal_approx(unit.attack_range, 140.0) and is_equal_approx(unit.armor, 0.30)
			and is_equal_approx(unit.move_speed, 150.0) and is_equal_approx(unit.mana_regen, 12.0),
			"战斗内属性修改立即写入 Unit")
		var new_basic: CombatActionDefinition = null
		for action in unit.actions:
			if action.category == CombatActionDefinition.Category.BASIC:
				new_basic = action
				break
		_check(new_basic != null and is_equal_approx(new_basic.cooldown, 0.5)
			and is_equal_approx(new_basic.action_range, 140.0),
			"战斗内修改同步基础攻击冷却与距离")
	await get_tree().create_timer(3.2).timeout
	GameState.reset_lineups()
	battle.queue_free()
	await get_tree().process_frame


func _test_battle() -> void:
	print("\n[8] 默认阵容自动战斗")
	_check(InputMap.has_action("range_toggle"), "范围开关已注册输入动作")
	await _run_battle("默认阵容")


func _test_extra_lineup() -> void:
	print("\n[9] 随机阵容自动战斗")
	var pool: Array = UnitCatalog.all().duplicate()
	pool.shuffle()
	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	for slot in 5:
		GameState.set_slot(0, slot, pool[slot].unit_id)
		GameState.set_slot(1, slot, pool[pool.size() - 1 - slot].unit_id)
	await _run_battle("随机阵容")


func _run_battle(label: String) -> void:
	var scene: PackedScene = load("res://scenes/battle/battle.tscn")
	_check(scene != null, "%s: battle.tscn 可加载" % label)
	if scene == null:
		return
	var battle: Battle = scene.instantiate()
	add_child(battle)
	var nonzero_units: Array[StringName] = []
	for unit in battle.units:
		if not is_zero_approx(unit.mana):
			nonzero_units.append(unit.definition.unit_id)
	_check(nonzero_units.is_empty(), "%s: 双方英雄入场蓝量均为 0" % label)
	await get_tree().process_frame

	if label == "默认阵容":
		_check(not battle.show_combat_ranges, "范围环默认关闭")
		battle.toggle_speed()
		_check(is_equal_approx(Engine.time_scale, 2.0) and battle.hud.speed_button.text == "×2",
			"倍速按钮从 ×1 切换到 ×2")
		battle.toggle_speed()
		_check(is_equal_approx(Engine.time_scale, 0.5) and battle.hud.speed_button.text == "×0.5",
			"倍速按钮切换到 ×0.5 并实际减速")
		battle.toggle_speed()
		_check(is_equal_approx(Engine.time_scale, 1.0) and battle.hud.speed_button.text == "×1",
			"倍速按钮循环回 ×1")
		_check(battle.hud.range_button.toggle_mode, "范围按钮是可切换开关")
		battle.set_range_overlay(true)
		_check(battle.show_combat_ranges, "范围环可以动态打开")
		battle.set_range_overlay(false)

	var states_seen := {}
	var attack_units := {}
	var lineup_has_ranged := false
	for team in 2:
		for unit_id in GameState.get_lineup(team):
			if unit_id == null:
				continue
			var definition: UnitDefinition = UnitCatalog.get_definition(unit_id)
			if definition != null and definition.is_ranged() \
					and definition.projectile_kind != UnitDefinition.ProjectileKind.NONE:
				lineup_has_ranged = true
	for unit in battle.units:
		var record := Callable(self, "_record_state").bind(unit, states_seen, attack_units)
		unit.state_machine.state_changed.connect(record)

	Engine.time_scale = 20.0
	var waited := 0.0
	while not battle.finished and waited < 12.0:
		await get_tree().create_timer(0.1, true, false, true).timeout
		waited += 0.1
	Engine.time_scale = 1.0

	_check(battle.finished, "%s: 战斗在超时前结束（%.1fs 真实时间）" % [label, waited])
	_check(battle.winner == 0 or battle.winner == 1, "%s: 产生胜者（winner=%d）" % [label, battle.winner])
	_check(battle.elapsed > 1.0, "%s: 战斗时长有效（%.1fs）" % [label, battle.elapsed])
	if battle.winner == 0 or battle.winner == 1:
		_check(battle.team_alive(1 - battle.winner) == 0, "%s: 败方全员阵亡" % label)
	_check(states_seen.get("行动", 0) > 0, "%s: 状态机进入过行动状态" % label)
	_check(states_seen.get("死亡", 0) > 0, "%s: 状态机进入过死亡状态" % label)
	_check(states_seen.get("移动", 0) > 0, "%s: 状态机进入过移动状态" % label)
	_check(states_seen.get("受击", 0) > 0, "%s: 状态机进入过受击状态" % label)
	if lineup_has_ranged:
		_check(battle.projectiles_fired > 0, "%s: 远程单位发射过投射物（%d 次）" % [label, battle.projectiles_fired])
	else:
		_check(true, "%s: 双方均无远程单位，跳过投射物检查" % label)
	_check(battle.team_damage[0] > 0.0 and battle.team_damage[1] > 0.0, "%s: 双方都造成过伤害" % label)

	var sample: Unit = null
	for unit in battle.units:
		if is_instance_valid(unit) and unit.alive:
			sample = unit
			break
	if sample != null:
		var snapshot: Dictionary = sample.ai_snapshot()
		_check(str(snapshot["observe"]) != "尚未观察", "%s: OODA 观察文本已更新" % label)
		_check(str(snapshot["decide"]) != "尚未决策", "%s: OODA 决策文本已更新" % label)
		_check(str(snapshot["action"]) != "等待战斗开始", "%s: OODA 行动文本已更新" % label)
	else:
		_check(true, "%s: 战斗结束时无存活单位，跳过 OODA 文本采样" % label)

	Engine.time_scale = 1.0
	# 等 Battle._finish 的结算协程跑完，避免测试退出时留下 SceneTreeTimer。
	await get_tree().create_timer(1.2, true, false, true).timeout
	battle.queue_free()
	await get_tree().process_frame


func _record_state(state_name: String, unit: Unit, states_seen: Dictionary, attack_units: Dictionary) -> void:
	states_seen[state_name] = states_seen.get(state_name, 0) + 1
	if state_name == "攻击":
		attack_units[unit.team] = attack_units.get(unit.team, 0) + 1
