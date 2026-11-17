extends Node

## 开发用：截取重甲斧兵施放「盔甲护身」时的试炼场画面，检查 Sprite Shader 的金色轮廓与暖光。
## 运行：godot --path . res://tools/armor_up_glow_capture.tscn --resolution 1600x900
## 图片写到 artifacts/，供 README 展示。

const LAB_SCENE := preload("res://scenes/debug/hero_lab.tscn")
const SHOT_PATH := "res://artifacts/armored_axeman_armor_guard.png"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	GameState.reset_lineups()
	var lab = LAB_SCENE.instantiate()
	add_child(lab)
	await _wait(0.8)
	var axeman := UnitCatalog.get_definition(&"armored_axeman")
	lab._select_definition(axeman)
	await _wait(1.2)
	lab.hero.brain.enabled = false
	var armor_guard: CombatActionDefinition = null
	for action in axeman.actions:
		if action != null and action.action_id == &"armored_axeman_armor_guard":
			armor_guard = action
			break
	lab._cast_action(armor_guard)
	# 等状态真正生效、Shader 材质挂到身体上，再让呼吸与高光进入中段。
	for _index in 120:
		if lab.hero.status_controller.has_status(&"armored_axeman_armor_guard") \
				and lab.hero.visual.material is ShaderMaterial:
			break
		await get_tree().process_frame
	await _wait(1.0)
	var vfx = lab.hero.status_controller.get_vfx(&"armored_axeman_armor_guard")
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(SHOT_PATH)
	var err := image.save_png(path)
	print("[armor-up] captured %s err=%d active=%s vfx=%s material=%s" % [path, err,
		lab.hero.status_controller.has_status(&"armored_axeman_armor_guard"),
		vfx, lab.hero.visual.material])
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
