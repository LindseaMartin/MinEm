extends Control
## Full-screen dig minigame: the wall on the left, tools and status on the
## right. Emits `finished` with the treasures the player gets to keep.

signal finished(found)

const WallScript := preload("res://Dig/dig_wall.gd")
const IconScript := preload("res://UI/treasure_icon.gd")
const TIER_NAMES := ["Shallow seam", "Rich seam", "Ancient deposit"]
const TOOL_INFO := {
	"pick": "Pick: chips 1 layer off one cell. Slow but safe.",
	"hammer": "Hammer: wide blow, centre goes 2 deep. Can smash finds!",
	"scan": "Detector: click the wall to scan a patch for treasure.",
	"dynamite": "Dynamite: blows a 3x3 hole. Damages anything buried there.",
}

var tier: int = 1
var bonus_cash: int = 0   # reward for clearing the wall, paid on leaving
var prop_button: Button
var wall
var stability_bar: ProgressBar
var stability_label: Label
var tool_buttons: Dictionary = {}
var info_label: Label
var found_box: VBoxContainer
var message_label: Label
var leave_button: Button


func setup(site_tier: int) -> void:
	tier = clampi(site_tier, 1, 3)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.07, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "%s  -  chip carefully, the wall won't hold forever" % TIER_NAMES[tier - 1]
	title.position = Vector2(8, 8)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	add_child(title)

	wall = WallScript.new()
	wall.position = Vector2(8, 28)
	add_child(wall)
	wall.generate(tier)
	wall.changed.connect(_refresh)
	wall.treasure_found.connect(_on_found)
	wall.treasure_damaged.connect(_on_damaged)
	wall.collapsed.connect(_on_collapsed)
	wall.cleared.connect(_on_cleared)
	wall.notice.connect(_say)

	message_label = Label.new()
	message_label.position = Vector2(8, 230)
	message_label.size = Vector2(286, 36)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.text = "Uncover a treasure completely to claim it."
	add_child(message_label)

	var side := VBoxContainer.new()
	side.position = Vector2(304, 28)
	side.size = Vector2(168, 236)
	side.add_theme_constant_override("separation", 3)
	add_child(side)

	stability_label = Label.new()
	side.add_child(stability_label)
	stability_bar = ProgressBar.new()
	stability_bar.show_percentage = false
	stability_bar.custom_minimum_size = Vector2(0, 8)
	stability_bar.max_value = wall.stability_max
	side.add_child(stability_bar)

	var tools := HBoxContainer.new()
	side.add_child(tools)
	var group := ButtonGroup.new()
	for id in ["pick", "hammer", "scan"]:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select_tool.bind(id))
		tools.add_child(b)
		tool_buttons[id] = b

	var extras := HBoxContainer.new()
	side.add_child(extras)
	prop_button = Button.new()
	prop_button.focus_mode = Control.FOCUS_NONE
	prop_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prop_button.pressed.connect(wall.shore_up)
	extras.add_child(prop_button)
	var boom := Button.new()
	boom.toggle_mode = true
	boom.button_group = group
	boom.focus_mode = Control.FOCUS_NONE
	boom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boom.pressed.connect(_select_tool.bind("dynamite"))
	extras.add_child(boom)
	tool_buttons["dynamite"] = boom

	info_label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(160, 34)
	info_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	side.add_child(info_label)

	var found_title := Label.new()
	found_title.text = "Claimed:"
	side.add_child(found_title)
	var found_scroll := ScrollContainer.new()
	found_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(found_scroll)
	found_box = VBoxContainer.new()
	found_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	found_box.add_theme_constant_override("separation", 1)
	found_scroll.add_child(found_box)

	leave_button = Button.new()
	leave_button.text = "Pack up and leave"
	leave_button.focus_mode = Control.FOCUS_NONE
	leave_button.pressed.connect(_leave)
	side.add_child(leave_button)

	_select_tool("pick")
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				_select_tool("pick")
			KEY_2:
				_select_tool("hammer")
			KEY_3:
				_select_tool("scan")
			KEY_4:
				wall.shore_up()
			KEY_5:
				_select_tool("dynamite")


func _select_tool(id: String) -> void:
	wall.tool_name = id
	tool_buttons[id].button_pressed = true
	info_label.text = TOOL_INFO[id]
	wall.queue_redraw()


func _refresh() -> void:
	stability_bar.value = wall.stability
	stability_label.text = "Wall stability: %d / %d" % [int(ceil(wall.stability)), int(wall.stability_max)]
	var ratio: float = wall.stability / wall.stability_max
	stability_bar.modulate = Color(1, 1, 1) if ratio > 0.35 else Color(1.0, 0.45, 0.4)
	tool_buttons["pick"].text = "1 Pick"
	tool_buttons["hammer"].text = "2 Hammer"
	tool_buttons["scan"].text = "3 Scan x%d" % wall.scans_left
	prop_button.text = "4 Prop x%d" % Game.supply_count("prop")
	prop_button.disabled = Game.supply_count("prop") <= 0 or not wall.active
	tool_buttons["dynamite"].text = "5 Dynamite x%d" % Game.supply_count("dynamite")
	tool_buttons["dynamite"].disabled = Game.supply_count("dynamite") <= 0
	if wall.tool_name == "dynamite" and Game.supply_count("dynamite") <= 0:
		_select_tool("pick")


func _say(text: String) -> void:
	message_label.text = text


func _on_found(t: Dictionary) -> void:
	var row := HBoxContainer.new()
	var icon = IconScript.new()
	icon.treasure_id = t["id"]
	icon.custom_minimum_size = Vector2(14, 14)
	row.add_child(icon)
	var label := Label.new()
	label.text = Game.item_label(t)
	row.add_child(label)
	found_box.add_child(row)
	_say("You freed a %s!" % Game.TREASURES[t["id"]]["name"])


func _on_damaged(t: Dictionary) -> void:
	_say("Careful! You damaged something - it is now %s." % str(Game.CONDITIONS[t["cond"]]["name"]).to_lower())


func _on_collapsed() -> void:
	_say("The wall collapsed! You keep only what you fully uncovered.")
	leave_button.text = "Climb out"


func _on_cleared() -> void:
	var flawless := true
	for t in wall.treasures:
		if int(t["cond"]) > 0:
			flawless = false
	bonus_cash = 20 * tier * (2 if flawless else 1)
	if flawless:
		_say("Flawless dig! Everything recovered in pristine condition. Bonus $%d." % bonus_cash)
	else:
		_say("Wall cleared - you found everything buried here! Bonus $%d." % bonus_cash)
	Sfx.play("fanfare")
	leave_button.text = "Collect and leave"


func _leave() -> void:
	leave_button.disabled = true
	wall.active = false
	finished.emit(wall.found_items())
