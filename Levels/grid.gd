extends Node2D

func _ready():
	pass

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		for item in $GridContainer.get_children():
			if item != null:
				var item_global_transform = item.global_transform
				var sprite_node = item.get_node_or_null("fossil")
				if sprite_node != null:
					var texture_size = sprite_node.texture.get_size()
					var sprite_transform = sprite_node.transform
					if sprite_transform != null:
						var scale = Vector2(sprite_transform.x.length(), sprite_transform.y.length())
						var rect = Rect2(Vector2.ZERO, texture_size * scale)
						rect.position -= sprite_transform.get_origin()
						rect.size += sprite_transform.get_origin() * 2
						
						var p1 = item_global_transform.xform(rect.position)
						var p2 = item_global_transform.xform(rect.position + Vector2(rect.size.x, 0))
						var p3 = item_global_transform.xform(rect.position + rect.size)
						var p4 = item_global_transform.xform(rect.position + Vector2(0, rect.size.y))
						
						var new_rect = Rect2(p1, Vector2.ZERO)
						new_rect = new_rect.expand(p2).expand(p3).expand(p4)
						
						if new_rect.has_point(event.position):
							item._on_HiddenItem_input_event(get_viewport(), event, 0)
							break
					else:
						print("sprite_transform is null: ", sprite_node)
				else:
					print("sprite_node is null: ", item)
