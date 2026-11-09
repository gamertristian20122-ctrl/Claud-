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
