extends Node

## 无界面冒烟测试：
## 1) 22 份英雄数据/动画完整；2) 布阵场景能实例化并生成卡牌；
## 3) 默认阵容可以完整打完一场战斗，且 FSM 真的经历了攻击/死亡；
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
	await _test_swordsman_kit()
	await _test_priest_kit()
	await _test_knight_kit()
	await _test_flame_slash()
	await _test_templar_judgement_wave()
	await _test_templar_guardian_ultimate()
	await _test_smart_knight()
	await _test_wizard_and_elite_orc()
	await _test_lancer_charge()
	await _test_orc_rider_tank()
	await _test_werebear_skills()
	await _test_new_passives_and_soldier()
	await _test_werewolf_combo()
	await _test_armored_skeleton_basic_and_ultimate()
	await _test_axeman_skills()
	await _test_action_framework()
	await _test_skill_effects()
	await _test_armored_orc_kit()
	await _test_stun_effect()
	await _test_status_framework()
	await _test_damage_no_interrupt()
	await _test_necromancer()
	await _test_battle()
	await _test_extra_lineup()
	await _test_stat_editor()


func _test_catalog() -> void:
	print("\n[1] 英雄数据")
	_check(UnitCatalog.count() == 22, "名册包含 22 名英雄（实际 %d）" % UnitCatalog.count())
	var swordsman := UnitCatalog.get_definition(&"swordsman")
	var triple: CombatActionDefinition = swordsman.actions[1]
	var flurry: CombatActionDefinition = swordsman.actions[2]
	_check(triple.detail_text(swordsman.attack_damage).contains("三剑，每一剑造成 15（AD × 1.0）单体伤害")
		and flurry.detail_text(swordsman.attack_damage).contains("15（AD × 1.0）")
		and flurry.effects.size() == 5,
		"技能描述按每次伤害倍率显示基础伤害和连击次数")
	var original_swordsman_attack := swordsman.attack_damage
	swordsman.attack_damage = 20.0
	_check(swordsman.skill_description_text().contains("每一剑造成 20（AD × 1.0）单体伤害")
		and swordsman.skill_description_text().contains("每一次造成 20（AD × 1.0）"),
		"英雄攻击力变化后技能描述实时重算")
	swordsman.attack_damage = original_swordsman_attack
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
	var basic_timing_mismatch: Array[StringName] = []
	for definition in UnitCatalog.all():
		if not is_zero_approx(definition.starting_mana):
			nonzero_starting_mana.append(definition.unit_id)
		if definition.visual_scene == null:
			missing_visual.append(definition.unit_id)
		if (definition.behavior_profile == null or definition.behavior_profile.targeting == null
				or definition.behavior_profile.movement == null):
			missing_behavior.append(definition.unit_id)
		for action in definition.actions:
			if (action != null and action.category == CombatActionDefinition.Category.BASIC
					and absf(action.cooldown - definition.attack_interval()) > 0.02):
				basic_timing_mismatch.append(definition.unit_id)
	_check(missing_visual.is_empty(), "22 名英雄都有视觉子场景")
	_check(missing_behavior.is_empty(), "22 名英雄都有索敌/移动行为配置")
	_check(nonzero_starting_mana == [&"swordsman"] and is_equal_approx(swordsman.starting_mana, 50.0),
		"剑士入场蓝量为 50，其余英雄为 0")
	_check(basic_timing_mismatch.is_empty(), "所有英雄普攻冷却与攻速一致")

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
	var allowed_no_ultimate: Array[String] = ["elite_orc", "soldier"]
	missing_ultimate.sort()
	allowed_no_ultimate.sort()
	_check(missing_ultimate == allowed_no_ultimate,
		"精锐兽人与士兵第三技能留空，其余英雄都有满蓝大招")
	_check(bad_mana.is_empty(), "普通技能只受 CD，不再消耗蓝量")
	_check(missing_attack_use == ["soldier/attack_03"], "除士兵未使用的 attack03 外，现有技能动画均被使用")
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
	print("\n[3] 英雄试炼场：稻草人靶与四技能")
	var scene: PackedScene = load("res://scenes/debug/hero_lab.tscn")
	_check(scene != null, "hero_lab.tscn 可加载")
	if scene == null:
		return
	var lab = scene.instantiate()
	add_child(lab)
	await get_tree().process_frame
	_check(lab.hero_grid.get_child_count() == 22, "试炼场生成 22 张英雄卡（实际 %d）" % lab.hero_grid.get_child_count())
	_check(is_instance_valid(lab.battle), "试炼场默认启动真实 Battle")
	_check(is_instance_valid(lab.hero) and is_instance_valid(lab.dummy), "默认场景生成英雄与稻草人")
	_check(lab.battle.training_mode and lab.battle.battle_active and not lab.battle.finished,
		"默认进入训练模式并直接开战")
	_check(lab.dummy.definition.training_dummy and lab.dummy.definition.display_name == "稻草人",
		"右侧单位是训练用稻草人")
	_check(lab.skill_cards.size() == 4 and lab.skill_cards[0].action != null,
		"底部生成四个技能槽并绑定主动技能")

	# 稻草人：不移动、不死亡、不掉血，但记录伤害。
	var dummy_hp: float = lab.dummy.hp
	var dummy_position: Vector2 = lab.dummy.position
	lab.dummy.take_damage(99999.0, lab.hero)
	lab.dummy.move_step(Vector2.RIGHT, 1.0)
	lab.dummy.apply_knockback(lab.hero.global_position, 400.0)
	_check(lab.dummy.alive and is_equal_approx(lab.dummy.hp, dummy_hp),
		"稻草人承受致命伤害后仍存活且生命不变")
	_check(lab.dummy.position.is_equal_approx(dummy_position),
		"稻草人不会被移动或击退")
	_check(lab.battle.training_damage() > 0.0, "稻草人记录实际受到的伤害")

	# 基础属性与当前属性分列显示；开战被动与减速应分别体现在当前值和状态列表里。
	var knight := UnitCatalog.get_definition(&"knight")
	lab._select_definition(knight)
	await get_tree().process_frame
	lab._refresh_live()
	_check(lab.hero.current_attack_damage() > knight.attack_damage
		and lab.hero.current_armor() > knight.armor,
		"骑士开战被动改变当前攻击与当前护甲")
	_check(lab.stat_atk_current.text.contains("+") and lab.stat_armor_current.text.contains("+"),
		"当前属性列标出相对基础值的增益差值")
	_check(lab.buffs_label.text.contains("斗志昂扬"), "状态列表显示开战被动")
	var slow: StatusDefinition = StatusCatalog.get_definition(&"slow")
	lab.hero.status_controller.apply(slow, lab.hero, {"duration": 5.0, "power": 0.5})
	lab._refresh_live()
	_check(lab.stat_speed_current.text.contains("(")
		and lab.hero.status_controller.modify_stat(&"move_speed", lab.hero.move_speed) < lab.hero.move_speed,
		"减速后当前移速低于基础移速并显示差值")
	_check(lab.buffs_label.text.contains("减速"), "状态列表显示减速 debuff")

	var wizard := UnitCatalog.get_definition(&"wizard")
	lab._select_definition(wizard)
	await get_tree().process_frame
	_check(lab.hero.definition.unit_id == &"wizard", "切换英雄后训练单位同步更新")
	_check(lab.detail_name.text == "法师", "右侧详情同步更新")
	_check(is_equal_approx(lab.stat_max_mana.value, wizard.max_mana)
		and is_equal_approx(lab.stat_starting_mana.value, wizard.starting_mana),
		"属性面板包含最大蓝量与入场蓝量")

	var fireball: CombatActionDefinition = null
	for action in wizard.actions:
		if action.action_id == &"wizard_fireball":
			fireball = action
			break
	_check(fireball != null, "法师配置火球术")
	if fireball != null:
		lab.hero.brain.enabled = false
		lab._cast_action(fireball)
		await get_tree().create_timer(0.9).timeout
		_check(lab.hero.action_cooldown(fireball) > 0.0,
			"点击技能卡会真实施放技能并进入冷却")
		_check(lab.battle.training_damage() > 0.0,
			"手动施放的技能实际命中稻草人并记录伤害")
		lab.hero.brain.enabled = true

	var original_attack := wizard.attack_damage
	lab.stat_atk.value = 77.0
	await get_tree().process_frame
	_check(is_equal_approx(wizard.attack_damage, 77.0) and is_equal_approx(lab.hero.attack_damage, 77.0),
		"在属性 SpinBox 上修改立即同步到训练单位")
	lab.stat_atk.value = original_attack
	await get_tree().process_frame
	var original_max_mana := wizard.max_mana
	var original_starting_mana := wizard.starting_mana
	lab.stat_max_mana.value = 150.0
	lab.stat_starting_mana.value = 50.0
	await get_tree().process_frame
	# 入场蓝量设置后英雄会立刻开始回蓝，因此只检查从 50 起且没有被旧值覆盖。
	_check(is_equal_approx(wizard.max_mana, 150.0)
		and is_equal_approx(wizard.starting_mana, 50.0)
		and is_equal_approx(lab.hero.max_mana, 150.0)
		and lab.hero.mana >= 50.0 and lab.hero.mana < 60.0,
		"修改最大蓝量/入场蓝量立即生效")
	lab.stat_max_mana.value = original_max_mana
	lab.stat_starting_mana.value = original_starting_mana
	await get_tree().process_frame

	# 治疗类主动技能在试炼场里可以对自己演示：施放前自动受伤以满足目标条件。
	var priest := UnitCatalog.get_definition(&"priest")
	lab._select_definition(priest)
	await get_tree().process_frame
	var blessing: CombatActionDefinition = null
	for action in priest.actions:
		if action.action_id == &"priest_blessing":
			blessing = action
			break
	if blessing != null:
		lab.hero.brain.enabled = false
		lab._cast_action(blessing)
		await get_tree().create_timer(0.7).timeout
		_check(lab.hero.hp > lab.hero.max_hp * 0.47,
			"治疗技能会自动受伤并治疗自己，可在试炼场演示辅助技能")
	lab.queue_free()
	await get_tree().process_frame
	GameState.reset_lineups()


