extends Node2D
## An abandoned supply crate left by the old miners. Opening it gives a
## random supply, some oil or a few coins. Restocks every day.

var key: String = ""   # entry in Game.dug_sites once opened today
var opened: bool = false


func _ready() -> void:
	z_index = 6


## Takes what's inside. Returns a description of the loot.
func open() -> String:
	opened = true
	Game.dug_sites[key] = true
	queue_redraw()
	var roll := randf()
	var coins := 10 + randi() % 31
	if roll < 0.35 and Game.supply_count("prop") < Game.SUPPLY_MAX:
		Game.supplies["prop"] = Game.supply_count("prop") + 1
		Game.changed.emit()
		return "a Timber Prop"
	if roll < 0.55 and Game.supply_count("dynamite") < Game.SUPPLY_MAX:
		Game.supplies["dynamite"] = Game.supply_count("dynamite") + 1
		Game.changed.emit()
		return "a stick of Dynamite"
	if roll < 0.8 and Game.oil < Game.oil_max() - 1.0:
		Game.oil = minf(Game.oil + 40.0, Game.oil_max())
		Game.changed.emit()
		return "a can of lamp oil (+40 oil)"
	Game.money += coins
	Game.changed.emit()
	return "$%d in old coins" % coins


func _draw() -> void:
	var wood := Color(0.5, 0.34, 0.18)
	draw_rect(Rect2(-7, -4, 14, 10), wood)
	draw_rect(Rect2(-7, -4, 14, 10), wood.darkened(0.45), false, 1.0)
	draw_line(Vector2(-7, 1), Vector2(7, 1), wood.darkened(0.35), 1.0)
	if opened:
		draw_colored_polygon(PackedVector2Array([Vector2(-7, -4), Vector2(7, -4), Vector2(9, -9), Vector2(-5, -9)]), wood.lightened(0.1))
		draw_rect(Rect2(-5, -3, 10, 3), Color(0.08, 0.05, 0.03))
	else:
		draw_rect(Rect2(-7, -6, 14, 3), wood.lightened(0.15))
		draw_rect(Rect2(-1, -5, 2, 3), Color(0.8, 0.7, 0.3))
