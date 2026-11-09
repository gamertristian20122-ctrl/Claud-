class_name MovesTour
extends RefCounted
## v2.3 special moves: the screenshot tour and the headless judge (scripts/game/moves.gd).
##   xvfb-run ... -- --autotest --tour --moves --shots=/abs/dir [--fit]   each candle's move mid-action,
##        the HUD button (recharging, ready, refused), the Keys page, the Journal and the Candle Box
##   godot --headless --path . -- --autotest --movescheck                every move against its numbers,
##        the input frame timing (key, touch), the hold / pause rules; [moves] PASS/FAIL lines, exit 1 on a FAIL

const CANDLES := ["tea_light", "party", "pillar", "moonwick", "tallow", "black_taper"]

static var _fails := 0
static var _spawn_frame := -1
static var _last_shot: Shot


# ================================================================ staging

## A fresh run with `candle` on a fixed seed, in floor 1's start room (quiet, wide open).
static func _stage(at: Node, candle: String, seed_n := 4242) -> Node:
	var tree: SceneTree = at.get_tree()
	Game.records["unlocked"] = Candles.ORDER.duplicate()
	at.main.goto("game", {"seed": seed_n, "candle": candle})
	while not (at.main.current and at.main.current.name == "Game" and at.main.current.get("player") != null and not at.main._busy):
		await tree.process_frame
	var w: Node = at.main.current
	var p: Player = w.player
	var waited := 0
	while (p.frozen or Juice.holding(w) or w.transitioning) and waited < 600:
		await tree.physics_frame
		waited += 1
	await at._wait(0.5)
	p.wax = 100.0
	p.move_cd = 0.0
	p.invuln = 0.0
	return w


static func _center(w: Node) -> Vector2:
	return w.room.position + Vector2(136, 112)


static func _put(w: Node, at_lp: Vector2) -> void:
	w.player.global_position = w.room.position + at_lp
	w.player.vel = Vector2.ZERO


static func _lodgers(w: Node, kind: String, offsets: Array) -> Array:
	var out := []
	for o in offsets:
		var e: Enemy = w.spawn_enemy(kind, w.player.global_position + (o as Vector2))
		if e:
			out.append(e)
	return out


static func _clear_foes(w: Node) -> void:
	for e in w.enemies.duplicate():
		if is_instance_valid(e):
			e.alive = false
			e.queue_free()
	w.enemies.clear()
	for s in w.enemy_shots:
		if is_instance_valid(s):
			s.queue_free()
	w.enemy_shots.clear()


static func _ok(name: String, cond: bool, detail: String) -> void:
	if not cond:
		_fails += 1
	print("[moves] %-34s %s  (%s)" % [name, "PASS" if cond else "FAIL", detail])


static func _key(action: String, pressed: bool) -> InputEventKey:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var k := (e as InputEventKey).duplicate() as InputEventKey
			k.pressed = pressed
			if k.keycode == KEY_NONE:
				k.keycode = k.physical_keycode
			return k
	return null


static func _watch_shots(w: Node) -> void:
	if w.has_meta("moves_watch"):
		return
	w.set_meta("moves_watch", true)
	w.fx_layer.child_entered_tree.connect(func(n: Node):
		if n is Shot and (n as Shot).friendly:
			_last_shot = n
			if _spawn_frame < 0:
				_spawn_frame = Engine.get_physics_frames())


# ================================================================ the judge

