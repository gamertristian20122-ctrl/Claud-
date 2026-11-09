class_name UI
extends RefCounted
## The UI kit (v2.6, docs/streams/v26_gui.md): "candlelit wood and brass".
##
## The look lives in ONE place. `UI.theme()` builds a Godot Theme from the kit art (tools/art_ui2.py ->
## assets/art/ui/kit_*.png) and `UI.install()` (main.gd, once at start) folds it into the engine's default theme,
## so every Control in the game wears it: a plain Button is a dark-oak plank with brass nails, a PanelContainer a
## mahogany frame with brass corners, scroll bars are pixel bars. Type variations give the other kinds:
##   PrimaryButton (a brass plate, ink text)   DangerButton (red sealing wax)   TabButton / TabButtonOn
##   SlotButton (an icon socket)   CardPanel (a slim card)   InsetPanel (a sunken well)
##   PlatePanel (a brass plate)    StripPanel (a dark ribbon with brass ends)
## The factories below add what a Theme cannot: the focus flame next to a focused button's words, toggles with a
## switch, cycles with their value, a slider, headings with flourishes, separators, wax drips on big panels, and
## motion (a pop for panels, a candle-light wipe for full-screen menus; both off with Settings > Reduce motion).

const CREAM := Color("#fdf7ed")
const WAX := Color("#e2b694")
const GOLD := Color("#facb3e")
const EMBER := Color("#ee8e2e")
const RED := Color("#da4e38")
const DIM := Color("#aa8d7a")
const INK := Color("#21141b")
const SHINE := Color("#ffcc68")
const BRASS_DARK := Color("#8f4029")
const MUTED := Color("#775c55")
const VOID := Color(0.035, 0.027, 0.035)   # the screens' background (the dark around the house)
const KINDS := {"primary": &"PrimaryButton", "danger": &"DangerButton", "tab": &"TabButton", "tab_on": &"TabButtonOn"}

static var _theme: Theme
static var _focus_box: StyleBox
static var _focus_slot: Texture2D


# ---------------------------------------------------------------- the Theme

## Folds the kit into the engine's default theme: every Control created from now on wears it (main.gd calls this
## once, before the first screen).
static func install() -> void:
	ThemeDB.get_default_theme().merge_with(theme())


static func _tex_box(name: String, m: Array, c: Array, center := true) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = Art.tex("ui/" + name)
	sb.texture_margin_left = m[0]
	sb.texture_margin_top = m[1]
	sb.texture_margin_right = m[2]
	sb.texture_margin_bottom = m[3]
	sb.content_margin_left = c[0]
	sb.content_margin_top = c[1]
	sb.content_margin_right = c[2]
	sb.content_margin_bottom = c[3]
	sb.draw_center = center
	return sb


static func _flat(col: Color, margin := 0.0) -> StyleBoxFlat:
	var f := StyleBoxFlat.new()
	f.bg_color = col
	f.anti_aliasing = false
	f.set_content_margin_all(margin)
	return f


