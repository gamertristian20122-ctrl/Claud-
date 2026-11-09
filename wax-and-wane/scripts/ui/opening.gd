class_name Opening
extends Control
## The story's opening (v2.7 dialogue stream, docs/streams/v27_dialogue.md): four gently animated panels with a line or
## two of narration each (about 30 s; the lines are TalkLines.OPENING):
##   house    the house at midnight: stars, the chimney smoking, one window lit, the tower clock nearly at twelve
##   dial     the great clock: the hands reach twelve, the bell strikes
##   kitchen  Martha's kitchen at midnight: she strikes a match and lights Tallow on her table ("Good evening, Tallow.");
##            he cries a drop of wax at the match, then beams
##   cellar   the cellar in the dark: the match strikes itself, Tallow wakes alone, looks for her, and goes up anyway
## The art is the v2.5 / tower ending scenes (tower/end_house, tower/end_dial, story/end_kitchen) and two new pieces from
## tools/art_talk.py (talk/martha_stand|match|light, talk/open_cellar); the moving parts are drawn here in the same
## palette, Tallow from his own body code (TalkPortrait.paint_candle). Shown x2 like the endings.
## Lines type out (Martha and Tallow with their talking voices) and move on by themselves; a tap / key / button moves
## on sooner, Skip / Esc / B / Back end it. Reduce motion: lines appear whole, no drift, plain cuts.
## Where it plays:
##   - a slot's first run: main.goto("game") comes here first when Opening.wanted() (the slot has no runs and has not
##     seen it, and no test is driving the game), then goes on to the run with the same params (and the run's own
##     controls primer plays in the run, after this)
##   - the Journal's Diary tab, "Watch the beginning" (Opening.watch: over the Journal, which comes back after)
## Records: Talk.note("opening"); an older slot that never saw it gets the Journal's gold dot ("d:opening").

const CPS := 50.0
const HOLD := 0.7             # s a line stays once typed, plus PER_CHAR a letter
const PER_CHAR := 0.012
const FADE := 0.4             # s each way between panels
const TAP_HOLD := 0.35        # s: a press this early was meant for the screen before
const BAND := 46.0            # the narration band along the bottom
const ART := {"house": "tower/end_house", "dial": "tower/end_dial", "kitchen": "story/end_kitchen", "cellar": "talk/open_cellar"}
const TABLE := Vector2(98, 60)      # Tallow's feet on the kitchen table
const CELLAR := Vector2(96, 82)     # ... in Martha's chalk circle
const MATCH_TIP := Vector2(32, 2)   # the match flame in Martha's "light" pose (tools/art_talk.py MATCH_TIP)
const DOOR_LIGHT := [Rect2(176, 15, 14, 1), Rect2(179, 3, 1, 1), Rect2(186, 6, 1, 1), Rect2(178, 10, 1, 1)]
const TOWER_CLOCK := Vector2(102, 40)
const CHIMNEY := Vector2(136, 37)
const KITCHEN_WINDOW := Vector2(70, 70)
const DIAL := Vector2(96, 48)

var params := {}          # the run to light afterwards (as a screen)
var overlay := false      # over the Journal
var done: Callable
var _lines: Array = []
var _i := -1
var _state := "in"        # in / line / out / end
var _st := 0.0            # s in this state
var _shown := 0.0
var _hold := 0.0
var _t := 0.0
var _pt := 0.0            # s since this panel began
var _lt := 0.0            # s since this line began
var _panel := ""
var _first := 0           # the first line of this panel
var _fade := 1.0
var _closing := false
var _us := 0
var _cue := {}
var _smoke: Array = []
var _shake := 0.0
var _stage: Node2D
var _black: ColorRect
var _text: Label
var _who: Label
var _skip: Button
var _hint: Label
var _voice: AudioStreamPlayer
var _blips := 0
var _streams := {}


## main.goto("game", params): a slot's first run opens with the story first (the run follows with the same params).
static func wanted(main: Node, p: Dictionary) -> bool:
	if p.get("opened", false):
		return false
	var testing: bool = main != null and main.get("autotest") != null and main.autotest != null
	if testing and not Talk.force:
		return false
	if Talk.seen("opening"):
		return false
	if int(Game.records.get("runs", 0)) > 0:
		Records.mark_new("d:opening")   # an older slot: the Journal's Diary tab shows it waiting (Watch the beginning)
		return false
	return true


