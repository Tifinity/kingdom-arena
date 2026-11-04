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
	await _test_axeman_skills()
	await _test_skill_effects()
	await _test_basic_no_interrupt()
	await _test_battle()
	await _test_extra_lineup()


func _test_catalog() -> void:
	print("\n[1] 英雄数据")
	_check(UnitCatalog.count() == 22, "名册包含 22 名英雄（实际 %d）" % UnitCatalog.count())
	var required := [&"idle", &"move", &"attack_01", &"hurt", &"death"]
	var missing_visual: Array[String] = []
	var missing_behavior: Array[String] = []
	for definition in UnitCatalog.all():
		if definition.visual_scene == null:
			missing_visual.append(definition.unit_id)
		if (definition.behavior_profile == null or definition.behavior_profile.targeting == null
				or definition.behavior_profile.movement == null):
			missing_behavior.append(definition.unit_id)
	_check(missing_visual.is_empty(), "22 名英雄都有视觉子场景")
	_check(missing_behavior.is_empty(), "22 名英雄都有索敌/移动行为配置")

	var missing_ultimate: Array[String] = []
	var bad_mana: Array[String] = []
	var missing_attack_use: Array[String] = []
	var effect_kinds := {}
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
	enemies[1].position = Vector2(820, 700)   # 扇形内
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
	GameState.set_slot(0, 0, &"skeleton")
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
			if action.action_id == &"skeleton_summon":
				summon_action = action
				break
		_check(summon_action != null, "骷髅拥有亡者召唤 Action")
		if summon_action != null:
			var before_units := summon_battle.units.size()
			summoner.target = target
			summoner.planned_action = summon_action
			summoner.state_machine.transition_to(&"action", true)
			await get_tree().create_timer(1.0).timeout
			_check(summon_battle.units.size() > before_units, "亡者召唤生成新的骷髅单位")
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
		# 目标太远时，盾牌震击不应参与决策（它是自身圆形 AOE）。
		orc.position = Vector2(700, 650)
		bear.position = Vector2(700, 300)
		far_enemy.position = Vector2(1200, 300)
		orc.brain.enabled = true
		orc.brain.force_think()
		_check(orc.planned_action == null or orc.planned_action.action_id != &"armored_orc_bash",
			"盾牌震击不会无视距离释放")
		orc.brain.enabled = false
		orc.position = Vector2(700, 650)
		bear.position = Vector2(790, 650)
		far_enemy.position = Vector2(300, 300)
		var bash: CombatActionDefinition = null
		for action in orc.actions:
			if action.action_id == &"armored_orc_bash":
				bash = action
				break
		_check(bash != null, "重甲兽人拥有铁颚重击 Action")
		if bash != null:
			var bear_x := bear.global_position.x
			orc.target = bear
			orc.planned_action = bash
			orc.state_machine.transition_to(&"action", true)
			await get_tree().create_timer(0.7).timeout
			_check(bear.stun_time > 0.0, "盾牌震击造成眩晕")
			_check(bear.global_position.x > bear_x, "盾牌震击造成击退")
			_check(far_enemy.stun_time <= 0.0, "盾牌震击不命中圆形范围外敌人")

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
