class_name Hud
extends CanvasLayer
## Wax/clock bar, counters, minimap, boss bar, banners and the twin-stick touch controls.

var world: Node
var root: Control
var bar: Control
var clock_label: Label
var floor_label: Label
var coin_label: Label
var bomb_label: Label
var minimap: Control
var boss_box: Control
var boss_name: Label
var boss_bar: Control
var banner: Label
var banner_sub: Label
var hint: Label
var pause_btn: TextureButton
var bomb_btn: TextureButton
var stick_l: Control
var stick_r: Control
var pause_layer: Control
var vignette: TextureRect
var preview: Label
var _preview_t := 0.0
var _safe_t := 0.0
var _last_safe := Rect2i()
var _bomb_idx := -1
var _bomb_press := Vector2.ZERO
var _bomb_ms := 0
var ghost_sticks := false

var shown_wax := 120.0
var ghost_wax := 120.0
var _ghost_hold := 0.0
var boss_frac := 1.0
var _flame_t := 0.0
var _flame_frames: Array[Texture2D] = []

# touch state
var move_vec := Vector2.ZERO
var aim_vec := Vector2.ZERO
var _l_idx := -1
var _r_idx := -1
var _l_origin := Vector2.ZERO
var _r_origin := Vector2.ZERO
const STICK_R := 22.0


func _init(w: Node) -> void:
	world = w
	layer = 10


