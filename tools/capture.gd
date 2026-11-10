extends Node

## 开发用截图脚本：在真实渲染窗口里抓取布阵、战斗、OODA 观察镜与结算画面。
## 运行：Godot --path . res://tools/capture.tscn --resolution 1600x900

const SETUP_SCENE := preload("res://scenes/setup/setup_screen.tscn")
const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const LAB_SCENE := preload("res://scenes/debug/hero_lab.tscn")
const OUT_DIR := "res://artifacts"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _real_wait(0.25)
	print("[capture] window=%s viewport=%s content_scale=%s" % [
		DisplayServer.window_get_size(), get_viewport().get_visible_rect().size,
		get_window().content_scale_size,
	])
	GameState.reset_lineups()

	var setup = SETUP_SCENE.instantiate()
	add_child(setup)
	await _real_wait(0.9)
	await _shot("setup.png")
	setup.queue_free()
	await get_tree().process_frame

	var lab = LAB_SCENE.instantiate()
	add_child(lab)
	await _real_wait(0.5)
	var knight := UnitCatalog.get_definition(&"knight")
	lab._select_definition(knight)
	await _real_wait(0.8)
	lab.hero.brain.enabled = false
	for action in knight.actions:
		if action != null and action.action_id == &"knight_flame_slash":
			lab._cast_action(action)
			break
	await _real_wait(0.72)
	await _shot("hero_lab.png")
	lab.queue_free()
	await get_tree().process_frame

	var battle: Battle = BATTLE_SCENE.instantiate()
	add_child(battle)
	await _real_wait(4.6)

	# 选中场上一个单位，展示 OODA 观察镜。
	var living: Array[Unit] = battle.living_units()
	if not living.is_empty():
		var chosen: Unit = living[0]
		for unit in living:
			if unit.team == 0:
				chosen = unit
				break
		battle._select_at(chosen.global_position + Vector2(0, -50))
	await _real_wait(0.4)
	await _shot("battle.png")

	# 等到有投射物在飞，抓一张能看清箭矢/法术弹的画面。
	var ranged: Unit = null
	for unit in battle.living_units():
		if unit.definition.is_ranged():
			ranged = unit
			break
	if ranged != null:
		battle._select_at(ranged.global_position + Vector2(0, -45))
	var projectile_wait := 0.0
	while battle.projectiles_root.get_child_count() == 0 and projectile_wait < 8.0:
		await _real_wait(0.03)
		projectile_wait += 0.03
	await _real_wait(0.05)
	await _shot("battle_projectile.png")

	Engine.time_scale = 3.0
	var waited := 0.0
	while not battle.finished and waited < 40.0:
		await _real_wait(0.2)
		waited += 0.2
	Engine.time_scale = 1.0
	await _real_wait(1.6)
	await _shot("result.png")

	print("[capture] done, battle finished=%s winner=%d elapsed=%.1f" % [battle.finished, battle.winner, battle.elapsed])
	get_tree().quit()


func _real_wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT_DIR.path_join(file_name))
	var err := image.save_png(path)
	print("[capture] %s -> %s (%dx%d) err=%d" % [file_name, path, image.get_width(), image.get_height(), err])
