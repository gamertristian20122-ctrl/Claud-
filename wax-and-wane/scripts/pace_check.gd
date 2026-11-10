class_name PaceCheck
extends RefCounted
## v2.8 pace + floor 1 (docs/streams/v28_pace.md). Two bot runs on 2.7.0 spent 44% of their time walking through
## rooms with nothing in them, and floor 1 was 4 fights of 1-3 lodgers. This is the judge of the three changes:
##   the hurry   in a room that is clear and quiet Tallow walks Player.HURRY times as fast, and not in a fight
##   the hop     the full map sends him to a room he has cleared (world.warp_to): only from a quiet room, only to
##               a cleared one, onto free floor, without touching the seeded RNG; a tap, a click, the arrows
##   the litters the Cellar's small lodgers arrive in threes as runts (one ember each, a nip for a touch)
## Each probe prints   [pace] <what>  PASS / FAIL  (the numbers it judged)   and a FAIL ends with exit code 1:
##   godot --headless --path . -- --autotest --pacecheck
## Pictures: xvfb-run ... -- --autotest --tour --pace --shots=/abs/dir

static var fails := 0


static func _say(what: String, ok: bool, detail: String) -> void:
	if not ok:
		fails += 1
	print("[pace] %-50s %s  (%s)" % [what, "PASS" if ok else "FAIL", detail])


static func _game(at: Node, params: Dictionary) -> Node:
	at.main.goto("game", params)
	var tree: SceneTree = at.get_tree()
	while not (at.main.current and at.main.current.name == "Game" and at.main.current.get("player") != null and not at.main._busy):
		await tree.process_frame
	var w: Node = at.main.current
	var waited := 0
	while (w.player.frozen or Juice.holding(w) or w.transitioning) and waited < 600:
		await tree.physics_frame
		waited += 1
	return w


## Tallow's speed after `secs` of holding right from a standstill.
static func _run_speed(at: Node, w: Node, secs: float) -> float:
	var tree: SceneTree = at.get_tree()
	var p: Player = w.player
	p.position = w.room.center() + Vector2(-90, 34)
	p.vel = Vector2.ZERO
	FeelProbe._press("move_right", true)
	var frames := int(secs * 60.0)
	for i in frames:
		await tree.physics_frame
	var v := p.vel.length()
	FeelProbe._press("move_right", false)
	return v


## The cells of this floor Tallow could walk into from the start, nearest first (never the guardian's, never a hollow).
static func _walkable(w: Node, n: int) -> Array:
	var cells: Dictionary = w.layout["cells"]
	var order: Array = [w.cur_cell]
	var i := 0
	while i < order.size() and order.size() < n:
		for d in FloorGen.DIRS:
			var c: Vector2i = order[i] + d
			if cells.has(c) and not c in order and cells[c]["type"] in ["normal", "treasure", "shop"]:
				order.append(c)
		i += 1
	return order