func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.draw.connect(_draw_ghosts)
	ghost_sticks = int(Game.records["runs"]) <= 3
	_flame_frames = Art.seq("hero/flame")
	# low-wax vignette (drawn under everything else in the HUD)
	var g := Gradient.new()
	g.set_color(0, Color(0.5, 0.05, 0.02, 0.0))
	g.set_color(1, Color(0.45, 0.04, 0.02, 0.85))
	g.add_point(0.55, Color(0.5, 0.05, 0.02, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 0.5)
	gt.width = 128
	gt.height = 72
	vignette = TextureRect.new()
	vignette.texture = gt
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate.a = 0.0
	root.add_child(vignette)
	# --- wax bar
	bar = Control.new()
	bar.position = Vector2(6, 5)
	bar.size = Vector2(150, 14)
	bar.draw.connect(_draw_bar)
	root.add_child(bar)
	clock_label = UI.label("12:00 AM", 16, UI.CREAM)
	clock_label.position = Vector2(8, 17)
	root.add_child(clock_label)
	floor_label = UI.label("", 8, UI.DIM)
	floor_label.position = Vector2(66, 22)
	root.add_child(floor_label)
	# --- counters
	var cbox := HBoxContainer.new()
	cbox.position = Vector2(8, 34)
	cbox.add_theme_constant_override("separation", 3)
	root.add_child(cbox)
	cbox.add_child(_icon("ui/icon_coin", "0x72/coin_anim_f0"))
	coin_label = UI.label("0", 16, UI.GOLD)
	cbox.add_child(coin_label)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(6, 0)
	cbox.add_child(gap)
	cbox.add_child(_icon("ui/icon_bomb", "0x72/bomb_f0"))
	bomb_label = UI.label("1", 16, UI.CREAM)
	cbox.add_child(bomb_label)
	# --- minimap (top right)
	minimap = Control.new()
	minimap.size = Vector2(72, 48)
	minimap.draw.connect(_draw_minimap)
	root.add_child(minimap)
	# --- pause
	pause_btn = TextureButton.new()
	pause_btn.texture_normal = Art.tex("ui/btn_pause")
	pause_btn.ignore_texture_size = true
	pause_btn.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	pause_btn.size = Vector2(23, 23)
	pause_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pause_btn)
	# --- bomb button (right edge, middle)
	bomb_btn = TextureButton.new()
	bomb_btn.texture_normal = Art.tex("ui/btn_bomb")
	bomb_btn.ignore_texture_size = true
	bomb_btn.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	bomb_btn.size = Vector2(30, 30)
	bomb_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bomb_btn.pivot_offset = Vector2(15, 15)
	root.add_child(bomb_btn)
	# --- boss bar
	boss_box = Control.new()
	boss_box.visible = false
	root.add_child(boss_box)
	boss_name = UI.label("", 8, UI.RED, HORIZONTAL_ALIGNMENT_CENTER)
	boss_name.size = Vector2(170, 10)
	boss_name.position = Vector2(0, -10)
	boss_box.add_child(boss_name)
	boss_bar = Control.new()
	boss_bar.size = Vector2(170, 6)
	boss_bar.draw.connect(_draw_boss_bar)
	boss_box.add_child(boss_bar)
	# --- banners
	banner = UI.label("", 16, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	banner.modulate.a = 0
	root.add_child(banner)
	banner_sub = UI.label("", 8, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	banner_sub.modulate.a = 0
	root.add_child(banner_sub)
	preview = UI.label("", 8, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	preview.modulate.a = 0
	root.add_child(preview)
	hint = UI.label("", 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	hint.modulate.a = 0
	root.add_child(hint)
	# --- sticks
	stick_l = _make_stick()
	stick_r = _make_stick()
	root.add_child(stick_l)
	root.add_child(stick_r)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _icon(path: String, fallback: String) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = Art.tex(path) if Art.has(path) else Art.tex(fallback)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tr.custom_minimum_size = Vector2(11, 13)
	return tr


func _make_stick() -> Control:
	var c := Control.new()
	c.size = Vector2(1, 1)
	c.visible = false
	c.set_meta("knob", Vector2.ZERO)
	c.draw.connect(func():
		if not c.visible:
			return
		var base := Art.tex("ui/stick_base")
		var knob := Art.tex("ui/stick_knob")
		c.draw_texture(base, -base.get_size() / 2.0, Color(1, 1, 1, 0.8))
		c.draw_texture(knob, c.get_meta("knob") - knob.get_size() / 2.0))
	return c


func view_size() -> Vector2:
	return get_viewport().get_visible_rect().size


## Left/right insets (in game pixels) for notches and rounded corners.
func safe_insets() -> Vector2:
	var win := Vector2(DisplayServer.window_get_size())
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or safe.size.x <= 0:
		return Vector2.ZERO
	var k := view_size().x / win.x
	return Vector2(maxf(0.0, safe.position.x * k), maxf(0.0, (win.x - safe.end.x) * k)).floor()


func _layout() -> void:
	var vs := view_size()
	var ins := safe_insets()
	bar.position = Vector2(6 + ins.x, 9)
	clock_label.position = Vector2(8 + ins.x, 21)
	floor_label.position = Vector2(8 + ins.x, 52)
	(coin_label.get_parent() as Control).position = Vector2(8 + ins.x, 37)
	minimap.position = Vector2(vs.x - minimap.size.x - 28 - ins.y, 4)
	pause_btn.position = Vector2(vs.x - 26 - ins.y, 3)
	bomb_btn.position = Vector2(vs.x - 33 - ins.y, 54)
	boss_box.position = Vector2((vs.x - 170) / 2.0, vs.y - 12)
	banner.size = Vector2(vs.x, 16)
	banner.position = Vector2(0, 48)
	banner_sub.size = Vector2(vs.x, 10)
	banner_sub.position = Vector2(0, 66)
	preview.size = Vector2(vs.x, 10)
	preview.position = Vector2(0, vs.y - 38)
	hint.size = Vector2(vs.x, 10)
	hint.position = Vector2(0, vs.y - 26)


func show_banner(title: String, sub := "", dur := 2.4) -> void:
	banner.text = title
	banner_sub.text = sub
	for l in [banner, banner_sub]:
		var tw: Tween = l.create_tween()
		tw.tween_property(l, "modulate:a", 1.0, 0.2)
		tw.tween_interval(dur)
		tw.tween_property(l, "modulate:a", 0.0, 0.6)


## Shown while standing next to a relic / shop item.
func preview_item(title: String, sub: String) -> void:
	preview.text = "%s  -  %s" % [title.to_upper(), sub]
	preview.modulate.a = 1.0
	_preview_t = 0.3


func show_hint(text: String, dur := 6.0) -> void:
	hint.text = text
	var tw := hint.create_tween()
	tw.tween_property(hint, "modulate:a", 1.0, 0.4)
	tw.tween_interval(dur)
	tw.tween_property(hint, "modulate:a", 0.0, 0.8)


func set_boss(name: String, visible_: bool) -> void:
	boss_box.visible = visible_
	boss_name.text = name
	boss_frac = 1.0
	boss_bar.queue_redraw()


func set_boss_frac(f: float) -> void:
	boss_frac = clampf(f, 0.0, 1.0)
	boss_bar.queue_redraw()


func on_hurt() -> void:
	_ghost_hold = 0.5


func _process(dt: float) -> void:
	var p: Player = world.player
	if p == null:
		return
	shown_wax = move_toward(shown_wax, p.wax, maxf(30.0, absf(p.wax - shown_wax) * 6.0) * dt)
	if p.wax > ghost_wax:
		ghost_wax = p.wax
	_ghost_hold -= dt
	if _ghost_hold <= 0:
		ghost_wax = move_toward(ghost_wax, p.wax, 30.0 * dt)
	_flame_t += dt
	_safe_t -= dt
	if _safe_t <= 0.0:
		_safe_t = 0.5
		var sa := DisplayServer.get_display_safe_area()
		if sa != _last_safe:
			_last_safe = sa
			_layout()
	_preview_t -= dt
	if _preview_t <= 0.0 and preview.modulate.a > 0.0:
		preview.modulate.a = move_toward(preview.modulate.a, 0.0, dt * 4.0)
	bar.queue_redraw()
	clock_label.text = Game.clock_text(world.clock_minutes())
	var low := p.wax < 20.0
	var want := 0.0
	if p.wax < 20.0 and not p.dead:
		want = (0.35 + 0.25 * sin(_flame_t * 4.5)) * (1.0 - p.wax / 20.0) + 0.15
	vignette.modulate.a = move_toward(vignette.modulate.a, want, dt * 2.0)
	clock_label.add_theme_color_override("font_color", UI.RED if low and fmod(_flame_t, 0.8) < 0.4 else UI.CREAM)
	floor_label.text = world.floor_title()
	coin_label.text = "%d" % p.coins
	bomb_label.text = "%d" % p.bombs
	bomb_btn.modulate.a = 1.0 if p.bombs > 0 else 0.35
	minimap.queue_redraw()
	move_vec = Vector2.ZERO if _l_idx < 0 else move_vec
	stick_l.queue_redraw()
	stick_r.queue_redraw()
	if ghost_sticks:
		root.queue_redraw()


func _draw_bar() -> void:
	var p: Player = world.player
	if p == null:
		return
	var left := Art.tex("ui/bar_frame_left")
	var right := Art.tex("ui/bar_frame_right")
	var fill := Art.tex("ui/bar_wax_fill")
	var empty := Art.tex("ui/bar_wax_empty")
	var h: float = fill.get_height() if Art.has("ui/bar_wax_fill") else 10.0
	var x0: float = left.get_width() if Art.has("ui/bar_frame_left") else 0.0
	var inner := 128.0
	var frac := clampf(shown_wax / p.wax_max, 0.0, 1.0)
	var ghost := clampf(ghost_wax / p.wax_max, 0.0, 1.0)
	var wpx := roundf(inner * frac)
	var gpx := roundf(inner * ghost)
	var y0 := 0.0
	if Art.has("ui/bar_wax_empty"):
		bar.draw_texture_rect(empty, Rect2(x0, y0, inner, h), true)
	else:
		bar.draw_rect(Rect2(x0, y0, inner, h), Color("#21141b"))
	if gpx > wpx:
		bar.draw_rect(Rect2(x0 + wpx, y0 + 2, gpx - wpx, h - 4), Color("#da4e38"))
	if Art.has("ui/bar_wax_fill"):
		bar.draw_texture_rect(fill, Rect2(x0, y0, wpx, h), true)
	else:
		bar.draw_rect(Rect2(x0, y0 + 1, wpx, h - 2), Color("#fdf7ed"))
	# quarter-hour notches (every 15 minutes of wax)
	var mins := p.wax_max
	var q := 15.0
	var k := q
	while k < mins:
		var nx := x0 + roundf(inner * k / mins)
		if nx < x0 + wpx - 1:
			bar.draw_rect(Rect2(nx, y0 + h - 3, 1, 2), Color("#d3bfa9"))
		k += q
	if Art.has("ui/bar_frame_left"):
		bar.draw_texture(left, Vector2(0, y0 + (h - left.get_height()) / 2.0))
	if Art.has("ui/bar_frame_right"):
		bar.draw_texture(right, Vector2(x0 + inner, y0 + (h - right.get_height()) / 2.0))
	# the flame burns at the end of the wax
	if not _flame_frames.is_empty() and shown_wax > 0.2:
		var fr: Texture2D = _flame_frames[int(_flame_t * 10.0) % _flame_frames.size()]
		bar.draw_texture(fr, Vector2(x0 + wpx - 4, y0 - fr.get_height() + 5))


func _draw_ghosts() -> void:
	if not ghost_sticks:
		return
	var vs := view_size()
	var base := Art.tex("ui/stick_base")
	if _l_idx < 0:
		root.draw_texture(base, Vector2(64, vs.y - 52) - base.get_size() / 2.0, Color(1, 1, 1, 0.3))
	if _r_idx < 0:
		root.draw_texture(base, Vector2(vs.x - 64, vs.y - 52) - base.get_size() / 2.0, Color(1, 1, 1, 0.3))


func _draw_boss_bar() -> void:
	var w := boss_bar.size.x
	boss_bar.draw_rect(Rect2(0, 0, w, 6), Color("#21141b"))
	boss_bar.draw_rect(Rect2(1, 1, (w - 2) * boss_frac, 4), Color("#9f294e"))
	boss_bar.draw_rect(Rect2(1, 1, (w - 2) * boss_frac, 1), Color("#dc4a7b"))


func _draw_minimap() -> void:
	var layout: Dictionary = world.layout
	if layout.is_empty():
		return
	var cells: Dictionary = layout["cells"]
	var cur: Vector2i = world.cur_cell
	var cw := 7.0
	var ch := 5.0
	var origin := minimap.size / 2.0 - Vector2(cw, ch) / 2.0
	for c in cells.keys():
		var d: Dictionary = cells[c]
		if not d["seen"]:
			continue
		var off := Vector2((c.x - cur.x) * (cw + 1), (c.y - cur.y) * (ch + 1))
		var pos: Vector2 = origin + off
		if pos.x < 0 or pos.y < 0 or pos.x + cw > minimap.size.x or pos.y + ch > minimap.size.y:
			continue
		var col := Color(0.42, 0.36, 0.36, 0.85) if d["visited"] else Color(0.25, 0.2, 0.22, 0.75)
		if c == cur:
			col = Color("#fdf7ed")
		minimap.draw_rect(Rect2(pos - Vector2(1, 1), Vector2(cw + 2, ch + 2)), Color(0.07, 0.04, 0.06, 0.8))
		minimap.draw_rect(Rect2(pos, Vector2(cw, ch)), col)
		var mark := Color.TRANSPARENT
		match d["type"]:
			"boss": mark = Color("#da4e38")
			"treasure": mark = Color("#facb3e")
			"shop": mark = Color("#72d6ce")
		if mark.a > 0:
			minimap.draw_rect(Rect2(pos + Vector2(2, 1), Vector2(3, 3)), mark)


# ---------------------------------------------------------------- touch input

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		world.toggle_pause()
		return
	if world.paused:
		# Godot only turns the first finger into clicks; let any finger tap menu buttons
		if event is InputEventScreenTouch and not event.pressed and event.index != 0:
			var b := _button_at(root, event.position)
			if b:
				b.pressed.emit()
				get_viewport().set_input_as_handled()
		return
	if world.player == null:
		return
	if event is InputEventScreenTouch and event.index == _bomb_idx and not event.pressed:
		_bomb_idx = -1
		if Time.get_ticks_msec() - _bomb_ms < 450 and Rect2(bomb_btn.position, bomb_btn.size).grow(6).has_point(event.position):
			world.place_bomb()
			bomb_btn.scale = Vector2(0.9, 0.9)
			bomb_btn.create_tween().tween_property(bomb_btn, "scale", Vector2.ONE, 0.12)
		return
	if event is InputEventScreenDrag and event.index == _bomb_idx and event.position.distance_to(_bomb_press) > 8.0:
		# a drag that started on the bomb button becomes the aim stick
		_bomb_idx = -1
		if _r_idx < 0:
			_r_idx = event.index
			_r_origin = _bomb_press
			stick_r.position = _r_origin
			stick_r.visible = true
	var swap: bool = Game.settings["swap_sticks"]
	if event is InputEventScreenTouch:
		var pos: Vector2 = event.position
		if event.pressed:
			# HUD buttons are handled here so they work with any finger (Godot only turns the
			# first finger into mouse clicks, and that finger is usually on the move stick)
			if Rect2(pause_btn.position, pause_btn.size).grow(4).has_point(pos):
				world.toggle_pause()
				get_viewport().set_input_as_handled()
				return
			if Rect2(bomb_btn.position, bomb_btn.size).grow(4).has_point(pos) and world.player.bombs > 0 and _bomb_idx < 0:
				_bomb_idx = event.index
				_bomb_press = pos
				_bomb_ms = Time.get_ticks_msec()
				get_viewport().set_input_as_handled()
				return
			var left_side := pos.x < view_size().x * 0.5
			if swap:
				left_side = not left_side
			if left_side and _l_idx < 0:
				_l_idx = event.index
				_l_origin = pos
				stick_l.position = pos
				stick_l.set_meta("knob", Vector2.ZERO)
				stick_l.visible = true
			elif not left_side and _r_idx < 0:
				_r_idx = event.index
				_r_origin = pos
				stick_r.position = pos
				stick_r.set_meta("knob", Vector2.ZERO)
				stick_r.visible = true
		else:
			if event.index == _l_idx:
				_l_idx = -1
				move_vec = Vector2.ZERO
				stick_l.visible = false
			elif event.index == _r_idx:
				_r_idx = -1
				aim_vec = Vector2.ZERO
				stick_r.visible = false
	elif event is InputEventScreenDrag:
		var pos: Vector2 = event.position
		if event.index == _l_idx:
			var d := pos - _l_origin
			if d.length() > STICK_R:
				# floating stick follows the thumb
				_l_origin = pos - d.normalized() * STICK_R
				stick_l.position = _l_origin
				d = pos - _l_origin
			move_vec = d / STICK_R
			if move_vec.length() < 0.15:
				move_vec = Vector2.ZERO
			stick_l.set_meta("knob", d)
		elif event.index == _r_idx:
			var d := pos - _r_origin
			if d.length() > STICK_R:
				_r_origin = pos - d.normalized() * STICK_R
				stick_r.position = _r_origin
				d = pos - _r_origin
			aim_vec = d / STICK_R if d.length() > 5.0 else Vector2.ZERO
			stick_r.set_meta("knob", d)


func _button_at(n: Node, pos: Vector2) -> Button:
	for i in range(n.get_child_count() - 1, -1, -1):
		var c := n.get_child(i)
		if c is CanvasItem and not (c as CanvasItem).is_visible_in_tree():
			continue
		var found := _button_at(c, pos)
		if found:
			return found
		if c is Button and (c as Button).get_global_rect().grow(2).has_point(pos):
			return c
	return null


func _over_button(pos: Vector2) -> bool:
	for b in [pause_btn, bomb_btn]:
		if Rect2(b.position, b.size).grow(3).has_point(pos):
			return true
	return false


func release_sticks() -> void:
	_l_idx = -1
	_r_idx = -1
	move_vec = Vector2.ZERO
	aim_vec = Vector2.ZERO
	stick_l.visible = false
	stick_r.visible = false


# ---------------------------------------------------------------- pause menu

func open_pause() -> void:
	release_sticks()
	if pause_layer:
		pause_layer.queue_free()
	var m := UI.modal(root, "PAUSED")
	pause_layer = m[0]
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var v: VBoxContainer = m[1]
	var info := UI.label("%s   %s" % [world.floor_title(), Game.clock_text(world.clock_minutes())], 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(info)
	var p: Player = world.player
	if not p.relics.is_empty():
		var row := HFlowContainer.new()
		row.custom_minimum_size = Vector2(150, 0)
		row.add_theme_constant_override("h_separation", 1)
		for r in p.relics:
			var tr := TextureRect.new()
			tr.texture = Art.tex(Items.icon(r))
			tr.tooltip_text = Items.display_name(r)
			row.add_child(tr)
		v.add_child(row)
	v.add_child(UI.button("Resume", func(): world.toggle_pause()))
	v.add_child(UI.button("Settings", func(): SettingsPanel.open(root)))
	v.add_child(UI.button("Give up", _confirm_give_up))
	Audio.play("ui_open")


func _confirm_give_up() -> void:
	var m := UI.modal(root, "SNUFF YOUR FLAME?")
	var r: Control = m[0]
	r.process_mode = Node.PROCESS_MODE_ALWAYS
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(UI.button("Keep burning", func(): r.queue_free(), 100))
	row.add_child(UI.button("Give up", func():
		r.queue_free()
		world.give_up(), 80))
	(m[1] as VBoxContainer).add_child(row)


func close_pause() -> void:
	if pause_layer:
		pause_layer.queue_free()
		pause_layer = null
