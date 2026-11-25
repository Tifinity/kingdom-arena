class_name UnitGroundVisual3D
extends Node3D

## 角色脚下的影子和圆环先于立绘绘制。节点随立绘销毁，坐标独立于立绘的朝向。
const RINGS_SHADER := preload("res://shaders/unit_ground_rings.gdshader")
const HERO_SHADOW_DEPTH_SCALE := 0.82
const HERO_RING_DEPTH_SCALE := 0.40

var _unit: Unit
var _stage: ArenaStage3D
var _shadow: Sprite3D
var _shadow_tint: Color
var _rings: MeshInstance3D
var _material: ShaderMaterial
var _shadow_depth_scale := 1.0


func setup(unit: Unit, stage: ArenaStage3D) -> void:
	_unit = unit
	_stage = stage
	top_level = true
	name = "GroundVisuals"
	_shadow = stage.add_ground_sprite(unit.shadow, self, ArenaStage3D.SHADOW_PRIORITY)
	_shadow.name = "Shadow"
	_shadow.visible = unit.shadow.visible
	# 场景里的颜色用于制作预览。开战改用队伍色，沿用贴图和尺寸。
	_shadow_tint = unit.team_ring.ring_color.darkened(0.57)
	unit.shadow.hide()

	_rings = MeshInstance3D.new()
	_rings.name = "Rings"
	_rings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	_rings.mesh = plane
	_material = ShaderMaterial.new()
	_material.shader = RINGS_SHADER
	_material.render_priority = ArenaStage3D.GROUND_MARKER_PRIORITY
	if not unit.is_main_base() and not unit.is_training_dummy():
		_shadow_depth_scale = HERO_SHADOW_DEPTH_SCALE
		_material.set_shader_parameter(&"foot_ring_depth", HERO_RING_DEPTH_SCALE)
	_rings.material_override = _material
	add_child(_rings)

	unit.team_ring.draw_in_3d = true
	unit.selection_ring.draw_in_3d = true
	sync()


func sync() -> void:
	global_position = _stage.ground_to_world(_unit.global_position)
	_stage.sync_ground_sprite(_shadow, _unit.shadow, -0.55)
	_shadow.transform.basis.y *= _shadow_depth_scale
	_shadow.modulate = _unit.shadow.modulate * Color(_shadow_tint, _unit.shadow.self_modulate.a) * _unit.modulate

	var team := _unit.team_ring
	var selection := _unit.selection_ring
	var team_radius := team.radius if team.visible else 0.0
	var selected := _unit.is_selected and _unit.alive
	var selection_radius := selection.radius if selected else 0.0
	var show_ranges := selected and selection.show_combat_ranges
	var attack_radius := selection.attack_range if show_ranges else 0.0
	var skill_radius := selection.skill_range if show_ranges and selection.skill_range > attack_radius + 0.5 else 0.0
	var extent := maxf(maxf(team_radius, selection_radius), maxf(attack_radius, skill_radius)) + 4.0
	_rings.visible = team_radius > 0.0 or selected
	_rings.position = Vector3(0.0, 0.1, -1.0)
	_rings.scale = Vector3(extent, 1.0, extent)
	_material.set_shader_parameter(&"extent", extent)
	_material.set_shader_parameter(&"team_color", team.ring_color)
	_material.set_shader_parameter(&"team_radius", team_radius)
	_material.set_shader_parameter(&"selection_radius", selection_radius)
	_material.set_shader_parameter(&"selection_time", selection.animation_time)
	_material.set_shader_parameter(&"attack_radius", attack_radius)
	_material.set_shader_parameter(&"skill_radius", skill_radius)
