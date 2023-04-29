extends Area2D

var is_hidden = true
var item_texture
var hidden_texture

func _ready():
	item_texture = load("res://Art/fossils3.PNG")
	hidden_texture = load("res://Art/cavewall.png")
	$fossil.texture = hidden_texture
	
func _on_HiddenItem_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		reveal()
		
func reveal():
	if is_hidden:
		$fossil.texture = item_texture
		is_hidden = false
