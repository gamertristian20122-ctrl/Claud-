class_name DiaryTour
extends RefCounted
## v2.5 story: the diary's judges (docs/streams/v25_story.md).
##   --autotest --diarycheck                     every page's sources listed and proven in a real 7-floor night (a
##                                               guardian's first fall, a hollow, the Study, a marked foe, a house
##                                               champion, the Kitchen's / Library's / Attic's room, the Clock Tower),
##                                               pages never repeat in a slot, the diary leaves world.rng alone, reading
##                                               cards never open in a fight, every ending reachable. Exit 1 on a FAIL.
##   --autotest --ending=<id> [--shots=/abs/dir] stage one ending (true, housekeeper, windows, whole_story) the way a
##                                               run reaches it: its cards (a shot of each), the credits, the results
##   --autotest --tour --diary --shots=/abs/dir [--fit]   a page in a room, its reading card, the card waiting out a
##                                               fight, the Journal's Diary tab, each ending's first card (and the new
##                                               scenes), the results line
## Every test plays on a throwaway profile in memory (Game.no_save): nothing reaches the real save slots.

static var fails := 0
static var checks := 0


static func _ok(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("[diarycheck] PASS ", what)
	else:
		fails += 1
		print("[diarycheck] FAIL ", what)


## A fresh slot in memory with these pages already found.
static func _fresh(pages: Array = []) -> void:
	Game.no_save = true
	Game.records = Game.RECORDS.duplicate(true)
	Game.records["seen_intro"] = true
	Game.records["wins"] = 1
	for id in pages:
		Diary.found()[id] = 1


## main.goto, once the screen before it has finished its own fade (a goto during one is dropped).
static func _goto(bot: Node, screen: String, params := {}) -> void:
	var main: Node = bot.main
	while main._busy:
		await bot._wait(0.05)
	main.goto(screen, params)
	await bot._wait(0.05)


static func _world(bot: Node) -> Node:
	var main: Node = bot.main
	var waited := 0.0
	while waited < 10.0 and not (main.current and main.current.name == "Game" and main.current.get("player") != null and not main._busy):
		await bot._wait(0.1)
		waited += 0.1
	await bot._wait(0.4)
	var w: Node = main.current
	w.player.invuln = 9999.0   # nothing in the house may end a test run
	return w


static func _pages_in(w: Node) -> Array:
	var out: Array = []
	if w.room == null:
		return out
	for o in w.room.objects.get_children():
		if o is Pickup and o.kind == "page" and not o.taken:
			out.append(o)
	return out


## Pick up every page lying in the room (the real Pickup path); returns their ids.
static func _collect_all(bot: Node, w: Node) -> Array:
	var ids: Array = []
	for p in _pages_in(w):
		ids.append(str(p.item))
		p._t = 1.0
		p._collect(w.player)
	await bot._wait(0.1)
	var d := Diary.of(w)
	d.queue.clear()   # read later (the check reads the cards on its own)
	return ids


static func _kill(e: Node) -> void:
	if e != null and is_instance_valid(e) and e.alive:
		e.hp = 0.0
		e._die()


static func _kill_all(w: Node) -> void:
	for e in w.enemies.duplicate():
		_kill(e)


# ================================================================ --diarycheck

static func check(bot: Node) -> void:
	fails = 0
	checks = 0
	bot.args["nocard"] = true   # no guardian versus cards in the way
	_fresh()
	_static_checks()
	var main: Node = bot.main
	await _goto(bot, "game", {"seed": 5, "floors": 7})
	var w: Node = await _world(bot)
	var d := Diary.of(w)
	# ---- seeded, and apart from the run's own generators
	var st: int = w.rng.state
	d._plan_floor()
	var plan1: Dictionary = d.plan.duplicate()
	var cell1: Vector2i = d.area_cell
	d._plan_floor()
	_ok(w.rng.state == st, "planning a floor's pages leaves world.rng (the loot) alone")
	_ok(d.plan == plan1 and d.area_cell == cell1, "the same seed plans the same pages: %s" % str(plan1))
	# ---- a guardian's first fall: a fresh slot's first page is page 1
	var got: Array = await _guardian(bot, w, 1)
	_ok(got == ["first_night"], "the Cellar's guardian, first fall in a fresh slot -> page 1 %s" % str(got))
	got = await _guardian(bot, w, 2)
	_ok(got == ["crypt_keys"], "the Crypt's guardian -> the Crypt's page %s" % str(got))
	# ---- the new areas: a page in one of their rooms, and their guardians
	got = await _area_room(bot, w, 3)
	_ok(got == ["cook"], "the Kitchen keeps its page in a room (shown once it is cleared) %s" % str(got))
	got = await _guardian(bot, w, 3)
	_ok(got.size() == 1 and Diary.is_loose(Diary.page(str(got[0]))) and Diary.number(str(got[0])) <= 7,
		"the Kitchen's guardian, its page already found -> a loose early page %s" % str(got))
	got = await _guardian(bot, w, 4)
	_ok(got == ["silence"], "the Library's guardian -> the Library's page %s" % str(got))
	got = await _area_room(bot, w, 4)
	_ok(got.is_empty(), "the Library's room has nothing left to give (its page is found) %s" % str(got))
	got = await _guardian(bot, w, 5)
	_ok(got == ["pennock"], "the Chapel's guardian -> the Chapel's page %s" % str(got))
	got = await _area_room(bot, w, 6)
	_ok(got == ["tibbet"], "the Attic keeps its page in a room %s" % str(got))
	# ---- loose pages: a hollow, the Study, a marked foe, a house champion
	got = await _hollow(bot, w, 2)
	_ok(got.size() == 1 and Diary.is_loose(Diary.page(str(got[0]))), "a hollow keeps a loose page %s" % str(got))
	got = await _study(bot, w)
	_ok(got.size() == 1 and Diary.is_loose(Diary.page(str(got[0]))), "the Study's desk keeps a loose page %s" % str(got))
	got = await _foe(bot, w, "marked")
	_ok(got.size() == 1 and Diary.is_loose(Diary.page(str(got[0]))), "the floor's first marked foe drops a loose page %s" % str(got))
	got = await _foe(bot, w, "champion")
	_ok(got.size() == 1 and Diary.is_loose(Diary.page(str(got[0]))), "a house champion drops a loose page %s" % str(got))
	# ---- reading cards never open in a fight
	await _cards_wait(bot, w)
	# ---- the last floors: the Belfry's and the Keeper's pages (a fall there ends the night: asked directly)
	_ok(d.pick("guardian", "belfry") == "great_bell", "the Belfry's guardians keep the Belfry's page")
	_ok(d.pick("guardian", "tower") == "for_tallow", "the Keeper of Hours keeps Martha's letter")
	_ok(d.pick("guardian", "cellar") == "under_stairs", "the Cellar's other guardians still keep the Cellar's page")
	# ---- the Clock Tower: the Keeper's page by the top of the ladder
	w._start_floor(int(w.night_floors) + 1)
	await bot._wait(0.6)
	got = await _collect_all(bot, w)
	_ok(got == ["keeper"], "the Clock Tower's first room keeps the Keeper's page %s" % str(got))
	# ---- never twice: draw from every source until the diary is whole
	_never_twice(d)
	# ---- the endings
	_ending_rules()
	await _ending_cards(bot, w)
	var sum := "[diarycheck] %d checks, %d failed -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"]
	print(sum)
	bot.args.erase("nocard")


