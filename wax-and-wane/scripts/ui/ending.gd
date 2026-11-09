class_name Ending
extends CanvasLayer
## The endings: three or four short pixel-art scenes with a line each, a credits roll, then the results screen
## (world._end_run via the callback). Which ending plays is `ending` (v2.5, Diary.ENDINGS; chosen by
## Diary.win_ending / Diary.keeper_ending):
##   true          the Keeper of Hours stilled: the house is quiet, the clock stops at the time you finished,
##                 Tallow's flame settles on the sill, dawn comes and the little flame goes out.
##   housekeeper   a won night with 12+ diary pages: the house with the kitchen light on, Martha's empty
##                 chair, the last candle she made, the clock still ticking above the bells.
##   windows       a won night of seven floors or more: the clock stops, a candle lights in every window, one
##                 for everyone who lived here, Tallow kept the small hours.
##   whole_story   the Keeper stilled with all 24 pages: the clock stops for good, the windows go dark, the
##                 pages fly home to the diary by her chair, dawn.
## Scenes are 192x96 art (tools/art_tower.py tower/end_*, tools/art_story.py story/end_kitchen) shown at x2;
## the moving parts are drawn here in the same palette. Any key, click, tap or pad button skips everything
## after the first scene.

const CARD := 5.0
const FADE := 0.6
const ROLL_SPEED := 26.0
const SKY_NIGHT := ["#1f1833", "#2a2a3a", "#2a2a3a", "#323e4f", "#414859"]
const SKY_STEPS := [
	["#1f1833", "#2a2a3a", "#2a2a3a", "#323e4f", "#414859"],
	["#2a2a3a", "#323e4f", "#38607c", "#5f2d56", "#9f294e"],
	["#323e4f", "#38607c", "#417089", "#9f294e", "#dc4a7b"],
	["#38607c", "#417089", "#5698cc", "#dc4a7b", "#ee8e2e"],
	["#417089", "#5698cc", "#72d6ce", "#f78697", "#ffad3b"],
]
const STARS := [Vector2(12, 8), Vector2(28, 40), Vector2(52, 14), Vector2(64, 30), Vector2(80, 6), Vector2(118, 18),
	Vector2(132, 6), Vector2(150, 26), Vector2(166, 10), Vector2(182, 34), Vector2(176, 52), Vector2(8, 54),
	Vector2(46, 4), Vector2(158, 44)]
## Where Tallow stands: on the sill (tower/end_window), on the kitchen table (story/end_kitchen).
const SILL := Vector2(96, 71)
const TABLE := Vector2(96, 60)
## The house's windows (tower/end_house, 4x5 each), in the order a candle lights them; the first is the
## kitchen's, lit in every ending. ROUND: the attic's round window.
const WINDOWS := [Vector2(70, 70), Vector2(58, 70), Vector2(58, 60), Vector2(70, 60), Vector2(82, 60), Vector2(98, 66),
	Vector2(118, 72), Vector2(118, 63), Vector2(130, 72), Vector2(130, 63), Vector2(142, 72), Vector2(142, 63)]
const ROUND := Vector2(72.5, 51.5)
const LIGHT_GAP := 0.3
## The kitchen's window panes (story/end_kitchen; the sky is drawn behind the art) and its fire and kettle.
const K_PANE := Rect2(101, 11, 23, 29)
const K_FIRE := [15, 17, 18, 20, 21, 23, 24, 26, 27]
const K_SPOUT := Vector2(9, 22)
const DIARY_AT := Vector2(111, 56)

var _clock := 0.0
var _candle := "tallow"
var ending := "true"   # v2.5: "true", "housekeeper", "windows", "whole_story" (Diary.ENDINGS)
var _done: Callable
var _root: Control
var _vs := Vector2(384, 216)
var _card := -1
var _cards: Array = []
var _fx := ""
var _skippable := false
var _over := false
var _stage: Node2D
var _art: Node2D          # drawn behind the scene art (the sky in the window panes)
var _front: Node2D        # drawn over it (stars, hands, smoke, the candle's glow)
var _cv: CanvasItem
var _texts: Array = []
var _t := 0.0
var _hero: Player
var _sky := 0
var _roll: VBoxContainer
var _rolling := false
var _skip_lbl: Label
var _dial_a := 0.0
var _dial_stopped := false
var _smoke: Array = []
var _lit := 0             # windows lit so far (lights_on / lights_off)
var _ticked := 0


