class_name UnitAttributeBadges
extends Node2D

const STATS: Array[StringName] = [&"attack_damage", &"attack_speed", &"armor", &"move_speed"]
const UP := 1
const DOWN := 2
const CELL_SIZE := Vector2(22, 18)
const ATLAS_FRAME_SIZE := Vector2(88, 54)
const ATLAS_COLUMNS := 3
const FPS := 12.0

@export var sheet: Texture2D

var directions := PackedInt32Array()
var _elapsed := 0.0


func _ready() -> void:
	hide()
	set_process(false)


func set_directions(next: PackedInt32Array) -> void:
	if directions == next:
		return
	directions = next
	visible = directions.count(0) < directions.size()
	set_process(visible)
	queue_redraw()


func _process(delta: float) -> void:
	var previous := int(_elapsed * FPS)
	_elapsed = fposmod(_elapsed + delta, 1.0)
	if previous != int(_elapsed * FPS):
		queue_redraw()


func _draw() -> void:
	var columns := directions.size() - directions.count(0)
	if columns == 0:
		return
	var frame := int(_elapsed * FPS)
	var atlas_origin := Vector2(frame % ATLAS_COLUMNS, int(frame / ATLAS_COLUMNS)) * ATLAS_FRAME_SIZE
	var x := -columns * CELL_SIZE.x * 0.5
	for stat in directions.size():
		var flags := directions[stat]
		if flags == 0:
			continue
		var cell := atlas_origin + Vector2(stat, flags - 1) * CELL_SIZE
		draw_texture_rect_region(sheet, Rect2(Vector2(x, 0), CELL_SIZE), Rect2(cell, CELL_SIZE))
		x += CELL_SIZE.x