## One button kind: its face in each state (normal / hover / pressed / disabled) and its text colours.
static func _button_type(t: Theme, type: StringName, art: String, fg: Color, fg_hot: Color) -> void:
	var m := [6, 6, 6, 7]
	var c := [8, 3, 8, 5]
	var down := [8, 4, 8, 4]   # pressed: the face (and the words) sit 1 px lower
	t.set_stylebox("normal", type, _tex_box(art, m, c))
	t.set_stylebox("hover", type, _tex_box(art + "_hover", m, c))
	t.set_stylebox("pressed", type, _tex_box(art + "_pressed", m, down))
	t.set_stylebox("hover_pressed", type, _tex_box(art + "_pressed", m, down))
	t.set_stylebox("disabled", type, _tex_box("kit_btn_disabled", m, c))
	t.set_stylebox("focus", type, focus_box())
	t.set_font("font", type, Art.font)
	t.set_font_size("font_size", type, 16)
	t.set_color("font_color", type, fg)
	for st in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(st, type, fg_hot)
	t.set_color("font_disabled_color", type, MUTED)
	t.set_constant("h_separation", type, 3)


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	_button_type(t, &"Button", "kit_btn", CREAM, GOLD)
	t.set_type_variation(&"PrimaryButton", &"Button")
	_button_type(t, &"PrimaryButton", "kit_btn_primary", INK, INK)
	t.set_type_variation(&"DangerButton", &"Button")
	_button_type(t, &"DangerButton", "kit_btn_danger", CREAM, SHINE)
	# tabs: the open one is a lit plate with a gold rule; the others sit darker (their words 1 px lower)
	for pair in [[&"TabButton", "kit_tab", DIM, CREAM, [5, 5, 5, 3]], [&"TabButtonOn", "kit_tab_on", GOLD, GOLD, [5, 4, 5, 4]]]:
		var type: StringName = pair[0]
		t.set_type_variation(type, &"Button")
		var box := _tex_box(pair[1], [5, 5, 5, 4], pair[4])
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			t.set_stylebox(st, type, box)
		t.set_stylebox("focus", type, focus_box())
		t.set_font("font", type, Art.font)
		t.set_font_size("font_size", type, 16)
		t.set_color("font_color", type, pair[2])
		for st in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			t.set_color(st, type, pair[3])
	# an icon socket (relics in the pause menu and on the results)
	t.set_type_variation(&"SlotButton", &"Button")
	var sock := _tex_box("kit_slot", [3, 3, 3, 3], [1, 1, 1, 1])
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(st, &"SlotButton", sock)
	t.set_stylebox("focus", &"SlotButton", focus_box())
	# panels
	t.set_stylebox("panel", &"PanelContainer", _tex_box("kit_panel", [8, 8, 8, 8], [9, 8, 9, 8]))
	t.set_type_variation(&"CardPanel", &"PanelContainer")
	t.set_stylebox("panel", &"CardPanel", _tex_box("kit_card", [4, 4, 4, 4], [5, 3, 5, 3]))
	t.set_type_variation(&"InsetPanel", &"PanelContainer")
	t.set_stylebox("panel", &"InsetPanel", _tex_box("kit_inset", [3, 3, 3, 3], [3, 3, 3, 3]))
	t.set_type_variation(&"PlatePanel", &"PanelContainer")
	t.set_stylebox("panel", &"PlatePanel", _tex_box("kit_plate", [5, 5, 5, 5], [8, 3, 8, 5]))
	t.set_type_variation(&"StripPanel", &"PanelContainer")
	t.set_stylebox("panel", &"StripPanel", _tex_box("kit_strip", [5, 4, 5, 4], [8, 2, 8, 2]))
	t.set_type_variation(&"ChipPanel", &"PanelContainer")   # the HUD's counters
	t.set_stylebox("panel", &"ChipPanel", _tex_box("hud_chip", [3, 3, 3, 3], [3, 0, 4, 0]))
	# thin pixel scroll bars (the default ones are smooth grey pills)
	for type in [&"VScrollBar", &"HScrollBar"]:
		var track := _flat(INK)
		track.content_margin_left = 1
		track.content_margin_right = 1
		t.set_stylebox("scroll", type, track)
		t.set_stylebox("scroll_focus", type, track)
		t.set_stylebox("grabber", type, _flat(DIM))
		t.set_stylebox("grabber_highlight", type, _flat(GOLD))
		t.set_stylebox("grabber_pressed", type, _flat(GOLD))
	_theme = t
	return t


# ---------------------------------------------------------------- text

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


## A crisp 1 px dark outline (outline_size 2 on the 8 px pixel font) for text drawn over the floor,
## where a drop shadow alone gets lost on bright chapel tiles.
static func outlined(l: Label) -> Label:
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 2)
	return l


## Words cut into brass (on a PlatePanel): ink letters with a 1 px bright edge under them.
static func engraved(l: Label) -> Label:
	l.add_theme_color_override("font_color", INK)
	l.add_theme_color_override("font_shadow_color", SHINE)
	return l


## A heading: the words in gold between two brass flourishes.
static func heading(text: String, col := GOLD) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture("ui/kit_orn_l"))
	var l := label(text, 16, col, HORIZONTAL_ALIGNMENT_CENTER)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	row.add_child(picture("ui/kit_orn_r"))
	return row


