class_name Talk
extends Control
## The talking scenes (v2.7 dialogue stream, docs/streams/v27_dialogue.md): a box along the bottom of the screen with
## two portraits (the candle on the left, whoever it talks to on the right; the speaker lit and talking, the listener
## dimmed), the speaker's name on a brass plate, the line typing out with a soft voice blip per speaker (a pitched
## CC0 sound: TalkLines.SPEAKERS), a blinking flame when it is done, and a Skip button.
##   - a tap, a click, any key or pad button finishes the line, the next one moves on; Skip, Esc, B or Back end the
##     scene; presses in the first HOLD seconds are still meant for the game and are ignored
##   - Settings > Game > Reduce motion: lines appear whole, nothing slides
##   - `short`: a single line that closes by itself (a later meeting, Tonight's Candle): never more than a tap
## Where scenes play (the hooks; each guarded so it never opens with a live foe, never in the bot's runs):
##   boss_intro.gd _finish -> Talk.meet     after a guardian's entrance, before its fight (it stays harmless and
##                                           untouchable until the scene ends, then the fight starts)
##   world._boss_down      -> Talk.fall     once the fallen guardian has faded, before the room's rewards
##   world.on_back         -> Talk.on_back  Back skips the scene
##   ending.gd             -> Talk.open     the endings' closing beat (Tallow and Martha's memory)
## Setting (Game.settings "talk"): "first" (default: a guardian's whole scene the first time a slot meets it, then at
## most one short line), "always" (the whole scene every time), "off". Records (per slot, Game.records "talks"):
## "meet:<kind>" / "fall:<kind>" -> times shown, "opening" -> times watched.

const HOLD := 0.3          # s: a press this early was meant for the game (the shot that skipped the entrance)
const CPS := 40.0          # letters a second while a line types
const SHORT_HOLD := 1.8    # s: a one-liner closes by itself this long after it has typed out
const DOUBLE := 0.09       # s: a tap arrives as a touch and as a mouse click; one press
const BOX_H := 54.0
const BAR_H := 26.0
const LAYER := 12          # above the HUD (10) and the versus card's letterbox bars (11)

## Tests and tours: scenes play under --autotest too (the bot and every other test never see one).
static var force := false
## The scene on screen (tests, Back).
static var live: Talk = null
static var _last_again := {}

var lines: Array = []
var candle := "tallow"
var short := false
var duck_db := -6.0
var done: Callable
var auto_advance := -1.0   # tests: move on by itself after this many seconds per line
var _i := -1
var _shown := 0.0
var _wait := 0.0
var _t := 0.0
var _line_t := 0.0
var _press_t := -9.0
var _closing := false
var _us := 0
var _blips := 0
var _duck_t := 0.0
var _left: TalkPortrait
var _right: TalkPortrait
var _box: PanelContainer
var _text: Label
var _plate: PanelContainer
var _plate_lbl: Label
var _sub: Label
var _flame: TextureRect
var _hint: Label
var _skip: Button
var _bar: Control
var _voice: Array = []
var _voice_i := 0
var _streams := {}


## Opens a scene on `parent` (a Control or a CanvasLayer). opts: candle, short, duck (dB), done (Callable).
static func open(parent: Node, scene_lines: Array, opts := {}) -> Talk:
	var t := Talk.new()
	t.lines = scene_lines
	t.candle = str(opts.get("candle", "tallow"))
	t.short = bool(opts.get("short", false))
	t.duck_db = float(opts.get("duck", -6.0))
	t.done = opts.get("done", Callable())
	parent.add_child(t)
	return t


