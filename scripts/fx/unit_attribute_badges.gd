class_name UnitAttributeBadges
extends Node2D

const STATS: Array[StringName] = [&"attack_damage", &"attack_speed", &"armor", &"move_speed"]
const UP := 1
const DOWN := 2
const SHEET := preload("res://assets/status/pixel_status.png")
const CELL := 8
const SIZE := 24.0
const STEP := 28.0
const BUFF_TILES := [0, 2, 4, 6]
const DEBUFF_TILES := [1, 3, 5, 7]
const RISE := Color("#b8e0a5")
const FALL := Color("#f18d83")

var directions := PackedInt32Array()


func _ready() -> void:
	hide()


func set_directions(next: PackedInt32Array) -> void:
	if directions == next:
		return
	directions = next
	visible = directions.count(0) < directions.size()
	queue_redraw()


func _draw() -> void:
	var columns := directions.size() - directions.count(0)
	var x := -columns * STEP * 0.5 + (STEP - SIZE) * 0.5
	for stat in directions.size():
		var flags := directions[stat]
		if flags == 0:
			continue
		var buff := (flags & UP) != 0
		var debuff := (flags & DOWN) != 0
		var tile: int = BUFF_TILES[stat] if buff else DEBUFF_TILES[stat]
		draw_texture_rect_region(SHEET, Rect2(x, 0, SIZE, SIZE), Rect2(tile * CELL, 0, CELL, CELL), Color.WHITE, false, true)
		if buff:
			draw_rect(Rect2(x + 16, 24, 8, 4), RISE)
		if debuff:
			draw_rect(Rect2(x, 24, 8, 4), FALL)
		x += STEP
