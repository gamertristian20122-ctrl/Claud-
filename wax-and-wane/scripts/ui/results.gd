extends Control
## End of a run: snuffed out (with a death note: who or what did it, with its portrait), or done
## before two. The run's relics (select one to read it), the floor, clock, time played, kills, best
## streak, the seed (to share), Tonight's Candle score, and anything that just moved into the house.

var main: Node
var params := {}
var _info: Label
## The layout (UX-01 / QA-01 / REL-07): everything but the buttons scrolls inside the panel, which is
## never taller than the screen above the button row; the buttons are pinned to the bottom edge.
var _pnl: PanelContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
var _buttons: HBoxContainer
const EDGE := 4          # px kept free at the screen edges
const MAX_NEWS := 2      # unlock rows shown; the rest is "and N more - see the Journal"
const RELIC_ROW := 16    # relic icons in the row (a longer collection: 15 and a "+N" button)
var _relic_row: HFlowContainer


func setup(p: Dictionary) -> void:
	params = p


func _ready() -> void:
	main = get_parent()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.027, 0.035)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var won: bool = params.get("won", false)
	var f := maxi(1, int(params.get("floor", 1)))
	var floors: Dictionary = preload("res://scripts/game/world.gd").FLOORS
	var room := TextureRect.new()
	var theme := str(floors[f]["theme"]) if floors.has(f) else "cellar"
	var area := str(params.get("area", ""))
	if Areas.is_built(area):
		theme = str(Areas.def(area)["theme"])   # the area the run ended in (a longer night's Kitchen, Library, Attic)
	room.texture = Art.tex("rooms/room_" + theme)
	room.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room.modulate = Color(0.32, 0.26, 0.28)
	add_child(room)
	_pnl = UI.panel()
	add_child(_pnl)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true   # a relic picked with the d-pad scrolls into view
	_style_scroll(_scroll.get_v_scroll_bar())
	_pnl.add_child(_scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(v)
	_body = v
	_header(v, won, f)
	# ---- the numbers
	var t: float = params.get("time", 0.0)
	# (when snuffed the clock always reads 2:00 AM - the wax is the clock - so show the rooms instead)
	var mid := Game.clock_text(float(params.get("clock", 120.0))) if won else "Rooms %d" % int(params.get("rooms", 0))
	var stats := "%s   %s   Played %d:%02d   Foes %d   Kindling x%d" % [_where(f, " "), mid,
		int(t) / 60, int(t) % 60, int(params.get("kills", 0)), int(params.get("streak", 0))]
	v.add_child(UI.label(stats, 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	# ---- the relics (select one to read it): one row; a big collection ends in a "+N" that opens the rest
	var relics: Array = params.get("relics", [])
	if not relics.is_empty():
		_relic_row = HFlowContainer.new()
		_relic_row.alignment = FlowContainer.ALIGNMENT_CENTER
		_relic_row.add_theme_constant_override("h_separation", 1)
		_relic_row.add_theme_constant_override("v_separation", 1)
		v.add_child(_relic_row)
		_fill_relics(relics, false)
		_info = UI.label("%d relics. Select one to read it." % relics.size() if relics.size() != 1 else "One relic. Select it to read it.", 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # a long description wraps, never widens the panel
		_info.custom_minimum_size = Vector2(300, 0)
		_info.resized.connect(_fit)
		v.add_child(_info)
	# ---- what moved into the house: two rows at most (a first win can bring seven), the rest in the Journal
	var news: Array = []
	for id in params.get("new_unlocks", []):
		news.append([Art.tex(Items.icon(id)), "NEW IN THE HOUSE: " + Items.display_name(id).to_upper(), Items.display_name(id).to_upper()])
	for key in params.get("unlocked", []):
		news.append([null, "NEW CANDLE: %s" % Candles.def_of(key)["name"].to_upper(), ""])
	var one_row := _news_row(news)   # two new relics side by side when they fit on one line
	if one_row:
		v.add_child(one_row)
		Audio.play("unlock", -3.0)
	elif not news.is_empty():
		var last: HBoxContainer
		for n in news.slice(0, MAX_NEWS):
			last = HBoxContainer.new()
			last.alignment = BoxContainer.ALIGNMENT_CENTER
			last.add_theme_constant_override("separation", 3)
			if n[0]:
				var ic := TextureRect.new()
				ic.texture = n[0]
				ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
				last.add_child(ic)
			var l := UI.label(n[1], 8, UI.GOLD)
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			last.add_child(l)
			v.add_child(last)
		if news.size() > MAX_NEWS:
			var more := UI.label("+%d more in the Journal" % (news.size() - MAX_NEWS), 8, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
			more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var n2: Array = news[MAX_NEWS - 1]
			if (19.0 if n2[0] else 0.0) + _tw(n2[1]) + 11.0 + _tw(more.text) <= 320.0:
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(5, 0)
				last.add_child(gap)
				last.add_child(more)   # on the same row as the second one
			else:
				v.add_child(more)
		Audio.play("unlock", -3.0)
	# ---- achievements earned as the run ended: listed here, never toasted over this screen
	var got := Achievements.take_pending()
	if not got.is_empty():
		var names: Array = []
		for id in got.slice(0, 3):
			names.append(Achievements.name_of(id))
		var line := ("ACHIEVEMENT: %s" if got.size() == 1 else "ACHIEVEMENTS: %s") % ", ".join(names)
		if got.size() > 3:
			line += " +%d" % (got.size() - 3)
		var al := UI.label(line, 8, UI.WAX, HORIZONTAL_ALIGNMENT_CENTER)
		al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		al.custom_minimum_size = Vector2(300, 0)
		v.add_child(al)
	# ---- Tonight's Candle, or the next candle to unlock
	if params.get("daily", false):
		var score := _daily_score()
		v.add_child(UI.label("Tonight's Candle: %d   (first try %d, best %d)" % [score, int(Game.records["daily_first"]), int(Game.records["daily_best"])], 8, UI.EMBER, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		for k in Candles.ORDER:
			if not Candles.is_unlocked(k):
				v.add_child(UI.label("Next candle: %s - %s" % [Candles.def_of(k)["name"], Candles.def_of(k)["unlock_text"]], 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
				break
	# ---- the seed, to share
	if params.has("seed"):
		var tag := "Tonight's Candle" if params.get("daily", false) else ("a seeded run" if params.get("seeded", false) else "share it with a friend")
		v.add_child(UI.label("Seed %s  -  %s" % [Records.seed_text(int(params["seed"])), tag], 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	# ---- the buttons: pinned to the bottom edge, outside the scrolling part, always reachable
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 6)
	var again := UI.button("Light another", func(): main.goto("game"))
	again.set_meta("default_focus", true)
	_buttons.add_child(again)
	_buttons.add_child(UI.button("Share", _share, 64))
	_buttons.add_child(UI.button("Title", func(): main.goto("title")))
	add_child(_buttons)
	Tower.on_results(self, v, params)   # the Clock Tower: TRUE ENDING, its floor name, the hint after a first win
	Diary.on_results(self, v, params)   # v2.5: the ending's name, tonight's diary pages, their reading cards
	_fit()
	_fit.call_deferred()   # again once the flow rows and labels have their real sizes
	get_viewport().size_changed.connect(_fit)


## "NEW IN THE HOUSE:  [icon] DUST BUNNY  [icon] BELL ROPE  +5 more in the Journal" on one line,
## when the first two pieces of news are relics and the line fits; else null (one row each).
func _news_row(news: Array) -> HBoxContainer:
	if news.size() < 2 or news[0][0] == null or news[1][0] == null:
		return null
	# measured with the font (a Label's minimum size is not reliable before it is in the tree)
	var more_text := "  +%d more in the Journal" % (news.size() - 2) if news.size() > 2 else ""
	var w := _tw("NEW IN THE HOUSE:") + 3.0
	for n in news.slice(0, 2):
		w += 3.0 + 3.0 + (n[0] as Texture2D).get_width() + 3.0 + _tw(n[2]) + 3.0
	if more_text != "":
		w += _tw(more_text)
	if w > 330.0:
		return null
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	var head := UI.label("NEW IN THE HOUSE:", 8, UI.GOLD)
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(head)
	for n in news.slice(0, 2):
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(3, 0)
		row.add_child(gap)
		var ic := TextureRect.new()
		ic.texture = n[0]
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(ic)
		var l := UI.label(n[2], 8, UI.GOLD)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
	if more_text != "":
		var more := UI.label(more_text, 8, UI.GOLD)
		more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(more)
	return row


static func _tw(text: String) -> float:
	return Art.font_small.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 1.0


## The relic icons: one row of RELIC_ROW; with more, RELIC_ROW - 1 and a "+N" that shows them all.
func _fill_relics(relics: Array, all: bool) -> void:
	for c in _relic_row.get_children():
		c.queue_free()
	var shown := relics if all or relics.size() <= RELIC_ROW else relics.slice(0, RELIC_ROW - 1)
	var cells := shown.size() + (1 if shown.size() < relics.size() else 0)
	_relic_row.custom_minimum_size = Vector2(mini(cells, RELIC_ROW) * 19 - 1, ceili(cells / float(RELIC_ROW)) * 19 - 1)
	for r in shown:
		var tb := TextureButton.new()
		tb.texture_normal = Art.tex(Items.icon(r))
		tb.custom_minimum_size = Vector2(18, 18)
		tb.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
		tb.ignore_texture_size = true
		UI.focusable_slot(tb)
		var rid: String = r
		var read := func(): _info.text = "%s - %s" % [Items.display_name(rid), Items.desc(rid)]
		tb.pressed.connect(read)
		tb.focus_entered.connect(read)
		tb.mouse_entered.connect(read)
		_relic_row.add_child(tb)
	if shown.size() < relics.size():
		var more := Button.new()
		more.text = "+%d" % (relics.size() - shown.size())
		more.flat = true
		more.custom_minimum_size = Vector2(18, 18)
		more.focus_mode = Control.FOCUS_ALL
		more.add_theme_font_override("font", Art.font_small)
		more.add_theme_font_size_override("font_size", 8)
		for st in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			more.add_theme_color_override(st, UI.GOLD if st != "font_color" else UI.DIM)
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			more.add_theme_stylebox_override(st, empty)
		more.add_theme_stylebox_override("focus", UI.focus_box())
		more.pressed.connect(func():
			Audio.play("ui_click")
			_fill_relics(relics, true)
			_fit.call_deferred())
		_relic_row.add_child(more)


## Panel height = its content, capped at the screen above the button row (then it scrolls); the
## panel is centred in that space, the buttons sit EDGE px above the bottom edge.
func _fit() -> void:
	if _pnl == null or _buttons == null or not is_inside_tree():
		return
	var vs := get_viewport_rect().size
	var bsz := _buttons.get_combined_minimum_size()
	_buttons.size = bsz
	_buttons.position = Vector2(floorf((vs.x - bsz.x) / 2.0), vs.y - EDGE - bsz.y)
	var room_h := _buttons.position.y - EDGE - EDGE   # free height above the buttons
	var chrome := _pnl.get_theme_stylebox("panel").get_minimum_size()
	var content := _body.get_combined_minimum_size()
	var bar_w := _scroll.get_v_scroll_bar().get_combined_minimum_size().x
	var h := minf(content.y, room_h - chrome.y)
	var over := content.y > h + 0.5
	_scroll.custom_minimum_size = Vector2(content.x + (bar_w + 2.0 if over else 0.0), h)
	_pnl.reset_size()
	var psz := _pnl.get_combined_minimum_size()
	_pnl.size = psz
	_pnl.position = Vector2(floorf((vs.x - psz.x) / 2.0), floorf(EDGE + (room_h - psz.y) / 2.0))


## A thin pixel scroll bar (the default one is a smooth grey pill).
func _style_scroll(bar: VScrollBar) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#21141b")
	track.content_margin_left = 1.5
	track.content_margin_right = 1.5
	var grab := StyleBoxFlat.new()
	grab.bg_color = UI.DIM
	grab.anti_aliasing = false
	var hot := grab.duplicate() as StyleBoxFlat
	hot.bg_color = UI.GOLD
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", grab)
	bar.add_theme_stylebox_override("grabber_highlight", hot)
	bar.add_theme_stylebox_override("grabber_pressed", hot)
	bar.custom_minimum_size.x = 3


## The top of the note: who did it (portrait + "Snuffed by ..."), or the win.
func _header(v: VBoxContainer, won: bool, f: int) -> void:
	var clock := Game.clock_text(float(params.get("clock", 120.0)))
	var killer := str(params.get("killer", "clock"))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var box := CenterContainer.new()
	box.custom_minimum_size = Vector2(40, 40)
	row.add_child(box)
	var pic := TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex: Texture2D = Art.tex("hero/hero_preview") if won or killer in ["clock", "gave_up"] else Records.killer_icon(killer)
	if tex:
		var k := 2 if tex.get_width() <= 18 and tex.get_height() <= 18 else 1
		pic.texture = tex
		pic.custom_minimum_size = tex.get_size() * k
	if not won and killer in ["clock", "gave_up"]:
		pic.modulate = Color(0.45, 0.4, 0.42)   # a cold candle
	elif killer.begins_with("e:"):
		pic.modulate = Enemy.DEFS.get(killer.substr(2), {}).get("tint", Color.WHITE)
	box.add_child(pic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	var lvl := UI.label(Records.level_text(int(params.get("level", 2))), 8, UI.DIM)   # the run's difficulty (save slot)
	if won:
		col.add_child(UI.label("DONE BY %s" % clock, 16, UI.GOLD))
		col.add_child(UI.label("The house is quiet. You can finally rest.", 8, UI.CREAM))
		col.add_child(UI.label("%s - %s" % [Candles.def_of(str(params.get("candle", "tallow")))["name"], "Tonight's Candle" if params.get("daily", false) else "Snuffed every guardian"], 8, UI.EMBER))
		col.add_child(lvl)
		return
	col.add_child(UI.label("SNUFFED OUT", 16, UI.RED))
	col.add_child(UI.label(Records.death_line(killer, Records.night_of(params)), 8, UI.CREAM))
	col.add_child(UI.label(_where(f, ", floor "), 8, UI.EMBER))
	col.add_child(lvl)


## "The Crypt 2/4" / "The Kitchen, floor 3 of 7"; the secret floor above the house is never "5/4".
func _where(f: int, style: String) -> String:
	var nm := Records.floor_name(f, false, str(params.get("area", "")))   # a Long Night area names itself
	var n := Records.night_of(params)   # the run's night length
	if f > n:
		return "%s%sabove the bells" % [nm, " - " if style == " " else ", "]
	if style == " ":
		return "%s %d/%d" % [nm, f, n]
	return "%s%s%d of %d" % [nm, style, f, n]


## Score for the nightly seeded run; only the first try of a date counts as "first".
func _daily_score() -> int:
	var won: bool = params.get("won", false)
	var s := 1000 * int(params.get("floor", 1)) + 60 * int(params.get("rooms", 0)) + 5 * int(params.get("kills", 0)) - 40 * int(params.get("hits", 0))
	if won:
		var night := Game.night_minutes(Records.night_of(params))   # the wax left at the finish
		s += 2000 + int(25.0 * (night - float(params.get("clock", night))))
	s = maxi(s, 0)
	var today := Time.get_date_string_from_system()
	if not params.get("scored", false):
		params["scored"] = true
		if Game.records.get("daily_date", "") != today:
			Game.records["daily_date"] = today
			Game.records["daily_first"] = s
			Game.records["daily_best"] = s
		else:
			Game.records["daily_best"] = maxi(int(Game.records["daily_best"]), s)
		Records.log_night(today, int(Game.records["daily_first"]), int(Game.records["daily_best"]), won)
		Game.save()
	return s


func on_back() -> void:
	main.goto("title")


## Design pass (docs/design/MDA.md, relatedness): copy a short, spoiler-free summary of the run
## (Share.text: candle, how far, relics, best Kindling, the seed or tonight's date, a glyph per floor).
var _toast_box: Control


func _share() -> void:
	if not params.has("date"):
		params["date"] = Time.get_date_string_from_system()
	Share.copy(params)
	Audio.play("ui_click")
	if is_instance_valid(_toast_box):
		_toast_box.queue_free()
	var box := UI.panel()
	box.add_child(UI.label("Copied - paste it anywhere", 8, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_bottom = -(EDGE + _buttons.size.y + 3)   # just above the button row
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_toast_box = box
	var tw := box.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(box, "modulate:a", 0.0, 0.4)
	tw.tween_callback(box.queue_free)
