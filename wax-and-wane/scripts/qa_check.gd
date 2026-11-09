extends RefCounted
## v2.7 QA pass (docs/streams/v27_qa.md): one probe per bug the pass fixed. Each prints a line
##   [qa] <what>  PASS / FAIL  (the numbers it judged)
## and the run ends with exit code 1 if any probe failed:
##   godot --headless --path . -- --autotest --qacheck

static var fails := 0


static func _say(what: String, ok: bool, detail: String) -> void:
	if not ok:
		fails += 1
	print("[qa] %-52s %s  (%s)" % [what, "PASS" if ok else "FAIL", detail])


## Every probe, one after another. Returns the number that failed.
static func run(at: Node) -> int:
	fails = 0
	Game.base_time_scale = 1.0
	Engine.time_scale = 1.0
	if DisplayServer.get_name() == "headless":
		at.get_tree().root.size = Vector2i(1536, 864)   # a 384x216 screen (the narrowest the game supports)
	print("[qa] screen %s" % at.get_viewport().get_visible_rect().size)
	await _banner_swap(at)
	await _back_matrix(at)
	await _stove_embers(at)
	await _pause_in_hitstop(at)
	await _card_in_hitstop(at)
	await _restart_kinds(at)
	print("[qa] %d failed -> %s" % [fails, "PASS" if fails == 0 else "FAIL"])
	return fails


## Android's back gesture (the system sends main a go-back request): one press closes the top menu, else pauses
## or resumes. It never opens the map and never leaves the game stuck.
static func _back(at: Node) -> void:
	at.main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)


## n frames and at least n x 0.05 s (a closing card fades for 0.12 s; headless frames are very short).
static func _frames(tree: SceneTree, n: int) -> void:
	for i in n:
		await tree.process_frame
	await tree.create_timer(0.05 * n, true, false, true).timeout


static func _top(w: Node) -> String:
	var r: Node = w.hud.root
	var top: Node = r.get_child(r.get_child_count() - 1)
	return "%s%s" % [top.get_class(), " modal" if top.get_meta("modal", false) else ""]


