class_name Ending
extends CanvasLayer
## The true ending (after the Keeper of Hours falls): four short pixel-art scenes with a line each,
## a credits roll, then the results screen marked TRUE ENDING (world._end_run via the callback).
##   1. The house is quiet: the manor under the moon, one lit window, chimney smoke.
##   2. The clock stops at the time you finished: the tower dial's hands run down and stop.
##   3. Tallow's flame settles on the sill under the night sky.
##   4. Dawn comes: the sky lightens step by step, the sun comes up, the little flame goes out.
## Scenes are 192x96 art (tools/art_tower.py, tower/end_*) shown at x2; the moving parts are drawn here
## in the same palette. Any key, click, tap or pad button skips everything after the first scene.

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

var _clock := 0.0
var _candle := "tallow"
var _done: Callable
var _root: Control
var _vs := Vector2(384, 216)
var _card := -1
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
	if _card >= 4:
		_start_roll()
		return
	_art = Node2D.new()
	_art.draw.connect(func(): _cv = _art; _draw_card())
	_front = Node2D.new()
	_front.draw.connect(func(): _cv = _front; _draw_front())
	var lines: Array = []
	var name := str(Candles.def_of(_candle)["name"])
	_stage.add_child(_art)
	match _card:
		0:
			_add_tex("tower/end_house")
			_stage.add_child(_front)
			lines = ["THE HOUSE IS QUIET", "Every lodger is asleep. Even the stairs."]
		1:
			_add_tex("tower/end_dial")
			_stage.add_child(_front)
			_dial_a = -TAU * 3.0
			_dial_stopped = false
			lines = ["THE CLOCK STOPS AT %s" % Game.clock_text(_clock), "It will not strike two tonight."]
		2:
			_sky = 0
			_add_tex("tower/end_window")
			_stage.add_child(_front)
			_add_hero()
			lines = ["%s'S FLAME SETTLES" % name.to_upper(), "No draught, no hands, no hurry. Just a small, warm light."]
		3:
			_sky = 0
			_add_tex("tower/end_window")
			_stage.add_child(_front)
			_add_hero()
			lines = ["DAWN COMES FOR THE LITTLE CANDLE", "Sleep well, %s." % name]
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


func _add_hero() -> void:
	_hero = Player.new()
	_hero.world = null
	_stage.add_child(_hero)
	_hero.set_physics_process(false)
	_hero.apply_candle(_candle)
	_hero.wax = 70.0
	_hero.light.enabled = false
	_hero.glow.enabled = false
	_hero.position = Vector2(96, 71)
	_hero._happy_face = 999.0
	if _card == 2:
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
	match _card:
		1:
			if not _dial_stopped:
				var k := clampf(_t / 2.6, 0.0, 1.0)
				var was := _dial_a
				_dial_a = -TAU * 3.0 * pow(1.0 - k, 3.0)
				if int(was / (TAU / 12.0)) != int(_dial_a / (TAU / 12.0)):
					Audio.play("tick", -8.0, 0.0, 1.0 + k * 0.5)
				if k >= 1.0:
					_dial_stopped = true
					Audio.play("bell_small", -4.0, 0.0, 0.9)
		2:
			_sky = 0
		3:
			_sky = clampi(int((_t - 0.4) / 0.75), 0, SKY_STEPS.size() - 1)
			if _hero and _t > 3.3 and _hero.flame.visible:
				_hero.flame.visible = false
				Audio.play("snuff_out", -8.0, 0.0, 1.2)
				for i in 6:
					_smoke.append([Vector2(96, 54), -i * 0.22])   # a thread of smoke, puff after puff
	if _card == 0 and fmod(_t, 0.9) < dt:
		_smoke.append([Vector2(136, 37), 0.0])
	for s in _smoke:
		s[1] += dt
	_smoke = _smoke.filter(func(s): return s[1] < 2.6)
	if _art and is_instance_valid(_art):
		_art.queue_redraw()
	if _front and is_instance_valid(_front):
		_front.queue_redraw()