static func check(at: Node) -> void:
	fails = 0
	var tree: SceneTree = at.get_tree()
	Game.base_time_scale = 1.0
	Engine.time_scale = 1.0
	Controls.set_device(Controls.KEYS)
	if DisplayServer.get_name() == "headless":
		tree.root.size = Vector2i(1536, 864)
	var w: Node = await _game(at, {"seed": 4242})
	var p: Player = w.player
	await at._wait(0.4)

	# ---- the hurry
	var base := p.speed
	var quiet: float = await _run_speed(at, w, 1.6)
	_say("hurry: speed in a quiet room", absf(quiet / base - Player.HURRY) < 0.05, "%.0f px/s, x%.2f of %.0f (want x%.2f)" % [quiet, quiet / base, base, Player.HURRY])
	var foe: Enemy = w.spawn_enemy("slug", w.room.center() + Vector2(100, -50))
	w.room.data["cleared"] = false
	w.room.set_open(false, true)
	await at._wait(0.3)
	var fight: float = await _run_speed(at, w, 1.2)
	_say("hurry: none while a lodger is up", absf(fight / base - 1.0) < 0.05, "%.0f px/s, x%.2f" % [fight, fight / base])
	_say("hurry: gone within 0.2 s of a room waking", p.hurry <= 0.001, "hurry %.2f" % p.hurry)
	if is_instance_valid(foe):
		foe.queue_free()
	w.enemies.clear()
	w.room.data["cleared"] = true
	w.room.set_open(true)
	await at._wait(0.2)

	# ---- the hop
	var cells: Dictionary = w.layout["cells"]
	var order := _walkable(w, 6)
	var home: Vector2i = order[0]
	var far: Vector2i = order[order.size() - 1]
	_say("hop: not to a room never entered", not w.can_warp(far), "cell %s visited=%s" % [far, cells[far]["visited"]])
	for c in order:
		cells[c]["cleared"] = true
		at._jump(w, c)
		await at._wait(0.1)
	at._jump(w, home)
	await at._wait(0.2)
	_say("hop: to a room walked and cleared", w.can_warp(far), "cell %s" % far)
	_say("hop: not to the room he stands in", not w.can_warp(home), "cell %s" % home)
	var boss_cell: Vector2i = w.layout["boss"]
	_say("hop: not to the guardian's room unbeaten", not w.can_warp(boss_cell), "cell %s cleared=%s" % [boss_cell, cells[boss_cell]["cleared"]])
	var foe2: Enemy = w.spawn_enemy("slug", w.room.center() + Vector2(60, -30))
	await tree.physics_frame
	_say("hop: not while a lodger is up", not w.can_warp(far), "enemies %d" % w.count_enemies())
	if is_instance_valid(foe2):
		foe2.queue_free()
	w.enemies.clear()
	await tree.physics_frame
	var state0: int = w.rng.state
	var t0 := Time.get_ticks_msec()
	var ok: bool = w.warp_to(far)
	var frames := 0
	while w.transitioning and frames < 300:
		await tree.physics_frame
		frames += 1
	var landed := p.global_position
	_say("hop: Tallow arrives", ok and w.cur_cell == far and not p.frozen, "cell %s after %d frames (%d ms), frozen=%s" % [w.cur_cell, frames, Time.get_ticks_msec() - t0, p.frozen])
	_say("hop: without control for 0.4 s at most", frames <= 24, "%d frames" % frames)
	_say("hop: onto free floor", not w.room.blocked(landed, 7.0) and w.room.inner_rect().has_point(landed), "at %s" % (landed - w.room.position))
	_say("hop: the seeded RNG is untouched", w.rng.state == state0, "state %d -> %d" % [state0, w.rng.state])
	_say("hop: counted", int(w.warps) == 1, "warps %d" % w.warps)

	# ---- the map: a tap, a click, the arrows
	at._jump(w, home)
	await at._wait(0.2)
	w.open_map()
	await at._wait(0.3)
	var map: FullMap = _find_map(w.hud.root)
	_say("map: the hop line invites", map != null and map.can_hop() and map.hop_line() != "", "'%s'" % (map.hop_line() if map else ""))
	if map:
		var want: Vector2i = far
		var at_px: Vector2 = map._at(want) + Vector2(map._cw, map._ch) / 2.0
		_say("map: a tap in a room finds it", map.room_at(at_px) == want, "%s -> %s" % [at_px, map.room_at(at_px)])
		var edge: Vector2 = map._at(want) + Vector2(-3, map._ch / 2.0)
		_say("map: a tap just beside it still does", map.room_at(edge) in [want, want + Vector2i.LEFT], "%s -> %s" % [edge, map.room_at(edge)])
		_say("map: a tap on nothing is nothing", map.room_at(Vector2(-40, -40)) == Vector2i(-99, -99), "%s" % map.room_at(Vector2(-40, -40)))
		# keys / pad: up from Resume, then pick with the arrows, confirm
		map.grab_focus()
		await tree.process_frame
		var first: Vector2i = map._pick
		_say("map: the arrows start on a room to go to", w.can_warp(first), "%s" % first)
		var seen := {first: true}
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT, Vector2i.LEFT]:
			map._pick = map._step(map._pick, dir)
			seen[map._pick] = true
		var all_ok := true
		for c in seen:
			all_ok = all_ok and w.can_warp(c)
		_say("map: the arrows only land on rooms to go to", all_ok and seen.size() >= 2, "%d rooms visited by the cursor" % seen.size())
		# a click on a room (what a tap sends too)
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = at_px
		map._gui_input(ev)
		frames = 0
		while (w.transitioning or w.paused) and frames < 300:
			await tree.physics_frame
			frames += 1
		_say("map: a click on a cleared room goes there", w.cur_cell == want and not w.paused and not is_instance_valid(map), "cell %s paused=%s" % [w.cur_cell, w.paused])

	# ---- the litters (a fresh house: floor 1's rooms as the seed lays them)
	w = await _game(at, {"seed": 4243})
	p = w.player
	await at._wait(0.3)
	var litters := 0   # rooms with runts in them
	var followed := 0  # bigger lodgers that bring two along
	var runts := 0
	var others := 0
	var bad := ""
	var rooms := 0
	for c in w.layout["cells"].keys():
		if w.layout["cells"][c]["type"] != "normal":
			continue
		rooms += 1
		at._jump(w, c)
		var waited := 0
		while not w.room_spawned and waited < 240:
			await tree.physics_frame
			waited += 1
		var by_kind := {}
		for e in w.enemies:
			if not is_instance_valid(e):
				continue
			if e.runt:
				runts += 1
				by_kind[e.kind] = int(by_kind.get(e.kind, 0)) + 1
				if e.max_hp != Enemy.RUNT_HP or not e.kind in w.RUNTS:
					bad += " %s hp %.1f" % [e.kind, e.max_hp]
				if w.room.blocked(e.global_position, e.radius):
					bad += " %s in the furniture" % e.kind
			else:
				others += 1
				if w.FOLLOWERS.has(e.kind):
					followed += 1
		var room_runts := 0
		for k in by_kind:
			room_runts += int(by_kind[k])
		if room_runts > 0:
			litters += 1
		for e in w.enemies.duplicate():
			if is_instance_valid(e):
				e.queue_free()
		w.enemies.clear()
		w.layout["cells"][c]["cleared"] = true
		w.room.data["cleared"] = true
		w.room.set_open(true)
		await tree.physics_frame
	var total := runts + others
	_say("litters: the Cellar's rooms hold more lodgers", total >= rooms * 5, "%d lodgers in %d rooms (%d runts in %d rooms, %d others, %d of them with two at heel); 2.7.0 had 2-3 a room" % [total, rooms, runts, litters, others, followed])
	_say("litters: runts are runts, on free floor", bad == "" and runts > 0 and (runts - 2 * followed) % int(w.LITTER) == 0, "ok" if bad == "" else bad)
	_say("litters: a runt's touch is a nip", Enemy.RUNT_TOUCH <= 2.0 and Enemy.RUNT_TOUCH < Enemy.TOUCH[0], "%.0f min (a lodger's: %d)" % [Enemy.RUNT_TOUCH, Enemy.TOUCH[0]])
	# one ember each: a runt dies to Tallow's plain shot whatever the slot's level
	_say("litters: one ember puts a runt out", Enemy.RUNT_HP <= p.damage, "runt %.1f, Tallow's ember %.1f" % [Enemy.RUNT_HP, p.damage])
	# floor 2 keeps its own crowd
	w.floor_num = 2
	var e2: Enemy = w.spawn_enemy("goblin", w.room.center())
	_say("litters: only in the Cellar's own rooms", e2 != null and not e2.runt, "a floor-2 goblin: runt=%s hp %.1f" % [e2.runt if e2 else "?", e2.max_hp if e2 else 0.0])
	print("[pace] %d failed -> %s" % [fails, "PASS" if fails == 0 else "FAIL"])


