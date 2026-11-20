extends CanvasLayer

signal finished

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const TAUNT_MARK_SCENE := preload("res://scenes/fx/taunt_mark.tscn")

@onready var _loading_screen: ColorRect = $LoadingScreen
@onready var _armor_glow_viewport: SubViewport = $ArmorGlowWarmup


func is_loading() -> bool:
	return _loading_screen.visible


func start() -> void:
	if is_loading():
		return
	var tree := get_tree()
	_loading_screen.show()
	await _wait_for_rendered_frame(tree)

	Engine.time_scale = 1.0
	tree.paused = false
	var error := tree.change_scene_to_file(BATTLE_SCENE)
	if error == OK:
		await tree.scene_changed
		await _warm_up_battle(tree)
	else:
		push_error("无法进入战斗：%s" % error_string(error))
	_loading_screen.hide()
	finished.emit()


func _warm_up_battle(tree: SceneTree) -> void:
	if DisplayServer.get_name() != "headless":
		# 在遮罩下提前绘制真实战场、嘲讽标记和盔甲护身材质。
		var taunt_mark := TAUNT_MARK_SCENE.instantiate() as Node2D
		taunt_mark.position = _loading_screen.size * 0.5
		add_child(taunt_mark)
		_armor_glow_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		taunt_mark.queue_free()
	await tree.process_frame


func _wait_for_rendered_frame(tree: SceneTree) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	await tree.process_frame


func _input(_event: InputEvent) -> void:
	if is_loading():
		get_viewport().set_input_as_handled()
