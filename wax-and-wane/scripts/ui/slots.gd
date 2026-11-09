class_name Slots
extends Control
## The Slots screen (title > Light the wick): three save slots side by side. Each slot keeps its own
## difficulty level (1-4), records, Journal, unlocks, achievements and saved run (Game, RunSave).
##   empty slot:  New candle -> pick a level (pick_level) -> the run starts
##   used slot:   its level, runs / wins, best finish, Journal progress, the last candle and, when a
##                run is saved, Continue (Floor N - 12:41 AM). Play (its second line: the slot's night length)
##                asks first if that would put a saved run out, then opens the Night length picker (pick_night:
##                4 to Areas.max_floors() floors, remembered in the slot's records) and lights the run;
##                Level changes the level between runs (asks first), Delete asks twice.
##   New candle:  pick a level, then the night's length (4 floors to begin with), then the run starts.
## The slot used last is remembered (Game.slot) and has the focus. Fits 384x216, 384x240 and the
## phone's 480x216; touch, keys and gamepad (Back / B / Esc returns to the title).

const GAP := 4
const CARD_MIN := 122
const CARD_MAX := 150

var main: Node
var _cards: HBoxContainer
var _focus_slot := 0   # after a rebuild, this slot's main button takes the focus


static func open(parent: Control, m: Node) -> Slots:
	var s := Slots.new()
	s.main = m
	parent.add_child(s)
	return s


