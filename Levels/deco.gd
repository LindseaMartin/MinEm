extends Node2D
## Ambient decoration for the deep levels:
##  "timber"  - old mine supports (Old Workings)
##  "crystal" - glowing crystal clusters that light the cave (Crystal Caverns)
##  "magma"   - glowing cracks in the floor (Deep Dark)

var kind: String = "timber"
var _time: float = 0.0
var _light: PointLight2D


func _ready() -> void:
	z_index = 4
	_time = randf() * 10.0
	if kind == "timber":
		return
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m
	_light = PointLight2D.new()
	_light.texture = Game.light_texture()
	if kind == "crystal":
		_light.color = Color(0.45, 0.75, 1.0)
		_light.texture_scale = 0.9
		_light.energy = 0.8
	else:
		_light.color = Color(1.0, 0.4, 0.15)
		_light.texture_scale = 0.75
		_light.energy = 0.9
	add_child(_light)


func _process(delta: float) -> void:
	if _light == null:
		set_process(false)
		return
	_time += delta
	var speed := 1.5 if kind == "crystal" else 3.5
	_light.energy = (0.8 if kind == "crystal" else 0.9) + 0.15 * sin(_time * speed)
	queue_redraw()


func _draw() -> void:
	match kind:
		"timber":
			var wood := Color(0.42, 0.3, 0.18)
			draw_rect(Rect2(-7, -12, 2, 14), wood)
			draw_rect(Rect2(5, -12, 2, 14), wood)
			draw_rect(Rect2(-8, -13, 16, 2), wood.lightened(0.1))
			draw_line(Vector2(-5, -11), Vector2(5, -3), wood.darkened(0.3), 1.0)
		"crystal":
			var c := Color(0.5, 0.85, 1.0, 0.85 + 0.15 * sin(_time * 1.5))
			for s in [[0, -10, 3, 3, -3, 3], [-5, -6, -2, 3, -7, 3], [5, -7, 7, 3, 2, 3]]:
				draw_colored_polygon(PackedVector2Array([Vector2(s[0], s[1]), Vector2(s[2], s[3]), Vector2(s[4], s[5])]), c)
			draw_line(Vector2(0, -9), Vector2(1, 1), Color(1, 1, 1, 0.7), 1.0)
		"magma":
			var glow := Color(1.0, 0.45 + 0.15 * sin(_time * 3.5), 0.1)
			draw_polyline(PackedVector2Array([Vector2(-8, -2), Vector2(-3, 1), Vector2(1, -1), Vector2(4, 3), Vector2(8, 2)]), glow, 1.5)
			draw_line(Vector2(1, -1), Vector2(3, -5), glow, 1.0)
