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
