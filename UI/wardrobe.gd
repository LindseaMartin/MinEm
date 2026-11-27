extends Control
## Character creator / wardrobe. Edits Game.look and emits `closed`.
## Opened after "New Game" and from the pause menu ("Change look").

signal closed

const Look := preload("res://Characters/look.gd")
const HatScript := preload("res://Characters/hat.gd")
const UiTheme := preload("res://UI/ui_theme.gd")
const PREVIEW_SCALE := 7.0
const WALK_FRAMES := [0, 1, 2, 3]

var first_time: bool = false   # new game: the button says "Start digging"

var _sprite: Sprite2D
var _hat
var _material: ShaderMaterial
var _rows: Dictionary = {}     # part -> HBoxContainer of swatches
var _hat_label: Label
var _hat_hint: Label
var _name_edit: LineEdit
var _frame_time: float = 0.0
var _frame: int = 0
var _done: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	panel.add_child(outer)

	var title := Label.new()
	title.text = "Who's heading into the mine?" if first_time else "Wardrobe"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	title.add_theme_font_size_override("font_size", Settings.title_size())
	outer.add_child(title)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	outer.add_child(columns)

	# Left: live preview on a little stage.
	var stage := Panel.new()
	stage.custom_minimum_size = Vector2(200, 300)
	stage.add_theme_stylebox_override("panel", UiTheme.box(Color(0.05, 0.04, 0.04), UiTheme.PANEL_EDGE, 1, 4))
	columns.add_child(stage)
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://Art/character.png")
	_sprite.hframes = 17
	_sprite.vframes = 8
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(PREVIEW_SCALE, PREVIEW_SCALE)
	_sprite.position = Vector2(100, 150)
	_material = Look.make_material(Game.look)
	_sprite.material = _material
	stage.add_child(_sprite)
	_hat = HatScript.new()
	_hat.hat_id = str(Game.look.get("hat", "helmet"))
	_sprite.add_child(_hat)

	# Right: the choices.
	var choices := VBoxContainer.new()
	choices.add_theme_constant_override("separation", 10)
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(choices)

	var name_row := HBoxContainer.new()
	name_row.add_child(_caption("Name"))
	_name_edit = LineEdit.new()
	_name_edit.text = str(Game.look.get("name", "Prospector"))
	_name_edit.max_length = 16
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(func(t): Game.look["name"] = t)
	name_row.add_child(_name_edit)
	choices.add_child(name_row)

	_add_swatch_row(choices, "hair", "Hair", Look.HAIR)
	_add_swatch_row(choices, "skin", "Skin", Look.SKIN)
	_add_swatch_row(choices, "shirt", "Shirt", Look.SHIRT)
	_add_swatch_row(choices, "pants", "Trousers", Look.PANTS)

	var hat_row := HBoxContainer.new()
	hat_row.add_child(_caption("Hat"))
	var prev := Button.new()
	prev.text = "<"
	prev.pressed.connect(_cycle_hat.bind(-1))
	hat_row.add_child(prev)
	_hat_label = Label.new()
	_hat_label.custom_minimum_size = Vector2(170, 0)
	_hat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hat_row.add_child(_hat_label)
	var next := Button.new()
	next.text = ">"
	next.pressed.connect(_cycle_hat.bind(1))
	hat_row.add_child(next)
	choices.add_child(hat_row)
	_hat_hint = Label.new()
	_hat_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hat_hint.custom_minimum_size = Vector2(480, 0)
	_hat_hint.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	_hat_hint.add_theme_font_size_override("font_size", Settings.small_size())
	choices.add_child(_hat_hint)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	outer.add_child(buttons)
	var random := Button.new()
	random.text = "Randomise"
	random.pressed.connect(_randomise)
	buttons.add_child(random)
	var done := Button.new()
	done.text = "Start digging" if first_time else "Done"
	done.custom_minimum_size = Vector2(180, 0)
	done.pressed.connect(_close)
	buttons.add_child(done)

	_refresh()


func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(90, 0)
	l.add_theme_color_override("font_color", UiTheme.GOLD)
	return l


func _add_swatch_row(parent: Control, part: String, caption: String, colors: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_caption(caption))
	for i in colors.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(30, 30)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_choose.bind(part, i))
		row.add_child(b)
	parent.add_child(row)
	_rows[part] = [row, colors]


func _choose(part: String, index: int) -> void:
	Game.look[part] = index
	Sfx.play("chip", 1.3, -12.0)
	_refresh()


func _unlocked_hats() -> Array:
	var out: Array = []
	for hat in Look.HATS:
		if Look.hat_unlocked(hat):
			out.append(hat)
	return out


func _cycle_hat(step: int) -> void:
	var hats := _unlocked_hats()
	var current := 0
	for i in hats.size():
		if hats[i]["id"] == Game.look.get("hat", "helmet"):
			current = i
	current = posmod(current + step, hats.size())
	Game.look["hat"] = hats[current]["id"]
	Sfx.play("chip", 1.1, -12.0)
	_refresh()


func _randomise() -> void:
	Game.look["hair"] = randi() % Look.HAIR.size()
	Game.look["skin"] = randi() % Look.SKIN.size()
	Game.look["shirt"] = randi() % Look.SHIRT.size()
	Game.look["pants"] = randi() % Look.PANTS.size()
	var hats := _unlocked_hats()
	Game.look["hat"] = hats[randi() % hats.size()]["id"]
	Sfx.play("sparkle", 1.0, -12.0)
	_refresh()


func _refresh() -> void:
	Look.update_material(_material, Game.look)
	_hat.set_hat(str(Game.look.get("hat", "helmet")))
	for part in _rows:
		var row: HBoxContainer = _rows[part][0]
		var colors: Array = _rows[part][1]
		var selected := int(Game.look.get(part, 0))
		# Child 0 is the caption; swatches follow.
		for i in colors.size():
			var b: Button = row.get_child(i + 1)
			var col := Color(str(colors[i]))
			var edge := UiTheme.GOLD if i == selected else Color(0, 0, 0, 0.6)
			var width := 3 if i == selected else 1
			for state in ["normal", "hover", "pressed", "focus"]:
				b.add_theme_stylebox_override(state, UiTheme.box(col if state != "hover" else col.lightened(0.15), edge, width, 4, 0.0, 0.0))
	for hat in Look.HATS:
		if hat["id"] == Game.look.get("hat", "helmet"):
			_hat_label.text = hat["name"]
	var locked: Array = []
	for hat in Look.HATS:
		if not Look.hat_unlocked(hat):
			locked.append("%s (%s)" % [hat["name"], Look.unlock_hint(hat)])
	_hat_hint.text = "" if locked.is_empty() else "Still to unlock: " + ", ".join(PackedStringArray(locked))


func _process(delta: float) -> void:
	_frame_time += delta
	if _frame_time >= 0.18:
		_frame_time = 0.0
		_frame = (_frame + 1) % WALK_FRAMES.size()
		_sprite.frame = WALK_FRAMES[_frame]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not first_time:
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	if _done:
		return
	_done = true
	if str(Game.look.get("name", "")).strip_edges() == "":
		Game.look["name"] = "Prospector"
	Game.save_game()
	Sfx.play("buy")
	closed.emit()
	queue_free()
