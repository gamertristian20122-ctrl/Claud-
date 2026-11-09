class_name Slots
extends Control
## The Slots screen (title > Light the wick): three save slots side by side. Each slot keeps its own
## difficulty level (1-4), records, Journal, unlocks, achievements and saved run (Game, RunSave).
##   empty slot:  New candle -> pick a level (pick_level) -> the run starts
##   used slot:   its level, runs / wins, best finish, Journal progress, the last candle and, when a
##                run is saved, Continue (Floor N - 12:41 AM). Play lights a new run (asks first if that
##                would put a saved run out), Level changes the level between runs (asks first), Delete
##                asks twice.
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
	var nm := UI.label("SLOT %d" % n, 16, UI.GOLD if n == Game.slot and not d.is_empty() else UI.CREAM)   # gold: played last
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(nm)
	v.add_child(head)
	if d.is_empty():
		_empty_card(n, v)
		return p
	head.add_child(UI.button("Delete", _delete.bind(n), 0))
	var rec: Dictionary = d["records"]
	var lvl := int(d["level"])
	_line(v, Records.level_text(lvl), UI.EMBER)
	_line(v, "Runs %d   Wins %d" % [int(rec.get("runs", 0)), int(rec.get("wins", 0))], UI.CREAM)
	var best := best_finish(rec)
	_line(v, "Best: done by %s" % Game.clock_text(best) if best > 0.0 else "Not won yet", UI.WAX if best > 0.0 else UI.DIM)
	var j := journal_counts(rec)
	_line(v, "Relics seen %d/%d" % [j[0], j[1]], UI.DIM)
	_line(v, "Lodgers met %d/%d" % [j[2], j[3]], UI.DIM)
	var cand := str(rec.get("candle", "tallow"))
	if not Candles.LIST.has(cand):
		cand = "tallow"
	_line(v, "Last candle: %s" % Candles.def_of(cand)["name"], UI.DIM)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.custom_minimum_size.y = 3
	v.add_child(fill)
	var saved: Dictionary = RunSave.peek(n)
	var main_btn: Button
	if not saved.is_empty():
		var cont := two_line_button("Continue", RunSave.summary_of(saved), _continue.bind(n))
		v.add_child(cont)
		var gap := Control.new()
		gap.custom_minimum_size.y = 3
		v.add_child(gap)
		main_btn = cont
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	var play := UI.button("Play", _play.bind(n), 0)
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(play)
	row.add_child(UI.button("Level", _change_level.bind(n), 0))
	v.add_child(row)
	if main_btn == null:
		main_btn = play
	main_btn.set_meta("default_focus", n == _focus_slot)
	return p


func _empty_card(n: int, v: VBoxContainer) -> void:
	_line(v, "Empty", UI.DIM)
	_line(v, "No candle lit here yet.", UI.DIM)
	var art := SleepyCandle.new()   # Tallow asleep, wick unlit, waiting for a new candle
	art.custom_minimum_size = Vector2(28, 40)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(art)
	var b := UI.button("New candle", _new.bind(n), 0)
	b.custom_minimum_size.y = 24
	b.set_meta("default_focus", n == _focus_slot)
	v.add_child(b)


func _line(v: VBoxContainer, text: String, col: Color) -> void:
	v.add_child(UI.label(text, 8, col))


## An empty slot's picture: Tallow drawn like the Candle Box (Player.paint_preview), eyes shut, no flame.
class SleepyCandle extends Control:
	func _draw() -> void:
		# its feet a little under the middle of the free space, so the ~20 px candle sits in the centre
		Player.paint_preview(self, Vector2(size.x / 2.0, size.y / 2.0 + 10.0).floor(), "tallow", {"unlit": true, "face": "blink"})


## A button with a 16 px word and an 8 px gold line under it ("Continue" / "Floor 3 - 12:41 AM").
static func two_line_button(top_text: String, sub_text: String, cb: Callable, w := 0) -> Button:
	var b := UI.button("", cb, w)
	b.custom_minimum_size.y = 30
	var top := UI.label(top_text, 16, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 1
	top.offset_bottom = 17
	b.add_child(top)
	var sub := UI.label(sub_text, 8, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 17
	sub.offset_bottom = 27
	b.add_child(sub)
	var hl := func(on: bool): top.add_theme_color_override("font_color", UI.GOLD if on else UI.CREAM)
	b.focus_entered.connect(hl.bind(true))
	b.focus_exited.connect(hl.bind(false))
	b.mouse_entered.connect(hl.bind(true))
	b.mouse_exited.connect(func(): hl.call(b.has_focus()))
	return b


## The earliest finish over every candle (best_finish = Tallow's, best_finish_<candle> the others').
static func best_finish(rec: Dictionary) -> float:
	var best := 0.0
	for k in rec:
		if str(k).begins_with("best_finish"):
			var t := float(rec[k])
			if t > 0.0 and (best == 0.0 or t < best):
				best = t
	return best


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
	abandon_check(get_parent(), n, func():
		Game.use_slot(n)
		Audio.play("ui_open")
		main.goto("game", {}))   # the slot's own candle (Game.records.candle) at its level


func _continue(n: int) -> void:
	Game.use_slot(n)
	RunSave.continue_run(main)


func _new(n: int) -> void:
	pick_level(get_parent(), "SLOT %d: PICK A DIFFICULTY" % n, 0, func(lvl: int):
		Game.start_slot(n, lvl)
		Audio.play("ui_open")
		main.goto("game", {"candle": "tallow"}))


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