static func _find_map(n: Node) -> FullMap:
	if n is FullMap:
		return n
	for c in n.get_children():
		var m := _find_map(c)
		if m:
			return m
	return null


# ================================================================ --tour --pace: the pictures
static func tour(at: Node) -> void:
	var tree: SceneTree = at.get_tree()
	Controls.set_device(Controls.TOUCH)
	var w: Node = await _game(at, {"seed": 4242})
	var p: Player = w.player
	await at._wait(3.0)   # the floor banner clears
	var cells: Dictionary = w.layout["cells"]
	var order := _walkable(w, 7)
	for c in order:
		cells[c]["cleared"] = true
		at._jump(w, c)
		await at._wait(0.15)
	at._jump(w, order[0])
	await at._wait(0.5)
	# 1. the hurry: Tallow mid-stride in a quiet room
	p.position = w.room.center() + Vector2(-80, 30)
	FeelProbe._press("move_right", true)
	await at._wait(0.9)
	await at._shot("pace_hurry")
	FeelProbe._press("move_right", false)
	await at._wait(0.3)
	# 2. the map on touch: rooms to go to wear a gold foot, the line says how
	Controls.set_device(Controls.TOUCH)   # the key press above made it a keyboard
	await at._wait(0.1)
	w.open_map()
	await at._wait(0.5)
	await at._shot("pace_map_touch")
	var map: FullMap = _find_map(w.hud.root)
	# 3. keys: the cursor on a room
	Controls.set_device(Controls.KEYS)
	if map:
		map.grab_focus()
		await at._wait(0.2)
		map._pick = map._step(map._pick, Vector2i.RIGHT)
		map.queue_redraw()
		await at._wait(0.2)
		await at._shot("pace_map_keys")
		# 4. the hop itself: mid-fade, then arrived
		var want: Vector2i = map._pick
		map.go(want)
		await at._wait(0.1)
		await at._shot("pace_hop_out")
		await at._wait(0.45)
		await at._shot("pace_hop_arrived")
	# 5. the map from a room that is not quiet: nothing to go to, and the line says why
	Controls.set_device(Controls.TOUCH)
	var foe: Enemy = w.spawn_enemy("slug", w.room.center() + Vector2(70, -30))
	w.room.data["cleared"] = false
	await at._wait(0.8)
	w.open_map()
	await at._wait(0.5)
	await at._shot("pace_map_busy")
	w.on_back()
	await at._wait(0.2)
	if w.paused:
		w.toggle_pause()
	if is_instance_valid(foe):
		foe.queue_free()
	w.enemies.clear()
	# 6. a Cellar room as a new night lays it: litters of runts
	w = await _game(at, {"seed": 4243})
	p = w.player
	await at._wait(3.0)
	var shown := 0
	for c in w.layout["cells"].keys():
		if w.layout["cells"][c]["type"] != "normal" or shown >= 2:
			continue
		at._jump(w, c)
		p.invuln = 99.0
		await at._wait(1.3)
		await at._shot("pace_litter_%d" % (shown + 1))
		shown += 1
		for e in w.enemies.duplicate():
			if is_instance_valid(e):
				e.queue_free()
		w.enemies.clear()
		w.layout["cells"][c]["cleared"] = true
	Audio.stop_all()