func _ready() -> void:
	live = self
	name = "Talk"
	set_meta("modal", true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vs := get_viewport().get_visible_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.02, 0.22)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var root := Control.new()   # everything that rises into place
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var top := vs.y - BOX_H - 4.0
	_box = UI.panel()
	_box.position = Vector2(4, top)
	_box.size = Vector2(vs.x - 8.0, BOX_H)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_box)
	_left = TalkPortrait.new()
	_left.candle = candle
	_left.position = Vector2(8, vs.y - 64.0)
	root.add_child(_left)
	_right = TalkPortrait.new()
	_right.candle = candle
	_right.position = Vector2(vs.x - 64.0, vs.y - 64.0)
	root.add_child(_right)
	_text = UI.label("", 8, UI.CREAM)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.position = Vector2(70, top + 12.0)
	_text.size = Vector2(vs.x - 140.0, BOX_H - 18.0)
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	root.add_child(_text)
	_plate = UI.panel(Vector2.ZERO, "plate")
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate_lbl = UI.engraved(UI.label("", 16, UI.INK))
	_plate.add_child(_plate_lbl)
	root.add_child(_plate)
	_sub = UI.label(L.t("a memory"), 8, UI.WAX, HORIZONTAL_ALIGNMENT_RIGHT)
	_sub.size = Vector2(60, 10)
	_sub.visible = false
	root.add_child(_sub)
	_flame = UI.picture("ui/kit_focus_flame")
	_flame.position = Vector2(vs.x - 80.0, top + BOX_H - 17.0)
	_flame.visible = false
	root.add_child(_flame)
	# a letterbox bar along the top (a whole scene, not a one-liner): how to go on, and Skip
	_bar = Control.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.visible = not short
	add_child(_bar)
	var band := ColorRect.new()
	band.color = UI.VOID
	band.size = Vector2(vs.x, BAR_H)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(band)
	var rule := ColorRect.new()
	rule.color = UI.BRASS_DARK
	rule.position = Vector2(0, BAR_H)
	rule.size = Vector2(vs.x, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(rule)
	_hint = UI.label(_continue_text(), 8, UI.DIM)
	_hint.position = Vector2(8, 8)
	_bar.add_child(_hint)
	_skip = UI.button(L.t("Skip"), func(): pass, 52)
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.mouse_filter = Control.MOUSE_FILTER_IGNORE   # hit-tested in _input (every press stops here)
	_skip.position = Vector2(vs.x - 58.0, 1)
	_bar.add_child(_skip)
	if not UI.calm() and not short:
		_bar.position.y = -BAR_H - 1.0
		var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_method(func(k: float): _bar.position.y = roundf((-BAR_H - 1.0) * (1.0 - k)), 0.0, 1.0, 0.18) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_voice.append(p)
	_us = Time.get_ticks_usec()
	Audio.play("page_flip", -10.0, 0.04, 1.3)
	_next()
	if not UI.calm():
		UI.pop_in(self, root, 6.0, 0.16)


func _exit_tree() -> void:
	if live == self:
		live = null


func _continue_text() -> String:
	match Controls.device:
		"touch": return L.t("Tap to continue")
		"gamepad": return L.t("Any button: next   B: skip")
	return L.t("Any key: next   Esc: skip")


# ---------------------------------------------------------------- lines

func _next() -> void:
	_i += 1
	if _i >= lines.size():
		close()
		return
	var ln: Dictionary = lines[_i]
	var who := str(ln.get("who", "me"))
	var face := str(ln.get("face", "open"))
	var cname := TalkLines.speaker_name("me", candle)
	_text.text = L.t(str(ln.get("text", "")), {"name": Candles.def_of(candle)["name"]})
	_shown = 0.0
	_wait = 0.0
	_line_t = 0.0
	_blips = 0
	if UI.calm():
		_shown = float(_text.get_total_character_count())   # Reduce motion: the whole line at once
		_blip()
	_text.visible_characters = int(_shown)
	# the left frame is always the candle; the right one is whoever it is talking to (the next one if the candle
	# speaks first)
	var other := who if who != "me" else _other_from(_i)
	_left.show_speaker("me", face if who == "me" else _left_face())
	_left.lit = who == "me"
	_left.talking = false
	_right.visible = other != ""
	if other != "":
		_right.show_speaker(other, face if who == other else ("smile" if other == "martha" else "open"))
	_right.lit = who != "me"
	_right.talking = false
	# the name plate over the speaker's side of the box
	_plate_lbl.text = TalkLines.speaker_name(who, candle) if who != "me" else cname
	_plate.reset_size()
	var vs := get_viewport().get_visible_rect().size
	var top := vs.y - BOX_H - 4.0
	var pw := _plate.get_combined_minimum_size().x
	_plate.position = Vector2(66.0 if who == "me" else vs.x - 66.0 - pw, top - 19.0)
	_sub.visible = who == "martha"
	_sub.position = Vector2(vs.x - 70.0 - pw - 60.0, top - 13.0)
	_flame.visible = false
	_hint.text = _continue_text()


func _left_face() -> String:
	# the candle listening keeps the face of its last line (or the next one it will say)
	for k in range(_i, -1, -1):
		if str(lines[k].get("who", "")) == "me":
			return str(lines[k].get("face", "open"))
	for k in range(_i, lines.size()):
		if str(lines[k].get("who", "")) == "me":
			return str(lines[k].get("face", "open"))
	return "open"


func _other_from(i: int) -> String:
	for k in range(i, -1, -1):
		var w := str(lines[k].get("who", "me"))
		if w != "me":
			return w
	for k in range(i, lines.size()):
		var w2 := str(lines[k].get("who", "me"))
		if w2 != "me":
			return w2
	return ""


func _typing() -> bool:
	return int(_shown) < _text.get_total_character_count()


func _speaker() -> String:
	return str(lines[_i].get("who", "me")) if _i >= 0 and _i < lines.size() else "me"


func _process(_dt: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := clampf(float(now - _us) / 1000000.0, 0.0, 0.1)   # real time: the house is paused, time_scale may not be 1
	_us = now
	_t += dt
	_line_t += dt
	if _closing or _i < 0 or _i >= lines.size():
		return
	if _typing():
		if _wait > 0.0:
			_wait -= dt
		else:
			var before := int(_shown)
			_shown = minf(_shown + CPS * dt, float(_text.get_total_character_count()))
			var txt := _text.text
			for k in range(before, int(_shown)):
				var ch := txt.substr(k, 1)
				if ch.strip_edges() != "" and ch not in [".", ",", "!", "?", "(", ")", "\"", "'"]:
					_blips += 1
					if _blips % 2 == 1:
						_blip()
				if ch in [".", "!", "?"] and k + 1 < txt.length() and txt.substr(k + 1, 1) == " ":
					_wait = 0.22
					_shown = float(k + 1)
					break
				if ch == ",":
					_wait = 0.1
					_shown = float(k + 1)
					break
				if ch == "." and k + 1 < txt.length() and txt.substr(k + 1, 1) == ".":
					_wait = 0.12
					_shown = float(k + 1)
					break
			_text.visible_characters = int(_shown)
	var talking := _typing() and _wait <= 0.0
	var who := _speaker()
	_left.talking = talking and who == "me"
	_right.talking = talking and who != "me"
	_left.step(dt)
	if _right.visible:
		_right.step(dt)
	_flame.visible = not _typing() and fmod(_t, 0.8) < 0.55 and not short
	_duck_t -= dt
	if _duck_t <= 0.0:
		_duck_t = 0.4
		Audio.duck(duck_db, 0.7)
	if short and not _typing():
		_wait -= dt
		if _wait < -SHORT_HOLD:
			close()
	if auto_advance >= 0.0 and _line_t >= auto_advance:
		_line_t = 0.0
		_shown = float(_text.get_total_character_count())
		_next()


## The speaker's voice: a short pitched blip (its own players, so the game's sound throttles never swallow it).
func _blip() -> void:
	var v: Array = TalkLines.voice(_speaker())
	var sname := str(v[0])
	if not _streams.has(sname):
		var path := "res://assets/audio/sfx/%s.ogg" % sname
		_streams[sname] = load(path) if ResourceLoader.exists(path) else null
	var st: AudioStream = _streams[sname]
	if st == null:
		return
	var pitches: Array = v[1]
	var p: AudioStreamPlayer = _voice[_voice_i % _voice.size()]
	_voice_i += 1
	p.stream = st
	p.pitch_scale = float(pitches[(_blips / 2) % pitches.size()]) * randf_range(0.97, 1.03)
	var whisper := _text.text.begins_with("(")
	p.volume_db = float(v[2]) - (6.0 if whisper else 0.0)
	p.play()


# ---------------------------------------------------------------- input

func _input(ev: InputEvent) -> void:
	# nothing under the scene sees input while it is up (the sticks, the pause button, the game's keys)
	get_viewport().set_input_as_handled()
	if _closing:
		return
	var press: bool = (ev is InputEventKey and ev.pressed and not ev.echo) or (ev is InputEventMouseButton and ev.pressed) \
			or (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventJoypadButton and ev.pressed)
	if not press or _t < HOLD or _t - _press_t < DOUBLE:
		return
	_press_t = _t
	var at := Vector2(-99, -99)
	if ev is InputEventMouseButton or ev is InputEventScreenTouch:
		at = ev.position
	if ev.is_action_pressed("ui_cancel") or (_skip.visible and _skip.get_global_rect().grow(4).has_point(at)):
		skip()
		return
	advance()


## A press: the whole line if it is still typing, else the next line (a one-liner just closes).
func advance() -> void:
	if _closing:
		return
	if short:
		close()
		return
	if _typing():
		_shown = float(_text.get_total_character_count())
		_text.visible_characters = -1
		_wait = 0.0
		return
	Audio.play("ui_move", -8.0)
	_next()


func skip() -> void:
	if _closing:
		return
	Audio.play("ui_back", -4.0)
	close()


func close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(self, "modulate:a", 0.0, 0.0 if UI.calm() else 0.14)
	tw.tween_callback(func():
		if live == self:
			live = null
		var cb := done
		queue_free()
		if cb.is_valid():
			cb.call())


# ================================================================ the scenes in a run (the hooks)

## The setting: "first" (default), "always" or "off".
static func mode() -> String:
	var m := str(Game.settings.get("talk", "first"))
	return m if m in ["first", "always", "off"] else "first"


## Scenes are for people: never in the play-test bot's runs or the other tests (unless a test sets `force`).
static func allowed(w: Node) -> bool:
	if mode() == "off":
		return false
	return force or not _testing(w)


static func _testing(w: Node) -> bool:
	var m: Variant = w.get("main") if w else null
	return m != null and is_instance_valid(m) and m.get("autotest") != null and m.autotest != null


static func _log(w: Node, msg: String) -> void:
	if _testing(w):
		print("[talk] ", msg)


static func talks() -> Dictionary:
	var d: Variant = Game.records.get("talks", {})
	if not (d is Dictionary):
		d = {}
	Game.records["talks"] = d
	return d


static func seen(key: String) -> bool:
	return int(talks().get(key, 0)) > 0


static func note(key: String) -> void:
	talks()[key] = int(talks().get(key, 0)) + 1
	Game.save()


## boss_intro.gd _finish (the guardian stands ready, its fight not started): a first meeting's words. Returns true
## when a scene opened; the guardian stays held (harmless, untouchable, its AI waiting) until the scene ends.
static func meet(w: Node, e: Node, _skipped := false) -> bool:
	if w == null or e == null or not is_instance_valid(e) or not e.get("alive") or not e.get("boss"):
		return false
	var kind := str(e.get("kind"))
	if TalkLines.meet(kind).is_empty():
		return false
	if not allowed(w):
		_log(w, "meet %s: no scene (%s)" % [kind, "setting off" if mode() == "off" else "bot / test"])
		return false
	if not _quiet_room(w, e):
		_log(w, "meet %s: no scene (another foe is up)" % kind)
		return false
	var key := "meet:" + kind
	var first := not seen(key)
	var daily := bool(w.get("daily"))
	var scene: Array = []
	var one := false
	if daily:   # Tonight's Candle: one line at most; a first meeting's whole scene waits for a normal night
		scene = TalkLines.meet(kind).slice(0, 1) if first else TalkLines.again(kind, str(_last_again.get(kind, "")))
		one = true
	elif first or mode() == "always":
		scene = TalkLines.meet(kind)
	else:
		scene = TalkLines.again(kind, str(_last_again.get(kind, "")))
		one = true
	if scene.is_empty():
		return false
	if one and not first:
		_last_again[kind] = str(scene[0]["text"])
	if not daily or not first:
		note(key)
	_log(w, "meet %s: %s (%d line%s)" % [kind, "one line" if one else "first meeting" if first else "the whole scene again",
		scene.size(), "" if scene.size() == 1 else "s"])
	_hold(w, e)
	_open_in(w, scene, one, -6.0, func():
		_release(w, e)
		_log(w, "meet %s: the fight starts" % kind))
	return true


## world._boss_down, once the guardian has faded (the world's tween waits while the house is paused): its last
## words, or a memory of Martha. Nothing on a later fall unless the setting is Always.
static func fall(w: Node, kind: String) -> void:
	if w == null or TalkLines.fall(kind).is_empty():
		return
	if not allowed(w):
		_log(w, "fall %s: no scene (%s)" % [kind, "setting off" if mode() == "off" else "bot / test"])
		return
	if not _quiet_room(w, null):
		_log(w, "fall %s: no scene (a foe is still up)" % kind)
		return
	var key := "fall:" + kind
	var first := not seen(key)
	var daily := bool(w.get("daily"))
	var scene: Array = []
	var one := false
	if daily:
		if not first:
			return
		scene = TalkLines.fall(kind).slice(0, 1)
		one = true
	elif first or mode() == "always":
		scene = TalkLines.fall(kind)
	else:
		return
	if not daily:
		note(key)
	_log(w, "fall %s: %d line%s" % [kind, scene.size(), "" if scene.size() == 1 else "s"])
	_hold(w, null)
	_open_in(w, scene, one, -12.0, func(): _release(w, null))


## ending.gd: the closing beat said over this card of this ending ([] = none): the candle and Martha's memory. The
## setting applies (First time: once per ending in a slot; Always; Off), and tests never see it unless forced.
static func ending_lines(e: Node, ending: String, card: int, candle: String) -> Array:
	if int(TalkLines.ENDING_CARD.get(ending, -1)) != card or not TalkLines.ENDINGS.has(ending):
		return []
	if ending in TalkLines.TALLOW_ONLY and candle != "tallow":
		return []
	var w: Node = e if e.get("main") != null else e.get_parent()   # the Ending's world (or the world itself)
	if mode() == "off" or (w != null and _testing(w) and not force):
		return []
	if mode() == "first" and seen("end:" + ending):
		return []
	note("end:" + ending)
	return TalkLines.ENDINGS[ending]


## ending.gd: plays the beat over the card (its own two lines step aside under the box), then `then`.
static func ending_beat(parent: Control, scene: Array, candle: String, card_lines: Array, then: Callable) -> void:
	for l in card_lines:
		if is_instance_valid(l):
			l.create_tween().tween_property(l, "modulate:a", 0.0, 0.3)
	# the world's HUD sits under the ending's screen: it steps aside too (the box's bar would land on its clock)
	var e: Node = parent.get_parent()
	var w: Node = e.get_parent() if e else null
	var hud: Variant = w.get("hud") if w else null
	if hud is CanvasLayer:
		(hud as CanvasLayer).visible = false
	open(parent, scene, {"candle": candle, "duck": -4.0, "done": func():
		if is_instance_valid(hud) and hud is CanvasLayer:
			(hud as CanvasLayer).visible = true
		then.call()})


## world._boss_down's reward step awaits this: it returns at once when no scene is up, else when the scene is over.
static func done_with(w: Node) -> void:
	while live != null and is_instance_valid(live) and is_instance_valid(w) and w.is_inside_tree():
		await w.get_tree().process_frame


## world.on_back: Back skips the scene.
static func on_back(_w: Node) -> bool:
	if live != null and is_instance_valid(live) and live.is_inside_tree() and not live._closing:
		live.skip()
		return true
	return false


## No foe may be up when a scene opens: nothing alive in the room but the guardian being met (held by its entrance).
static func _quiet_room(w: Node, e: Node) -> bool:
	for m in w.get("enemies"):
		if is_instance_valid(m) and m.alive and m != e:
			return false
	return e == null or (not e.active)


static func _layer(w: Node) -> CanvasLayer:
	var l := w.get_node_or_null("TalkLayer") as CanvasLayer
	if l == null:
		l = CanvasLayer.new()
		l.name = "TalkLayer"
		l.layer = LAYER
		l.process_mode = Node.PROCESS_MODE_ALWAYS
		w.add_child(l)
	else:
		w.move_child(l, w.get_child_count() - 1)   # input reaches it before anything added since
	return l


static func _open_in(w: Node, scene: Array, one: bool, db: float, then: Callable) -> void:
	var t := open(_layer(w), scene, {"candle": str(w.get("candle_id")), "short": one, "duck": db, "done": then})
	if _testing(w) and force and w.main.autotest.get("args") is Dictionary and w.main.autotest.args.has("talkauto"):
		t.auto_advance = float(w.main.autotest.args["talkauto"])


## The house holds still while a scene plays: paused (the clock too), the sticks let go; the guardian being met stays
## in its entrance (harmless, untouchable) and keeps breathing; Tallow's flame keeps flickering.
static func _hold(w: Node, e: Node) -> void:
	w.hud.release_sticks()
	w.hud.visible = false   # a cutscene: the box and the room only (the HUD is back when the scene ends)
	w.paused = true
	w.get_tree().paused = true
	if e and is_instance_valid(e):
		e.intro = true
		e.active = false
		e.spr.process_mode = Node.PROCESS_MODE_ALWAYS
	var p: Node = w.get("player")
	if p and p.get("flame"):
		p.flame.process_mode = Node.PROCESS_MODE_ALWAYS


static func _release(w: Node, e: Node) -> void:
	if not is_instance_valid(w):
		return
	w.hud.visible = true
	var p: Node = w.get("player")
	if p and p.get("flame"):
		p.flame.process_mode = Node.PROCESS_MODE_INHERIT
	if e and is_instance_valid(e):
		e.spr.process_mode = Node.PROCESS_MODE_INHERIT
		if e.alive:
			e.intro = false
			e.active = true
			e._telegraph(Color(1, 1, 1))   # a white flash: the fight starts
	if not w.finished and not w.hud.pause_layer:
		w.paused = false
		w.get_tree().paused = false
