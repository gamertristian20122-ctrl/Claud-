class_name FeelProbe
extends RefCounted
## v2.6 feel pass (docs/streams/v26_feel.md): where a play-test run's time goes. The bot calls tick()
## every physics frame with what it is doing; each run's results print one [feel] block:
##   fight      lodgers or a guardian are up (the room is not cleared yet)
##   doors      doors shut, the lodgers not out yet (the beat after entering a room)
##   pickup     the room is clear and the bot walks to something on the floor
##   walk       the room is clear and the bot walks to the next door (first visit)
##   walk_back  the same in a room it already cleared (crossing the house again)
##   special    a special room's bell / music box / font
##   held       no control: a relic held aloft, the guardian's entrance
##   pan        the camera pans to the next room (no control)
##   trapdoor   down the trapdoor to the next floor (no control)
## Game seconds (at --speed=4 the clock runs 4x, every number stays in game time).

static var t := {}
static var rooms_new := 0
static var rooms_back := 0
static var pans: Array = []
static var drops: Array = []        # trapdoor -> control back
static var clear_exit: Array = []   # room cleared -> through the next door
static var swept := 0               # loose drops the clear magnet brought (pickup.gd counts them)
static var _cell := Vector2i(-99, -99)
static var _floor := 0
static var _trans := false
static var _trans_t := 0.0
static var _trans_floor := 0
static var _back := false
static var _cleared_seen := false
static var _clear_at := -1.0
static var _clock := 0.0


static func reset() -> void:
	t = {}
	rooms_new = 0
	rooms_back = 0
	pans = []
	drops = []
	clear_exit = []
	swept = 0
	_cell = Vector2i(-99, -99)
	_floor = 0
	_trans = false
	_back = false
	_cleared_seen = false
	_clear_at = -1.0
	_clock = 0.0


static func _add(k: String, dt: float) -> void:
	t[k] = float(t.get(k, 0.0)) + dt


static func tick(w: Node, intent: String, dt: float) -> void:
	var p: Player = w.player
	if p == null or p.dead or w.finished or w.room == null:
		return
	_clock += dt
	if w.get("swept") != null:
		swept = int(w.swept)
	if w.cur_cell != _cell or w.floor_num != _floor:
		if _clear_at >= 0.0 and w.floor_num == _floor:
			clear_exit.append(_clock - _clear_at)
		_clear_at = -1.0
		var d0: Dictionary = w.room.data
		_back = w.floor_num == _floor and bool(d0.get("visited", false)) and bool(d0.get("cleared", false))
		if _back:
			rooms_back += 1
		else:
			rooms_new += 1
		_cleared_seen = bool(d0.get("cleared", false))
		_cell = w.cur_cell
		_floor = w.floor_num
	if w.transitioning:
		if not _trans:
			_trans = true
			_trans_t = 0.0
			_trans_floor = w.floor_num
		_trans_t += dt
		_add("trans", dt)
		return
	if _trans:
		_trans = false
		(drops if w.floor_num != _trans_floor else pans).append(_trans_t)
	var d: Dictionary = w.room.data
	if d["cleared"] and not _cleared_seen:
		_cleared_seen = true
		_clear_at = _clock
	var cat := ""
	if p.frozen or float(p.get("_hold_t")) > 0.0:
		cat = "held"
	elif not d["cleared"] or w.count_enemies() > 0:
		cat = "fight" if (w.room_spawned or d["type"] == "boss" or w.count_enemies() > 0) else "doors"
	else:
		match intent:
			"pickup": cat = "pickup"
			"special": cat = "special"
			"walk": cat = "walk_back" if _back else "walk"
			_: cat = "idle"
	_add(cat, dt)


static func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for x in a:
		s += float(x)
	return s / a.size()


static func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