static func check(at: Node) -> void:
	_fails = 0
	var tree: SceneTree = at.get_tree()
	Game.base_time_scale = 1.0
	Engine.time_scale = 1.0
	Game.no_save = true
	Controls.set_device(Controls.KEYS)
	# ---- the table and the input map
	var all_moves := true
	for c in Candles.ORDER:
		all_moves = all_moves and Moves.LIST.has(Moves.for_candle(c))
	_ok("every candle has a move", all_moves, ", ".join(Candles.ORDER.map(func(c): return "%s=%s" % [c, Moves.for_candle(c)])))
	var sp := InputMap.action_get_events("special")
	var has_shift := sp.any(func(e): return e is InputEventKey and e.physical_keycode == KEY_SHIFT and e.location == KEY_LOCATION_LEFT)
	var has_f := sp.any(func(e): return e is InputEventKey and e.physical_keycode == KEY_F)
	var has_lt := sp.any(func(e): return e is InputEventJoypadMotion and e.axis == JOY_AXIS_TRIGGER_LEFT)
	var has_thumb := sp.any(func(e): return e is InputEventMouseButton and e.button_index in [MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2])
	var ks := InputMap.action_get_events("keepsake")
	var ks_clean := not ks.any(func(e): return (e is InputEventKey and e.physical_keycode == KEY_SHIFT) or (e is InputEventJoypadMotion and e.axis == JOY_AXIS_TRIGGER_LEFT))
	var ks_keeps := ks.any(func(e): return e is InputEventKey and e.physical_keycode == KEY_Q) and ks.any(func(e): return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_LEFT_SHOULDER)
	_ok("special = LShift, F, LT, thumb", has_shift and has_f and has_lt and has_thumb, "shift %s f %s lt %s thumb %s" % [has_shift, has_f, has_lt, has_thumb])
	_ok("keepsake keeps Q / LB only", ks_clean and ks_keeps, "glyphs %s / %s" % [Controls.bound_glyph("keepsake", false), Controls.bound_glyph("keepsake", true)])
	# rebinding: special -> G, a clash with the bomb is refused, reset puts Left Shift back
	var g := InputEventKey.new()
	g.physical_keycode = KEY_G
	var r1 := Controls.rebind("special", g)
	var g_ok := r1 == "" and Controls.bound_glyph("special", false) == "G"
	var e_key := InputEventKey.new()
	e_key.physical_keycode = KEY_E
	var r2 := Controls.rebind("special", e_key)
	Controls.reset_binds()
	var ls := InputEventKey.new()   # a real Left Shift press reports Shift as held
	ls.physical_keycode = KEY_SHIFT
	ls.keycode = KEY_SHIFT
	ls.location = KEY_LOCATION_LEFT
	ls.shift_pressed = true
	ls.pressed = true
	var r3 := Controls.rebind("bomb", ls)
	_ok("rebind special (G, clash, reset)", g_ok and r2 == "bomb" and r3 == "special" and Controls.bound_glyph("special", false) == "SHIFT",
		"G -> %s, E clash -> '%s', bomb on Left Shift -> '%s', reset -> %s" % [g_ok, r2, r3, Controls.bound_glyph("special", false)])

	# ---- frame timing (Tea Light): key press between two physics steps -> the move fires on the next one
	var w: Node = await _stage(at, "tea_light")
	var p: Player = w.player
	_put(w, Vector2(136, 112))
	await tree.process_frame
	Moves.fired_frame = -1
	var f0 := Engine.get_physics_frames()
	Input.parse_input_event(_key("special", true))
	for i in 20:
		await tree.physics_frame
		if Moves.fired_frame >= 0:
			break
	Input.parse_input_event(_key("special", false))
	var key_lat := Moves.fired_frame - f0 if Moves.fired_frame >= 0 else 99
	_ok("key -> move (physics frames)", key_lat == 1, "%d (1 = the next physics step)" % key_lat)
	await at._wait(2.8)
	# touch: a finger on the HUD's move button
	Controls.set_device(Controls.TOUCH)
	await tree.physics_frame
	await tree.process_frame
	var mb: MoveButton = w.hud.move_btn
	p.move_cd = 0.0
	var vp_pos := mb.position + mb.size / 2.0
	var t := InputEventScreenTouch.new()
	t.index = 2
	t.pressed = true
	t.position = w.get_viewport().get_screen_transform() * vp_pos
	Moves.fired_frame = -1
	f0 = Engine.get_physics_frames()
	Input.parse_input_event(t)
	for i in 20:
		await tree.physics_frame
		if Moves.fired_frame >= 0:
			break
	var up := t.duplicate() as InputEventScreenTouch
	up.pressed = false
	Input.parse_input_event(up)
	var touch_lat := Moves.fired_frame - f0 if Moves.fired_frame >= 0 else 99
	_ok("touch button -> move (frames)", touch_lat == 1, "%d; button %s at %s, hit area %s" % [touch_lat, mb.size, mb.position, mb.hit_rect().size])
	Controls.set_device(Controls.KEYS)
	await at._wait(2.8)

	# ---- Skip: 48 px in about 0.12 s, untouchable for 0.3 s, through an enemy shot
	_put(w, Vector2(100, 112))
	p.move_cd = 0.0
	await tree.physics_frame
	var x0 := p.global_position.x
	var wax0 := p.wax
	w.enemy_shot(p.global_position + Vector2(30, -8), Vector2(-130, 0))
	var used := p.use_move(Vector2.RIGHT)
	var inv := p.invuln
	for i in 8:
		await tree.physics_frame
	var d8 := p.global_position.x - x0
	await at._wait(0.4)
	var dist := p.global_position.x - x0
	_ok("Skip: dash distance", used and d8 >= 44.0 and dist >= 46.0 and dist <= 54.0, "%.1f px after 8 frames, %.1f px at rest" % [d8, dist])
	_ok("Skip: i-frames + shot through", inv >= 0.29 and p.wax >= wax0 - 0.6 and Achievements.is_unlocked("move_skip"),
		"invuln %.2f s, wax %.1f -> %.1f, Close Shave %s" % [inv, wax0, p.wax, Achievements.is_unlocked("move_skip")])
	_ok("Skip: cooldown", absf(p.move_cd - (2.5 - 0.4 - 8.0 / 60.0)) < 0.1 and not p.use_move(Vector2.RIGHT), "%.2f s left" % p.move_cd)
	# never while holding a relic aloft, and the cooldown waits through a pause
	p.move_cd = 0.0
	p.hold_aloft(Art.tex(Moves.icon("skip")))
	var held := p.use_move(Vector2.LEFT)
	await at._wait(1.1)
	p.move_cd = 1.0
	w.toggle_pause()
	await tree.create_timer(0.5, true, false, true).timeout
	var cd_paused := p.move_cd
	w.toggle_pause()
	await at._wait(0.2)
	_ok("held aloft / paused", not held and is_equal_approx(cd_paused, 1.0) and p.move_cd < 0.95,
		"held -> %s, cd 1.00 -> %.2f paused -> %.2f after" % [held, cd_paused, p.move_cd])

	# ---- Sparkler: 12 sparks, 2x shot damage each, pops enemy shots in its radius
	w = await _stage(at, "party")
	p = w.player
	_put(w, Vector2(136, 112))
	var foes := _lodgers(w, "slug", [Vector2(24, 0), Vector2(-24, 0), Vector2(0, -22), Vector2(0, 26)])
	await at._wait(0.9)
	var hp0 := foes.map(func(e): return e.hp)
	for k in 3:
		w.enemy_shot(p.global_position + Vector2.from_angle(k * 2.0) * 30.0 + Vector2(0, -6), Vector2.ZERO)
	var shots0: int = w.enemy_shots.filter(func(s): return is_instance_valid(s) and not s._dead).size()
	used = p.use_move()
	await at._wait(0.35)
	var dmg := []
	for i in foes.size():
		var e: Enemy = foes[i]
		dmg.append(snappedf(float(hp0[i]) - (e.hp if is_instance_valid(e) else 0.0), 0.01))
	var left: int = w.enemy_shots.filter(func(s): return is_instance_valid(s) and not s._dead).size()
	var each := Moves.SPARK_DMG * p.damage
	_ok("Sparkler: every foe hit", used and dmg.all(func(d): return float(d) >= each - 0.01), "damage %s (one spark = %.2f)" % [dmg, each])
	_ok("Sparkler: pops shots", shots0 == 3 and left == 0 and Achievements.is_unlocked("move_sparkler"), "%d -> %d shots, Party Popper %s" % [shots0, left, Achievements.is_unlocked("move_sparkler")])
	_clear_foes(w)

	# ---- Slam: rooted 0.25 s, then lodgers in 40 px stunned 1.2 s, a guardian slowed; urns crack
	w = await _stage(at, "pillar")
	p = w.player
	_put(w, Vector2(136, 112))
	foes = _lodgers(w, "slug", [Vector2(28, 0), Vector2(-28, 4), Vector2(0, -26)])
	var far: Array = _lodgers(w, "slug", [Vector2(0, 60)])
	var boss: Enemy = w.spawn_enemy("big_zombie", p.global_position + Vector2(30, 24))
	await at._wait(1.0)
	x0 = p.global_position.x
	used = p.use_move()
	Input.parse_input_event(_key("move_right", true))
	for i in 9:
		await tree.physics_frame
	var early := foes.filter(func(e): return is_instance_valid(e) and float(e.get_meta("rfx_st", {}).get("stun", 0.0)) > 0.0).size()
	var root_dx := absf(p.global_position.x - x0)
	Input.parse_input_event(_key("move_right", false))
	await at._wait(0.25)
	var stunned := foes.filter(func(e): return is_instance_valid(e) and e.alive and float(e.get_meta("rfx_st", {}).get("stun", 0.0)) > 0.8 and not e.is_physics_processing()).size()
	var far_ok: bool = far.is_empty() or float((far[0] as Enemy).get_meta("rfx_st", {}).get("stun", 0.0)) <= 0.0
	var bst: Dictionary = boss.get_meta("rfx_st", {}) if is_instance_valid(boss) else {}
	_ok("Slam: wind-up roots the candle", used and early == 0 and root_dx <= 1.5, "nothing stunned before the slam (%d), moved %.1f px" % [early, root_dx])
	_ok("Slam: stuns lodgers in reach", stunned == foes.size() and far_ok and Achievements.is_unlocked("move_slam"), "%d of %d stunned, the far one %s" % [stunned, foes.size(), "spared" if far_ok else "STUNNED"])
	_ok("Slam: a guardian is slowed, not stunned", float(bst.get("slow", 0.0)) > 0.5 and float(bst.get("stun", 0.0)) <= 0.0, "guardian %s" % [bst.keys().filter(func(k): return not str(k).begins_with("_"))])
	await at._wait(1.2)
	var after := foes.filter(func(e): return is_instance_valid(e) and e.alive and e.is_physics_processing()).size()
	_ok("Slam: the stun wears off", after == foes.filter(func(e): return is_instance_valid(e) and e.alive).size(), "%d moving again" % after)
	_clear_foes(w)

	# ---- Blink: over one tile of rubble, never through two, never out of the room
	w = await _stage(at, "moonwick")
	p = w.player
	var room: Room = w.room
	var grid: Array = room.data["grid"]
	var saved := grid.duplicate(true)
	for y in Room.ROWS:
		for x in Room.COLS:
			grid[y][x] = "."
	grid[4][7] = "R"
	var from := room.position + Room.IN + Vector2(5 * 16 + 8, 4 * 16 + 10)
	var to := Moves.blink_target(room, from, Vector2.RIGHT, Moves.BLINK_DIST)
	var hop_ok := to.x > room.position.x + Room.IN.x + 8 * 16 + 4 and not room.blocked(to, Player.RADIUS)
	grid[4][8] = "R"
	var to2 := Moves.blink_target(room, from, Vector2.RIGHT, Moves.BLINK_DIST)
	var wall_ok := to2.x < room.position.x + Room.IN.x + 7 * 16 and not room.blocked(to2, Player.RADIUS)
	grid[4][7] = "P"
	grid[4][8] = "P"
	var to3 := Moves.blink_target(room, from, Vector2.RIGHT, Moves.BLINK_DIST)
	var pit_ok := to3.x > room.position.x + Room.IN.x + 9 * 16 and not room.blocked(to3, Player.RADIUS)
	var edge := room.position + Room.IN + Vector2(14 * 16 + 4, 4 * 16 + 8)
	var to4 := Moves.blink_target(room, edge, Vector2.RIGHT, Moves.BLINK_DIST)
	var in_ok := room.inner_rect().has_point(to4) and not room.blocked(to4, Player.RADIUS)
	_ok("Blink: over one rock", hop_ok, "lands %.0f px on" % (to.x - from.x))
	_ok("Blink: stops at two rocks", wall_ok, "lands %.0f px on (the first rock starts at %.0f)" % [to2.x - from.x, room.position.x + Room.IN.x + 7 * 16 - from.x])
	_ok("Blink: over a two-tile pit", pit_ok, "lands %.0f px on" % (to3.x - from.x))
	_ok("Blink: stays inside the walls", in_ok, "from the east wall -> %s" % (to4 - room.position).round())
	# the real move: i-frames on arrival, and three pits crossed in one room -> Moon Hop
	p.global_position = from
	for k in 3:
		p.move_cd = 0.0
		p.global_position = from
		used = p.use_move(Vector2.RIGHT)
		await tree.physics_frame
	_ok("Blink: i-frames + Moon Hop", used and p.invuln > 0.1 and Achievements.is_unlocked("move_blink"), "invuln %.2f, Moon Hop %s" % [p.invuln, Achievements.is_unlocked("move_blink")])
	room.data["grid"] = saved

	# ---- Flare Up: 2 minutes of wax for 3 s of fire (x1.5 shots that burn); refused below 5 minutes
	w = await _stage(at, "tallow")
	p = w.player
	_put(w, Vector2(136, 112))
	_watch_shots(w)
	await tree.physics_frame
	wax0 = p.wax
	used = p.use_move()
	var paid := wax0 - p.wax
	await tree.physics_frame
	_last_shot = null
	Input.parse_input_event(_key("shoot_right", true))
	for i in 6:
		await tree.physics_frame
	Input.parse_input_event(_key("shoot_right", false))
	var s1: Shot = _last_shot
	var flare_ok := s1 != null and is_equal_approx(s1.dmg, p.damage * Moves.FLARE_DMG) and s1.burn >= Moves.FLARE_BURN
	_ok("Flare Up: pays 2 minutes", used and paid >= 1.99 and paid <= 2.05, "wax %.2f -> %.2f" % [wax0, p.wax])
	_ok("Flare Up: shots x1.5 and alight", flare_ok, "shot dmg %s (x%.1f), burn %s" % [s1.dmg if s1 else -1.0, Moves.FLARE_DMG, s1.burn if s1 else -1.0])
	await at._wait(3.2)
	_last_shot = null
	Input.parse_input_event(_key("shoot_left", true))
	for i in 30:
		await tree.physics_frame
	Input.parse_input_event(_key("shoot_left", false))
	var s2: Shot = _last_shot
	_ok("Flare Up: ends after 3 s", s2 != null and is_equal_approx(s2.dmg, p.damage), "shot dmg %s" % (s2.dmg if s2 else -1.0))
	p.move_cd = 0.0
	p.wax = 4.5
	used = p.use_move()
	_ok("Flare Up: refused below 5 minutes", not used and p.wax >= 4.49 and p.move_cd == 0.0, "wax 4.5 -> %.2f, cd %.1f" % [p.wax, p.move_cd])
	p.wax = 100.0

	# ---- Snuff: 2 s dark (lodgers lose track, no shots), then a black flame (x3, pierce 3)
	w = await _stage(at, "black_taper")
	p = w.player
	_put(w, Vector2(80, 112))
	_watch_shots(w)
	foes = _lodgers(w, "slug", [Vector2(120, 0)])
	await at._wait(0.8)
	var pos0 := p.global_position
	used = p.use_move()
	_put(w, Vector2(80, 60))   # it slips away in the dark
	await tree.physics_frame
	var e0: Enemy = foes[0]
	var fooled := Moves.dark and Moves.target_of(e0, p).distance_to(pos0) < 12.0 and Moves.target_of(e0, p).distance_to(p.global_position) > 30.0
	_spawn_frame = -1
	_last_shot = null
	Input.parse_input_event(_key("shoot_right", true))
	await at._wait(1.5)
	var dark_shot := _spawn_frame >= 0
	await at._wait(0.8)
	Input.parse_input_event(_key("shoot_right", false))
	var s3: Shot = _last_shot
	var black_ok := s3 != null and s3.has_meta("black_flame") and is_equal_approx(s3.dmg, p.damage * Moves.SNUFF_DMG) and s3.pierce >= Moves.SNUFF_PIERCE
	_ok("Snuff: lodgers lose track", used and fooled, "target %s from %s (candle at %s)" % [Moves.target_of(e0, p).round(), pos0.round(), p.global_position.round()])
	_ok("Snuff: no shots in the dark", not dark_shot and not Moves.dark, "a shot in the dark %s, dark now %s" % [dark_shot, Moves.dark])
	_ok("Snuff: the black flame", black_ok, "dmg %s pierce %s" % [s3.dmg if s3 else -1.0, s3.pierce if s3 else -1])
	_clear_foes(w)

	print("[moves] %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])


# ================================================================ the tour

static func tour(at: Node) -> void:
	Game.no_save = true
	var tree: SceneTree = at.get_tree()
	for c in CANDLES:
		var w: Node = await _stage(at, c, 77)
		var p: Player = w.player
		# a normal room of floor 2 with a few lodgers round the candle
		var cell := Vector2i(-99, -99)
		for cc in w.layout["cells"].keys():
			if w.layout["cells"][cc]["type"] == "normal":
				cell = cc
				break
		if cell != Vector2i(-99, -99):
			w.layout["cells"][cell]["cleared"] = true
			at._jump(w, cell)
		_put(w, Vector2(120, 112))
		p.wax = 96.0
		await at._wait(0.6)
		var id := Moves.for_candle(c)
		var foes := _lodgers(w, "goblin", [Vector2(34, -8), Vector2(-30, 16), Vector2(8, -30)])
		if id == "slam":
			foes.append(w.spawn_enemy("skelet", p.global_position + Vector2(26, 18)))
		w.hud.show_hint(Controls.special_hint(id), 5.0)   # the first-fight tip (judged by --fit on every shot)
		await at._wait(0.9)
		for e in foes:
			if is_instance_valid(e):
				e.hp = 99.0   # they stay for the pictures
		match id:
			"skip":
				w.enemy_shot(p.global_position + Vector2(52, -8), Vector2(-120, 0))
				await at._wait(0.15)
				p.use_move(Vector2.RIGHT)
				await tree.physics_frame
				await tree.physics_frame
				await tree.physics_frame
				await at._shot("move_skip")
			"sparkler":
				for k in 4:
					w.enemy_shot(p.global_position + Vector2.from_angle(0.6 + k * 1.5) * 34.0 + Vector2(0, -6), Vector2.from_angle(0.6 + k * 1.5 + PI) * 30.0)
				await at._wait(0.1)
				p.use_move()
				await at._wait(0.07)
				await at._shot("move_sparkler")
			"slam":
				p.use_move()
				await at._wait(0.16)
				await at._shot("move_slam_windup")
				await at._wait(0.13)
				await at._shot("move_slam")
			"blink":
				var from := p.global_position
				w.room.data["grid"][4][7] = "P"
				p.use_move(Vector2.RIGHT)
				await at._wait(0.06)
				await at._shot("move_blink")
				p.global_position = from
			"flare":
				p.use_move()
				await at._wait(0.2)
				Input.parse_input_event(_key("shoot_right", true))
				await at._wait(0.22)
				await at._shot("move_flare")
				Input.parse_input_event(_key("shoot_right", false))
			"snuff":
				p.use_move()
				await at._wait(0.6)
				await at._shot("move_snuff_dark")
				Input.parse_input_event(_key("shoot_right", true))
				await at._wait(1.6)
				await at._shot("move_snuff_black")
				Input.parse_input_event(_key("shoot_right", false))
		# the HUD button: recharging (the Pillar's ring part lit), then the moment the Skip is back
		await at._wait(0.6)
		if c == "pillar":
			await at._shot("hud_button_recharging")
		if c == "tea_light":
			var waited := 0
			while p.move_cd > 0.0 and waited < 400:
				await tree.physics_frame
				waited += 1
			await at._wait(0.12)
			await at._shot("hud_button_ready_flash")
	# Flare Up refused (red ring) and the keyboard look of the button
	var w2: Node = await _stage(at, "tallow", 77)
	w2.player.wax = 4.0
	await at._wait(0.4)
	await at._shot("hud_button_refused")
	w2.player.wax = 80.0
	await at._wait(2.2)   # let the clock's 1:45 banner (low wax) clear before the next pictures
	Controls.set_device(Controls.KEYS)
	await at._wait(0.3)
	w2.player.wax = 80.0
	w2.player.keepsake = "flare_match"
	w2.player.charge = 1
	await at._wait(0.3)
	w2.hud.show_hint(Controls.special_hint("flare"), 4.0)
	await at._shot("hud_keys")
	Controls.set_device(Controls.PAD)
	await at._wait(0.3)
	await at._shot("hud_pad")
	Controls.set_device(Controls.TOUCH)
	Game.settings["swap_sticks"] = true
	Game.settings_changed.emit()
	await at._wait(0.3)
	await at._shot("hud_touch_swapped")
	Game.settings["swap_sticks"] = false
	Game.settings_changed.emit()
	await at._wait(0.2)
	# the Keys page (Settings) and the Controls page
	Controls.set_device(Controls.KEYS)
	w2.toggle_pause()
	await at._wait(0.3)
	SettingsPanel.open(w2.hud.pause_layer, 2)
	await at._wait(0.4)
	await at._shot("settings_keys")
	for n in w2.hud.pause_layer.get_children():
		if n.has_meta("modal"):
			n.queue_free()
	SettingsPanel.open(w2.hud.pause_layer, 1)
	await at._wait(0.4)
	await at._shot("settings_controls")
	for n in w2.hud.pause_layer.get_children():
		if n.has_meta("modal"):
			n.queue_free()
	w2.toggle_pause()
	# thumb reach on a touch screen: centre distances from where the right thumb rests (the ghost
	# aim stick, Hud._draw_ghosts) to each right-hand button, and from button to button
	Controls.set_device(Controls.TOUCH)
	w2.player.keepsake = "flare_match"
	await at._wait(0.3)
	reach(w2)
	await at._shot("hud_touch_all_three")
	# the Candle Box on the title and the Journal's Candles tab show each candle's move
	Game.records["unlocked"] = Candles.ORDER.duplicate()
	at.main.goto("title")
	await at._wait(3.4)
	var title: Node = at.main.current
	for c in ["tallow", "black_taper"]:
		title.sel = c
		title._show_candle()
		await at._wait(0.3)
		await at._shot("candle_box_%s" % c)
	var j := Journal.open(title.root)
	await at._wait(0.4)
	j._set_tab(Journal.TABS.find("candles"), false)
	for c in Candles.ORDER:
		j._select(Candles.ORDER.find(c))
		await at._wait(0.3)
		await at._shot("journal_candle_%s" % c)
	Audio.stop_all()


## Prints the right-hand buttons' centre distances (the thumb-reach measure, ROADMAP_V2 section 1).
static func reach(w: Node) -> void:
	var hud: Hud = w.hud
	var vs: Vector2 = hud.view_size()
	var thumb := Vector2(vs.x - 64, vs.y - 52)   # where the ghost aim stick sits (the thumb's rest)
	var mb: MoveButton = hud.move_btn
	var c_move := mb.position + mb.size / 2.0
	var c_bomb := hud.bomb_btn.position + hud.bomb_btn.size / 2.0
	var c_keep := hud.keep_btn.position + Vector2(15, 13)   # the keepsake's circle centre (_draw_keep)
	var mm := 150.0 / vs.x   # a 6.5" phone held sideways shows the 480 px width over about 150 mm
	print("[moves] reach %dx%d: thumb rest %s -> move %.0f px (%.0f mm), bomb %.0f px (%.0f mm), keepsake %.0f px (%.0f mm); move-bomb %.0f px, bomb-keepsake %.0f px; move hit area %s, bomb %s" % [
		vs.x, vs.y, thumb, thumb.distance_to(c_move), thumb.distance_to(c_move) * mm, thumb.distance_to(c_bomb),
		thumb.distance_to(c_bomb) * mm, thumb.distance_to(c_keep), thumb.distance_to(c_keep) * mm,
		c_move.distance_to(c_bomb), c_bomb.distance_to(c_keep), mb.hit_rect().size, Rect2(hud.bomb_btn.position, hud.bomb_btn.size).grow(4).size])
	var safe := Rect2(Vector2(hud.safe_insets().x, 0), vs - Vector2(hud.safe_insets().x + hud.safe_insets().y, 0))
	print("[moves] reach %dx%d: all three inside the safe area: %s" % [vs.x, vs.y,
		safe.encloses(Rect2(mb.position, mb.size)) and safe.encloses(Rect2(hud.bomb_btn.position, hud.bomb_btn.size)) and safe.encloses(Rect2(hud.keep_btn.position, hud.keep_btn.size))])
