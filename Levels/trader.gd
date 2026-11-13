extends Node2D
## The trader's little camp, drawn with code (swap for a sprite any time).


func _ready() -> void:
	z_index = 6


func _draw() -> void:
	# Tent
	draw_colored_polygon(PackedVector2Array([Vector2(-11, 6), Vector2(0, -10), Vector2(11, 6)]), Color(0.75, 0.25, 0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(-4, 6), Vector2(0, -10), Vector2(4, 6)]), Color(0.93, 0.86, 0.7))
	draw_colored_polygon(PackedVector2Array([Vector2(-2, 6), Vector2(0, -1), Vector2(2, 6)]), Color(0.15, 0.1, 0.1))
	draw_line(Vector2(0, -10), Vector2(0, -14), Color(0.35, 0.25, 0.15), 1.0)
	draw_rect(Rect2(0, -14, 4, 3), Color(0.95, 0.8, 0.2))
	# Crate with a coin on it
	draw_rect(Rect2(9, 0, 7, 6), Color(0.5, 0.35, 0.2))
	draw_rect(Rect2(9, 0, 7, 6), Color(0.3, 0.2, 0.1), false, 1.0)
	draw_circle(Vector2(12.5, -1.5), 2.0, Color(0.95, 0.8, 0.2))
