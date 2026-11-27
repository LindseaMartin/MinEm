extends RefCounted
## The game's UI look: dark panels with a brass border, wooden buttons and
## warm text, built in code so no art is needed. Settings.apply() installs it
## on the root window, so every Control in the game picks it up.
## Swap these styleboxes for textures (StyleBoxTexture) once UI art exists.

const TEXT := Color(0.93, 0.89, 0.82)
const TEXT_DIM := Color(0.68, 0.66, 0.66)
const GOLD := Color(0.98, 0.84, 0.45)
const GOOD := Color(0.6, 1.0, 0.72)
const BAD := Color(1.0, 0.5, 0.42)
const INFO := Color(0.66, 0.86, 1.0)

const PANEL_BG := Color(0.09, 0.075, 0.07, 0.97)
const PANEL_EDGE := Color(0.58, 0.44, 0.24)
const WOOD := Color(0.26, 0.19, 0.13)
const WOOD_HOVER := Color(0.36, 0.27, 0.17)
const WOOD_PRESSED := Color(0.47, 0.34, 0.18)


static func box(bg: Color, edge: Color, border: int = 2, radius: int = 4, pad_x: float = 10.0, pad_y: float = 8.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s


## Translucent box for HUD read-outs and pop-up messages.
static func hud_box() -> StyleBoxFlat:
	return box(Color(0.05, 0.04, 0.04, 0.72), Color(0.58, 0.44, 0.24, 0.6), 1, 4, 10.0, 5.0)


static func build(font_size: int) -> Theme:
	var t := Theme.new()
	t.default_font_size = font_size

	var panel := box(PANEL_BG, PANEL_EDGE, 2, 5, 14.0, 12.0)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	# Buttons
	var pad_x := 10.0
	var pad_y := 5.0
	t.set_stylebox("normal", "Button", box(WOOD, Color(0.5, 0.37, 0.2), 1, 3, pad_x, pad_y))
	t.set_stylebox("hover", "Button", box(WOOD_HOVER, Color(0.72, 0.55, 0.28), 1, 3, pad_x, pad_y))
	t.set_stylebox("pressed", "Button", box(WOOD_PRESSED, GOLD, 2, 3, pad_x, pad_y))
	t.set_stylebox("hover_pressed", "Button", box(WOOD_PRESSED, GOLD, 2, 3, pad_x, pad_y))
	t.set_stylebox("disabled", "Button", box(Color(0.14, 0.12, 0.11), Color(0.3, 0.26, 0.22), 1, 3, pad_x, pad_y))
	var focus := box(Color(0, 0, 0, 0), GOLD, 1, 3, pad_x, pad_y)
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1.0, 0.95, 0.78))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_hover_pressed_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(0.46, 0.43, 0.4))

	# Text
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", Color(1.0, 0.95, 0.78))
	t.set_color("font_color", "OptionButton", TEXT)

	# Tabs
	t.set_stylebox("panel", "TabContainer", box(Color(0.06, 0.05, 0.05, 0.9), Color(0.4, 0.3, 0.18), 1, 3, 10.0, 8.0))
	t.set_stylebox("tab_selected", "TabContainer", box(WOOD_PRESSED, GOLD, 1, 3, 12.0, 4.0))
	t.set_stylebox("tab_unselected", "TabContainer", box(WOOD, Color(0.4, 0.3, 0.18), 1, 3, 12.0, 4.0))
	t.set_stylebox("tab_hovered", "TabContainer", box(WOOD_HOVER, Color(0.6, 0.45, 0.25), 1, 3, 12.0, 4.0))
	t.set_color("font_selected_color", "TabContainer", GOLD)
	t.set_color("font_unselected_color", "TabContainer", TEXT_DIM)
	t.set_color("font_hovered_color", "TabContainer", TEXT)

	# Bars
	t.set_stylebox("background", "ProgressBar", box(Color(0.05, 0.04, 0.04), Color(0.35, 0.27, 0.17), 1, 3, 0.0, 0.0))
	t.set_stylebox("fill", "ProgressBar", box(Color(0.85, 0.62, 0.25), Color(0, 0, 0, 0), 0, 3, 0.0, 0.0))
	t.set_stylebox("slider", "HSlider", box(Color(0.05, 0.04, 0.04), Color(0.35, 0.27, 0.17), 1, 3, 0.0, 3.0))
	t.set_stylebox("grabber_area", "HSlider", box(Color(0.85, 0.62, 0.25), Color(0, 0, 0, 0), 0, 3, 0.0, 3.0))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(GOLD, Color(0, 0, 0, 0), 0, 3, 0.0, 3.0))

	# Scrollbars: slim and dark
	t.set_stylebox("scroll", "VScrollBar", box(Color(0.05, 0.04, 0.04, 0.6), Color(0, 0, 0, 0), 0, 3, 3.0, 0.0))
	t.set_stylebox("grabber", "VScrollBar", box(Color(0.45, 0.34, 0.2), Color(0, 0, 0, 0), 0, 3, 3.0, 0.0))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(Color(0.65, 0.5, 0.28), Color(0, 0, 0, 0), 0, 3, 3.0, 0.0))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(GOLD, Color(0, 0, 0, 0), 0, 3, 3.0, 0.0))
	return t
