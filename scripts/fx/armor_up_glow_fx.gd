class_name ArmorUpGlowFx
extends Node2D

## 重甲斧兵「盔甲护身」的 Sprite Shader 表现。
## 状态生效时给单位 Body 换上金色轮廓材质，状态结束时恢复原材质。
## 不依赖精灵表，直接采样当前动作帧的 alpha，因此光环会跟随动作、朝向和受击闪烁。

const SHADER := preload("res://shaders/armor_up_glow.gdshader")

var _unit: Unit
var _body: AnimatedSprite2D
var _material: ShaderMaterial
var _previous_material: Material
var _playing := false


func _ready() -> void:
	# 特效本身不绘制任何东西，材质直接作用在单位身体上。
	_unit = _find_unit()
	if _unit != null:
		_body = _unit.visual


func play() -> void:
	if _playing or not is_instance_valid(_body):
		return
	_previous_material = _body.material
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_body.material = _material
	_playing = true


func stop() -> void:
	_playing = false
	_restore()


func is_playing() -> bool:
	return _playing


func _exit_tree() -> void:
	_restore()


func _restore() -> void:
	if is_instance_valid(_body) and _body.material == _material:
		_body.material = _previous_material
	_material = null


func _find_unit() -> Unit:
	var node := get_parent()
	while node != null:
		if node is Unit:
			return node as Unit
		node = node.get_parent()
	return null