static func _static_checks() -> void:
	var ids := {}
	var bad: Array = []
	var known := ["hollow", "marked", "champion", "study", "guardian", "tower"]
	for pg in Diary.PAGES:
		var id := str(pg["id"])
		if ids.has(id):
			bad.append("twice: " + id)
		ids[id] = true
		var text := str(pg["text"])
		var sentences := text.replace("Mr. ", "Mr ").count(". ") + text.count("? ") + text.count("! ") + (1 if text.ends_with(".") or text.ends_with("!") or text.ends_with("?") else 0)
		if sentences < 2 or sentences > 5:
			bad.append("%s has %d sentences" % [id, sentences])
		if text.length() > 330 or str(pg["title"]).length() > 22:
			bad.append("%s is too long (%d / %d)" % [id, text.length(), str(pg["title"]).length()])
		for k in pg["from"]:
			var s := str(k)
			if not (s in known or s.begins_with("guardian:") or s.begins_with("area:")):
				bad.append("%s: unknown source %s" % [id, s])
	_ok(Diary.PAGES.size() == Diary.TOTAL and bad.is_empty(), "24 pages, unique ids, 2-5 sentences each, short enough %s" % str(bad))
	# every page, where it turns up (the list the stream doc copies), and each source is in the game
	for pg in Diary.PAGES:
		print("[diarycheck]   page %2d %-14s %-24s %s" % [Diary.number(str(pg["id"])), pg["id"], pg["title"], ", ".join(pg["from"])])
	var sources := {}
	for pg in Diary.PAGES:
		for k in pg["from"]:
			sources[str(k)] = true
	var missing: Array = []
	for s in sources:
		if not _source_exists(str(s)):
			missing.append(s)
	_ok(missing.is_empty(), "every source exists in the game (%d sources) %s" % [sources.size(), str(missing)])


