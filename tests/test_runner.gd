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
	_test_catalog()
	await _test_setup_scene()
	await _test_hero_lab()
	await _test_flame_slash()
	await _test_battle()
	await _test_extra_lineup()


func _test_catalog() -> void:
	print("\n[1] 英雄数据")
	_check(UnitCatalog.count() == 22, "名册包含 22 名英雄（实际 %d）" % UnitCatalog.count())
	var required := [&"idle", &"move", &"attack_01", &"hurt", &"death"]
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

	setup._set_filter(UnitDefinition.Faction.KINGDOM)
	_check(setup.roster_count.text.contains("9"), "阵营筛选更新可见数量")
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
	enemies[1].position = Vector2(820, 720)   # 扇形内
	enemies[2].position = Vector2(600, 650)   # 身后，不应命中
	for enemy in enemies:
		enemy.brain.enabled = false
	var hp_before: Array[float] = [enemies[0].hp, enemies[1].hp, enemies[2].hp]
	# 先验证决策层：技能就绪且目标在范围内时，应选中火焰斩击而不是普攻。
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
	for key in knight.action_cooldowns.keys():
		knight.action_cooldowns[key] = 0.0
	for action in knight.actions:
		if action.action_id != &"knight_basic":
			knight.action_cooldowns[action.action_id] = action.cooldown
	knight.mana = knight.max_mana
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


func _test_battle() -> void:
	print("\n[5] 默认阵容自动战斗")
	_check(InputMap.has_action("range_toggle"), "范围开关已注册输入动作")
	await _run_battle("默认阵容")


func _test_extra_lineup() -> void:
	print("\n[6] 随机阵容自动战斗")
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
	await get_tree().process_frame

	if label == "默认阵容":
		_check(not battle.show_combat_ranges, "范围环默认关闭")
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
			if definition != null and definition.is_ranged():
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
