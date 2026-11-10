extends Node

## 开发用：强制圣殿骑士释放「圣盾守护」，按时抓落地结界的帧，并额外存一张 2 倍放大裁切。
## 运行：godot --path . res://tools/templar_aegis_capture.tscn
## 图片写到 user://captures/（Godot 用户数据目录，不进仓库）。

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const OUT_DIR := "user://captures"
## 结界出现后依次截图的时刻（秒）。
const SHOTS := [0.5, 1.05, 1.6]
## 放大裁切的区域（设计分辨率像素）。
const ZOOM_RECT := Vector2i(720, 405)
const ZOOM := 2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	GameState.reset_lineups()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var battle: Battle = BATTLE_SCENE.instantiate()
	add_child(battle)
	while not battle.battle_active and is_instance_valid(battle):
		await _wait(0.05)
	await _wait(0.75)

	var templar: Unit = null
	var enemies: Array[Unit] = []
	for unit in battle.units:
		if not is_instance_valid(unit):
			continue
		if unit.team == 0 and unit.definition.unit_id == &"knight_templar":
			templar = unit
		elif unit.team == 1:
			enemies.append(unit)
	if templar == null or enemies.is_empty():
		printerr("[aegis] 找不到圣殿骑士或敌人")
		get_tree().quit(1)
		return

	var ultimate: CombatActionDefinition = null
	for action in templar.actions:
		if action.action_id == &"knight_templar_block":
			ultimate = action
			break
	if ultimate == null:
		printerr("[aegis] 圣殿骑士没有圣盾守护 Action")
		get_tree().quit(1)
		return

	# 清场：所有单位站定，只让圣殿骑士放一次大招，截图里不留别人的攻击特效。
	for unit in battle.units:
		if not is_instance_valid(unit):
			continue
		unit.brain.enabled = false
		unit.state_machine.transition_to(&"idle", true)
	templar.position = Vector2(620, 650)
	for index in mini(enemies.size(), 4):
		enemies[index].position = Vector2(830 + index * 30, 610 + index * 42)
	templar.mana = templar.max_mana
	for key in templar.action_cooldowns.keys():
		templar.action_cooldowns[key] = 0.0
	templar.target = enemies[0]
	templar.planned_target = enemies[0]
	templar.planned_action = ultimate
	templar.planned_point = Vector2(860, 645)
	templar.planned_has_point = true
	templar.planned_direction = Vector2.RIGHT
	templar.state_machine.transition_to(&"action", true)

	var ring: Node2D = null
	var deadline := Time.get_ticks_msec() + 3000
	while ring == null and Time.get_ticks_msec() < deadline:
		for child in battle.effects_root.get_children():
			if child.get_script() != null and child.get_script().resource_path == "res://scripts/fx/aegis_ring_fx.gd":
				ring = child as Node2D
				break
		await get_tree().process_frame
	if ring == null:
		printerr("[aegis] 结界没有生成")
		get_tree().quit(1)
		return

	var start := Time.get_ticks_msec()
	for index in SHOTS.size():
		var at := int(SHOTS[index] * 1000.0)
		while Time.get_ticks_msec() - start < at:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png(_path("aegis_%d.png" % index))
		# 窗口可能被拉伸过：先把设计坐标换成截图里的像素坐标，再定裁切框。
		var k := float(image.get_width()) / get_viewport().get_visible_rect().size.x
		var center := Vector2i(ring.global_position * k)
		var box := Vector2i(ZOOM_RECT * k)
		var region := Rect2i(center - box / 2, box)
		region = region.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
		var zoom := image.get_region(region)
		zoom.resize(region.size.x * ZOOM, region.size.y * ZOOM, Image.INTERPOLATE_NEAREST)
		zoom.save_png(_path("aegis_%d_zoom.png" % index))
		print("[aegis] captured %d @ %.2fs -> %s" % [index, SHOTS[index], _path("")])
	await _wait(1.2)
	battle.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _path(file: String) -> String:
	return ProjectSettings.globalize_path("%s/%s" % [OUT_DIR, file])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