static func _source_exists(s: String) -> bool:
	match s:
		"hollow":   # FloorGen gives every floor a hollow when it can
			for sd in [1, 2, 3]:
				var rng := RandomNumberGenerator.new()
				rng.seed = sd
				var lay := FloorGen.generate(1, rng)
				for c in lay["cells"]:
					if lay["cells"][c]["type"] == "secret":
						return true
			return false
		"marked":
			return preload("res://scripts/game/world.gd").CHAMP_ODDS.min() > 0.0
		"champion":
			return not Specials.MINIS.is_empty() and Specials.MINI_CHANCE > 0.0
		"study":
			return "study" in Specials.TYPES and float(Specials.INFO["study"]["chance"]) > 0.0
		"guardian":
			return not Records.house_guardians().is_empty()
		"tower":
			return Areas.is_built("tower") and Enemy.DEFS.has("keeper")
	if s.begins_with("guardian:"):
		var a := s.substr(9)
		var bosses: Array = Areas.def(a).get("bosses", [])
		var all := not bosses.is_empty() and Areas.is_built(a)
		for b in bosses:
			all = all and Enemy.DEFS.has(b) and Enemy.DEFS[b].get("boss", false)
		return all
	if s.begins_with("area:"):
		var a2 := s.substr(5)
		return Areas.is_built(a2) and a2 in Areas.sequence(Areas.max_floors())
	return false


## The guardian of floor n: its room, the fight, its fall; returns the pages it left (picked up).
static func _guardian(bot: Node, w: Node, n: int) -> Array:
	if int(w.floor_num) != n:
		w._start_floor(n)
		await bot._wait(0.5)
	bot._jump(w, w.layout["boss"])
	for i in 30:
		await bot._wait(0.1)
		if w.boss and is_instance_valid(w.boss) and w.boss.alive:
			break
	if w.boss == null or not is_instance_valid(w.boss):
		print("[diarycheck]   (no guardian came on floor %d)" % n)
		return []
	print("[diarycheck]   floor %d (%s): %s falls" % [n, Diary.area_of(w), w.boss.kind])
	_kill(w.boss)
	await bot._wait(1.6)
	return await _collect_all(bot, w)


## The room that keeps a new area's page: in, every lodger snuffed, cleared; returns the pages there.
static func _area_room(bot: Node, w: Node, n: int) -> Array:
	if int(w.floor_num) != n:
		w._start_floor(n)
		await bot._wait(0.5)
	var c: Vector2i = Diary.of(w).area_cell
	if c == Vector2i(-99, -99):
		print("[diarycheck]   (floor %d keeps no room page: %s)" % [n, Diary.area_of(w)])
		return []
	Diary.of(w).plan["marked"] = false     # only the room's own page here
	Diary.of(w).plan["champion"] = false
	bot._jump(w, c)
	await bot._wait(0.6)
	for i in 4:
		_kill_all(w)
		await bot._wait(0.4)
	if not w.room.data["cleared"]:
		w._clear_room()
	await bot._wait(0.3)
	return await _collect_all(bot, w)


static func _hollow(bot: Node, w: Node, n: int) -> Array:
	if int(w.floor_num) != n:
		w._start_floor(n)
		await bot._wait(0.5)
	for c in w.layout["cells"]:
		if w.layout["cells"][c]["type"] == "secret":
			Diary.of(w).plan["hollow"] = true   # the floor's roll, forced
			w.layout["cells"][c]["revealed"] = true
			bot._jump(w, c)
			await bot._wait(0.5)
			return await _collect_all(bot, w)
	print("[diarycheck]   (no hollow on floor %d)" % n)
	return []


static func _study(bot: Node, w: Node) -> Array:
	for n in range(2, int(w.night_floors)):
		w._start_floor(n)
		await bot._wait(0.4)
		for c in w.layout["cells"]:
			if w.layout["cells"][c]["type"] == "study":
				Diary.of(w).plan["study"] = true
				bot._jump(w, c)
				await bot._wait(0.5)
				print("[diarycheck]   the Study on floor %d" % n)
				return await _collect_all(bot, w)
	# no Study on this seed's floors: stock one in a room the way Specials does it
	print("[diarycheck]   (no Study on this night: stocking one in a cleared room)")
	Diary.of(w).plan["study"] = true
	Specials.of(w)._stock("study", w.room.data)
	await bot._wait(0.2)
	return await _collect_all(bot, w)