func _test_swordsman_kit() -> void:
	print("\n[3c] 剑士追击步与热诚决斗")
	var definition := UnitCatalog.get_definition(&"swordsman")
	var chase: CombatActionDefinition = null
	var basic: CombatActionDefinition = null
	var triple: CombatActionDefinition = null
	for action in definition.actions:
		if action == null:
			continue
		if action.action_id == &"swordsman_chase_step":
			chase = action
		elif action.action_id == &"swordsman_triple":
			triple = action
		elif action.category == CombatActionDefinition.Category.BASIC:
			basic = action
	_check(chase != null and chase.display_name == "追击步"
		and chase.category == CombatActionDefinition.Category.SKILL,
		"剑士配置主动技能追击步")
	if chase != null:
		var has_damage := false
		var status_effect: ActionEffectDefinition = null
		for effect in chase.effects:
			if effect.kind == ActionEffectDefinition.Kind.DAMAGE or effect.kind == ActionEffectDefinition.Kind.PROJECTILE:
				has_damage = true
			elif effect.kind == ActionEffectDefinition.Kind.STATUS:
				status_effect = effect
		_check(chase.mana_cost <= 0.001 and is_equal_approx(chase.cooldown, 9.0)
			and chase.movement_kind() == ActionMovementDefinition.Kind.ADVANCE
			and is_equal_approx(chase.movement_distance(), 160.0),
			"追击步为 CD9、无耗蓝、位移 160 像素的主动技能")
		_check(not has_damage and status_effect != null
			and status_effect.status_id == &"swordsman_chase_haste",
			"追击步不造成伤害，只施加攻速状态")
		_check(chase.targeting != null
			and chase.targeting.selection == ActionTargetingDefinition.Selection.LOWEST_HP_ENEMY,
			"追击步的目标规则为范围内最低血量敌人")
	var passive := definition.passive
	var zeal: StatusDefinition = passive.skill_hit_stacks_status if passive != null else null
	_check(passive != null and passive.display_name == "热诚决斗" and zeal != null
		and is_equal_approx(zeal.duration, 6.0) and zeal.max_stacks == 5
		and zeal.stack_policy == StatusDefinition.StackPolicy.STACK,
		"热诚决斗配置为每次技能命中叠一层、持续 6 秒、最多 5 层")
	if zeal != null and zeal.behavior is ZealDuelBehavior:
		var behavior := zeal.behavior as ZealDuelBehavior
		_check(is_equal_approx(behavior.attack_speed_per_stack, 0.05)
			and is_equal_approx(behavior.max_stack_bonus_damage, 5.0),
			"热诚每层攻速 +5%，满层每次攻击额外 +5")
	else:
		_check(false, "热诚决斗绑定 ZealDuelBehavior")
	_check(definition.skill_description_text().contains("追击步")
		and definition.skill_description_text().contains("热诚决斗"),
		"剑士技能详情包含追击步与热诚决斗")
	if chase == null or basic == null or triple == null or passive == null or zeal == null:
		_check(false, "剑士追击步/热诚决斗资源完整")
		return

	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"swordsman")
	GameState.set_slot(1, 0, &"soldier")
	GameState.set_slot(1, 1, &"archer")
	GameState.set_slot(1, 2, &"skeleton")
	var battle: Battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	var hero: Unit = null
	var enemies: Array[Unit] = []
	for unit in battle.units:
		if unit.team == 0:
			hero = unit
		else:
			enemies.append(unit)
	if hero == null or enemies.size() != 3:
		_check(false, "剑士追击步固定场景生成")
		battle.queue_free()
		await get_tree().process_frame
		return
	hero.brain.enabled = false
	for enemy in enemies:
		enemy.brain.enabled = false
	battle.battle_active = true
	hero.position = Vector2(700, 650)
	enemies[0].position = Vector2(980, 650)
	enemies[1].position = Vector2(960, 720)
	enemies[2].position = Vector2(1000, 590)
	enemies[0].hp = enemies[0].max_hp
	enemies[1].hp = enemies[1].max_hp * 0.5
	enemies[2].hp = enemies[2].max_hp * 0.8
	# 只让追击步参与决策，检查最低血量目标选择。
	for action in hero.actions:
		if action == null or action == chase or action.category == CombatActionDefinition.Category.BASIC:
			continue
		hero.action_cooldowns[action.action_id] = 99.0
	hero.mana = 0.0
	hero.action_cooldowns[chase.action_id] = 0.0
	hero.brain.enabled = true
	hero.brain.force_think()
	_check(hero.planned_action == chase and hero.planned_target == enemies[1],
		"AI 在范围内选择血量最低的敌人作为追击步目标")
	hero.brain.enabled = false

	# 实际施放：无伤害、向前位移并施加攻速 buff。
	var haste: StatusDefinition = StatusCatalog.get_definition(&"swordsman_chase_haste")
	hero.status_controller.clear_all()
	var start_position := hero.global_position
	hero.target = enemies[1]
	hero.planned_action = chase
	hero.planned_direction = (enemies[1].global_position - hero.position).normalized()
	hero.planned_has_point = false
	var damage_before := battle.training_damage()
	hero.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(0.6).timeout
	_check(hero.state_machine.current_name != &"death"
		and hero.global_position.distance_to(start_position) > 50.0,
		"追击步实际朝目标方向位移一段距离")
	_check(haste != null and hero.status_controller.has_status(haste.id)
		and hero.current_attack_speed() > 1.0 / hero.attack_interval * 1.05,
		"追击步施加 10% 攻速提升并反映在当前攻速")
	_check(is_equal_approx(battle.training_damage(), damage_before),
		"追击步本身不造成伤害")

	# 热诚决斗：只有技能命中叠层，普攻不叠；每次叠加刷新 6 秒。
	hero.status_controller.clear_all()
	var base_speed := hero.current_attack_speed()
	hero.register_damage_hit(enemies[0], false)
	_check(hero.status_controller.stacks(zeal.id) == 0, "普攻命中不会叠加热诚")
	hero.register_damage_hit(enemies[0], true)
	_check(hero.status_controller.stacks(zeal.id) == 1
		and hero.status_controller.remaining(zeal.id) > 5.5
		and is_equal_approx(hero.current_attack_speed(), base_speed * 1.05),
		"技能命中叠 1 层并提高 5% 攻速")
	hero.status_controller._physics_process(4.0)
	hero.register_damage_hit(enemies[0], true)
	_check(hero.status_controller.stacks(zeal.id) == 2
		and hero.status_controller.remaining(zeal.id) > 5.5,
		"再次技能命中叠层并刷新 6 秒持续时间")
	hero.register_damage_hit(enemies[0], true)
	hero.register_damage_hit(enemies[0], true)
	_check(hero.status_controller.stacks(zeal.id) == 4
		and is_equal_approx(hero.apply_status_damage_bonus(100.0, false), 100.0),
		"4 层热诚尚未获得固定额外伤害")
	hero.register_damage_hit(enemies[0], true)
	_check(hero.status_controller.stacks(zeal.id) == 5
		and is_equal_approx(hero.current_attack_speed(), base_speed * 1.25)
		and is_equal_approx(hero.apply_status_damage_bonus(100.0, false), 105.0)
		and is_equal_approx(hero.apply_status_damage_bonus(100.0, true), 105.0),
		"满 5 层时 +25% 攻速且每次攻击额外 +5 伤害")
	hero.start_action_cooldown(basic)
	_check(hero.action_cooldown(basic) < hero.attack_interval * 0.95,
		"满层攻速缩短基础普攻冷却")

	# 真实动作路径：突刺斩 3 次命中叠 3 层。
	hero.status_controller.clear_all()
	hero.action_cooldowns[triple.action_id] = 0.0
	if hero.state_machine.current_name != &"idle":
		hero.state_machine.transition_to(&"idle", true)
	hero.position = enemies[0].global_position + Vector2(-70.0, 0.0)
	hero.target = enemies[0]
	hero.planned_action = triple
	hero.planned_target = enemies[0]
	hero.planned_direction = Vector2.RIGHT
	hero.planned_has_point = false
	hero.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(0.8).timeout
	_check(hero.status_controller.stacks(zeal.id) == 3,
		"突刺斩三次技能命中真实叠加 3 层热诚")
	hero.status_controller.clear_all()

	battle.queue_free()
	await get_tree().process_frame
	GameState.reset_lineups()


