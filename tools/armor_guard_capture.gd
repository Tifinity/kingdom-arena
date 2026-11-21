extends Node

## 开发用：截取重甲斧兵施放「盔甲护身」时的试炼场画面。
## 运行：godot --path . res://tools/armor_guard_capture.tscn --resolution 1600x900
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
	var vfx: ArmorGuardFx
	for _index in 120:
		vfx = lab.hero.status_controller.get_vfx(&"armored_axeman_armor_guard") as ArmorGuardFx
		if is_instance_valid(vfx) and vfx.current_frame() >= 5:
			break
		await get_tree().process_frame
	if not is_instance_valid(vfx) or vfx.current_frame() < 5:
		push_error("未捕获盔甲护身的扣合帧")
		get_tree().quit(1)
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(SHOT_PATH)
	var err := image.save_png(path)
	print("[armor-guard] captured %s err=%d frame=%d" % [path, err, vfx.current_frame()])
	get_tree().quit(0 if err == OK else 1)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