static func report() -> String:
	var total := 0.0
	for k in t:
		total += float(t[k])
	total = maxf(total, 0.001)
	var order := ["fight", "doors", "pickup", "walk", "walk_back", "special", "held", "trans", "idle"]
	var parts: Array = []
	for k in order:
		if t.has(k):
			parts.append("%s %.0fs %.1f%%" % [k, float(t[k]), 100.0 * float(t[k]) / total])
	var rooms := rooms_new + rooms_back
	var lines: Array = []
	lines.append("[feel]    time %.0fs: %s" % [total, ", ".join(parts)])
	lines.append("[feel]    rooms entered %d: new %d, walked back through %d (%.0f%%); clear -> next door median %.1fs mean %.1fs (%d rooms); swept drops %d" % [
		rooms, rooms_new, rooms_back, 100.0 * rooms_back / maxf(1.0, rooms), _median(clear_exit), _mean(clear_exit), clear_exit.size(), swept])
	lines.append("[feel]    room pans %d, mean %.2fs; trapdoors %d, mean %.2fs (no control)" % [pans.size(), _mean(pans), drops.size(), _mean(drops)])
	return "\n".join(lines)


# ================================================================ --autotest --feelcheck: the feel judges
## Headless, seeded (4242), physics frames at 60 Hz. Each line prints a number; 99 = never / eaten.
##   turn90        frames for a full-speed run to swing 90 degrees (velocity within 20 degrees of the new way)
##   touch_full    thumb travel (game px) on the touch move stick for full speed; touch_10px = speed at 10 px
##   pan / drop    frames without control in a room-to-room pan / down a trapdoor
##   tap_in_pan    a fire tap that ends 3 frames before a pan ends: frames after control returns to the ember
##   move_in_pan   the special move pressed 4 frames before a pan ends: frames after control returns to the move
##   magnet        seconds for a coin 110 px away in a cleared room to reach a Tallow standing still
##   magnet_full / magnet_shop   a wax drop at full wax / a shop item stay where they are (true = stayed)
##   auto_front / auto_override / auto_rate   Aim: Auto picks the foe in front, the stick overrides it, the
##                 fire rate is the same as holding a fire key (embers in 2 s, auto vs keys)
static var _ember_frame := -1
static var _ember_dir := Vector2.ZERO
static var _embers := 0


static func check(at: Node) -> void:
	var tree: SceneTree = at.get_tree()
	Game.base_time_scale = 1.0
	Engine.time_scale = 1.0
	Controls.set_device(Controls.KEYS)
	at.main.goto("game", {"seed": 4242})
	while not (at.main.current and at.main.current.name == "Game" and at.main.current.get("player") != null and not at.main._busy):
		await tree.process_frame
	var w: Node = at.main.current
	var p: Player = w.player
	var waited := 0
	while (p.frozen or Juice.holding(w) or w.transitioning) and waited < 600:
		await tree.physics_frame
		waited += 1
	await at._wait(0.6)
	w.fx_layer.child_entered_tree.connect(func(n: Node):
		if n is Shot and (n as Shot).friendly:
			_embers += 1
			if _ember_frame < 0:
				_ember_frame = Engine.get_physics_frames()
				_ember_dir = ((n as Shot).vel - p.vel * 0.25).normalized())
	for c in w.layout["cells"].keys():   # no fights: the pans cross cleared rooms
		w.layout["cells"][c]["cleared"] = true
	var res := {}
	res["turn90"] = await _turn90(tree, p)
	Controls.set_device(Controls.TOUCH)
	await tree.physics_frame
	var tilt: Array = await _touch_tilt(tree, w)
	res["touch_full"] = tilt[0]
	res["touch_10px"] = tilt[1]
	Controls.set_device(Controls.KEYS)
	var pans: Array = await _pans(tree, w, p)
	res["pan"] = pans[0]
	res["tap_in_pan"] = pans[1]
	res["move_in_pan"] = pans[2]
	res["drop"] = await _drop(tree, w, p)
	var mag: Array = await _magnet(tree, w, p)
	res["magnet"] = mag[0]
	res["magnet_full"] = mag[1]
	res["magnet_shop"] = mag[2]
	if Game.settings.has("aim"):
		var au: Array = await _auto(tree, w, p)
		res["auto_front"] = au[0]
		res["auto_override"] = au[1]
		res["auto_rate"] = au[2]
	if w.has_method("open_map"):
		res["map"] = await _map(tree, w)
	if w.has_method("quick_restart"):
		res["restart"] = await _restart(at, tree, w)
	print("[feel] check (physics frames at 60 Hz; 99 = never / eaten):")
	for k in res:
		print("[feel]   %s: %s" % [k, res[k]])
	var ok := int(res["turn90"]) <= 6 and float(res["touch_full"]) <= 16.0 and int(res["tap_in_pan"]) < 99 and int(res["move_in_pan"]) < 99
	ok = ok and float(res["magnet"]) < 3.0 and bool(res["magnet_full"]) and bool(res["magnet_shop"])
	ok = ok and res.has("auto_front") and bool(res["auto_front"]) and bool(res["auto_override"])
	ok = ok and res.has("auto_rate") and absi(int(res["auto_rate"][0]) - int(res["auto_rate"][1])) <= 1
	ok = ok and res.has("map") and str(res["map"]) == "opened paused, M closed and resumed"
	ok = ok and res.has("restart") and str(res["restart"]).begins_with("lit")
	print("[feel] check %s" % ("PASS" if ok else "FAIL"))