func _test_priest_kit() -> void:
	print("\n[3d] 牧师三技能与恩泽被动")
	var definition := UnitCatalog.get_definition(&"priest")
	var holy_bolt: CombatActionDefinition = null
	var blessing: CombatActionDefinition = null
	var sanctuary: CombatActionDefinition = null
	for action in definition.actions:
		if action == null:
			continue
		if action.action_id == &"priest_holy_bolt":
			holy_bolt = action
		elif action.action_id == &"priest_blessing":
			blessing = action
		elif action.action_id == &"priest_sanctuary":
			sanctuary = action
	var grace := definition.passive
	_check(holy_bolt != null and blessing != null and sanctuary != null,
		"牧师配置圣光弹、祈福与圣光普照")
	_check(holy_bolt != null and not holy_bolt.effects.is_empty()
		and holy_bolt.effects[0].kind == ActionEffectDefinition.Kind.PROJECTILE
		and holy_bolt.effects[0].projectile_kind == UnitDefinition.ProjectileKind.HOLY_BOLT,
		"圣光弹使用圣光投射物")
	_check(blessing != null and blessing.target_mode == CombatActionDefinition.TargetMode.ALLY
		and blessing.targeting != null
		and blessing.targeting.selection == ActionTargetingDefinition.Selection.LOWEST_HP_ALLY
		and blessing.requires_wounded_ally,
		"祈福默认选择最低血量受伤友军")
	_check(sanctuary != null and sanctuary.target_mode == CombatActionDefinition.TargetMode.ALLY
		and sanctuary.targeting != null
		and sanctuary.targeting.selection == ActionTargetingDefinition.Selection.LOWEST_HP_ALLY
		and not sanctuary.effects.is_empty() and sanctuary.effects[0].effect_scene != null,
		"圣光普照以最低血量友军为中心并带治疗特效")
	_check(grace != null and grace.display_name == "恩泽"
		and is_equal_approx(grace.heal_below_hp_ratio, 0.4)
		and is_equal_approx(grace.heal_bonus_ratio, 0.2),
		"恩泽配置为低于 40% 生命时治疗 +20%")
	if holy_bolt == null or blessing == null or grace == null:
		_check(false, "牧师技能资源完整")
		return

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
	if priest == null or patient == null or enemy == null:
		_check(false, "牧师测试固定场景生成")
		battle.queue_free()
		await get_tree().process_frame
		return
	for unit in battle.units:
		unit.brain.enabled = false
	battle.battle_active = true
	priest.position = Vector2(700, 650)
	patient.position = Vector2(760, 650)
	enemy.position = Vector2(850, 650)
	patient.hp = patient.max_hp * 0.35
	priest.mana = priest.max_mana
	var before_heal := patient.hp
	priest.target = enemy
	priest.planned_action = blessing
	priest.planned_target = patient
	priest.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(0.7).timeout
	var heal_gain := patient.hp - before_heal
	_check(heal_gain > 17.0 and heal_gain <= 21.0,
		"祈福治疗受伤队友并按恩泽提高 20% 治疗量")

	var enemy_hp := enemy.hp
	priest.position = Vector2(700, 650)
	enemy.position = Vector2(850, 650)
	priest.mana = 0.0
	priest.target = enemy
	priest.planned_action = holy_bolt
	priest.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(1.0).timeout
	_check(enemy.hp < enemy_hp, "圣光弹命中敌人并造成伤害")

	battle.queue_free()
	await get_tree().process_frame
	GameState.reset_lineups()


func _test_knight_kit() -> void:
	print("\n[4] 骑士双连斩、格挡奖励与开战被动")
	var definition := UnitCatalog.get_definition(&"knight")
	var cleave: CombatActionDefinition = definition.actions[1]
	var block: CombatActionDefinition = definition.actions[3]
	_check(cleave.display_name == "双连斩" and cleave.effects.size() == 2
		and cleave.effects[0].shape == ActionEffectDefinition.Shape.SINGLE
		and cleave.effects[1].shape == ActionEffectDefinition.Shape.SINGLE
		and is_equal_approx(cleave.effects[0].damage_ratio, 1.2)
		and is_equal_approx(cleave.effects[1].damage_ratio, 1.5)
		and cleave.effects[0].trigger_frame < cleave.effects[1].trigger_frame,
		"双连斩依次对同一目标造成 1.2/1.5 AD")
	_check(definition.skill_description_text().contains("14.4（AD × 1.2）")
		and definition.skill_description_text().contains("18（AD × 1.5）")
		and definition.skill_description_text().contains("斗志昂扬"),
		"技能详情显示两段伤害和被动数值")
	_check(definition.passive != null and definition.passive.battle_start_statuses.size() == 2,
		"骑士配置独立的开战被动资源")
	var armor_status: StatusDefinition = definition.passive.battle_start_statuses[0]
	var original_armor_power := armor_status.base_power
	armor_status.base_power = 0.08
	_check(definition.skill_description_text().contains("护甲 +8 个百分点"),
		"调整被动状态数值后技能描述实时重算")
	armor_status.base_power = original_armor_power
	_check(is_equal_approx(block.effects[0].guard_reward_shield_ratio, 0.08)
		and is_equal_approx(block.effects[0].guard_reward_shield_duration, 3.0),
		"骑士格挡成功奖励 8% 最大生命护盾 3 秒")
	var original_block_reward := block.effects[0].guard_reward_shield_ratio
	block.effects[0].guard_reward_shield_ratio = 0.12
	_check(block.detail_text().contains("最大生命 12% 的护盾"),
		"调整格挡奖励数值后技能描述实时重算")
	block.effects[0].guard_reward_shield_ratio = original_block_reward
	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"knight")
	GameState.set_slot(1, 0, &"soldier")
	GameState.set_slot(1, 1, &"archer")
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
	if knight == null or enemies.size() != 2:
		_check(false, "骑士固定场景生成")
		battle.queue_free()
		await get_tree().process_frame
		return
	knight.brain.enabled = false
	for enemy in enemies:
		enemy.brain.enabled = false
	_check(is_equal_approx(knight.current_attack_damage(), 12.0) and is_equal_approx(knight.current_armor(), 0.15),
		"倒计时期间尚未获得被动加成")
	await get_tree().create_timer(2.5).timeout
	_check(battle.battle_active and is_equal_approx(knight.current_attack_damage(), 17.0)
		and is_equal_approx(knight.current_armor(), 0.20)
		and knight.status_controller.remaining(&"knight_morale_attack") > 19.0,
		"开战时获得攻击 +5、护甲 +5 个百分点，持续 20 秒")
	battle.hud.set_selected_unit(knight)
	_check(battle.hud.skill_status.text.contains("斗志昂扬 · 被动 · 生效中")
		and battle.hud.skill_status.text.contains("20.4（AD × 1.2）")
		and battle.hud.skill_status.text.contains("25.5（AD × 1.5）"),
		"战斗观察镜显示被动剩余时间和当前攻击力对应的技能伤害")
	knight.position = Vector2(700, 650)
	enemies[0].position = Vector2(750, 650)
	enemies[1].position = Vector2(752, 670)
	knight.target = enemies[0]
	knight.planned_action = cleave
	var first_hp := enemies[0].hp
	var other_hp := enemies[1].hp
	var hits_before := battle.action_hits
	knight.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(0.8).timeout
	var expected_damage := 17.0 * 2.7 * (1.0 - enemies[0].current_armor())
	_check(is_equal_approx(enemies[0].hp, first_hp - expected_damage)
		and is_equal_approx(enemies[1].hp, other_hp)
		and battle.action_hits == hits_before + 2,
		"双连斩实际两次命中锁定目标，附近单位不受伤")
	knight.apply_guard(1.0, 0.08, 3.0)
	knight._physics_process(1.01)
	_check(is_equal_approx(knight.shield, 0.0), "未挡住伤害时不获得奖励护盾")
	knight.apply_guard(1.0, 0.08, 3.0)
	var guarded_hp := knight.hp
	knight.take_damage(100.0, enemies[0])
	knight._physics_process(1.01)
	_check(is_equal_approx(knight.hp, guarded_hp)
		and is_equal_approx(knight.shield, knight.max_hp * 0.08)
		and knight.shield_time > 0.0,
		"格挡成功后免伤并获得 3 秒奖励护盾")
	knight.apply_guard(1.0, 0.08, 3.0)
	knight.take_damage(100.0, enemies[0])
	knight._physics_process(1.01)
	_check(is_equal_approx(knight.shield, knight.max_hp * 0.16),
		"格挡奖励叠加现有护盾，不会清除原有护盾")
	knight.status_controller._physics_process(20.1)
	_check(is_equal_approx(knight.current_attack_damage(), 12.0)
		and is_equal_approx(knight.current_armor(), 0.15),
		"被动到期后攻击和护甲恢复基础值")
	battle.queue_free()
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
	_check(skill.display_name == "烈焰剑" and is_equal_approx(skill.effects[0].damage_ratio, 1.5)
		and is_equal_approx(skill.effects[0].radius, 170.0)
		and is_equal_approx(skill.effects[0].half_angle, 65.0),
		"烈焰剑维持原扇形范围，伤害提高到 1.5 AD")
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
			"双连斩不会在单体攻击范围之外释放")
		enemies[1].position = knight.position + Vector2(65, 0)
		_check(knight.is_target_in_action_range(cleave, 4.0),
			"双连斩在单体攻击范围内可释放")

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


