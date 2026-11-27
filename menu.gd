extends Control
## Title screen: continue a saved game, start over, toggle sound or quit.

const IconScript := preload("res://UI/treasure_icon.gd")
const PauseScript := preload("res://UI/pause_menu.gd")
const MINE_SCENE := "res://Levels/level_0.tscn"

var new_button: Button
var _confirm_new: bool = false


func _ready() -> void:
	Sfx.start_ambience(0)
	var bg := TextureRect.new()
	bg.texture = load("res://Art/cavewall.png")
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.35, 0.3, 0.32)
	add_child(bg)

	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 12)
	add_child(center)

	var title := Label.new()
	title.text = "MinEm"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.98, 0.85, 0.45))
	title.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.05))
	title.add_theme_constant_override("outline_size", 10)
	center.add_child(title)

	var tagline := Label.new()
	tagline.text = "Chip carefully. Dig deep. Get rich."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_color_override("font_color", Color(0.85, 0.8, 0.75))
	center.add_child(tagline)

	# A row of treasures you could find.
	var gems := HBoxContainer.new()
	gems.alignment = BoxContainer.ALIGNMENT_CENTER
	gems.add_theme_constant_override("separation", 14)
	for id in ["gold", "emerald", "raptor", "ruby", "diamond"]:
		var icon = IconScript.new()
		icon.treasure_id = id
		icon.custom_minimum_size = Vector2(56, 44)
		gems.add_child(icon)
	center.add_child(gems)

	var buttons := VBoxContainer.new()
	buttons.custom_minimum_size = Vector2(300, 0)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buttons.add_theme_constant_override("separation", 8)
	center.add_child(buttons)

	if Game.has_save():
		var cont := Button.new()
		cont.text = "Continue  (day %d, $%d)" % [Game.day, Game.money]
		cont.pressed.connect(_continue)
		buttons.add_child(cont)

	new_button = Button.new()
	new_button.text = "New Game"
	new_button.pressed.connect(_new_game)
	buttons.add_child(new_button)

	var settings := Button.new()
	settings.text = "Settings"
	settings.pressed.connect(_open_settings)
	buttons.add_child(settings)

	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func(): get_tree().quit())
	buttons.add_child(quit)

	buttons.get_child(0).grab_focus()

	var help := Label.new()
	help.text = "WASD move  -  E interact  -  Tab map  -  F oil flask  -  1-5 dig tools  -  M mute  -  Esc pause"
	help.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	help.grow_horizontal = Control.GROW_DIRECTION_BOTH
	help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	help.offset_bottom = -16
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color(0.65, 0.6, 0.6))
	add_child(help)


func _continue() -> void:
	Sfx.play("buy")
	get_tree().change_scene_to_file(MINE_SCENE)


func _new_game() -> void:
	# Starting over wipes an existing save, so ask twice.
	if Game.has_save() and not _confirm_new:
		_confirm_new = true
		new_button.text = "Erase save and start over?"
		Sfx.play("deny")
		return
	Game.new_game()
	Sfx.play("buy")
	get_tree().change_scene_to_file(MINE_SCENE)


func _open_settings() -> void:
	var pause = PauseScript.new()
	pause.in_game = false
	add_child(pause)