## A small picture that keeps its pixels (centred in its box, never stretched).
static func picture(path: String) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = Art.tex(path)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## An engraved rule with a brass gem in the middle.
static func separator(w := 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 7)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL if w <= 0.0 else Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var y := floorf(c.size.y / 2.0)
		c.draw_rect(Rect2(0, y, c.size.x, 1), INK)
		c.draw_rect(Rect2(0, y + 1, c.size.x, 1), Color("#483b3a"))
		var gem := Art.tex("ui/kit_sep_gem")
		c.draw_texture(gem, Vector2(floorf((c.size.x - gem.get_width()) / 2.0), y - 3)))
	return c


# ---------------------------------------------------------------- panels

## kind: "" (the framed panel, with a pour of wax on a wide one), "card", "inset", "plate", "strip".
static func panel(min_size := Vector2.ZERO, kind := "") -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	match kind:
		"card": p.theme_type_variation = &"CardPanel"
		"inset": p.theme_type_variation = &"InsetPanel"
		"plate": p.theme_type_variation = &"PlatePanel"
		"strip": p.theme_type_variation = &"StripPanel"
		_: p.draw.connect(_drips.bind(p))
	return p


## Wax poured on the top rail of a big panel: one drip (two on a wide one), at fixed spots.
static func _drips(p: Control) -> void:
	var w := p.size.x
	if w < 90.0 or p.size.y < 40.0:
		return
	p.draw_texture(Art.tex("ui/kit_drip"), Vector2(floorf(w * 0.14), -2))
	if w >= 170.0:
		p.draw_texture(Art.tex("ui/kit_drip_small"), Vector2(floorf(w * 0.8), -2))


## Keyboard / gamepad selection frame: an ink and gold ring 2 px outside the button.
static func focus_box() -> StyleBox:
	if _focus_box:
		return _focus_box
	var sb := _tex_box("kit_focus", [4, 4, 4, 4], [0, 0, 0, 0], false)
	sb.set_expand_margin_all(2)
	_focus_box = sb
	return sb


## The old ring for 18x18 icon slots drawn by hand (the Journal's grid uses focus_box()).
static func focus_slot() -> Texture2D:
	if _focus_slot == null:
		_focus_slot = Art.tex("ui/focus_slot") if Art.has("ui/focus_slot") else null
	return _focus_slot


## Makes an icon TextureButton keyboard/gamepad selectable with the pixel focus frame.
static func focusable_slot(tb: TextureButton) -> void:
	tb.focus_mode = Control.FOCUS_ALL
	var slot := focus_slot()
	if slot:
		tb.draw.connect(func():
			if tb.has_focus(true):
				tb.draw_texture(slot, ((tb.size - slot.get_size()) / 2.0).floor()))
		tb.focus_entered.connect(tb.queue_redraw)
		tb.focus_exited.connect(tb.queue_redraw)


# ---------------------------------------------------------------- buttons

## kind: "" (dark oak), "primary" (brass: the screen's main action), "danger" (red wax), "tab", "tab_on".
static func button(text: String, cb: Callable, min_w := 96, kind := "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 24)
	b.focus_mode = Control.FOCUS_ALL
	if KINDS.has(kind):
		b.theme_type_variation = KINDS[kind]
	b.pressed.connect(func():
		Audio.play("ui_click")
		cb.call())
	b.draw.connect(_focus_flame.bind(b))
	return b


static func primary(text: String, cb: Callable, min_w := 120) -> Button:
	return button(text, cb, min_w, "primary")


static func danger(text: String, cb: Callable, min_w := 96) -> Button:
	return button(text, cb, min_w, "danger")


## A button with a small picture before its words (the title's Journal / Seed / Settings ...).
static func icon_button(text: String, icon_path: String, cb: Callable, min_w := 0, kind := "") -> Button:
	var b := button(text, cb, min_w, kind)
	b.icon = Art.tex(icon_path)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


## The flame lit next to the words of the button that has the keyboard / gamepad focus (the ring is the Theme's).
static func _focus_flame(b: Button) -> void:
	# (not on narrow keys, nor on icon buttons: their picture already stands where the flame would)
	if not b.has_focus(true) or b.text == "" or b.alignment != HORIZONTAL_ALIGNMENT_CENTER or b.icon or b.size.x < 56.0:
		return
	var f := Art.tex("ui/kit_focus_flame")
	var font := b.get_theme_font("font")
	var tw := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
	var x := floorf((b.size.x - tw) / 2.0) - f.get_width() - 2.0
	if x < 3.0:
		return
	var down := b.get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED]
	var y := floorf((b.size.y - f.get_height()) / 2.0) - 1.0 + (1.0 if down else 0.0)
	b.draw_texture(f, Vector2(x, y))