func _test_templar_judgement_wave() -> void:
	print("\n[4b] 圣殿骑士圣光裁决冲击波")
	var definition := UnitCatalog.get_definition(&"knight_templar")
	var judgement: CombatActionDefinition = null
	for action in definition.actions:
		if action.action_id == &"knight_templar_judgement":
			judgement = action
			break
	_check(judgement != null and judgement.effects.size() == 1
		and judgement.effects[0].effect_scene != null,
		"圣光裁决伤害效果绑定金色冲击波场景")
	if judgement == null or judgement.effects.is_empty() or judgement.effects[0].effect_scene == null:
		return
	var effect: ActionEffectDefinition = judgement.effects[0]
	_check(effect.shape == ActionEffectDefinition.Shape.CONE
		and is_equal_approx(effect.radius, 190.0)
		and is_equal_approx(effect.half_angle, 55.0)
		and is_equal_approx(effect.damage_ratio, 1.5)
		and is_equal_approx(judgement.mana_cost, 0.0),
		"圣光裁决转为 0 蓝普通技能并保留扇形范围")
	_check(judgement.detail_text(definition.attack_damage).contains("金色冲击波")
		and judgement.detail_text(definition.attack_damage).contains("AD × 1.5"),
		"圣光裁决描述同时展示冲击波与当前伤害倍率")
	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"knight_templar")
	GameState.set_slot(1, 0, &"soldier")
	GameState.set_slot(1, 1, &"archer")
	var battle: Battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	var templar: Unit = null
	var enemies: Array[Unit] = []
	for unit in battle.units:
		if unit.team == 0:
			templar = unit
		else:
			enemies.append(unit)
	if templar == null or enemies.size() != 2:
		_check(false, "圣光裁决固定场景生成")
		battle.queue_free()
		await get_tree().process_frame
		return
	templar.brain.enabled = false
	for enemy in enemies:
		enemy.brain.enabled = false
	templar.position = Vector2(700, 650)
	enemies[0].position = Vector2(850, 650)
	enemies[1].position = Vector2(600, 650)
	var front_hp := enemies[0].hp
	var rear_hp := enemies[1].hp
	templar.mana = templar.max_mana
	templar.target = enemies[0]
	templar.planned_action = judgement
	templar.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(0.45).timeout
	var wave: Node2D = null
	for child in battle.effects_root.get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/fx/templar_judgement_wave.gd":
			wave = child as Node2D
			break
	_check(wave != null and is_equal_approx(float(wave.get("radius")), effect.radius)
		and is_equal_approx(float(wave.get("half_angle")), deg_to_rad(effect.half_angle))
		and wave.global_position.distance_to(templar.global_position) < 1.0
		and absf(wave.rotation) < 0.05,
		"斩击触发时冲击波以骑士为中心、朝目标方向展开")
	_check(is_equal_approx(enemies[0].hp, front_hp - templar.current_attack_damage() * 1.5 * (1.0 - enemies[0].current_armor()))
		and is_equal_approx(enemies[1].hp, rear_hp),
		"冲击波仅作表现，扇形前方受伤而身后不受伤")
	await get_tree().create_timer(0.45).timeout
	_check(not is_instance_valid(wave), "冲击波播放后自动清理")
	battle.queue_free()
	await get_tree().process_frame
	GameState.reset_lineups()


