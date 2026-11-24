extends Control
## Small picture of a treasure. Set `known = false` for a dark silhouette.

var treasure_id: String = ""
var known: bool = true
var shine: bool = false   # gleaming variant: draw sparkles on top


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not known:
		self_modulate = Color(0, 0, 0, 0.55)


func _draw() -> void:
	if treasure_id == "":
		return
	var def: Dictionary = Game.TREASURES[treasure_id]
	var cell := minf(size.x / float(def["w"]), size.y / float(def["h"]))
	var sz := Vector2(float(def["w"]), float(def["h"])) * cell
	Game.draw_treasure(self, treasure_id, Rect2((size - sz) * 0.5, sz))
	if shine:
		Game.draw_gleam(self, Rect2((size - sz) * 0.5, sz))
