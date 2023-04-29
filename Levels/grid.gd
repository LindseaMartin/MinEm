extends Node2D

func _ready():
	pass

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		for item in $GridContainer.get_children():
			if item != null:
				item._on_HiddenItem_input_event(get_viewport(), event, 0)