## A marked foe or a house champion in a cleared room, snuffed; returns the page it dropped.
static func _foe(bot: Node, w: Node, src: String) -> Array:
	var d := Diary.of(w)
	d.plan[src] = true
	var pos: Vector2 = w.free_spot_near(w.player.global_position + Vector2(40, 0), 6.0)
	var e: Enemy
	if src == "champion":
		e = Specials.of(w).spawn_mini("skelet", pos)
	else:
		e = w.spawn_enemy("goblin", pos, "gilded")
	await bot._wait(0.2)
	_kill(e)
	await bot._wait(0.6)
	return await _collect_all(bot, w)


## The reading card waits out a fight (foes alive, a guardian alive, a Seance between waves) and opens after.
static func _cards_wait(bot: Node, w: Node) -> void:
	var d := Diary.of(w)
	bot.args["diary"] = true   # the cards stay open until closed here (play-tests close them by themselves)
	w._start_floor(2)
	await bot._wait(0.5)
	var c: Vector2i = bot._normal_cells(w)[0]
	w.layout["cells"][c]["cleared"] = false
	bot._jump(w, c)
	await bot._wait(0.8)
	var alive: int = w.count_enemies()
	d.queue.append("family")
	await bot._wait(1.6)
	_ok(alive > 0 and d.card == null, "no reading card while %d foes are alive" % alive)
	for i in 5:
		_kill_all(w)
		await bot._wait(0.3)
	await bot._wait(1.2)
	var opened: bool = d.card != null and is_instance_valid(d.card) and w.get_tree().paused
	if not opened:
		print("[diarycheck]   why: cleared=%s foes=%d paused=%s/%s trans=%s finished=%s queue=%s card=%s boss=%s holding=%s" % [w.room.data["cleared"],
			w.count_enemies(), w.paused, w.get_tree().paused, w.transitioning, w.finished, d.queue, d.card, w.boss, Juice.holding(w)])
	_ok(opened, "the card opens once the room is clear, and the house waits while it is read")
	if d.card:
		d.card.close()
	await bot._wait(0.4)
	_ok(not w.get_tree().paused and not w.paused, "closing the card gives the house back")
	# a guardian on its feet in a cleared room
	var b: Enemy = w.spawn_enemy("big_zombie", w.free_spot_near(w.room.center() + Vector2(0, -30), 10.0))
	w.boss = b
	d.queue.append("seance")
	await bot._wait(1.5)
	_ok(d.card == null, "no reading card while a guardian is on its feet")
	b.alive = false
	b.queue_free()
	w.boss = null
	await bot._wait(1.2)
	_ok(d.card != null, "the card opens once the guardian is gone")
	if d.card:
		d.card.close()
	await bot._wait(0.4)
	# a Seance between two waves
	w.room.data["rung"] = true
	w.room.data["seance_done"] = false
	d.queue.append("wilf")
	await bot._wait(1.5)
	_ok(d.card == null, "no reading card between a Seance's waves")
	w.room.data["seance_done"] = true
	await bot._wait(1.2)
	_ok(d.card != null, "the card opens when the Seance is over")
	if d.card:
		d.card.close()
	await bot._wait(0.4)
	d.queue.clear()
	bot.args.erase("diary")


## Every source, drawn again and again until the diary is whole: no page twice, each from a place it can turn up.
static func _never_twice(d: Diary) -> void:
	d._out.clear()
	var srcs := [["hollow", ""], ["marked", ""], ["champion", ""], ["study", ""], ["tower", ""]]
	for a in ["cellar", "crypt", "kitchen", "library", "chapel", "attic", "belfry", "tower"]:
		srcs.append(["guardian", a])
	for a in ["kitchen", "library", "attic"]:
		srcs.append(["area", a])
	var rng := RandomNumberGenerator.new()
	rng.seed = 2501
	var twice: Array = []
	var wrong: Array = []
	var draws := 0
	while Diary.count() < Diary.TOTAL and draws < 600:
		draws += 1
		var s: Array = srcs[rng.randi() % srcs.size()]
		var id := d.pick(str(s[0]), str(s[1]))
		if id == "":
			continue
		if Diary.is_found(id):
			twice.append(id)
		var from: Array = Diary.page(id)["from"]
		var key := str(s[0]) if str(s[1]) == "" else "%s:%s" % [s[0], s[1]]
		if not (key in from or (str(s[0]) in from)):
			wrong.append("%s from %s" % [id, key])
		Diary.mark_found(id)
	_ok(Diary.count() == Diary.TOTAL and twice.is_empty() and wrong.is_empty(),
		"all 24 pages turn up from their own sources, none twice (%d draws) %s %s" % [draws, str(twice), str(wrong)])
	var left := ""
	for s in srcs:
		left += d.pick(str(s[0]), str(s[1]))
	_ok(left == "", "a whole diary gives nothing more, from anywhere")