func _test_templar_guardian_ultimate() -> void:
	print("\n[4c] 圣殿骑士冲阵嘲讽大招")
	var definition := UnitCatalog.get_definition(&"knight_templar")
	var ultimate: CombatActionDefinition = definition.actions[3]
	_check(ultimate.action_id == &"knight_templar_block" and ultimate.mana_cost == definition.max_mana
		and ultimate.animation == &"move_02"
		and ultimate.movement_kind() == ActionMovementDefinition.Kind.DASH_TO_POINT
		and ultimate.select_densest_cluster()
		and ultimate.effects.size() == 2,
		"原格挡改为使用移动2的满蓝敌群嘲讽大招")
	_check(ultimate.effects[0].status_id == &"taunt"
		and ultimate.effects[0].shape == ActionEffectDefinition.Shape.CIRCLE
		and is_equal_approx(ultimate.effects[0].radius, 160.0)
		and ultimate.effects[1].kind == ActionEffectDefinition.Kind.SHIELD
		and is_equal_approx(ultimate.effects[1].shield_per_target_ratio, 0.12),
		"大招在 160px 圆形内嘲讽，并按每名敌人 12% 最大生命获盾")
	_check(ultimate.effects[0].effect_scene != null
		and ultimate.effects[0].effect_scene.resource_path == "res://scenes/fx/aegis_ring.tscn",
		"大招落地特效使用 pixelfx 的 Aegis ring 结界")
	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"knight_templar")
	GameState.set_slot(0, 1, &"archer")
	GameState.set_slot(1, 0, &"soldier")
	GameState.set_slot(1, 1, &"armored_orc")
	GameState.set_slot(1, 2, &"skeleton")
	GameState.set_slot(1, 3, &"skeleton_archer")
	var battle: Battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	var templar: Unit = null
	var ally: Unit = null
	var enemies: Array[Unit] = []
	for unit in battle.units:
		if unit.team == 0:
			if unit.definition.unit_id == &"knight_templar":
				templar = unit
			else:
				ally = unit
		else:
			enemies.append(unit)
	if templar == null or ally == null or enemies.size() != 4:
		_check(false, "圣盾守护固定场景生成")
		battle.queue_free()
		await get_tree().process_frame
		return
	ally.brain.enabled = false
	for enemy in enemies:
		enemy.brain.enabled = false
		enemy.target = ally
	templar.position = Vector2(600, 1050)
	ally.position = Vector2(560, 1100)
	enemies[0].position = Vector2(830, 1020)
	enemies[1].position = Vector2(860, 1070)
	enemies[2].position = Vector2(900, 1030)
	enemies[3].position = Vector2(550, 1250)
	# 两处敌群人数相同：优先保护正被追击的远程友军。
	var original_third_position := enemies[2].position
	var original_fourth_position := enemies[3].position
	enemies[2].position = Vector2(450, 1420)
	enemies[3].position = Vector2(510, 1460)
	enemies[2].target = templar
	enemies[3].target = templar
	var protected_cluster := ActionTargetQuery.densest_circle_point(templar, enemies, 160.0, 340.0)
	var protected_point: Vector2 = protected_cluster.get("point", Vector2.ZERO)
	_check(int(protected_cluster.get("count", 0)) == 2
		and protected_point.distance_to(Vector2(845, 1045)) < 80.0,
		"同样密集时优先冲向正在追击后排友军的敌群")
	enemies[2].position = original_third_position
	enemies[3].position = original_fourth_position
	enemies[2].target = ally
	enemies[3].target = ally
	templar.mana = templar.max_mana
	templar.brain.enabled = true
	templar.brain.force_think()
	var chosen_point := templar.planned_point
	_check(templar.planned_action == ultimate and templar.planned_has_point
		and templar.brain.planned_target_count == 3
		and chosen_point.distance_to(Vector2(863, 1040)) < 65.0
		and templar.global_position.distance_to(chosen_point) > 150.0,
		"AI 选择可到达的三人密集区，不追逐附近的单个敌人")
	templar.brain.enabled = false
	templar.state_machine.transition_to(&"action", true)
	_check(templar.current_animation() == &"move_02", "冲向目标地点时播放移动2动画")
	var effect_deadline := Time.get_ticks_msec() + 2000
	while templar.shield <= 0.0 and Time.get_ticks_msec() < effect_deadline:
		await get_tree().process_frame
	_check(templar.global_position.distance_to(chosen_point) < 15.0
		and templar.mana < 15.0,
		"圣殿骑士实际冲入敌群并消耗满蓝")
	_check(is_equal_approx(templar.shield, templar.max_hp * 0.36)
		and templar.shield_time > 3.0,
		"三名受嘲讽敌人提供 36% 最大生命护盾")
	var all_taunted := true
	for index in 3:
		all_taunted = all_taunted and enemies[index].status_controller.has_status(&"taunt")
		all_taunted = all_taunted and enemies[index].target == templar
	_check(all_taunted and not enemies[3].status_controller.has_status(&"taunt")
		and enemies[3].target == ally,
		"圆形内三名敌人被强制改攻圣殿骑士，圈外敌人不受影响")
	var ring: Node2D = null
	for child in battle.effects_root.get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/fx/aegis_ring_fx.gd":
			ring = child as Node2D
			break
	var ground: Sprite2D = null
	var glow: Sprite2D = null
	if ring != null:
		ground = ring.get_node_or_null("Ground") as Sprite2D
		glow = ring.get_node_or_null("Glow") as Sprite2D
	_check(ring != null and is_equal_approx(float(ring.get("radius")), 160.0)
		and ring.global_position.distance_to(templar.global_position) < 1.0
		and is_equal_approx(ring.scale.x, 160.0 / AegisRingFx.SHEET_RING_RADIUS)
		and ground != null and glow != null
		and battle.effects_root.z_index + ground.z_index < 0
		and battle.effects_root.z_index + glow.z_index > 0
		and enemies[0].status_controller.get_vfx(&"taunt") != null
		and enemies[3].status_controller.get_vfx(&"taunt") == null,
		"落地结界以骑士为中心、按 160px 嘲讽半径铺开，地面层在单位下方、光柱层在上方")
	var basic: CombatActionDefinition = enemies[0].actions[0]
	_check(ActionActivation.reason(enemies[0], basic, ally).contains("被嘲讽"),
		"嘲讽期间不能对原友军目标发动攻击")
	var orc_block: CombatActionDefinition = null
	for action in enemies[1].actions:
		if action.action_id == &"armored_orc_block":
			orc_block = action
			break
	enemies[1].hp = enemies[1].max_hp * 0.4
	_check(orc_block != null and ActionActivation.reason(enemies[1], orc_block, enemies[1]).contains("被嘲讽"),
		"嘲讽期间不能改用自我格挡规避强制攻击")
	enemies[0].brain.enabled = true
	enemies[0].brain.force_think()
	_check(enemies[0].brain.target == templar and enemies[0].planned_target == templar,
		"受嘲讽敌人重新决策时仍锁定圣殿骑士")
	enemies[0].brain.enabled = false
	enemies[0].status_controller._physics_process(2.6)
	_check(enemies[0].status_controller.forced_target() == null
		and not ActionActivation.reason(enemies[0], basic, ally).contains("被嘲讽"),
		"嘲讽到期后恢复自由选敌")
	# 减速会拉长冲刺时间；嘲讽仍要等真正到达选定区域后结算。
	templar.state_machine.transition_to(&"idle", true)
	templar.position = Vector2(600, 1050)
	templar.mana = templar.max_mana
	templar.action_cooldowns[ultimate.action_id] = 0.0
	templar.status_controller.apply(StatusCatalog.get_definition(&"slow"), enemies[0], {
		"duration": 3.0, "power": 0.3,
	})
	templar.target = enemies[0]
	templar.planned_target = enemies[0]
	templar.planned_action = ultimate
	templar.planned_point = chosen_point
	templar.planned_has_point = true
	templar.planned_direction = (chosen_point - templar.global_position).normalized()
	templar.state_machine.transition_to(&"action", true)
	var slow_deadline := Time.get_ticks_msec() + 3000
	while not enemies[0].status_controller.has_status(&"taunt") and Time.get_ticks_msec() < slow_deadline:
		await get_tree().process_frame
	_check(enemies[0].status_controller.has_status(&"taunt")
		and templar.global_position.distance_to(chosen_point) <= 18.0,
		"受到减速时大招等待到达目标地点再释放嘲讽")
	var rings: Array[Node] = []
	for child in battle.effects_root.get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/fx/aegis_ring_fx.gd":
			rings.append(child)
	await get_tree().create_timer(3.2).timeout
	var rings_cleared := not rings.is_empty()
	for node in rings:
		rings_cleared = rings_cleared and not is_instance_valid(node)
	_check(rings_cleared, "结界播放完毕自动清理")
	battle.queue_free()
	await get_tree().process_frame
	GameState.reset_lineups()


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
	_check(battle.hud.skill_status.text.contains(fireball.detail_text(wizard.attack_damage)),
		"战斗观察镜显示按当前攻击力计算的技能伤害")
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
	var sweep: CombatActionDefinition = elite_def.actions[2]
	var hunt: CombatActionDefinition = elite_def.actions[1]
	_check(sweep.animation == &"attack_02" and sweep.target_mode == CombatActionDefinition.TargetMode.DIRECTION
		and sweep.movement_kind() == ActionMovementDefinition.Kind.ADVANCE and sweep.movement_speed() > 0.0
		and sweep.effects.size() == 4 and sweep.display_name == "巨斧狂袭",
		"attack02 向人群推进并连续攻击")
	_check(hunt.animation == &"attack_03" and hunt.effects[0].shape == ActionEffectDefinition.Shape.SINGLE
		and is_equal_approx(hunt.effects[0].damage_ratio, 1.5) and hunt.mana_cost == 0.0,
		"attack03 是冷酷捕猎：0 蓝重击当前目标")
	_check(elite_def.actions.size() == 3 and elite_def.passive != null
		and elite_def.passive.hp_threshold_status != null,
		"精锐兽人两主动加狂怒被动，第三格留空")
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
	elite.target = enemies[0]
	elite.planned_action = hunt
	var target_hp := enemies[0].hp
	var other_hp := enemies[1].hp
	elite.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(0.8).timeout
	var expected_hunt_damage := minf(target_hp,
		elite.attack_damage * hunt.effects[0].damage_ratio * (1.0 - enemies[0].armor))
	_check(target_hp - enemies[0].hp >= expected_hunt_damage - 0.1
		and is_equal_approx(enemies[1].hp, other_hp),
		"冷酷捕猎仅对当前目标造成 1.5 AD")

	# 狂怒：生命低于 50% 时攻击 +50%、10% 吸血，并显示 Rage 循环特效。
	elite.hp = elite.max_hp * 0.4
	elite.sync_conditional_passives()
	_check(elite.status_controller.has_status(&"elite_orc_rage"), "生命低于 50% 时触发狂怒")
	_check(is_equal_approx(elite.current_attack_damage(), elite.attack_damage * 1.5),
		"狂怒提高 50% 攻击力")
	var rage_fx := elite.status_controller.get_vfx(&"elite_orc_rage")
	_check(rage_fx is RageStatusFx and rage_fx.is_playing(), "狂怒使用 Seething 状态特效")
	battle.hud.set_selected_unit(elite)
	await get_tree().process_frame
	_check(battle.hud.skill_status.text.contains("狂怒") and battle.hud.skill_status.text.contains("生效中"),
		"观察镜显示狂怒生效中")
	var hp_before := elite.hp
	enemies[1].take_damage(20.0, elite, null, true)
	_check(is_equal_approx(elite.hp - hp_before, 2.0), "狂怒按造成伤害的 10% 吸血")
	elite.heal(elite.max_hp * 0.3)
	_check(not elite.status_controller.has_status(&"elite_orc_rage"), "生命回到 50% 以上后狂怒结束")
	_check(is_equal_approx(elite.current_attack_damage(), elite.attack_damage),
		"狂怒结束后攻击恢复基础值")
	GameState.reset_lineups()
	battle.queue_free()
	await get_tree().process_frame


