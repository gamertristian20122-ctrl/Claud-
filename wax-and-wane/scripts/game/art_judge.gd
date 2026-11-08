class_name ArtJudge
extends RefCounted
## fix/art judge images (UX-03 creatures in Tallow's shadow, C6 guardians in the dark), measured by
## tools/art_judge.py. Never used in play.
##   xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 --resolution 1600x720 \
##       -- --autotest --tour --artjudge --shots=DIR [--set=shadow|bosses]
## Every lodger of each floor stands in Tallow's hard shadow (a 14 px occluder between them, in a room with
## its pits and obstacles taken out), at full wax and at 25 % wax, plus the same ring lit as a reference. Every
## guardian stands far across a room from Tallow (outside his light at 25 % wax). Each layout is shot twice
## with the game paused: A as played, B with the creatures' sprites hidden, so the diff gives each
## creature's own pixels; `judge.json` lists every creature's screen rect per shot pair.

const RING_R := 46.0
const OCC_R := 22.0
const OCC_HALF := 7.0


static func run(bot: Node) -> void:
	var dir: String = bot._shots_dir
	DirAccess.make_dir_recursive_absolute(dir)
	var which := str(bot.args.get("set", "all"))
	if which == "cards":
		await _cards(bot)
		bot.get_tree().quit()
		return
	if which == "perf":
		await _perf(bot)
		bot.get_tree().quit()
		return
	bot.main.goto("game", {"seed": 5})
	await bot._wait(1.5)
	var w: Node = bot.main.current
	var out := {"pairs": []}
	for n in [1, 2, 3, 4]:
		w._start_floor(n)
		await bot._wait(3.0)   # the floor banner clears
		var cells: Array = bot._normal_cells(w)
		var c: Vector2i = cells[0]
		w.layout["cells"][c]["cleared"] = true
		w.layout["cells"][c]["grid"] = _open_grid(w.layout["cells"][c]["grid"])   # no pits, no obstacles
		bot._jump(w, c)
		await bot._wait(0.5)
		w.player.frozen = true
		w.freeze_t = 9999.0
		if which in ["all", "shadow"]:
			var kinds: Array = []
			for slot in ["e", "h", "f"]:
				for k in w.POOLS[n][slot]:
					if not k in kinds:
						kinds.append(k)
			for cond in [["shadow", 1.0], ["shadow", 0.25], ["lit", 1.0]]:
				for g0 in range(0, kinds.size(), 8):
					var grp: Array = kinds.slice(g0, g0 + 8)
					var tag := "f%d_%s_%d_g%d" % [n, cond[0], int(cond[1] * 100), g0 / 8]
					out["pairs"].append(await _ring(bot, w, grp, cond[0] == "shadow", cond[1], tag))
		if which in ["all", "bosses"]:
			for kind in w.FLOORS[n]["bosses"]:
				for wax in [1.0, 0.25]:
					out["pairs"].append(await _far(bot, w, kind, wax, "f%d_boss_%s_%d" % [n, kind, int(wax * 100)]))
	var f := FileAccess.open(dir + "/judge.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " "))
	f.close()
	print("[artjudge] done: ", out["pairs"].size(), " shot pairs")
	bot.get_tree().quit()


## --set=cards: every guardian's versus card as it comes in, then the fight 3 s later (the bot plays,
## unkillable): the guardians in their own arenas with the rim, the light pool and the ground shadow.
static func _cards(bot: Node) -> void:
	bot.args["god"] = true
	bot.args["drive"] = true
	var floors: Dictionary = load("res://scripts/game/world.gd").FLOORS
	for n in [1, 2, 3, 4]:
		for kind in floors[n]["bosses"]:
			if bot.args.has("only") and str(bot.args["only"]) != kind:
				continue
			bot.main.goto("game", {"seed": 11 + n})
			await bot._wait(1.2)
			var w: Node = bot.main.current
			w._start_floor(n)
			w.boss_kind = kind
			await bot._wait(0.3)
			bot._jump(w, w.layout["boss"])
			await bot._wait(0.55)
			await bot._shot("card_%s" % kind)
			await bot._wait(3.4)
			await bot._shot("fight_%s" % kind)


## --set=perf: what the shadow-floor twin light and the glow pass cost, in one process so the machine's load
## is the same for both: a crowded crypt room with its own obstacles (shadows), 24 lodgers (some marked),
## frames counted over alternating 3 s windows with each feature on and off (ABAB..., so load drift cancels).
static func _perf(bot: Node) -> void:
	bot.args["god"] = true
	bot.main.goto("game", {"seed": 5})
	await bot._wait(1.5)
	var w: Node = bot.main.current
	w._start_floor(2)
	await bot._wait(3.0)
	var c: Vector2i = bot._normal_cells(w)[0]
	w.layout["cells"][c]["cleared"] = true
	bot._jump(w, c)
	await bot._wait(0.5)
	w.player.frozen = true
	w.freeze_t = 9999.0
	var kinds: Array = []
	for slot in ["e", "h", "f"]:
		for k in w.POOLS[2][slot]:
			if not k in kinds:
				kinds.append(k)
	var ctr: Vector2 = w.room.center()
	for i in 24:
		var e: Enemy = w.spawn_enemy(kinds[i % kinds.size()], ctr + Vector2(-96 + 24 * (i % 9), -50 + 34 * (i / 9)),
			["", "", "", "ember", "", "chilled"][i % 6])
		if e:
			e.set_meta("swarm_child", true)
	await bot._wait(2.0)
	var res := {"twin_on": [], "twin_off": [], "glow_on": [], "glow_off": [], "both_off": []}
	for rep in 3:
		for mode in ["twin_on", "twin_off", "glow_on", "glow_off", "both_off"]:
			Lighting.twin_on = mode != "twin_off" and mode != "both_off"
			CreatureGlow.enabled = mode != "glow_off" and mode != "both_off"
			await bot._wait(0.5)
			var f0 := Engine.get_frames_drawn()
			var t0 := Time.get_ticks_usec()
			await bot._wait(3.0)
			res[mode].append((Engine.get_frames_drawn() - f0) / ((Time.get_ticks_usec() - t0) / 1e6))
	Lighting.twin_on = true
	CreatureGlow.enabled = true
	for k in res:
		var v: Array = res[k]
		print("[artjudge] perf %-9s fps %s  mean %.1f" % [k, str(v.map(func(x): return snappedf(x, 0.1))), v.reduce(func(a, b): return a + b, 0.0) / v.size()])
	print("[artjudge] perf enemies %d, canvas draw calls now %d" % [w.enemies.size(),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])


## The same room with every tile plain floor (walls and doors are drawn by the room itself).
static func _open_grid(g: Array) -> Array:
	var out := []
	for row in g:
		if row is String:
			out.append(".".repeat((row as String).length()))
		else:
			var r := []
			r.resize((row as Array).size())
			r.fill(".")
			out.append(r)
	return out


static func _clear(w: Node) -> void:
	for e in w.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	w.enemies.clear()


static func _set_wax(w: Node, frac: float) -> void:
	w.player.wax = w.player.wax_max * frac


## Up to 8 creatures in a ring round Tallow, each behind its own occluder (or lit, without them).
static func _ring(bot: Node, w: Node, kinds: Array, shadowed: bool, wax: float, tag: String) -> Dictionary:
	_clear(w)
	var c: Vector2 = w.room.center()
	w.player.position = c + Vector2(0, 18)
	await bot.get_tree().process_frame
	await bot.get_tree().process_frame
	c = (w.player.get("light") as Node2D).global_position   # the ring centres on his flame's light
	var occs: Array = []
	var list: Array = []
	for i in kinds.size():
		var d := Vector2.from_angle(TAU * i / 8.0 + PI / 8.0)
		var at := c + d * RING_R
		if shadowed:
			var occ := LightOccluder2D.new()
			var poly := OccluderPolygon2D.new()
			var o := c + d * OCC_R
			poly.polygon = PackedVector2Array([o + Vector2(-OCC_HALF, -OCC_HALF), o + Vector2(OCC_HALF, -OCC_HALF),
				o + Vector2(OCC_HALF, OCC_HALF), o + Vector2(-OCC_HALF, OCC_HALF)])
			occ.occluder = poly
			w.room.add_child(occ)
			occ.global_position = Vector2.ZERO
			occs.append(occ)
		var e: Enemy = w.spawn_enemy(kinds[i], at + Vector2(0, 9))
		if e:
			e.set_meta("swarm_child", true)
			list.append(e)
	var rec := await _shoot(bot, w, list, wax, tag)
	for o in occs:
		o.queue_free()
	return rec


## One guardian across the room from Tallow, in the dark.
static func _far(bot: Node, w: Node, kind: String, wax: float, tag: String) -> Dictionary:
	_clear(w)
	var c: Vector2 = w.room.center()
	w.player.position = c + Vector2(-96, 40)
	var e: Enemy = w.spawn_enemy(kind, c + Vector2(80, -14))
	return await _shoot(bot, w, [e] if e else [], wax, tag)


static func _shoot(bot: Node, w: Node, list: Array, wax: float, tag: String) -> Dictionary:
	_set_wax(w, wax)
	await bot._wait(2.6)   # spawn fade-in done, the waning caught up with the wax
	_set_wax(w, wax)
	await bot._wait(0.3)
	var tree: SceneTree = bot.get_tree()
	tree.paused = true
	await tree.process_frame
	await tree.process_frame
	var vp: Vector2 = bot.get_viewport().get_visible_rect().size
	var rects := []
	for e in list:
		if not is_instance_valid(e):
			continue
		var s: AnimatedSprite2D = e.spr
		var tex: Texture2D = s.sprite_frames.get_frame_texture(s.animation, s.frame)
		var xf: Transform2D = s.get_global_transform_with_canvas()
		var p0: Vector2 = xf * s.offset
		var p1: Vector2 = xf * (s.offset + tex.get_size())
		rects.append({"kind": e.kind, "boss": e.boss, "x0": minf(p0.x, p1.x), "y0": minf(p0.y, p1.y),
			"x1": maxf(p0.x, p1.x), "y1": maxf(p0.y, p1.y)})
	await bot._shot(tag + "_A")
	var a_name := "%02d_%s_A.png" % [bot._shot_i, tag]
	for e in list:
		if is_instance_valid(e):
			e.spr.visible = false
			for ch in e.get_children():
				if str(ch.name) == "CreatureGlow":
					ch.visible = false
	await tree.process_frame
	await bot._shot(tag + "_B")
	var b_name := "%02d_%s_B.png" % [bot._shot_i, tag]
	for e in list:
		if is_instance_valid(e):
			e.spr.visible = true
	tree.paused = false
	return {"tag": tag, "wax": wax, "a": a_name, "b": b_name, "viewport": [vp.x, vp.y], "rects": rects}