func _ready() -> void:
	set_meta("modal", true)   # the title's Back closes it; FitCheck judges only this screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()   # opaque, like the Journal: the title's menu never shows through
	bg.color = Color(0.035, 0.027, 0.035)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", GAP)
	center.add_child(v)
	# ---- [Back]   SAVE SLOTS   (the title stays centred: a spacer as wide as Back on the right)
	var head := HBoxContainer.new()
	head.set_meta("fit_group", "slots_head")
	var back := UI.button("Back", close, 56)
	head.add_child(back)
	var t := UI.label("SAVE SLOTS", 16, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(t)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(56, 0)
	head.add_child(pad)
	v.add_child(head)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", GAP)
	v.add_child(_cards)
	var hint := UI.label("Every slot keeps its own difficulty level, Journal, unlocks and achievements.", 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	hint.set_meta("fit_group", "slots_hint")
	v.add_child(hint)
	_focus_slot = Game.slot
	_build()
	Controls.on_modal_opened(self)   # keyboard / gamepad focus comes in (the last slot used), and goes back on close
	get_viewport().size_changed.connect(_build)
	Audio.play("ui_open")
	UI.wipe_in(self)   # v2.6: a candle-light edge sweeps the screen in (Reduce motion: at once)


func close() -> void:
	Audio.play("ui_back")
	queue_free()


## (Re)builds the three cards; the cards widen on a wider screen (the phone's 480x216).
func _build() -> void:
	if not is_inside_tree():
		return
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	var vs := get_viewport_rect().size
	var cw := clampi(int((vs.x - 2.0 * GAP - 2.0 * GAP) / Game.SLOTS), CARD_MIN, CARD_MAX)
	for n in range(1, Game.SLOTS + 1):
		_cards.add_child(_card(n, cw))
	var fid := get_instance_id()
	(func():
		var s := instance_from_id(fid) as Slots
		if s and s.is_inside_tree() and not s.is_queued_for_deletion() and Controls.menu_root() == s:
			Controls.focus_first(s)).call_deferred()


# ---------------------------------------------------------------- the cards

func _card(n: int, cw: int) -> Control:
	var d := Game.slot_data(n)
	var p := UI.panel(Vector2(cw, 0))
	p.set_meta("fit_group", "slot%d" % n)   # FitCheck: cards never overlap each other
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.custom_minimum_size.y = 24
	var nm := UI.label(L.t("SLOT {n}", {"n": n}), 16, UI.GOLD if n == Game.slot and not d.is_empty() else UI.CREAM)   # gold: played last
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(nm)
	v.add_child(head)
	if d.is_empty():
		_empty_card(n, v)
		return p
	head.add_child(UI.danger(L.t("Delete"), _delete.bind(n), 0))
	var rec: Dictionary = d["records"]
	var lvl := int(d["level"])
	# v2.6: the slot's candle, big and lit, beside its numbers (level medal, best time, runs, the Journal's ring)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	v.add_child(body)
	var cand := str(rec.get("candle", "tallow"))
	if not Candles.LIST.has(cand):
		cand = "tallow"
	var art := SlotPortrait.new()
	art.candle = cand
	art.custom_minimum_size = Vector2(36, 56)
	art.clip_contents = true   # a portrait: the dish's sides fall outside the niche
	body.add_child(art)
	# the level, as a brass medal pinned on the portrait's corner
	var medal := UI.picture("ui/kit_medal")
	medal.position = Vector2(0, 41)
	medal.size = Vector2(15, 15)
	var num := UI.engraved(UI.label(str(lvl), 16, UI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	num.position = Vector2(1, 0)
	num.size = Vector2(15, 15)
	medal.add_child(num)
	art.add_child(medal)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(info)
	_line(info, str(Records.level_def(lvl)["name"]), UI.EMBER)
	var best := best_finish(rec)
	var long := best_long(rec)   # no 4-floor win yet: the best longer night says how long it was
	if best > 0.0:
		_line(info, L.t("Best: {t}", {"t": Game.clock_text(best)}), UI.GOLD)
	elif not long.is_empty():
		_line(info, L.t("Best: {t}, {n} floors", {"t": Game.clock_text(float(long[1])), "n": int(long[0])}), UI.GOLD)
	else:
		_line(info, L.t("Not won yet"), UI.DIM)
	_line(info, L.t("Runs {r}  Wins {w}", {"r": int(rec.get("runs", 0)), "w": int(rec.get("wins", 0))}), UI.CREAM)
	var j := journal_counts(rec)
	var ring := JournalRing.new()
	ring.frac = float(j[0] + j[2]) / maxf(1.0, float(j[1] + j[3]))
	var jr := HBoxContainer.new()
	jr.add_theme_constant_override("separation", 3)
	jr.add_child(ring)
	var jl := UI.label(L.t("Journal {p}%", {"p": roundi(ring.frac * 100.0)}), 8, UI.DIM)
	jl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	jr.add_child(jl)
	info.add_child(jr)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.custom_minimum_size.y = 3
	v.add_child(fill)
	var saved: Dictionary = RunSave.peek(n)
	var main_btn: Button
	if not saved.is_empty():
		var cont := two_line_button(L.t("Continue"), RunSave.summary_of(saved), _continue.bind(n), 0, true)
		v.add_child(cont)
		var gap := Control.new()
		gap.custom_minimum_size.y = 3
		v.add_child(gap)
		main_btn = cont
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	var play := two_line_button(L.t("Play"), L.t("{n} floors", {"n": slot_night(rec)}), _play.bind(n), 0, saved.is_empty())   # the slot's night length
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(play)
	row.add_child(UI.button(L.t("Level"), _change_level.bind(n), 0))
	v.add_child(row)
	if main_btn == null:
		main_btn = play
	main_btn.set_meta("default_focus", n == _focus_slot)
	return p


func _empty_card(n: int, v: VBoxContainer) -> void:
	_line(v, L.t("Empty"), UI.DIM)
	_line(v, L.t("A fresh candle waits here."), UI.DIM)
	var art := SleepyCandle.new()   # Tallow asleep, wick unlit, waiting for a new candle (big, on his books)
	art.custom_minimum_size = Vector2(40, 50)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(art)
	var any := false
	for k in range(1, Game.SLOTS + 1):
		any = any or not Game.slot_data(k).is_empty()
	var b := UI.button(L.t("New candle"), _new.bind(n), 0, "" if any else "primary")
	b.custom_minimum_size.y = 24
	b.set_meta("default_focus", n == _focus_slot)
	v.add_child(b)


func _line(v: VBoxContainer, text: String, col: Color) -> void:
	v.add_child(UI.label(text, 8, col))


## An empty slot's picture: Tallow drawn like the Candle Box (Player.paint_preview), eyes shut, no flame, twice the
## size, standing in a sunken niche.
class SleepyCandle extends Control:
	func _draw() -> void:
		var feet := Vector2(size.x / 2.0, size.y / 2.0 + 16.0).floor()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(2, 2))
		Player.paint_preview(self, (feet / 2.0).floor(), "tallow", {"unlit": true, "face": "blink"})


## A used slot's candle, twice the size and lit (its flame flickers), in a sunken niche.
class SlotPortrait extends Control:
	var candle := "tallow"
	var _t := 0.0

	func _process(dt: float) -> void:
		_t += dt
		if int(_t * 8.0) != int((_t - dt) * 8.0):
			queue_redraw()

	func _draw() -> void:
		draw_style_box(UI._tex_box("kit_inset", [3, 3, 3, 3], [0, 0, 0, 0]), Rect2(Vector2.ZERO, size))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(2, 2))
		var feet := Vector2(floorf(size.x / 4.0), floorf(size.y / 2.0))
		Player.paint_preview(self, feet, candle, {"frame": int(_t * 8.0), "wax": 84.0})


## The Journal's progress as a stepped ring (13x13): gold for the share of relics seen and lodgers met.
class JournalRing extends Control:
	var frac := 0.0
	static var _pts: Array = []

	func _init() -> void:
		custom_minimum_size = Vector2(13, 13)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	static func _ring() -> Array:
		if not _pts.is_empty():
			return _pts
		var pts: Array = []
		for y in range(-6, 7):
			for x in range(-6, 7):
				var d := sqrt(float(x * x + y * y))
				if d >= 4.6 and d <= 6.2:
					pts.append([atan2(float(x), -float(y)), Vector2(x + 6, y + 6)])
		pts.sort_custom(func(a, b): return wrapf(a[0], 0.0, TAU) < wrapf(b[0], 0.0, TAU))
		_pts = pts
		return pts

	func _draw() -> void:
		var pts := _ring()
		var lit := roundi(frac * pts.size())
		for i in pts.size():
			draw_rect(Rect2(pts[i][1], Vector2.ONE), UI.GOLD if i < lit else Color("#483b3a"))
		draw_rect(Rect2(5, 5, 3, 3), UI.EMBER if frac > 0.0 else Color("#483b3a"))


## A button with a 16 px word and an 8 px gold line under it ("Continue" / "Floor 3 - 12:41 AM").
static func two_line_button(top_text: String, sub_text: String, cb: Callable, w := 0, brass := false) -> Button:
	var b := UI.button("", cb, w, "primary" if brass else "")   # v2.6: brass when it is the slot's main action
	b.custom_minimum_size.y = 30
	var top := UI.label(top_text, 16, UI.INK if brass else UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	if brass:
		UI.engraved(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 1
	top.offset_bottom = 17
	b.add_child(top)
	var sub := UI.label(sub_text, 8, UI.BRASS_DARK if brass else UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	if brass:
		sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 17
	sub.offset_bottom = 27
	b.add_child(sub)
	var rest := UI.INK if brass else UI.CREAM
	var hot := UI.INK if brass else UI.GOLD
	var hl := func(on: bool): top.add_theme_color_override("font_color", hot if on else rest)
	b.focus_entered.connect(hl.bind(true))
	b.focus_exited.connect(hl.bind(false))
	b.mouse_entered.connect(hl.bind(true))
	b.mouse_exited.connect(func(): hl.call(b.has_focus()))
	return b


## The earliest finish over every candle on a 4-floor night (best_finish = Tallow's, best_finish_<candle> the
## others'; longer nights keep their own: best_long).
static func best_finish(rec: Dictionary) -> float:
	var best := 0.0
	for k in rec:
		if str(k).begins_with("best_finish"):
			var t := float(rec[k])
			if t > 0.0 and (best == 0.0 or t < best):
				best = t
	return best


## [floors, minute] of the shortest longer night won (the earliest finish on it), or [] if none.
static func best_long(rec: Dictionary) -> Array:
	for n in range(Areas.MIN_FLOORS + 1, Areas.MAX_FLOORS + 1):
		var t := Records.best_of_night(n, rec)
		if t > 0.0:
			return [n, t]
	return []


## A slot's night length (its records; 4 until it picks another).
static func slot_night(rec: Dictionary) -> int:
	return clampi(int(rec.get("night_floors", Areas.MIN_FLOORS)), Areas.MIN_FLOORS, Areas.max_floors())


## [relics seen, relics in the house, lodgers met, lodgers] for a slot's records (the Journal's
## Relics and Lodgers tabs count the same things).
static func journal_counts(rec: Dictionary) -> Array:
	var seen: Dictionary = rec.get("seen_relics", {}) if rec.get("seen_relics", {}) is Dictionary else {}
	var met: Dictionary = rec.get("met", {}) if rec.get("met", {}) is Dictionary else {}
	var kills: Dictionary = rec.get("kills_by_kind", {}) if rec.get("kills_by_kind", {}) is Dictionary else {}
	var r := 0
	for id in Items.RELICS:
		if seen.has(id):
			r += 1
	var lodgers := BestiaryGallery.regulars()
	var l := 0
	for k in lodgers:
		if met.has(k) or int(kills.get(k, 0)) > 0:
			l += 1
	return [r, Items.RELICS.size(), l, lodgers.size()]


# ---------------------------------------------------------------- actions

func _play(n: int) -> void:
	var d := Game.slot_data(n)
	var cur := slot_night(d.get("records", {}))
	abandon_check(get_parent(), n, func():
		pick_night(get_parent(), "SLOT %d: HOW LONG A NIGHT?" % n, cur, func(floors: int):
			Game.use_slot(n)
			Records.set_night_floors(floors)   # remembered by the slot
			Audio.play("ui_open")
			main.goto("game", {"floors": floors})))   # the slot's own candle (Game.records.candle) at its level


func _continue(n: int) -> void:
	Game.use_slot(n)
	RunSave.continue_run(main)


func _new(n: int) -> void:
	pick_level(get_parent(), "SLOT %d: PICK A DIFFICULTY" % n, 0, func(lvl: int):
		pick_night(get_parent(), "SLOT %d: HOW LONG A NIGHT?" % n, Areas.MIN_FLOORS, func(floors: int):
			Game.start_slot(n, lvl)
			Records.set_night_floors(floors)
			Audio.play("ui_open")
			main.goto("game", {"candle": "tallow", "floors": floors})))


func _change_level(n: int) -> void:
	var d := Game.slot_data(n)
	if d.is_empty():
		return
	var cur := int(d["level"])
	pick_level(get_parent(), "SLOT %d: DIFFICULTY" % n, cur, func(lvl: int):
		if lvl == cur:
			return
		var m := UI.modal(get_parent(), "LEVEL %d: %s?" % [lvl, str(Records.level_def(lvl)["name"]).to_upper()])
		var r: Control = m[0]
		var v: VBoxContainer = m[1]
		v.add_child(UI.label("Slot %d plays at this level from its next candle." % n, 8, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
		if not RunSave.peek(n).is_empty():
			v.add_child(UI.label("Your saved run stays at level %d." % cur, 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		var keep := UI.button("Keep level %d" % cur, func(): r.queue_free(), 100)
		keep.set_meta("default_focus", true)
		row.add_child(keep)
		row.add_child(UI.button("Change", func():
			r.queue_free()
			Game.set_level(n, lvl)
			_refresh(n), 90))
		v.add_child(row))


## Two steps: a slot never goes by a single stray tap.
func _delete(n: int) -> void:
	var m := UI.modal(get_parent(), "DELETE SLOT %d?" % n)
	var r: Control = m[0]
	var v: VBoxContainer = m[1]
	v.add_child(UI.label("Its runs, unlocks, achievements and Journal go out for good.", 8, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var keep := UI.button("Keep it", func(): r.queue_free(), 90)
	keep.set_meta("default_focus", true)
	row.add_child(keep)
	row.add_child(UI.button("Delete", func():
		r.queue_free()
		_delete_really(n), 90))
	v.add_child(row)


func _delete_really(n: int) -> void:
	var m := UI.modal(get_parent(), "ARE YOU SURE?")
	var r: Control = m[0]
	var v: VBoxContainer = m[1]
	v.add_child(UI.label("Slot %d cannot come back." % n, 8, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var keep := UI.button("Keep it", func(): r.queue_free(), 90)
	keep.set_meta("default_focus", true)
	row.add_child(keep)
	row.add_child(UI.button("Delete for good", func():
		r.queue_free()
		Game.delete_slot(n)
		Audio.play("snuff_out", -6.0)
		_refresh(n), 120))
	v.add_child(row)


func _refresh(n: int) -> void:
	_focus_slot = n
	_build()


# ---------------------------------------------------------------- shared pieces

## QA-02: a saved run is never thrown away silently. Starting a new run in a slot that has one asks
## first; only "Light new" lets the new run replace it. (The title's Tonight's Candle and Seed ask the
## same for the slot in use.)
static func abandon_check(parent: Control, n: int, start: Callable) -> void:
	var saved: Dictionary = RunSave.peek(n)
	if saved.is_empty():
		start.call()
		return
	var m := UI.modal(parent, "YOUR CANDLE IS STILL LIT")
	var r: Control = m[0]
	var v: VBoxContainer = m[1]
	var where := RunSave.summary_of(saved).replace(" - ", " at ")
	if n != Game.slot:
		where = "Slot %d's %s" % [n, where]
	v.add_child(UI.label("Your run on %s will go out for good." % where, 8, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("Light a new candle anyway?", 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var keep := UI.button("Keep it", func(): r.queue_free(), 90)
	keep.set_meta("default_focus", true)
	row.add_child(keep)
	row.add_child(UI.button("Light new", func():
		r.queue_free()
		RunSave.clear_slot(n)
		start.call(), 90))
	v.add_child(row)


## The four levels as big buttons, each with its number, name and one line; `current` (0 = none)
## is marked NOW. cb(level) runs once a level is picked (the picker closes first).
static func pick_level(parent: Control, title: String, current: int, cb: Callable) -> void:
	var m := UI.modal(parent, title)
	var r: Control = m[0]
	var v: VBoxContainer = m[1]
	v.add_theme_constant_override("separation", 3)
	for lvl in range(1, Game.MAX_LEVEL + 1):
		var d := Records.level_def(lvl)
		var b := UI.button("", func():
			r.queue_free()
			cb.call(lvl), 264)
		b.custom_minimum_size.y = 30
		var num := UI.label(str(lvl), 16, UI.GOLD)
		num.position = Vector2(8, 1)
		num.size = Vector2(12, 16)
		b.add_child(num)
		var nm := UI.label(str(d["name"]), 16, UI.CREAM)
		nm.position = Vector2(22, 1)
		nm.size = Vector2(150, 16)
		b.add_child(nm)
		var line := UI.label(str(d["line"]), 8, UI.DIM)
		line.position = Vector2(22, 17)
		line.size = Vector2(236, 10)
		b.add_child(line)
		if lvl == current:
			var now := UI.label("NOW", 8, UI.EMBER, HORIZONTAL_ALIGNMENT_RIGHT)
			now.position = Vector2(206, 4)
			now.size = Vector2(50, 10)
			b.add_child(now)
		var hl := func(on: bool): nm.add_theme_color_override("font_color", UI.GOLD if on else UI.CREAM)
		b.focus_entered.connect(hl.bind(true))
		b.focus_exited.connect(hl.bind(false))
		b.mouse_entered.connect(hl.bind(true))
		b.mouse_exited.connect(func(): hl.call(b.has_focus()))
		b.set_meta("default_focus", lvl == (current if current > 0 else Game.DEFAULT_LEVEL))
		v.add_child(b)
	var back := UI.button("Back", func(): r.queue_free(), 70)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)


## The Night length picker (the Long Night, docs/design/LONG_NIGHT.md): how many floors the slot's next night
## has, from 4 (the house as it was made) up to Areas.max_floors() (areas not built yet are not offered), with
## the hour the night ends and the house it builds (the new areas in gold). cb(floors) lights the candle:
## "Light it", or A / Enter on the slider. Touch: the arrows or the track; keys and gamepad: left / right.
static func pick_night(parent: Control, title: String, current: int, cb: Callable) -> void:
	var m := UI.modal(parent, title)
	var r: Control = m[0]
	var v: VBoxContainer = m[1]
	v.add_theme_constant_override("separation", 3)
	var big := UI.label("", 16, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(big)
	var s := NightSlider.new()
	s.lo = Areas.MIN_FLOORS
	s.hi = Areas.max_floors()
	s.value = clampi(current, s.lo, s.hi)
	s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	s.set_meta("default_focus", true)
	v.add_child(s)
	var line := UI.label("", 8, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(line)
	var house := HBoxContainer.new()
	house.alignment = BoxContainer.ALIGNMENT_CENTER
	house.add_theme_constant_override("separation", 0)
	v.add_child(house)
	var gap := Control.new()
	gap.custom_minimum_size.y = 2
	v.add_child(gap)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var go := func():
		if not is_instance_valid(r) or r.is_queued_for_deletion():
			return
		r.queue_free()
		cb.call(s.value)
	row.add_child(UI.button("Light it", go, 100))
	row.add_child(UI.button("Back", func(): r.queue_free(), 70))
	v.add_child(row)
	var show := func(n: int):
		big.text = "%d FLOORS" % n
		line.text = "Until %s. %s" % [Game.clock_text(Game.night_minutes(n), false),
			"The night as it was made." if n <= Areas.MIN_FLOORS else "Each floor past four adds half an hour."]
		night_house(house, n)
	s.changed.connect(show)
	s.accepted.connect(go)
	show.call(s.value)


## The areas of a night of `n` floors as one line of names ("Cellar - Crypt - Kitchen ..."), the areas of the
## Long Night in gold, into `box` (an HBoxContainer; its old names go).
static func night_house(box: HBoxContainer, n: int) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	var seq := Areas.sequence(n)
	for i in seq.size():
		var id: String = seq[i]
		if i > 0:
			box.add_child(UI.label(" - ", 8, UI.DIM))
		var nm := str(Areas.def(id).get("name", id))
		box.add_child(UI.label(nm.substr(4) if nm.begins_with("The ") else nm, 8, UI.GOLD if id in Areas.NEW else UI.WAX))


## The Night length slider: a pixel track with a tick per night length (4 .. hi), the knob on the chosen one and
## an arrow at each end. One focus stop: left / right (keys, d-pad, stick) step it (at an end they move the focus
## on), Enter / A lights the candle (`accepted`); touch taps an arrow or a tick, or drags along the track.
class NightSlider extends Button:
	signal changed(v: int)
	signal accepted
	const ARROW := 18.0
	var value := 4
	var lo := 4
	var hi := 7
	var _drag := false

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(200, 26)
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, empty)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func set_value(v: int) -> void:
		v = clampi(v, lo, hi)
		if v == value:
			return
		value = v
		Audio.play("ui_move")
		queue_redraw()
		changed.emit(v)

	func _gui_input(e: InputEvent) -> void:
		if e.is_action_pressed("ui_left", true) and value > lo:
			set_value(value - 1)
			accept_event()
		elif e.is_action_pressed("ui_right", true) and value < hi:
			set_value(value + 1)
			accept_event()
		elif e.is_action_pressed("ui_accept") and not (e is InputEventMouseButton):
			accept_event()
			accepted.emit()
		elif e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb := e as InputEventMouseButton
			_drag = mb.pressed
			if mb.pressed:
				_pick(mb.position.x, true)
			accept_event()
		elif e is InputEventMouseMotion and _drag:
			_pick((e as InputEventMouseMotion).position.x, false)
			accept_event()
		elif e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed:   # touch not turned into a mouse
			_pick((e as InputEventScreenTouch).position.x, true)
			accept_event()

	func _x0() -> float:
		return ARROW + 6.0

	func _x1() -> float:
		return size.x - ARROW - 6.0

	func _x_of(v: int) -> float:
		return roundf(_x0() + (_x1() - _x0()) * float(v - lo) / float(maxi(1, hi - lo)))

	func _pick(x: float, tap: bool) -> void:
		if tap and x < ARROW:
			set_value(value - 1)
		elif tap and x > size.x - ARROW:
			set_value(value + 1)
		else:
			var best := value
			var bd := INF
			for v in range(lo, hi + 1):
				var d := absf(_x_of(v) - x)
				if d < bd:
					bd = d
					best = v
			set_value(best)

	func _draw() -> void:
		var f: Font = Art.font_small
		var ty := 9.0
		# the arrows: a pixel triangle at each end (dim when the night cannot go further that way)
		for side in [-1, 1]:
			var col := UI.CREAM if (side < 0 and value > lo) or (side > 0 and value < hi) else Color(UI.DIM, 0.5)
			var cx := 9.0 if side < 0 else size.x - 10.0
			for i in 5:
				var hgt := 1 + 2 * i
				var x: float = cx + 2.0 * side - float(i) * side
				draw_rect(Rect2(x + 1, ty + 2 - i, 1, hgt), UI.INK)
				draw_rect(Rect2(x, ty + 1 - i, 1, hgt), col)
		# the track: lit up to the knob
		var x0 := _x0()
		var x1 := _x1()
		var kx := _x_of(value)
		# v2.6: the kit's sunken track, lit up to the knob (like Settings' volume sliders)
		draw_style_box(UI.KitSlider._box("kit_track"), Rect2(x0 - 3, ty - 2, x1 - x0 + 7, 7))
		if kx > x0:
			draw_style_box(UI.KitSlider._box("kit_track_fill"), Rect2(x0 - 3, ty - 2, kx - x0 + 6, 7))
		for v in range(lo, hi + 1):
			var x := _x_of(v)
			draw_rect(Rect2(x, ty - 2, 1, 6), UI.GOLD if v <= value else Color("#775c55"))
			var t := str(v)
			var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			var p := Vector2(roundf(x - tw / 2.0 + 0.5), 24)
			draw_string(f, p + Vector2(1, 1), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UI.INK)
			draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UI.GOLD if v == value else UI.DIM)
		# the knob: the kit's little candle flame on the chosen night
		var knob := Art.tex("ui/kit_knob")
		draw_texture(knob, Vector2(kx - 3, ty - 6))
		if has_focus() and Controls.uses_buttons():   # the focus ring shows for keys and gamepads only
			draw_style_box(UI.focus_box(), Rect2(Vector2.ZERO, size))