func setup(clock: float, candle: String, done: Callable) -> void:
	_clock = clock
	_candle = candle
	_done = done


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vs = get_viewport().get_visible_rect().size
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color("#140c11")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	_stage = Node2D.new()
	_stage.scale = Vector2(2, 2)
	_stage.position = Vector2(floorf((_vs.x - 384.0) / 2.0), 2)
	_root.add_child(_stage)
	_skip_lbl = UI.label(_skip_text(), 8, UI.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_skip_lbl.size = Vector2(160, 10)
	_skip_lbl.position = Vector2(_vs.x - 166, _vs.y - 12)
	_skip_lbl.visible = false
	_root.add_child(_skip_lbl)
	_cards = _card_list()
	_next_card()


func _skip_text() -> String:
	match Controls.device:
		"touch": return "Tap to skip"
		"gamepad": return "Any button to skip"
	return "Any key to skip"


func _input(ev: InputEvent) -> void:
	if not _skippable or _over:
		return
	var press: bool = (ev is InputEventKey and ev.pressed and not ev.echo) or (ev is InputEventMouseButton and ev.pressed) \
			or (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventJoypadButton and ev.pressed)
	if press:
		get_viewport().set_input_as_handled()
		Audio.play("ui_click")
		_finish()


func _finish() -> void:
	if _over:
		return
	_over = true
	if _done.is_valid():
		_done.call()


# ---------------------------------------------------------------- cards

## The cards of this ending: art, fx (what moves, see _process / _draw_front), where Tallow stands (or none),
## and the two lines under the scene.
func _card_list() -> Array:
	var name := str(Candles.def_of(_candle)["name"])
	var nm: float = get_parent().night_minutes() if get_parent() and get_parent().has_method("night_minutes") else Game.END_MINUTES
	var floors := int(get_parent().get("night_floors")) if get_parent() and get_parent().get("night_floors") != null else 4
	var stops := L.t("THE CLOCK STOPS AT {time}", {"time": Game.clock_text(_clock)})
	match ending:
		"housekeeper":
			return [
				_c("tower/end_house", "house", null, L.t("THE HOUSE IS QUIET"), L.t("One window is still lit. It's the kitchen. It always was.")),
				_c("story/end_kitchen", "kitchen", null, L.t("MARTHA FENN, HOUSEKEEPER"), L.t("Sixty-one years of keys, lists, mended curtains and seed cake.")),
				_c("story/end_kitchen", "kitchen", TABLE, L.t("SHE MADE ONE LAST CANDLE"), L.t("She lit him every night for a year, until he could light himself.")),
				_c("tower/end_dial", "tick", null, L.t("SOMETHING STILL TICKS ABOVE THE BELLS"), L.t("At twelve the Keeper will wind the clock again. Unless someone is early.")),
			]
		"windows":
			return [
				_c("tower/end_dial", "dial", null, stops, L.t("It will not strike {hour} tonight.", {"hour": Records.hour_words(nm)})),
				_c("tower/end_house", "lights_on", null, L.t("A CANDLE IN EVERY WINDOW"), L.t("The Kitchen, the Library, the Attic: lit again after all these years.")),
				_c("tower/end_house", "lights_lit", null, L.t("ONE FOR EVERYONE WHO LIVED HERE"), L.t("One for Cook. One for Miss Tibbet. One for Wilf, who hated the dark.")),
				_c("tower/end_window", "sill", SILL, L.t("{name} KEPT THE SMALL HOURS", {"name": name.to_upper()}),
					L.t("{floors} floors, every room, and not one of them forgotten.", {"floors": Records.number_word(floors).capitalize()})),
			]
		"whole_story":
			return [
				_c("tower/end_dial", "dial", null, stops, L.t("Nobody will wind it tomorrow. The Keeper has earned its rest.")),
				_c("tower/end_house", "lights_off", null, L.t("THE ROUNDS ARE DONE"), L.t("The pot cools. The organ breathes out. The Gaoler hangs up its keys.")),
				_c("story/end_kitchen", "pages", null, L.t("THE DIARY IS WHOLE"), L.t("Twenty-four pages, home by her chair.")),
				_c("tower/end_window", "dawn", SILL, L.t("DAWN COMES FOR THE LITTLE CANDLE"),
					L.t("Sleep well, Tallow. Martha kept your seat by the fire.") if _candle == "tallow" else L.t("Sleep well, {name}. The house is all done.", {"name": name})),
			]
	return [
		_c("tower/end_house", "house", null, L.t("THE HOUSE IS QUIET"), L.t("Every lodger is asleep. Even the stairs.")),
		_c("tower/end_dial", "dial", null, stops, L.t("It will not strike {hour} tonight.", {"hour": Records.hour_words(nm)})),
		_c("tower/end_window", "sill", SILL, L.t("{name}'S FLAME SETTLES", {"name": name.to_upper()}), L.t("No draught, no hands, no hurry. Just a small, warm light.")),
		_c("tower/end_window", "dawn", SILL, L.t("DAWN COMES FOR THE LITTLE CANDLE"), L.t("Sleep well, {name}.", {"name": name})),
	]


func _c(art: String, fx: String, hero: Variant, l1: String, l2: String) -> Dictionary:
	return {"art": art, "fx": fx, "hero": hero, "lines": [l1, l2]}


func _next_card() -> void:
	_card += 1
	if _card >= 1:
		_skippable = true
		_skip_lbl.visible = true
	for c in _stage.get_children():
		c.queue_free()
	for l in _texts:
		l.queue_free()
	_texts.clear()
	_smoke.clear()
	_hero = null
	_t = 0.0
	_lit = 0
	_ticked = 0
	if _card >= _cards.size():
		_start_roll()
		return
	var cd: Dictionary = _cards[_card]
	_fx = str(cd["fx"])
	_art = Node2D.new()
	_art.draw.connect(func(): _cv = _art; _draw_card())
	_front = Node2D.new()
	_front.draw.connect(func(): _cv = _front; _draw_front())
	var lines: Array = cd["lines"]
	_stage.add_child(_art)
	_add_tex(str(cd["art"]))
	_stage.add_child(_front)
	_sky = 0
	if _fx == "dial":
		_dial_a = -TAU * 3.0
		_dial_stopped = false
	if _fx == "lights_lit" or _fx == "lights_off":
		_lit = WINDOWS.size() + 1
	if cd["hero"] != null:
		_add_hero(cd["hero"], _fx == "sill")
	# a dark band for the words, over the bottom of the scene
	var band := ColorRect.new()
	band.color = Color("#140c11")
	band.position = Vector2(0, 160)
	band.size = Vector2(_vs.x, 56)
	_root.add_child(band)
	_root.move_child(band, 2)
	_texts.append(band)
	var t1 := UI.label(lines[0], 16, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	t1.size = Vector2(_vs.x, 16)
	t1.position = Vector2(0, 166)
	_root.add_child(t1)
	_texts.append(t1)
	var t2 := UI.label(lines[1], 8, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	t2.size = Vector2(_vs.x, 10)
	t2.position = Vector2(0, 186)
	_root.add_child(t2)
	_texts.append(t2)
	_stage.modulate.a = 0.0
	for l in [t1, t2]:
		l.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_stage, "modulate:a", 1.0, FADE)
	tw.parallel().tween_property(t1, "modulate:a", 1.0, FADE).set_delay(0.3)
	tw.parallel().tween_property(t2, "modulate:a", 1.0, FADE).set_delay(0.7)
	tw.tween_interval(CARD - FADE * 2.0)
	tw.tween_property(_stage, "modulate:a", 0.0, FADE)
	tw.parallel().tween_property(t1, "modulate:a", 0.0, FADE)
	tw.parallel().tween_property(t2, "modulate:a", 0.0, FADE)
	tw.tween_callback(_next_card)


func _add_tex(path: String) -> void:
	var s := Sprite2D.new()
	s.texture = Art.tex(path)
	s.centered = false
	_stage.add_child(s)


func _add_hero(at: Vector2, settle: bool) -> void:
	_hero = Player.new()
	_hero.world = null
	_stage.add_child(_hero)
	_hero.set_physics_process(false)
	_hero.apply_candle(_candle)
	_hero.wax = 70.0
	_hero.light.enabled = false
	_hero.glow.enabled = false
	_hero.position = at
	_hero._happy_face = 999.0
	if settle:
		_hero.flame.speed_scale = 2.4
		var tw := _hero.create_tween()
		tw.tween_property(_hero.flame, "speed_scale", 0.55, 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_hero.flame.speed_scale = 0.55


func _process(dt: float) -> void:
	if _rolling:
		_roll.position.y -= ROLL_SPEED * dt
		if _roll.position.y + _roll.size.y < _vs.y * 0.5 - 30.0 and not _over:
			_rolling = false
			var tw := create_tween()
			tw.tween_interval(2.6)
			tw.tween_callback(_finish)
		return
	_t += dt
	match _fx:
		"dial":
			if not _dial_stopped:
				var k := clampf(_t / 2.6, 0.0, 1.0)
				var was := _dial_a
				_dial_a = -TAU * 3.0 * pow(1.0 - k, 3.0)
				if int(was / (TAU / 12.0)) != int(_dial_a / (TAU / 12.0)):
					Audio.play("tick", -8.0, 0.0, 1.0 + k * 0.5)
				if k >= 1.0:
					_dial_stopped = true
					Audio.play("bell_small", -4.0, 0.0, 0.9)
		"tick":   # the clock goes on: a minute a second, a tick each
			if int(_t) > _ticked:
				_ticked = int(_t)
				Audio.play("tick", -8.0, 0.0, 0.9)
		"dawn":
			_sky = clampi(int((_t - 0.4) / 0.75), 0, SKY_STEPS.size() - 1)
			if _hero and _t > 3.3 and _hero.flame.visible:
				_hero.flame.visible = false
				Audio.play("snuff_out", -8.0, 0.0, 1.2)
				for i in 6:
					_smoke.append([Vector2(96, 54), -i * 0.22])   # a thread of smoke, puff after puff
		"lights_on":   # a candle in every window, one after another
			var n := clampi(int((_t - 0.5) / LIGHT_GAP) + 1, 1, WINDOWS.size() + 1)
			if n > _lit:
				_lit = n
				if n > 1:
					Audio.play("tick", -10.0, 0.02, 1.4 + 0.04 * n)
		"lights_off":  # the rounds are done: the windows go dark, the chimney stops
			var n2 := clampi(WINDOWS.size() + 1 - int((_t - 0.6) / LIGHT_GAP), 0, WINDOWS.size() + 1) if _t > 0.6 else WINDOWS.size() + 1
			if n2 < _lit:
				_lit = n2
				Audio.play("tick", -12.0, 0.02, 1.2 - 0.03 * (WINDOWS.size() - n2))
		"pages":
			var landed := clampi(int((_t - 0.3 - 1.2) / 0.11) + 1, 0, Diary.TOTAL)
			if landed > _lit:
				_lit = landed
				Audio.play("page_flip", -12.0, 0.08, 1.3)
	var chimney := _fx in ["house", "lights_on", "lights_lit"] or (_fx == "lights_off" and _lit > 0)
	if chimney and fmod(_t, 0.9) < dt:
		_smoke.append([Vector2(136, 37), 0.0])
	if (_fx == "kitchen" or _fx == "pages") and fmod(_t, 0.8) < dt:
		_smoke.append([K_SPOUT, 0.0])   # the kettle
	for s in _smoke:
		s[1] += dt
	_smoke = _smoke.filter(func(s): return s[1] < 2.6)
	if _art and is_instance_valid(_art):
		_art.queue_redraw()
	if _front and is_instance_valid(_front):
		_front.queue_redraw()


func _px(p: Vector2, c: String, sz := Vector2.ONE) -> void:
	_cv.draw_rect(Rect2(p.round(), sz), Color(c))


## Behind the art: the sky in the window panes.
func _draw_card() -> void:
	if _fx == "kitchen" or _fx == "pages":
		_sky_bands(K_PANE, SKY_NIGHT, 3)
		for s in [Vector2(104, 14), Vector2(110, 20), Vector2(116, 13), Vector2(121, 22), Vector2(106, 30), Vector2(119, 33)]:
			if fmod(_t * 1.1 + s.x * 0.13, 2.0) < 1.6:
				_px(s, "#cae6f5")
		return
	if _fx != "sill" and _fx != "dawn":
		return
	var cols: Array = SKY_STEPS[_sky] if _fx == "dawn" else SKY_NIGHT
	_sky_bands(Rect2(58, 8, 76, 60), cols, 5)
	if _fx == "sill" or _sky <= 1:
		for i in STARS.size():
			var s2: Vector2 = STARS[i]
			var p := Vector2(58 + fmod(s2.x * 0.42, 76.0), 8 + fmod(s2.y, 56.0))
			if fmod(_t * 1.1 + i * 0.5, 2.0) < 1.6:
				_px(p, "#cae6f5")
	if _fx == "dawn" and _sky >= 2:
		var rise := clampf((_t - 1.9) * 7.0, 0.0, 22.0)
		_disc(Vector2(112, 72 - rise), 7.0, "#facb3e", "#ffcc68")


## Flat bands of sky in `r`, each seam a two-row checker dither (stepped, never a gradient).
func _sky_bands(r: Rect2, cols: Array, n: int) -> void:
	var h := int(r.size.y) / n
	for b in n:
		_px(Vector2(r.position.x, r.position.y + h * b), cols[b], Vector2(r.size.x, h if b < n - 1 else r.size.y - h * b))
	for b in range(1, n):
		var y := int(r.position.y) + h * b
		for x in range(int(r.position.x), int(r.end.x)):
			if x % 2 == 0:
				_px(Vector2(x, y - 1), cols[b])
			else:
				_px(Vector2(x, y), cols[b - 1])


## Over the art: stars, the tower clock, windows, smoke, the dial's hands, the fire, flying pages.
func _draw_front() -> void:
	match _fx:
		"house", "lights_on", "lights_lit", "lights_off":
			for i in STARS.size():
				var s: Vector2 = STARS[i]
				if s.y > 50 or (s.x > 22 and s.x < 46 and s.y < 36):
					continue    # not over the moon
				var on := fmod(_t * 1.3 + i * 0.37, 2.0) < 1.55
				_px(s, "#cae6f5" if on else "#414859")
			_clock_hands(Vector2(102, 40), 5.0, 3.5, "#222222")
			if _fx == "house":
				if fmod(_t, 2.3) < 0.12:
					_px(Vector2(70, 70), "#ee8e2e", Vector2(4, 5))   # the candle in the kitchen window gutters
			else:
				for i in mini(_lit, WINDOWS.size()):
					_lit_window(WINDOWS[i], i)
				if _lit <= 0:
					_px(Vector2(70, 70), "#111111", Vector2(4, 5))   # even the kitchen
					_px(Vector2(70, 70), "#140c11", Vector2(4, 1))
				if _lit > WINDOWS.size():
					_round_window()
			_draw_smoke("#7b8994", "#545454")
		"dial":
			_clock_hands(Vector2(96, 48), 29.0, 19.0, "#222222", _dial_a, true)
		"tick":
			_clock_hands(Vector2(96, 48), 29.0, 19.0, "#222222", float(int(_t)) * TAU / 60.0, true)
		"sill", "dawn":
			_draw_smoke("#b6cbcf", "#7b8994")
		"kitchen", "pages":
			_fire()
			_draw_smoke("#b6cbcf", "#7b8994")
			if _fx == "pages":
				_flying_pages()


func _lit_window(p: Vector2, i: int) -> void:
	_px(p, "#facb3e", Vector2(4, 5))
	_px(p, "#ee8e2e", Vector2(4, 1))
	if fmod(_t * 0.9 + i * 0.61, 3.1) > 0.15:   # each candle flickers on its own
		_px(p + Vector2(2, 2), "#fdf7ed")


func _round_window() -> void:
	for y in range(int(ROUND.y - 2), int(ROUND.y + 3)):
		for x in range(int(ROUND.x - 2), int(ROUND.x + 3)):
			if Vector2(x + 0.5, y + 0.5).distance_to(ROUND) <= 2.2:
				_px(Vector2(x, y), "#facb3e")
	_px(ROUND.floor(), "#fdf7ed")


## The kitchen range's fire: each gap between the bars flickers to its own height.
func _fire() -> void:
	for x in K_FIRE:
		var h := 3 + int(2.4 * (sin(_t * 9.0 + x * 1.7) + 1.0) + 1.2 * (sin(_t * 5.3 + x * 0.9) + 1.0))
		for k in h:
			var y := 57 - k
			var c := "#da4e38" if k < 2 else ("#ee8e2e" if k < h - 1 else "#facb3e")
			_px(Vector2(x, y), c)


## The whole story: 24 pages flutter down from above and land in the diary on the table, one by one.
func _flying_pages() -> void:
	for i in Diary.TOTAL:
		var t0 := 0.3 + i * 0.11
		var k := clampf((_t - t0) / 1.2, 0.0, 1.0)
		if k <= 0.0 or k >= 1.0:
			continue
		var from := Vector2(14 + fmod(i * 37.0, 164.0), -6.0 - float(i % 4) * 5.0)
		var p := from.lerp(DIARY_AT, k * k * (3.0 - 2.0 * k))
		p.x += sin(_t * 7.0 + i) * 3.0 * (1.0 - k)
		_px(p - Vector2(2, 1), "#222222", Vector2(5, 4))
		_px(p - Vector2(1, 0), "#fdf7ed", Vector2(3, 2))
		_px(p + Vector2(1, 1), "#d3bfa9")
	if _lit > 0 and fmod(_t, 0.24) < 0.16:   # the diary glows as they come home
		for o in [Vector2(-8, -3), Vector2(8, -3), Vector2(-6, -5), Vector2(6, -5), Vector2(0, -6)]:
			_px(DIARY_AT + o, "#facb3e")


func _disc(c: Vector2, r: float, col: String, core: String) -> void:
	for y in range(int(c.y - r), int(c.y + r) + 1):
		if y >= 68:
			continue    # below the panes: hidden by the window frame
		for x in range(int(c.x - r), int(c.x + r) + 1):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= r:
				_px(Vector2(x, y), core if d < r - 2.5 else col)


func _draw_smoke(c1: String, c2: String) -> void:
	for s in _smoke:
		var a: float = s[1]
		if a < 0.0:
			continue
		var p: Vector2 = s[0] + Vector2(sin(a * 2.2) * 3.0 + a * 4.0, -a * 9.0)
		_px(p, c1 if a < 1.2 else c2, Vector2(2, 2) if a < 1.6 else Vector2.ONE)


## Clock hands drawn pixel by pixel. `spin` adds to both (the dial running down).
func _clock_hands(c: Vector2, lm: float, lh: float, col: String, spin := 0.0, thick := false) -> void:
	var am := fmod(_clock, 60.0) / 60.0 * TAU + spin
	var ah := fmod(_clock / 60.0, 12.0) / 12.0 * TAU + spin / 12.0
	for pair in [[am, lm, 1.0], [ah, lh, 2.0 if thick else 1.0]]:
		var d := Vector2(sin(pair[0]), -cos(pair[0]))
		var n := int(pair[1])
		for i in n:
			var p: Vector2 = c + d * i
			_px(p, col, Vector2(pair[2], pair[2]) if i < n - 2 else Vector2.ONE)
	if thick:
		_px(c - Vector2(2, 2), "#c56025", Vector2(4, 4))
		_px(c - Vector2(1, 1), "#facb3e", Vector2(2, 2))


# ---------------------------------------------------------------- credits

func _start_roll() -> void:
	for c in _stage.get_children():
		c.queue_free()
	_roll = VBoxContainer.new()
	_roll.add_theme_constant_override("separation", 3)
	_roll.custom_minimum_size = Vector2(_vs.x, 0)
	_roll.size = Vector2(_vs.x, 0)
	_roll.position = Vector2(0, _vs.y + 4)
	_root.add_child(_roll)
	if Art.has("ui/title_logo"):
		var logo := TextureRect.new()
		logo.texture = Art.tex("ui/title_logo")
		logo.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		logo.custom_minimum_size = Vector2(0, Art.tex("ui/title_logo").get_height())
		_roll.add_child(logo)
	_line(L.t("{ending}   -   DONE BY {time}", {"ending": Diary.ending_name(ending).to_upper(), "time": Game.clock_text(_clock)}), UI.GOLD)
	_gap(14)
	for sec in _credits():
		_line(sec[0], UI.GOLD)
		for l in sec[1]:
			_line(l, UI.CREAM)
		_gap(10)
	_gap(30)
	var thanks := UI.label(L.t("THANK YOU FOR PLAYING"), 16, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_roll.add_child(thanks)
	_line(_last_line(), UI.CREAM)
	_rolling = true
	Audio.play("page_flip", -6.0)


func _last_line() -> String:
	match ending:
		"housekeeper": return L.t("The kitchen light is on. Somebody is expected.")
		"windows": return L.t("Every window in the house is lit.")
		"whole_story": return L.t("Martha kept this house for sixty-one years. {name} let it rest.", {"name": str(Candles.def_of(_candle)["name"])})
	return L.t("The house is quiet now.")


func _line(text: String, col: Color) -> void:
	var l := UI.label(text, 8, col, HORIZONTAL_ALIGNMENT_CENTER)
	l.custom_minimum_size = Vector2(_vs.x, 9)
	_roll.add_child(l)


func _gap(h: int) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	_roll.add_child(c)


func _credits() -> Array:
	var guardians: Array = []
	for k in Enemy.DEFS.keys():
		var d: Dictionary = Enemy.DEFS[k]
		if d.get("boss", false):
			guardians.append(str(d["name"]))
	var champs: Array = []
	if Specials.MINIS.size() > 0:
		for k in Specials.MINIS.keys():
			champs.append(str(Specials.MINIS[k]["name"]))
	var cast: Array = []
	for i in range(0, guardians.size(), 2):
		cast.append("   ".join(guardians.slice(i, i + 2)))
	var champ_lines: Array = []
	for i in range(0, champs.size(), 2):
		champ_lines.append("   ".join(champs.slice(i, i + 2)))
	var pages := preload("res://scripts/ui/credits_pages.gd")
	var household: Array = []
	if Diary.count() > 0:   # once the diary has introduced them
		household = [[L.t("THE HOUSEHOLD"), [L.t("Martha Fenn, housekeeper, who kept the diary"), L.t("Cook, Mr. Pennock, Miss Tibbet, Big Walter and Wilf")]]]
	return [
		["MADE BY", ["One developer, with Claude (AI)"]],
		["MADE FOR THIS GAME", ["Tallow, %s," % pages.cast_line(true), "the relics, the rooms, the Clock Tower and every effect",
			"(pixel art drawn by scripts written with Claude, checked by the developer)"]],
		["DUNGEON ART", ["0x72 - 16x16 DungeonTileset II (CC0)", "the dungeon tiles, %s" % pages.cast_line(false)]],
		["MUSIC", ["Ninja Adventure Asset Pack by Pixel-boy and AAA (CC0)",
			"Dream - Crypt - Dungeon - Temple - Final Area", "Boat - Fight - Tension - Ascension - Credit Theme",
			"Curse - Ruins - Melancholia", "Jingles: original, made for this game"]],
		["SOUND", ["Kenney audio packs (CC0)", "Ninja Adventure sounds (CC0)", "Original synthesis"]],
		["FONTS", ["Kenney Pixel and Kenney Mini by Kenney (CC0)"]],
		["ENGINE", ["Godot Engine (MIT) - godotengine.org/license"]],
		["LICENCES AND PRIVACY", ["Title screen > Credits", "The game collects no data"]],
		["THE GUARDIANS", cast],
		["THE HOUSE CHAMPIONS", champ_lines],
		["AND", ["Every lodger, moth and melt drop in the house", "Tallow, the last candle in the cellar"]],
	] + household
