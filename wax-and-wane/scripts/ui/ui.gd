class_name UI
extends RefCounted
## Small factory for pixel-style controls (nine-patch panels/buttons from assets/art/ui when present).

const CREAM := Color("#fdf7ed")
const WAX := Color("#e2b694")
const GOLD := Color("#facb3e")
const EMBER := Color("#ee8e2e")
const RED := Color("#da4e38")
const DIM := Color("#aa8d7a")
const INK := Color("#21141b")


static func label(text: String, size := 16, color := CREAM, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_override("font", Art.font if size >= 16 else Art.font_small)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", INK)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func _box(path: String, margin: int, fallback: Color, content_v := 2) -> StyleBox:
	if Art.has(path):
		var sb := StyleBoxTexture.new()
		sb.texture = Art.tex(path)
		sb.texture_margin_left = margin
		sb.texture_margin_right = margin
		sb.texture_margin_top = margin
		sb.texture_margin_bottom = margin
		sb.content_margin_left = margin + 2
		sb.content_margin_right = margin + 2
		sb.content_margin_top = content_v
		sb.content_margin_bottom = content_v
		return sb
	var f := StyleBoxFlat.new()
	f.bg_color = fallback
	f.border_color = Color("#775c55")
	f.set_border_width_all(1)
	f.content_margin_left = 6
	f.content_margin_right = 6
	return f


static func panel(min_size := Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box("ui/panel_9", 8, Color(0.13, 0.09, 0.1, 0.96), 7))
	p.custom_minimum_size = min_size
	return p


static func button(text: String, cb: Callable, min_w := 96) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 24)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Art.font)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_pressed_color", GOLD)
	var normal := _box("ui/button_9", 6, Color(0.2, 0.14, 0.14, 1))
	var pressed := _box("ui/button_9_pressed", 6, Color(0.3, 0.2, 0.16, 1)) if Art.has("ui/button_9_pressed") else normal
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func():
		Audio.play("ui_click")
		cb.call())
	return b


static func toggle(text: String, value: bool, cb: Callable) -> Button:
	var b := button("", func(): pass, 150)
	var state := [value]
	var refresh := func():
		b.text = "%s: %s" % [text, "ON" if state[0] else "OFF"]
	refresh.call()
	b.pressed.connect(func():
		state[0] = not state[0]
		refresh.call()
		cb.call(state[0]))
	return b


static func slider_row(text: String, value: float, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var l := label(text, 16)
	l.custom_minimum_size = Vector2(52, 0)
	row.add_child(l)
	var minus := button("-", func(): pass, 20)
	var val := label("", 16, GOLD)
	val.custom_minimum_size = Vector2(30, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var plus := button("+", func(): pass, 20)
	var st := [value]
	var refresh := func():
		val.text = "%d" % roundi(st[0] * 10)
	refresh.call()
	minus.pressed.connect(func():
		st[0] = clampf(st[0] - 0.1, 0.0, 1.0)
		refresh.call()
		cb.call(st[0]))
	plus.pressed.connect(func():
		st[0] = clampf(st[0] + 0.1, 0.0, 1.0)
		refresh.call()
		cb.call(st[0]))
	row.add_child(minus)
	row.add_child(val)
	row.add_child(plus)
	return row


## Full-screen dim layer with a centred VBox inside a panel; returns [root Control, vbox].
static func modal(parent: Node, title := "") -> Array:
	var root := Control.new()
	root.set_meta("modal", true)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.02, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var p := panel()
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	if title != "":
		var t := label(title, 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(t)
	parent.add_child(root)
	return [root, v]
