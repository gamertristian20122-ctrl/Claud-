class_name Ending
extends CanvasLayer
## The endings: three or four short scenes with a line each, a credits roll, then the results screen
## (world._end_run via the callback). Which ending plays is `ending` (v2.5, Diary.ENDINGS; chosen by
## Diary.win_ending / Diary.keeper_ending):
##   true          the Keeper of Hours stilled: the hall is quiet, the clock stops at the time you finished and the
##                 light in the tower goes out, Tallow's flame settles on the sill, dawn comes and it goes out.
##   windows       a won night of seven floors or more: the clock stops, a candle lights in every window, one
##                 for everyone who lived here, Tallow kept the small hours.
##   housekeeper   a won night with 12+ diary pages, and
##   whole_story   the Keeper stilled with all 24 pages: both wait on the diary pages (Diary.PAGES_ON, off in 2.10).
## Scenes are 192x96, shown at x2. Since 2.10 they are found pictures (tools/free_art.py story()): Luis Zuno's
## night town in two layers (houses, clouds) and rooms laid out of the game's own tiles. What moves is drawn here,
## in the pictures' own colours: a window lit or put out, the clouds' tint from night to dawn, smoke.
## Any key, click, tap or pad button skips everything after the first scene.

const CARD := 5.0
const FADE := 0.6
const ROLL_SPEED := 26.0
const SKY := "story/clouds"
const SKY_DRIFT := 1.5        # px a second the clouds drift (whole pixels; not with Reduce motion)
const SKY_X := 64.0           # the clouds are 256 wide, the scene 192: the part behind the town, before any drift
## The clouds' tint: night, then the steps of the dawn, up to the gold the picture was painted in.
const SKY_TINTS := [Color(0.45, 0.55, 0.75), Color(0.58, 0.64, 0.78), Color(0.72, 0.74, 0.8), Color(0.86, 0.86, 0.88),
	Color(1, 1, 1)]
## The scenes, back to front: [picture, where]. An outdoor scene's first layer is its clouds; a room has two
## frames (its torches flicker).
const SCENES := {
	"town": [["story/clouds", Vector2(0, -16)], ["story/town", Vector2(0, -16)]],
	"window": [["story/clouds_low", Vector2.ZERO], ["story/town_low", Vector2.ZERO], ["story/sill", Vector2(0, 64)]],
	"hall": [["story/hall", Vector2.ZERO]],
	"kitchen": [["story/kitchen", Vector2.ZERO]],
}
const TOWN_AT := Vector2(0, -16)     # the town in the endings: its lower 80 rows show above the words
const LOW := Vector2(0, -30)         # the same town seen from the sill (story/town_low is cut 30 rows lower)
## The town's own window colours, so a candle lit here looks like one the picture already has.
const LIT := {"y": "#bbac5c", "Y": "#eccd85"}
const DARK := "#153635"
const HOUSE_WIN := ["yyy", "YYy", "yYy", "yYy", "yyy"]      # the house's lit window, pixel for pixel
const TOWER_WIN := [".yy.", ".yy.", "Yyyy", "Yyyy", "Yyyy", "YYyy", "YYyy", "YYyy"]   # ... and the tower's
const SMALL_WIN := ["yy", "Yy", "yy"]
const HOUSE_LIT := Vector2(34, 63)   # a window the picture has lit (its candle gutters in the opening)
const TOWER_LIT := Vector2(145, 47)  # the tower's lit window: it goes dark when the clock stops
## The town's dark windows, in the order a candle lights them: the house's two, lights across the town, the
## belfry last. [where in story/town, shape]
const WINDOWS := [[Vector2(29, 63), HOUSE_WIN], [Vector2(39, 63), HOUSE_WIN], [Vector2(63, 66), SMALL_WIN],
	[Vector2(83, 74), SMALL_WIN], [Vector2(73, 89), SMALL_WIN], [Vector2(97, 80), SMALL_WIN], [Vector2(136, 69), SMALL_WIN],
	[Vector2(160, 66), SMALL_WIN], [Vector2(172, 88), SMALL_WIN], [Vector2(186, 88), SMALL_WIN], [Vector2(145, 34), TOWER_WIN]]
const LIGHT_GAP := 0.3
## Where Tallow stands: on the sill (the "window" scene), on the kitchen table.
const SILL := Vector2(96, 71)
const TABLE := Vector2(96, 57)
## The kitchen (story/kitchen): the range's fire and the pot's steam, the diary on the table.
const STOVE := Vector2(36, 24)
const K_SPOUT := Vector2(40, 30)
const DIARY_AT := Vector2(112, 53)

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
var _front: Node2D        # drawn over the scene (windows, smoke, sparks)
var _cv: CanvasItem
var _texts: Array = []
var _t := 0.0
var _hero: Player
var _sky := 0
var _sky_spr: Sprite2D    # the clouds of an outdoor scene (tinted, drifting)
var _room_spr: Sprite2D   # a room with torches
var _room_fr: Array = []
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

