extends Control

class_name Transitioner

@export var scene_switch_anim : String = "fade_out"
@export var scene_to_load : PackedScene

@onready var animation_tex : TextureRect = $TextureRect
@onready var animation_player : AnimationPlayer = $AnimationPlayer

func _ready():
	animation_tex.visible = false

func set_next_animation(fading_out : bool):
	if(fading_out):
		animation_player.queue("fade_out")
	else:
		animation_player.queue("fade_in")

## Close the iris over the screen. Use with `await`.
func cover(speed : float = 2.5) -> void:
	animation_player.play("fade_out", -1, speed)
	await animation_player.animation_finished

## Open the iris again. Use with `await`.
func uncover(speed : float = 2.5) -> void:
	animation_player.play("fade_in", -1, speed)
	await animation_player.animation_finished

func _on_animation_player_animation_finished(anim_name):
	if (scene_to_load != null && anim_name == scene_switch_anim):
		get_tree().change_scene_to_packed(scene_to_load)