func _test_lancer_charge() -> void:
	print("\n[枪兵] 冲锋与火焰 DOT")
	var definition := UnitCatalog.get_definition(&"lancer")
	var pierce: CombatActionDefinition = definition.actions[1]
	var flame: CombatActionDefinition = definition.actions[2]
	_check(pierce.select_farthest() and flame.select_farthest() and pierce.movement_kind() == ActionMovementDefinition.Kind.CHARGE and pierce.movement_speed() > 0.0,
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


func _test_werebear_skills() -> void:
	print("\n[熊人] 双爪、怒吼与震落")
	var definition := UnitCatalog.get_definition(&"werebear")
	var claw: CombatActionDefinition = definition.actions[1]
	var roar: CombatActionDefinition = definition.actions[2]
	var quake: CombatActionDefinition = definition.actions[3]
	_check(claw.effects.size() == 2 and is_equal_approx(claw.effects[0].damage_ratio, 0.9)
		and is_equal_approx(claw.effects[1].damage_ratio, 0.9), "暴怒双爪有两次单体 0.9 AD 命中")
	_check(roar.cooldown == 10.0 and roar.effects[0].shape == ActionEffectDefinition.Shape.CIRCLE
		and roar.effects[0].status_power == 0.5 and roar.effects[0].status_duration == 2.0
		and roar.effects[0].effect_scene != null and roar.animation == &"idle"
		and roar.effects[0].trigger_frame == 0,
		"怒吼范围减速 50%，持续 2 秒")
	_check(quake.select_densest_cluster() and quake.movement_kind() == ActionMovementDefinition.Kind.DASH_TO_POINT
		and quake.effects[0].effect_scene != null and quake.effects[1].status_duration == 0.5,
		"天声震落跳向密集敌群并配置落地特效与眩晕")
	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"werebear")
	for index in 3:
		GameState.set_slot(1, index, &"soldier")
	var battle: Battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	var bear: Unit = null
	var enemies: Array[Unit] = []
	for fighter in battle.units:
		fighter.brain.enabled = false
		if fighter.team == 0:
			bear = fighter
		else:
			enemies.append(fighter)
	if bear == null or enemies.size() != 3:
		_check(false, "熊人与三名目标生成成功")
		GameState.reset_lineups()
		battle.queue_free()
		return
	var start := battle.field_min + Vector2(220.0, 220.0)
	bear.position = start
	enemies[0].position = start + Vector2(85.0, 0.0)
	enemies[1].position = start + Vector2(280.0, 0.0)
	enemies[2].position = start + Vector2(295.0, 45.0)
	bear.target = enemies[0]
	bear.planned_action = claw
	var first_hp: float = enemies[0].hp
	bear.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(1.2).timeout
	_check(absf(first_hp - enemies[0].hp - bear.attack_damage * 1.8 * (1.0 - enemies[0].armor)) < 1.0,
		"暴怒双爪实际命中同一目标两次")
	bear.planned_action = roar
	bear.target = enemies[0]
	var roar_position := bear.position
	bear.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(0.7).timeout
	_check(bear.position.is_equal_approx(roar_position), "怒吼原地站立释放")
	_check(enemies[0].status_controller.has_status(&"slow") and not enemies[1].status_controller.has_status(&"slow"),
		"怒吼只减速周围敌人")
	_check(is_equal_approx(enemies[0].slow_factor, 0.5)
		and enemies[0].status_controller.get_vfx(&"slow") != null,
		"怒吼减速实际降低移速并显示圆圈")
	bear.state_machine.transition_to(&"idle", true)
	bear.mana = bear.max_mana
	bear.planned_action = quake
	bear.target = enemies[1]
	bear.planned_point = (enemies[1].position + enemies[2].position) * 0.5
	bear.planned_has_point = true
	var quake_hp: float = enemies[1].hp
	bear.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(0.65).timeout
	_check(bear.position.distance_to(bear.planned_point) < 25.0 and enemies[1].hp < quake_hp
		and enemies[1].status_controller.has_status(&"stun"), "天声震落落到敌群并造成伤害和眩晕")
	GameState.reset_lineups()
	battle.queue_free()
	await get_tree().process_frame
	var lab = load("res://scenes/debug/hero_lab.tscn").instantiate()
	add_child(lab)
	await get_tree().process_frame
	lab._select_definition(definition)
	lab.hero.brain.enabled = false
	lab._cast_action(claw)
	await get_tree().create_timer(0.8).timeout
	_check(lab.battle.training_damage() > 0.0, "试炼场暴怒双爪命中稻草人")
	lab.queue_free()
	await get_tree().process_frame


func _test_new_passives_and_soldier() -> void:
	print("\n[新被动与士兵] 光环、厚皮、跳劈、后撤射击、双武器")
	var soldier_def := UnitCatalog.get_definition(&"soldier")
	var jump: CombatActionDefinition = soldier_def.actions[2]
	var backshot: CombatActionDefinition = soldier_def.actions[3]
	_check(soldier_def.actions.size() == 4 and soldier_def.passive != null
		and jump.targeting.selection == ActionTargetingDefinition.Selection.LOWEST_ARMOR_ENEMY
		and jump.movement_kind() == ActionMovementDefinition.Kind.DASH_TO_POINT
		and backshot.movement_kind() == ActionMovementDefinition.Kind.RETREAT,
		"士兵保留近远程普攻、跳劈和后撤射击，技能3留空")
	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"knight_templar")
	GameState.set_slot(0, 1, &"knight_templar")
	GameState.set_slot(0, 2, &"soldier")
	GameState.set_slot(0, 3, &"werebear")
	GameState.set_slot(1, 0, &"soldier")
	GameState.set_slot(1, 1, &"soldier")
	var battle: Battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	var templars: Array[Unit] = []
	var soldier: Unit = null
	var bear: Unit = null
	var enemies: Array[Unit] = []
	for fighter in battle.units:
		fighter.brain.enabled = false
		if fighter.team == 1:
			enemies.append(fighter)
		elif fighter.definition.unit_id == &"knight_templar":
			templars.append(fighter)
		elif fighter.definition.unit_id == &"werebear":
			bear = fighter
		else:
			soldier = fighter
	if templars.size() != 2 or soldier == null or bear == null or enemies.size() != 2:
		_check(false, "被动和士兵测试单位生成成功")
		GameState.reset_lineups()
		battle.queue_free()
		return
	var origin := battle.field_min + Vector2(350.0, 300.0)
	templars[0].position = origin
	templars[1].position = origin + Vector2(15.0, 0.0)
	soldier.position = origin + Vector2(45.0, 0.0)
	bear.position = origin + Vector2(280.0, 100.0)
	enemies[0].position = origin + Vector2(240.0, 0.0)
	enemies[1].position = origin + Vector2(290.0, 65.0)
	_check(is_equal_approx(soldier.current_armor(), soldier.armor + 0.04)
		and is_equal_approx(templars[0].current_armor(), templars[0].armor + 0.04),
		"两个同名圣殿光环不叠加，施放者自身也受益")
	templars[0].position += Vector2(-400.0, 0.0)
	templars[1].position += Vector2(-400.0, 0.0)
	_check(is_equal_approx(soldier.current_armor(), soldier.armor), "离开 120 像素光环后护甲恢复")
	bear.hp = bear.max_hp * 0.49
	bear.sync_conditional_passives()
	_check(is_equal_approx(bear.current_armor(), bear.armor + 0.06), "熊人低于半血时厚皮增加 6 个百分点护甲")
	bear.hp = bear.max_hp * 0.5
	bear.sync_conditional_passives()
	_check(is_equal_approx(bear.current_armor(), bear.armor), "熊人回到半血时厚皮消失")
	enemies[0].armor = 0.3
	enemies[1].armor = 0.02
	_check(soldier.brain._lowest_armor_enemy_in_range(jump, enemies) == enemies[1],
		"跳劈锁定中距离内护甲最低的敌人")
	var initial_hp := enemies[1].hp
	soldier.target = enemies[1]
	soldier.planned_action = jump
	soldier.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(1.0).timeout
	_check(soldier.position.distance_to(enemies[1].position) < 100.0
		and absf(initial_hp - enemies[1].hp - soldier.attack_damage * (1.0 - enemies[1].armor)) < 0.5,
		"跳劈落到目标身旁并造成 1.0 AD 单体伤害")
	soldier.state_machine.transition_to(&"idle", true)
	soldier.position = origin + Vector2(45.0, 0.0)
	enemies[0].position = origin + Vector2(240.0, 0.0)
	var before_retreat := soldier.position
	var before_shot_hp := enemies[0].hp
	soldier.target = enemies[0]
	soldier.planned_action = backshot
	soldier.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(0.18).timeout
	_check(soldier.position.distance_to(before_retreat) > 35.0
		and is_equal_approx(enemies[0].hp, before_shot_hp), "后撤射击先位移再发箭")
	await get_tree().create_timer(0.9).timeout
	_check(absf(before_shot_hp - enemies[0].hp - soldier.attack_damage * 1.3 * (1.0 - enemies[0].armor)) < 0.5,
		"后撤射出的直线箭造成 1.3 AD 单体伤害")
	soldier.state_machine.transition_to(&"idle", true)
	soldier.action_cooldowns[jump.action_id] = 99.0
	soldier.action_cooldowns[backshot.action_id] = 99.0
	soldier.brain._observe()
	soldier.brain._judge()
	var far_plan: ActionPlan = soldier.brain._select_action()
	_check(far_plan != null and far_plan.action.action_id == &"soldier_ranged_basic",
		"远距离自动使用弓箭普攻")
	soldier.position = enemies[0].position - Vector2(65.0, 0.0)
	soldier.brain._observe()
	soldier.brain._judge()
	var near_plan: ActionPlan = soldier.brain._select_action()
	_check(near_plan != null and near_plan.action.action_id == &"soldier_basic"
		and is_equal_approx(near_plan.action.effects[0].damage_ratio, 1.2),
		"近战距离自动使用 1.2 AD 挥剑普攻")
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
		and ram.movement_distance() > 0.0 and ram.effects[0].knockback > 0.0,
		"attack01 是定距突进击退技能")
	_check(block.animation == &"block" and block.effects[0].kind == ActionEffectDefinition.Kind.GUARD,
		"block 动画对应格挡技能")
	_check(cyclone.animation == &"attack_03" and cyclone.mana_cost >= definition.max_mana
		and cyclone.effects.size() == 1 and definition.passive.skill_hit_shield_ratio == 0.05,
		"attack03 是满蓝环斩，技能命中触发被动护盾")

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
	_check(absf(rider.shield - rider.max_hp * 0.05) < 1.0,
		"冲撞技能命中触发 5% 最大生命护盾")

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
	rider.shield = 0.0
	rider.shield_time = 0.0
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
	var two_target_shield: float = rider.max_hp * 0.10
	_check(enemies[0].hp < hp_near and is_equal_approx(enemies[2].hp, hp_far),
		"环斩只命中周围范围内的敌人")
	_check(absf(rider.shield - two_target_shield) < 1.0 and rider.shield_time > 0.0,
		"命中两名敌人获得 10% 最大生命护盾")
	var hp_before_absorb: float = rider.hp
	var shield_before_absorb: float = rider.shield
	rider.take_damage(20.0, enemies[0])
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
	_check(absf(rider.shield - (shield_before_absorb - 20.0 * (1.0 - rider.armor) + rider.max_hp * 0.20)) < 1.0,
		"四目标每次命中叠加 5% 最大生命护盾")
	await get_tree().create_timer(6.1).timeout
	_check(is_zero_approx(rider.shield) and is_zero_approx(rider.shield_time),
		"护盾持续时间结束后消失")
	rider.hp = rider.max_hp
	rider.apply_shield(100.0, 3.0, rider.max_hp * 0.48)
	var hp_before_overflow: float = rider.hp
	var shield_before_overflow: float = rider.shield
	rider.take_damage(200.0, enemies[0])
	var overflow_damage := 200.0 * (1.0 - rider.armor) - shield_before_overflow
	_check(is_zero_approx(rider.shield) and absf(rider.hp - (hp_before_overflow - overflow_damage)) < 0.1,
		"破盾后的剩余伤害正确扣除生命")
	GameState.reset_lineups()
	battle.queue_free()
	await get_tree().process_frame


