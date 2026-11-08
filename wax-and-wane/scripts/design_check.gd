class_name DesignCheck
extends RefCounted
## The design pass's outside judges (docs/design/MDA.md). Each prints [design] lines and a PASS/FAIL.
##   godot --headless --path . -- --autotest --designcheck            all of them
##   ... --designcheck --latency      input -> first shot / first step, hit -> flash + sound, in physics frames
##   ... --designcheck --share        the results Share text: <= 280, has the seed / date, same text twice
##   ... --designcheck --floors       20 floor-1 layouts: rooms to the treasure, the first rooms' tier and lodgers

static var _spawn_frame := -1


static func run(at: Node) -> void:
	var a: Dictionary = at.args
	if a.has("floorshots"):   # (with xvfb and --shots=dir) for tools/design_contrast.py
		await floor_shots(at)
		return
	if a.has("ghostshot"):    # (with xvfb and --shots=dir) for tools/design_ghost_check.py
		await ghost_shots(at)
		return
	var any := a.has("latency") or a.has("share") or a.has("floors")
	if not any or a.has("share"):
		share_check()
	if not any or a.has("floors"):
		floors_check()
	if not any or a.has("latency"):
		await latency(at)


# ================================================================ 2. feedback under 100 ms

static func latency(at: Node) -> void:
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
		if n is Shot and (n as Shot).friendly and _spawn_frame < 0:
			_spawn_frame = Engine.get_physics_frames())
	var res := {}
	# --- keyboard: the fire key, pressed between two physics steps (a real key press lands there too)
	res["key_fire"] = await _key_to_shot(tree, p, "shoot_right")
	await _settle(tree, p, 40)
	# --- a quick tap (3 frames) 0.27 s after a shot, while the flame recharges: kept or eaten?
	res["tap_in_cooldown"] = await _tap_in_cooldown(tree, p)
	await _settle(tree, p, 40)
	# --- touch: the aim stick (finger down, then a drag past the stick's dead zone)
	Controls.set_device(Controls.TOUCH)
	await tree.physics_frame
	var vs: Vector2 = w.hud.view_size()
	var aim_at := Vector2(vs.x * 0.78, vs.y * 0.62)
	res["touch_fire_from_drag"] = await _touch_to_shot(tree, w, aim_at, Vector2(12, 0), false)
	await _settle(tree, p, 40)
	res["touch_fire_from_down"] = await _touch_to_shot(tree, w, aim_at, Vector2(12, 0), true)
	await _settle(tree, p, 40)
	# a small flick of the thumb (5 viewport px, about 2 mm on a phone): does it fire at all?
	res["touch_fire_small_flick"] = await _touch_to_shot(tree, w, aim_at, Vector2(0, -5), false)
	await _settle(tree, p, 40)
	# --- move: keyboard and the move stick; frames until Tallow is drawn one pixel further on
	Controls.set_device(Controls.KEYS)
	res["key_move"] = await _key_to_move(tree, p, "move_left")
	await _settle(tree, p, 40)
	# --- dodge: running right at full speed, then left: frames until drawn a pixel left of the turn
	res["key_reverse"] = await _key_reverse(tree, p)
	await _settle(tree, p, 40)
	Controls.set_device(Controls.TOUCH)
	res["touch_move"] = await _touch_to_move(tree, w, Vector2(vs.x * 0.22, vs.y * 0.62), Vector2(18, 0))
	await _settle(tree, p, 40)
	Controls.set_device(Controls.KEYS)
	# --- damage feedback: an enemy bolt hits Tallow; flash, sound and the HUD in the same frame?
	res["hurt"] = await _hurt_probe(tree, w, p)
	await at._wait(1.5)
	res["enemy_hit"] = await _enemy_hit_probe(tree, w, p)
	var ok := true
	for k in ["key_fire", "touch_fire_from_drag", "touch_fire_small_flick"]:
		ok = ok and int(res[k]) == 1
	ok = ok and int(res["key_reverse"]) <= 6 and int(res["tap_in_cooldown"]) < 99
	ok = ok and int(res["hurt"][0]) == 0 and int(res["hurt"][1]) == 0 and int(res["enemy_hit"][0]) == 0 and int(res["enemy_hit"][1]) == 0
	print("[design] latency (physics frames at 60 Hz, 1 = the next physics step after the input arrives):")
	print("[design]   key fire -> ember spawned: %s" % res["key_fire"])
	print("[design]   3-frame tap 0.27 s into the 0.42 s recharge -> ember (99 = eaten): %s" % res["tap_in_cooldown"])
	print("[design]   touch drag past dead zone -> ember: %s" % res["touch_fire_from_drag"])
	print("[design]   touch down (drag 1 frame later) -> ember: %s" % res["touch_fire_from_down"])
	print("[design]   touch small flick (5 px) -> ember: %s" % res["touch_fire_small_flick"])
	print("[design]   key move -> first drawn pixel: %s" % res["key_move"])
	print("[design]   key reverse at full speed -> first drawn pixel the other way: %s" % res["key_reverse"])
	print("[design]   touch move stick -> first drawn pixel: %s" % res["touch_move"])
	print("[design]   bolt hit -> [flash lag, sound lag, hud ghost lag]: %s" % [res["hurt"]])
	print("[design]   ember hit -> [enemy flash lag, sound lag]: %s" % [res["enemy_hit"]])
	print("[design] latency %s" % ("PASS" if ok else "FAIL"))