## The cards of this ending: the scene (SCENES), fx (what moves, see _process / _draw_front), where Tallow stands
## (or none), and the two lines under the scene.
func _card_list() -> Array:
	var name := str(Candles.def_of(_candle)["name"])
	var nm: float = get_parent().night_minutes() if get_parent() and get_parent().has_method("night_minutes") else Game.END_MINUTES
	var floors := int(get_parent().get("night_floors")) if get_parent() and get_parent().get("night_floors") != null else 4
	var stops := L.t("THE CLOCK STOPS AT {time}", {"time": Game.clock_text(_clock)})
	match ending:
		"housekeeper":
			return [
				_c("town", "house", null, L.t("THE HOUSE IS QUIET"), L.t("One window is still lit. It's the kitchen. It always was.")),
				_c("kitchen", "kitchen", null, L.t("MARTHA FENN, HOUSEKEEPER"), L.t("Sixty-one years of keys, lists, mended curtains and seed cake.")),
				_c("kitchen", "kitchen", TABLE, L.t("SHE MADE ONE LAST CANDLE"), L.t("She lit him every night for a year, until he could light himself.")),
				_c("hall", "tick", null, L.t("SOMETHING STILL TICKS ABOVE THE BELLS"), L.t("At twelve the Keeper will wind the clock again. Unless someone is early.")),
			]
		"windows":
			return [
				_c("town", "dial", null, stops, L.t("It will not strike {hour} tonight.", {"hour": Records.hour_words(nm)})),
				_c("town", "lights_on", null, L.t("A CANDLE IN EVERY WINDOW"), L.t("The Kitchen, the Library, the Attic: lit again after all these years.")),
				_c("town", "lights_lit", null, L.t("ONE FOR EVERYONE WHO LIVED HERE"), L.t("One for Cook. One for Miss Tibbet. One for Wilf, who hated the dark.")),
				_c("window", "sill", SILL, L.t("{name} KEPT THE SMALL HOURS", {"name": name.to_upper()}),
					L.t("{floors} floors, every room, and not one of them forgotten.", {"floors": Records.number_word(floors).capitalize()})),
			]
		"whole_story":
			return [
				_c("town", "dial", null, stops, L.t("Nobody will wind it tomorrow. The Keeper has earned its rest.")),
				_c("town", "lights_off", null, L.t("THE ROUNDS ARE DONE"), L.t("The pot cools. The organ breathes out. The Gaoler hangs up its keys.")),
				_c("kitchen", "pages", null, L.t("THE DIARY IS WHOLE"), L.t("Twenty-four pages, home by her chair.")),
				_c("window", "dawn", SILL, L.t("DAWN COMES FOR THE LITTLE CANDLE"),
					L.t("Sleep well, Tallow. Martha kept your seat by the fire.") if _candle == "tallow" else L.t("Sleep well, {name}. The house is all done.", {"name": name})),
			]
	return [
		_c("hall", "quiet", null, L.t("THE HOUSE IS QUIET"), L.t("Every lodger is asleep. Even the stairs.")),
		_c("town", "dial", null, stops, L.t("It will not strike {hour} tonight.", {"hour": Records.hour_words(nm)})),
		_c("window", "sill", SILL, L.t("{name}'S FLAME SETTLES", {"name": name.to_upper()}), L.t("No draught, no hands, no hurry. Just a small, warm light.")),
		_c("window", "dawn", SILL, L.t("DAWN COMES FOR THE LITTLE CANDLE"), L.t("Sleep well, {name}.", {"name": name})),
	]


func _c(scene: String, fx: String, hero: Variant, l1: String, l2: String) -> Dictionary:
	return {"scene": scene, "fx": fx, "hero": hero, "lines": [l1, l2]}


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
	_sky_spr = null
	_room_spr = null
	_t = 0.0
	_lit = 0
	_ticked = 0
	if _card >= _cards.size():
		_start_roll()
		return
	var cd: Dictionary = _cards[_card]
	_fx = str(cd["fx"])
	_front = Node2D.new()
	_front.draw.connect(func(): _cv = _front; _draw_front())
	var lines: Array = cd["lines"]
	_add_scene(str(cd["scene"]))
	_stage.add_child(_front)
	_sky = 0
	if _fx == "dial":
		_dial_a = -TAU * 3.0
		_dial_stopped = false
	if _fx == "lights_lit" or _fx == "lights_off":
		_lit = WINDOWS.size()
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
	# v2.7: one card of each ending closes with a few words (the candle and Martha's memory; scripts/ui/talk.gd)
	var beat := Talk.ending_lines(self, ending, _card, _candle)
	if not beat.is_empty():
		tw.tween_interval(1.8)
		tw.tween_callback(func(): Talk.ending_beat(_root, beat, _candle, [t1, t2], _card_out.bind(t1, t2, null)))
		return
	tw.tween_interval(CARD - FADE * 2.0)
	_card_out(t1, t2, tw)