## The full map: a tap on the minimap opens it over a paused game; M closes it and play goes on.
static func _map(tree: SceneTree, w: Node) -> String:
	Controls.set_device(Controls.TOUCH)
	var mm: Control = w.hud.minimap
	DesignCheck._touch(w, 5, mm.position + mm.size / 2.0, true)
	await tree.process_frame
	await tree.process_frame
	DesignCheck._touch(w, 5, mm.position + mm.size / 2.0, false)
	await tree.process_frame
	var opened: bool = w.paused and is_instance_valid(w.hud.map_layer)
	Controls.set_device(Controls.KEYS)
	_press("map", true)
	await tree.process_frame
	await tree.process_frame
	_press("map", false)
	await tree.process_frame
	await tree.process_frame
	var closed: bool = not w.paused and not is_instance_valid(w.hud.map_layer)
	if opened and closed:
		return "opened paused, M closed and resumed"
	return "opened=%s closed=%s" % [opened, closed]


## Quick restart: the run is recorded (given up) and a new one is lit with the same candle and night length.
static func _restart(at: Node, tree: SceneTree, w: Node) -> String:
	var runs := int(Game.records["runs"])
	var cid: String = w.candle_id
	var nf: int = w.night_floors
	var old_seed: int = w.run_seed
	w.quick_restart()
	var waited := 0
	while waited < 600 and not (at.main.current != w and at.main.current and at.main.current.name == "Game" and not at.main._busy):
		await tree.process_frame
		waited += 1
	var n: Node = at.main.current
	if n == w or n == null or n.name != "Game":
		return "no new run"
	var hist: Array = Game.records.get("run_history", [])
	var noted: bool = not hist.is_empty() and str(hist[0].get("killer", "")) == "gave_up"
	return "lit %s, %d floors, runs %d -> %d, old run noted as given up: %s, same seed: %s" % [n.candle_id, n.night_floors,
		runs, int(Game.records["runs"]), noted, n.run_seed == old_seed] if n.candle_id == cid and n.night_floors == nf else "wrong night"


static func _press(action: String, on: bool) -> void:
	Input.parse_input_event(DesignCheck._key_event(action, on))


static func _turn90(tree: SceneTree, p: Player) -> int:
	p.position = p.world.room.center() + Vector2(-60, -30)
	p.vel = Vector2.ZERO
	_press("move_right", true)
	for i in 30:
		await tree.physics_frame
	_press("move_right", false)
	_press("move_down", true)
	var got := 99
	for i in 40:
		await tree.physics_frame
		if p.vel.length() > 8.0 and absf(rad_to_deg(p.vel.angle_to(Vector2.DOWN))) < 20.0:
			got = i + 1
			break
	_press("move_down", false)
	await DesignCheck._settle(tree, p, 30)
	return got