static func _settle(tree: SceneTree, p: Player, frames: int) -> void:
	for i in frames:
		await tree.physics_frame
	p.vel = Vector2.ZERO


static func _key_event(action: String, pressed: bool) -> InputEventKey:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var k := (e as InputEventKey).duplicate() as InputEventKey
			k.pressed = pressed
			if k.keycode == KEY_NONE:
				k.keycode = k.physical_keycode
			return k
	return null


## Frames from the key press to the first ember. The press goes in after a frame's physics step
## (as a real key does, between steps); 1 means the very next step fired.
static func _key_to_shot(tree: SceneTree, p: Player, action: String) -> int:
	await tree.process_frame
	_spawn_frame = -1
	var f0 := Engine.get_physics_frames()
	Input.parse_input_event(_key_event(action, true))
	for i in 30:
		await tree.physics_frame
		if _spawn_frame >= 0:
			break
	Input.parse_input_event(_key_event(action, false))
	return _spawn_frame - f0 if _spawn_frame >= 0 else 99


static func _key_to_move(tree: SceneTree, p: Player, action: String) -> int:
	await tree.process_frame
	var x0 := roundf(p.global_position.x)
	var f0 := Engine.get_physics_frames()
	Input.parse_input_event(_key_event(action, true))
	var got := 99
	for i in 30:
		await tree.process_frame   # after this frame's physics: what the next draw shows
		if roundf(p.global_position.x) != x0:
			got = Engine.get_physics_frames() - f0
			break
	Input.parse_input_event(_key_event(action, false))
	return got


## One shot, release; 16 frames later a 3-frame tap. Frames from the tap to the second ember.
static func _tap_in_cooldown(tree: SceneTree, p: Player) -> int:
	await _key_to_shot(tree, p, "shoot_up")
	for i in 15:
		await tree.physics_frame
	await tree.process_frame
	_spawn_frame = -1
	var f0 := Engine.get_physics_frames()
	Input.parse_input_event(_key_event("shoot_up", true))
	for i in 3:
		await tree.physics_frame
	await tree.process_frame
	Input.parse_input_event(_key_event("shoot_up", false))
	for i in 30:
		await tree.physics_frame
		if _spawn_frame >= 0:
			break
	return _spawn_frame - f0 if _spawn_frame >= 0 else 99


static func _key_reverse(tree: SceneTree, p: Player) -> int:
	Input.parse_input_event(_key_event("move_right", true))
	for i in 30:
		await tree.physics_frame
	await tree.process_frame
	var peak := roundf(p.global_position.x)
	var f0 := Engine.get_physics_frames()
	Input.parse_input_event(_key_event("move_right", false))
	Input.parse_input_event(_key_event("move_left", true))
	var got := 99
	for i in 40:
		await tree.process_frame
		var x := roundf(p.global_position.x)
		peak = maxf(peak, x)
		if x < peak:
			got = Engine.get_physics_frames() - f0
			break
	Input.parse_input_event(_key_event("move_left", false))
	return got


static func _screen(w: Node, vp_pos: Vector2) -> Vector2:
	return w.get_viewport().get_screen_transform() * vp_pos


