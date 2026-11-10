class_name Hud
extends CanvasLayer
## Wax/clock bar, counters, minimap, boss bar, banners and the twin-stick touch controls.

var world: Node
var root: Control
var bar: Control
var clock_label: Label
var spare_label: Label    # "+8 min": wax beyond a full night (the clock stays at 12:00 AM)
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
var map_layer: Control   # v2.6: the full map (FullMap), over the pause menu
var vignette: TextureRect
var preview: Label
var _preview_t := 0.0
var _preview_lines := 1
var _safe_t := 0.0
var _last_safe := Rect2i()
var _bomb_idx := -1
var _bomb_press := Vector2.ZERO
var _bomb_ms := 0
var ghost_sticks := false
var banner_band: NinePatchRect   # v2.6: the brass plate under the banner title
var keep_btn: Control
var _keep_idx := -1
var _keep_press := Vector2.ZERO
var _keep_ms := 0
var streak_box: Control
var streak_label: Label
var hint_band: NinePatchRect
var _banner_tw: Tween
var _hint_tw: Tween
var _held_tips: Array = []      # [text, dur]: tips that landed mid guardian fight, shown after it (UX-04)
var _hint_scope := []           # [floor, cell] of the special room a hint belongs to, or [] (C11)
var _banner_scope := []
## v2.6 (docs/streams/v26_gui.md): the candle gauge = the clock's big digits on a brass-rimmed plate sitting on
## the wax bar's holder; coins and bombs in chips; the floor's name with a pip per floor; the banner's title on
## a brass plate with its line on a dark ribbon; hints on the same ribbon; a framed boss bar.
var clock_face: Control         # the plate and the big digits (hud_digits.png); clock_label is its "AM"
var _clock_digits := "12:00"
var _clock_hot := false
var floor_pips: Control
var banner_strip: NinePatchRect  # the ribbon under the banner's plate (banner_band is the plate)
const DIGIT_ADV := 7             # a digit cell is 8 px (1 px ink each side): neighbours share an outline
const COLON_ADV := 4
const PLATE_H := 18
const BOSS_W := 200.0

var shown_wax := 120.0
var ghost_wax := 120.0
var _wax_seen := false   # the bar starts at the candle's own wax (a longer night's candle holds more)
var _ghost_hold := 0.0
var boss_frac := 1.0
var _flame_t := 0.0
var _flame_frames: Array[Texture2D] = []

# input: the world reads move_vec / aim_vec every physics tick. They merge the touch sticks with
# the keyboard, gamepad and mouse (Controls autoload); the touch handlers below fill _touch_*.
var move_vec := Vector2.ZERO
var aim_vec := Vector2.ZERO
var _touch_move := Vector2.ZERO
var _touch_aim := Vector2.ZERO
var _mouse_block := false        # the left button went down on a HUD button, not to fire
var keep_key: Label
var _l_idx := -1
var _r_idx := -1
var _l_origin := Vector2.ZERO
var _r_origin := Vector2.ZERO
const STICK_R := 22.0
const AIM_FLICK := 4.0   # px of thumb travel before the aim stick fires
const MOVE_DEAD := 0.15  # the move stick: no walk under 15% of its reach (3 px)
const MOVE_FULL := 0.6   # v2.6: full speed from 60% of its reach (13 px)


