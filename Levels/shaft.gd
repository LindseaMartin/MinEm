extends Node2D
## A way between depths: a dark shaft with a ladder going down, or a
## ladder climbing back up towards a faint light from above.

var up: bool = false
var lift: bool = false   # this way up is the lift back to camp
var _time: float = 0.0


func _ready() -> void:
	z_index = 6
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m
	if up:
		# A little daylight-ish glow spills down the ladder.
		var glow := PointLight2D.new()
		glow.texture = Game.light_texture()
		glow.texture_scale = 0.7
		glow.color = Color(0.75, 0.8, 1.0)
		glow.energy = 0.6
		add_child(glow)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var wood := Color(0.55, 0.38, 0.2)
	if up:
		draw_line(Vector2(-4, 8), Vector2(-4, -12), wood, 1.5)
		draw_line(Vector2(4, 8), Vector2(4, -12), wood, 1.5)
		for i in 5:
			var y := 6.0 - i * 4.0
			draw_line(Vector2(-4, y), Vector2(4, y), wood.lightened(0.15), 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-12, -15), "LIFT" if lift else "UP", HORIZONTAL_ALIGNMENT_CENTER, 24, 6,
			Color(0.85, 0.9, 1.0, 0.6 + 0.3 * sin(_time * 3.0)))
	else:
		draw_circle(Vector2.ZERO, 9.0, Color(0.25, 0.18, 0.12))
		draw_circle(Vector2.ZERO, 7.5, Color(0.02, 0.01, 0.02))
		draw_line(Vector2(-3, -7), Vector2(-3, 4), wood, 1.5)
		draw_line(Vector2(3, -7), Vector2(3, 4), wood, 1.5)
		for i in 3:
			var y := -5.0 + i * 4.0
			draw_line(Vector2(-3, y), Vector2(3, y), wood.darkened(0.2 + i * 0.25), 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-12, -12), "DOWN", HORIZONTAL_ALIGNMENT_CENTER, 24, 6,
			Color(1.0, 0.85, 0.6, 0.6 + 0.3 * sin(_time * 3.0)))
