class_name GroundPoundFx
extends Node2D

## pixelfx moves/ground-pound-perspective. Floor art is circular in world space.
const SHEET_RADIUS := 78.0
const FRAME_COUNT := 55
const FPS := 30.0

var _elapsed := 0.0
var _projected_ground: Sprite3D

@onready var _ground: Sprite2D = $Ground
@onready var _air: Sprite3D = $Air


func setup_from_effect(source: Unit, effect: ActionEffectDefinition) -> void:
	var cast := source.current_cast
	global_position = cast.point if cast != null and cast.has_point and not effect.center_on_self else source.global_position
	var size_ratio := effect.radius / SHEET_RADIUS
	scale = Vector2.ONE * size_ratio

	var stage: ArenaStage3D = source.battle.stage
	_projected_ground = stage.add_ground_sprite(_ground, self, ArenaStage3D.GROUND_MARKER_PRIORITY + 2)
	_projected_ground.name = "ProjectedGround"
	stage.sync_ground_sprite(_projected_ground, _ground, 0.25)
	_ground.hide()
	_air.pixel_size = size_ratio
	_air.global_transform = Transform3D(stage.camera.basis, stage.ground_to_world(global_position, 0.25))


func _process(delta: float) -> void:
	_elapsed += delta
	var index := int(_elapsed * FPS)
	if index >= FRAME_COUNT:
		queue_free()
		return
	if _projected_ground != null:
		_projected_ground.frame = index
	_air.frame = index
