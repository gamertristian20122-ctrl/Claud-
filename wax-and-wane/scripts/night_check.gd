extends RefCounted
## The Long Night's determinism check (v2.2 night stream, docs/streams/v22_night.md):
##   godot --headless --path . -- --autotest --nightdump --speed=4 [--floors=N] [--dump=/abs/file.txt]
## Builds every floor of a few nights the way a run builds them (the same seeds, floor after floor, the Clock
## Tower last) and prints what the seed decides: each floor's area, guardian and omen, every cell of its layout
## (type, distance, the cell's own seed, a hash of its grid, mini-boss, opening), the numbers it plays by (melt,
## Kindling cap, QUICK bonus, wax odds, marked foes, foe damage, contact damage), the treasure room's and the
## shop's stock as they are first entered, the first ordinary room's lodgers (kind, mark, health) and the
## guardian with its health. A 4-floor night must print exactly the same lines before and after any change to
## the night (the baseline: docs/streams/v22_night_baseline.txt). Lodgers and guardians are frozen, Tallow is
## never driven, so nothing but the seed decides what is printed.

const SEEDS := [11, 5, 7, 2024]


static func run(bot: Node) -> void:
	var lines: Array = []
	var nights: Array = []
	for s in SEEDS:
		nights.append({"seed": s, "label": "seeded %d" % s})
	nights.append({"seed": 777777, "seeded": false, "label": "plain 777777"})
	nights.append({"seed": hash("wax&wane" + "2026-11-09"), "daily": true, "date": "2026-11-09", "label": "tonight 2026-11-09"})
	for nt in nights:
		var params: Dictionary = (nt as Dictionary).duplicate()
		params.erase("label")
		if bot.args.has("floors") and not params.get("daily", false):
			params["floors"] = int(bot.args["floors"])
		await _night(bot, params, str(nt["label"]), lines)
	var text := "\n".join(lines) + "\n"
	print("[night] dump: %d lines, hash %d" % [lines.size(), text.hash()])
	var path := str(bot.args.get("dump", ""))
	if path != "":
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(text)
			f.close()
			print("[night] written to ", path)
	Audio.stop_all()


static func _night(bot: Node, params: Dictionary, label: String, lines: Array) -> void:
	var main: Node = bot.main
	while main._busy:
		await bot.get_tree().process_frame
	main.goto("game", params)
	var waited := 0.0
	while waited < 10.0 and not (main.current and main.current.name == "Game" and main.current.get("player") != null and not main._busy):
		await bot.get_tree().create_timer(0.1).timeout
		waited += 0.1
	await bot._wait(0.3)
	var w: Node = main.current
	var floors := int(w.get("night_floors")) if w.get("night_floors") != null else 4
	lines.append("night %s: floors %d, run seed %d" % [label, floors, int(w.run_seed)])
	for n in range(1, floors + 2):
		if n > 1:
			w._start_floor(n)
		await _floor(bot, w, n, lines)
		if w.finished or w.player.dead:
			lines.append("f%d the run ended during the dump" % n)
			break


# ================================================================ --tour --night