## [the smallest drag (px) on the move stick that runs at full speed, the speed at a 10 px drag]
static func _touch_tilt(tree: SceneTree, w: Node) -> Array:
	var vs: Vector2 = w.hud.view_size()
	var at := Vector2(vs.x * 0.22, vs.y * 0.62)
	var full := 99.0
	var at10 := 0.0
	for d in range(4, 23):
		DesignCheck._touch(w, 4, at, true)
		await tree.physics_frame
		await tree.process_frame
		DesignCheck._drag(w, 4, at + Vector2(d, 0), Vector2(d, 0))
		await tree.physics_frame
		await tree.process_frame   # after the HUD's physics step: what the world reads
		var k: float = w.hud.move_vec.length()
		if d == 10:
			at10 = snappedf(k, 0.01)
		if k >= 0.99 and full == 99.0:
			full = d
		DesignCheck._touch(w, 4, at + Vector2(d, 0), false)
		await tree.physics_frame
	await DesignCheck._settle(tree, w.player, 10)
	return [full, at10]


static func _no_control(w: Node, p: Player) -> bool:
	return w.transitioning or p.frozen


## [pan frames, frames from control back to a fire tap's ember, frames to a special move pressed in the pan]
static func _pans(tree: SceneTree, w: Node, p: Player) -> Array:
	var dir := Vector2i.ZERO
	for d in FloorGen.DIRS:
		if w.layout["cells"].has(w.cur_cell + d) and w.room.doors.has(d):
			dir = d
			break
	# 1. a plain pan: how long without control
	w.go_through(dir)
	var n := 0
	while _no_control(w, p) and n < 200:
		await tree.physics_frame
		n += 1
	await DesignCheck._settle(tree, p, 40)
	# 2. back again with a fire tap that ends 3 frames before control returns
	_ember_frame = -1
	w.go_through(-dir)
	var f := 0
	while _no_control(w, p) and f < 200:
		if f == n - 6:
			_press("shoot_right", true)
		if f == n - 3:
			_press("shoot_right", false)
		await tree.physics_frame
		f += 1
	_press("shoot_right", false)
	var back := Engine.get_physics_frames()
	for i in 30:
		if _ember_frame >= 0:
			break
		await tree.physics_frame
	var tap := (_ember_frame - back) if _ember_frame >= 0 else 99
	await DesignCheck._settle(tree, p, 60)
	# 3. the special move (Tallow: Flare Up) pressed 4 frames before control returns
	p.move_cd = 0.0
	p.wax = maxf(p.wax, 60.0)
	var f0 := Moves.fired_frame
	w.go_through(dir)
	f = 0
	while _no_control(w, p) and f < 200:
		if f == n - 4:
			_press("special", true)
		if f == n - 2:
			_press("special", false)
		await tree.physics_frame
		f += 1
	_press("special", false)
	back = Engine.get_physics_frames()
	var mv := 99
	for i in 30:
		if Moves.fired_frame != f0:
			mv = maxi(0, Moves.fired_frame - back)
			break
		await tree.physics_frame
	await DesignCheck._settle(tree, p, 30)
	return [n, tap, mv]


static func _drop(tree: SceneTree, w: Node, p: Player) -> int:
	w.descend()
	var n := 0
	while _no_control(w, p) and n < 300:
		await tree.physics_frame
		n += 1
	for c in w.layout["cells"].keys():
		w.layout["cells"][c]["cleared"] = true
	await DesignCheck._settle(tree, p, 30)
	return n


## [seconds for a far coin to reach a still Tallow (99 = never), a wax drop at full wax stayed, a shop item stayed]
static func _magnet(tree: SceneTree, w: Node, p: Player) -> Array:
	var c: Vector2 = w.room.center()
	p.position = c + Vector2(-50, 0)
	p.vel = Vector2.ZERO
	await DesignCheck._settle(tree, p, 40)
	var coins := p.coins
	var coin: Pickup = w.add_pickup("coin", w.free_spot_near(c + Vector2(60, 40)))
	var shop: Pickup = w.add_pickup("relic", w.free_spot_near(c + Vector2(40, -40)), "lamp_oil", 12)
	p.wax = p.wax_max
	var wax: Pickup = w.add_pickup("wax_small", w.free_spot_near(c + Vector2(30, 0)))
	var wax0 := wax.global_position
	var shop0 := shop.global_position
	var t := 99.0
	for i in 240:
		await tree.physics_frame
		p.wax = p.wax_max   # the melt must not make the drop wanted
		if p.coins > coins:
			t = snappedf((i + 1) / 60.0, 0.01)
			break
	await DesignCheck._settle(tree, p, 30)
	var full_stayed := is_instance_valid(wax) and wax.global_position.distance_to(wax0) < 1.0
	var shop_stayed := is_instance_valid(shop) and shop.global_position.distance_to(shop0) < 1.0
	if is_instance_valid(coin) and not coin.taken:
		coin.queue_free()
	return [t, full_stayed, shop_stayed]


