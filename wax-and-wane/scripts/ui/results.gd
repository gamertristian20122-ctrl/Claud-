extends Control
## End of a run: snuffed out (with a death note: who or what did it, with its portrait), or done
## before two. The run's relics (select one to read it), the floor, clock, time played, kills, best
## streak, the seed (to share), Tonight's Candle score, and anything that just moved into the house.
##
## v2.6 (docs/streams/v26_gui.md), top to bottom: a headline card (the portrait; DONE BY 1:06 AM / SNUFFED OUT /
## the ending's name; the line under it; the candle and where), five stat tiles (time played, floor, foes,
## Kindling, diary pages or rooms), the relics in sockets with their description line, "new in the house" and the
## achievements as two small cards side by side, then Tonight's score / the next candle and the level + seed.
## Light another (brass) / Share / Title stay pinned to the bottom edge.

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
const MAX_NEWS := 2      # unlocks shown in their card (one row); the rest is "+N more in the Journal" in its heading
const RELIC_ROW := 16    # relic icons in the row (a longer collection: 15 and a "+N" button)
const BODY_W := 306      # the narrowest column (the screen minus 64 px, between BODY_W and BODY_MAX: 320 on 384, 400 on 480)
const BODY_MAX := 400
var _relic_row: HFlowContainer


func setup(p: Dictionary) -> void:
	params = p


