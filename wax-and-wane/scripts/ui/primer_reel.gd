class_name PrimerReel
extends Control
## v2.7 (docs/streams/v27_onboarding.md): How to play, from the pause menu and the Journal: the controls primer
## (primer.gd) again as a short animated reel in a modal. A little stage where the candle walks, fires at the wax
## dummy, loses four minutes to a hit and picks them back up, drops a bomb and steps back, and uses its special move;
## beside it the controls for the device in use (live: touch thumbs, keys, the gamepad, the mouse; Swap sticks
## mirrors the thumbs; rebinds show), under it the step's name and line (the primer's own words, Primer.texts). It
## turns its own pages (< > or LB / RB to choose); Reduce motion: nothing glides. A picture: nothing in a run changes.

const STAGE := Vector2(232, 88)
const PAGE := 3.6              # s per step
const FLOOR := Color("#483b3a")
const GRID := Color("#3b3332")

var step := 0
var t := 0.0
var candle := "tallow"
var _name: Label
var _line: Label
var _pips: Control
var _sb: StyleBox


## Opens the reel over `parent` (the HUD's root over the pause menu, or the Journal's parent: Back closes it first).
static func open(parent: Node, candle_id := "") -> Control:
	var m := UI.modal(parent, L.t("HOW TO PLAY"))
	var root: Control = m[0]
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	var v: VBoxContainer = m[1]
	v.add_theme_constant_override("separation", 3)
	var reel := PrimerReel.new()
	reel.candle = candle_id if candle_id != "" else str(Game.records.get("candle", "tallow"))
	v.add_child(reel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.add_child(UI.button("<", reel.turn.bind(-1), 28))
	var close := UI.primary(L.t("Close"), func(): root.queue_free(), 84)
	close.set_meta("default_focus", true)
	row.add_child(close)
	row.add_child(UI.button(">", reel.turn.bind(1), 28))
	v.add_child(row)
	Controls.set_page_handler(root, reel.turn)   # LB / RB, Q / E
	Audio.play("ui_open")
	return root


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = STAGE + Vector2(0, 26)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sb = UI._tex_box("kit_inset", [3, 3, 3, 3], [0, 0, 0, 0])   # (a flat inset since 2.10)
	_pips = Control.new()
	_pips.custom_minimum_size = Vector2(Primer.STEPS.size() * 6 - 1, 7)
	_pips.position = Vector2(floorf((STAGE.x - _pips.custom_minimum_size.x) / 2.0), STAGE.y + 3.0)
	_pips.size = _pips.custom_minimum_size
	_pips.draw.connect(_draw_pips)
	add_child(_pips)
	_name = UI.label("", 8, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_name.position = Vector2(0, STAGE.y + 8.0)
	_name.size = Vector2(STAGE.x, 10)
	add_child(_name)
	_line = UI.label("", 8, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_line.position = Vector2(0, STAGE.y + 17.0)
	_line.size = Vector2(STAGE.x, 10)
	_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_line)
	_texts()


func turn(d: int) -> void:
	step = (step + d + Primer.STEPS.size()) % Primer.STEPS.size()
	t = 0.0
	_texts()
	Audio.play("ui_move")


func _move_id() -> String:
	return Moves.for_candle(candle)


func _texts() -> void:
	var id: String = Primer.STEPS[step]
	if id == "special" and _move_id() == "":
		step = 0
		id = Primer.STEPS[0]
	var tx := Primer.texts(id, _move_id())
	_name.text = tx[0]
	_line.text = tx[1]
	_pips.queue_redraw()


func _process(dt: float) -> void:
	t += dt
	if t >= PAGE:
		turn(1)
	queue_redraw()


func _draw_pips() -> void:
	for i in Primer.STEPS.size():
		var x := float(i * 6)
		var col := UI.CREAM if i == step else (UI.GOLD if i < step else Color("#483b3a"))
		_pips.draw_rect(Rect2(x, 1, 5, 5), UI.INK)
		_pips.draw_rect(Rect2(x + 1, 2, 3, 3), col)


# ---------------------------------------------------------------- the stage

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, STAGE)
	draw_style_box(_sb, r)
	draw_rect(r.grow(-3.0), FLOOR)
	var x := 3.0 + 15.0
	while x < STAGE.x - 3.0:
		draw_rect(Rect2(x, 3, 1, STAGE.y - 6), GRID)
		x += 16.0
	var y := 3.0 + 15.0
	while y < STAGE.y - 3.0:
		draw_rect(Rect2(3, y, STAGE.x - 6, 1), GRID)
		y += 16.0
	var calm := UI.calm()
	var dev := Controls.device
	var left := Vector2(32, STAGE.y - 30)     # the move thumb's spot (the glyphs, as in play)
	var right := Vector2(STAGE.x - 32, STAGE.y - 30)
	if dev == Controls.TOUCH and bool(Game.settings.get("swap_sticks", false)):
		var tmp := left
		left = right
		right = tmp
	var feet := Vector2(floorf(STAGE.x / 2.0), STAGE.y - 26.0)
	match Primer.STEPS[step]:
		"move": _move(dev, left, feet, calm)
		"aim": _aim(dev, right, feet, calm)
		"wax": _wax(feet, calm)
		"bomb": _bomb(dev, right, feet, calm)
		"special": _special(dev, right, feet, calm)


func _candle(feet: Vector2, flash := false) -> void:
	Player.paint_preview(self, feet.round(), candle, {"frame": int(t * 8.0) % 4})
	if flash:
		draw_rect(Rect2(feet + Vector2(-7, -18), Vector2(14, 16)), Color(1, 1, 1, 0.45))


func _move(dev: String, spot: Vector2, feet: Vector2, calm: bool) -> void:
	var k := PrimerGlyphs.push(t, calm)
	_candle(feet + PrimerGlyphs.way(t, calm) * Vector2(22, 10) * k)
	PrimerGlyphs.move(self, dev, spot, t, calm)


## Three embers into the dummy, a pop, again.
func _aim(dev: String, spot: Vector2, feet: Vector2, calm: bool) -> void:
	var me := feet + Vector2(-34, 0)
	var dummy := feet + Vector2(30, 0)
	var shot := int(t / 0.5)
	var u := fmod(t, 0.5) / 0.32
	var hits := shot % 4
	if hits < 3 or u < 1.0:
		var hit := u >= 1.0 and u < 1.25
		var f := 0 if not hit else (1 if shot % 2 == 0 else 2)
		var tex := Art.tex("primer/dummy_hit" if hit and not calm else "primer/dummy_f%d" % f)
		draw_texture(tex, dummy + Vector2(-9, -25))
		if u < 1.0 and hits < 3:
			var from := me + Vector2(6, -8)
			var to := dummy + WaxDummy.CHEST
			draw_texture(Art.tex("fx/ember_f0"), (from.lerp(to, u) - Vector2(3, 3)).round())
	else:
		var fr := Art.seq("fx/poof")
		var i := clampi(int((u - 1.0) * 12.0), 0, fr.size() - 1)
		draw_texture(fr[i], (dummy + WaxDummy.CHEST - fr[i].get_size() / 2.0).round(), Color(1.0, 0.8, 0.55))
	_candle(me)
	PrimerGlyphs.aim(self, dev, spot, Vector2.RIGHT, t, calm)


## The gauge: 12:00 -> a bolt -> 12:04 and two drips -> walk over them -> 12:00.
func _wax(feet: Vector2, calm: bool) -> void:
	var cut := 0.0
	var me := feet
	var drips := [feet + Vector2(-30, 4), feet + Vector2(30, -4)]
	var taken := 0
	if t >= 0.7:
		cut = 4.0
		if t >= 1.5:
			var w := clampf((t - 1.5) / 0.6, 0.0, 1.0)
			me = feet.lerp(drips[0], w)
			if w >= 1.0:
				taken = 1
		if t >= 2.1:
			var w2 := clampf((t - 2.1) / 0.8, 0.0, 1.0)
			me = drips[0].lerp(drips[1], w2)
			if w2 >= 1.0:
				taken = 2
		cut -= 2.0 * taken
	# the bolt flies in from the right
	if t < 0.7 and not calm:
		var bf := Art.seq("fx/bolt_wax")
		var bx := lerpf(STAGE.x - 12.0, feet.x + 6.0, clampf(t / 0.7, 0.0, 1.0))
		draw_texture(bf[int(t * 10.0) % bf.size()], Vector2(bx, feet.y - 12.0).round())
	for i in 2:
		if t >= 0.7 and taken <= i:
			var land: Vector2 = drips[i]
			var a := clampf((t - 0.7) / 0.3, 0.0, 1.0)
			var at: Vector2 = feet.lerp(land, a) + Vector2(0, -sin(a * PI) * 8.0)
			draw_texture(Art.tex("pickups/wax_small"), (at - Vector2(4, 8)).round(), Color("#ee8e2e") if fmod(t, 0.5) < 0.3 else Color("#facb3e"))
	_candle(me, t >= 0.7 and t < 0.85)
	# the gauge, top-left of the stage: the clock digits on their plate, the wax bar under it, a gold frame round both
	var g := Rect2(8, 7, 70, 27)
	var minutes := int(cut)
	var digits := "12:%02d" % minutes
	var am := Art.font_small.get_string_size("AM", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var plate := Hud._plate_box()   # sized like the HUD's: the digits, "AM", a margin each side
	draw_style_box(plate, Rect2(g.position, Vector2(4.0 + Hud._digits_w(digits) + 2.0 + am + 4.0, 18)))
	if Art.has("ui/hud_digits"):
		var strip := Art.tex("ui/hud_digits")
		var x := g.position.x + 4.0
		for ch in digits:
			var i := "0123456789:".find(ch)
			draw_texture_rect_region(strip, Rect2(Vector2(x - (2.0 if ch == ":" else 0.0), g.position.y + 3.0), Vector2(8, 12)), Rect2(i * 8, 0, 8, 12))
			x += 4.0 if ch == ":" else 7.0
	else:   # v2.10: the clock is set in the game's font, as the HUD's is (Hud._draw_clock)
		draw_string(Art.font, g.position + Vector2(4, 13), digits, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.CREAM)
	draw_string(Art.font_small, Vector2(g.position.x + 4.0 + Hud._digits_w(digits) + 2.0, g.position.y + 14.0), "AM", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UI.CREAM)
	var by := g.position.y + 20.0
	var bw := 64.0
	var fill := roundf(bw * (120.0 - cut) / 120.0)
	draw_rect(Rect2(g.position.x, by, bw + 2.0, 7), UI.INK)
	draw_rect(Rect2(g.position.x + 1.0, by + 1.0, bw, 5), Color("#21141b"))   # the HUD's own bar: plain since 2.10
	draw_rect(Rect2(g.position.x + 1.0, by + 2.0, fill, 3), Color("#fdf7ed"))
	PrimerGlyphs.frame(self, Rect2(g.position, Vector2(bw + 2.0, 27)), t, calm)


## A bomb at the feet, a step back, the blast.
func _bomb(dev: String, spot: Vector2, feet: Vector2, calm: bool) -> void:
	var u := fmod(t, 1.8)
	var bomb_at := feet + Vector2(0, 1)
	var back := clampf((u - 0.25) / 0.35, 0.0, 1.0)
	if u >= 0.15 and u < 1.25:
		var bf := Art.seq("0x72/bomb")
		draw_texture(bf[int(u * 10.0) % bf.size()], (bomb_at - Vector2(8, 14)).round())
	elif u >= 1.25 and not calm:
		var ef := Art.seq("fx/explosion")
		var i := clampi(int((u - 1.25) * 18.0), 0, ef.size() - 1)
		draw_texture(ef[i], (bomb_at + Vector2(0, -10) - ef[i].get_size() / 2.0).round())
	_candle(feet + Vector2(-30.0 * back, 0))
	if dev == Controls.TOUCH:
		var c := spot + Vector2(0, 4)
		var b := Art.tex("ui/btn_bomb")
		draw_texture(b, (c - b.get_size() / 2.0).floor())
		PrimerGlyphs.tap(self, c, 14, t, calm)
	else:
		PrimerGlyphs.press(self, dev, spot, Controls.bound_glyph("bomb", dev == Controls.PAD), t, calm)


## The candle's move: its picture bursts out over the candle with a ring of light.
func _special(dev: String, spot: Vector2, feet: Vector2, calm: bool) -> void:
	var id := _move_id()
	var u := fmod(t, 1.8)
	_candle(feet)
	if u >= 0.4:
		var k := clampf((u - 0.4) / 0.5, 0.0, 1.0)
		var r := int(4.0 + 14.0 * k)
		if not calm or k >= 1.0:
			PrimerGlyphs.ring(self, feet + Vector2(0, -10), r, t, calm)
		var ic := Art.tex(Moves.icon(id))
		draw_texture(ic, (feet + Vector2(-8, -40 - 4.0 * k)).round())
	if dev == Controls.TOUCH:
		var c := spot + Vector2(0, 4)
		draw_circle(c, 15.0, UI.INK, true, -1.0, false)
		draw_circle(c, 14.0, Color("#21141b"), true, -1.0, false)
		var ic2 := Art.tex(Moves.icon(id))
		draw_texture(ic2, (c - ic2.get_size() / 2.0).floor())
		PrimerGlyphs.tap(self, c, 16, t, calm)
	else:
		PrimerGlyphs.press(self, dev, spot, Controls.bound_glyph("special", dev == Controls.PAD), t, calm)
