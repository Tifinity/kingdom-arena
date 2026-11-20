extends Node2D

## pixelfx foot-level status loop. The status controller owns the lifetime.
const GROUND_RADIUS := 21.0
const FRAME_COUNT := 48
const FPS := 30.0

@onready var _ground: Sprite2D = $Ground
@onready var _chevrons: Sprite2D = $Chevrons

var _elapsed := 0.0
var _stage: ArenaStage3D
var _ground_3d: Sprite3D


func _ready() -> void:
	var parent := get_parent()
	var unit := parent as Unit if parent is Unit else parent.get_parent() as Unit
	if unit != null:
		scale = Vector2.ONE * ((unit.body_radius + 10.0) / GROUND_RADIUS)
		if unit.battle is Battle:
			_stage = unit.battle.stage
			_ground_3d = _stage.add_ground_sprite(_ground, self, ArenaStage3D.GROUND_MARKER_PRIORITY + 1)
			_ground.hide()
			visibility_changed.connect(_sync_ground)
			_sync_ground()


func _process(delta: float) -> void:
	_elapsed = fposmod(_elapsed + delta, FRAME_COUNT / FPS)
	var index := int(_elapsed * FPS)
	_ground.frame = index
	_chevrons.frame = index
	if _ground_3d != null:
		_sync_ground()


func _sync_ground() -> void:
	_ground_3d.visible = is_visible_in_tree()
	if _ground_3d.visible:
		_stage.sync_ground_sprite(_ground_3d, _ground, 0.2)