## A setting that is on or off: its name on the left, a switch on the right.
static func toggle(text: String, value: bool, cb: Callable, min_w := 150) -> Button:
	var b := button(text, func(): pass, min_w)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var state := [value]
	var refresh := func():
		b.icon = Art.tex("ui/kit_switch_on" if state[0] else "ui/kit_switch_off")
		b.set_meta("on", state[0])
	refresh.call()
	b.pressed.connect(func():
		state[0] = not state[0]
		refresh.call()
		cb.call(state[0]))
	return b


## A button that steps through options: "Touch          AUTO" -> "ON" -> "OFF" (the value in gold on the right).
static func cycle(text: String, values: Array, labels: Array, value: Variant, cb: Callable, min_w := 150) -> Button:
	var b := button(text, func(): pass, min_w)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var val := label("", 16, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	val.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	val.offset_right = -8
	val.offset_top = 3
	val.offset_bottom = -5
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(val)
	var st := [maxi(0, values.find(value))]
	var refresh := func():
		val.text = str(labels[st[0]])
	refresh.call()
	b.button_down.connect(func(): val.position.y = 4)
	b.button_up.connect(func(): val.position.y = 3)
	b.pressed.connect(func():
		st[0] = (st[0] + 1) % values.size()
		refresh.call()
		cb.call(values[st[0]]))
	return b


## A volume slider row: its name, a track with a flame knob (tap, drag, or left / right with keys and pads) and
## the value 0-10.
static func slider_row(text: String, value: float, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var l := label(text, 16)
	l.custom_minimum_size = Vector2(44, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var s := KitSlider.new()
	s.value = value
	row.add_child(s)
	var val := label("", 16, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	val.custom_minimum_size = Vector2(14, 0)
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(val)
	var refresh := func(x: float): val.text = "%d" % roundi(x * 10)
	refresh.call(value)
	s.changed.connect(func(x: float):
		refresh.call(x)
		cb.call(x))
	return row


## The kit's slider: a sunken track lit up to a flame knob, a notch per step. One focus stop: left / right step
## it; a tap or a drag on the track sets it. 24 px tall (a thumb-sized target).
class KitSlider extends Button:
	signal changed(v: float)
	var value := 0.5
	var steps := 10
	var _drag := false

	func _init() -> void:
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(88, 24)
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, empty)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func set_value(v: float) -> void:
		v = clampf(roundf(v * steps) / steps, 0.0, 1.0)
		if is_equal_approx(v, value):
			return
		value = v
		Audio.play("ui_move")
		queue_redraw()
		changed.emit(v)

	func _x0() -> float:
		return 5.0

	func _x1() -> float:
		return size.x - 6.0

	func _gui_input(e: InputEvent) -> void:
		if e.is_action_pressed("ui_left", true) and value > 0.0:
			set_value(value - 1.0 / steps)
			accept_event()
		elif e.is_action_pressed("ui_right", true) and value < 1.0:
			set_value(value + 1.0 / steps)
			accept_event()
		elif e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_drag = (e as InputEventMouseButton).pressed
			if _drag:
				_pick((e as InputEventMouseButton).position.x)
			accept_event()
		elif e is InputEventMouseMotion and _drag:
			_pick((e as InputEventMouseMotion).position.x)
			accept_event()
		elif e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed:
			_pick((e as InputEventScreenTouch).position.x)
			accept_event()
		elif e is InputEventScreenDrag:
			_pick((e as InputEventScreenDrag).position.x)
			accept_event()

	func _pick(x: float) -> void:
		set_value((x - _x0()) / maxf(1.0, _x1() - _x0()))

	func _draw() -> void:
		var x0 := _x0()
		var x1 := _x1()
		var ty := floorf(size.y / 2.0) - 3.0
		var kx := roundf(x0 + (x1 - x0) * value)
		draw_style_box(_box("kit_track"), Rect2(x0 - 3, ty, x1 - x0 + 6, 7))
		if kx > x0:
			draw_style_box(_box("kit_track_fill"), Rect2(x0 - 3, ty, kx - x0 + 6, 7))
		for i in range(1, steps):
			var nx := roundf(x0 + (x1 - x0) * float(i) / steps)
			draw_rect(Rect2(nx, ty + 8, 1, 2), UI.GOLD if nx <= kx else UI.MUTED)
		var knob := Art.tex("ui/kit_knob")
		draw_texture(knob, Vector2(kx - floorf(knob.get_width() / 2.0), ty - 3))
		if has_focus(true):
			draw_style_box(UI.focus_box(), Rect2(Vector2.ZERO, size))

	static func _box(name: String) -> StyleBoxTexture:
		return UI._tex_box(name, [4, 3, 4, 3], [0, 0, 0, 0])


# ---------------------------------------------------------------- motion

## Settings > Reduce motion: panels appear in place, screens change with a plain short fade.
static func calm() -> bool:
	return bool(Game.settings.get("reduce_motion", false))


## A panel opening: it rises 6 px into place and fades in (0.14 s), pixel-snapped; `fade` is what fades (the dim
## and the panel), `mover` what rises.
static func pop_in(fade: CanvasItem, mover: Control, dy := 6.0, secs := 0.14) -> void:
	if calm() or not mover.is_inside_tree():
		return
	var y0 := mover.position.y
	fade.modulate.a = 0.0
	mover.position.y = y0 + dy
	var tw := mover.create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(fade, "modulate:a", 1.0, secs * 0.8)
	tw.tween_method(func(k: float):
		if is_instance_valid(mover):
			mover.position.y = roundf(y0 + dy * (1.0 - k)), 0.0, 1.0, secs).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A full-screen menu opening (Slots, Journal): a candle-light edge sweeps across and uncovers it (0.2 s).
static func wipe_in(screen: Control, secs := 0.2) -> void:
	if calm() or not screen.is_inside_tree():
		return
	var w := Control.new()
	w.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.set_meta("fit_skip", true)
	var st := {"k": 0.0}
	w.draw.connect(func():
		var x := roundf(w.size.x * st["k"])
		w.draw_rect(Rect2(x, 0, w.size.x - x + 1, w.size.y), VOID)
		# the edge of the light: a cream core, gold, ember, and a few sparks ahead of it
		w.draw_rect(Rect2(x - 3, 0, 1, w.size.y), BRASS_DARK)
		w.draw_rect(Rect2(x - 2, 0, 1, w.size.y), EMBER)
		w.draw_rect(Rect2(x - 1, 0, 1, w.size.y), GOLD)
		w.draw_rect(Rect2(x, 0, 1, w.size.y), SHINE)
		for i in 12:
			var yy := float((i * 37 + int(x) * 3) % int(maxf(1.0, w.size.y)))
			w.draw_rect(Rect2(x + 2 + (i * 5) % 7, yy, 1, 1), EMBER if i % 2 else GOLD))
	screen.add_child(w)
	var tw := w.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_method(func(k: float):
		st["k"] = k
		w.queue_redraw(), 0.0, 1.0, secs).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(w.queue_free)


# ---------------------------------------------------------------- modals

## UX-07: a button (already in the tree) that ignores presses for its first `secs`: a second press
## meant for the screen before it can't skip a one-time card. No focus, no clicks, a little dimmed,
## then focus moves onto it.
static func hold_presses(b: Control, secs := 0.8) -> void:
	if b == null or not b.is_inside_tree():
		return
	var fm := b.focus_mode
	var mf := b.mouse_filter
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.modulate.a = 0.6
	b.get_tree().create_timer(secs, true, false, true).timeout.connect(func():
		if not is_instance_valid(b):
			return
		b.focus_mode = fm
		b.mouse_filter = mf
		b.modulate.a = 1.0
		var top: Node = b
		while top and not top.get_meta("modal", false):
			top = top.get_parent()
		if top is Control:
			Controls.focus_first(top))


## Full-screen dim layer with a centred VBox inside a panel (with a heading when `title` is given); the panel pops
## in. Returns [root Control, vbox].
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
		v.add_child(heading(title))
	parent.add_child(root)
	Controls.on_modal_opened(root)   # keyboard / gamepad focus moves in, and comes back on close
	pop_in(root, center)
	return [root, v]