static func _back_matrix(at: Node) -> void:
	var tree: SceneTree = at.get_tree()
	var w: Node = await _new_run(at, {"seed": 4242})
	var hud: Node = w.hud
	# in play: pause; again: resume
	_back(at)
	await _frames(tree, 3)
	var paused1: bool = w.paused and hud.pause_layer != null and not is_instance_valid(hud.map_layer)
	_back(at)
	await _frames(tree, 3)
	_say("Back in play: pauses, again resumes", paused1 and not w.paused and not tree.paused,
		"paused %s, then paused %s / tree %s" % [paused1, w.paused, tree.paused])
	# the full map: closes it (the pause menu under it stays), then resumes
	w.open_map()
	await _frames(tree, 3)
	var map_open: bool = is_instance_valid(hud.map_layer)
	_back(at)
	await _frames(tree, 3)
	var map_shut: bool = not is_instance_valid(hud.map_layer) and w.paused and hud.pause_layer != null
	_back(at)
	await _frames(tree, 3)
	_say("Back over the full map: closes it, then resumes", map_open and map_shut and not w.paused,
		"open %s, closed to the pause menu %s, resumed %s" % [map_open, map_shut, not w.paused])
	# Settings > Achievements over the pause menu: one layer per press
	w.toggle_pause()
	SettingsPanel.open(hud.root)
	await _frames(tree, 2)
	Achievements.open_list(hud.root)
	await _frames(tree, 2)
	var steps: Array = []
	for i in 3:
		_back(at)
		await _frames(tree, 3)
		steps.append("%s/%s" % [_top(w), "paused" if w.paused else "playing"])
	_say("Back: Achievements, Settings, then the game", not w.paused and hud.pause_layer == null, ", ".join(steps))
	# the guardian's versus card and its entrance: Back pauses over them, Back resumes, the fight starts
	at.args.erase("nocard")
	var bc: Vector2i = w.layout["boss"]
	w.player.wax = 100.0
	at._jump(w, bc)
	var waited := 0
	while waited < 120 and not Juice.holding(w):
		await tree.process_frame
		waited += 1
	var card_up := Juice.holding(w)
	_back(at)
	await _frames(tree, 3)
	var card_paused: bool = w.paused and hud.pause_layer != null
	_back(at)
	await _frames(tree, 3)
	waited = 0
	while waited < 600 and BossIntro.live == null:
		await tree.process_frame
		waited += 1
	var intro_up: bool = BossIntro.live != null and is_instance_valid(BossIntro.live)
	_back(at)
	await _frames(tree, 3)
	var intro_paused: bool = w.paused and hud.pause_layer != null
	_back(at)
	waited = 0
	while waited < 900 and not (w.boss != null and is_instance_valid(w.boss) and w.boss.active and not tree.paused):
		await tree.process_frame
		waited += 1
	var fighting: bool = w.boss != null and is_instance_valid(w.boss) and w.boss.active and not tree.paused and not w.paused
	_say("Back over the versus card and the entrance", card_up and card_paused and intro_up and intro_paused and fighting,
		"card %s paused %s, entrance %s paused %s, then the fight %s" % [card_up, card_paused, intro_up, intro_paused, fighting])
	# a diary page's reading card: Back closes it and the house goes on
	for e in w.enemies:
		if is_instance_valid(e):
			e.queue_free()
	w.enemies.clear()
	w.boss = null
	w.hud.set_boss("", false)
	w.room.data["cleared"] = true
	at.args["diary"] = true   # the card stays open until Back closes it
	var d := Diary.of(w)
	d.queue.append("family")
	waited = 0
	while waited < 600 and not (d.card != null and is_instance_valid(d.card)):
		await tree.process_frame
		waited += 1
	var read_up: bool = d.card != null and is_instance_valid(d.card) and w.paused
	_back(at)
	await _frames(tree, 6)
	at.args.erase("diary")
	_say("Back closes a diary page's reading card", read_up and d.card == null and not w.paused and not tree.paused,
		"card open %s, then card %s paused %s / tree %s" % [read_up, d.card, w.paused, tree.paused])