## --autotest --tour --night --shots=DIR [--fit]: the Night length picker (a slot's Play, at 4 and 7 floors and
## with a gamepad's focus; the Slots screen; the seed keypad), a 7-floor run next to a 4-floor one (the HUD at
## 100% and 25% wax: the same candle and bar at the same fraction), the floor banners of the Kitchen, the Library
## and the Attic, the pause menu, the results of long nights (a win, a clock death, a lodger) and the Journal (a
## 7-floor run record, the Ledger). Staged on a copy of the records (Game.no_save), put back at the end.
static func tour(bot: Node) -> void:
	var main: Node = bot.main
	var saved: Dictionary = Game.records.duplicate(true)
	Game.no_save = true
	_stage()
	Controls.set_device(Controls.TOUCH)
	main.goto("title")
	await bot._wait(3.4)
	var title: Node = main.current
	var sl := Slots.open(title.root, main)
	await bot._wait(0.6)
	await bot._shot("night_slots")
	Slots.pick_night(title.root, "SLOT 1: HOW LONG A NIGHT?", 7, func(_f: int): pass)
	await bot._wait(0.5)
	await bot._shot("night_picker_7")
	var s: Variant = _find_slider(title.root)
	if s:
		s.set_value(4)
		await bot._wait(0.3)
		await bot._shot("night_picker_4")
		s.set_value(5)
		await bot._wait(0.3)
		await bot._shot("night_picker_5")
		# a gamepad: the focus ring on the slider, right steps the night longer
		Controls.set_device(Controls.PAD)
		s.grab_focus()
		for k in 2:
			var ev := InputEventAction.new()
			ev.action = "ui_right"
			ev.pressed = true
			Input.parse_input_event(ev)
			await bot._wait(0.15)
			var up := InputEventAction.new()
			up.action = "ui_right"
			up.pressed = false
			Input.parse_input_event(up)
			await bot._wait(0.15)
		await bot._wait(0.3)
		await bot._shot("night_picker_pad")
		print("[night] the gamepad stepped the slider to %d floors (5 + 2 presses)" % int(s.value))
		Controls.set_device(Controls.TOUCH)
	_close_top(title.root)
	sl.queue_free()
	await bot._wait(0.3)
	title.open_seed_pad()
	await bot._wait(0.5)
	await bot._shot("night_seedpad")
	_close_top(title.root)
	await bot._wait(0.3)
	# ---- a 4-floor and a 7-floor run at the same fractions of the night
	for floors in [4, 7]:
		main.goto("game", {"seed": 31, "floors": floors})
		await bot._wait(3.4)
		var w: Node = main.current
		w.player.position = w.room.center() + Vector2(0, 8)
		for frac in [1.0, 0.25]:
			w.player.wax = w.night_minutes() * frac
			w.freeze_t = 999.0
			await bot._wait(1.4)
			print("[night] %d floors at %d%%: wax %.0f of %.0f, clock %s, body rows %d" % [floors, roundi(frac * 100.0), float(w.player.wax),
				float(w.player.wax_max), Game.clock_text(w.clock_minutes()), int(w.player.body_height())])
			await bot._shot("night%d_hud_%d" % [floors, roundi(frac * 100.0)])
		if floors == 7:
			# the floor banners of the new areas, the clock where a run might be by then
			for n in [3, 4, 6]:
				w.player.wax = w.night_minutes() - 25.0 * n
				w._start_floor(n)
				await bot._wait(0.7)
				await bot._shot("night7_banner_%d_%s" % [n, str(w.fdef()["area"])])
				await bot._wait(2.4)
			w.toggle_pause()
			await bot._wait(0.5)
			await bot._shot("night7_pause")
			w.toggle_pause()
			await bot._wait(0.3)
	# ---- the results of long nights
	var rel := ["sharp_wick", "bellows", "beeswax", "lamp_oil", "thimble", "split_wick", "hourglass", "wax_coat"]
	var base := {"kills": 241, "rooms": 52, "relics": rel, "time": 1520.0, "streak": 12, "hits": 31, "candle": "tallow",
		"daily": false, "seed": 31, "seeded": false, "level": 2, "coins": 12}
	var cases := [
		{"won": true, "floor": 7, "floors": 7, "area": "belfry", "clock": 171.0, "killer": ""},
		{"won": false, "floor": 6, "floors": 7, "area": "attic", "clock": 210.0, "killer": "clock"},
		{"won": false, "floor": 3, "floors": 5, "area": "kitchen", "clock": 150.0, "killer": "e:lid_crab"},
	]
	for c in cases:
		var p: Dictionary = base.duplicate(true)
		p.merge(c, true)
		main.goto("results", p)
		await bot._wait(1.4)
		print("[night] share: " + Share.text(p).replace("\n", " | "))
		await bot._shot("night_results_%s_%s" % ["win" if p["won"] else "death", str(p["area"])])
	# ---- the Journal: a 7-floor run record and the Ledger
	main.goto("title")
	await bot._wait(3.4)
	title = main.current
	var j := Journal.open(title.root, 5)
	await bot._wait(0.5)
	j._select(1)   # the Ledger
	await bot._wait(0.3)
	await bot._shot("night_journal_ledger")
	j._select(3)   # the last run: a 7-floor night
	await bot._wait(0.3)
	await bot._shot("night_journal_run7")
	j._select(0)   # How to play: the slot's night
	await bot._wait(0.3)
	await bot._shot("night_journal_howto")
	j.queue_free()
	Game.records = saved
	Game.no_save = false
	Audio.stop_all()


static func _stage() -> void:
	var r := Game.records
	r["runs"] = 31
	r["wins"] = 6
	r["seen_intro"] = true
	r["night_floors"] = 7
	r["best_finish"] = 63.0
	r["best_area"] = "attic"
	r["best_nights"] = {"5": {"tallow": 101.0}, "7": {"tallow": 171.0}}
	var hist: Array = []
	var rows := [
		{"won": true, "floor": 7, "floors": 7, "area": "belfry", "clock": 171.0, "killer": ""},
		{"won": false, "floor": 6, "floors": 7, "area": "attic", "clock": 210.0, "killer": "clock"},
		{"won": false, "floor": 3, "floors": 5, "area": "kitchen", "clock": 96.0, "killer": "e:lid_crab"},
		{"won": true, "floor": 4, "floors": 4, "area": "belfry", "clock": 63.0, "killer": ""},
	]
	for i in rows.size():
		var h: Dictionary = rows[i].duplicate()
		h.merge({"candle": "tallow", "relics": ["sharp_wick", "bellows", "beeswax"], "time": 900.0 + i * 200.0, "kills": 120 + i * 30,
			"streak": 6 + i, "seed": 31 + i, "daily": false, "date": "2026-11-09", "n": 31 - i, "level": 2})
		hist.append(h)
	r["run_history"] = hist


