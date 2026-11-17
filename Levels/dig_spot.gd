extends Node2D
## A glint in the mine wall that can be dug up. Hidden until the player
## gets close enough to spot it.

var tier: int = 1
var stand_cell: Vector2i      # floor cell the player digs from
var revealed: bool = false
var show_tier: bool = false   # detector level 2+ colours the glint by richness
var _time: float = 0.0


func _ready() -> void:
	z_index = 6
	_time = randf() * 6.0
	# Glints sparkle even in the dark, outside the lantern's glow.
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m


func _process(delta: float) -> void:
	if revealed:
		_time += delta
		queue_redraw()


func reveal() -> void:
	if not revealed:
		revealed = true
		queue_redraw()


func _draw() -> void:
	if not revealed:
		return
	var col := Color(1, 1, 0.85)
	if show_tier:
		col = [Color(1, 1, 0.85), Color(1.0, 0.8, 0.3), Color(0.5, 0.95, 1.0)][tier - 1]
	var pulse := 0.6 + 0.4 * sin(_time * 4.0)
	_star(Vector2(-2, -1), 4.5 * pulse, col)
	_star(Vector2(4, 3), 2.5 * (1.3 - pulse), col)
	_star(Vector2(-4, 4), 2.0 * pulse, col)


func _star(c: Vector2, s: float, col: Color) -> void:
	if s < 0.5:
		return
	var k := s * 0.28
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -s), c + Vector2(k, -k), c + Vector2(s, 0), c + Vector2(k, k),
		c + Vector2(0, s), c + Vector2(-k, k), c + Vector2(-s, 0), c + Vector2(-k, -k)]), col)