## A screenshot for --shots=/abs/dir (with a window: xvfb-run ... --resolution 1536x864 for 384x216).
static func _shot(at: Node, name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await at._shot(name)


## A new run (params as main.goto takes them); returns the world once Tallow can move.
static func _new_run(at: Node, params: Dictionary) -> Node:
	var tree: SceneTree = at.get_tree()
	var old: Node = at.main.current
	at.main.goto("game", params)
	var waited := 0
	while waited < 1200 and not (at.main.current != old and at.main.current and at.main.current.name == "Game" \
			and at.main.current.get("player") != null and not at.main._busy):
		await tree.process_frame
		waited += 1
	var w: Node = at.main.current
	waited = 0
	while waited < 600 and (w.player.frozen or Juice.holding(w) or w.transitioning):
		await tree.physics_frame
		waited += 1
	return w


## Swap sticks on a 384-wide screen put the keepsake button on the left, and the floor / relic banner took that
## button's x as its right edge: the subtitle got no room and ran off the right of the screen (hud._place_banner).
static func _banner_swap(at: Node) -> void:
	var tree: SceneTree = at.get_tree()
	var w: Node = await _new_run(at, {"seed": 4242})
	var hud: Node = w.hud
	var vs: Vector2 = hud.view_size()
	var swap0: bool = Game.settings.get("swap_sticks", false)
	var dev0: String = Controls.device
	Game.settings["swap_sticks"] = true
	Controls.set_device(Controls.TOUCH)
	hud._refresh_touch()
	hud.show_banner("TWIN WICK", "Two flames at once, side by side   (Rite of Many Wicks 1/3)", 2.0)
	await tree.process_frame
	await tree.process_frame
	var sub: Label = hud.banner_sub
	var r: Rect2 = sub.get_global_rect()
	var lines: int = sub.get_line_count()
	var ok := r.position.x >= 0.0 and r.end.x <= vs.x and lines <= 2
	_say("banner subtitle, Swap sticks, %dx%d" % [vs.x, vs.y], ok, "subtitle x %d..%d of %d, %d lines" % [r.position.x, r.end.x, vs.x, lines])
	await _shot(at, "qa_banner_swap")
	Game.settings["swap_sticks"] = swap0
	Controls.set_device(dev0)
	hud._refresh_touch()


## The Kitchen's hot stove tops were hard to see on a phone (a 16 px tile turning orange on an orange-brown floor):
## a hot top now throws a few rising embers, like a hearth's coals (area_gimmicks._kitchen_step, visual only).
static func _stove_embers(at: Node) -> void:
	var tree: SceneTree = at.get_tree()
	var w: Node = await _new_run(at, {"seed": 4242})
	w.floor_areas = {Areas.TEST_DEPTH: "kitchen"}
	w._start_floor(Areas.TEST_DEPTH)
	await _frames(tree, 2)
	var g: AreaGimmicks = null
	for c in w.layout["cells"]:
		if w.layout["cells"][c]["type"] != "normal":
			continue
		w.layout["cells"][c]["cleared"] = true   # an empty room: the stoves heat with nobody fighting
		at._jump(w, c)
		await _frames(tree, 2)
		g = AreaGimmicks.of(w.room)
		if g and not g.stoves.is_empty():
			break
	if g == null or g.stoves.is_empty():
		_say("hot stove tops throw embers (Kitchen)", false, "no Kitchen room with stove tops")
		return
	w.player.invuln = 99.0
	var waited := 0
	while waited < 900 and not g.stoves.any(func(s): return g.stove_state(s) == "hot"):
		await tree.physics_frame
		waited += 1
	await tree.create_timer(0.4).timeout
	var parts: FxParts = Juice.of(w).hot
	var embers := 0
	var hot := 0
	for s in g.stoves:
		if g.stove_state(s) != "hot":
			continue
		hot += 1
		var r := Rect2(w.room.position + w.room.cell_pos(s["c"]) + Vector2(-4, -30), Vector2(24, 46))
		for i in parts.count():
			if parts.ramp[i] == FxParts.EMBER and r.has_point(parts.pos[i]):
				embers += 1
	_say("hot stove tops throw embers (Kitchen)", hot > 0 and embers >= hot, "%d embers over %d hot tops" % [embers, hot])
	await _shot(at, "qa_stove_hot")
	w.player.invuln = 0.0


## A hit's freeze (world.hitstop: time x0.05-0.15 for a moment) ends with a tween that waits while the game is
## paused. Pausing in that moment (II, Back, a call or notification taking the screen) left the pause menu,
## Settings, the Journal and Save & quit's screen fade running at that speed (a 0.42 s fade took 8 s).
static func _pause_in_hitstop(at: Node) -> void:
	var tree: SceneTree = at.get_tree()
	var w: Node = await _new_run(at, {"seed": 4242})
	w.hitstop(0.35, 0.05)   # the guardian's fall uses 0.35 s; a hit 0.06 s
	w.toggle_pause()
	await _frames(tree, 4)
	var paused_ts := Engine.time_scale
	var t0 := Time.get_ticks_msec()
	RunSave.flush()
	at.main.goto("title")   # Save & quit
	while not (at.main.current and at.main.current.name == "Title" and not at.main._busy) and Time.get_ticks_msec() - t0 < 20000:
		await tree.process_frame
	var quit_s := (Time.get_ticks_msec() - t0) / 1000.0
	_say("a pause during a hit's freeze: menus at full speed", is_equal_approx(paused_ts, Game.base_time_scale) and quit_s < 2.0,
		"time x%.2f while paused, Save & quit's fade %.1f s" % [paused_ts, quit_s])


## The same freeze when a reading card (or the versus card) pauses the house instead of the pause menu: a diary
## page's card opening on the frame Tallow is hurt (a hot stove top, his own bomb) ran at x0.05, so its 0.6 s
## "unread" hold kept every tap out for about 12 s.
static func _card_in_hitstop(at: Node) -> void:
	var tree: SceneTree = at.get_tree()
	var w: Node = await _new_run(at, {"seed": 4242})
	at.args["diary"] = true   # the card stays open until closed here
	var d := Diary.of(w)
	w.hitstop(0.06, 0.05)   # a hit (world.on_player_hurt)
	d._open_card("family")
	await tree.create_timer(0.7, true, false, true).timeout   # real time
	var ts := Engine.time_scale
	var card: PageCard = d.card as PageCard
	var held: float = card._t if card and is_instance_valid(card) else -1.0
	_say("a reading card opened during a hit's freeze", is_equal_approx(ts, Game.base_time_scale) and held >= PageCard.HOLD,
		"time x%.2f, the card's hold %.2f s of %.1f after 0.7 s" % [ts / Game.base_time_scale, held, PageCard.HOLD])
	if card and is_instance_valid(card):
		card.close()
	await tree.create_timer(0.3, true, false, true).timeout
	at.args.erase("diary")


## Quick restart (pause menu > Restart) from Tonight's Candle and from a 7-floor night in a level-3 slot: the
## night is scored / recorded once, the next one is the same kind of night (the same house tonight, level 2,
## 4 floors; a new 7-floor house at the slot's level), the slot keeps one saved run (the new one).
static func _restart_kinds(at: Node) -> void:
	var tree: SceneTree = at.get_tree()
	var lv0: int = Game.level
	Game.set_level(Game.slot, 3)
	var date := Time.get_date_string_from_system()
	var w: Node = await _new_run(at, {"seed": hash("wax&wane" + date), "daily": true, "candle": "tallow"})
	var seed0: int = w.run_seed
	w.toggle_pause()
	w.quick_restart()
	var n: Node = await _next_world(at, w)
	var nights: Array = Game.records.get("daily_history", [])
	var ok_daily: bool = n != null and n.daily and n.run_seed == seed0 and int(n.level) == 2 and int(n.night_floors) == 4 \
		and str(Game.records.get("daily_date", "")) == date and not nights.is_empty() and str(nights[0].get("date", "")) == date
	_say("Quick restart in Tonight's Candle", ok_daily, "daily %s, same house %s, level %s, floors %s, scored %s" % [
		n.daily if n else "-", n.run_seed == seed0 if n else "-", n.level if n else "-", n.night_floors if n else "-",
		Game.records.get("daily_date", "")])
	var w7: Node = await _new_run(at, {"floors": 7})
	var seed7: int = w7.run_seed
	w7.toggle_pause()
	w7.quick_restart()
	var n7: Node = await _next_world(at, w7)
	await _frames(tree, 4)
	var snap: Dictionary = RunSave.snap.get("run", {})
	var ok7: bool = n7 != null and int(n7.night_floors) == 7 and int(n7.level) == 3 and n7.run_seed != seed7 \
		and int(snap.get("floors", 0)) == 7 and int(snap.get("run_seed", 0)) == int(n7.run_seed)
	_say("Quick restart in a 7-floor night (level 3)", ok7, "floors %s, level %s, new house %s, saved run floors %s of the new house %s" % [
		n7.night_floors if n7 else "-", n7.level if n7 else "-", n7.run_seed != seed7 if n7 else "-", snap.get("floors", "-"),
		int(snap.get("run_seed", 0)) == int(n7.run_seed) if n7 else "-"])
	Game.set_level(Game.slot, lv0)


## The world that replaces `old` (Quick restart), once it can be played.
static func _next_world(at: Node, old: Node) -> Node:
	var tree: SceneTree = at.get_tree()
	var waited := 0
	while waited < 1200 and not (at.main.current != old and at.main.current and at.main.current.name == "Game" \
			and at.main.current.get("player") != null and not at.main._busy):
		await tree.process_frame
		waited += 1
	var n: Node = at.main.current
	return n if n != old and n and n.name == "Game" else null