## v2.3: the special move's button (scripts/game/move_button.gd; it places itself in _layout).
var move_btn: MoveButton


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
	vignette.material = Lighting.dither_material()   # stepped + dithered, not a smooth ramp
	root.add_child(vignette)
	# --- the candle gauge: the clock plate (big digits + AM) on the wax bar's brass holder
	bar = Control.new()
	bar.position = Vector2(4, 22)
	bar.size = Vector2(142, 14)
	bar.draw.connect(_draw_bar)
	clock_face = Control.new()
	clock_face.size = Vector2(52, PLATE_H)
	clock_face.draw.connect(_draw_clock)
	root.add_child(clock_face)
	root.add_child(bar)   # over the plate: the flame at the burning end walks under the clock as the night goes
	clock_label = UI.label("AM", 8, UI.CREAM)
	clock_face.add_child(clock_label)
	streak_box = Control.new()
	streak_box.size = Vector2(40, 16)
	streak_box.draw.connect(_draw_streak)
	root.add_child(streak_box)
	streak_label = UI.label("", 16, UI.EMBER)
	streak_label.position = Vector2(10, -1)
	streak_box.add_child(streak_label)
	spare_label = UI.label("", 8, UI.GOLD)
	root.add_child(spare_label)
	floor_label = UI.label("", 8, UI.WAX)
	root.add_child(floor_label)
	floor_pips = Control.new()
	floor_pips.size = Vector2(60, 5)
	floor_pips.draw.connect(_draw_pips)
	root.add_child(floor_pips)
	# --- counters: a chip each (icon + number)
	var cbox := HBoxContainer.new()
	cbox.position = Vector2(4, 39)
	cbox.add_theme_constant_override("separation", 2)
	root.add_child(cbox)
	coin_label = _chip(cbox, "ui/hud_coin", UI.GOLD)
	bomb_label = _chip(cbox, "ui/hud_bomb", UI.CREAM)
	# --- minimap (top right; v2.6: 10x7 cells)
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
	# --- keepsake button (above the bomb button)
	keep_btn = Control.new()
	keep_btn.size = Vector2(30, 30)
	keep_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keep_btn.draw.connect(_draw_keep)
	root.add_child(keep_btn)
	move_btn = MoveButton.new(self)   # v2.3: the special move (under the bomb, the biggest of the three)
	root.add_child(move_btn)
	# --- boss bar
	boss_box = Control.new()
	boss_box.visible = false
	root.add_child(boss_box)
	boss_name = UI.outlined(UI.label("", 16, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER))   # v2.6: the guardian's name, readable
	boss_name.size = Vector2(BOSS_W, 16)
	boss_name.position = Vector2(0, -17)
	boss_box.add_child(boss_name)
	boss_bar = Control.new()
	boss_bar.size = Vector2(BOSS_W, 10)
	boss_bar.draw.connect(_draw_boss_bar)
	boss_box.add_child(boss_bar)
	# --- banners
	banner_strip = _nine("ui/kit_strip", 5, 4)
	root.add_child(banner_strip)
	banner_band = _nine("ui/kit_plate", 5, 5)
	root.add_child(banner_band)
	hint_band = _nine("ui/kit_strip", 5, 4)
	root.add_child(hint_band)
	banner = UI.engraved(UI.label("", 16, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))   # cut into the brass plate
	banner.modulate.a = 0
	root.add_child(banner)
	banner_sub = UI.label("", 8, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	banner_sub.modulate.a = 0
	root.add_child(banner_sub)
	preview = UI.label("", 8, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	preview.modulate.a = 0
	preview.max_lines_visible = 2
	preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	root.add_child(preview)
	hint = UI.outlined(UI.label("", 8, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER))   # outlined: in a boss fight it has no band
	hint.modulate.a = 0
	root.add_child(hint)
	# --- sticks
	stick_l = _make_stick()
	stick_r = _make_stick()
	root.add_child(stick_l)
	root.add_child(stick_r)
	# keyboard / gamepad key under the keepsake pips ("Q", "LB")
	keep_key = UI.label("", 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	keep_key.size = Vector2(30, 10)
	keep_key.position = Vector2(0, 30)
	keep_btn.add_child(keep_key)
	for b in [pause_btn, bomb_btn]:
		b.focus_mode = Control.FOCUS_NONE
	# FitCheck (--fit tours): which pieces of the HUD are laid out together
	for pair in [[bar, "status"], [clock_face, "status"], [spare_label, "status"], [streak_box, "status"],
			[floor_label, "status"], [cbox, "status"], [minimap, "map"], [pause_btn, "map"],
			[banner, "banner"], [banner_sub, "banner"], [hint, "hints"], [preview, "hints"],
			[boss_box, "boss"], [bomb_btn, "buttons"], [keep_btn, "buttons"]]:
		(pair[0] as Node).set_meta("fit_group", pair[1])
	process_physics_priority = -10      # read input before the world moves Tallow
	get_viewport().size_changed.connect(_layout)
	Controls.device_changed.connect(_on_device)
	Game.settings_changed.connect(_refresh_touch)
	_layout()
	_refresh_touch()


func _exit_tree() -> void:
	Controls.want_crosshair(false)


## A counter chip: [icon] 23, on a small dark plate. Returns its number label.
func _chip(row: HBoxContainer, icon: String, col: Color) -> Label:
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"ChipPanel"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chip)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	chip.add_child(h)
	var tr := TextureRect.new()
	tr.texture = Art.tex(icon)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tr.custom_minimum_size = Vector2(12, 12)
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tr)
	var l := UI.label("0", 16, col)
	l.custom_minimum_size = Vector2(7, 12)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return l


## A pixel-exact nine-patch (banner plate, ribbons, the map's frame), hidden until shown.
func _nine(path: String, mx: int, my: int) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = Art.tex(path)
	n.patch_margin_left = mx
	n.patch_margin_right = mx
	n.patch_margin_top = my
	n.patch_margin_bottom = my
	n.modulate.a = 0
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


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


## True on 16:9 / 16:10 screens (monitors, Steam Deck: 384 px wide), where the room leaves only a
## 56 px gutter at each side: the floor name stacks into the gutter, the minimap stays off the floor.
var _narrow := false


func _layout() -> void:
	var vs := view_size()
	var ins := safe_insets()
	_narrow = vs.x - ins.x - ins.y < 432.0
	minimap.size = Vector2(76, 40 if _narrow else 50)
	# the gauge: the clock plate at the top-left corner, the wax bar's holder right under it
	clock_face.position = Vector2(4 + ins.x, 3)
	bar.position = Vector2(4 + ins.x, 3 + PLATE_H + 1)
	_place_clock()
	(coin_label.get_parent().get_parent().get_parent() as Control).position = Vector2(4 + ins.x, 39)
	floor_label.position = Vector2(6 + ins.x, 58)
	minimap.position = Vector2(vs.x - minimap.size.x - 30 - ins.y, 5)
	pause_btn.position = Vector2(vs.x - 26 - ins.y, 3)
	bomb_btn.position = Vector2(vs.x - 33 - ins.y, vs.y - 118)
	keep_btn.position = Vector2(vs.x - 33 - ins.y, vs.y - 154)
	if Game.settings.get("swap_sticks", false) and Controls.touch_visible():
		# UX-08: swapped sticks aim with the left thumb, so its buttons sit on the left edge (a little
		# lower, clear of the floor name in the left gutter)
		bomb_btn.position = Vector2(3 + ins.x, vs.y - 108)
		keep_btn.position = Vector2(3 + ins.x, vs.y - 144)
	boss_box.position = Vector2(floorf((vs.x - BOSS_W) / 2.0), vs.y - 11)
	_place_banner()
	hint.size = Vector2(vs.x, 10)
	hint_band.size = Vector2(300, 25)
	_place_hints()
	if move_btn:
		move_btn.place()   # v2.3: the move button joins the bomb / keepsake column


## Hints and item previews sit at the bottom edge; while the boss bar is up they move above it
## (they must never cover the boss's name or bar).
func _place_hints() -> void:
	var vs := view_size()
	var lift := 30.0 if boss_box.visible else 0.0
	var ph := 10.0 * _preview_lines   # an item preview is one or two lines
	preview.size = Vector2(vs.x - 16.0, ph)
	preview.position = Vector2(8, vs.y - 13 - ph - lift)
	hint.position = Vector2(0, vs.y - 12 - lift)
	if boss_box.visible:
		# UX-04: during a guardian fight a hint is one line at the top, under the banner slot, with no
		# band: the arena floor (and its bottom rows) stays clear
		hint.position = Vector2(0, 66.0 if _narrow else 48.0)
	hint_band.size.y = ph + 16.0
	hint_band.position = Vector2(floorf((vs.x - hint_band.size.x) / 2.0), vs.y - 16 - ph - lift)


## The dark band under hints / previews grows with the longest line (a shop line can be wide).
func _fit_band(fresh: Label) -> void:
	var w := 120.0
	for l in [hint, preview]:
		var lab: Label = l
		if lab.text != "" and (lab == fresh or lab.modulate.a > 0.05):
			for line in lab.text.split("\n"):
				w = maxf(w, _tw8(line) + 24.0)   # the ribbon's brass ends + a little air
	hint_band.size.x = minf(ceilf(w), view_size().x)
	_place_hints()


static func _tw8(text: String) -> float:
	return Art.font_small.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x


## Floor / relic / room banners: the title, then a subtitle that wraps to two lines, on a dark band
## sized to the text. The subtitle keeps clear of the clock and counters on the left and the minimap
## on the right; on 384-wide screens the banner sits below the wax bar (QA-11: a long relic line ran
## over the bomb counter there).
func _place_banner() -> void:
	var vs := view_size()
	var ins := safe_insets()
	var top := 27.0 if _narrow else 16.0
	var sub_y := top + (18.0 if _narrow else 17.0)
	var mid := floorf(vs.x / 2.0)
	var left := 72.0 + ins.x   # the clock, coins and bombs column
	# the right edge: the minimap beside the title, else the keepsake button's column; Swap sticks moves that
	# button to the left edge, and then only the screen's edge is on the right at this height
	var right := vs.x - ins.y - 4.0
	if sub_y < minimap.position.y + minimap.size.y:
		right = minimap.position.x - 4.0
	elif keep_btn.position.x > mid:
		right = keep_btn.position.x - 4.0
	var sub_max := 2.0 * minf(mid - left, right - mid)
	var sw := Art.font_small.get_string_size(banner_sub.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var lines := 1 if sw <= sub_max else 2
	var w := ceilf(minf(sw, sub_max))
	banner.size = Vector2(vs.x, 16)
	banner.position = Vector2(0, top)
	banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if lines > 1 else TextServer.AUTOWRAP_OFF
	banner_sub.max_lines_visible = 2
	banner_sub.size = Vector2(w + 2.0, 10.0 * lines)
	banner_sub.position = Vector2(floorf(mid - w / 2.0) - 1.0, sub_y)
	# v2.6: the title on a brass plate (sized to its words), the line under it on a dark ribbon
	var tw := Art.font.get_string_size(banner.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x if banner.text != "" else 0.0
	var pw := ceilf(maxf(tw + 26.0, 72.0))
	banner_band.position = Vector2(floorf(mid - pw / 2.0), top - 2.0)
	banner_band.size = Vector2(pw, 19)
	banner_band.visible = banner.text != ""
	banner.position.y = top - 1.0
	var sw2 := ceilf(maxf(w + 24.0, pw - 12.0))
	banner_strip.position = Vector2(floorf(mid - sw2 / 2.0), sub_y - 3.0)
	banner_strip.size = Vector2(sw2, 10.0 * lines + 6.0)
	banner_strip.visible = banner_sub.text != ""


func show_banner(title: String, sub := "", dur := 2.4) -> void:
	banner.text = title
	banner_sub.text = sub
	_banner_scope = _room_scope()
	_place_banner()
	if title != "" and preview.text.begins_with(title.to_upper() + "  -  "):
		preview.modulate.a = 0.0   # the banner names it now: no second copy at the bottom
		_preview_t = 0.0
	if _banner_tw:
		_banner_tw.kill()
	_banner_tw = create_tween().set_parallel(true)
	for l in [banner, banner_sub, banner_band, banner_strip]:
		_banner_tw.tween_property(l, "modulate:a", 1.0, 0.2)
		_banner_tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.2 + dur)
	if not UI.calm():   # v2.6: the plate drops 3 px into place as it appears
		for l in [banner, banner_band]:
			var y0: float = (l as Control).position.y
			(l as Control).position.y = y0 - 3.0
			_banner_tw.tween_property(l, "position:y", y0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Shown while standing next to a relic / shop item.
## Long offers (a Cracked Mirror relic: name, what it does, its price, the rite) take two lines, never
## more than the screen width - 16 px: "NAME  -  what it does" / "Costs 15 max minutes (7 now)   [Rite]".
func preview_item(title: String, sub: String) -> void:
	# the top banner names this item right now (it was just taken): no second copy at the bottom
	if banner.modulate.a > 0.05 and banner.text == title.to_upper():
		return
	var t := "%s  -  %s" % [title.to_upper(), sub]
	var maxw := view_size().x - 16.0
	var lines := 1
	if _tw8(t) > maxw:
		lines = 2
		var cut := sub.find("   -   ")
		if cut < 0:
			cut = sub.find("   [")
		if cut >= 0:
			t = "%s  -  %s\n%s" % [title.to_upper(), sub.substr(0, cut), sub.substr(cut).trim_prefix("   -   ").strip_edges()]
	if t != preview.text:
		preview.text = t
		_preview_lines = lines
		var wrap := lines == 2 and (not t.contains("\n") or _tw8(t.get_slice("\n", 0)) > maxw or _tw8(t.get_slice("\n", 1)) > maxw)
		preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
		_fit_band(preview)
	preview.modulate.a = 1.0
	_preview_t = 0.3


func show_hint(text: String, dur := 6.0) -> void:
	# UX-04: a first-time tip (Game.tip) that lands while a guardian fights waits for the fight to end; v2.7: so does
	# any hint during the controls primer (its own line sits there), shown when it ends (Primer._finish)
	if (boss_box.visible and int(Game.get_meta("tip_frame", -1)) == Engine.get_process_frames()) or Primer.active(world):
		if _held_tips.size() < 3 and not _held_tips.any(func(h): return h[0] == text):
			_held_tips.append([text, dur])
		return
	hint.text = text
	_hint_scope = _room_scope()
	_fit_band(hint)
	if _hint_tw:
		_hint_tw.kill()
	_hint_tw = create_tween()
	_hint_tw.tween_property(hint, "modulate:a", 1.0, 0.4)
	_hint_tw.tween_interval(dur)
	_hint_tw.tween_property(hint, "modulate:a", 0.0, 0.8)


func set_boss(name: String, visible_: bool) -> void:
	var ended := boss_box.visible and not visible_
	boss_box.visible = visible_
	_place_hints()
	if ended and not _held_tips.is_empty():
		_flush_tips()
	boss_name.text = name
	boss_frac = 1.0
	boss_bar.queue_redraw()


## The tips held during the fight, one after another.
func _flush_tips() -> void:
	var tw := create_tween()
	tw.tween_interval(1.0)
	for h in _held_tips:
		tw.tween_callback(show_hint.bind(h[0], h[1]))
		tw.tween_interval(float(h[1]) + 1.4)
	_held_tips.clear()


## C11: banners and hints shown in a special room (seance, mirror, music box, study, font), a treasure
## room, the shop or a hollow belong to it: they fade as soon as Tallow leaves it. Floor banners,
## tutorial tips and boss lines (start / normal / boss rooms) keep their time.
func _room_scope() -> Array:
	var r: Variant = world.get("room")
	if r == null or not is_instance_valid(r) or not ("data" in r):
		return []
	if str((r as Node).get("data").get("type", "normal")) in ["start", "normal", "boss"]:
		return []
	return [world.get("floor_num"), world.get("cur_cell")]


func _drop_room_text() -> void:
	var here := [world.get("floor_num"), world.get("cur_cell")]
	if not _hint_scope.is_empty() and _hint_scope != here:
		_hint_scope = []
		if _hint_tw:
			_hint_tw.kill()
		_hint_tw = create_tween()
		_hint_tw.tween_property(hint, "modulate:a", 0.0, 0.25)
	if not _banner_scope.is_empty() and _banner_scope != here:
		_banner_scope = []
		if _banner_tw:
			_banner_tw.kill()
		_banner_tw = create_tween().set_parallel(true)
		for l in [banner, banner_sub, banner_band, banner_strip]:
			_banner_tw.tween_property(l, "modulate:a", 0.0, 0.25)


func set_boss_frac(f: float) -> void:
	boss_frac = clampf(f, 0.0, 1.0)
	boss_bar.queue_redraw()


func on_hurt() -> void:
	_ghost_hold = 0.5


func _process(dt: float) -> void:
	var p: Player = world.player
	if p == null:
		return
	if not _wax_seen:
		_wax_seen = true
		shown_wax = p.wax
		ghost_wax = p.wax
	shown_wax = move_toward(shown_wax, p.wax, maxf(30.0, absf(p.wax - shown_wax) * 6.0) * dt)
	if p.wax > ghost_wax:
		ghost_wax = p.wax
	_ghost_hold -= dt
	if _ghost_hold <= 0:
		ghost_wax = move_toward(ghost_wax, p.wax, 30.0 * dt)
	_flame_t += dt
	_cost_t -= dt
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
		if preview.modulate.a <= 0.0:
			preview.text = ""
			if _preview_lines != 1:
				_preview_lines = 1
				_place_hints()
	hint_band.modulate.a = maxf(0.0 if boss_box.visible else hint.modulate.a, preview.modulate.a)
	_drop_room_text()
	bar.queue_redraw()
	var ct := Game.clock_text(world.clock_minutes(), false)
	var digits := ct.get_slice(" ", 0)
	if digits != _clock_digits:
		_clock_digits = digits
		_place_clock()
	clock_label.text = ct.get_slice(" ", 1)
	var spare := Game.spare_minutes(world.clock_minutes())
	spare_label.text = "+%d min" % spare if spare > 0 else ""
	var low := p.wax < 20.0
	var want := 0.0
	if p.wax < 20.0 and not p.dead:
		want = (0.35 + 0.25 * sin(_flame_t * 4.5)) * (1.0 - p.wax / 20.0) + 0.15
	vignette.modulate.a = move_toward(vignette.modulate.a, want, dt * 2.0)
	var hot := low and fmod(_flame_t, 0.8) < 0.4   # low wax: the clock flashes red
	if hot != _clock_hot:
		_clock_hot = hot
		clock_face.queue_redraw()
	clock_label.add_theme_color_override("font_color", UI.RED if hot else UI.CREAM)
	floor_label.text = _floor_name()
	floor_pips.queue_redraw()
	streak_box.visible = world.streak >= 2
	if world.streak >= 2:
		streak_label.text = "x%d" % world.streak
		streak_box.queue_redraw()
	coin_label.text = "%d" % p.coins
	bomb_label.text = "%d" % p.bombs
	bomb_btn.modulate.a = 1.0 if p.bombs > 0 else 0.35
	keep_btn.visible = p.keepsake != ""
	keep_btn.queue_redraw()
	minimap.queue_redraw()
	if _l_idx < 0:
		_touch_move = Vector2.ZERO
	Controls.want_crosshair(not world.paused and not world.finished and not p.dead and Controls.uses_kbm())
	stick_l.queue_redraw()
	stick_r.queue_redraw()
	if ghost_sticks:
		root.queue_redraw()


## The clock plate's size follows its digits ("1:05" is narrower than "12:05"); "AM" sits after them, the
## spare minutes and the Kindling streak to the right of the plate.
func _place_clock() -> void:
	var w := _digits_w(_clock_digits)
	var am := Art.font_small.get_string_size("AM", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	clock_face.size = Vector2(4 + w + 2 + am + 4, PLATE_H)
	clock_label.position = Vector2(4 + w + 2, 6)
	clock_label.size = Vector2(am + 2, 10)
	var right := clock_face.position.x + clock_face.size.x
	spare_label.position = Vector2(right + 3, 7)
	streak_box.position = Vector2(right + 3 + (Art.font_small.get_string_size(spare_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 4.0 if spare_label.text != "" else 0.0), 3)
	clock_face.queue_redraw()


static func _digits_w(t: String) -> float:
	var x := 0.0
	for ch in t:
		x += COLON_ADV if ch == ":" else DIGIT_ADV
	return x + 1.0


func _draw_clock() -> void:
	var sb: StyleBoxTexture = _plate_box()
	clock_face.draw_style_box(sb, Rect2(Vector2.ZERO, clock_face.size))
	var strip := Art.tex("ui/hud_digits_hot" if _clock_hot else "ui/hud_digits")
	var x := 4.0
	for ch in _clock_digits:
		var i := "0123456789:".find(ch)
		if i < 0:
			continue
		var at := Vector2(x - (2.0 if ch == ":" else 0.0), 3)
		clock_face.draw_texture_rect_region(strip, Rect2(at, Vector2(8, 12)), Rect2(i * 8, 0, 8, 12))
		x += COLON_ADV if ch == ":" else DIGIT_ADV


static var _plate_sb: StyleBoxTexture


static func _plate_box() -> StyleBoxTexture:
	if _plate_sb == null:
		_plate_sb = StyleBoxTexture.new()
		_plate_sb.texture = Art.tex("ui/hud_clockplate")
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			_plate_sb.set_texture_margin(side, 4)
	return _plate_sb


## "The Cellar" (the floor's name), with a pip per floor of the night under it (pips: floor_pips).
func _floor_name() -> String:
	var t: String = world.floor_title()
	return t.get_slice("  -  ", 0)


## One pip per floor of the night: gold for the floors behind, a flame-white one for this floor, dark ahead;
## above the bells (the Clock Tower) every pip is lit and a last one burns blue.
func _draw_pips() -> void:
	var n: int = world.last_floor() if world.has_method("last_floor") else 4
	var f: int = int(world.get("floor_num"))
	floor_pips.position = floor_label.position + Vector2(0, 11)
	var tower := f > n
	for i in n + (1 if tower else 0):
		var x := float(i * 6)
		var col := Color("#483b3a")
		if i + 1 < f:
			col = UI.GOLD
		if i + 1 == f:
			col = UI.CREAM
		if tower and i == n:
			col = Color("#72d6ce")
		floor_pips.draw_rect(Rect2(x, 0, 5, 5), UI.INK)
		floor_pips.draw_rect(Rect2(x + 1, 1, 3, 3), col)
		if i + 1 == f and not tower:
			floor_pips.draw_rect(Rect2(x + 1, 1, 3, 1), UI.GOLD)


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
	var total := p.wax_max + p.charred     # minutes sold at the Smoke Altar stay burnt at the end
	var frac := clampf(shown_wax / total, 0.0, 1.0)
	var ghost := clampf(ghost_wax / total, 0.0, 1.0)
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
	if p.charred > 0.0:
		var cpx := roundf(inner * p.charred / total)
		var cx := x0 + inner - cpx
		bar.draw_rect(Rect2(cx, y0 + 1, cpx, h - 2), Color("#21141b"))
		var i := 0
		while i < int(cpx):
			bar.draw_rect(Rect2(cx + i, y0 + 2 + (i % 4) * 2, 1, 1), Color("#483b3a"))
			i += 2
	if _cost_t > 0.0:
		_draw_cost(x0, y0, h, inner, total, wpx)
	# notches every eighth of the night (quarter hours on a 4-floor night), so a longer night's bar looks the
	# same at the same fraction; the wider one is half the night (1:00 AM on a 4-floor night: the tower's line)
	var mins := total
	var night: float = world.night_minutes() if world.has_method("night_minutes") else 120.0
	var step := night / 8.0
	var k := step
	while k < mins - 0.01:
		var nx := x0 + roundf(inner * k / mins)
		var ww := 2.0 if is_equal_approx(k, night / 2.0) else 1.0
		var col := Color("#8a503e") if nx < x0 + wpx - 1 else Color("#775c55")
		bar.draw_rect(Rect2(nx, y0 + 3, ww, h - 6), col)
		k += step
	if Art.has("ui/bar_frame_left"):
		bar.draw_texture(left, Vector2(0, y0 + (h - left.get_height()) / 2.0))
	if Art.has("ui/bar_frame_right"):
		bar.draw_texture(right, Vector2(x0 + inner, y0 + (h - right.get_height()) / 2.0))
	# the flame burns at the end of the wax
	if not _flame_frames.is_empty() and shown_wax > 0.2:
		var fr: Texture2D = _flame_frames[int(_flame_t * 10.0) % _flame_frames.size()]
		bar.draw_texture(fr, Vector2(x0 + wpx - 4, y0 - fr.get_height() + 5))


## Design pass (docs/design/MDA.md): a wax price within reach (Smoke Altar, Cracked Mirror, the Wax
## Font, the mirror's toll) shows ON the wax bar before it is paid, so the clock trade is felt, not
## read. `now_min`: minutes cut from the wax now (marching red at the flame end); `max_min`: minutes
## charred for good (marching soot at the far end). Callers refresh it every frame while in reach.
var cost_now := 0.0
var cost_max := 0.0
var _cost_t := 0.0
const COST_HOT := [Color("#da4e38"), Color("#8f4029")]
const COST_CHAR := [Color("#775c55"), Color("#21141b")]


func preview_cost(now_min: float, max_min := 0.0) -> void:
	cost_now = maxf(0.0, now_min)
	cost_max = maxf(0.0, max_min)
	_cost_t = 0.15


## The exact pixels: the slice runs from where the wax would end to where it ends now; the soot from
## where the charred end would begin to where it begins now. Rows 2..h-3, under the notches.
func _draw_cost(x0: float, y0: float, h: float, inner: float, total: float, wpx: float) -> void:
	var p: Player = world.player
	var march := int(_flame_t * 8.0)
	if cost_max > 0.0:
		var c1 := roundf(inner * (total - p.charred) / total)
		var c0 := roundf(inner * maxf(0.0, total - p.charred - cost_max) / total)
		for i in int(c1 - c0):
			bar.draw_rect(Rect2(x0 + c0 + i, y0 + 2, 1, h - 4), COST_CHAR[(i + march) % 2])
	if cost_now > 0.0:
		var keep := roundf(inner * clampf((shown_wax - cost_now) / total, 0.0, 1.0))
		for i in int(wpx - keep):
			bar.draw_rect(Rect2(x0 + keep + i, y0 + 2, 1, h - 4), COST_HOT[(i + march) % 2])


func _draw_ghosts() -> void:
	if not ghost_sticks or not Controls.touch_visible():
		return
	var vs := view_size()
	var base := Art.tex("ui/stick_base")
	if _l_idx < 0:
		root.draw_texture(base, Vector2(64, vs.y - 52) - base.get_size() / 2.0, Color(1, 1, 1, 0.3))
	if _r_idx < 0:
		root.draw_texture(base, Vector2(vs.x - 64, vs.y - 52) - base.get_size() / 2.0, Color(1, 1, 1, 0.3))


func _draw_keep() -> void:
	var p: Player = world.player
	if p == null or p.keepsake == "":
		return
	var full := int(Items.KEEPSAKES[p.keepsake]["pips"])
	var ready := p.charge >= full
	var c := Vector2(15, 13)
	keep_btn.draw_circle(c, 12, Color("#775c55") if not ready else Color("#facb3e"), true, -1.0, false)
	keep_btn.draw_circle(c, 11, Color("#21141b"), true, -1.0, false)
	var ic := Art.tex(Items.icon(p.keepsake))
	var a := 1.0 if ready else 0.45
	if ready:
		a = 0.8 + 0.2 * sin(_flame_t * 8.0)
	keep_btn.draw_texture(ic, (c - ic.get_size() / 2.0).floor(), Color(1, 1, 1, a))
	var w := full * 5 - 1
	var x0 := floorf(15 - w / 2.0)
	for i in full:
		keep_btn.draw_rect(Rect2(x0 + i * 5, 27, 4, 2), Color("#facb3e") if i < p.charge else Color("#483b3a"))


func _draw_streak() -> void:
	if world.streak < 2:
		return
	if not _flame_frames.is_empty():
		var fr: Texture2D = _flame_frames[int(_flame_t * 12.0) % _flame_frames.size()]
		streak_box.draw_texture(fr, Vector2(0, 0))
	var w := roundf(20.0 * clampf(world.streak_t / 2.2, 0.0, 1.0))
	streak_box.draw_rect(Rect2(10, 14, 20, 1), Color("#483b3a"))
	streak_box.draw_rect(Rect2(10, 14, w, 1), UI.EMBER)


static var _boss_sb: StyleBoxTexture


func _draw_boss_bar() -> void:
	var w := boss_bar.size.x
	if _boss_sb == null:
		_boss_sb = StyleBoxTexture.new()
		_boss_sb.texture = Art.tex("ui/boss_frame")
		_boss_sb.texture_margin_left = 5
		_boss_sb.texture_margin_right = 5
		_boss_sb.texture_margin_top = 4
		_boss_sb.texture_margin_bottom = 4
	boss_bar.draw_style_box(_boss_sb, Rect2(0, 0, w, 10))
	var inner := w - 10.0
	var fw := roundf(inner * boss_frac)
	if fw > 0.0:
		boss_bar.draw_rect(Rect2(5, 2, fw, 6), Color("#9f294e"))
		boss_bar.draw_rect(Rect2(5, 2, fw, 1), Color("#dc4a7b"))
		boss_bar.draw_rect(Rect2(5, 7, fw, 1), Color("#62232f"))
		boss_bar.draw_rect(Rect2(5 + fw - 1, 2, 1, 6), Color("#f78697"))   # the bright edge where it was cut
	var skull := Art.tex("0x72/skull")
	boss_bar.draw_texture(skull, Vector2(-skull.get_width() - 1, floorf((10 - skull.get_height()) / 2.0)))


func _draw_minimap() -> void:
	var layout: Dictionary = world.layout
	if layout.is_empty():
		return
	var cells: Dictionary = layout["cells"]
	var cur: Vector2i = world.cur_cell
	var cw := 10.0
	var ch := 7.0
	var origin := (minimap.size / 2.0 - Vector2(cw, ch) / 2.0).floor()
	for c in cells.keys():
		var d: Dictionary = cells[c]
		if not d["seen"]:
			continue
		var off := Vector2((c.x - cur.x) * (cw + 2), (c.y - cur.y) * (ch + 2))
		var pos: Vector2 = origin + off
		if pos.x < 0 or pos.y < 0 or pos.x + cw > minimap.size.x or pos.y + ch > minimap.size.y:
			continue
		var col := Color("#775c55") if d["visited"] else Color("#483b3a")
		if c == cur:
			col = Color("#fdf7ed")
		minimap.draw_rect(Rect2(pos - Vector2(1, 1), Vector2(cw + 2, ch + 2)), Color("#21141b"))
		minimap.draw_rect(Rect2(pos, Vector2(cw, ch)), col)
		var mark := Color.TRANSPARENT
		match d["type"]:
			"boss": mark = Color("#da4e38")
			"treasure": mark = Color("#facb3e")
			"shop": mark = Color("#72d6ce")
			"secret": mark = Color("#dc4a7b")
		if mark.a > 0:
			minimap.draw_rect(Rect2(pos + Vector2(3, 1), Vector2(3, 4)), mark)
		Specials.draw_map_mark(minimap, world, d, pos)   # special rooms ("?" until known), mini-bosses


# ---------------------------------------------------------------- input

## Merges every device into move_vec / aim_vec (touch sticks win, then keys / gamepad, then the
## mouse) and handles the bomb and keepsake buttons. Runs before the world's physics tick.
func _physics_process(_dt: float) -> void:
	var p: Player = world.player
	if p == null:
		return
	var mv := _touch_move
	if mv == Vector2.ZERO:
		mv = Controls.move_vector()
	var aim := _touch_aim
	if aim == Vector2.ZERO and _r_idx >= 0 and Game.settings.get("aim", "assist") == "auto":
		aim = world.auto_aim(p)   # v2.6 Aim: Auto - the right thumb is down, not steering: fire at a foe
	if aim == Vector2.ZERO:
		aim = Controls.aim_vector()
	if aim == Vector2.ZERO:
		aim = _mouse_aim(p)
	move_vec = mv
	aim_vec = aim
	if world.paused or world.finished:
		return
	if Input.is_action_just_pressed("bomb") and p.bombs > 0:
		world.place_bomb()
		_bump(bomb_btn)
	if Input.is_action_just_pressed("keepsake"):
		world.use_keepsake()
	if (Input.is_action_just_pressed("special") or move_btn.take()) and p.use_move():   # v2.3 (Moves)
		move_btn.bump()


## Mouse aim: hold the left button to fire from the candle toward the cursor.
func _mouse_aim(p: Player) -> Vector2:
	if not Game.settings.get("mouse_aim", true) or not Controls.uses_kbm() or _mouse_block or world.paused:
		return Vector2.ZERO
	if Input.emulate_touch_from_mouse or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return Vector2.ZERO
	# v2.8: where Tallow is on the HUD's canvas (Screen: Big draws the world at its own scale, scripts/stage.gd)
	var from := Stage.to_ui(p) + Vector2(0, -6) * float(Stage.kw) / float(Stage.ku)
	var d := get_viewport().get_mouse_position() - from
	return d.normalized() if d.length() > 3.0 else Vector2.ZERO


func _bump(b: Control) -> void:
	b.scale = Vector2(0.9, 0.9)
	b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12)


func _on_device(_dev: String) -> void:
	_refresh_touch()


## Touch sticks and the bomb button show only while touch is the device in use (or always / never,
## from Settings > Controls > Touch). The keepsake button stays: it is also the charge display.
func _refresh_touch() -> void:
	var on := Controls.touch_visible()
	bomb_btn.visible = on
	if not on:
		release_sticks()
	keep_key.text = "" if on else Controls.glyph("keepsake")
	_layout()   # Swap sticks moves the bomb / keepsake buttons
	root.queue_redraw()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("map") and not world.finished and (not world.paused or is_instance_valid(map_layer)):
		get_viewport().set_input_as_handled()   # v2.6: M / Tab / the pad's Back open the full map, again closes it
		if is_instance_valid(map_layer):
			map_layer.queue_free()
			world.toggle_pause()
		else:
			world.open_map()
		return
	if event.is_action_pressed("pause") or (world.paused and event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		if world.paused:
			world.on_back()     # closes Settings / a confirm first, then resumes
		else:
			world.toggle_pause()
		return
	var real_touch: bool = (event is InputEventScreenTouch or event is InputEventScreenDrag) \
		and event.device != InputEvent.DEVICE_ID_EMULATION
	if real_touch and Controls.device != Controls.TOUCH:
		Controls.set_device(Controls.TOUCH)
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
	# mouse: a click on the pause button pauses; anywhere else the left button fires (mouse aim)
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and Rect2(pause_btn.position, pause_btn.size).grow(2).has_point(event.position):
			_mouse_block = true
			world.toggle_pause()
			get_viewport().set_input_as_handled()
			return
		if event.pressed and keep_btn.visible and Rect2(keep_btn.position, keep_btn.size).has_point(event.position):
			_mouse_block = true
			world.use_keepsake()
			get_viewport().set_input_as_handled()
			return
		if event.pressed and Rect2(minimap.position, minimap.size).has_point(event.position) and world.count_enemies() == 0:
			_mouse_block = true   # v2.6: a click on the minimap opens the full map (in a quiet room; v2.7 QA)
			world.open_map()
			get_viewport().set_input_as_handled()
			return
		if not event.pressed:
			_mouse_block = false
	if (event is InputEventScreenTouch or event is InputEventScreenDrag) and not Controls.touch_enabled():
		# touch controls are off (e.g. a gamepad on a phone): the pause button still works
		if event is InputEventScreenTouch and event.pressed and Rect2(pause_btn.position, pause_btn.size).grow(4).has_point(event.position):
			world.toggle_pause()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch and event.index == _keep_idx and not event.pressed:
		_keep_idx = -1
		if Time.get_ticks_msec() - _keep_ms < 450 and Rect2(keep_btn.position, keep_btn.size).grow(6).has_point(event.position):
			world.use_keepsake()
		return
	if event is InputEventScreenTouch and event.index == _bomb_idx and not event.pressed:
		_bomb_idx = -1
		if Time.get_ticks_msec() - _bomb_ms < 450 and Rect2(bomb_btn.position, bomb_btn.size).grow(6).has_point(event.position):
			world.place_bomb()
			_bump(bomb_btn)
		return
	if event is InputEventScreenDrag and event.index == _keep_idx and event.position.distance_to(_keep_press) > 8.0:
		_keep_idx = -1
		if _r_idx < 0:
			_r_idx = event.index
			_r_origin = _keep_press
			stick_r.position = _r_origin
			stick_r.visible = true
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
			# v2.6: tap the minimap for the whole floor - only in a quiet room (v2.7 QA: a thumb resting on it in a
			# fight, the move thumb's side with Swap sticks, paused the game); in a fight the touch is a stick touch
			if Rect2(minimap.position, minimap.size).has_point(pos) and world.count_enemies() == 0:
				world.open_map()
				get_viewport().set_input_as_handled()
				return
			if keep_btn.visible and Rect2(keep_btn.position, keep_btn.size).grow(4).has_point(pos) and _keep_idx < 0:
				_keep_idx = event.index
				_keep_press = pos
				_keep_ms = Time.get_ticks_msec()
				get_viewport().set_input_as_handled()
				return
			if bomb_btn.visible and Rect2(bomb_btn.position, bomb_btn.size).grow(4).has_point(pos) and world.player.bombs > 0 and _bomb_idx < 0:
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
				_touch_move = Vector2.ZERO
				stick_l.visible = false
			elif event.index == _r_idx:
				_r_idx = -1
				_touch_aim = Vector2.ZERO
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
			# v2.6 (feel): full speed at MOVE_FULL of the stick (13 px of thumb travel; it took all 22 px), a
			# smooth ramp up from the dead zone so a small push still walks
			var tilt := d.length() / STICK_R
			_touch_move = Vector2.ZERO if tilt < MOVE_DEAD else d.normalized() * clampf((tilt - MOVE_DEAD) / (MOVE_FULL - MOVE_DEAD), 0.0, 1.0)
			stick_l.set_meta("knob", d)
		elif event.index == _r_idx:
			var d := pos - _r_origin
			if d.length() > STICK_R:
				_r_origin = pos - d.normalized() * STICK_R
				stick_r.position = _r_origin
				d = pos - _r_origin
			# the aim stick is a direction: past a 4 px flick it fires at full tilt (design pass: a 5 px
			# flick used to do nothing, the player waited for 0.3 x STICK_R = 6.6 px)
			_touch_aim = d.normalized() if d.length() > AIM_FLICK else Vector2.ZERO
			stick_r.set_meta("knob", d)


func _button_at(n: Node, pos: Vector2) -> BaseButton:
	for i in range(n.get_child_count() - 1, -1, -1):
		var c := n.get_child(i)
		if c is CanvasItem and not (c as CanvasItem).is_visible_in_tree():
			continue
		var found := _button_at(c, pos)
		if found:
			return found
		if c is BaseButton and c != pause_btn and c != bomb_btn and (c as Control).get_global_rect().grow(2).has_point(pos):
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
	_touch_move = Vector2.ZERO
	_touch_aim = Vector2.ZERO
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
	var info := UI.label("%s   %s   %s" % [world.floor_title(), Game.clock_text(world.clock_minutes()), Records.level_text(int(world.level))], 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(info)
	var p: Player = world.player
	if not p.relics.is_empty():
		var row := HFlowContainer.new()
		# 24 px slots so a thumb can pick one; a huge collection packs tighter so the menu still fits
		var slot := 24.0 if p.relics.size() <= 24 else 18.0
		row.custom_minimum_size = Vector2(clampf(p.relics.size() * (slot + 1.0), 198.0, 304.0), 0)
		row.alignment = FlowContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("h_separation", 1)
		row.add_theme_constant_override("v_separation", 1)
		var relic_info := UI.label("Tap a relic to read it" if Controls.device == Controls.TOUCH else "Select a relic to read it",
			8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		for r in p.relics:
			var tb := Button.new()   # v2.6: an icon socket (the Theme's SlotButton)
			tb.theme_type_variation = &"SlotButton"
			tb.icon = Art.tex(Items.icon(r))
			tb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tb.custom_minimum_size = Vector2(slot, slot)
			tb.focus_mode = Control.FOCUS_ALL
			var rid: String = r
			var read := func(): relic_info.text = "%s - %s" % [Items.display_name(rid), Items.desc(rid)]
			tb.pressed.connect(read)
			tb.focus_entered.connect(read)
			row.add_child(tb)
		v.add_child(row)
		v.add_child(relic_info)
	var resume := UI.primary("Resume", func(): world.toggle_pause())   # v2.6: the brass button
	resume.set_meta("default_focus", true)
	v.add_child(resume)
	var row1 := HBoxContainer.new()   # Journal | Map | Settings | How to play (v2.7: the controls primer's reel)
	row1.add_theme_constant_override("separation", 6)
	for b in [UI.button("Journal", func(): Journal.open(root), 72), UI.button(L.t("Map"), open_map, 72),
			UI.button("Settings", func(): SettingsPanel.open(root), 72),
			UI.button(L.t("How to play"), func(): PrimerReel.open(root, str(world.get("candle_id"))), 72)]:
		(b as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row1.add_child(b)
	v.add_child(row1)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	for b in [UI.button("Save & quit", _confirm_save_quit, 72), UI.button(L.t("Restart"), _confirm_restart, 72),
			UI.danger("Give up", _confirm_give_up, 72)]:
		(b as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL   # thirds under a wide relic row
		row2.add_child(b)
	v.add_child(row2)
	Audio.play("ui_open")


## Leave now, continue later from the start of this floor (title screen: Continue).
func _confirm_save_quit() -> void:
	var m := UI.modal(root, "REST FOR NOW?")
	var r: Control = m[0]
	r.process_mode = Node.PROCESS_MODE_ALWAYS
	var v: VBoxContainer = m[1]
	v.add_child(UI.label("Continue later from the start of floor %d." % world.floor_num, 8, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var keep := UI.primary("Keep burning", func(): r.queue_free(), 100)
	keep.set_meta("default_focus", true)
	row.add_child(keep)
	row.add_child(UI.button("Save & quit", func():
		RunSave.flush()
		world.main.goto("title"), 90))
	v.add_child(row)


## v2.6 Quick restart: this night ends (as given up) and the next one is lit at once in the same slot, with the
## same candle and night length (a typed-in seed or Tonight's Candle: that same house again). world.quick_restart
func _confirm_restart() -> void:
	var m := UI.modal(root, L.t("LIGHT A NEW CANDLE?"))
	var r: Control = m[0]
	r.process_mode = Node.PROCESS_MODE_ALWAYS
	var v: VBoxContainer = m[1]
	v.add_child(UI.label(L.t("This night ends here. The next starts at once."), 8, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UI.button("Keep burning", func(): r.queue_free(), 100))
	row.add_child(UI.button(L.t("Restart"), func():
		r.queue_free()
		world.quick_restart(), 80))
	v.add_child(row)


## v2.6: the full map over the pause menu (the minimap tapped, M / Tab / Back, the pause menu's Map).
func open_map() -> void:
	if is_instance_valid(map_layer):
		return
	map_layer = FullMap.open(world)


func _confirm_give_up() -> void:
	var m := UI.modal(root, "SNUFF YOUR FLAME?")
	var r: Control = m[0]
	r.process_mode = Node.PROCESS_MODE_ALWAYS
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var keep := UI.primary("Keep burning", func(): r.queue_free(), 100)
	keep.set_meta("default_focus", true)
	row.add_child(keep)
	row.add_child(UI.danger("Give up", func():
		r.queue_free()
		world.give_up(), 80))
	(m[1] as VBoxContainer).add_child(row)


func close_pause() -> void:
	if pause_layer:
		pause_layer.queue_free()
		pause_layer = null
	if is_instance_valid(map_layer):
		map_layer.queue_free()