func _test_werewolf_combo() -> void:
	print("\n[狼人] 血月连斩")
	var definition := UnitCatalog.get_definition(&"werewolf")
	var combo: CombatActionDefinition = definition.actions[1]
	_check(combo.display_name == "血月连斩" and combo.animation == &"attack_02"
		and combo.movement_kind() == ActionMovementDefinition.Kind.TELEPORT and combo.preferred_min_range >= 130.0
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
	await get_tree().create_timer(0.8).timeout
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
	_check(spin.effects.size() == 5 and spin.movement_kind() == ActionMovementDefinition.Kind.ADVANCE and spin.movement_speed() > 0.0 and spin.min_targets <= 1,
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


func _test_action_framework() -> void:
	print("\n[技能框架] 友军目标、地点目标与施放实例")
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
	var ally_action: CombatActionDefinition
	for unit in battle.units:
		unit.brain.enabled = false
		if unit.team == 1:
			enemy = unit
		elif unit.definition.unit_id == &"priest":
			priest = unit
		else:
			patient = unit
	_check(priest != null and patient != null and enemy != null, "目标规则测试生成双方单位")
	if priest != null and patient != null and enemy != null:
		patient.hp = patient.max_hp * 0.5
		var heal_effect := ActionEffectDefinition.new()
		heal_effect.kind = ActionEffectDefinition.Kind.HEAL
		heal_effect.shape = ActionEffectDefinition.Shape.SINGLE
		heal_effect.trigger_frame = 0
		heal_effect.heal_amount = 20.0
		ally_action = CombatActionDefinition.new()
		ally_action.action_id = &"test_ally_heal"
		ally_action.display_name = "定向治疗测试"
		ally_action.category = CombatActionDefinition.Category.SUPPORT
		ally_action.target_mode = CombatActionDefinition.TargetMode.ALLY
		ally_action.animation = &"heal"
		ally_action.action_range = 1000.0
		ally_action.priority = 50
		ally_action.requires_wounded_ally = true
		ally_action.effects = [heal_effect]
		priest.actions = [ally_action]
		priest.brain.enabled = true
		priest.brain.force_think()
		priest.brain.enabled = false
		priest.brain.intent = UnitBrain.Intent.IDLE
		_check(priest.planned_action == ally_action and priest.planned_target == patient,
			"AI 将友军治疗指向受伤队友")
		_check(ActionActivation.reason(priest, ally_action, enemy).contains("阵营")
			and ActionActivation.reason(priest, ally_action, patient).is_empty(),
			"统一施放检查拒绝敌方目标并接受友军目标")
		var before_heal := patient.hp
		priest.state_machine.transition_to(&"action", true)
		await get_tree().create_timer(0.3).timeout
		_check(patient.hp > before_heal and priest.current_cast != null and priest.current_cast.target == patient,
			"友军治疗实际命中计划目标，并创建独立施放实例")
		await get_tree().create_timer(0.7).timeout
		_check(priest.current_cast == null, "动作结束后释放施放实例")

		var damage_effect := ActionEffectDefinition.new()
		damage_effect.kind = ActionEffectDefinition.Kind.DAMAGE
		damage_effect.shape = ActionEffectDefinition.Shape.CIRCLE
		damage_effect.trigger_frame = 0
		damage_effect.radius = 45.0
		damage_effect.damage_ratio = 1.0
		var point_action := CombatActionDefinition.new()
		point_action.action_id = &"test_point_blast"
		point_action.display_name = "地点范围测试"
		point_action.category = CombatActionDefinition.Category.SKILL
		point_action.target_mode = CombatActionDefinition.TargetMode.POINT
		point_action.animation = &"attack_01"
		point_action.action_range = 1000.0
		point_action.effects = [damage_effect]
		priest.actions = [point_action]
		priest.brain.enabled = true
		priest.brain.force_think()
		priest.brain.enabled = false
		priest.brain.intent = UnitBrain.Intent.IDLE
		_check(priest.planned_action == point_action and priest.planned_has_point and priest.planned_point.distance_to(enemy.global_position) < 0.1,
			"AI 为地点范围技能选中敌人位置")
		priest.target = enemy
		priest.planned_action = point_action
		priest.planned_point = enemy.global_position
		priest.planned_has_point = true
		var expected := ActionTargetQuery.enemies(priest, damage_effect, enemy, Vector2.ZERO, priest.planned_point, true)
		_check(expected.has(enemy) and ActionActivation.reason(priest, point_action, enemy, Vector2.ZERO, priest.planned_point, true).is_empty(),
			"地点目标查询与施放检查都接受所选敌人位置")
		_check(ActionActivation.reason(priest, point_action, enemy) == "缺少施放地点",
			"未选施放地点时不会误用坐标原点")
		_check(ActionActivation.reason(priest, point_action, enemy, Vector2.ZERO, priest.global_position + Vector2(2000.0, 0.0), true) == "地点超出范围",
			"地点目标超出技能范围时被拒绝")
		var before_damage := enemy.hp
		priest.state_machine.transition_to(&"action", true)
		await get_tree().create_timer(0.3).timeout
		_check(enemy.hp < before_damage, "地点范围伤害实际命中查询到的目标")
		await get_tree().create_timer(0.7).timeout
		var self_effect := ActionEffectDefinition.new()
		self_effect.kind = ActionEffectDefinition.Kind.STATUS
		self_effect.shape = ActionEffectDefinition.Shape.SELF
		self_effect.status_id = &"slow"
		self_effect.status_duration = 1.0
		self_effect.status_power = 0.6
		var self_action := CombatActionDefinition.new()
		self_action.action_id = &"test_self_status"
		self_action.target_mode = CombatActionDefinition.TargetMode.SELF
		self_action.animation = &"heal"
		self_action.effects = [self_effect]
		priest.planned_action = self_action
		priest.state_machine.transition_to(&"action", true)
		await get_tree().create_timer(0.2).timeout
		_check(priest.status_controller.has_status(&"slow") and not enemy.status_controller.has_status(&"slow"),
			"自身形状状态只施加给施法者")
	await get_tree().create_timer(1.0).timeout
	if priest != null and ally_action != null:
		var stale_target := Unit.new()
		priest.actions = [ally_action]
		priest.planned_action = ally_action
		priest.planned_target = stale_target
		battle.hud.set_selected_unit(priest)
		stale_target.free()
		var stale_reason := ActionActivation.reason(priest, ally_action, stale_target)
		battle.hud._update_inspector()
		_check(stale_reason == "目标无效" and not priest.can_execute_planned_action()
			and battle.hud.skill_status.text.contains("目标无效"),
			"目标释放后 HUD 与施放检查安全返回目标无效")
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
			priest.planned_target = patient
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
		# 目标太远时，贯甲突刺不应参与决策（它是朝向目标的直线 AOE）。
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
				"贯甲突刺不命中直线范围外敌人")

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


func _test_armored_orc_kit() -> void:
	print("\n[重甲兽人] 直线贯甲/护盾格挡/被动再生")
	var definition := UnitCatalog.get_definition(&"armored_orc")
	var bash: CombatActionDefinition = null
	var block: CombatActionDefinition = null
	var quakeslam: CombatActionDefinition = null
	for action in definition.actions:
		if action.action_id == &"armored_orc_bash":
			bash = action
		elif action.action_id == &"armored_orc_block":
			block = action
		elif action.action_id == &"armored_orc_quakeslam":
			quakeslam = action
	_check(bash != null and block != null and quakeslam != null, "重甲兽人技能数据齐全")
	var bash_damage: ActionEffectDefinition = null
	var bash_displace: ActionEffectDefinition = null
	if bash != null:
		for effect in bash.effects:
			if effect.kind == ActionEffectDefinition.Kind.DAMAGE:
				bash_damage = effect
			elif effect.kind == ActionEffectDefinition.Kind.DISPLACE:
				bash_displace = effect
	_check(bash_damage != null and bash_damage.shape == ActionEffectDefinition.Shape.RECT
		and bash_damage.length > 0.0 and bash_damage.width > 0.0
		and bash_damage.ignore_shield,
		"贯甲突刺是矩形直线伤害并忽略护盾")
	_check(bash != null and bash.target_mode == CombatActionDefinition.TargetMode.ENEMY
		and bash_damage != null and is_equal_approx(bash.action_range, bash_damage.length),
		"贯甲突刺以敌人为方向目标，释放距离与直线长度一致")
	_check(bash_displace != null
		and bash_displace.shape == ActionEffectDefinition.Shape.RECT
		and bash_damage != null
		and is_equal_approx(bash_displace.length, bash_damage.length)
		and is_equal_approx(bash_displace.width, bash_damage.width),
		"贯甲突刺的击退范围与伤害直线一致")
	var block_effect: ActionEffectDefinition = block.effects[0] if block != null and not block.effects.is_empty() else null
	_check(block_effect != null and block_effect.kind == ActionEffectDefinition.Kind.SHIELD
		and is_equal_approx(block_effect.shield_self_ratio, 0.2)
		and block_effect.duration > 0.0,
		"格挡改为立即获得 20% 最大生命护盾")
	_check(block_effect != null and block_effect.kind != ActionEffectDefinition.Kind.GUARD,
		"格挡不再使用免伤 GUARD 效果")
	var quake_damage: ActionEffectDefinition = null
	var quake_stun: ActionEffectDefinition = null
	if quakeslam != null:
		for effect in quakeslam.effects:
			if effect.kind == ActionEffectDefinition.Kind.DAMAGE:
				quake_damage = effect
			elif effect.kind == ActionEffectDefinition.Kind.STATUS:
				quake_stun = effect
	_check(quake_damage != null and quake_damage.shape == ActionEffectDefinition.Shape.CIRCLE
		and quake_damage.center_on_self and is_equal_approx(quake_damage.radius, 150.0)
		and quake_stun != null and is_equal_approx(quake_stun.status_duration, 1.0),
		"裂地盾击保持自身圆形 1.8 AD 与 1 秒眩晕")
	var passive := definition.passive
	_check(passive != null and is_equal_approx(passive.hp_regen_ratio_per_second, 0.02),
		"重甲兽人被动每秒回复 2% 最大生命")
	_check(definition.skill_description_text().contains("最大生命 20% 的护盾")
		and definition.skill_description_text().contains("每秒回复 2% 最大生命"),
		"技能详情显示护盾格挡与被动回复数值")

	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"armored_orc")
	GameState.set_slot(1, 0, &"werebear")
	GameState.set_slot(1, 1, &"soldier")
	var battle: Battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	var orc: Unit = null
	var bear: Unit = null
	var soldier: Unit = null
	for unit in battle.units:
		unit.brain.enabled = false
		if unit.team == 0:
			orc = unit
		elif unit.definition.unit_id == &"werebear":
			bear = unit
		else:
			soldier = unit
	_check(orc != null and bear != null and soldier != null, "重甲兽人测试生成双方单位")
	if orc == null or bear == null or soldier == null or bash == null or block == null:
		GameState.reset_lineups()
		battle.queue_free()
		await get_tree().process_frame
		return
	orc.position = Vector2(700, 650)
	bear.position = Vector2(790, 650)
	soldier.position = Vector2(700, 820)

	# 格挡：低血量时立即获得护盾，并且不再进入免伤状态。
	orc.hp = orc.max_hp * 0.5
	orc.health_bar.set_ratio(0.5)
	orc.target = bear
	orc.planned_action = block
	orc.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(0.2).timeout
	_check(orc.guard_time <= 0.0, "格挡期间不再进入无敌免伤")
	_check(is_equal_approx(orc.shield, orc.max_hp * 0.2) and orc.shield_time > 0.0,
		"格挡立即获得 20% 最大生命护盾")
	var hp_with_shield := orc.hp
	var shield_before_hit := orc.shield
	orc.take_damage(10.0, bear)
	_check(is_equal_approx(orc.hp, hp_with_shield) and orc.shield < shield_before_hit,
		"护盾先于生命吸收伤害")

	# 被动：每秒按最大生命 2% 回复。
	orc.hp = orc.max_hp * 0.5
	orc.health_bar.set_ratio(0.5)
	var hp_before_regen := orc.hp
	orc._physics_process(1.0)
	_check(is_equal_approx(orc.hp, hp_before_regen + orc.max_hp * 0.02),
		"被动每秒回复 2% 最大生命")
	# 等格挡动作结束，避免与同状态的贯甲突刺冲突。
	await get_tree().create_timer(1.1).timeout

	# 贯甲突刺：直线命中并击退，护盾不吸收伤害，直线外敌人不受影响。
	orc.hp = orc.max_hp
	orc.health_bar.set_ratio(1.0)
	orc.shield = 0.0
	orc.shield_time = 0.0
	bear.shield = 20.0
	bear.shield_time = 10.0
	bear.health_bar.set_shield_ratio(20.0 / bear.max_hp)
	soldier.shield = 20.0
	soldier.shield_time = 10.0
	var bear_hp := bear.hp
	var bear_shield := bear.shield
	var soldier_hp := soldier.hp
	var soldier_shield := soldier.shield
	var bear_x := bear.global_position.x
	orc.target = bear
	orc.planned_action = bash
	orc.state_machine.transition_to(&"action", true)
	await get_tree().create_timer(0.7).timeout
	_check(bear.hp < bear_hp, "贯甲突刺对直线上的敌人造成伤害")
	_check(is_equal_approx(bear.shield, bear_shield), "贯甲突刺无视并保留目标护盾")
	_check(bear.global_position.x > bear_x, "贯甲突刺击退直线上的敌人")
	_check(is_equal_approx(soldier.hp, soldier_hp) and is_equal_approx(soldier.shield, soldier_shield),
		"贯甲突刺不命中直线外的敌人")

	await get_tree().create_timer(1.5).timeout
	GameState.reset_lineups()
	battle.queue_free()
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
	_check(StatusCatalog.count() == 12, "状态目录包含 12 种状态（含厚皮）")
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


