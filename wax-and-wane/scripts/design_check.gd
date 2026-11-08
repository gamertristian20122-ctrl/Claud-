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
	# --- touch: the aim stick (finger down, then a drag past the stick's dead zone)
	Controls.set_device(Controls.TOUCH)
	await tree.physics_frame
	var vs: Vector2 = w.hud.view_size()
	var aim_at := Vector2(vs.x * 0.78, vs.y * 0.62)
	res["touch_fire_from_drag"] = await _touch_to_shot(tree, w, aim_at, Vector2(12, 0), false)
	await _settle(tree, p, 40)
	res["touch_fire_from_down"] = await _touch_to_shot(tree, w, aim_at, Vector2(12, 0), true)
	await _settle(tree, p, 40)
	# --- move: keyboard and the move stick; frames until Tallow is drawn one pixel further on
	Controls.set_device(Controls.KEYS)
	res["key_move"] = await _key_to_move(tree, p, "move_left")
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
	for k in ["key_fire", "touch_fire_from_drag"]:
		ok = ok and int(res[k]) == 1
	ok = ok and int(res["hurt"][0]) == 0 and int(res["hurt"][1]) == 0 and int(res["enemy_hit"][0]) == 0 and int(res["enemy_hit"][1]) == 0
	print("[design] latency (physics frames at 60 Hz, 1 = the next physics step after the input arrives):")
	print("[design]   key fire -> ember spawned: %s" % res["key_fire"])
	print("[design]   touch drag past dead zone -> ember: %s" % res["touch_fire_from_drag"])
	print("[design]   touch down (drag 1 frame later) -> ember: %s" % res["touch_fire_from_down"])
	print("[design]   key move -> first drawn pixel: %s" % res["key_move"])
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
	if from_down:
		await tree.process_frame   # the thumb moves on the next frame
	else:
		await tree.process_frame
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