func _ready() -> void:
	main = get_parent()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UI.VOID
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
	_scroll.get_v_scroll_bar().custom_minimum_size.x = 3
	_pnl.add_child(_scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bw := clampf(get_viewport_rect().size.x - 64.0, BODY_W, BODY_MAX)
	v.custom_minimum_size.x = bw
	_scroll.add_child(v)
	_body = v
	_header(v, won, f)
	_tiles(v, f)
	# ---- the relics (select one to read it): one row of sockets; a big collection ends in a "+N" that opens the rest
	var relics: Array = params.get("relics", [])
	if not relics.is_empty():
		_relic_row = HFlowContainer.new()
		_relic_row.alignment = FlowContainer.ALIGNMENT_CENTER
		_relic_row.add_theme_constant_override("h_separation", 1)
		_relic_row.add_theme_constant_override("v_separation", 1)
		v.add_child(_relic_row)
		_fill_relics(relics, false)
		_info = UI.label(L.t("{n} relics. Select one to read it.", {"n": relics.size()}) if relics.size() != 1 else L.t("One relic. Select it to read it."), 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # a long description wraps, never widens the panel
		_info.custom_minimum_size = Vector2(bw - 6.0, 0)
		_info.resized.connect(_fit)
		v.add_child(_info)
	# ---- what moved into the house and the achievements: two small cards side by side
	var news: Array = []
	for id in params.get("new_unlocks", []):
		news.append([Art.tex(Items.icon(id)), Items.display_name(id).to_upper()])
	for key in params.get("unlocked", []):
		news.append([null, L.t("NEW CANDLE: {name}", {"name": L.t(str(Candles.def_of(key)["name"])).to_upper()})])
	var got := Achievements.take_pending()   # achievements earned as the run ended: listed here, never toasted over this screen
	if not news.is_empty() or not got.is_empty():
		var cards := HBoxContainer.new()
		cards.add_theme_constant_override("separation", 4)
		v.add_child(cards)
		if not news.is_empty():
			cards.add_child(_news_card(news))
			Audio.play("unlock", -3.0)
		if not got.is_empty():
			cards.add_child(_ach_card(got))
	# ---- Tonight's Candle, or the next candle to unlock
	if params.get("daily", false):
		var score := _daily_score()
		v.add_child(UI.label(L.t("Tonight's Candle: {s}   (first try {f}, best {b})", {"s": score, "f": int(Game.records["daily_first"]), "b": int(Game.records["daily_best"])}), 8, UI.EMBER, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		for k in Candles.ORDER:
			if not Candles.is_unlocked(k):
				v.add_child(UI.label(L.t("Next candle: {name} - {how}", {"name": L.t(str(Candles.def_of(k)["name"])), "how": L.t(str(Candles.def_of(k)["unlock_text"]))}), 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
				break
	# ---- the level and the seed, to share
	var foot := Records.level_text(int(params.get("level", 2)))   # the run's difficulty (save slot)
	if params.has("seed"):
		var tag := L.t("Tonight's Candle") if params.get("daily", false) else (L.t("a seeded run") if params.get("seeded", false) else L.t("share it with a friend"))
		foot += "   " + L.t("Seed {seed} - {tag}", {"seed": Records.seed_text(int(params["seed"])), "tag": tag})
	v.add_child(UI.label(foot, 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	# ---- the buttons: pinned to the bottom edge, outside the scrolling part, always reachable
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 6)
	# v2.6 Quick restart: one press lights the next candle in this slot - the same candle and night length
	# (after Tonight's Candle: the slot's own candle, as before)
	var next := {} if params.get("daily", false) else {"candle": str(params.get("candle", "tallow")), "floors": int(params.get("floors", 4))}
	var again := UI.icon_button(L.t("Light another"), "ui/ico_flame_dark", func(): main.goto("game", next), 116, "primary")
	again.set_meta("default_focus", true)
	_buttons.add_child(again)
	_buttons.add_child(UI.button(L.t("Share"), _share, 64))
	_buttons.add_child(UI.button(L.t("Title"), func(): main.goto("title"), 80))
	add_child(_buttons)
	Tower.on_results(self, v, params)   # the Clock Tower: TRUE ENDING, its floor name, the hint after a first win
	Diary.on_results(self, v, params)   # v2.5: the ending's name, tonight's diary pages, their reading cards
	_fit()
	_fit.call_deferred()   # again once the flow rows and labels have their real sizes
	get_viewport().size_changed.connect(_fit)
	UI.pop_in(_pnl, _pnl, 6.0, 0.18)   # v2.6: the note rises into place as the burn clears


static func _tw(text: String) -> float:
	return Art.font_small.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 1.0


## "NEW IN THE HOUSE": up to three new things (their icons and names), then "+N more in the Journal".
func _news_card(news: Array) -> PanelContainer:
	var card := UI.panel(Vector2.ZERO, "card")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 1)
	card.add_child(cv)
	var nh := L.t("NEW IN THE HOUSE") + ("   " + L.t("+{n} more", {"n": news.size() - MAX_NEWS}) if news.size() > MAX_NEWS else "")
	cv.add_child(UI.label(nh, 8, UI.GOLD))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 0)
	cv.add_child(flow)
	for n in news.slice(0, MAX_NEWS):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		if n[0]:
			var ic := TextureRect.new()
			ic.texture = n[0]
			ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			row.add_child(ic)
		var l := UI.label(n[1], 8, UI.CREAM)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		flow.add_child(row)
	return card


## "ACHIEVEMENTS": the names of the first three earned as the run ended (+N).
func _ach_card(got: Array) -> PanelContainer:
	var card := UI.panel(Vector2.ZERO, "card")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 1)
	card.add_child(cv)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 3)
	head.add_child(UI.picture("ui/icon_medal"))
	head.add_child(UI.label(L.t("ACHIEVEMENT") if got.size() == 1 else L.t("ACHIEVEMENTS"), 8, UI.GOLD))
	cv.add_child(head)
	var names: Array = []
	for id in got.slice(0, 3):
		names.append(Achievements.name_of(id))
	var line := ", ".join(names) + ("  +%d" % (got.size() - 3) if got.size() > 3 else "")
	var al := UI.label(line, 8, UI.WAX)
	al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	al.custom_minimum_size = Vector2(110, 0)
	cv.add_child(al)
	return card


## The relic icons in sockets: one row of RELIC_ROW; with more, RELIC_ROW - 1 and a "+N" that shows them all.
func _fill_relics(relics: Array, all: bool) -> void:
	for c in _relic_row.get_children():
		c.queue_free()
	var shown := relics if all or relics.size() <= RELIC_ROW else relics.slice(0, RELIC_ROW - 1)
	var cells := shown.size() + (1 if shown.size() < relics.size() else 0)
	_relic_row.custom_minimum_size = Vector2(mini(cells, RELIC_ROW) * 19 - 1, ceili(cells / float(RELIC_ROW)) * 19 - 1)
	for r in shown:
		var tb := Button.new()   # v2.6: an icon socket (the Theme's SlotButton)
		tb.theme_type_variation = &"SlotButton"
		tb.icon = Art.tex(Items.icon(r))
		tb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tb.custom_minimum_size = Vector2(18, 18)
		tb.focus_mode = Control.FOCUS_ALL
		var rid: String = r
		var read := func(): _info.text = "%s - %s" % [Items.display_name(rid), Items.desc(rid)]
		tb.pressed.connect(read)
		tb.focus_entered.connect(read)
		tb.mouse_entered.connect(read)
		_relic_row.add_child(tb)
	if shown.size() < relics.size():
		var more := Button.new()
		more.text = "+%d" % (relics.size() - shown.size())
		more.theme_type_variation = &"SlotButton"
		more.custom_minimum_size = Vector2(18, 18)
		more.focus_mode = Control.FOCUS_ALL
		more.add_theme_font_override("font", Art.font_small)
		more.add_theme_font_size_override("font_size", 8)
		for st in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			more.add_theme_color_override(st, UI.GOLD if st != "font_color" else UI.DIM)
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


## The headline card: the portrait (who did it, or the candle), then DONE BY 1:06 AM / SNUFFED OUT, the line
## under it and the candle (with where it went out).
func _header(v: VBoxContainer, won: bool, f: int) -> void:
	var clock := Game.clock_text(float(params.get("clock", 120.0)))
	var killer := str(params.get("killer", "clock"))
	var card := UI.panel(Vector2.ZERO, "card")
	v.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
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
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var cname := L.t(str(Candles.def_of(str(params.get("candle", "tallow")))["name"]))
	if won:
		col.add_child(UI.label("DONE BY %s" % clock, 16, UI.GOLD))
		col.add_child(UI.label("The house is quiet. You can finally rest.", 8, UI.CREAM))
		col.add_child(UI.label("%s - %s" % [cname, L.t("Tonight's Candle") if params.get("daily", false) else L.t("Snuffed every guardian")], 8, UI.EMBER))
	else:
		col.add_child(UI.label(L.t("SNUFFED OUT"), 16, UI.RED))
		col.add_child(UI.label(Records.death_line(killer, Records.night_of(params)), 8, UI.CREAM))
		col.add_child(UI.label("%s - %s" % [cname, _where(f, ", floor ")], 8, UI.EMBER))
	# the seal: gold for a night won, red wax for a flame snuffed
	var seal := UI.picture("ui/kit_medal" if won else "ui/kit_seal")
	seal.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(seal)


## Five stat tiles: time played, the floor, foes snuffed, the best Kindling, and the diary pages found tonight
## (or the rooms cleared when none were).
func _tiles(v: VBoxContainer, f: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	v.add_child(row)
	var t: float = params.get("time", 0.0)
	var n := Records.night_of(params)
	var pages: Array = params.get("diary_new", [])
	var floor_v := ("%d/%d" % [f, n]) if f <= n else L.t("Tower")
	for tile in [["ico_clock", "%d:%02d" % [int(t) / 60, int(t) % 60], L.t("PLAYED")],
			["ico_stairs", floor_v, L.t("FLOOR")],
			["ico_skull", str(int(params.get("kills", 0))), L.t("FOES")],
			["ico_flame", "x%d" % int(params.get("streak", 0)), L.t("KINDLING")],
			["ico_page", "+%d" % pages.size(), L.t("PAGES")] if not pages.is_empty() else ["ico_rooms", str(int(params.get("rooms", 0))), L.t("ROOMS")]]:
		row.add_child(_tile(tile[0], tile[1], tile[2]))


func _tile(icon: String, value: String, caption: String) -> PanelContainer:
	var p := UI.panel(Vector2(56, 0), "card")
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -3)
	p.add_child(tv)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 3)
	top.add_child(UI.picture("ui/" + icon))
	top.add_child(UI.label(value, 16, UI.CREAM))
	tv.add_child(top)
	tv.add_child(UI.label(caption, 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	return p


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
	var box := UI.panel(Vector2.ZERO, "strip")
	box.add_child(UI.label(L.t("Copied - paste it anywhere"), 8, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
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
