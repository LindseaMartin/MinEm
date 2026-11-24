extends Node2D
## A cave bat (deep levels only). Bats circle their roost, but if you come
## close with a lit lantern they swoop at it and knock some oil loose.
## You can outrun them.

const SWOOP_SPEED := 65.0      # the player walks at 100
const NOTICE_RANGE := 72.0
const GIVE_UP_RANGE := 150.0
const HIT_RANGE := 8.0

var mine   # the Levels/mine.gd node
var home: Vector2
var _state: String = "idle"
var _time: float = 0.0
var _cooldown: float = 0.0
var _flee_dir := Vector2.ZERO


func _ready() -> void:
	z_index = 7
	_time = randf() * 10.0
	position = home
	# Bats are dark shapes, faintly visible even outside the lantern light.
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if mine == null or mine.busy:
		return
	_cooldown -= delta
	var to_player: Vector2 = mine.player.position - position
	var dist := to_player.length()
	match _state:
		"idle":
			var target := home + Vector2(cos(_time * 0.9), sin(_time * 1.7)) * 20.0
			position = position.lerp(target, clampf(delta * 2.0, 0.0, 1.0))
			if _cooldown <= 0.0 and dist < NOTICE_RANGE and Game.oil > 0.0:
				_state = "swoop"
				Sfx.play("flap", randf_range(0.9, 1.2), -14.0)
		"swoop":
			position += to_player.normalized() * SWOOP_SPEED * delta
			if dist < HIT_RANGE:
				mine.bat_hit()
				_state = "flee"
				_cooldown = 6.0
				_flee_dir = -to_player.normalized()
			elif dist > GIVE_UP_RANGE or Game.oil <= 0.0:
				_state = "return"
		"flee":
			position += _flee_dir * 90.0 * delta
			if _cooldown < 4.5:
				_state = "return"
		"return":
			position = position.move_toward(home, 50.0 * delta)
			if position.distance_to(home) < 4.0:
				_state = "idle"


func _draw() -> void:
	var flap := sin(_time * (22.0 if _state == "swoop" else 12.0))
	var body := Color(0.16, 0.12, 0.18, 0.95)
	var tip := Vector2(7.0, -2.0 - 3.0 * flap)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(tip.x * 0.5, -3), tip, Vector2(tip.x * 0.6, 1)]), body)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(-tip.x * 0.5, -3), Vector2(-tip.x, tip.y), Vector2(-tip.x * 0.6, 1)]), body)
	draw_circle(Vector2(0, 0), 2.2, body)
	draw_rect(Rect2(-1.5, -1, 1, 1), Color(1.0, 0.3, 0.25))
	draw_rect(Rect2(0.5, -1, 1, 1), Color(1.0, 0.3, 0.25))