## Aim: Auto. [the first ember went to the foe in front, a dragged thumb overrode it, [embers auto, embers keys] in 2 s]
static func _auto(tree: SceneTree, w: Node, p: Player) -> Array:
	Controls.set_device(Controls.TOUCH)
	var was: String = Game.settings["aim"]
	Game.settings["aim"] = "auto"
	var c: Vector2 = w.room.center()
	p.position = c
	p.facing = Vector2.RIGHT
	await DesignCheck._settle(tree, p, 10)
	var front: Enemy = w.spawn_enemy("slug", c + Vector2(64, -2))
	var behind: Enemy = w.spawn_enemy("slug", c + Vector2(-44, -2))
	var waited := 0
	while waited < 240 and not (front.active and behind.active):
		await tree.physics_frame
		waited += 1
	for e in [front, behind]:
		e.max_hp = 999.0
		e.hp = 999.0
	p.facing = Vector2.RIGHT
	var vs: Vector2 = w.hud.view_size()
	var thumb := Vector2(vs.x * 0.78, vs.y * 0.62)
	p.fire_cd = 0.0
	_ember_frame = -1
	DesignCheck._touch(w, 3, thumb, true)
	for i in 30:
		await tree.physics_frame
		if _ember_frame >= 0:
			break
	var in_front := _ember_frame >= 0 and _ember_dir.x > 0.8
	DesignCheck._touch(w, 3, thumb, false)
	await DesignCheck._settle(tree, p, 40)
	# the thumb moves: the stick wins (the touch itself may fire at the foe first; the next ember counts)
	DesignCheck._touch(w, 3, thumb, true)
	await tree.physics_frame
	DesignCheck._drag(w, 3, thumb + Vector2(0, -12), Vector2(0, -12))
	await tree.physics_frame
	_ember_frame = -1
	for i in 40:
		await tree.physics_frame
		if _ember_frame >= 0:
			break
	var override := _ember_frame >= 0 and _ember_dir.y < -0.8
	DesignCheck._touch(w, 3, thumb + Vector2(0, -12), false)
	await DesignCheck._settle(tree, p, 40)
	# the fire rate: 2 s of auto against 2 s of a held fire key
	_embers = 0
	DesignCheck._touch(w, 3, thumb, true)
	for i in 120:
		await tree.physics_frame
	DesignCheck._touch(w, 3, thumb, false)
	var n_auto := _embers
	await DesignCheck._settle(tree, p, 40)
	Controls.set_device(Controls.KEYS)
	_embers = 0
	_press("shoot_right", true)
	for i in 120:
		await tree.physics_frame
	_press("shoot_right", false)
	var n_keys := _embers
	Game.settings["aim"] = was
	for e in [front, behind]:
		if is_instance_valid(e):
			e.queue_free()
	return [in_front, override, [n_auto, n_keys]]


