extends Control
## The canary in its cage, shown in the dig screen once bought. Hops and
## flaps when `nervous` (your tool is near hidden gas).

var nervous: bool = false
var _time: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(20, 20)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var brass := Color(0.75, 0.62, 0.3)
	# Cage
	draw_arc(Vector2(10, 10), 9.0, PI, TAU, 14, brass, 1.0)
	for x in [2, 6, 10, 14, 18]:
		var top := 10.0 - sqrt(maxf(81.0 - pow(x - 10.0, 2.0), 0.0))
		draw_line(Vector2(x, top), Vector2(x, 19), brass.darkened(0.2), 1.0)
	draw_line(Vector2(1, 19), Vector2(19, 19), brass, 1.5)
	draw_line(Vector2(4, 15), Vector2(16, 15), Color(0.45, 0.3, 0.15), 1.0)  # perch
	# Bird
	var hop := absf(sin(_time * 16.0)) * 3.0 if nervous else 0.0
	var yellow := Color(1.0, 0.85, 0.2)
	var body := Vector2(9, 12 - hop)
	draw_circle(body, 3.2, yellow)
	draw_circle(body + Vector2(2.6, -2.6), 2.0, yellow)
	draw_colored_polygon(PackedVector2Array([body + Vector2(4.4, -2.9), body + Vector2(6.2, -2.4), body + Vector2(4.4, -1.8)]), Color(1.0, 0.55, 0.1))
	draw_rect(Rect2(body + Vector2(3, -3.2), Vector2(1, 1)), Color(0, 0, 0))
	var wing := -2.0 * absf(sin(_time * 30.0)) if nervous else 0.0
	draw_colored_polygon(PackedVector2Array([body + Vector2(-2, -1), body + Vector2(1, -1 + wing), body + Vector2(1, 1)]), yellow.darkened(0.25))
	if nervous:
		draw_string(get_theme_default_font(), Vector2(15, 6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.3, 0.25))