## The Journal's Diary tab: watch it again, over the Journal.
static func watch(parent: Control, on_done := Callable()) -> Opening:
	var o := Opening.new()
	o.overlay = true
	o.done = on_done
	parent.add_child(o)
	return o


## As a screen (main.SCREENS "opening"): the params of the run that follows.
func setup(p: Dictionary) -> void:
	params = p.duplicate()


func _ready() -> void:
	name = "Opening"
	set_meta("modal", true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_lines = TalkLines.OPENING
	var vs := get_viewport().get_visible_rect().size
	var bg := ColorRect.new()
	bg.color = Color("#140c11")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_stage = Node2D.new()
	_stage.scale = Vector2(2, 2)
	_stage.draw.connect(_draw_stage)
	add_child(_stage)
	_black = ColorRect.new()
	_black.color = Color("#140c11")
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	var band := ColorRect.new()
	band.color = UI.VOID
	band.position = Vector2(0, vs.y - BAND)
	band.size = Vector2(vs.x, BAND)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	var rule := ColorRect.new()
	rule.color = UI.BRASS_DARK
	rule.position = Vector2(0, vs.y - BAND)
	rule.size = Vector2(vs.x, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)
	# the band (the art keeps its corners: the moon, the stairs' lit door): how to go on and who speaks on its top row,
	# the line under them, Skip on the right
	var col_w := minf(340.0, vs.x - 76.0)
	var col_x := floorf((vs.x - 62.0 - col_w) / 2.0)
	_who = UI.label("", 8, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_who.position = Vector2(col_x, vs.y - BAND + 4.0)
	_who.size = Vector2(col_w, 10)
	add_child(_who)
	_text = UI.label("", 8, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_text.size = Vector2(col_w, 24)
	_text.position = Vector2(col_x, vs.y - BAND + 15.0)
	add_child(_text)
	_hint = UI.label(_hint_text(), 8, UI.DIM)
	_hint.position = Vector2(6, vs.y - BAND + 4.0)
	add_child(_hint)
	_skip = UI.button(L.t("Skip"), func(): pass, 52)
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.mouse_filter = Control.MOUSE_FILTER_IGNORE   # hit-tested in _input
	_skip.position = Vector2(vs.x - 58.0, vs.y - BAND + 11.0)
	add_child(_skip)
	_voice = AudioStreamPlayer.new()
	_voice.bus = "SFX"
	_voice.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_voice)
	_layout()
	_us = Time.get_ticks_usec()
	_panel = str(_lines[0]["panel"])
	_i = 0
	_first = 0
	_state = "in"
	_text.text = ""
	_who.text = ""


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	# the 384 x 192 scene centred in the room above the band
	_stage.position = Vector2(floorf((vs.x - 384.0) / 2.0), floorf((vs.y - BAND - 192.0) / 2.0))
	_black.position = _stage.position
	_black.size = Vector2(384, 192)


func _hint_text() -> String:
	match Controls.device:
		"touch": return L.t("Tap to go on")
		"mouse": return L.t("Click to go on")
		"gamepad": return L.t("Any button: next   B: skip")
	return L.t("Any key: next   Esc: skip")


# ---------------------------------------------------------------- the flow

func _process(_dt: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := clampf(float(now - _us) / 1000000.0, 0.0, 0.1)
	_us = now
	_t += dt
	_st += dt
	_pt += dt
	_lt += dt
	_shake = maxf(0.0, _shake - dt)
	match _state:
		"in":
			_fade = 0.0 if UI.calm() else clampf(1.0 - _st / FADE, 0.0, 1.0)
			if _st >= (0.0 if UI.calm() else FADE):
				_start_line()
		"line":
			_type(dt)
		"out":
			_fade = 1.0 if UI.calm() else clampf(_st / FADE, 0.0, 1.0)
			if _st >= (0.0 if UI.calm() else FADE):
				if _i >= _lines.size():
					_finish()
					return
				_panel = str(_lines[_i]["panel"])
				_first = _i
				_pt = 0.0
				_cue.clear()
				_smoke.clear()
				_text.text = ""   # the last panel's line leaves with it
				_who.text = ""
				_state = "in"
				_st = 0.0
	_black.color.a = _fade
	_cues()
	_smoke_step(dt)
	_stage.queue_redraw()


func _start_line() -> void:
	_state = "line"
	_st = 0.0
	_lt = 0.0
	_fade = 0.0
	var ln: Dictionary = _lines[_i]
	var who := str(ln.get("who", ""))
	_who.text = TalkLines.speaker_name(who, "tallow") if who != "" else ""
	_text.text = L.t(str(ln.get("text", "")))
	_shown = 0.0
	_blips = 0
	if UI.calm():
		_shown = float(_text.get_total_character_count())
	_text.visible_characters = int(_shown)
	_hold = HOLD + PER_CHAR * _text.text.length() + _extra_hold()


func _extra_hold() -> float:
	return extra_for(_panel, _i - _first)


## Some lines wait for their animation (the match, the cellar lighting up, Tallow looking round for her).
static func extra_for(panel: String, pl: int) -> float:
	if panel == "kitchen" and pl == 2:
		return 1.6
	if panel == "cellar" and pl == 0:
		return 1.2
	if panel == "cellar" and pl == 1:
		return 1.7
	if panel == "cellar" and pl == 2:
		return 0.8
	if panel == "dial" and pl == 0:
		return 0.6
	return 0.0


## How long the opening plays when nobody taps (s): the fades, each line typing out and holding.
static func length() -> float:
	var total := FADE
	var last := ""
	var pl := 0
	for ln in TalkLines.OPENING:
		var panel := str(ln["panel"])
		if panel != last:
			if last != "":
				total += FADE * 2.0
			last = panel
			pl = 0
		var n := L.t(str(ln["text"])).length()
		total += n / CPS + HOLD + PER_CHAR * n + extra_for(panel, pl)
		pl += 1
	return total + FADE


func _type(dt: float) -> void:
	var total := _text.get_total_character_count()
	if int(_shown) < total:
		var before := int(_shown)
		_shown = minf(_shown + CPS * dt, float(total))
		var who := str(_lines[_i].get("who", ""))
		if who != "":
			for k in range(before, int(_shown)):
				var ch := _text.text.substr(k, 1)
				if ch.strip_edges() != "" and ch not in [".", ",", "!", "?"]:
					_blips += 1
					if _blips % 2 == 1:
						_blip(who)
		_text.visible_characters = int(_shown)
		return
	_hold -= dt
	if _hold <= 0.0:
		_next_line()


func _next_line() -> void:
	_i += 1
	if _i >= _lines.size() or str(_lines[_i]["panel"]) != _panel:
		_state = "out"
		_st = 0.0
		return
	_start_line()


func _blip(who: String) -> void:
	var v: Array = TalkLines.voice(who)
	var sname := str(v[0])
	if not _streams.has(sname):
		var path := "res://assets/audio/sfx/%s.ogg" % sname
		_streams[sname] = load(path) if ResourceLoader.exists(path) else null
	if _streams[sname] == null:
		return
	_voice.stream = _streams[sname]
	_voice.pitch_scale = float((v[1] as Array)[0]) * randf_range(0.97, 1.03)
	_voice.volume_db = float(v[2])
	_voice.play()


func _input(ev: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if _closing:
		return
	var press: bool = (ev is InputEventKey and ev.pressed and not ev.echo) or (ev is InputEventMouseButton and ev.pressed) \
			or (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventJoypadButton and ev.pressed)
	if not press or _t < TAP_HOLD:
		return
	_hint.text = _hint_text()
	var at := Vector2(-99, -99)
	if ev is InputEventMouseButton or ev is InputEventScreenTouch:
		at = ev.position
	if ev.is_action_pressed("ui_cancel") or _skip.get_global_rect().grow(4).has_point(at):
		skip()
		return
	if _state == "line":
		if int(_shown) < _text.get_total_character_count():
			_shown = float(_text.get_total_character_count())
			_text.visible_characters = -1
		elif _lt > 0.25:   # (a double tap does not skip a line unread)
			_next_line()


func on_back() -> void:
	skip()


func skip() -> void:
	if _closing:
		return
	Audio.play("ui_back", -4.0)
	_finish()


func _finish() -> void:
	if _closing:
		return
	_closing = true
	Talk.note("opening")
	Records.clear_new("d:opening")
	if overlay:
		var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(self, "modulate:a", 0.0, 0.0 if UI.calm() else 0.25)
		tw.tween_callback(func():
			var cb := done
			queue_free()
			if cb.is_valid():
				cb.call())
		return
	var p := params.duplicate()
	p["opened"] = true
	var main: Node = get_parent()
	if main and main.has_method("goto"):
		while main.get("_busy"):   # a skip during this screen's own fade-in: a goto then would be dropped
			await get_tree().process_frame
		main.goto("game", p)


# ---------------------------------------------------------------- cues: sounds and one-off moments

func _once(key: String) -> bool:
	if _cue.has(key):
		return false
	_cue[key] = true
	return true


func _pl() -> int:
	return _i - _first


func _cues() -> void:
	if _state == "in" or _state == "out":
		return
	var pl := _pl()
	match _panel:
		"dial":
			var m := _dial_minutes()
			if int(m) != int(_cue.get("min", -1)):
				_cue["min"] = int(m)
				if m < 60.0:
					Audio.play("tick", -8.0, 0.0, 1.0)
			if m >= 60.0 and _once("strike"):
				Audio.play("bell_toll", -2.0, 0.0, 0.9)
				_shake = 0.3
		"kitchen":
			if pl == 2 and _lt >= 0.15 and _once("match"):
				Audio.play("match_strike", -4.0)
			if pl == 2 and _lt >= 1.2 and _once("lit"):
				Audio.play("fire_crackle", -10.0, 0.0, 1.3)
			if _once("steam%d" % int(_pt / 0.8)):   # the kettle, a puff every 0.8 s
				_smoke.append([Ending.K_SPOUT, 0.0])
		"cellar":
			if pl == 0 and _lt >= 1.1 and _once("spark"):
				Audio.play("match_strike", -4.0, 0.0, 1.1)
			if pl == 0 and _lt >= 1.4 and _once("lit"):
				Audio.play("fire_crackle", -10.0, 0.0, 1.4)
			if pl == 2 and _lt >= 1.0 and _once("hop"):
				Audio.play("step", -8.0, 0.0, 1.3)
		"house":
			if _once("smoke%d" % int(_pt / 0.9)):   # the chimney, a puff every 0.9 s
				_smoke.append([CHIMNEY, 0.0])


func _smoke_step(dt: float) -> void:
	for s in _smoke:
		s[1] += dt
	_smoke = _smoke.filter(func(s): return s[1] < 2.6)


# ---------------------------------------------------------------- drawing

var _cv: CanvasItem


func _px(p: Vector2, c: Variant, sz := Vector2.ONE) -> void:
	_cv.draw_rect(Rect2(p.round(), sz), c if c is Color else Color(str(c)))


func _draw_stage() -> void:
	_cv = _stage
	var off := Vector2.ZERO
	if _shake > 0.0 and not UI.calm():
		off = Vector2(1.0 if fmod(_t, 0.1) < 0.05 else -1.0, 0)
	if _panel == "house" and not UI.calm():   # the camera eases up the house as the first lines are read
		off.y += float(maxi(0, 3 - int(_pt / 1.4)))
	_stage.draw_set_transform(off, 0.0, Vector2.ONE)
	if _panel == "kitchen":
		_sky(Ending.K_PANE)
	var tex := Art.tex(ART.get(_panel, "tower/end_house"))
	if tex:
		_stage.draw_texture(tex, Vector2.ZERO)
	match _panel:
		"house": _draw_house()
		"dial": _draw_dial()
		"kitchen": _draw_kitchen()
		"cellar": _draw_cellar()
	_stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _sky(r: Rect2) -> void:
	var cols: Array = Ending.SKY_NIGHT
	var n := 3
	var h := int(r.size.y) / n
	for b in n:
		_px(Vector2(r.position.x, r.position.y + h * b), cols[b], Vector2(r.size.x, h if b < n - 1 else r.size.y - h * b))
	for s in [Vector2(104, 14), Vector2(110, 20), Vector2(116, 13), Vector2(121, 22), Vector2(106, 30), Vector2(119, 33)]:
		if fmod(_t * 1.1 + s.x * 0.13, 2.0) < 1.6:
			_px(s, "#cae6f5")


func _draw_house() -> void:
	for i in Ending.STARS.size():
		var s: Vector2 = Ending.STARS[i]
		if s.y > 50 or (s.x > 22 and s.x < 46 and s.y < 36):
			continue    # not over the moon
		_px(s, "#cae6f5" if fmod(_t * 1.3 + i * 0.37, 2.0) < 1.55 else "#414859")
	# the kitchen's window is lit (Martha is up), its candle flickering
	_px(KITCHEN_WINDOW, "#facb3e", Vector2(4, 5))
	_px(KITCHEN_WINDOW, "#ee8e2e", Vector2(4, 1))
	if fmod(_t * 0.9, 3.1) > 0.15:
		_px(KITCHEN_WINDOW + Vector2(2, 2), "#fdf7ed")
	# the tower clock creeps to twelve as the lines are read
	var m := 58.0 + clampf(_pt / 5.0, 0.0, 2.0)
	_hands(TOWER_CLOCK, m, 5.0, 3.5, false)
	_draw_smoke("#7b8994", "#545454")


func _dial_minutes() -> float:
	return minf(57.0 + floorf(_pt / 0.9), 60.0)


func _draw_dial() -> void:
	var m := _dial_minutes()
	_hands(DIAL, m, 29.0, 19.0, true)
	if m >= 60.0 and _cue.has("strike"):
		var k := clampf(1.0 - (_pt - 2.7) / 0.6, 0.0, 1.0)   # the strike's flash on the rim
		if k > 0.0:
			for a in 24:
				var d := Vector2.from_angle(a / 24.0 * TAU)
				_px(DIAL + d * 33.0, "#ffcc68" if a % 2 else "#facb3e")


## Clock hands, pixel by pixel: `m` minutes past eleven (60 = twelve o'clock).
func _hands(c: Vector2, m: float, lm: float, lh: float, thick: bool) -> void:
	var am := m / 60.0 * TAU
	var ah := (11.0 + m / 60.0) / 12.0 * TAU
	for pair in [[am, lm, 1.0], [ah, lh, 2.0 if thick else 1.0]]:
		var d := Vector2(sin(pair[0]), -cos(pair[0]))
		for i in int(pair[1]):
			var p := (c + d * float(i)).floor()
			_px(p, "#222222", Vector2(pair[2], pair[2]))
	_px(c - Vector2(1, 1), "#8f4029", Vector2(2, 2) if thick else Vector2.ONE)


func _draw_kitchen() -> void:
	var pl := _pl()
	# the range's fire flickers, the kettle steams
	for x in Ending.K_FIRE:
		var h := 3 + int(2.4 * (sin(_t * 9.0 + x * 1.7) + 1.0) + 1.2 * (sin(_t * 5.3 + x * 0.9) + 1.0))
		for k in h:
			_px(Vector2(x, 57 - k), "#da4e38" if k < 2 else ("#ee8e2e" if k < h - 1 else "#facb3e"))
	_draw_smoke("#b6cbcf", "#7b8994")
	# Martha strikes the match, holds it up, lights him; then the match is out
	var pose := "stand"
	if pl == 2:
		if _lt >= 0.15 and _lt < 0.8:
			pose = "match"
		elif _lt >= 0.8 and _lt < 2.4:
			pose = "light"
		elif _lt >= 2.4:
			pose = "match"
	var lit := pl >= 3 or (pl == 2 and _lt >= 1.2)
	var mtex := Art.tex("talk/martha_" + pose)
	var at := _wick(TABLE, 0) - MATCH_TIP + Vector2(0, 0)
	if mtex:
		_stage.draw_texture(mtex, at.floor())
	if pl == 2 and _lt >= 2.4 and _lt < 3.2:   # she shakes the match out: a thread of smoke
		_px(at + Vector2(24, 6 - int((_lt - 2.4) * 8.0)), "#b6cbcf")
	# Tallow on her table: asleep and unlit, then lit (a drop of wax at the match), then beaming
	var face := "blink"
	var flame := ""
	var tear := 0.0
	if lit:
		flame = "small" if pl == 2 and _lt < 1.6 else "idle"
		var since := (_lt - 1.2) if pl == 2 else 9.0
		if since < 1.0:
			face = "teary"
			tear = clampf(since, 0.0, 1.0)
		else:
			face = "happy" if pl == 2 or fmod(_pt, 3.0) < 2.85 else "blink"
	TalkPortrait.paint_candle(_stage, TABLE, "tallow", {"face": face, "flame": flame, "t": _t, "tear": tear,
		"arms": ["cheer", "cheer"] if face == "happy" else ["rest", "rest"]})
	if pl == 2 and _lt >= 0.15 and _lt < 0.5:   # the match flares
		_glow(at + Vector2(24, 8), 6.0 - (_lt - 0.15) * 8.0, "#ffcc68")


func _draw_cellar() -> void:
	var pl := _pl()
	var lit := pl >= 1 or _lt >= 1.4
	var r := 0.0
	if lit:
		r = 42.0 if pl >= 1 else clampf((_lt - 1.4) / 1.2, 0.0, 1.0) * 42.0
		r += 1.0 if fmod(_t, 0.6) < 0.3 else 0.0
	var face := "blink"
	var look := 0
	var flame := ""
	var tear := 0.0
	var hop := 0.0
	var arms := ["rest", "rest"]
	if lit:
		flame = "small" if pl == 0 and _lt < 2.0 else "idle"
		face = "blink" if pl == 0 and _lt < 2.2 else "open"
	if pl == 1:
		face = "worried"
		look = -1 if _lt < 0.7 else (1 if _lt < 1.4 else 0)
		if _lt >= 1.2:
			face = "teary"
			tear = clampf((_lt - 1.2) / 1.2, 0.0, 1.0)
		arms = ["low", "low"]
	elif pl == 2:
		face = "brave"
		flame = "flare"
		look = 1 if _lt >= 0.6 else 0
		hop = 2.0 if _lt >= 1.0 and _lt < 1.25 else 0.0
		arms = ["rest", "fwd"]
	TalkPortrait.paint_candle(_stage, CELLAR - Vector2(0, hop), "tallow", {"face": face, "flame": flame, "t": _t,
		"look": look, "tear": tear, "arms": arms})
	# the dark, and the candle's banded light pushing it back
	_darkness(_wick(CELLAR, look) + Vector2(0, 4), r)
	for d in DOOR_LIGHT:   # the light under the door at the top of the stairs is never quite out
		_px(d.position, "#ffcc68", d.size)
	if pl == 0 and _lt >= 1.1 and _lt < 1.5:   # the match strikes itself: a spark at the wick
		var w := _wick(CELLAR, 0)
		for k in 6:
			var a := k * 1.05 + _t * 9.0
			_px(w + Vector2(cos(a), sin(a)) * (2.0 + (_lt - 1.1) * 10.0), "#facb3e" if k % 2 else "#fdf7ed")


## Where the wick of a candle standing at `feet` is (the match and the light find it there).
func _wick(feet: Vector2, look: int) -> Vector2:
	var g := TalkPortrait.shape_of("tallow", look)
	return feet + Vector2(g["tip"])


## The cellar's dark: three bands of shadow around the light (whole pixels, the game's banded light), black beyond.
func _darkness(c: Vector2, r: float) -> void:
	var bands := [[r, Color(0.03, 0.02, 0.03, 0.55)], [r * 0.72, Color(0.03, 0.02, 0.03, 0.3)], [r * 0.45, Color(0, 0, 0, 0)]]
	for y in 96:
		var dy := absf(y + 0.5 - c.y)
		var spans: Array = []
		for b in bands:
			var rr: float = b[0]
			var hw := sqrt(maxf(0.0, rr * rr - dy * dy)) * 1.15 if dy < rr else -1.0
			spans.append(hw)
		# beyond the outer band: almost black
		var outer: float = spans[0]
		if outer < 0.0:
			_px(Vector2(0, y), Color(0.03, 0.02, 0.03, 0.94), Vector2(192, 1))
			continue
		var x0 := floorf(c.x - outer)
		var x1 := ceilf(c.x + outer)
		_px(Vector2(0, y), Color(0.03, 0.02, 0.03, 0.94), Vector2(maxf(0.0, x0), 1))
		_px(Vector2(x1, y), Color(0.03, 0.02, 0.03, 0.94), Vector2(maxf(0.0, 192.0 - x1), 1))
		for k in range(0, 2):
			var a: float = spans[k]
			var b2: float = spans[k + 1]
			var col: Color = bands[k][1]
			if b2 < 0.0:
				_px(Vector2(floorf(c.x - a), y), col, Vector2(ceilf(c.x + a) - floorf(c.x - a), 1))
			else:
				_px(Vector2(floorf(c.x - a), y), col, Vector2(floorf(c.x - b2) - floorf(c.x - a), 1))
				_px(Vector2(ceilf(c.x + b2), y), col, Vector2(ceilf(c.x + a) - ceilf(c.x + b2), 1))


func _glow(c: Vector2, r: float, col: String) -> void:
	if r <= 0.5:
		return
	for y in range(int(c.y - r), int(c.y + r) + 1):
		for x in range(int(c.x - r), int(c.x + r) + 1):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= r and (x + y) % 2 == 0:
				_px(Vector2(x, y), col)


func _draw_smoke(c1: String, c2: String) -> void:
	for s in _smoke:
		var a: float = s[1]
		var p: Vector2 = s[0] + Vector2(sin(a * 2.2) * 3.0 + a * 4.0, -a * 9.0)
		_px(p, c1 if a < 1.2 else c2, Vector2(2, 2) if a < 1.6 else Vector2.ONE)