static func _find_slider(n: Node) -> Variant:
	for c in n.get_children():
		if c is Slots.NightSlider:
			return c
		var deep: Variant = _find_slider(c)
		if deep != null:
			return deep
	return null


static func _close_top(root: Control) -> void:
	var top: Node = root.get_child(root.get_child_count() - 1)
	if top.get_meta("modal", false):
		top.queue_free()


static func _floor(bot: Node, w: Node, n: int, lines: Array) -> void:
	var fd: Dictionary = w.fdef(n)
	var lay: Dictionary = w.layout
	lines.append("f%d %s (theme %s, music %s) guardian %s omen '%s' cells %d start %s boss %s" % [n, fd["name"], fd["theme"],
		fd["music"], w.boss_kind, w.omen, (lay["cells"] as Dictionary).size(), lay["start"], lay["boss"]])
	w.player.wax = 100.0   # the clock at a fixed wax (the melt during the dump is not part of the seed)
	lines.append("f%d numbers: melt x%s kindle %s quick %s wax odds %s marked %s foe dmg x%s touch %s clock@100wax %s" % [n,
		str(w.floor_k(w.FLOOR_DRAIN)), str(w.floor_k(w.KINDLE_CAP)), str(w.floor_k(w.QUICK_WAX)), str(w.floor_k(w.WAX_ODDS)),
		str(w.champ_chance()), str(w.enemy_dmg_mult()), str(_touch(w)), str(w.clock_minutes())])
	var keys: Array = (lay["cells"] as Dictionary).keys()
	keys.sort()
	for c in keys:
		var d: Dictionary = lay["cells"][c]
		lines.append("f%d cell %s %s dist %d seed %d grid %d%s%s" % [n, c, d["type"], int(d["dist"]), int(d["seed"]),
			_grid_hash(d["grid"]), (" mini " + str(d["mini"])) if d.has("mini") else "", " opening" if d.get("opening", false) else ""])
	# the loot the seed hands out: the treasure room and the shop, stocked as Tallow first walks in
	for t in ["treasure", "shop"]:
		var tc: Variant = _first(w, t)
		if tc != null:
			bot._jump(w, tc)
			w.freeze_t = 999.0
			lines.append("f%d %s %s: %s" % [n, t, tc, _stock(w)])
	# the first ordinary room's lodgers
	var nc: Variant = _first(w, "normal")
	if nc != null:
		bot._jump(w, nc)
		w.freeze_t = 999.0
		var t := 0.0
		while t < 6.0 and not w.room_spawned:   # the lodgers come in a quarter second after the doors shut
			await bot._wait(0.05)
			t += 0.05
		w.freeze_t = 999.0
		lines.append("f%d room %s lodgers: %s" % [n, nc, _foes(w)])
	# the guardian
	w.boss = null
	bot._jump(w, lay["boss"])
	w.freeze_t = 999.0
	var t2 := 0.0
	while t2 < 8.0 and not (w.boss != null and is_instance_valid(w.boss)):   # it steps out after its versus card
		await bot._wait(0.05)
		t2 += 0.05
	await bot._wait(0.1)
	w.freeze_t = 999.0
	var b: Variant = w.boss
	if b != null and is_instance_valid(b):
		lines.append("f%d guardian %s hp %s" % [n, b.kind, str(b.max_hp)])
	else:
		lines.append("f%d guardian not up" % n)


static func _touch(w: Node) -> float:
	if w.has_method("touch_damage"):
		return float(w.touch_damage())
	return float(Enemy.TOUCH[clampi(int(w.floor_num), 1, 4) - 1])


static func _first(w: Node, t: String) -> Variant:
	var keys: Array = (w.layout["cells"] as Dictionary).keys()
	keys.sort()
	for c in keys:
		if w.layout["cells"][c]["type"] == t:
			return c
	return null


static func _grid_hash(g: Array) -> int:
	var s := ""
	for row in g:
		s += "".join(row)
	return s.hash()


static func _stock(w: Node) -> String:
	var out: Array = []
	for rec in w.room.data["pickups"]:
		out.append("%s%s%s" % [rec["kind"], (":" + str(rec["item"])) if str(rec["item"]) != "" else "",
			("@%d" % int(rec["price"])) if int(rec["price"]) > 0 else ""])
	return ", ".join(out)


static func _foes(w: Node) -> String:
	var out: Array = []
	for e in w.enemies:
		if is_instance_valid(e) and e.alive and not e.is_queued_for_deletion():
			out.append("%s%s hp %s" % [e.kind, ("/" + str(e.champ)) if str(e.champ) != "" else "", str(e.max_hp)])
	return ", ".join(out)