## The card's end: the scene and its lines fade, then the next card (v2.7: after a closing beat, on a fresh tween).
func _card_out(t1: Label, t2: Label, tw: Tween) -> void:
	if tw == null:
		tw = create_tween()
		tw.tween_interval(0.5)
	tw.tween_property(_stage, "modulate:a", 0.0, FADE)
	tw.parallel().tween_property(t1, "modulate:a", 0.0, FADE)
	tw.parallel().tween_property(t2, "modulate:a", 0.0, FADE)
	tw.tween_callback(_next_card)


## The scene's layers as sprites (SCENES), back to front.
func _add_scene(key: String) -> void:
	var layers: Array = SCENES.get(key, [])
	for i in layers.size():
		var path := str(layers[i][0])
		var s := Sprite2D.new()
		s.centered = false
		s.position = layers[i][1]
		var fr := Art.seq(path)
		s.texture = fr[0]
		if i == 0 and layers.size() > 1:   # the clouds: a 192-wide window on the 256-wide picture
			_sky_spr = s
			s.region_enabled = true
			s.region_rect = Rect2(SKY_X, 0, 192, 96)
			s.modulate = SKY_TINTS[0]
		elif fr.size() > 1:
			_room_spr = s
			_room_fr = fr
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
			_sky = clampi(int((_t - 0.4) / 0.75), 0, SKY_TINTS.size() - 1)
			if _hero and _t > 3.3 and _hero.flame.visible:
				_hero.flame.visible = false
				Audio.play("snuff_out", -8.0, 0.0, 1.2)
				for i in 6:
					_smoke.append([Vector2(96, 54), -i * 0.22])   # a thread of smoke, puff after puff
		"lights_on":   # a candle in every window, one after another
			var n := clampi(int((_t - 0.5) / LIGHT_GAP) + 1, 0, WINDOWS.size()) if _t > 0.5 else 0
			if n > _lit:
				_lit = n
				Audio.play("tick", -10.0, 0.02, 1.4 + 0.04 * n)
		"lights_off":  # the rounds are done: the windows go dark again
			var n2 := clampi(WINDOWS.size() - int((_t - 0.6) / LIGHT_GAP), 0, WINDOWS.size()) if _t > 0.6 else WINDOWS.size()
			if n2 < _lit:
				_lit = n2
				Audio.play("tick", -12.0, 0.02, 1.2 - 0.03 * (WINDOWS.size() - n2))
		"pages":
			var landed := clampi(int((_t - 0.3 - 1.2) / 0.11) + 1, 0, Diary.TOTAL)
			if landed > _lit:
				_lit = landed
				Audio.play("page_flip", -12.0, 0.08, 1.3)
	if (_fx == "kitchen" or _fx == "pages") and fmod(_t, 0.8) < dt:
		_smoke.append([K_SPOUT, 0.0])   # the pot on the range
	for s in _smoke:
		s[1] += dt
	_smoke = _smoke.filter(func(s): return s[1] < 2.6)
	if _sky_spr and is_instance_valid(_sky_spr):   # the clouds: the hour's tint, a slow drift
		_sky_spr.modulate = SKY_TINTS[_sky]
		if not UI.calm():
			_sky_spr.region_rect.position.x = SKY_X - floorf(minf(_t * SKY_DRIFT, 40.0))
	if _room_spr and is_instance_valid(_room_spr) and not UI.calm():   # the torches
		_room_spr.texture = _room_fr[int(_t * 5.0) % _room_fr.size()]
	if _front and is_instance_valid(_front):
		_front.queue_redraw()


func _px(p: Vector2, c: String, sz := Vector2.ONE) -> void:
	_cv.draw_rect(Rect2(p.round(), sz), Color(c))


## A scene picture by name, for a drawing call: a room has two frames (its torches flicker), the rest have one.
static func scene_tex(path: String, t: float) -> Texture2D:
	var fr := Art.seq(path)
	return fr[0 if UI.calm() else int(t * 5.0) % fr.size()]


## A window of the town, painted over the picture: "lit" as the picture lights its own, "dim" (a candle
## guttering) or "dark".
static func paint_window(ci: CanvasItem, at: Vector2, rows: Array, how: String) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			var col: String = DARK
			if how == "lit":
				col = LIT[ch]
			elif how == "dim":
				col = LIT["y"]
			ci.draw_rect(Rect2(at + Vector2(x, y), Vector2.ONE), Color(col))


