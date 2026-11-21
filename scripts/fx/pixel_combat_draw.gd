class_name PixelCombatDraw
extends RefCounted

const CELL := Vector2(4.0, 4.0)


static func dot(canvas: CanvasItem, at: Vector2, color: Color) -> void:
	canvas.draw_rect(Rect2(at.snapped(CELL) - CELL * 0.5, CELL), color)


static func streak(canvas: CanvasItem, start: Vector2, end: Vector2, color: Color) -> void:
	var steps := maxi(1, ceili(start.distance_to(end) / CELL.x))
	var previous := Vector2.INF
	for index in range(steps + 1):
		var cell := start.lerp(end, float(index) / float(steps)).snapped(CELL)
		if cell != previous:
			dot(canvas, cell, color)
			previous = cell
