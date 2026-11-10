extends Node

## 开发用：截取精锐兽人触发「狂怒」时的试炼场画面，检查 Rage 特效尺寸与位置。
## 运行：godot --path . res://tools/elite_orc_rage_capture.tscn --resolution 1600x900
## 图片写到 user://captures/（Godot 用户数据目录，不进仓库）。

const LAB_SCENE := preload("res://scenes/debug/hero_lab.tscn")
const OUT_DIR := "user://captures"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	GameState.reset_lineups()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
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
	var index := 0
	for delay in [0.18, 0.1, 0.1]:
		await _wait(delay)
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := ProjectSettings.globalize_path("%s/elite_orc_rage_%s.png" % [OUT_DIR, "abc"[index]])
		index += 1
		image.save_png(path)
		print("[rage] %s active=%s hp=%.0f/%.0f" % [path, lab.hero.status_controller.has_status(&"elite_orc_rage"),
			lab.hero.hp, lab.hero.max_hp])
	await _wait(0.4)
	await RenderingServer.frame_post_draw
	var final_image := get_viewport().get_texture().get_image()
	final_image.save_png(ProjectSettings.globalize_path("%s/elite_orc_rage.png" % OUT_DIR))
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
