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
	print("[qa] %d failed -> %s" % [fails, "PASS" if fails == 0 else "FAIL"])
	return fails


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