func _px(p: Vector2, c: String, sz := Vector2.ONE) -> void:
	_cv.draw_rect(Rect2(p.round(), sz), Color(c))


func _draw_card() -> void:
	if _card != 2 and _card != 3:
		return
	var cols: Array = SKY_STEPS[_sky] if _card == 3 else SKY_NIGHT
	for b in 5:
		_px(Vector2(58, 8 + 12 * b), cols[b], Vector2(76, 12))
	for b in range(1, 5):   # a two-row checker dither on each seam (stepped, never a gradient)
		var y := 8 + 12 * b
		for x in range(58, 134):
			if x % 2 == 0:
				_px(Vector2(x, y - 1), cols[b])
			else:
				_px(Vector2(x, y), cols[b - 1])
	if _card == 2 or _sky <= 1:
		for i in STARS.size():
			var s2: Vector2 = STARS[i]
			var p := Vector2(58 + fmod(s2.x * 0.42, 76.0), 8 + fmod(s2.y, 56.0))
			if fmod(_t * 1.1 + i * 0.5, 2.0) < 1.6:
				_px(p, "#cae6f5")
	if _card == 3 and _sky >= 2:
		var rise := clampf((_t - 1.9) * 7.0, 0.0, 22.0)
		_disc(Vector2(112, 72 - rise), 7.0, "#facb3e", "#ffcc68")


func _draw_front() -> void:
	match _card:
		0:
			for i in STARS.size():
				var s: Vector2 = STARS[i]
				if s.y > 50 or (s.x > 22 and s.x < 46 and s.y < 36):
					continue    # not over the moon
				var on := fmod(_t * 1.3 + i * 0.37, 2.0) < 1.55
				_px(s, "#cae6f5" if on else "#414859")
			_clock_hands(Vector2(102, 40), 5.0, 3.5, "#222222")
			if fmod(_t, 2.3) < 0.12:
				_px(Vector2(70, 70), "#ee8e2e", Vector2(4, 5))   # the candle in the window gutters
			_draw_smoke("#7b8994", "#545454")
		1:
			_clock_hands(Vector2(96, 48), 29.0, 19.0, "#222222", _dial_a, true)
		2, 3:
			_draw_smoke("#b6cbcf", "#7b8994")


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
	_line("TRUE ENDING   -   DONE BY %s" % Game.clock_text(_clock), UI.GOLD)
	_gap(14)
	for sec in _credits():
		_line(sec[0], UI.GOLD)
		for l in sec[1]:
			_line(l, UI.CREAM)
		_gap(10)
	_gap(30)
	var thanks := UI.label("THANK YOU FOR PLAYING", 16, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_roll.add_child(thanks)
	_line("The house is quiet now.", UI.CREAM)
	_rolling = true
	Audio.play("page_flip", -6.0)


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
	return [
		["DESIGN, CODE AND PIXEL ART", ["Made for you with Claude"]],
		["DUNGEON ART", ["0x72 - 16x16 DungeonTileset II (CC0)"]],
		["ORIGINAL ART", ["Tallow, the house, its lodgers, the relics and the Clock Tower:", "drawn pixel by pixel for this game"]],
		["MUSIC", ["Ninja Adventure Asset Pack by Pixel-boy and AAA (CC0)",
			"Dream - Crypt - Dungeon - Temple - Final Area", "Boat - Fight - Tension - Ascension - Credit Theme",
			"Jingles: original, made for this game"]],
		["SOUND", ["Kenney audio packs (CC0)", "Ninja Adventure sounds (CC0)", "Original synthesis"]],
		["FONTS", ["Kenney Pixel and Kenney Mini by Kenney (CC0)"]],
		["ENGINE", ["Godot Engine (MIT)"]],
		["THE GUARDIANS", cast],
		["THE HOUSE CHAMPIONS", champ_lines],
		["AND", ["Every lodger, moth and melt drop in the house", "Tallow, the last candle in the cellar"]],
	]