func _test_damage_no_interrupt() -> void:
	print("\n[7] 普通伤害不打断动作")
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
		attacker.position = battle.field_min + Vector2(220.0, 180.0)
		target.position = attacker.position + Vector2(55.0, 0.0)
		target.target = attacker
		target.planned_action = target.actions[0]
		target.state_machine.transition_to(&"action", true)
		_check(target.state_machine.current_name == &"action", "受击前目标正在执行普攻")
		var cast := target.current_cast
		var start_position := target.global_position
		target.take_damage(target.max_hp * 0.2, attacker)
		_check(target.state_machine.current_name == &"action" and target.current_cast == cast,
			"普通伤害不中断正在执行的动作")
		_check(target.global_position.distance_to(start_position) < 0.01, "普通攻击不产生击退")
		var skill: CombatActionDefinition = attacker.actions[1]
		target.take_damage(attacker.attack_damage * skill.effects[0].damage_ratio, attacker)
		_check(target.state_machine.current_name == &"action" and target.current_cast == cast,
			"技能伤害也不中断正在执行的动作")
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
	var wrong_starting_mana: Array[StringName] = []
	for unit in battle.units:
		if not is_equal_approx(unit.mana, unit.definition.starting_mana):
			wrong_starting_mana.append(unit.definition.unit_id)
	_check(wrong_starting_mana.is_empty(), "%s: 双方英雄按资源配置获得入场蓝量" % label)
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
	# 投射物由法师固定场景及默认阵容验证；随机阵容可能没有投射物动作，
	# 也可能在远程单位出手前结束战斗。
	if label == "默认阵容":
		_check(battle.projectiles_fired > 0, "%s: 远程单位发射过投射物（%d 次）" % [label, battle.projectiles_fired])
	_check(battle.team_damage[0] > 0.0 and battle.team_damage[1] > 0.0, "%s: 双方都造成过伤害" % label)

	var sample: Unit = null
	for unit in battle.units:
		if is_instance_valid(unit) and unit.alive:
			sample = unit
			break
	if sample != null:
		battle.hud.set_selected_unit(sample)
		battle.hud._update_inspector()
		_check(battle.hud.inspector.visible, "%s: 战斗结束后仍可安全查看存活单位技能" % label)
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
