extends Node2D
## The trader's little camp, drawn with code (swap for a sprite any time).
## Its campfire is the one safe, lit place in the mine.

var _light: PointLight2D
var _time: float = 0.0


func _ready() -> void:
	z_index = 6
	_light = PointLight2D.new()
	_light.texture = Game.light_texture()
	_light.texture_scale = 1.3
	_light.color = Color(1.0, 0.7, 0.4)
	_light.energy = 1.1
	_light.position = Vector2(-14, 4)
	add_child(_light)


func _process(delta: float) -> void:
	_time += delta
	_light.energy = 1.0 + 0.12 * sin(_time * 11.0) + 0.08 * sin(_time * 23.0)
	queue_redraw()


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
	# Campfire
	var fire := Vector2(-14, 6)
	draw_line(fire + Vector2(-4, 1), fire + Vector2(4, -1), Color(0.35, 0.22, 0.12), 2.0)
	draw_line(fire + Vector2(-4, -1), fire + Vector2(4, 1), Color(0.3, 0.18, 0.1), 2.0)
	var h := 6.0 + 1.5 * sin(_time * 13.0)
	draw_colored_polygon(PackedVector2Array([fire + Vector2(-3, 0), fire + Vector2(0, -h), fire + Vector2(3, 0)]), Color(1.0, 0.45, 0.1))
	draw_colored_polygon(PackedVector2Array([fire + Vector2(-1.5, 0), fire + Vector2(0, -h * 0.55), fire + Vector2(1.5, 0)]), Color(1.0, 0.9, 0.4))