## The kitchen range's fire: the game's own stove flame (areas/kitchen/stove_glow), frame by frame.
static func paint_fire(ci: CanvasItem, t: float) -> void:
	var fr := Art.seq("areas/kitchen/stove_glow")
	ci.draw_texture(fr[int(t * 8.0) % fr.size()], STOVE)


## Over the scene: the town's windows, smoke, the fire, flying pages.
func _draw_front() -> void:
	match _fx:
		"house":   # the kitchen's candle gutters now and then
			if fmod(_t, 2.3) < 0.12:
				paint_window(_front, HOUSE_LIT + TOWN_AT, HOUSE_WIN, "dim")
		"dial":    # the clock stops: the light in the tower goes out
			if _dial_stopped:
				paint_window(_front, TOWER_LIT + TOWN_AT, TOWER_WIN, "dark")
		"lights_on", "lights_lit", "lights_off":
			_candles(TOWN_AT, _lit)
		"sill", "dawn":
			# the same town from the sill: the tower as the night left it
			if ending == "windows":
				_candles(LOW, WINDOWS.size())
			else:
				paint_window(_front, TOWER_LIT + LOW, TOWER_WIN, "dark")
			_draw_smoke("#b6cbcf", "#7b8994")
		"kitchen", "pages":
			paint_fire(_front, _t)
			_draw_smoke("#b6cbcf", "#7b8994")
			if _fx == "pages":
				_flying_pages()


## The first `n` of the town's dark windows with a candle in them (each flickers on its own), the town drawn
## at `at`. Until the tower's turn comes its own window stays dark: the clock has stopped.
func _candles(at: Vector2, n: int) -> void:
	for i in mini(n, WINDOWS.size()):
		var w: Array = WINDOWS[i]
		var gutter := fmod(_t * 0.9 + i * 0.61, 3.1) < 0.15
		paint_window(_front, w[0] + at, w[1], "dim" if gutter else "lit")
	if n < WINDOWS.size():
		paint_window(_front, TOWER_LIT + at, TOWER_WIN, "dark")


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


func _draw_smoke(c1: String, c2: String) -> void:
	for s in _smoke:
		var a: float = s[1]
		if a < 0.0:
			continue
		var p: Vector2 = s[0] + Vector2(sin(a * 2.2) * 3.0 + a * 4.0, -a * 9.0)
		_px(p, c1 if a < 1.2 else c2, Vector2(2, 2) if a < 1.6 else Vector2.ONE)


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
	var household: Array = []
	if Diary.count() > 0:   # once the diary has introduced them
		household = [[L.t("THE HOUSEHOLD"), [L.t("Martha Fenn, housekeeper, who kept the diary"), L.t("Cook, Mr. Pennock, Miss Tibbet, Big Walter and Wilf")]]]
	return [
		["MADE BY", ["One developer, with Claude (AI): the design, the code and the words"]],
		["THE CANDLES", ["Tallow and the other candles, their costumes and flames",
			"(pixel art drawn by scripts written with Claude, checked by the developer)"]],
		["ART FROM FREE PACKS (CC0)", ["0x72 - 16x16 DungeonTileset II: the house's stones and many lodgers",
			"Pixel-boy and AAA - Ninja Adventure: lodgers, guardians, relics, effects",
			"Kenney - Roguelike Indoors, Tiny Dungeon, Cursor Pixel Pack",
			"Alex's Assets - 16x16 RPG Item Pack", "Foozle (drawn by Baldur) - Lucifer: Ancient Skeleton",
			"Luis Zuno (ansimuz) - Gothicvania Patreon's Collection", "Not Jam - Haunted Hotel Asset Pack"]],
		["MUSIC", ["Ninja Adventure Asset Pack by Pixel-boy and AAA (CC0)",
			"Dream - Crypt - Dungeon - Temple - Final Area", "Boat - Fight - Tension - Ascension - Credit Theme",
			"Curse - Ruins - Melancholia", "and the pack's own jingles"]],
		["SOUND", ["Kenney audio packs (CC0)", "Ninja Adventure sounds (CC0)", "each sound a pack file, as it is"]],
		["FONTS", ["Kenney Pixel and Kenney Mini by Kenney (CC0)"]],
		["ENGINE", ["Godot Engine (MIT) - godotengine.org/license"]],
		["LICENCES AND PRIVACY", ["Title screen > Credits", "The game collects no data"]],
		["THE GUARDIANS", cast],
		["THE HOUSE CHAMPIONS", champ_lines],
		["AND", ["Every lodger, moth and melt drop in the house", "Tallow, the last candle in the cellar"]],
	] + household
