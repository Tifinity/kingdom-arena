extends Node

## 开发用：让重甲兽人释放盾牌震击，并在两名敌人被眩晕时截图。
## 运行：godot --path . res://tools/stun_capture.tscn --resolution 1600x900

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 1.0
	get_tree().paused = false
	await get_tree().process_frame
	GameState.reset_lineups()
	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, &"armored_orc")
	GameState.set_slot(1, 0, &"werebear")
	GameState.set_slot(1, 1, &"soldier")
	var battle: Battle = BATTLE_SCENE.instantiate()
	add_child(battle)
	while not battle.battle_active and is_instance_valid(battle):
		await _wait(0.05)
	await _wait(0.75)

	var orc: Unit = null
	var enemies: Array[Unit] = []
	for unit in battle.units:
		if not is_instance_valid(unit):
			continue
		if unit.team == 0:
			orc = unit
		else:
			enemies.append(unit)
	var bash: CombatActionDefinition = null
	if orc != null:
		for action in orc.actions:
			if action.action_id == &"armored_orc_bash":
				bash = action
				break
	if orc == null or enemies.size() < 2 or bash == null:
		printerr("[stun] 找不到重甲兽人/敌人/盾牌震击")
		get_tree().quit(1)
		return

	for unit in battle.units:
		unit.brain.enabled = false
		if unit.team == 1:
			# 截图用：冻结敌人的状态机，确保它们留在盾击范围内并保持受击姿势。
			unit.state_machine.transition_to(&"idle", true)
			unit.state_machine.set_physics_process(false)
	orc.position = Vector2(700, 660)
	enemies[0].position = Vector2(785, 635)
	enemies[1].position = Vector2(600, 720)
	orc.target = enemies[0]
	orc.planned_action = bash
	orc.state_machine.transition_to(&"action", true)
	# 第 5 帧约 0.31s 触发眩晕；再等一小段让星星完全淡入。
	await _wait(0.58)
	battle._select_at(enemies[0].global_position + Vector2(0, -50))
	await _wait(0.08)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://artifacts/stun.png")
	image.save_png(path)
	print("[stun] captured %s" % path)
	await _wait(1.2)
	battle.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
