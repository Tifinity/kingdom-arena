extends Node

## 开发用：截取精锐兽人触发「狂怒」时的试炼场画面，检查 Rage 特效尺寸与位置。
## 运行：godot --path . res://tools/elite_orc_rage_capture.tscn --resolution 1600x900
## 图片写到 artifacts/，供 README 展示。

const LAB_SCENE := preload("res://scenes/debug/hero_lab.tscn")
const SHOT_PATH := "res://artifacts/elite_orc_rage.png"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	GameState.reset_lineups()
	var lab = LAB_SCENE.instantiate()
	add_child(lab)
	await _wait(0.8)
	var elite := UnitCatalog.get_definition(&"elite_orc")
	lab._select_definition(elite)
	await _wait(1.2)
	lab.hero.brain.enabled = false
	lab.hero.hp = maxf(1.0, lab.hero.max_hp * 0.4)
	lab.hero.health_bar.set_ratio(lab.hero.hp / lab.hero.max_hp)
	lab.hero.sync_conditional_passives()
	# 等当前动作播放完，让画面停在待机姿态，只看狂怒光环。
	await _wait(1.6)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(SHOT_PATH)
	var err := image.save_png(path)
	print("[rage] captured %s err=%d active=%s" % [path, err,
		lab.hero.status_controller.has_status(&"elite_orc_rage")])
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
