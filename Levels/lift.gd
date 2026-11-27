extends Node2D
## The old mine lift next to the camp. Broken until the trader fixes it
## (the Mine Lift upgrade), then it runs down to the depths you've unlocked.

var _time: float = 0.0


func _ready() -> void:
	z_index = 6


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var wood := Color(0.5, 0.35, 0.18)
	var iron := Color(0.45, 0.45, 0.5)
	var working := Game.lift_depth() > 0
	# Frame and pulley
	draw_line(Vector2(-8, 8), Vector2(-8, -16), wood, 2.0)
	draw_line(Vector2(8, 8), Vector2(8, -16), wood, 2.0)
	draw_line(Vector2(-10, -16), Vector2(10, -16), wood.lightened(0.1), 2.0)
	draw_circle(Vector2(0, -16), 2.5, iron)
	# Cage (bobs gently when working)
	var y := -1.0 * sin(_time * 2.0) if working else 0.0
	draw_line(Vector2(0, -14), Vector2(0, -7 + y), Color(0.7, 0.6, 0.4), 1.0)
	draw_rect(Rect2(-6, -7 + y, 12, 14), iron, false, 1.0)
	for x in [-3, 0, 3]:
		draw_line(Vector2(x, -7 + y), Vector2(x, 7 + y), iron.darkened(0.3), 1.0)
	if not working:
		draw_line(Vector2(-7, -8), Vector2(7, 8), Color(0.8, 0.2, 0.15), 1.5)
	draw_string(ThemeDB.fallback_font, Vector2(-12, -19), "LIFT", HORIZONTAL_ALIGNMENT_CENTER, 24, 5,
		Color(0.9, 0.85, 0.6) if working else Color(0.6, 0.5, 0.5))