static func _ending_rules() -> void:
	_ok(Diary.ending_for_win(4, 0, {}) == "", "a won 4-floor night without pages: the results screen as before")
	_ok(Diary.ending_for_win(4, 11, {}) == "", "11 pages are not enough for the Housekeeper")
	_ok(Diary.ending_for_win(4, 12, {}) == "housekeeper", "12 pages and a win: The Housekeeper")
	_ok(Diary.ending_for_win(7, 0, {}) == "windows", "a seven-floor night won: A Candle in Every Window")
	_ok(Diary.ending_for_win(7, 12, {"windows": 1}) == "housekeeper", "both earned: the one not seen yet first")
	_ok(Diary.ending_for_win(7, 12, {"windows": 1, "housekeeper": 2}) == "windows", "both seen: the long night's")
	Diary.found().clear()
	_ok(Diary.count() == 0 and Diary.TOTAL == 24, "the Keeper with fewer pages: the true ending")


static func _ending_cards(bot: Node, w: Node) -> void:
	for id in ["true", "housekeeper", "windows", "whole_story"]:
		var e := Ending.new()
		e.ending = id
		e.setup(72.0, "tallow", func(): pass)
		w.add_child(e)
		await bot._wait(0.2)
		var arts := true
		for cd in e._cards:
			arts = arts and Art.has(str(cd["art"]))
		_ok(e._cards.size() >= 3 and e._cards.size() <= 4 and arts, "the %s ending: %d cards, every scene drawn" % [id, e._cards.size()])
		e.queue_free()
		await bot._wait(0.1)
	_fresh(Diary.PAGES.map(func(pg): return str(pg["id"])))
	_ok(Diary.keeper_ending(w) == "whole_story", "every page and the Keeper stilled: The Whole Story")
	_fresh()
	_ok(Diary.keeper_ending(w) == "true", "the Keeper stilled with no pages: the true ending")


# ================================================================ --ending=<id>

## Stage one ending the way a run reaches it, with the pages it needs: shots of each card, the credits, results.
static func stage_ending(bot: Node, id: String) -> void:
	var need: Array = []
	if id == "housekeeper":
		need = Diary.PAGES.slice(0, Diary.HALF).map(func(pg): return str(pg["id"]))
	elif id == "whole_story":
		need = Diary.PAGES.map(func(pg): return str(pg["id"]))
	_fresh(need)
	var main: Node = bot.main
	await _goto(bot, "game", {"seed": 7, "floors": Diary.LONG_NIGHT if id == "windows" else 4})
	var w: Node = await _world(bot)
	print("[ending] staging %s with %d pages" % [id, Diary.count()])
	if id == "true" or id == "whole_story":
		Tower.test_start(w)
		await bot._wait(1.0)
		w.player.wax = 70.0
		Tower.of(w).true_end()
		await bot._wait(3.2)
	else:
		w._start_floor(w.last_floor())
		await bot._wait(1.0)
		w.player.wax = 40.0
		w._victory()
		await bot._wait(3.4)
	var e: Ending = null
	for i in 20:
		for ch in w.get_children():
			if ch is Ending:
				e = ch
		if e:
			break
		await bot._wait(0.1)
	if e == null:
		print("[ending] FAIL: no ending played for %s" % id)
		return
	print("[ending] %s plays %d cards" % [e.ending, e._cards.size()])
	for i in e._cards.size():
		await bot._wait(2.6 if i == 0 else Ending.CARD)
		await bot._shot("ending_%s_%d" % [id, i + 1])
	await bot._wait(Ending.CARD - 2.6 + 4.0)
	await bot._shot("ending_%s_credits" % id)
	for i in 120:
		if main.current and main.current.name == "Results" and not main._busy:
			break
		await bot._wait(0.5)
	await bot._wait(1.0)
	await bot._shot("ending_%s_results" % id)
	print("[ending] %s done: results say ending=%s" % [id, str(main.current.get("params").get("ending", "")) if main.current.get("params") != null else "?"])