# ================================================================ --tour --feel: the v2.6 changes on screen
## xvfb-run ... -- --autotest --tour --feel --shots=DIR [--fit]: the magnet mid-sweep, a hit's mark, Aim: Auto
## firing, the full map, the pause menu (Map, Restart), the Restart question, Settings (Aim, Pickup magnet).
static func tour(at: Node) -> void:
	Controls.set_device(Controls.TOUCH)
	at.main.goto("game", {"seed": 4242})
	var tree: SceneTree = at.get_tree()
	while not (at.main.current and at.main.current.name == "Game" and at.main.current.get("player") != null and not at.main._busy):
		await tree.process_frame
	var w: Node = at.main.current
	var p: Player = w.player
	await at._wait(3.0)   # the floor banner clears
	p.invuln = 0.0
	# walk a few rooms (cleared) so the map has a floor to show, and leave a drop behind in one of them
	var order: Array = [w.cur_cell]
	var cells: Dictionary = w.layout["cells"]
	var i := 0
	while i < order.size() and order.size() < 6:
		for d in FloorGen.DIRS:
			var n: Vector2i = order[i] + d
			if cells.has(n) and not n in order and cells[n]["type"] in ["normal", "treasure", "shop"]:
				order.append(n)
		i += 1
	var normal := Vector2i(-99, -99)
	for c in order:
		cells[c]["cleared"] = true
		at._jump(w, c)
		await at._wait(0.2)
		if cells[c]["type"] == "normal":
			normal = c
	if normal != Vector2i(-99, -99) and normal != order[0]:
		cells[order[0]]["pickups"].append({"kind": "wax_small", "pos": Vector2.ZERO, "item": "", "price": 0})
	if normal != Vector2i(-99, -99):
		at._jump(w, normal)
	await at._wait(0.6)
	# 1. the pickup magnet: drops spread over the room fly in (wax is wanted: the candle is not full)
	var c0: Vector2 = w.room.center()
	p.position = c0 + Vector2(-70, 6)
	p.wax = 70.0
	for off in [Vector2(60, -40), Vector2(90, 20), Vector2(40, 46), Vector2(100, -10), Vector2(20, -50)]:
		w.add_pickup("coin", w.free_spot_near(c0 + off))
	w.add_pickup("wax_small", w.free_spot_near(c0 + Vector2(70, 40)))
	w.add_pickup("bomb", w.free_spot_near(c0 + Vector2(110, 30)))
	await at._wait(0.72)
	await at._shot("feel_magnet_sweep")
	await at._wait(0.25)
	await at._shot("feel_magnet_arrive")
	await at._wait(1.0)
	# 2. a hit's mark: a bolt from the left
	p.invuln = 0.0
	w.enemy_shot(p.global_position + Vector2(-34, -7), Vector2(170, 0))
	var waited := 0
	while p.invuln <= 0.0 and waited < 60:
		await tree.physics_frame
		waited += 1
	await at._wait(0.06)
	await at._shot("feel_hit_mark")
	await at._wait(1.4)
	# 3. Aim: Auto - the right thumb rests on the screen, Tallow fires at the foe in front
	Game.settings["aim"] = "auto"
	p.position = c0 + Vector2(-30, 6)
	var foe: Enemy = w.spawn_enemy("slug", c0 + Vector2(40, -10))
	var foe2: Enemy = w.spawn_enemy("slug", c0 + Vector2(-80, 30))
	waited = 0
	while waited < 240 and not (foe.active and foe2.active):
		await tree.physics_frame
		waited += 1
	var vs: Vector2 = w.hud.view_size()
	DesignCheck._touch(w, 3, Vector2(vs.x * 0.8, vs.y * 0.66), true)
	await at._wait(0.75)
	await at._shot("feel_aim_auto")
	DesignCheck._touch(w, 3, Vector2(vs.x * 0.8, vs.y * 0.66), false)
	Game.settings["aim"] = "assist"
	for e in [foe, foe2]:
		if is_instance_valid(e):
			e.queue_free()
	await at._wait(0.3)
	# 4. the full map (as a tap on the minimap opens it), then the pause menu under it
	w.open_map()
	await at._wait(0.5)
	await at._shot("feel_full_map")
	if is_instance_valid(w.hud.map_layer):
		w.hud.map_layer.queue_free()
	await at._wait(0.3)
	await at._shot("feel_pause_menu")
	w.hud._confirm_restart()
	await at._wait(0.3)
	await at._shot("feel_restart_ask")
	var top: Node = w.hud.root.get_child(w.hud.root.get_child_count() - 1)
	top.queue_free()
	await at._wait(0.2)
	# 5. Settings: Controls (Aim) and Game (Pickup magnet)
	SettingsPanel.open(w.hud.root, 1)
	await at._wait(0.4)
	await at._shot("feel_settings_controls")
	top = w.hud.root.get_child(w.hud.root.get_child_count() - 1)
	top.queue_free()
	await at._wait(0.2)
	SettingsPanel.open(w.hud.root, 0)
	await at._wait(0.4)
	await at._shot("feel_settings_game")
