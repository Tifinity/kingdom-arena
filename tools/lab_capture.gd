extends Node

## 开发用：截取英雄试炼场（单位 vs 稻草人、技能槽与基础/当前属性）。
## 运行：godot --path . res://tools/lab_capture.tscn --resolution 1600x900

const LAB_SCENE := preload("res://scenes/debug/hero_lab.tscn")
const SHOT_PATH := "res://artifacts/hero_lab.png"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	GameState.reset_lineups()
	var lab = LAB_SCENE.instantiate()
	add_child(lab)
	await _wait(0.5)
	var swordsman := UnitCatalog.get_definition(&"swordsman")
	lab._select_definition(swordsman)
	await _wait(2.6)
	# 只演示追击步，避免 AI 在截图前接上别的技能。
	lab.hero.brain.enabled = false
	for action in swordsman.actions:
		if action != null and action.action_id == &"swordsman_chase_step":
			lab._cast_action(action)
			break
	await _wait(0.7)
	# 模拟 5 次技能命中，展示热诚决斗满层。
	for _index in 5:
		lab.hero.register_damage_hit(lab.dummy, true)
	await _wait(0.12)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(SHOT_PATH)
	var err := image.save_png(path)
	print("[lab] captured %s err=%d" % [path, err])
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