# ================================================================ --tour --diary

static func tour(bot: Node) -> void:
	var main: Node = bot.main
	bot.args["diary"] = true   # reading cards stay open for the shots
	_fresh(["first_night", "rounds", "the_rule", "under_stairs", "crypt_keys", "merchant", "pennock"])
	await _goto(bot, "game", {"seed": 3})
	var w: Node = await _world(bot)
	var d := Diary.of(w)
	# ---- a page lying in the cellar, fluttering
	var p: Pickup = d._drop("below_stairs", w.free_spot_near(w.player.global_position + Vector2(34, -10), 6.0))
	await bot._wait(1.4)
	await bot._shot("diary_page_in_room")
	w.player.global_position = p.global_position
	await bot._wait(1.4)
	await bot._shot("diary_reading_card")
	if d.card:
		d.card.close()
	await bot._wait(0.5)
	# ---- picked up mid-fight: the card waits for the room to be clear
	var c: Vector2i = bot._normal_cells(w)[0]
	w.layout["cells"][c]["cleared"] = false
	bot._jump(w, c)
	await bot._wait(0.9)
	var q: Pickup = d._drop("family", w.player.global_position + Vector2(0, 2))
	q._t = 1.0
	q._collect(w.player)
	await bot._wait(1.5)
	await bot._shot("diary_card_waits_in_a_fight")
	for i in 5:
		_kill_all(w)
		await bot._wait(0.3)
	await bot._wait(1.4)
	await bot._shot("diary_card_after_the_fight")
	if d.card:
		d.card.close()
	await bot._wait(0.4)
	# ---- the Journal's Diary tab (from the title, touch)
	await _goto(bot, "title")
	await bot._wait(3.4)
	var title: Node = main.current
	var j := Journal.open(title.root)
	await bot._wait(0.4)
	j._set_tab(Journal.TABS.find("diary"), false)
	await bot._wait(0.3)
	await bot._shot("diary_tab")
	j._select(Diary.number("seance") - 1)
	await bot._wait(0.3)
	await bot._shot("diary_tab_missing")
	j._select(Diary.number("pennock") - 1)
	await bot._wait(0.3)
	await bot._shot("diary_tab_found")
	j._sel_ms = 0
	j._press(Diary.number("pennock") - 1)
	await bot._wait(0.6)
	await bot._shot("diary_tab_card")
	for ch in j.get_children():
		if ch is PageCard:
			ch.close()
	Controls.set_device(Controls.PAD)
	j._select(Diary.number("the_rule") - 1)
	await bot._wait(0.3)
	await bot._shot("diary_tab_pad")
	Controls.set_device(Controls.TOUCH)
	j.close()
	await bot._wait(0.3)
	# ---- the endings: each one's first card, and the new scenes
	var shots := {"true": [1], "housekeeper": [1, 2, 3, 4], "windows": [1, 2, 3, 4], "whole_story": [1, 2, 3, 4]}
	for id in ["housekeeper", "windows", "whole_story", "true"]:
		await _goto(bot, "game", {"seed": 3, "floors": Diary.LONG_NIGHT if id == "windows" else 4})
		w = await _world(bot)
		w.player.frozen = true
		w.hud.visible = false   # a run's first hint would sit under the cards (an ending comes at the end of a night)
		for k in shots[id]:
			var e := Ending.new()
			e.ending = id
			e.setup(68.0, "tallow", func(): pass)
			e._card = k - 2   # _next_card() steps to card k
			w.add_child(e)
			await bot._wait(2.6)
			await bot._shot("diary_ending_%s_%d" % [id, k])
			e.queue_free()
			await bot._wait(0.2)
	# ---- the results line: tonight's pages and the ending's name
	await _goto(bot, "results", {"won": true, "floor": 4, "clock": 66.0, "kills": 140, "rooms": 33, "relics": ["sharp_wick", "bellows"],
		"time": 2300.0, "floors": 4, "ending": "housekeeper", "diary_new": ["hammer", "candle_knows"], "diary_unread": ["hammer"]})
	await bot._wait(2.2)
	await bot._shot("diary_results_card")
	var r: Node = main.current
	for ch in r.get_children():
		if ch is PageCard:
			ch.close()
	await bot._wait(0.6)
	await bot._shot("diary_results")
	Audio.stop_all()