static func _touch(w: Node, idx: int, vp_pos: Vector2, pressed: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = idx
	t.pressed = pressed
	t.position = _screen(w, vp_pos)
	Input.parse_input_event(t)


static func _drag(w: Node, idx: int, vp_pos: Vector2, rel: Vector2) -> void:
	var d := InputEventScreenDrag.new()
	d.index = idx
	d.position = _screen(w, vp_pos)
	d.relative = rel
	Input.parse_input_event(d)


static func _touch_to_shot(tree: SceneTree, w: Node, at_pos: Vector2, drag: Vector2, from_down: bool) -> int:
	await tree.process_frame
	_spawn_frame = -1
	_touch(w, 3, at_pos, true)
	var f0 := Engine.get_physics_frames()
	# headless runs many idle frames per physics step: step once so the down and the drag land in
	# different physics frames (the thumb moves a frame after it lands)
	await tree.physics_frame
	await tree.process_frame
	if not from_down:
		f0 = Engine.get_physics_frames()
	_drag(w, 3, at_pos + drag, drag)
	for i in 30:
		await tree.physics_frame
		if _spawn_frame >= 0:
			break
	_touch(w, 3, at_pos + drag, false)
	return _spawn_frame - f0 if _spawn_frame >= 0 else 99


static func _touch_to_move(tree: SceneTree, w: Node, at_pos: Vector2, drag: Vector2) -> int:
	var p: Player = w.player
	await tree.process_frame
	_touch(w, 4, at_pos, true)
	await tree.physics_frame
	await tree.process_frame
	var x0 := roundf(p.global_position.x)
	var f0 := Engine.get_physics_frames()
	_drag(w, 4, at_pos + drag, drag)
	var got := 99
	for i in 30:
		await tree.process_frame
		if roundf(p.global_position.x) != x0:
			got = Engine.get_physics_frames() - f0
			break
	_touch(w, 4, at_pos + drag, false)
	return got


## An enemy bolt flies into Tallow. Returns [flash lag, sound lag, HUD ghost lag] in physics frames
## after the frame that took the wax (0 = the same frame).
static func _hurt_probe(tree: SceneTree, w: Node, p: Player) -> Array:
	p.invuln = 0.0
	var snd0 = Audio._last_play.get("player_hurt", -1.0)
	var wax0 := p.wax
	w.enemy_shot(p.global_position + Vector2(-24, -8), Vector2(160, 0))
	var hit_f := -1
	var flash_f := -1
	var snd_f := -1
	var hud_f := -1
	for i in 60:
		await tree.physics_frame
		var f := Engine.get_physics_frames() - 1   # state left by the previous step
		if hit_f < 0 and p.wax < wax0 - 1.0:
			hit_f = f
		if hit_f >= 0:
			if flash_f < 0 and float(p.get("_white")) > 0.0:
				flash_f = f
			if snd_f < 0 and Audio._last_play.get("player_hurt", -1.0) != snd0:
				snd_f = f
			if hud_f < 0 and float(w.hud.get("_ghost_hold")) > 0.0:
				hud_f = f
			if flash_f >= 0 and snd_f >= 0 and hud_f >= 0:
				break
	if hit_f < 0:
		return [99, 99, 99]
	return [flash_f - hit_f if flash_f >= 0 else 99, snd_f - hit_f if snd_f >= 0 else 99, hud_f - hit_f if hud_f >= 0 else 99]


static func _enemy_hit_probe(tree: SceneTree, w: Node, p: Player) -> Array:
	var e: Enemy = w.spawn_enemy("slug", p.global_position + Vector2(40, 0))
	if e == null:
		return [99, 99]
	var waited := 0
	while not e.active and waited < 240:
		await tree.physics_frame
		waited += 1
	var hp0 := e.hp
	var snd0 = Audio._last_play.get("hit_enemy", -1.0)
	var dir: Vector2 = (e.global_position + Vector2(0, -e.half_h) - (p.global_position + Vector2(0, -6))).normalized()
	w.shoot_player(p.global_position + Vector2(0, -6) + dir * 4, dir, p, 1.0)
	var hit_f := -1
	var flash_f := -1
	var snd_f := -1
	for i in 90:
		await tree.physics_frame
		if not is_instance_valid(e):
			break
		var f := Engine.get_physics_frames() - 1
		if hit_f < 0 and e.hp < hp0:
			hit_f = f
		if hit_f >= 0:
			if flash_f < 0 and float(e.get("_flash")) > 0.0:
				flash_f = f
			if snd_f < 0 and Audio._last_play.get("hit_enemy", -1.0) != snd0:
				snd_f = f
			if flash_f >= 0 and snd_f >= 0:
				break
	if hit_f < 0:
		return [99, 99]
	return [flash_f - hit_f if flash_f >= 0 else 99, snd_f - hit_f if snd_f >= 0 else 99]


# ================================================================ 3. fair deaths: what bullets sit on

const BULLETS := ["bullet_purple", "bullet_green", "bullet_water", "bolt_bone", "bolt_cog", "bolt_page", "bolt_ring", "bolt_wax"]


## Per floor (1-5): a cleared ordinary room with Tallow in the middle ("floorbg_N", the floor colours
## the contrast tool samples), then every enemy bullet held still in a row across the lit floor
## ("floorbullets_N", to look at). Prints the room's rect in the shot so the tool knows where to look.
static func floor_shots(at: Node) -> void:
	var tree: SceneTree = at.get_tree()
	DirAccess.make_dir_recursive_absolute(at._shots_dir)
	at.main.goto("game", {"seed": 4242})
	while not (at.main.current and at.main.current.name == "Game" and at.main.current.get("player") != null and not at.main._busy):
		await tree.process_frame
	var w: Node = at.main.current
	await at._wait(1.0)
	for n in [1, 2, 3, 4, 5]:
		w._start_floor(n)
		await at._wait(3.0)
		var cells: Array = at._normal_cells(w)
		if cells.is_empty():
			continue
		var c: Vector2i = cells[0]
		w.layout["cells"][c]["cleared"] = true
		at._jump(w, c)
		for e in w.enemies:
			if is_instance_valid(e):
				e.queue_free()
		w.player.position = w.room.center() + Vector2(0, 10)
		w.player.wax = 100.0
		await at._wait(1.2)
		var xf: Transform2D = w.room.get_global_transform_with_canvas()
		var o: Vector2 = xf.origin
		var pl: Vector2 = w.player.get_global_transform_with_canvas().origin
		print("[design] floorbg %d room_rect %d %d %d %d player %d %d" % [n, o.x, o.y, 272, 192, pl.x, pl.y])
		await at._shot("floorbg_%d" % n)
		var shots: Array = []
		var i := 0
		for k in BULLETS:
			var s := Shot.new()
			s.setup(w, w.player.global_position + Vector2(-70 + i * 20, -30), Vector2.ZERO, k, false)
			s.life = 99.0
			w.fx_layer.add_child(s)
			shots.append(s)
			i += 1
		await at._wait(0.3)
		await at._shot("floorbullets_%d" % n)
		for s in shots:
			if is_instance_valid(s):
				s.queue_free()


# ================================================================ 4. the wax price on the wax bar

## Tallow stands in reach of a priced relic (Smoke Altar style: cost_wax 15) at two wax levels, then of
## the Wax Font. Each shot gets a line in ghost.json: the game's numbers (wax, max, charred, price)
## and where the bar is, so tools/design_ghost_check.py can work out the expected pixels on its own.
static func ghost_shots(at: Node) -> void:
	var tree: SceneTree = at.get_tree()
	DirAccess.make_dir_recursive_absolute(at._shots_dir)
	at.main.goto("game", {"seed": 4242})
	while not (at.main.current and at.main.current.name == "Game" and at.main.current.get("player") != null and not at.main._busy):
		await tree.process_frame
	var w: Node = at.main.current
	var p: Player = w.player
	await at._wait(3.6)   # past the floor banner
	var rows: Array = []
	for wax in [90.0, 118.0]:
		var c: Vector2 = w.room.center()
		var a: Pickup = w.add_pickup("relic", c + Vector2(0, -20), "sharp_wick")
		a.record["cost_wax"] = 15
		a.queue_free()
		var pk: Pickup = w._spawn_pickup_node(w.room, a.record)
		p.position = c + Vector2(0, 2)
		p.frozen = true
		p.wax = wax
		w.hud.shown_wax = wax
		w.hud.ghost_wax = wax   # no red "just lost" trail: only the price shows
		await at._wait(0.6)
		p.wax = wax
		w.hud.shown_wax = wax
		w.hud.ghost_wax = wax   # no red "just lost" trail: only the price shows
		await tree.physics_frame
		await tree.process_frame
		var name := "ghost_altar_%d" % int(wax)
		rows.append(_ghost_row(w, name, 15.0, Pickup.pact_cut(p, 15.0)))
		await at._shot(name)
		if is_instance_valid(pk):
			pk.queue_free()
		await at._wait(0.3)
	# the Wax Font: four minutes an offering
	var fc: Vector2i = Specials._cell_of_type(w, "font")
	if fc == Vector2i(-99, -99):
		fc = Specials._make_special(w, "font")
	if fc != Vector2i(-99, -99):
		p.frozen = false
		at._jump(w, fc)
		await at._wait(2.8)   # past the room banner
		var feet: Vector2 = w.room.cell_center(Specials.PROP_CELL) + Vector2(0, 2)
		p.position = feet + Vector2(0, 30)
		p.frozen = true
		p.wax = 80.0
		w.hud.shown_wax = 80.0
		w.hud.ghost_wax = 80.0
		await at._wait(0.5)
		p.wax = 80.0
		w.hud.shown_wax = 80.0
		w.hud.ghost_wax = 80.0
		await tree.physics_frame
		await tree.process_frame
		rows.append(_ghost_row(w, "ghost_font", 0.0, Specials.FONT_COST))
		await at._shot("ghost_font")
	var f := FileAccess.open(at._shots_dir + "/ghost.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(rows))
	print("[design] ghost shots: %d" % rows.size())


static func _ghost_row(w: Node, name: String, cost_max: float, cost_now: float) -> Dictionary:
	var p: Player = w.player
	var bar: Control = w.hud.bar
	var o: Vector2 = bar.get_global_transform_with_canvas().origin
	var left: Texture2D = Art.tex("ui/bar_frame_left")
	return {"name": name, "wax": p.wax, "wax_max": p.wax_max, "charred": p.charred, "cost_now": cost_now, "cost_max": cost_max,
		"bar_x": o.x + float(left.get_width()), "bar_y": o.y, "inner": 128, "h": 14,
		"hud_now": w.hud.cost_now, "hud_max": w.hud.cost_max}


# ================================================================ 5. the share text

static func share_check() -> void:
	var cases := [
		{"won": true, "floor": 4, "clock": 101.5, "relics": ["a", "b", "c", "d", "e", "f", "g"], "streak": 14, "seed": 1234567890,
			"candle": "tallow", "daily": true, "date": "2026-11-08", "killer": "", "rooms": 30, "hits": 9},
		{"won": false, "floor": 3, "clock": 120.0, "relics": ["a", "b"], "streak": 6, "seed": -987654321, "candle": "tallow",
			"daily": false, "killer": "e:skelet", "rooms": 17, "boss_death": false},
		{"won": false, "floor": 2, "clock": 120.0, "relics": [], "streak": 0, "seed": 42, "candle": "tallow",
			"daily": false, "killer": "clock", "rooms": 9, "boss_death": true},
		{"won": false, "floor": 5, "clock": 120.0, "relics": range(40).map(func(i): return "r%d" % i), "streak": 99, "seed": 2147483647,
			"candle": "tallow", "daily": true, "date": "2026-12-31", "killer": "e:keeper", "rooms": 60, "boss_death": true},
	]
	var ok := true
	for c in cases:
		var a := Share.text(c)
		var b := Share.text(c.duplicate(true))
		var key: String = str(c["date"]) if c.get("daily", false) else Records.seed_text(int(c["seed"]))
		var weighted := Share.x_length(a)
		var pass_ := a.length() <= 280 and weighted <= 280 and a == b and key in a
		ok = ok and pass_
		print("[design] share (%d chars, %d on X, same twice %s, has %s %s) %s" % [a.length(), weighted, a == b, key, key in a, "ok" if pass_ else "BAD"])
		for line in a.split("\n"):
			print("[design]   | " + line)
	print("[design] share %s" % ("PASS" if ok else "FAIL"))


# ================================================================ 6. the first floor's opening

static func floors_check() -> void:
	var dists: Array = []
	var first_ok := 0
	var first_n := 0
	var tiers := {}
	var lodgers := {}
	for s in range(1, 21):
		var frng := RandomNumberGenerator.new()
		frng.seed = hash("%d:%d" % [s, 1])   # exactly as the world seeds floor 1
		var lay := FloorGen.generate(1, frng)
		var cells: Dictionary = lay["cells"]
		var best := 99
		for c in cells:
			if cells[c]["type"] == "treasure":
				best = mini(best, int(cells[c]["dist"]))
		dists.append(best)
		for c in cells:
			var d: Dictionary = cells[c]
			if d["type"] != "normal" or int(d["dist"]) > 2:
				continue
			first_n += 1
			var n := 0
			for row in d["grid"]:
				for ch in row:
					if ch in ["e", "h", "f"]:
						n += 1
			var tier := FloorGen.tier_of(d)
			tiers[tier] = int(tiers.get(tier, 0)) + 1
			lodgers[n] = int(lodgers.get(n, 0)) + 1
			if tier == "easy" and n >= 2 and n <= 3 and d.get("gentle", false):
				first_ok += 1
	var within := dists.filter(func(x): return x <= 3).size()
	var sorted := dists.duplicate()
	sorted.sort()
	print("[design] floor 1 x20: rooms from the start to the treasure %s" % [dists])
	print("[design]   treasure within 3 rooms: %d/20 (median %d, worst %d)" % [within, sorted[10], sorted[19]])
	print("[design]   dist<=2 ordinary rooms: %d; tiers %s; lodger slots %s; easy + 2-3 slow lodgers: %d/%d" % [first_n, tiers, lodgers, first_ok, first_n])
	print("[design] floors %s" % ("PASS" if within == 20 and first_ok == first_n else "FAIL"))
