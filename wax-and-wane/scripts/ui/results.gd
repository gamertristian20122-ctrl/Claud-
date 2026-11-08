extends Control
## End of a run: snuffed out (with a death note: who or what did it, with its portrait), or done
## before two. The run's relics (select one to read it), the floor, clock, time played, kills, best
## streak, the seed (to share), Tonight's Candle score, and anything that just moved into the house.

var main: Node
var params := {}
var _info: Label


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
	room.texture = Art.tex("rooms/room_" + (str(floors[f]["theme"]) if floors.has(f) else "cellar"))
	room.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room.modulate = Color(0.32, 0.26, 0.28)
	add_child(room)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var pnl := UI.panel()
	center.add_child(pnl)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	pnl.add_child(v)
	_header(v, won, f)
	# ---- the numbers
	var t: float = params.get("time", 0.0)
	# (when snuffed the clock always reads 2:00 AM - the wax is the clock - so show the rooms instead)
	var mid := Game.clock_text(float(params.get("clock", 120.0))) if won else "Rooms %d" % int(params.get("rooms", 0))
	var stats := "%s %d/%d   %s   Played %d:%02d   Foes %d   Kindling x%d" % [Records.floor_name(f), f, Records.floor_count(), mid,
		int(t) / 60, int(t) % 60, int(params.get("kills", 0)), int(params.get("streak", 0))]
	v.add_child(UI.label(stats, 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	# ---- the relics (select one to read it)
	var relics: Array = params.get("relics", [])
	if not relics.is_empty():
		var row := HFlowContainer.new()
		row.alignment = FlowContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("h_separation", 1)
		row.add_theme_constant_override("v_separation", 1)
		row.custom_minimum_size = Vector2(mini(relics.size(), 16) * 19, 0)
		for r in relics:
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
			row.add_child(tb)
		v.add_child(row)
		_info = UI.label("%d relics. Select one to read it." % relics.size() if relics.size() != 1 else "One relic. Select it to read it.", 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(_info)
	# ---- what moved into the house
	var news: Array = []
	for id in params.get("new_unlocks", []):
		news.append([Art.tex(Items.icon(id)), "NEW IN THE HOUSE: " + Items.display_name(id).to_upper()])
	for key in params.get("unlocked", []):
		news.append([null, "NEW CANDLE: %s" % Candles.def_of(key)["name"].to_upper()])
	if not news.is_empty():
		var nf := HFlowContainer.new()
		nf.alignment = FlowContainer.ALIGNMENT_CENTER
		nf.add_theme_constant_override("h_separation", 10)
		nf.custom_minimum_size = Vector2(300, 0)
		for n in news.slice(0, 4):
			var item := HBoxContainer.new()
			item.add_theme_constant_override("separation", 3)
			if n[0]:
				var ic := TextureRect.new()
				ic.texture = n[0]
				ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
				item.add_child(ic)
			var l := UI.label(n[1], 8, UI.GOLD)
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			item.add_child(l)
			nf.add_child(item)
		v.add_child(nf)
		if news.size() > 4:
			v.add_child(UI.label("and %d more - see the Journal" % (news.size() - 4), 8, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		Audio.play("unlock", -3.0)
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
		v.add_child(UI.label("Seed %s  -  %s" % [Records.seed_text(int(params["seed"])), tag], 8, Color("#775c55"), HORIZONTAL_ALIGNMENT_CENTER))
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 6)
	var again := UI.button("Light another", func(): main.goto("game"))
	again.set_meta("default_focus", true)
	row2.add_child(again)
	row2.add_child(UI.button("Title", func(): main.goto("title")))
	v.add_child(row2)
	Tower.on_results(self, v, params)   # the Clock Tower: TRUE ENDING, its floor name, the hint after a first win


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
	if won:
		col.add_child(UI.label("DONE BY %s" % clock, 16, UI.GOLD))
		col.add_child(UI.label("The house is quiet. You can finally rest.", 8, UI.CREAM))
		col.add_child(UI.label("%s - %s" % [Candles.def_of(str(params.get("candle", "tallow")))["name"], "Tonight's Candle" if params.get("daily", false) else "Snuffed every guardian"], 8, UI.EMBER))
		return
	col.add_child(UI.label("SNUFFED OUT", 16, UI.RED))
	col.add_child(UI.label(Records.death_line(killer), 8, UI.CREAM))
	var where := "%s, floor %d of %d" % [Records.floor_name(f), f, Records.floor_count()]
	col.add_child(UI.label(where, 8, UI.EMBER))


## Score for the nightly seeded run; only the first try of a date counts as "first".
func _daily_score() -> int:
	var won: bool = params.get("won", false)
	var s := 1000 * int(params.get("floor", 1)) + 60 * int(params.get("rooms", 0)) + 5 * int(params.get("kills", 0)) - 40 * int(params.get("hits", 0))
	if won:
		s += 2000 + int(25.0 * (120.0 - float(params.get("clock", 120.0))))
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
