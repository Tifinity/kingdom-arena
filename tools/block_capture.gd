extends Node

## 开发用：强制骑士低血量释放格挡，并在受到攻击、显示“格挡”时截图。
## 运行：godot --path . res://tools/block_capture.tscn --resolution 1600x900

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	GameState.reset_lineups()
	var battle: Battle = BATTLE_SCENE.instantiate()
	add_child(battle)
	# 等倒计时完全结束，避免截图里出现巨大的倒计时数字。
	while not battle.battle_active and is_instance_valid(battle):
		await _wait(0.05)
	# 等“开战！”提示完全消失。
	await _wait(0.75)

	var knight: Unit = null
	var enemies: Array[Unit] = []
	for unit in battle.units:
		if not is_instance_valid(unit):
			continue
		if unit.team == 0 and unit.definition.unit_id == &"knight":
			knight = unit
		elif unit.team == 1:
			enemies.append(unit)
	if knight == null or enemies.is_empty():
		printerr("[block] 找不到骑士或敌人")
		get_tree().quit(1)
		return

	var block: CombatActionDefinition = null
	for action in knight.actions:
		if action.action_id == &"knight_block":
			block = action
			break
	if block == null:
		printerr("[block] 骑士没有格挡 Action")
		get_tree().quit(1)
		return

	for enemy in enemies:
		enemy.brain.enabled = false
	knight.position = Vector2(700, 650)
	for index in mini(enemies.size(), 3):
		enemies[index].position = Vector2(820 + index * 34, 620 + index * 60)
	knight.hp = knight.max_hp * 0.4
	knight.mana = knight.max_mana
	for key in knight.action_cooldowns.keys():
		knight.action_cooldowns[key] = 0.0
	# 让决策层真实地选择一次格挡，同时刷新 OODA 文本。
	knight.brain.enabled = true
	knight.brain.force_think()
	knight.brain.enabled = false
	knight.target = enemies[0]
	knight.planned_action = block
	knight.state_machine.transition_to(&"action", true)
	battle._select_at(knight.global_position + Vector2(0, -50))
	await _wait(0.18)
	knight.take_damage(100.0, enemies[0])
	await _wait(0.12)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://artifacts/block.png")
	image.save_png(path)
	print("[block] captured %s" % path)
	await _wait(1.25)
	battle.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
