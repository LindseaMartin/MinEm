extends Node2D
## A hat drawn on top of the player sprite (16x32 frames, centred).
## Position (0, 0) is the sprite centre; the top of the hair is about y = -11.

var hat_id: String = "helmet"
var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	var f = get_parent().get("facing")
	if f != null:
		scale.x = -1.0 if float(f) < 0.0 else 1.0
	if hat_id == "crown" or hat_id == "helmet":
		queue_redraw()


func set_hat(id: String) -> void:
	hat_id = id
	queue_redraw()


func _draw() -> void:
	match hat_id:
		"helmet":
			var yellow := Color(0.95, 0.75, 0.15)
			draw_colored_polygon(PackedVector2Array([Vector2(-6, -8), Vector2(-5, -12), Vector2(-2, -14), Vector2(2, -14), Vector2(5, -12), Vector2(6, -8)]), yellow)
			draw_rect(Rect2(-7, -9, 14, 2), yellow.darkened(0.25))
			draw_rect(Rect2(-1.5, -13, 3, 3), Color(0.25, 0.25, 0.28))
			draw_rect(Rect2(-1, -12.5, 2, 2), Color(1.0, 0.95, 0.6, 0.8 + 0.2 * sin(_time * 6.0)))
		"cap":
			var cloth := Color(0.4, 0.36, 0.3)
			draw_colored_polygon(PackedVector2Array([Vector2(-6, -9), Vector2(-5, -13), Vector2(4, -13), Vector2(6, -10), Vector2(8, -9)]), cloth)
			draw_line(Vector2(-6, -9), Vector2(8, -9), cloth.darkened(0.35), 1.0)
		"bandana":
			var red := Color(0.8, 0.2, 0.2)
			draw_colored_polygon(PackedVector2Array([Vector2(-6, -9), Vector2(-5, -13), Vector2(5, -13), Vector2(6, -9)]), red)
			draw_colored_polygon(PackedVector2Array([Vector2(5, -10), Vector2(9, -8), Vector2(8, -6)]), red.darkened(0.2))
			draw_rect(Rect2(-3, -12, 1, 1), Color(1, 1, 1, 0.8))
			draw_rect(Rect2(2, -11, 1, 1), Color(1, 1, 1, 0.8))
		"flower":
			var c := Vector2(4, -12)
			for i in 5:
				draw_circle(c + Vector2.from_angle(i * TAU / 5.0) * 2.0, 1.4, Color(1.0, 0.55, 0.75))
			draw_circle(c, 1.2, Color(1.0, 0.85, 0.2))
		"tophat":
			var black := Color(0.12, 0.11, 0.13)
			draw_rect(Rect2(-7, -10, 14, 2), black)
			draw_rect(Rect2(-4.5, -19, 9, 9), black)
			draw_rect(Rect2(-4.5, -12, 9, 2), Color(0.6, 0.15, 0.2))
		"skull":
			var bone := Color(0.88, 0.83, 0.72)
			draw_colored_polygon(PackedVector2Array([Vector2(-6, -8), Vector2(-6, -12), Vector2(-3, -15), Vector2(3, -15), Vector2(6, -12), Vector2(6, -8)]), bone)
			draw_rect(Rect2(-4, -12, 2, 2), Color(0.2, 0.15, 0.12))
			draw_rect(Rect2(2, -12, 2, 2), Color(0.2, 0.15, 0.12))
			draw_line(Vector2(-6, -8), Vector2(-8, -5), bone.darkened(0.2), 1.0)
			draw_line(Vector2(6, -8), Vector2(8, -5), bone.darkened(0.2), 1.0)
		"crown":
			var gold := Color(0.95, 0.8, 0.3)
			draw_colored_polygon(PackedVector2Array([Vector2(-5, -9), Vector2(-5, -14), Vector2(-3, -11), Vector2(0, -15), Vector2(3, -11), Vector2(5, -14), Vector2(5, -9)]), gold)
			var glow := 0.75 + 0.25 * sin(_time * 4.0)
			draw_rect(Rect2(-0.5, -12, 1.5, 1.5), Color(0.4, 0.85, 1.0, glow))
			draw_rect(Rect2(-4, -11, 1, 1), Color(1.0, 0.3, 0.4, glow))
			draw_rect(Rect2(3.5, -11, 1, 1), Color(0.5, 1.0, 0.6, glow))
