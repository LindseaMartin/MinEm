extends Label
## A short piece of text that drifts up and fades out ("+$40", "Damaged!").
## Set `position` to where it should appear (its centre) and `color`, then
## add it as a child.

const WIDTH := 280.0

var color: Color = Color(1, 1, 1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	size = Vector2(WIDTH, 20)
	position -= Vector2(WIDTH * 0.5, 10)
	add_theme_color_override("font_color", color)
	add_theme_color_override("font_outline_color", Color(0, 0, 0))
	add_theme_constant_override("outline_size", 3)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y - 32.0, 1.1)
	tw.tween_property(self, "modulate:a", 0.0, 0.7).set_delay(0.4)
	tw.chain().tween_callback(queue_free)
